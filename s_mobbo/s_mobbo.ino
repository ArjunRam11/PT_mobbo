#include <Arduino.h>
 
// NodeMCU 1.0 (ESP-12E) pin configuration
 
const uint8_t HX711_DOUT[4] = {D0, D5, D7, D1};
const uint8_t HX711_SCK[4]  = {D3, D6, D8, D2};
 
// Board Number: 0 = LEFT BOARD
// Board Number: 1 = RIGHT BOARD
const char* Boardno = "1";
 
int32_t rawAdc[4] = {0, 0, 0, 0};
bool updated[4] = {false, false, false, false};
 
// Read signed 24-bit HX711 conversion
int32_t readHx711(uint8_t dout, uint8_t sck) {
  uint32_t value = 0;
 
  noInterrupts();
 
  for (uint8_t bit = 0; bit < 24; ++bit) {
    digitalWrite(sck, HIGH);
    delayMicroseconds(1);
 
    value = (value << 1) | (digitalRead(dout) ? 1UL : 0UL);
 
    digitalWrite(sck, LOW);
    delayMicroseconds(1);
  }
 
  // 25th pulse: Channel A, gain 128
  digitalWrite(sck, HIGH);
  delayMicroseconds(1);
  digitalWrite(sck, LOW);
 
  interrupts();
 
  // Sign extension
  if (value & 0x800000UL) {
    value |= 0xFF000000UL;
  }
 
  return (int32_t)value;
}
 
void setup() {
  Serial.begin(115200);
 
  for (uint8_t i = 0; i < 4; ++i) {
    pinMode(HX711_DOUT[i], INPUT);
    pinMode(HX711_SCK[i], OUTPUT);
    digitalWrite(HX711_SCK[i], LOW);
  }
}
 
void loop() {
 
  // Read four HX711 modules
  for (uint8_t i = 0; i < 4; ++i) {
    if (!updated[i] && digitalRead(HX711_DOUT[i]) == LOW) {
      rawAdc[i] = readHx711(HX711_DOUT[i], HX711_SCK[i]);
      updated[i] = true;
    }
  }
 
  // Transmit when all four readings are available
  if (updated[0] && updated[1] &&
      updated[2] && updated[3]) {
 
    // Added string identifier
    // Serial.print(packetLabel);
    // Serial.print(',');
 
    // Transmit four ADC values
    for (uint8_t i = 0; i < 4; ++i) {
      if (i != 0) Serial.print(',');
 
      Serial.print(rawAdc[i]);
      updated[i] = false;
   
   
    }
    Serial.print(',');
    Serial.print(Boardno);
    Serial.println();
  }
 
  yield();
}
 