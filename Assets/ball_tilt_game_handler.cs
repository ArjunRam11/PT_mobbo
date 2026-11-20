using System.IO.Enumeration;
using System.Security.AccessControl;
using System.Runtime;
using System.Reflection;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using MoBBoLibrary_WIFI;
using System;
using System.IO;
using System.Diagnostics;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Threading;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using CodeMonkey.Utils;

public class ball_tilt_game_handler : MonoBehaviour
{
    public Text timerText;       // Timer text UI
    public Text scoreText;       // Score text UI
    public Button startButton, btnStartSession, btnGoBack;   // Start button UI
    public BallCollisionHandler ballHandler; // Ball collision handler
    public Transform ballStartPosition;     // Ball start position
    public GameObject ball;                 // Ball GameObject
    public BoardTiltController boardController; // Board controller

    private float trialTime;  // Time for each trial
    private int score = 0;         // Player's score
    private bool trialActive = false; // Is a trial ongoing?
    public static string player_id;
    public int trail_count;
    public string csvFilePath;
    public BoardTiltController boardTiltController;

    public List<string> game_data = new List<string>();
    public bool is_header_written = false;
    public AudioSource audioSource;


    void Start()
    {
        if (AppData_WIFI.session == null)
        {
            AppData_WIFI.StartDummySession();
        }
        trialTime = login_handlr.trial_duration;
      

        btnStartSession.GetComponent<Button>().onClick.AddListener(btnStartSession_Click);
        btnGoBack.GetComponent<Button>().onClick.AddListener(btnGoBack_Click);
        UpdateTimerText();
        UpdateScoreText();
      
        startButton.onClick.AddListener(() => StartCoroutine(TrialCoroutine()));
    }

    public void btnStartSession_Click()
    {
        UnityEngine.Debug.Log("Starting session.");
    }

    public void btnGoBack_Click()
    {
        SceneManager.LoadScene("2mb");
    }

    private void StartLoggingProcess(string filePath, int trial)
    {
        MoBBoServer.server.StartLogging_p(filePath, trial);
        UnityEngine.Debug.Log($"Logging started: {filePath}");
    }

    private void StopLoggingProcess()
    {
        MoBBoServer.server.StopLogging();
        UnityEngine.Debug.Log("Logging stopped");
    }
    
    public void tilt_game_data_strbldr(float ballPosX, float ballPosY, float angleOfTilt, int level, float ballSpeed, float paddleWidth)
    {

        string game_time = DateTime.UtcNow.ToString("yy-MM-dd-HH-mm-ss");
        Vector2 position_of_bird = ball.transform.position;
        string ball_x = ballPosX.ToString(); string ball_y = ballPosY.ToString(); string angle = angleOfTilt.ToString(); string level_ = level.ToString(); string Pdwidth = paddleWidth.ToString(); string ball_speed_= ballSpeed.ToString(); // x and y postion from the vector component of all gameobjects
        string gamelevel_ = boardTiltController.gamelevel.ToString();
       

        string all_data = game_time + "," + ball_x + "," + ball_y + "," + angle+ "," + gamelevel_ + "," + ball_speed_ +"," + Pdwidth;

        game_data.Add(all_data);

    }
    private void SaveGameDataWithTrial(int trialNumber, string filePath)
    {
        UnityEngine.Debug.Log($"Saving game data to: {filePath}");

        // Write game data to the specified file
        using (StreamWriter writer = new StreamWriter(filePath))
        {
            if (!is_header_written)
            {
                writer.WriteLine("time,ball_pos_x,ball_pos_y, angle_of_tilt,level,ball_speed, paddle_width");
                is_header_written = true;
            }
            foreach (string dataLine in game_data)
            {
                writer.WriteLine(dataLine);
            }
        }

        // Clear game data for the next trial
        game_data.Clear();
    }



    private IEnumerator TrialCoroutine()
    {
        trail_count++;
        trialActive = true;

        if (audioSource != null && !audioSource.isPlaying)
        {
            audioSource.Play(); // Start playing audio
        }
        if (ballHandler != null)
        {
            ballHandler.ResetTrial();
        }
        else
        {
            UnityEngine.Debug.LogError("ballHandler is null!");
        }

        if (ball != null && ballStartPosition != null)
        {
            ball.transform.position = ballStartPosition.position;
           
        }
        else
        {
            UnityEngine.Debug.LogError($"ball or ballStartPosition is null! ball: {ball}, ballStartPosition: {ballStartPosition}");
        }

        if (boardController != null)
        {
            boardController.UpdateWeight(50, 50);
        }
        else
        {
            UnityEngine.Debug.LogError("boardController is null!");
        }

        UpdateTimerText();

        startButton.gameObject.SetActive(false);

        Rigidbody2D ballRb = ball.GetComponent<Rigidbody2D>();
        if (ballRb != null)
        {
            ballRb.velocity = Vector2.zero;
            ballRb.angularVelocity = 0f;
        }
        else
        {
            UnityEngine.Debug.LogError("Rigidbody2D on ball is missing!");
        }

        string logFilePath = login_handlr.ball_roller_rawdata + "//" + player_id + DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss") + $"Trial_{trail_count}";
        if (!string.IsNullOrEmpty(logFilePath))
        {
            StartLoggingProcess(logFilePath, trail_count);
        }
        else
        {
            UnityEngine.Debug.LogError("Log file path is invalid!");
        }

        float remainingTime = trialTime;

        while (remainingTime > 0 && !ballHandler.IsTrialComplete())
        {
            UpdateTimerText(remainingTime);
            tilt_game_data_strbldr(ball.transform.position.x, ball.transform.position.y, boardTiltController.tiltAngle, boardTiltController.gamelevel, boardTiltController.ballSpeed, boardTiltController.newPaddleWidth);
            yield return new WaitForSeconds(1f);
            remainingTime--;
        }
        UnityEngine.Debug.Log("Trial bool."+ ballHandler.IsTrialComplete()+ "   "+ ballHandler.DidBallHitGround());

        bool success = remainingTime <= 0 && !ballHandler.DidBallHitGround();

        EndTrial(success);
    }


    void EndTrial(bool success)
    {
        trialActive = false;
        RectTransform ballRectTransform = GameObject.FindGameObjectWithTag("ball").GetComponent<RectTransform>();
        if (ballRectTransform != null)
        {
            ballRectTransform.anchoredPosition = new Vector2(0f, 30f);
        }
        if (audioSource != null && audioSource.isPlaying)
        {
            audioSource.Stop();
        }
        // Stop logging process
        StopLoggingProcess();
        string fileName = $"Trial_{trail_count}_Data_{DateTime.Now:yyyy-MM-dd_HH-mm-ss}.csv";
        string trialFilePath = Path.Combine(login_handlr.ball_roller_gamedata, fileName);

        SaveGameDataWithTrial(trail_count, trialFilePath);

        if (success)
        {
            score++;
            UnityEngine.Debug.Log("Trial succeeded! Ball stayed on the board.");
        }
        else
        {
            UnityEngine.Debug.Log("Trial failed. Ball hit the ground or time ran out.");
        }

        UpdateScoreText();
        startButton.gameObject.SetActive(true); // Show the button for the next trial
    }
    void UpdateTimerText(float remainingTime=-1)
    {
        timerText.text = "Time: " + Mathf.Max(remainingTime, 0).ToString("F1");
    }
   

    void UpdateScoreText()
    {
        scoreText.text = "Score: " + score;
    }

    public void OnBallHitsGround()
    {
        if (trialActive)
        {
            EndTrial(success: false); // Trial failed if the ball hits the ground
        }
    }
}


