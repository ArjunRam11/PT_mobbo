using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using TMPro;


public class LogicScript : MonoBehaviour
{
    [SerializeField] timer stop;
    public int playerScore;
    public Text scoreText;
    public GameObject gameOverScreen;
    //public AudioSource dingSFX;
    public int highScore;
    public Text highScoreText;
    //private int trialCount = 0;  // Track the trial number
    private bool isTrialActive = false;
    private List<string> csvData = new List<string>(); // Data for CSV
    public PipeSpawnScript pipe_v;


    void Start()
    {
        //highScore = PlayerPrefs.GetInt("highScore");
        //ScoreText.text = "High Score: " + Score.ToString();
    }

    [ContextMenu("Increase Score")]

    public void addScore(int scoreToAdd)
    {
      
            playerScore += scoreToAdd;
            scoreText.text = playerScore.ToString();

            if (playerScore > highScore)
            {
                highScoreText.text = "High Score: " + playerScore.ToString();
            }
        
    }

    public void restartGame()
    {
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
        Time.timeScale = 1;
    }

    //public void gameOver()
    //{
    //    gameOverScreen.SetActive(true);
    //    if (playerScore > highScore)
    //    {
    //        highScore = playerScore;
    //        PlayerPrefs.SetInt("highScore", playerScore);

    //    }
    //    highScoreText.text = "High Score:" + highScore.ToString();
    //    if (stop != null)   
    //    {
    //        stop.StopTimer();
    //    }

    //}
    public void gameOver()
    {
     
            //isTrialActive = false;
            gameOverScreen.SetActive(true);

            //if (playerScore > highScore)
            //{
            //    highScore = playerScore;
            //    PlayerPrefs.SetInt("highScore", playerScore);
            //}

            //highScoreText.text = "High Score: " + highScore.ToString();

            SaveTrialData(); // Save trial data to CSV
        
    }
    //public void StartTrial()
    //{
    //    if (!isTrialActive)
    //    {
    //        isTrialActive = true;
    //        trialCount++;
    //        playerScore = 0;
    //        //stop.StartTimer(); // Start the 30-second timer
    //        csvData.Clear();   // Clear data for new trial
    //    }
    //}
    private void SaveTrialData()
    {
        string filePath = Application.persistentDataPath + "/trial_" + pipe_v.Trialcount + ".csv";
        System.IO.File.WriteAllLines(filePath, csvData.ToArray());
        UnityEngine.Debug.Log("Trial data saved to: " + filePath);
    }

    public void LogBirdData(Vector3 position, float speed)
    {
        string data = $"{Time.time},{position.x},{position.y},{position.z},{speed}";
        csvData.Add(data);
    }
}




//using System.Collections;
//using System.Collections.Generic;
//using UnityEngine;
//using UnityEngine.UI;
//using UnityEngine.SceneManagement;
//using TMPro;


//public class LogicScript : MonoBehaviour
//{
//    [SerializeField] timer stop;
//    public int playerScore;
//    //public Text scoreText;
//    public GameObject gameOverScreen;
//    //public AudioSource dingSFX;
//    public int highScore;
//    public Text highScoreText;
//    //private int trialCount = 0;  // Track the trial number
//    private bool isTrialActive = false;
//    private List<string> csvData = new List<string>(); // Data for CSV
//    public PipeSpawnScript pipe_v;

//    public Text scoreText; // Reference to the UI Text element for displaying the score
//    private int score = 0;



//    void Start()
//    {
//        if (scoreText == null)
//        {
//            Debug.LogError("Score Text not assigned!");
//        }
//    }

//    [ContextMenu("Increase Score")]

//    public void addScore(int points)
//    {
//        score += points;
//        UpdateScoreText();
//    }

//    private void UpdateScoreText()
//    {
//        // Update the text UI with the current score
//        scoreText.text = "Score: " + score.ToString();
//    }

//    public void restartGame()
//    {
//        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
//        Time.timeScale = 1;
//    }

//    //public void gameOver()
//    //{
//    //    gameOverScreen.SetActive(true);
//    //    if (playerScore > highScore)
//    //    {
//    //        highScore = playerScore;
//    //        PlayerPrefs.SetInt("highScore", playerScore);

//    //    }
//    //    highScoreText.text = "High Score:" + highScore.ToString();
//    //    if (stop != null)   
//    //    {
//    //        stop.StopTimer();
//    //    }

//    //}
//    public void gameOver()
//    {
//        if (isTrialActive)
//        {
//            isTrialActive = false;
//            gameOverScreen.SetActive(true);

//            if (playerScore > highScore)
//            {
//                highScore = playerScore;
//                PlayerPrefs.SetInt("highScore", playerScore);
//            }

//            highScoreText.text = "High Score: " + highScore.ToString();

//            SaveTrialData(); // Save trial data to CSV
//        }
//    }
//    //public void StartTrial()
//    //{
//    //    if (!isTrialActive)
//    //    {
//    //        isTrialActive = true;
//    //        trialCount++;
//    //        playerScore = 0;
//    //        //stop.StartTimer(); // Start the 30-second timer
//    //        csvData.Clear();   // Clear data for new trial
//    //    }
//    //}
//    private void SaveTrialData()
//    {
//        string filePath = Application.persistentDataPath + "/trial_" + pipe_v.Trialcount + ".csv";
//        System.IO.File.WriteAllLines(filePath, csvData.ToArray());
//        Debug.Log("Trial data saved to: " + filePath);
//    }

//    public void LogBirdData(Vector3 position, float speed)
//    {
//        string data = $"{Time.time},{position.x},{position.y},{position.z},{speed}";
//        csvData.Add(data);
//    }
//}