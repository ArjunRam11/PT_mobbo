using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
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
using UnityEngine.SceneManagement;
using System.Net.NetworkInformation;
using UnityEditor;
//using UnityEditor.AnimatedValues;

public class script : MonoBehaviour
{
    public GameObject pingball;
    public GameObject resett,start_game_scene;
    public Rigidbody pgb;
    public float Timer = 0f;
     public Button easy_button, moderate_button  ;
    public int score_int_p1 = 0;
    public int score_int_p2 = 0;
    public Text Interval_text;
    public Text player1_score;
    public Text player2_score;
    public static bool score_inc_p1 = false;
    public static bool score_inc_p2 = false;

    public static bool stop_players = false;
   
    public Text gameover;

    public static bool hitball_right_p1 = false;
    public static bool hitball_centre_p1 = false;
    public static bool hitball_left_p1 = false;
    public static bool hitball_right_p2 = false;
    public static bool hitball_centre_p2 = false;
    public static bool hitball_left_p2 = false;
    public float ball_p1_diff;
    public float ball_p2_diff;
    public float paddleSpeed = 100f;
    public  Text repetition_count;
    public int count = 1;

   
    public static bool stopwatch = false;
    public static bool reset_clck = false;
    public float timer__;
    public Text won;
    public GameObject player_2;
    public Transform comp_player,ping_balltransform;
    public static bool reset = false;
    public Text trial_number;
    public Transform bound_right;
    public Transform bound_left;
    public Text reset_timer;
    public float reset_time;
    public Renderer Br_Renderer;
    public Renderer Bl_Renderer;
    public Material onhit_boundary_material; public Material exist_boundary_material;
    public Renderer lowerboundary_colorchanger, upperboundary_colorchanger;
    public GameObject bound1; 
    public GameObject bound2;
    public Transform player;
    public string  game_time,ball_pos_x, ball_pos_y, player_paddle_x, player_paddle_y, comp_paddle_x, comp_paddle_y;
    public List<string> game_data=new List<string> ();
    public bool is_header_written=false;

    public bool game_started = false;
    private List<GameObject> gameObjects = new List<GameObject>();
    public float ballSpeed = 1f ; // Default speed value
    public float easySpeed = 0.25f;  // Speed when Easy button is pressed
    public float moderateSpeed = 3f; // Speed when Moderate button is pressed
    private Coroutine assess_loggingCoroutine;
    public Text timerText, statusText;
    public Button start_stop_logging;
    public static string player_id;
    private int trialCount = 0;
    public int gamelevel = 0;
    public Text leveltext;
    public float newPaddleWidth;
    public float moderatepaddle_w = 15f;
    public float easypaddle_w = 60f;
    public AudioSource audioSource;

    //AudioSource audio_;


    // Start is called before the first frame update
    void Start()
    {
        gameObjects.Clear();
        timer__ = 3f;
        reset_time = 7f;

        Directory.CreateDirectory(login_handlr.pingpong_rawdata);
        Directory.CreateDirectory(login_handlr.pingpong_gamedata);
     

        pgb = pingball.GetComponent<Rigidbody>();

     

        pingball.GetComponent<Transform>().position = new Vector3(-67.1f, 0f, 0); 
        resett.SetActive(false);
        player_2.GetComponent<Transform>().position = new Vector3(-67.1f, 25.3f, 0);

        player = GameObject.FindGameObjectWithTag("player1").transform;
        comp_player= GameObject.FindGameObjectWithTag("player2").transform;
        ping_balltransform = GameObject.FindGameObjectWithTag("target").transform;
        

    
        bound1 = GameObject.FindGameObjectWithTag("y_left");
        bound2 = GameObject.FindGameObjectWithTag("y_right");
        Bl_Renderer = bound1.GetComponent<Renderer>();
        Br_Renderer = bound2.GetComponent<Renderer>();
        




    }
   


    public void move_paddle()
    {
        
        float currSpeed = Mathf.Clamp(paddleSpeed - (timer__ / 90 * paddleSpeed * 0.3f), 0.6f * paddleSpeed, paddleSpeed);
        currSpeed = 20;
       

        //checking x direction of the ball
        if (pgb.velocity.y > 0)
        {

            //checking y direction of ball
            if (pgb.position.x < player_2.transform.position.x - .3F)
            {
                //move ball down if lower than paddle
                player_2.transform.Translate(Vector3.left * currSpeed * Time.deltaTime);
            }
            else if (pgb.position.x > player_2.transform.position.x + .3F)
            {
                //move ball up if higher than paddle
                player_2.transform.Translate(Vector3.right * currSpeed * Time.deltaTime);
            }

        }

        ////set bounds of enemy
        if (player_2.transform.position.x > 13)
        {
            player_2.transform.position = new Vector3(transform.position.x, 13, 0);
        }
        else if (player_2.transform.position.y < -13)
        {
            player_2.transform.position = new Vector3(transform.position.x, -13, 0);
        }
    }
    
    public void startgame()
    {
        float rand = UnityEngine.Random.Range(0f, 2f);
        float y_vel_1 = UnityEngine.Random.Range(5f, 10f);
        float y_vel_2 = UnityEngine.Random.Range(-5f, -10f);
        // float x_vel = Random.Range(-f,5f);
        stopwatch = true;

        //Debug.Log(rand);
       // if (start_game.GetComponentInChildren<Text>().text == "START")
        {

            if (rand <= 1)
            {
                pgb.velocity = new Vector3(1f, y_vel_1, 0) * ballSpeed;
            }
            if (rand <= 2 && rand > 1)
            {
                pgb.velocity = new Vector3(-1f, y_vel_2, 0) * ballSpeed;
            }
        }
        game_started = true;


    }
    private void OnTriggerEnter(Collider collision)
    {
        float x_ball = pingball.GetComponent<Transform>().position.x;

        if (collision.gameObject.tag == "player1")
        {
            float x1 = collision.gameObject.transform.position.x;
            ball_p1_diff = x1 - x_ball;
            pgb.velocity = new Vector3(-ball_p1_diff*2f, 20f, 0) * ballSpeed;


        }
        if (collision.gameObject.tag == "player2")
        {
            float x2 = collision.gameObject.transform.position.x;
            ball_p2_diff = x2 - x_ball;
            pgb.velocity = new Vector3(-ball_p2_diff*2f, -20f, 0) * ballSpeed;
            //Debug.Log("trigg at left");
        }

        if (collision.gameObject.tag == "x_up")
        {

            var bound_up = collision.GetComponent<MeshRenderer>().material;
            bound_up.SetColor("_color", UnityEngine.Color.white);
            score_inc_p1 = true;
            reset = true;
            reset_clck = true;
            score_update();
            //boundary_colorchanger.material = onhit_boundary_material;
            resett.SetActive(true);

            stop_players = true;

           // DSCORE1.text = score_int_p1.ToString();
            stopwatch = true;
        }

        if (collision.gameObject.tag == "x_down")
        {
           UnityEngine. Debug.Log("trigg at right");
            var bound_down = collision.GetComponent<MeshRenderer>().material;
            bound_down.SetColor("_color", UnityEngine.Color.white);
            score_inc_p2 = true;
            lowerboundary_colorchanger.material = onhit_boundary_material;
            reset = true;
            reset_clck = true;
            score_update();
            resett.SetActive(true);
            stop_players = true;
            //DSCORE2.text = score_int_p2.ToString();
            stopwatch = true;
        }
        if (collision.gameObject.tag == "y_left")
        {
            Bl_Renderer.material.color = UnityEngine.Color.green;
        }
        if (collision.gameObject.tag == "y_right")
        {
            Br_Renderer.material.color = UnityEngine.Color.green;
        }
    }

    public void score_update()
    {
        if (score_inc_p1)
        {
            UnityEngine.Debug.Log("PLAYER_1" + score_inc_p1);
            score_int_p1 += 1;
            score_inc_p1 = false;
            player1_score.text = score_int_p1.ToString();   

        }
        if (score_inc_p2)
        {
            UnityEngine.Debug.Log("PLAYER_2" + score_inc_p2);
            score_int_p2 += 1;
            score_inc_p2 = false;
            player2_score.text = score_int_p2.ToString();
            //health_1.fillAmount = Mathf.Lerp(0, 100, Time.deltaTime);
        }

        gameover_();
    }
    public void gameover_()
    {
        if (score_int_p1 == 5f)
        {
            won.text = " YOU WIN ";

        }
        if (score_int_p2 == 5f)
        {
            won.text = "COMPUTER WIN ";
        }

        if (score_int_p1 == 5f || score_int_p2 == 5f)
        {
            gameover.text = "GAMEOVER";
            stop_players = true;
        }
    }
    public void start_afterrestart()
    {
        resett.SetActive(false);
        pgb.position = new Vector3(-58.4f, -7.3f, 0);
        lowerboundary_colorchanger.material = exist_boundary_material;
        float rand = UnityEngine.Random.Range(0f, 2f);
        float y_vel_1 = UnityEngine.Random.Range(5f, 10f);
        float y_vel_2 = UnityEngine.Random.Range(-5f, -10f);
        // float x_vel = Random.Range(-f,5f);
        stopwatch = true;

    
        {

            if (rand <= 1)
            {
                pgb.velocity = new Vector3(1f, y_vel_1, 0);
            }
            if (rand <= 2 && rand > 1)
            {
                pgb.velocity = new Vector3(-1f, y_vel_2, 0);
            }
        }

    }
    //public void start_resetpage()
    //{
    //    if (timer__ == 0f)
    //    {

    //          //resett.SetActive(true);
        

            
    //    }
    //}
    public void repetition_counter()
    {
        if (reset)
        {

            count += 1;
            reset = false;
            //trial_number.text = count.ToString();

        }
    }

    public void game_data_strbldr()
    {
        
        game_time =DateTime.UtcNow.ToString("yy-MM-dd-HH-mm-ss");
        Vector2 position_of_ball = pingball.transform.position;
        Vector2 postion_of_player=player.transform.position;
        Vector2 position_of_computer=comp_player.transform.position;
        string ball_x = position_of_ball.x.ToString();string ball_y = position_of_ball.y.ToString(); // x and y postion from the vector component of all gameobjects
        string original_player_x = postion_of_player.x.ToString(); string original_player_y = postion_of_player.y.ToString();
        string comp_paddle_x=position_of_computer.x.ToString();string comp_paddle_y=position_of_computer.y.ToString();
        string gamelevel_= gamelevel.ToString();

        string all_data = game_time + "," + ball_x + "," + ball_y + "," + original_player_x + "," + original_player_y + "," + comp_paddle_x + "," + comp_paddle_y+","+ gamelevel_;

        game_data.Add(all_data);

    }
  


    public void assess_btnStrtStpLogging_Click()
    {
        if (MoBBoServer.server.isLogging)
        {
            StopLoggingProcess(); // Stop the logging if it's already running
            UnityEngine.Debug.Log("Stopped logging");

        }
        else
        {
            // Increment the trial count for the new trial
            trialCount++;
            UnityEngine.Debug.Log("trail_nnumber"+trialCount);

            trial_number.text = trialCount.ToString();
           

    
            // Start the game trial coroutine
            StartCoroutine(GameTrialCoroutine(login_handlr.trial_duration)); // Set the trial duration (e.g., 10 seconds)
        }
    }


    
    private void StartLoggingProcess(string filePath, int trial)
    {
       
        MoBBoServer.server.StartLogging_p(filePath,trial);
        UnityEngine.Debug.Log($"Logging started: {filePath}");

        // Update UI to indicate logging status
        statusText.text = "Logging On";
        statusText.color = UnityEngine.Color.green;
    }

    // Stop the logging process
    private void StopLoggingProcess()
    {
        
        MoBBoServer.server.StopLogging();
        UnityEngine.Debug.Log("Logging stopped");

        // Update UI to indicate logging status
        statusText.text = "Logging Off";
        statusText.color = UnityEngine.Color.blue;
    }
    

    private IEnumerator GameTrialCoroutine(float duration)
    {
        float remainingTime = duration;
        bool collisionOccurred = false;

        // Start logging raw data for the current trial
        string fileName = $"Trial_{trialCount}_Data_{DateTime.Now:yyyy-MM-dd_HH-mm-ss}.csv";    
        string trialFilePath = Path.Combine(login_handlr.pingpong_gamedata, fileName);

        if (audioSource != null && !audioSource.isPlaying)
        {
            audioSource.Play(); // Start playing audio
        }

        string test_scene_data_folder = login_handlr.pingpong_rawdata + "//" + player_id + DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss") + $"Trial_{trialCount}";
        StartLoggingProcess(test_scene_data_folder,trialCount);

        // Reset game state for the trial
        start_afterrestart();
        reset = false;
        reset_clck = false;
        stopwatch = true;

        while (remainingTime > 0)
        {
            // Update the timer display
            timerText.text = $"{Mathf.CeilToInt(remainingTime)}";
            timerText.color = remainingTime <= 2 ? UnityEngine.Color.red : UnityEngine.Color.white;

            // Collect raw game data during each frame
            game_data_strbldr();

            // Check if a collision occurred (x_up or x_down)
            if (reset_clck)
            {
                collisionOccurred = true;

                // Stop the ball's movement and place it at the center
                pgb.velocity = Vector3.zero;
                pgb.position = new Vector3(-67.1f, 0f, 0);

                // Update the score and trial count
                score_update();
                repetition_counter();

                // Save game data for the current trial
                SaveGameDataWithTrial(trialCount, trialFilePath);

                break; // Exit the trial loop
            }

            // Wait for the next frame and decrement the timer
            yield return new WaitForSeconds(1f);
            remainingTime--;
        }

        // Handle case where the timer ends without a collision
        if (!collisionOccurred)
        {
            // Stop the ball's movement and place it at the center
            pgb.velocity = Vector3.zero;
            pgb.position = new Vector3(-67.1f, 0f, 0);

            // Update the trial count and score
            repetition_counter();
            score_update();

            // Save game data for the current trial
            SaveGameDataWithTrial(trialCount, trialFilePath);
        }

        // Stop logging for the current trial
        StopLoggingProcess();
        if (audioSource != null && audioSource.isPlaying)
        {
            audioSource.Stop();
        }

        // Wait for the button press to start the next trial
        yield return new WaitUntil(() => MoBBoServer.server.isLogging);

        // Reset the game for the next trial
        start_afterrestart();
    }


    // Function to save game data with trial number in the file name
    private void SaveGameDataWithTrial(int trialNumber, string filePath)
    {
        UnityEngine.Debug.Log($"Saving game data to: {filePath}");

        // Write game data to the specified file
        using (StreamWriter writer = new StreamWriter(filePath))
        {
            if (!is_header_written)
            {
                writer.WriteLine("Time,ball_x,ball_y,player_paddle_x,player_paddle_y,comp_paddle_x,comp_paddle_y,Gamelevel");
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



    private void StartGameForTrial()
    {
        resett.SetActive(false); // Hide reset UI
        pgb.position = new Vector3(-58.4f, -7.3f, 0); // Reset ball position
        reset_clck = false;
        lowerboundary_colorchanger.material = exist_boundary_material;

        // Start ball movement
        float rand = UnityEngine.Random.Range(0f, 2f);
        float y_vel_1 = UnityEngine.Random.Range(5f, 10f);
        float y_vel_2 = UnityEngine.Random.Range(-5f, -10f);

        if (rand <= 1)
        {
            pgb.velocity = new Vector3(1f, y_vel_1, 0);
        }
        else
        {
            pgb.velocity = new Vector3(-1f, y_vel_2, 0);
        }
    }



   
    public void _go_home()
    {
        SceneManager.LoadScene("2mb");
    }


    void Update()

    {
           game_data_strbldr();

      

        if (stopwatch)
        {

            timer__ -= Time.deltaTime;
            //TIMER.text = timer__.ToString();

            if (timer__ <= 0f)
            {
                stopwatch = false;
                timer__ = 20f;
                //TIMER.text = "00";
                //start_resetpage();
            }
        }


        if (Input.GetKey(KeyCode.Return))
        {
            //startgame();        // to start the ball moving
            //start_game_scene.SetActive(false);
            //SetObjectsActive(true);

        }  
     
        if (Input.GetKey(KeyCode.Space))
        {
            UnityEngine.Debug.Log("Space");
            start_afterrestart();
                     
        }
        if (Input.GetKey(KeyCode.B))
        {
            SceneManager.LoadScene("2mb");
            //UnityEngine.Debug.Log("home");
           
        }
     
        if (reset_clck) // clck for the reset page
        {
            reset_time -= Time.deltaTime;
            reset_timer.text = (Math.Round(reset_time,0)).ToString();
            if (reset_time <= 0f)
            {
                reset_clck = false;
                reset_time = 7f;
                reset_timer.text = "00";
                //start_trial();
            }
        }
        move_paddle();
        repetition_counter();
        if (Input.GetKeyDown(KeyCode.UpArrow))
        {
            IncrementLevel();
        }
        if (Input.GetKeyDown(KeyCode.DownArrow))
        {
            DecrementLevel();
        }
    }

    private float GetPaddleWidth()
    {
        RectTransform playerRectTransform = GameObject.FindGameObjectWithTag("player1").GetComponent<RectTransform>();
        return playerRectTransform.localScale.x; // Returns the current width of the paddle
    }

    private void SetBallForce(float ballspeed)
    {
        ballSpeed = ballspeed;   // Update ball speed if needed elsewhere
                                 // Update spawn rate dynamically
    }
    private void SetPaddleWidth(float newWidth)
    {
        // Get the RectTransform component attached to the GameObject
        RectTransform playerRectTransform = GameObject.FindGameObjectWithTag("player1").GetComponent<RectTransform>();

        // Modify the sizeDelta to set the new width
        Vector3 currentSize = playerRectTransform.localScale;

        // Update the width while keeping the current height the same
        playerRectTransform.localScale = new Vector3(newWidth, currentSize.y,currentSize.z);

    }
    private void IncrementLevel()
    {
        // Increment ball speed and decrease paddle size
        if (gamelevel < 10) // Cap level at 10
        {
            UnityEngine.Debug.Log($"Increased Level: Game Level = {gamelevel}, Ball Speed = {ballSpeed}, Paddle Width = {newPaddleWidth}");
            ballSpeed = Mathf.Clamp(ballSpeed + 0.275f, easySpeed, moderateSpeed);
            newPaddleWidth = Mathf.Clamp(GetPaddleWidth() - 4.5f, moderatepaddle_w, easypaddle_w);
            SetPaddleWidth(newPaddleWidth);

            gamelevel++; // Increment game level
            UpdateLevelText(); // Update UI
            //Debug.Log($"Increased Level: Game Level = {gameLevel}, Ball Speed = {ballSpeed}, Paddle Width = {newPaddleWidth}");
        }
        else
        {
            //Debug.Log("Reached maximum level.");
        }
    }

    private void DecrementLevel()
    {
        // Decrement ball speed and increase paddle size
        if (gamelevel > 0) // Minimum level is 0
        {
            ballSpeed = Mathf.Clamp(ballSpeed - 0.275f, easySpeed, moderateSpeed);
            newPaddleWidth = Mathf.Clamp(GetPaddleWidth() + 4.5f, moderatepaddle_w, easypaddle_w);
            SetPaddleWidth(newPaddleWidth);
            gamelevel--; // Decrement game level
            UpdateLevelText(); // Update UI
            //Debug.Log($"Decreased Level: Game Level = {gameLevel}, Ball Speed = {ballSpeed}, Paddle Width = {newPaddleWidth}");
        }
        else
        {
            // Debug.Log("Reached minimum level.");
        }
    }
    private void UpdateLevelText()
    {
        if (leveltext != null)
        {
            leveltext.text = $"Level: {gamelevel}";
        }
        else
        {
            //  Debug.LogError("Level Text UI element is not assigned in the Inspector.");
        }
    }
}
