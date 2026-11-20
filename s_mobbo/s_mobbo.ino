#include <Arduino.h>

// NodeMCU 1.0 (ESP-12E) pin map used here:
//   D0=GPIO16  D1=GPIO5  D2=GPIO4  D3=GPIO0  D4=GPIO2
//   D5=GPIO14  D6=GPIO12 D7=GPIO13 D8=GPIO15
//   D9=GPIO3 (Serial RX) and D10=GPIO1 (Serial TX) are used by Serial,
//   so they must NOT be used for the HX711.
//
// Wiring:
//   HX711 #1: DOUT=D0  SCK=D4   (D4 = GPIO2, also the on-board LED)
//   HX711 #2: DOUT=D5  SCK=D6
//   HX711 #3: DOUT=D7  SCK=D8   (GPIO15 must be LOW at boot; HX711 input is fine)
//   HX711 #4: DOUT=D1  SCK=D2
const uint8_t HX711_DOUT[4] = {D0, D5, D7, D1};
const uint8_t HX711_SCK[4]  = {D4, D6, D8, D2};

int32_t rawAdc[4] = {0, 0, 0, 0};
bool updated[4] = {false, false, false, false};

// Read one signed 24-bit conversion. The 25th clock selects channel A,
// gain 128, for the next conversion. Call only when DOUT is low (ready).
int32_t readHx711(uint8_t dout, uint8_t sck) {
  uint32_t value = 0;
  // SCK high for >60 us powers the HX711 down, so keep the sequence atomic.
  noInterrupts();
  for (uint8_t bit = 0; bit < 24; ++bit) {
    digitalWrite(sck, HIGH);
    delayMicroseconds(1);
    value = (value << 1) | (digitalRead(dout) ? 1UL : 0UL);
    digitalWrite(sck, LOW);
    delayMicroseconds(1);
  }
  digitalWrite(sck, HIGH);   // 25th pulse: next conversion = channel A, gain 128
  delayMicroseconds(1);
  digitalWrite(sck, LOW);
  interrupts();

  // Sign-extend the 24-bit two's-complement result.
  if (value & 0x800000UL) value |= 0xFF000000UL;
  return (int32_t)value;
}

void setup() {
  Serial.begin(115200);
  // Radio is not needed; turning it off reduces noise on the ADC readings.
  WiFi.mode(WIFI_OFF);
  WiFi.forceSleepBegin();
  delay(1);

  for (uint8_t i = 0; i < 4; ++i) {
    pinMode(HX711_DOUT[i], INPUT);   // GPIO16 (D0) has no internal pull-up anyway
    pinMode(HX711_SCK[i], OUTPUT);
    digitalWrite(HX711_SCK[i], LOW); // SCK low = HX711 awake
  }
}

void loop() {
  for (uint8_t i = 0; i < 4; ++i) {
    if (!updated[i] && digitalRead(HX711_DOUT[i]) == LOW) {
      rawAdc[i] = readHx711(HX711_DOUT[i], HX711_SCK[i]);
      updated[i] = true;
    }
  }

  // One packet per line: ADC1,ADC2,ADC3,ADC4\r\n  (raw, untared, signed 24-bit)
  if (updated[0] && updated[1] && updated[2] && updated[3]) {
    for (uint8_t i = 0; i < 4; ++i) {
      if (i != 0) Serial.print(',');
      Serial.print(rawAdc[i]);
      updated[i] = false;
    }
    Serial.print("\r\n");
  }

  yield();  // keep the ESP8266 watchdog happy
}