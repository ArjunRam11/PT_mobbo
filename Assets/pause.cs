using UnityEngine;

public class pause : MonoBehaviour
{
    public KeyCode pauseKey = KeyCode.P; // Set your preferred pause key here
    public timer timerScript; // Reference to the Timer script

    private bool isPaused = false;

    void Update()
    {
        if (Input.GetKeyDown(pauseKey))
        {
            TogglePause();
        }
    }

    void TogglePause()
    {
        if (isPaused)
        {
            ResumeGame();
        }
        else
        {
            PauseGame();
        }
    }

    void PauseGame()
    {
        Time.timeScale = 0;
        isPaused = true;
        if (timerScript != null)
        {
            timerScript.pause(); // Pause the timer
        }
    }

    void ResumeGame()
    {
        Time.timeScale = 1;
        isPaused = false;
        if (timerScript != null)
        {
            // Make sure the timer continues to update
            // Timer script will automatically resume when Time.timeScale is 1
        }
    }
}
