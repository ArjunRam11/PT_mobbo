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

public class BirdScript : MonoBehaviour
{
    public Rigidbody2D player;
    public float flapStrength;
    public HeartSystem heartSystem; // Reference to HeartSystem
    public bool birdIsAlive = true;
    public LogicScript increase;

    private string gameDataFilePath;
    private string rawDataFilePath;
    public Button strt_saving_raw;
    private float left_limit;
    private float right_limit;
    private float top_limit, min_gcop_y_ml; // for ap shifitng
    private float bottom_limit;// for ap shifitng
    private const float FootLength = 15f;
    private string csvFilePath_ml; // Update this to the correct path in your project.
    // Start is called before the first frame update
    public int score = 0;
    public Text score_text;
    int windowSize = 10; // Adjust the number of past values used for smoothing
    Queue<float> copYHistory = new Queue<float>();
    public PipeSpawnScript pipeSpawner;
    void Start()
    {

        // Find the HeartSystem component by tag
        GameObject heartSystemObject = GameObject.FindGameObjectWithTag("HeartSystem");

        if (heartSystemObject != null)
        {
            heartSystem = heartSystemObject.GetComponent<HeartSystem>();
        }
        else
        {
            UnityEngine.Debug.LogError("HeartSystem object not found in the scene. Make sure it has the correct tag.");
        }
            List<string> variablesToRead = new List<string>
        {
            "min_gcop_x","min_gcop_y", "max_gcop_x", "max_gcop_y"
        };
            csvFilePath_ml = System.IO.Path.Combine(login_handlr.assess_folder, "min_max_dist_ml.csv");

            // Fetch data from the CSV
            CsvAssesReader csvReader = new CsvAssesReader();
            List<Dictionary<string, string>> csvData = csvReader.ReadVariables(csvFilePath_ml, variablesToRead);

            // Log the data to ensure it is loaded
            if (csvData.Count > 0)
            {
                // Assuming you need the first row's values
                if (csvData[0].TryGetValue("min_gcop_x", out string minGcopXString) &&
                    csvData[0].TryGetValue("max_gcop_x", out string maxGcopXString) &&
                    csvData[0].TryGetValue("min_gcop_y", out string minGcopYString))
                {
                    // Parse the strings to float
                    if (float.TryParse(minGcopXString, out float minGcopX) &&
                        float.TryParse(maxGcopXString, out float maxGcopX) &&
                        float.TryParse(minGcopYString, out float minGcopY))
                    {
                        left_limit = minGcopX;
                        right_limit = maxGcopX;
                        min_gcop_y_ml = minGcopY;


                        UnityEngine.Debug.Log($"Left Limit (min_gcop_x): {left_limit}");
                        UnityEngine.Debug.Log($"Right Limit (max_gcop_x): {right_limit}");
                       
                    }
                    else
                    {
                        UnityEngine.Debug.LogError("Failed to parse min_gcop_x or max_gcop_x to float.");
                    }
                }
                else
                {
                    UnityEngine.Debug.LogError("min_gcop_x or max_gcop_x not found in the CSV data.");
                }
            }
            else
            {
                UnityEngine.Debug.LogError("No data found in the CSV file.");
            }


            // Set up the file paths
            string assessFolder = login_handlr.Floppybird_gamedata;
            gameDataFilePath = Path.Combine(assessFolder, "Floppybird_gamedata.csv");

            //string rawdataFolder = login_handlr.Floppybird_rawdata;
            //rawDataFilePath = Path.Combine(rawdataFolder, "Floppybird_rawdata.csv");

            // Create the game data file and write the header if not already created
            if (!File.Exists(gameDataFilePath))
            {
                using (StreamWriter writer = new StreamWriter(gameDataFilePath, true))
                {
                    writer.WriteLine("Time,X,Y,Z");
                }
            }

            // Create the raw data file and write the header if not already created
            //if (!File.Exists(rawDataFilePath))
            //{
            //    using (StreamWriter writer = new StreamWriter(rawDataFilePath, true))
            //    {
            //        writer.WriteLine("Time,COP_X,COP_Y");
            //    }
            //}

            // Start logging the raw data
            //rawdata_start_saving();
        
    }
    // Update is called once per frame
    //void Update()
    //{
    //    float gamemax = 4.3f;
    //    float gamemin = -4.3f;
    //    score_text.text = score.ToString();


    //    top_limit = min_gcop_y_ml + (FootLength / 2);    // Top limit 12.5 cm above ap using ml assess

    //    bottom_limit = min_gcop_y_ml - (FootLength / 2); // Bottom limit 12.5 cm below
    //    UnityEngine.Debug.Log($"y_position of game: {min_gcop_y_ml}");
    //    UnityEngine.Debug.Log($"top: {top_limit}");
    //    UnityEngine.Debug.Log($"bottom: {bottom_limit}");


    //    float cop_x = MoBBoServer.COP.x;
    //    float cop_y = MoBBoServer.COP.y;
    //    UnityEngine.Debug.Log($"cop_x: {cop_x}");
    //    UnityEngine.Debug.Log($"cop_y: {cop_y}");



    //    float boardcop_x = (gamemax - gamemin) / (right_limit - left_limit) * (cop_x - left_limit) + gamemin; // for meidolateral games


    //    float board_scaled_cop_y = (gamemax - gamemin) / (top_limit - bottom_limit) * (cop_y - bottom_limit) + gamemin; // for the ap uusing the same


    //    UnityEngine.Debug.Log($"board sclaed_y: {board_scaled_cop_y}");

    //    float clamped_board_scaled_cop_y = Mathf.Clamp(board_scaled_cop_y, gamemin, gamemax);

    //    transform.position = new Vector3(0, (clamped_board_scaled_cop_y), 0);
    //    transform.position = Vector3.Lerp(transform.position, new Vector3(0, clamped_board_scaled_cop_y, 0), Time.deltaTime * 5);




    //    if (Input.GetKey(KeyCode.B))
    //    {
    //        SceneManager.LoadScene("2mb");
    //        //rawdata_stop_saving();
    //    }






    //    // Stop saving raw data when a certain key is pressed and change scene

    //    //rawdata_start_saving();


    //    // Store the game position data
    //    StorePosition(transform.position);

    //    // Store the raw data (COP values)
    //    //StoreRawData(cop_x, MoBBoServer.COP.y);
    //}
    void Update()
    {
        float gamemax = 4.3f;
        float gamemin = -4.3f;
        score_text.text = score.ToString();

        top_limit = min_gcop_y_ml + (FootLength / 2);
        bottom_limit = min_gcop_y_ml ;

        float cop_y = MoBBoServer.COP.y;

        // Store the last `windowSize` values in the queue
        copYHistory.Enqueue(cop_y);
        if (copYHistory.Count > windowSize)
        {
            copYHistory.Dequeue();
        }

        // Compute the moving average
        float avg_cop_y = 0;
        foreach (float y in copYHistory)
        {
            avg_cop_y += y;
        }
        avg_cop_y /= copYHistory.Count;

        // Scale the smoothed COP to game limits
        float board_scaled_cop_y = Mathf.Clamp(
            (gamemax - gamemin) / (top_limit - bottom_limit) * (avg_cop_y - bottom_limit) + gamemin,
            gamemin, gamemax
        );

        // Apply the smoothed position
        transform.position = new Vector3(0, board_scaled_cop_y, 0);

        // Debugging info
        UnityEngine.Debug.Log($"COP Y: {cop_y}, Smoothed Avg Y: {avg_cop_y}, Scaled Y: {board_scaled_cop_y}");

        // Store the position
        StorePosition(transform.position);
    }





    private void StorePosition(Vector3 position)
    {
        string positionData = Time.time + "," + position.x + "," + position.y + "," + position.z + "\n";
        File.AppendAllText(gameDataFilePath, positionData);
    }
   public void btnGoBack_Click()
   {
            SceneManager.LoadScene("2mb");
   }
    public void save_raw_data_btn()
        {
            rawdata_start_saving();

        }

    public void stop_saving_raw_data()
        {
            rawdata_stop_saving();
        }



    public void rawdata_start_saving()
        {
            // Create the folder name using the current date and time
            string test_scene_data_folder = login_handlr.Floppybird_rawdata + "//" + DateTime.Now.ToString("yyyy-MM-dd_THH-mm-ss");

            // Log the folder creation
            ;// UnityEngine.Debug.Log("Started saving raw data at: " + test_scene_data_folder);

            // Start logging the raw data to the specified folder
            MoBBoServer.server.StartLogging(test_scene_data_folder);
            UnityEngine.Debug.Log("Started saving raw data at: " + test_scene_data_folder);
        }


    public void rawdata_stop_saving()
        {
            if (MoBBoServer.server.isLogging)
            {
                UnityEngine.Debug.Log("Stopped logging");
                MoBBoServer.server.StopLogging();
            }
        }

    private void OnCollisionEnter2D(Collision2D collision)
    {
        if (heartSystem != null)
        {
            //heartSystem.LoseLife(); // Deduct a life when hitting something

            if (heartSystem.currentLives > 0)
            {
                birdIsAlive = true; // Allow bird to continue flying
            }
            else
            {
                birdIsAlive = false; // Bird cannot fly if no lives are left
            }
        }
        else
        {
            UnityEngine.Debug.LogError("HeartSystem is not assigned.");
        }

        // Add the score if the bird collides with the middle pipe
        if (collision.gameObject.CompareTag("Middle") && pipeSpawner.isTrialActive)
        {
           // UnityEngine.Debug.LogError("HeartSystem is not assigned.");
            score++;
        }
        else if (collision.gameObject.CompareTag("TopPipe") || collision.gameObject.CompareTag("BottomPipe"))
        {
            heartSystem.LoseLife();
        }
    }
    
}
