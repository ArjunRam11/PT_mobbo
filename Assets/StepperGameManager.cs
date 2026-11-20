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
using Color = UnityEngine.Color;


public class StepperGameManager : MonoBehaviour
{
    public GameObject rightFootUpImage, leftFootUpImage, leftFootDownImage, rightFootDownImage;

    public Image leftFootUp1;
    public Image leftFootDown1;
    public Image rightFootDown1;
    public Image rightFootUp1;
   

    public Text timerText; // UI Text to display the timer
    public Button startButton, btnGoBack; // Button to start the trial
    public Text resultText; // Display results after the trial

    public float fadeDuration = 2f; // Duration of the fade effect in seconds
    public float delayBetweenStates = 3f; // Delay between state transitions in seconds

    private enum StepState { None, RightFootUp, LeftFootUp, LeftFootDown, RightFootDown }
    private StepState currentState = StepState.None;

    public float weightStep1;
    public float weightStep2, copX_step1, copX_step2;
    public float totalBodyWeight;
    private float trialDuration; // Trial duration in seconds
    private float remainingTime; // Timer countdown
    private bool isTrialActive = false; // Whether the trial is active

    private int rightFootUpCount = 0;
    private int leftFootUpCount = 0;
    private int rightFootDownCount = 0;
    private int leftFootDownCount = 0;

    //private bool rightFootUpFlag = false;
    //private bool rightFootDownFlag = false;
    //private bool leftFootUpFlag = false;
    //private bool leftFootDownFlag = false;
    private int trialCount = 0;
    private float trialStartTime;
    public Text rightup, leftup;

    public string csvFilePath;
    public static string player_id;
    bool bothfootstep1_flag = false;
    bool bothfootstep2_flag = false;
    bool r_rightUp_leftDown, r_leftDown_rightUp = false;
    bool l_leftUp_rightDown, l_rightDown_leftUp= false;
    public AudioSource audioSource;
    public AudioClip audioClip;
    public AudioSource bgm;
    public Button right_amp;
    public Button left_amp;
    public bool its_right, its_left = false;
    public bool cycle=false;



    void Start()
    {
        if (AppData_WIFI.session == null)
        {
            AppData_WIFI.StartDummySession();
        }
     
        Directory.CreateDirectory(login_handlr.stepper_gamedata);
        Directory.CreateDirectory(login_handlr.stepper_rawdata);

        csvFilePath = Path.Combine(login_handlr.stepper_gamedata, "stepper_gamedata.csv");
        trialDuration = login_handlr.trial_duration;
        if (!File.Exists(csvFilePath))
        {
            CreateCSVFile();
        }
        startButton.onClick.AddListener(OnStartButtonPressed);
        resultText.text = "";
        timerText.text = "0.00"; // Initialize timer text
        bothfootstep1_flag = false;
        bothfootstep2_flag = false;
        r_leftDown_rightUp = false;
        r_rightUp_leftDown = false;
        l_leftUp_rightDown = false;
        l_rightDown_leftUp = false;
    
  

    }
    public void btnGoBack_Click()
    {
        SceneManager.LoadScene("2mb");
    }
    public void r_side_amp_check()
    {
        if(!its_right)
        {
            its_right = true;
            left_amp.interactable = false;
            right_amp.interactable = false;
            UnityEngine.Debug.Log("r_amp_pressed");


        }
        
    }
    public void l_side_amp_check()
    {
        if (!its_left)
        {
            its_left = true;
            left_amp.interactable = false;
            right_amp.interactable = false;
            UnityEngine.Debug.Log("le_amp_pressed");
        }

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

    void Update()
    {


        weightStep1 = MoBBoServer.W_player2_ap;
        weightStep2 = MoBBoServer.W_player1_ap;
        copX_step1 = MoBBoServer.COP_BottomBoard.x;
        copX_step2 = MoBBoServer.COP_TopBoard.x;
        totalBodyWeight = weightStep1 + weightStep2;
        UnityEngine.Debug.Log($"weightStep1: {weightStep1}, weightStep2: {weightStep2}, totalBodyWeight: {totalBodyWeight}, copX_step1: {copX_step1}, copX_step2: {copX_step2}");

        if (isTrialActive)
        {
            remainingTime = Mathf.Max(0, trialDuration - (Time.time - trialStartTime));
            UpdateTimerDisplay(remainingTime);

            if (remainingTime <= 0)
            {
                EndTrial();

            }
            else
            {
                if(its_right && !its_left) 
                {
                    r_setpsLogic();
                }
                if (its_left && !its_right)
                {
                    l_setpsLogic();
                }


            }
        }
    }

    void CreateCSVFile()
    {
        // Create the CSV file with headers
        using (StreamWriter writer = new StreamWriter(csvFilePath))
        {
            writer.WriteLine("Trial,Right Foot Up,Left Foot Up,Right Foot Down,Left Foot Down,Trial Duration");
        }
    }

    void WriteToCSV(int trial, int rightFootUp, int leftFootUp, int rightFootDown, int leftFootDown, float duration)
    {
        // Append a row of trial data to the CSV file
        using (StreamWriter writer = new StreamWriter(csvFilePath, true))
        {
            writer.WriteLine($"{trial},{rightFootUp},{leftFootUp},{rightFootDown},{leftFootDown},{duration:F2}");
        }
    }

    void OnStartButtonPressed()
    {
        if (isTrialActive)
        {
            EndTrial();
        }
        else
        {
            StartNewTrial();
        }
    }

    void StartNewTrial()
    {
        trialCount++;
        isTrialActive = true;
        trialStartTime = Time.time;
        remainingTime = trialDuration; // Reset the timer
        rightFootUpImage.SetActive(false);
        leftFootUpImage.SetActive(false);
        leftFootDownImage.SetActive(true);
        rightFootDownImage.SetActive(true);

        bothfootstep1_flag = false;
        bothfootstep2_flag = false;
        r_leftDown_rightUp = false;
        r_rightUp_leftDown = false;
        l_leftUp_rightDown = false;
        l_rightDown_leftUp = false;


        Image childImage_1 = leftFootDownImage.GetComponentInChildren<Image>();
        Image childImage_2 = rightFootDownImage.GetComponentInChildren<Image>();
        childImage_1.color = new Color(0f, 1f, 0f);
        childImage_2.color = new Color(0f, 1f, 0f);
        // Reset counts for the new trial

        rightFootUpCount = 0;
        leftFootUpCount = 0;
        rightFootDownCount = 0;
        leftFootDownCount = 0;

        resultText.text = ""; // Clear previous trial results
        timerText.text = trialDuration.ToString("F2"); // Initialize timer display

        string logFilePath = login_handlr.stepper_rawdata + "//" + player_id + DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss") + $"Trial_{trialCount}";
        //UnityEngine.Debug.Log(logFilePath+"filepath"+trialCount);
        if (!string.IsNullOrEmpty(logFilePath))
        {
            StartLoggingProcess(logFilePath, trialCount);
        }
    }

    void EndTrial()
    {
        isTrialActive = false;
        its_left= false; its_right= false;
        left_amp.interactable = true;
        right_amp.interactable = true;
        StopLoggingProcess();
        if (bgm != null && bgm.isPlaying)
        {
          bgm.Stop();
        }

        // Calculate trial duration
        float actualDuration = trialDuration - remainingTime;

        // Write trial data to CSV
        WriteToCSV(trialCount, rightFootUpCount, leftFootUpCount, rightFootDownCount, leftFootDownCount, actualDuration);

        // Display results
        resultText.text = $"Trial {trialCount} completed.\nDuration: {actualDuration:F2} seconds\n" +
                          $"Right Foot Up: {rightFootUpCount}\nLeft Foot Up: {leftFootUpCount}\n" +
                          $"Right Foot Down: {rightFootUpCount}\nLeft Foot Down: {leftFootUpCount}";

        UnityEngine.Debug.Log($"Trial {trialCount} saved to {csvFilePath}");
    }

    void UpdateTimerDisplay(float timeLeft)
    {
        timerText.text = timeLeft.ToString("F2"); // Update the timer text
    }


    void r_setpsLogic()
    {
        if (bgm != null && !bgm.isPlaying)
        {
           bgm.Play(); // Start playing audio
        }
        UnityEngine.Debug.Log("into the r_loop");
        //if trail starts initially leftdown and right dowwn image shown in redcolor which is placed on the board,then rightup will shown in green color
        if (weightStep1 >= totalBodyWeight && !bothfootstep1_flag && copX_step1 > 20.5 && copX_step1 < 40)
        {
            UnityEngine.Debug.Log("loop1");
            Image childImage_1 = leftFootDownImage.GetComponentInChildren<Image>();
            Image childImage_2 = rightFootDownImage.GetComponentInChildren<Image>();
            Image childImage_3 = rightFootUpImage.GetComponentInChildren<Image>();
            //Image childImage_4 = leftFootUpImage.GetComponentInChildren<Image>();
            childImage_1.color = new Color(1f, 0f, 0f);
            childImage_2.color = new Color(1f, 0f, 0f);
      
            leftFootUpImage.SetActive(false);                                                               //leftFootUpImage.SetActive(false);
        
            rightFootUpImage.SetActive(true);
            childImage_3.color = new Color(0f, 1f, 0f);
            leftFootDownCount++;
            bothfootstep1_flag = true;
            audioSource.PlayOneShot(audioClip);
            UnityEngine.Debug.Log("fullweight in bord");
        }
            // if rightfootup placed on the bord this will run then leftup image will shown
        if ( !(weightStep1 < 2) && copX_step1 < 30f && copX_step2 > 30f && !r_rightUp_leftDown && bothfootstep1_flag )
        {
            UnityEngine.Debug.Log("loop2");
            Image childImage_1 = leftFootUpImage.GetComponentInChildren<Image>();
            Image childImage_2 = rightFootUpImage.GetComponentInChildren<Image>();
            rightFootDownImage.SetActive(false);
            leftFootUpImage.SetActive(true);
            childImage_1.color = new Color(0f, 1f, 0f, 1f);
            childImage_2.color = new Color(1f, 0f, 0f);
            rightFootUpCount++;          
            rightup.text = rightFootUpCount.ToString();
            r_rightUp_leftDown = true;
            //cycle = true;
            audioSource.PlayOneShot(audioClip);

        }
        //both leftup and rightup  placed on the bord, then it will show the image for right down to move the foot down
        if (weightStep2 >= totalBodyWeight && !bothfootstep2_flag && (copX_step2>20.5 && copX_step2<40) && r_rightUp_leftDown && weightStep1 <2)
        {
            UnityEngine.Debug.Log("loop3");
       
            Image childImage_2 = leftFootDownImage.GetComponentInChildren<Image>();
            Image childImage_1 = leftFootUpImage.GetComponentInChildren<Image>();
     
            leftFootDownImage.SetActive(true);
      
            rightFootDownImage.SetActive(false);
            childImage_1.color = new Color(1f, 0f, 0f);
            childImage_2.color = new Color(0f, 1f, 0f);
 
          
            leftFootUpCount++;
            leftup.text = leftFootUpCount.ToString();
            bothfootstep2_flag = true;
            audioSource.PlayOneShot(audioClip);


        }
        // if right down placed then it show for left down image to move the foot
        if (!(weightStep2 < 2) && copX_step1 > 5f && copX_step1 < 30f && copX_step2 > 30f && !r_leftDown_rightUp && bothfootstep2_flag)
        {
            UnityEngine.Debug.Log("loop4");
            Image childImage_1 = leftFootDownImage.GetComponentInChildren<Image>();
            Image childImage_2 = rightFootDownImage.GetComponentInChildren<Image>();
       
            leftFootUpImage.SetActive(false);
  
            rightFootDownImage.SetActive(true);
            childImage_1.color = new Color(1f, 0f, 0f);
            childImage_2.color = new Color(0f, 1f, 0f);
         
            
            rightFootDownCount++;
            r_leftDown_rightUp = true;    //true
            //cycle = false;
            audioSource.PlayOneShot(audioClip);

        }

        if (bothfootstep1_flag && bothfootstep2_flag && r_rightUp_leftDown && r_leftDown_rightUp)
        {
            bothfootstep1_flag = false; //false
            bothfootstep2_flag = false;  //false
            r_rightUp_leftDown = false;   //false
            r_leftDown_rightUp = false;
            //cycle = false;    //false

        }




    }


    void l_setpsLogic()
    {
        if (bgm != null && !bgm.isPlaying)
        {
            bgm.Play(); // Start playing audio
        }
        UnityEngine.Debug.Log("into the l_loop");
        //if trail starts initially leftdown and right dowwn image shown in redcolor which is placed on the board,then rightup will shown in green color
        if (weightStep1 >= totalBodyWeight && !bothfootstep1_flag && copX_step1 > 20.5 && copX_step1 < 40)
        {
            UnityEngine.Debug.Log("loop1");
            Image childImage_1 = leftFootDownImage.GetComponentInChildren<Image>();
            Image childImage_2 = rightFootDownImage.GetComponentInChildren<Image>();
            Image childImage_3 = leftFootUpImage.GetComponentInChildren<Image>();

            childImage_1.color = new Color(1f, 0f, 0f);
            childImage_2.color = new Color(1f, 0f, 0f);

            rightFootUpImage.SetActive(false);                                                               //leftFootUpImage.SetActive(false);

            leftFootUpImage.SetActive(true);
            childImage_3.color = new Color(0f, 1f, 0f);
            leftFootDownCount++;
            bothfootstep1_flag = true;
            audioSource.PlayOneShot(audioClip);
            UnityEngine.Debug.Log("fullweight in board");
        }
        // if leftfootup placed on the bord this will run then rightup image will shown
        if (!(weightStep1 < 2) && !(weightStep2 < 2) && copX_step2 < 30f && copX_step1 > 30f && !l_leftUp_rightDown && bothfootstep1_flag)
        {
            UnityEngine.Debug.Log("loop2");
            Image childImage_1 = rightFootUpImage.GetComponentInChildren<Image>();
            Image childImage_2 = leftFootUpImage.GetComponentInChildren<Image>();

            childImage_1.color = new Color(0f, 1f, 0f);

            leftFootDownImage.SetActive(false);


            rightFootUpImage.SetActive(true);
            childImage_2.color = new Color(1f, 0f, 0f);
            leftFootUpCount++;

            leftup.text = leftFootUpCount.ToString();
            l_leftUp_rightDown = true;
            audioSource.PlayOneShot(audioClip);

        }
        //both leftup and rightup  placed on the bord, then it will show the image for right down to move the foot down
        if (weightStep2 >= totalBodyWeight && !bothfootstep2_flag && (copX_step2 > 20.5 && copX_step2 < 40)&& l_leftUp_rightDown && weightStep1<2)
        {
            UnityEngine.Debug.Log("loop3");

            Image childImage_2 = rightFootDownImage.GetComponentInChildren<Image>();
            Image childImage_1 = rightFootUpImage.GetComponentInChildren<Image>();

            rightFootDownImage.SetActive(true);

            leftFootDownImage.SetActive(false);
            childImage_1.color = new Color(1f, 0f, 0f);
            childImage_2.color = new Color(0f, 1f, 0f);


            rightFootUpCount++;
            rightup.text = rightFootUpCount.ToString();
            bothfootstep2_flag = true;
            audioSource.PlayOneShot(audioClip);


        }
        // if right down placed then it show for left down image to move the foot
        if (!(weightStep2 < 2) && !(weightStep1 < 2) && copX_step1 > 30f && copX_step2 < 33f && copX_step2 >5f && !l_rightDown_leftUp && bothfootstep2_flag)
        {
            UnityEngine.Debug.Log("loop4");
            Image childImage_1 = leftFootDownImage.GetComponentInChildren<Image>();
            Image childImage_2 = rightFootDownImage.GetComponentInChildren<Image>();

            rightFootUpImage.SetActive(false);

            leftFootDownImage.SetActive(true);
            childImage_1.color = new Color(0f, 1f, 0f);
            childImage_2.color = new Color(1f, 0f, 0f);


            rightFootDownCount++;
            l_rightDown_leftUp = true;    //true

            audioSource.PlayOneShot(audioClip);

        }

        if (bothfootstep1_flag && bothfootstep2_flag && l_leftUp_rightDown && l_rightDown_leftUp)
        {
            bothfootstep1_flag = false; //false
            bothfootstep2_flag = false;  //false
            l_leftUp_rightDown = false;   //false
            l_rightDown_leftUp = false;

        }


    }

        //}

        // Coroutine to fade out an image
        IEnumerator FadeOutImage(Image image, GameObject gameobject, float duration = 1.0f)
    {
        float startAlpha = image.color.a; // Current alpha value
        float elapsed = 0f;

        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            float newAlpha = Mathf.Lerp(startAlpha, 0f, elapsed / duration);
            image.color = new Color(image.color.r, image.color.g, image.color.b, newAlpha);
            yield return null; // Wait for the next frame
        }

        image.color = new Color(image.color.r, image.color.g, image.color.b, 0f); // Fully transparent
        gameobject.SetActive(false); // Optional: disable the object
    }
    IEnumerator DelayedSetActive(GameObject gameObject, bool isActive, float delay)
    {
        yield return new WaitForSeconds(delay); // Wait for the specified delay
        gameObject.SetActive(isActive); // Set active state after delay
    }

    // Coroutine to fade in an image
    IEnumerator FadeInImage(Image image, GameObject gameobject, float duration = 1.0f)
    {
        gameobject.SetActive(true); // Ensure the object is active
        float startAlpha = image.color.a; // Current alpha value (should be 0)
        float elapsed = 0f;

        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            float newAlpha = Mathf.Lerp(startAlpha, 1f, elapsed / duration);
            image.color = new Color(image.color.r, image.color.g, image.color.b, newAlpha);
            yield return null; // Wait for the next frame
        }

        image.color = new Color(image.color.r, image.color.g, image.color.b, 1f); // Fully opaque
    }
 

}




