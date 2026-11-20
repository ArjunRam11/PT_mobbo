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
using TMPro;


public class PipeSpawnScript : MonoBehaviour
{
    public GameObject pipe, bird_object; // Pipe prefab
    public GameObject optionscene;
    private GameObject previousPipe;
    public float spawnRate; // Initial spawn rate (in seconds)
    private float timer = 0f;
    public float heightOffset = 0.5f; // Offset for vertical pipe positioning

    private float trialDuration; // Trial duration in seconds
    private float remainingTime;
    private float trialStartTime;

     public  bool isTrialActive = false; // Tracks if a trial is active

    public int gamelevel = 0; // Current game level
    public float minSpawnRate = 1f; // Minimum spawn rate (higher difficulty)
    public float maxSpawnRate = 5f; // Maximum spawn rate (lower difficulty)

    public Text leveltext; // UI text for level
    public Text timertext; // UI text for timer
    public int Trialcount = 0;
    public Text Trailcounter_txt;
    public static string player_id;
    public HeartSystem heart_variable;
    public BirdScript bird;
    public List<string> game_data = new List<string>();
    public bool is_header_written = false;
    public float p_moveSpeed = 2f; // Initial pipe movement speed
    private float deadZone = -20f; // Position where pipes will be destroyed
    public float p_movespeed_max = 9.5f;
    public float p_movespeed_min = 2f;
    public AudioSource audioSource;
    private float lastSpawnX;
    private bool isFirstSpawn = true; // Track first spawn
    private float minPipeSpacing = 10f;
    float baseSpacing = 5f;  // Adjust as needed
    private float width_offset = 4f;
    public bool IsGameOver = false;







    //Start is called before the first frame update
    void Start()
    {
        trialDuration = login_handlr.trial_duration;
        Directory.CreateDirectory(login_handlr.Floppybird_rawdata);
        Directory.CreateDirectory(login_handlr.Floppybird_gamedata);

        if (timertext != null)
        {
            timertext.text = trialDuration.ToString("F2"); // Initialize timer display
        }

        if (leveltext != null)
        {
            leveltext.text = $"Level: {gamelevel}"; // Initialize level display
        }
      

        bird_object = GameObject.FindGameObjectWithTag("bird");
        spawnRate = maxSpawnRate;


    }

    //Update is called once per frame
    void Update()
    {
        if (isTrialActive)
        {
            //Update remaining trial time
            remainingTime = Mathf.Max(0, trialDuration - (Time.time - trialStartTime));
            UpdateTimerDisplay(remainingTime);

            //End trial if time is up
            if (remainingTime <= 0)
                {
                    StopTrial();
                }
            flappy_game_data_strbldr();
        }

       // Handle level adjustment inputs
        if (Input.GetKeyDown(KeyCode.UpArrow))
        {
            IncrementLevel();
        }
        if (Input.GetKeyDown(KeyCode.DownArrow))
        {
            DecrementLevel();
        }

    }
    void DestroyAllPipes()
    {
        GameObject[] pipes = GameObject.FindGameObjectsWithTag("Pipe");
        foreach (GameObject pipe in pipes)
        {
            Destroy(pipe);
        }
    }

    private void SaveGameDataWithTrial(int trialNumber, string filePath)
    {
        UnityEngine.Debug.Log($"Saving game data to: {filePath}");

        //Write game data to the specified file
        using (StreamWriter writer = new StreamWriter(filePath))
        {
            if (!is_header_written)
            {
                writer.WriteLine("Time,bird_x,bird_y,Gamelevel, pipe_spawnrate,pipespeed,heightOffsetpipe,score");
                is_header_written = true;
            }
            foreach (string dataLine in game_data)
            {
                writer.WriteLine(dataLine);
            }
        }

        //Clear game data for the next trial

       game_data.Clear();
    }
    public void flappy_game_data_strbldr()
    {

        string game_time = DateTime.UtcNow.ToString("yy-MM-dd-HH-mm-ss");
        Vector2 position_of_bird = bird_object.transform.position;
        string ball_x = position_of_bird.x.ToString(); string ball_y = position_of_bird.y.ToString(); // x and y postion from the vector component of all gameobjects
        string gamelevel_ = gamelevel.ToString();
        string sprate_ = spawnRate.ToString();
        string movespeed = p_moveSpeed.ToString();
        string height = heightOffset.ToString();
        string score = bird.score.ToString();

        string all_data = game_time + "," + ball_x + "," + ball_y + "," + gamelevel_ + "," + sprate_ + "," + movespeed + "," + height + "," + score;

        game_data.Add(all_data);

    }
    public void gameOver()
    {


        optionscene.SetActive(true);
        isTrialActive = false;

        IsGameOver = true;
        deadZone = 30f;




        //  Save trial data to CSV

    }
    public void play_again()
    {

        optionscene.SetActive(false);

    }


    private void IncrementLevel()
    {


        //Increment spawn rate and decrease height offset
        if (gamelevel < 10) // Maximum level cap
        {
            //Decrease spawn rate gradually(e.g., from 5s to 1s)
            spawnRate = Mathf.Clamp(spawnRate - 0.5f, minSpawnRate, maxSpawnRate);
            //spawnRate = Mathf.Clamp(2f - 0.15f * gamelevel, 0.8f, 2f);

            //Adjust height offset
            //heightOffset = Mathf.Clamp(heightOffset + 0.1f, 1.2f, 2.2f); // Reduce height range

            //Increase pipe speed gradually(e.g., from 2 to 10)
            p_moveSpeed = Mathf.Clamp(2f + 0.5f * gamelevel, p_movespeed_min, p_movespeed_max);
        

            gamelevel++; // Increment level
            UpdateLevelText(); // Update level UI
        }
    }

    private void DecrementLevel()
    {
        //Decrease spawn rate and increase height offset
        if (gamelevel > 0) // Minimum level cap
        {
            // Increase spawn rate gradually(e.g., from 1.5s to 5s)
            spawnRate = Mathf.Clamp(spawnRate + 0.5f, minSpawnRate, 5f);

            //Adjust height offset
            //heightOffset = Mathf.Clamp(heightOffset - 0.1f, 1.2f, 2.2f); // Increase height range 

            //Decrease pipe speed gradually(e.g., from 10 to 2)   
            p_moveSpeed = Mathf.Clamp(2f + 0.75f * (gamelevel - 1), p_movespeed_min, p_movespeed_max);

            gamelevel--; // Decrement level
            UpdateLevelText(); // Update level UI
        }
    }


    private void UpdateLevelText()
    {
        if (leveltext != null)
        {
            leveltext.text = $"Level: {gamelevel}";
        }
    }


    //private void spawnPipe()
    //{
    //float lowestPoint = pipe.transform.position.x + heightOffset;
    //float highestPoint = 4f;
    //    previousPipe = newPipe;
    //    // Spawn the pipe at a random vertical position
    //    GameObject newPipe = Instantiate(pipe,
    //        new Vector3(previousPipe.transform.position.x+5f,pipe.transform.position.y, 0),
    //        transform.rotation);

    //    UnityEngine.Debug.Log(previousPipe.transform.position.x);
    //    //Pass the current move speed to the spawned pipe
    //   PipeMove pipeMove = newPipe.GetComponent<PipeMove>();
    //    if (pipeMove != null)
    //    {
    //        pipeMove.Initialize(p_moveSpeed, deadZone);
    //    }
    //}


    private void spawnPipe()
    {

        float lowestPoint = pipe.transform.position.x - heightOffset;
        float highestPoint =pipe.transform.position.x + heightOffset;

        GameObject newPipe = Instantiate(pipe,
            new Vector3(previousPipe==null?pipe.transform.position.x: previousPipe.transform.position.x+20f, UnityEngine.Random.Range(lowestPoint,highestPoint)   , 0),
            transform.rotation);

        previousPipe = newPipe;
        //Debug.Log("Spawned pipe at X: " + previousPipe.transform.position.x);

        PipeMove pipeMove = newPipe.GetComponent<PipeMove>();
        if (pipeMove != null)
        {
            pipeMove.Initialize(p_moveSpeed, deadZone);
        }
        else
        {
            //Debug.LogError("PipeMove script is missing on the pipe prefab!");
        }
    }


    public void StartTrial()
    {
        isTrialActive = true;
        heart_variable.currentLives = 5;
        heart_variable.UpdateHeartUI();
        trialStartTime = Time.time; // Record trial start time
        isFirstSpawn = true;
        IsGameOver = false;
        deadZone = -30f;

        bird.score = 0;
        Trialcount++;
        Trailcounter_txt.text = Trialcount.ToString();
        StartCoroutine(SpawnPipeRoutine());


        string logFilePath = login_handlr.Floppybird_rawdata + "//" + player_id + DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss") + $"Trial_{Trialcount}";
        UnityEngine.Debug.Log(logFilePath + "filepath" + Trialcount);
        if (!string.IsNullOrEmpty(logFilePath))
        {
            StartLoggingProcess(logFilePath, Trialcount);
        }
    }

    private IEnumerator SpawnPipeRoutine()
    {
        while (isTrialActive)
        {
            if (audioSource != null && !audioSource.isPlaying)
            {
                audioSource.Play(); // Start playing audio
            }
            if (isFirstSpawn)
            {
                width_offset = 0;
                spawnPipe();
                isFirstSpawn = false;
              
                
            }
            else if(!isFirstSpawn)
            {
                yield return new WaitForSeconds(spawnRate); // Wait for the spawn rate duration }
                spawnPipe(); // Spawn a pipe
              

            }
        }
    }

    public void StopTrial()
    {
        isTrialActive = false;
        gameOver();
        StopCoroutine(SpawnPipeRoutine());
        if (audioSource != null && audioSource.isPlaying)
        {
            audioSource.Stop();
        }
        StopLoggingProcess();// Stop pipe spawning
        string fname = $"Trial_{Trialcount}_Data_{DateTime.Now:yyyy-MM-dd_HH-mm-ss}.csv";
        string gameDataFilePath = Path.Combine(login_handlr.Floppybird_gamedata, fname);
        SaveGameDataWithTrial(Trialcount, gameDataFilePath);
    }

    private void UpdateTimerDisplay(float timeLeft)
    {
        if (timertext != null)
        {
            timertext.text = timeLeft.ToString("F2"); // Update timer UI
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
}



