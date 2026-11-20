//using System.IO.Enumeration;
//using System.Security.AccessControl;
//using System.Runtime;
//using System.Reflection;
//using System.Collections;
//using System.Collections.Generic;
//using UnityEngine;
//using UnityEngine.UI;
//using UnityEngine.SceneManagement;
//using MoBBoLibrary_WIFI;
//using System;
//using System.IO;
//using System.Diagnostics;
//using System.ComponentModel;
//using System.Data;
//using System.Drawing;
//using System.Threading;
//using System.Linq;
//using System.Net;
//using System.Net.Sockets;
//using System.Runtime.CompilerServices;
//using System.Text;
//using System.Text.RegularExpressions;
//using System.Threading.Tasks;
//using CodeMonkey.Utils;

//public class StepperGameManager : MonoBehaviour
//{
//    public Image rightFootUpImage;
//    public Image leftFootUpImage;
//    public Image leftFootDownImage;
//    public Image rightFootDownImage;

//    public Text timerText; // UI Text to display the timer
//    public Button startButton, btnGoBack; // Button to start the trial
//    public Text resultText; // Display results after the trial

//    public float fadeDuration = 2f; // Duration of the fade effect in seconds
//    public float delayBetweenStates = 3f; // Delay between state transitions in seconds

//    private enum StepState { None, RightFootUp, LeftFootUp, LeftFootDown, RightFootDown }
//    private StepState currentState = StepState.None;

//    public float weightStep1;
//    public float weightStep2, copX_step1, copX_step2;
//    public float totalBodyWeight;

//    private float trialDuration = 30f; // Trial duration in seconds
//    private float remainingTime; // Timer countdown
//    private bool isTrialActive = false; // Whether the trial is active

//    private int rightFootUpCount = 0;
//    private int leftFootUpCount = 0;
//    private int rightFootDownCount = 0;
//    private int leftFootDownCount = 0;

//    private bool rightFootUpFlag = false;
//    private bool rightFootDownFlag = false;
//    private bool leftFootUpFlag = false;
//    private bool leftFootDownFlag = false;
//    private int trialCount = 0;
//    private float trialStartTime;

//    public string csvFilePath;
//    public static string player_id;

//    void Start()
//    {
//        if (AppData_WIFI.session == null)
//        {
//            AppData_WIFI.StartDummySession();
//        }
//        csvFilePath = Path.Combine(login_handlr.stepper_gamedata, "stepper_gamedata.csv");
//        if (!File.Exists(csvFilePath))
//        {
//            CreateCSVFile();
//        }
//        startButton.onClick.AddListener(OnStartButtonPressed);
//        resultText.text = "";
//        timerText.text = "30.00"; // Initialize timer text
//    }
//    public void btnGoBack_Click()
//    {
//        SceneManager.LoadScene("2mb");
//    }
//    private void StartLoggingProcess(string filePath, int trial)
//    {
//        MoBBoServer.server.StartLogging_p(filePath, trial);
//        UnityEngine.Debug.Log($"Logging started: {filePath}");
//    }

//    private void StopLoggingProcess()
//    {
//        MoBBoServer.server.StopLogging();
//        UnityEngine.Debug.Log("Logging stopped");
//    }

//    void Update()
//    {


//        weightStep1 = MoBBoServer.W_player2_ap;
//        weightStep2 = MoBBoServer.W_player1_ap;
//        copX_step1 = MoBBoServer.COP_BottomBoard.x;
//        copX_step2 = MoBBoServer.COP_TopBoard.x;
//        totalBodyWeight = weightStep1 + weightStep2;
//        UnityEngine.Debug.Log($"weightStep1: {weightStep1}, weightStep2: {weightStep2}, totalBodyWeight: {totalBodyWeight}, copX_step1: {copX_step1}, copX_step2: {copX_step2}");

//        if (isTrialActive)
//        {
//            remainingTime = Mathf.Max(0, trialDuration - (Time.time - trialStartTime));
//            UpdateTimerDisplay(remainingTime);

//            if (remainingTime <= 0)
//            {
//                EndTrial();
//            }
//            else
//            {
//                HandleStepLogic();
//            }
//        }
//    }

//    void CreateCSVFile()
//    {
//        // Create the CSV file with headers
//        using (StreamWriter writer = new StreamWriter(csvFilePath))
//        {
//            writer.WriteLine("Trial,Right Foot Up,Left Foot Up,Right Foot Down,Left Foot Down,Trial Duration");
//        }
//    }

//    void WriteToCSV(int trial, int rightFootUp, int leftFootUp, int rightFootDown, int leftFootDown, float duration)
//    {
//        // Append a row of trial data to the CSV file
//        using (StreamWriter writer = new StreamWriter(csvFilePath, true))
//        {
//            writer.WriteLine($"{trial},{rightFootUp},{leftFootUp},{rightFootDown},{leftFootDown},{duration:F2}");
//        }
//    }

//    void OnStartButtonPressed()
//    {
//        if (isTrialActive)
//        {
//            EndTrial();
//        }
//        else
//        {
//            StartNewTrial();
//        }
//    }

//    void StartNewTrial()
//    {
//        trialCount++;
//        isTrialActive = true;
//        trialStartTime = Time.time;
//        remainingTime = trialDuration; // Reset the timer

//        // Reset counts for the new trial
//        rightFootUpCount = 0;
//        leftFootUpCount = 0;
//        rightFootDownCount = 0;
//        leftFootDownCount = 0;

//        rightFootUpFlag = false;
//        rightFootDownFlag = false;
//        leftFootUpFlag = false;
//        leftFootDownFlag = false;

//        resultText.text = ""; // Clear previous trial results
//        timerText.text = trialDuration.ToString("F2"); // Initialize timer display

//        string logFilePath = login_handlr.stepper_rawdata + "//" + player_id + DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss") + $"Trial_{trialCount}";
//        if (!string.IsNullOrEmpty(logFilePath))
//        {
//            StartLoggingProcess(logFilePath, trialCount);
//        }
//    }

//    void EndTrial()
//    {
//        isTrialActive = false;
//        StopLoggingProcess();

//        // Calculate trial duration
//        float actualDuration = trialDuration - remainingTime;

//        // Write trial data to CSV
//        WriteToCSV(trialCount, rightFootUpCount, leftFootUpCount, rightFootDownCount, leftFootDownCount, actualDuration);

//        // Display results
//        resultText.text = $"Trial {trialCount} completed.\nDuration: {actualDuration:F2} seconds\n" +
//                          $"Right Foot Up: {rightFootUpCount}\nLeft Foot Up: {leftFootUpCount}\n" +
//                          $"Right Foot Down: {rightFootDownCount}\nLeft Foot Down: {leftFootDownCount}";

//        UnityEngine.Debug.Log($"Trial {trialCount} saved to {csvFilePath}");
//    }

//    void UpdateTimerDisplay(float timeLeft)
//    {
//        timerText.text = timeLeft.ToString("F2"); // Update the timer text
//    }

//    void HandleStepLogic()
//    {

//        UnityEngine.Debug.Log($"currentState: {currentState}, rightFootUpFlag: {rightFootUpFlag}, rightFootDownFlag: {rightFootDownFlag}, leftFootUpFlag: {leftFootUpFlag}, leftFootDownFlag: {leftFootDownFlag}");

//        // Right Foot Up
//        if (currentState == StepState.None && weightStep1 >= totalBodyWeight)
//        {
//            UnityEngine.Debug.Log("Entered  weightStep1 >= totalBodyWeight");
//            if (!rightFootUpFlag)
//            {
//                UnityEngine.Debug.Log("rightFootUpFlag");
//                StartCoroutine(TransitionToState(StepState.RightFootUp, rightFootUpImage));
//                leftFootDownCount++;
//                rightFootUpFlag = true;
//                SetFlags("RightFootUp");
//                // ResetFlagsExcept("RightFootUp");

//            }
//        }
//        // Right Foot Down
//        else if (currentState == StepState.None && weightStep2 >= totalBodyWeight)
//        {
//            UnityEngine.Debug.Log("Entered weightStep2 >= totalBodyWeight");
//            if (!rightFootDownFlag)
//            {
//                UnityEngine.Debug.Log("rightFootDownFlag");
//                StartCoroutine(TransitionToState(StepState.RightFootDown, rightFootDownImage));
//                leftFootUpCount++;
//                rightFootDownFlag = true;
//                SetFlags("RightFootDown");
//                //ResetFlagsExcept("RightFootDown");

//            }
//        }
//        // Left Foot Up
//        else if (currentState == StepState.None && weightStep1 < totalBodyWeight && copX_step2 > 30 && copX_step1 < 30)
//        {
//            UnityEngine.Debug.Log("Entered weightStep1 != totalBodyWeight && copX_step2 > 30 && copX_step1 < 30");
//            if (!leftFootUpFlag)
//            {
//                UnityEngine.Debug.Log("leftFootUpFlag");
//                StartCoroutine(TransitionToState(StepState.LeftFootUp, leftFootUpImage));
//                rightFootUpCount++;
//                leftFootUpFlag = true;
//                SetFlags("LeftFootUp");
//                // ResetFlagsExcept("LeftFootUp");

//            }
//        }
//        // Left Foot Down
//        else if (currentState == StepState.None && weightStep2 < totalBodyWeight && copX_step1 > 30 && copX_step2 < 30)
//        {
//            UnityEngine.Debug.Log("Entered weightStep2 != totalBodyWeight && copX_step1 > 30 && copX_step2 < 30");
//            if (!leftFootDownFlag)
//            {
//                UnityEngine.Debug.Log("leftFootDownFlag");
//                StartCoroutine(TransitionToState(StepState.LeftFootDown, leftFootDownImage));
//                rightFootDownCount++;
//                leftFootDownFlag = true;
//                SetFlags("LeftFootDown");
//                //ResetFlagsExcept("LeftFootDown");

//            }
//        }
//    }

//    void SetFlags(string activeFlag)
//    {
//        rightFootUpFlag = activeFlag == "RightFootUp";
//        rightFootDownFlag = activeFlag == "RightFootDown";
//        leftFootUpFlag = activeFlag == "LeftFootUp";
//        leftFootDownFlag = activeFlag == "LeftFootDown";
//    }

//    IEnumerator TransitionToState(StepState newState, Image imageToShow)
//    {
//        currentState = StepState.None;
//        yield return FadeInImage(imageToShow);
//        yield return new WaitForSeconds(delayBetweenStates);
//        currentState = newState;
//    }


//    IEnumerator FadeInImage(Image image)
//    {
//        HideAllImages();
//        float elapsedTime = 0f;

//        UnityEngine.Color color = image.color;
//        color.a = 0f;
//        image.color = color;
//        image.gameObject.SetActive(true);

//        while (elapsedTime < fadeDuration)
//        {
//            color.a = Mathf.Lerp(0f, 1f, elapsedTime / fadeDuration);
//            image.color = color;
//            elapsedTime += Time.deltaTime;
//            yield return null;
//        }

//        color.a = 1f;
//        image.color = color;
//    }

//    void HideAllImages()
//    {
//        HideImage(rightFootUpImage);
//        HideImage(leftFootUpImage);
//        HideImage(leftFootDownImage);
//        HideImage(rightFootDownImage);
//    }

//    void HideImage(Image image)
//    {
//        UnityEngine.Color color = image.color;
//        color.a = 0f;
//        image.color = color;
//        image.gameObject.SetActive(false);
//    }
//}
