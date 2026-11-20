using UnityEngine;
using UnityEngine.UI; // Required for UI components

public class startbirdgame : MonoBehaviour
{
    public Button startButton; // Reference to the UI Button
    public Image blackScreen; // Reference to the black screen Image
    public BirdScript birdScript; // Reference to the BirdScript
    public timer timerScript; // Reference to TimerScript

    void Start()
    {
        if (startButton != null && blackScreen != null && birdScript != null && timerScript != null)
        {
            blackScreen.gameObject.SetActive(true);
            startButton.gameObject.SetActive(true);
            startButton.onClick.AddListener(StartGame);
        }
        else
        {
            UnityEngine.Debug.LogError("StartButton, BlackScreen, BirdScript, or TimerScript is not assigned.");
        }
    }

    void StartGame()
    {
        if (birdScript != null && timerScript != null)
        {
           

            // Hide the button and black screen
            startButton.gameObject.SetActive(false);
            blackScreen.gameObject.SetActive(false);

            // Start the timer
            timerScript.remTime = 30; // Set initial time (e.g., 60 seconds)
            timerScript.gameObject.SetActive(true); // Ensure the timer UI is active
        }
        else
        {
            UnityEngine.Debug.LogError("BirdScript or TimerScript is not assigned.");
        }
    }
}
