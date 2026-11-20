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

public class TestScene_handler : MonoBehaviour
{
    //Using Scene handler
    public Button btnStartSession;
    public Button btnGoBack;
    public Text txtBoxIndivDevData;
    // public GameObject target;
    static public float tar_x_pos;
    static public float tar_y_pos;
    static public float tar_z_pos;
    static public float tar_x_pos_;
    static public float tar_y_pos_;
    static public float tar_x_pos__;
    static public float tar_y_pos__;
    // COP and position of board_boundaries
    //public List<GameObject> boards;
    //public float W, w0, w1, w2;
    //public GameObject COP;

    // Data logging folder.
    // string dataDir = "data";
    // MoBBo UDP Server
    bool _updateDevList = false;

    // Streaming toggle.
    private bool stream = false;

    // Display toggle
    private bool indivDisp = false;
    private string csvFileName;
    // MoBBo grid
    private List<int[]> _currGridOpts;
    public GameObject combCOP;
    private GameObject[,] indivCOP;
    public GameObject[,] target_object;

    //private MoBBoGrid mGrid;
    private List<GameObject> colSep;
    private List<LineRenderer> colLR;
    private List<GameObject> rowSep;
    private List<LineRenderer> rowLR;
    public bool change_tar_x, isheaderwritten = false;
    public bool change_tar_y = false;
    Vector3 _p1, _p2, _p4, _p3;
    public GameObject boundary_1;
    Vector3 p1, p2, p3, p4;
    Vector3 t1, t2, t3, t4;
    public GameObject boundary_2;
    public GameObject boundary_3;
    public GameObject boundary_4;
    public GameObject centre_point;
    public Button start_stop_logging;
    public UnityEngine.UI. Image left_W;
    public UnityEngine.UI.Image right_W;
    public Text L_percentage;
    public Text R_percentage;
    public Text r_wt;
    public Text l_wt;
    public InputField textboxfilename;
    public Text info_pane;
    public bool assess_timer = false;
    public float timer;
    public Text timetext;
    public  float min_cop_x,min_cop_y,max_cop_x,max_cop_y, max_cop_x_str, max_cop_y_str, min_cop_x_str, min_cop_y_str;
    public Button get_asses_val_ml,get_asses_val_ap, test_button_;
    private int dispcnt = 0;
    public Text left_x_val,bottom_y_val, right_x_val, top_y_val;
    public Button assess_button;


    public Text timerText, statusText,trial_text;


    public static string save_path;
    public static string player_id;
    public List<string> min_assessvalue_list,max_assessvalue_list,combined_list_assess = new List<string>();
    public static string min_x,min_y,max_y, max_x,min_gcop_x,min_gcop_y,max_gcop_x,max_gcop_y,min_l_x,min_l_y,min_r_x,min_r_y,min_l_per,
        min_r_per,max_l_x,max_l_y,max_r_x,max_r_y,max_l_per,max_r_per, l_W,r_w, min_ind_cop_x,min_ind_cop_y,max_ind_cop_x,max_ind_cop_y,min_b_per,min_t_per,max_t_per,max_b_per,b_w,t_w ;
 
    public string min_assess_data,max_assess_data;
    private int assess_elements;
    private bool got_min,got_max,got_bottom,got_top=false;
    public bool isheaderwritten_bs, file_written = false;
    public List<string> board_number = new List<string>();
    public static string setup_folder, board_setup_folder;
    private Coroutine assess_loggingCoroutine;
    public int trialcount = 0;
    





    void Start()
    {
       

        setup_folder = login_handlr.boardset_up_folder;
        player_id = login_handlr.session_starter_name;
        PlayerPrefs.DeleteAll();
        // Check if session is none. Then use default dummy patient sesson.
        if (AppData_WIFI.session == null)
        {
            AppData_WIFI.StartDummySession();
        }
        // Register call back functions.
        btnStartSession.GetComponent<Button>().onClick.AddListener(btnStartSession_Click);
        btnGoBack.GetComponent<Button>().onClick.AddListener(btnGoBack_Click);

        // Refresh grid text display
        AppData_WIFI.mGrid.UpdateTextMesh_fat(AppConfig_WIFI.GridOriginTestScn, AppConfig_WIFI.boardWidthTestScn,
                                     AppConfig_WIFI.boardHeightTestScn, UnityEngine.Color.black);

        writrecsvfor_boardsetting();
        // Intiailize line renders
        combCOP = new GameObject();

        combCOP.AddComponent<LineRenderer>();
        combCOP.AddComponent<BoxCollider2D>();
        //combCOP.AddComponent<Rigidbody2D>();
        //Rigidbody2D rd = combCOP.GetComponent<Rigidbody2D>();
        BoxCollider2D cr = combCOP.GetComponent<BoxCollider2D>();
        LineRenderer _lr = combCOP.GetComponent<LineRenderer>();

        _lr.material = new Material(Shader.Find("Sprites/Default"));
        _lr.startColor = UnityEngine.Color.black;
        _lr.endColor = UnityEngine.Color.black;
        _lr.startWidth = 1f;
        _lr.positionCount = 5;
        _lr.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero });
        //rd.bodyType = kinematic;
        //rd.simulated=true ;
        cr.isTrigger = true;



        //target_object = new GameObject();
        //target_object.AddComponent<LineRenderer>();
        //LineRenderer _lrt = target_object.GetComponent<LineRenderer>();
        //_lrt.material = new Material(Shader.Find("Sprites/Default"));
        //_lrt.startColor = UnityEngine.Color.red;
        //_lrt.endColor = UnityEngine.Color.red;
        //_lrt.startWidth = 0.5f;
        //_lrt.positionCount = 5;
        //_lr.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero });


        // target_object = new GameObject
        indivCOP = new GameObject[AppData_WIFI.mGrid.height, AppData_WIFI.mGrid.width];
        for (int i = 0; i < AppData_WIFI.mGrid.height; i++)
        {
            for (int j = 0; j < AppData_WIFI.mGrid.width; j++)
            {
                indivCOP[i, j] = new GameObject();
                indivCOP[i, j].AddComponent<LineRenderer>();
                _lr = indivCOP[i, j].GetComponent<LineRenderer>();
                _lr.material = new Material(Shader.Find("Sprites/Default"));
                _lr.startColor = UnityEngine.Color.black;
                _lr.endColor = UnityEngine.Color.black;
                _lr.startWidth = 0.2f;
                _lr.positionCount = 5;
                _lr.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero });
            }
        }
        //target_object = new GameObject[AppData.mGrid.height, AppData.mGrid.width];
        //for (int l = 0; l < AppData.mGrid.height; l++)
        //{
        //    for (int k = 0; k < AppData.mGrid.width; k++)
        //    {
        //        target_object[l, k] = new GameObject();
        //        target_object[l, k].AddComponent<LineRenderer>();
        //        _lr = target_object[l, k].GetComponent<LineRenderer>();
        //        _lr.material = new Material(Shader.Find("Sprites/Default"));
        //        _lr.startColor = UnityEngine.Color.white;
        //        _lr.endColor = UnityEngine.Color.white;
        //        _lr.startWidth = 0.9f;
        //        _lr.positionCount = 5;
        //        _lr.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero });
        //    }
        //}



        // Start server and reset their times
        StartCoroutine(StartDevices());

        // Initialize dispaly stuff.
        //combCOP = new GameObject();
        //combCOP.AddComponent<LineRenderer>();

        // Intiailize line renders
        colSep = new List<GameObject>();
        colLR = new List<LineRenderer>();
        rowSep = new List<GameObject>();
        rowLR = new List<LineRenderer>();

        // Draow grid lines
        // Column lines
         DrawColumnLines();
       //DrawColumnLines_inverted();
        // Row lines
        DrawRowLines();
        //DrawRowLines_inverted();
        // DrawOuterGridLines();

        dispcnt = 0;
       
      

    }


    public void writrecsvfor_boardsetting()
    {
        // Values from MoBBoGrid for each set
        string board1_value = MoBBoGrid.set1_value; 
        string board2_value = MoBBoGrid.set2_value;
        string board3_value = MoBBoGrid.set3_value;

        // Initialize board values
        string board_value1 = string.Empty;
        string board_value2 = string.Empty;
        string board_value3 = string.Empty; // Default to "null" for the third board in the case of 2 boards

        // Assign board_value1
        if (board1_value == "1")
            board_value1 = "1";
        else if (board1_value == "2")
            board_value1 = "2";
        else if (board1_value == "3")
            board_value1 = "3";

        // Assign board_value2
        if (board2_value == "2")
            board_value2 = "2";
        else if (board2_value == "1")
            board_value2 = "1";
        else if (board2_value == "3")
            board_value2 = "3";

        // Assign board_value3 (only if there are 3 boards)
        if (!string.IsNullOrEmpty(board3_value))
        {
            if (board3_value == "3")
                board_value3 = "3";
            else if (board3_value == "2")
                board_value3 = "2";
            else if (board3_value == "1")
                board_value3 = "1";
        }

        // Add to the board setup list
        board_number.Add($"{board_value1},{board_value2},{board_value3}");

        // Write to the CSV file
        using (StreamWriter file = new StreamWriter(Path.Combine(setup_folder, "devicesetup.csv"), true))
        {
            if (!isheaderwritten_bs)
            {
                file.WriteLine("1 Board, 2 Board, 3 Board"); // CSV Header
                isheaderwritten_bs = true;
            }

            foreach (string line in board_number)
            {
                file.WriteLine(line);
            }
        }
    }


    IEnumerator StartDevices()
    {
        StartAllDevs();
        yield return new WaitForSeconds(1);
        ResetTime();
    }
    public void info_update()
    {
        if(timer>2f && timer<5f)
        {
            info_pane.text = " stand still and upright as you can";
        }
        if (timer > 7f && timer < 10f)
        {
            info_pane.text = " Lean on left side as much as you can";
        }
        if (timer > 12f && timer <17f)
        {
            info_pane.text = " Lean on right side as much as you can";
        }

    }
    public void write_assessfile()
    {
     save_path = login_handlr.assess_folder;
    }
    public void find_Min_max_ML_reach()
    {
        UnityEngine.Debug.Log($"weight_1@ ML {MoBBoServer.W_player1} and weight_2 {MoBBoServer.W_player2}");

        if (MoBBoServer.W_player1 > MoBBoServer.W_player2)
           
        {
            UnityEngine.Debug.Log($"weight_1 greater");

            if (MoBBoServer.COP.x < 55f)
            {
                min_cop_x = MoBBoServer.COP.x;
              
                left_x_val.text = min_cop_x.ToString();
                min_x = min_cop_x.ToString();
                min_l_per = ((MoBBoServer.W_player1 / MoBBoServer.W) * 100f).ToString();
                min_r_per = ((MoBBoServer.W_player2 / MoBBoServer.W) * 100f).ToString();
                min_gcop_x = MoBBoServer.COP.x.ToString();
                min_gcop_y = MoBBoServer.COP.y.ToString();
                l_W=MoBBoServer.W_player1.ToString();
                min_ind_cop_x = MoBBoServer.COP_player1.x.ToString();
                min_ind_cop_y = MoBBoServer.COP_player1.y.ToString();

                min_assess_data= min_x + "," + min_r_per + "," + min_l_per + "," + min_ind_cop_x +","+min_ind_cop_y+","+ min_gcop_x + "," + min_gcop_y+","+l_W;

                PlayerPrefs.SetFloat("left_limit", min_cop_x);
                got_min = true;
               
               // UnityEngine.Debug.Log("minimum value of cop in the left board:"+min_cop_x);
            }
        }
        if (MoBBoServer.W_player1 < MoBBoServer.W_player2)
        {
            UnityEngine.Debug.Log($"weight_2 greater");
            if (MoBBoServer.COP.x > 60f)
            {
                max_cop_x = MoBBoServer.COP.x;
                right_x_val.text = max_cop_x.ToString();
                max_x = max_cop_x.ToString();


                max_l_per = ((MoBBoServer.W_player1 / MoBBoServer.W) * 100f).ToString();
                max_r_per = ((MoBBoServer.W_player2 / MoBBoServer.W) * 100f).ToString();
                max_ind_cop_x = MoBBoServer.COP_player2.x.ToString();
                max_ind_cop_y = MoBBoServer.COP_player2.y.ToString();

                max_gcop_x = MoBBoServer.COP.x.ToString();
                max_gcop_y = MoBBoServer.COP.y.ToString();
                r_w=MoBBoServer.W_player2.ToString();
                max_assess_data = max_x + "," + max_r_per + "," + max_l_per + "," +max_ind_cop_x+","+max_ind_cop_y+","+ max_gcop_x + "," + max_gcop_y+","+r_w;
                PlayerPrefs.SetFloat("Right_limit", max_cop_x);
                got_max = true;
                // UnityEngine.Debug.Log("maximum value of cop in the right board:" + max_cop_x);
            }
        }
        

    }
    public void find_Min_max_AP_reach()
    {
        
        UnityEngine.Debug.Log($"weight_1 @ AP reach{MoBBoServer.W_player1_ap} and weight_2 {MoBBoServer.W_player2_ap}");


        if (MoBBoServer.W_player1_ap > MoBBoServer.W_player2_ap)
        {
            UnityEngine.Debug.Log($"cop_y_1{MoBBoServer.COP.y}");

            if (MoBBoServer.COP.y > -45f)
            {
                UnityEngine.Debug.Log("cop<45f bottom:");
                min_cop_y = MoBBoServer.COP.y;

                bottom_y_val.text = min_cop_y.ToString();
                min_y = min_cop_y.ToString();
                min_b_per = ((MoBBoServer.W_player1_ap / MoBBoServer.W) * 100f).ToString();
                min_t_per = ((MoBBoServer.W_player2_ap / MoBBoServer.W) * 100f).ToString();
                min_gcop_x = MoBBoServer.COP.x.ToString();
                min_gcop_y = MoBBoServer.COP.y.ToString();
                b_w = MoBBoServer.W_player1.ToString();
                min_ind_cop_x = MoBBoServer.COP_player1.x.ToString();
                min_ind_cop_y = MoBBoServer.COP_player1.y.ToString();

                min_assess_data = min_y + "," + min_b_per + "," + min_t_per + "," + min_ind_cop_x + "," + min_ind_cop_y + "," + min_gcop_x + "," + min_gcop_y + "," + b_w;

                PlayerPrefs.SetFloat("bottom_limit", min_cop_y);

                got_bottom = true;

                // UnityEngine.Debug.Log("minimum value of cop in the left board:"+min_cop_x);
            }
        }
        if (MoBBoServer.W_player1_ap < MoBBoServer.W_player2_ap)
        {
            UnityEngine.Debug.Log($"cop_y{MoBBoServer.COP.y}");
            if (MoBBoServer.COP.y < -45f)
            {
                UnityEngine.Debug.Log("cop>45f top:");

                max_cop_y = MoBBoServer.COP.y;
                top_y_val.text = max_cop_y.ToString();
                max_y = max_cop_y.ToString();


                max_b_per = ((MoBBoServer.W_player1_ap / MoBBoServer.W) * 100f).ToString();
                max_t_per = ((MoBBoServer.W_player2_ap / MoBBoServer.W) * 100f).ToString();
                max_ind_cop_x = MoBBoServer.COP_player2.x.ToString();
                max_ind_cop_y = MoBBoServer.COP_player2.y.ToString();

                max_gcop_x = MoBBoServer.COP.x.ToString();
                max_gcop_y = MoBBoServer.COP.y.ToString();
                t_w = MoBBoServer.W_player2_ap.ToString();
                max_assess_data = max_y + "," + max_b_per + "," + max_t_per + "," + max_ind_cop_x + "," + max_ind_cop_y + "," + max_gcop_x + "," + max_gcop_y + "," + t_w;
                PlayerPrefs.SetFloat("top_limit", max_cop_y);
                got_top = true;
                // UnityEngine.Debug.Log("maximum value of cop in the right board:" + max_cop_x);
            }
        }


    }

    public void button_min_max_ml()
    {
       

        if(get_asses_val_ml.GetComponentInChildren<Text>().text == "Assess_ml")
        {
            get_asses_val_ml.GetComponentInChildren<Text>().text = "right_x";  
            find_Min_max_ML_reach();



        }
        if(get_asses_val_ml.GetComponentInChildren<Text>().text=="right_x")
        {
            get_asses_val_ml.GetComponentInChildren<Text>().text = "Assess_ml";
            find_Min_max_ML_reach();

        }
        if (got_max && got_min)
        {
            write_csv_min_max_ml();
        }
    }
    public void button_min_max_ap()
    {
        UnityEngine.Debug.Log("not_inside_button");

        if (get_asses_val_ap.GetComponentInChildren<Text>().text == "get_ap")
        {
            UnityEngine.Debug.Log("inside_button");
            get_asses_val_ap.GetComponentInChildren<Text>().text = "next";
            find_Min_max_AP_reach();



        }
        if (get_asses_val_ap.GetComponentInChildren<Text>().text == "next")
        {
            get_asses_val_ap.GetComponentInChildren<Text>().text = "get_ap";
            find_Min_max_AP_reach();

        }
        if (got_bottom && got_top)
        {
            UnityEngine.Debug.Log("y bools true");
            write_csv_min_max_ap();
        }
    }



    public void write_csv_min_max_ml() 
    {
        
        combined_list_assess.Add(min_assess_data + "," + max_assess_data);

        UnityEngine.Debug.Log(combined_list_assess);

        using (StreamWriter file = new StreamWriter(Path.Combine(login_handlr.assess_folder, "min_max_dist_ml.csv"), true))
  
        {
            if (!isheaderwritten)
            {
                file.WriteLine("min_x,min_%,min_left%,min_cop_x,min_cop_y,min_gcop_x,min_gcop_y,left_weight, max_x,max_right%,max_left%,max_cop_x,max_cop_y,max_gcop_x,max_gcop_y,right_weight");
                isheaderwritten = true;    
            }
            foreach (string assessdata in combined_list_assess)
            {

                file.WriteLine(assessdata);

            }
            file.Close();
        }
    }
    public void write_csv_min_max_ap()
    {

        combined_list_assess.Add(min_assess_data + "," + max_assess_data);

        UnityEngine.Debug.Log(combined_list_assess);

        using (StreamWriter file = new StreamWriter(Path.Combine(login_handlr.assess_folder, "min_max_dist_ap.csv"), true))

        {
            if (!isheaderwritten)
            {
                
                file.WriteLine("min_y,min_bottom %,min_top %,min_cop_x,min_cop_y,min_gcop_x,min_gcop_y,b_weight, max_y,max_bottom %,max_top %,max_cop_x,max_cop_y,max_gcop_x,max_gcop_y,t_weight");
                isheaderwritten = true;
            }
            foreach (string assessdata in combined_list_assess)
            {

                file.WriteLine(assessdata);

            }
            file.Close();
        }
    }
    public void assess_btnStrtStpLogging_Click()
    {
        if (MoBBoServer.server.isLogging)
        {
            StopLoggingProcess();
        }
        else
        {
            StartLoggingProcess();
        }
    }

    private void StartLoggingProcess()
    {
        trialcount++;
        string test_scene_data_folder = login_handlr.assess_folder + "//" + player_id + DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
        UnityEngine.Debug.Log("Logging started: " + test_scene_data_folder);

        MoBBoServer.server.StartLogging_p(test_scene_data_folder,trialcount);
        start_stop_logging.GetComponentInChildren<Text>().text = "Stop Logging";
        statusText.text = "Assessment started...";  
        statusText.color = UnityEngine.Color.green;
        statusText.fontSize = 25;
        timerText.fontSize = 45;
        
        trial_text.text = trialcount.ToString();

        // Start coroutine for timed logging
        assess_loggingCoroutine = StartCoroutine(TimedLogging(login_handlr.trial_duration)); // 30 seconds
    }



    private void StopLoggingProcess()
    {
        if (assess_loggingCoroutine != null)
        {
            StopCoroutine(assess_loggingCoroutine);
            assess_loggingCoroutine = null;
        }

        UnityEngine.Debug.Log("Stopped logging");
        MoBBoServer.server.StopLogging();
        start_stop_logging.GetComponentInChildren<Text>().text = "Start assessment";
        timerText.text = "5";
        timerText.color = UnityEngine.Color.black;

        // Update the status text
        statusText.text = "Assessment data recorded.";
        statusText.color = UnityEngine.Color.blue;
        statusText.fontSize = 25;
    }

    private IEnumerator TimedLogging(float duration)
    {
        float remainingTime = duration;
     

        while (remainingTime > 0)
        {
            // Update the timer text
            timerText.text = $"{Mathf.CeilToInt(remainingTime)}";

            // Change color if less than 5 seconds
            if (remainingTime <= 5)
            {
                timerText.color = UnityEngine.Color.red; // Change to red
            }
            else
            {
                timerText.color = UnityEngine.Color.black; // Default color
            }

            // Wait for a second and decrement the timer
            yield return new WaitForSeconds(1f);
            remainingTime--;
        }

        // Stop logging when the timer ends
        StopLoggingProcess();
    }
    void Update()
    {
        // want to check wheter the scsne starst even the access timer is not active//
        //if (assess_timer)
        //{
        //    timer += Time.deltaTime;
        //    int timer_ = Mathf.RoundToInt(timer);
        //    timetext.text=timer_.ToString();
        //    info_update();
        //    if(timer>=20f)
        //    {
        //        assess_timer = false;
        //        //timer
        //    }

        //}
        //UnityEngine.Debug.Log(combCOP.transform.position.ToString());
        // Do something only when the server is running.
      
        if (MoBBoServer.started)
        {
            // Handle keyboard inputs.
            HandleKeyboardInputs();
        }

        // Update COP information.
        UpdateDeviceDataDisplay();
    

        // Update COP display on the boards.
        dispcnt++;
        dispcnt = dispcnt % 5;
        if (dispcnt == 0)
        {
            DisplayCOP();
        }
        int rows_ = AppData_WIFI.SelectedGridRows;
        int columns_ = AppData_WIFI.SelectedGridColumns;
        //UnityEngine.Debug.Log($"hello+{rows_},{columns_}");


        if (rows_ < columns_) 
        { 

            update_percentage_ml();
            UnityEngine.Debug.Log($"hello++++++{rows_},{columns_}");
        }
        if (rows_ > columns_) 
        { 
            update_percentage_ap();
            UnityEngine.Debug.Log($"hello::::::{rows_},{columns_}");
        }
        //UnityEngine.Debug.Log($"weight_1@ ML {MoBBoServer.W_player1} and weight_2 {MoBBoServer.W_player2}");

    }


    public void test_button()
    {
       // if(test_button_.GetComponentInChildren<Text>().text == "press")
        {
            UnityEngine.Debug.Log("pressed");
            test_button_.GetComponentInChildren<Text>().text = "DONE";
        }
    }
    public void btnStrtStpLogging_Click()
    {
        // Check logging status
        if (MoBBoServer.server.isLogging)
        {
            UnityEngine.Debug.Log("Stopped logging");
            MoBBoServer.server.StopLogging();
           start_stop_logging.GetComponentInChildren<Text>().text = "Start Logging";
           /* txtBoxFilename.enabled = true;
            txtBoxFilename.text = " ";
            // Enable annotation.
            toggleAnnotation.enabled = false;
            txtBoxAnnotation.enabled = false;
            txtBoxAnnotation.text = "";*/
        }
        else
        {
           // string _fname = AppData_WIFI.subjd.SetupFileDir +
                           /// $"\\setup_{player_id}_" +
                           // DateTime.Now.ToString("Dyyyy-MM-dd_THH-mm-ss");
          //  UnityEngine.Debug.Log(_fname);
            string test_scene_data_folder=login_handlr.assess_folder +"//"+player_id +DateTime.Now.ToString("Dyyyy-MM-dd_THH-mm-ss");
            UnityEngine.Debug.Log(test_scene_data_folder);
            MoBBoServer.server.StartLogging(test_scene_data_folder);
            start_stop_logging.GetComponentInChildren<Text>().text = "Stop Logging";
           // txtBoxFilename.enabled = false;
            // Enable annotation.
           // toggleAnnotation.enabled = true;
            //txtBoxAnnotation.enabled = true;
        }
    }
    private void update_percentage_ml()
    {

     
        float Ri_percentage = (MoBBoServer.W_player2 / MoBBoServer.W)*100f ;
         float Le_percentage = (MoBBoServer.W_player1 / MoBBoServer.W)*100f ;

        if (MoBBoServer.W_player1 > 2f || MoBBoServer.W_player2 > 2f)
        {
            left_W.GetComponent<RectTransform>().localScale = new Vector3(1f, (Le_percentage/100f), 1f);
            right_W.GetComponent<RectTransform>().localScale = new Vector3(1f, (Ri_percentage/100f), 1f);
            r_wt.text = (Math.Round(MoBBoServer.W_player1,0).ToString());
            l_wt.text = (Math.Round(MoBBoServer.W_player2,0).ToString());
            R_percentage.text = (Math.Round(Ri_percentage,0).ToString());
            L_percentage.text = (Math.Round(Le_percentage, 0).ToString());

        }
        else
        {
            left_W.GetComponent<RectTransform>().localScale = new Vector3(1f, 0f, 1f);
            right_W.GetComponent<RectTransform>().localScale = new Vector3(1f, 0f, 1f);

            r_wt.text = " ";
            l_wt.text = " ";
            L_percentage.text = " ";
            R_percentage.text = " ";
          
        }
    }
    private void update_percentage_ap()
    {


        float top_percentage = (MoBBoServer.W_player2_ap / MoBBoServer.W) * 100f;
        float bot_percentage = (MoBBoServer.W_player1_ap / MoBBoServer.W) * 100f;

        if (MoBBoServer.W_player1_ap > 2f || MoBBoServer.W_player2_ap > 2f)
        {
            left_W.GetComponent<RectTransform>().localScale = new Vector3(1f, (bot_percentage / 100f), 1f);
            right_W.GetComponent<RectTransform>().localScale = new Vector3(1f, (top_percentage / 100f), 1f);
            r_wt.text = (Math.Round(MoBBoServer.W_player1_ap, 0).ToString());
            l_wt.text = (Math.Round(MoBBoServer.W_player2_ap, 0).ToString());
            R_percentage.text = (Math.Round(top_percentage, 0).ToString());
            L_percentage.text = (Math.Round(bot_percentage, 0).ToString());

        }
        else
        {
            left_W.GetComponent<RectTransform>().localScale = new Vector3(1f, 0f, 1f);
            right_W.GetComponent<RectTransform>().localScale = new Vector3(1f, 0f, 1f);

            r_wt.text = " ";
            l_wt.text = " ";
            L_percentage.text = " ";
            R_percentage.text = " ";

        }
    }

    private void DisplayCOP()
    {
        if (MoBBoServer.W > 0)
        {
            //UnityEngine.Debug.Log("wieght"+MoBBoServer.W);

            if (indivDisp)
            {
                for (int i = 0; i < AppData_WIFI.mGrid.height; i++)
                {
                    for (int j = 0; j < AppData_WIFI.mGrid.width; j++)
                    {
                        if (MoBBoServer.server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F > 1.0f)
                        {
                            // Show individual line renderer.
                            ShowIndividualCOPLR(i, j);
                        }
                        else
                        {
                            ClearIndividualCOPLR(i, j);
                        }
                    }
                }
            }
            if (MoBBoServer.W == 0)
            {
                ClearCombinedCOPLR();
            }
            else
            {
                ShowCombinedCOPLR();
            }
        }
    }

    private void ClearIndividualCOPLR(int i, int j)
    {
        LineRenderer _lr = indivCOP[i, j].GetComponent<LineRenderer>();
        _lr.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero });
    }

    private void ClearCombinedCOPLR()
    {
        LineRenderer _lr = combCOP.GetComponent<LineRenderer>();
        _lr.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero });
    }

    private void draw_confidence_area()
    {
        var resolution = 50; //resolution of ellipse
        var a = MoBBoServer.COP.x;
        var b = MoBBoServer.COP.y;
        var rotation = Quaternion.Euler(45, 0, 0); //set your angles here
        for (var i = 0f; i < 2 * Mathf.PI; i += 2 * Mathf.PI / resolution)
        {
            var vector = new Vector3(a * Mathf.Cos(i), 0, b * Mathf.Sin(i));
            vector = rotation * vector; // you can multiply vector by quaternion to get tilted ellipse

            //you can do something with vector here

        }
    }
    private void DrawRowLines()
    {

        Vector3 _p1, _p2;
        ClearRowSep();
        for (int i = 0; i <= AppData_WIFI.mGrid.height; i++)
        {

            GameObject tempGO = new GameObject();
            tempGO.AddComponent<LineRenderer>();
            rowSep.Add(tempGO);
            rowLR.Add(tempGO.GetComponent<LineRenderer>());
            rowLR[rowLR.Count - 1].material = new Material(Shader.Find("Sprites/Default"));
            rowLR[rowLR.Count - 1].startColor = UnityEngine.Color.black;
            rowLR[rowLR.Count - 1].endColor = UnityEngine.Color.black;
            rowLR[rowLR.Count - 1].startWidth = 0.25f;
            rowLR[rowLR.Count - 1].positionCount = 2;
            // Update position.
            _p1 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(0, -AppConfig_WIFI.boardHeightTestScn, 0));
            _p2 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(0, -AppConfig_WIFI.boardHeightTestScn, 0)) +
                  AppData_WIFI.mGrid.width * (new Vector3(AppConfig_WIFI.boardWidthTestScn, 0, 0));
            rowLR[rowLR.Count - 1].SetPositions(new Vector3[] { _p1, _p2 });
        }
    }
    private void DrawRowLines_inverted()
    {

        Vector3 _p1, _p2;
        ClearRowSep();
        for (int i = 0; i <= AppData_WIFI.mGrid.width; i++)
        {

            GameObject tempGO = new GameObject();
            tempGO.AddComponent<LineRenderer>();
            rowSep.Add(tempGO);
            rowLR.Add(tempGO.GetComponent<LineRenderer>());
            rowLR[rowLR.Count - 1].material = new Material(Shader.Find("Sprites/Default"));
            rowLR[rowLR.Count - 1].startColor = UnityEngine.Color.black;
            rowLR[rowLR.Count - 1].endColor = UnityEngine.Color.black;
            rowLR[rowLR.Count - 1].startWidth = 0.25f;
            rowLR[rowLR.Count - 1].positionCount = 2;
            // Update position.
            _p1 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(0, -AppConfig_WIFI.boardWidthTestScn, 0));
            _p2 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(0, -AppConfig_WIFI.boardWidthTestScn, 0)) +
                 AppData_WIFI.mGrid.height * (new Vector3(AppConfig_WIFI.boardHeightTestScn, 0, 0));
            rowLR[rowLR.Count - 1].SetPositions(new Vector3[] { _p1, _p2 });
        }
    }
    private void DrawColumnLines()
    {
        Vector3 _p1, _p2;
        ClearColSep();
        for (int i = 0; i <= AppData_WIFI.mGrid.width; i++)
        {
            GameObject tempGO = new GameObject();
            tempGO.AddComponent<LineRenderer>();
            colSep.Add(tempGO);
            colLR.Add(tempGO.GetComponent<LineRenderer>());
            colLR[colLR.Count - 1].material = new Material(Shader.Find("Sprites/Default"));
            colLR[colLR.Count - 1].startColor = UnityEngine.Color.black;
            colLR[colLR.Count - 1].endColor = UnityEngine.Color.black;
            colLR[colLR.Count - 1].startWidth = 0.25f;
            colLR[colLR.Count - 1].positionCount = 2;
            // Update position.
            _p1 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(AppConfig_WIFI.boardWidthTestScn, 0, 0));
            _p2 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(AppConfig_WIFI.boardWidthTestScn, 0, 0)) +
                 AppData_WIFI.mGrid.height * (new Vector3(0, -AppConfig_WIFI.boardHeightTestScn, 0));
            colLR[colLR.Count - 1].SetPositions(new Vector3[] { _p1, _p2 });
        }
    }
    private void DrawColumnLines_inverted()
    {
        Vector3 _p1, _p2;
        ClearColSep();
        for (int i = 0; i <= AppData_WIFI.mGrid.height; i++)
        {
            GameObject tempGO = new GameObject();
            tempGO.AddComponent<LineRenderer>();
            colSep.Add(tempGO);
            colLR.Add(tempGO.GetComponent<LineRenderer>());
            colLR[colLR.Count - 1].material = new Material(Shader.Find("Sprites/Default"));
            colLR[colLR.Count - 1].startColor = UnityEngine.Color.black;
            colLR[colLR.Count - 1].endColor = UnityEngine.Color.black;
            colLR[colLR.Count - 1].startWidth = 0.25f;
            colLR[colLR.Count - 1].positionCount = 2;

            // Update position.
            _p1 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(AppConfig_WIFI.boardHeightTestScn, 0, 0));
            _p2 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(AppConfig_WIFI.boardHeightTestScn, 0, 0)) + AppData_WIFI.mGrid.width * (new Vector3(0, -AppConfig_WIFI.boardWidthTestScn, 0));
            colLR[colLR.Count - 1].SetPositions(new Vector3[] { _p1, _p2 });
        }
    }
    private void ShowCombinedCOPLR()

    {

        // First clear the current set of points in the LR.
        Vector3 _p1, _p2, _p3, _p4;

        //*******here i interchenged the values for x and y because i flipped the board in the real world******//

        float _x = MoBBoServer.COP.x* (AppConfig_WIFI.boardWidthTestScn) / (AppConfig_WIFI.realBoardWidth);
        float _y = MoBBoServer.COP.y * (AppConfig_WIFI.boardHeightTestScn) / (AppConfig_WIFI.realBoardHeight);
        //   
        //AppConfig.boardHeightTestScn / AppConfig.realBoardHeight
        LineRenderer _lr = combCOP.GetComponent<LineRenderer>();
        float _del = 0.5f;
        Vector3 _off = AppConfig_WIFI.GridOriginTestScn;

        _p1 = new Vector3(_x - _del, _y + _del, 0) + _off;
        _p2 = new Vector3(_x + _del, _y + _del, 0) + _off;
        _p3 = new Vector3(_x + _del, _y - _del, 0) + _off;
        _p4 = new Vector3(_x - _del, _y - _del, 0) + _off;
       // COPImage.transform.position = _p1;

        Vector2[] points = new Vector2[3]
        {
            new Vector2(_x - _del, _y + _del),
              new Vector2(_x - _del, _y - _del),
               new Vector2(_x + _del, _y - _del)
        };
        _lr.SetPositions(new Vector3[] { _p1, _p2, _p3, _p4, _p1 });

    }

    private void ShowIndividualCOPLR(int i, int j)
    {
        // First clear the current set of points in the LR.
        Vector3 _p1, _p2, _p3, _p4;
        float _x = MoBBoServer.server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].X * (AppConfig_WIFI.boardWidthTestScn / AppConfig_WIFI.realBoardWidth);
        float _y = MoBBoServer.server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].Y * (AppConfig_WIFI.boardHeightTestScn / AppConfig_WIFI.realBoardHeight);
        LineRenderer _lr = indivCOP[i, j].GetComponent<LineRenderer>();
        float _del = 0.5f;
        Vector3 _off = AppConfig_WIFI.GridOriginTestScn + new Vector3((j + 0.5f) * AppConfig_WIFI.boardWidthTestScn, 0, 0)
                       + new Vector3(0, -(i + 0.5f) * AppConfig_WIFI.boardHeightTestScn, 0);
        _p1 = new Vector3(_x - _del, _y + _del, 0) + _off;
        _p2 = new Vector3(_x + _del, _y + _del, 0) + _off;
        _p3 = new Vector3(_x + _del, _y - _del, 0) + _off;
        _p4 = new Vector3(_x - _del, _y - _del, 0) + _off;
        _lr.SetPositions(new Vector3[] { _p1, _p2, _p3, _p4, _p1 });
    }


    private void UpdateDeviceDataDisplay()
    {
        // Update text display.
        txtBoxIndivDevData.text = "";

        StringBuilder _strBldr = new StringBuilder();
        // Update display of the data from the different MoBo boards.
        for (int i = 0; i < Params.MaxNoOfDevs; i++)
        {
            // Check if device is connected.
            if (MoBBoServer.server.IsRegisteredID(i + 1))
            {
                _strBldr.AppendLine(GetFormattedMoBoData(MoBBoServer.server.mobboDevs[i]));
            }
        }
        _strBldr.AppendLine(    // Combine COP information from baords.
        txtBoxIndivDevData.text = _strBldr.ToString());
    }

    private void HandleKeyboardInputs()
    {
        // If key down?
        int kdwn = OneIDKeyDown();

        // If Key is down then swtich on the LED
        if (kdwn != -1)
        {
            // Check if the device is currently streaming.
            if (MoBBoServer.server.mobboDevs[kdwn - 1].LEDOn == false)
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID((byte)kdwn, new byte[] { (byte)MoBBoCommands.LED_ON, });
                }
                // Get status
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID((byte)kdwn, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
                }
            }
        }

        // If key up?
        int kup = OneIDKeyUp();
        if (kup > 0)
        {
            // Check if the device is currently streaming.
            if (MoBBoServer.server.mobboDevs[kup - 1].LEDOn)
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID((byte)kup, new byte[] { (byte)MoBBoCommands.LED_OFF, });
                }
                // Get status
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID((byte)kup, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
                }
            }
        }

        // Check if the "s" key is up.
        if (Input.GetKeyUp(KeyCode.S))
        {
            if (stream)
            {
                StartAllDevs();
            }
            else
            {
                StopAllDevs();
            }
            stream = !stream;
        }

        // Check if the "i" key is up.
        if (Input.GetKeyUp(KeyCode.I))
        {
            indivDisp = !indivDisp;
        }
    }

    private int OneIDKeyDown()
    {
        if (Input.GetKeyDown(KeyCode.Alpha0))
        {
            return 0;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            return 1;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha2))
        {
            return 2;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha3))
        {
            return 3;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha4))
        {
            return 4;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha5))
        {
            return 5;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha6))
        {
            return 6;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha7))
        {
            return 7;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha8))
        {
            return 8;
        }
        else if (Input.GetKeyDown(KeyCode.Alpha9))
        {
            return 9;
        }
        else if (Input.GetKeyDown(KeyCode.A))
        {
            return 10;
        }
        else if (Input.GetKeyDown(KeyCode.B))
        {
            return 11;
        }
        else if (Input.GetKeyDown(KeyCode.C))
        {
            return 12;
        }
        else if (Input.GetKeyDown(KeyCode.D))
        {
            return 13;
        }
        else if (Input.GetKeyDown(KeyCode.E))
        {
            return 14;
        }
        else if (Input.GetKeyDown(KeyCode.F))
        {
            return 15;
        }
        return -1;
    }

    private int OneIDKeyUp()
    {
        if (Input.GetKeyUp(KeyCode.Alpha1))
        {
            return 1;
        }
        else if (Input.GetKeyUp(KeyCode.Alpha2))
        {
            return 2;
        }
        else if (Input.GetKeyUp(KeyCode.Alpha3))
        {
            return 3;
        }
        else if (Input.GetKeyUp(KeyCode.Alpha4))
        {
            return 4;
        }
        else if (Input.GetKeyUp(KeyCode.Alpha5))
        {
            return 5;
        }
        else if (Input.GetKeyUp(KeyCode.Alpha6))
        {
            return 6;
        }
        else if (Input.GetKeyUp(KeyCode.Alpha7))
        {
            return 7;
        }
        else if (Input.GetKeyUp(KeyCode.Alpha8))
        {
            return 8;
        }
        else if (Input.GetKeyUp(KeyCode.Alpha9))
        {
            return 9;
        }
        else if (Input.GetKeyDown(KeyCode.A))
        {
            return 10;
        }
        else if (Input.GetKeyDown(KeyCode.B))
        {
            return 11;
        }
        else if (Input.GetKeyDown(KeyCode.C))
        {
            return 12;
        }
        else if (Input.GetKeyDown(KeyCode.D))
        {
            return 13;
        }
        else if (Input.GetKeyDown(KeyCode.E))
        {
            return 14;
        }
        else if (Input.GetKeyDown(KeyCode.F))
        {
            return 15;
        }
        return -1;
    }

    public string GetFormattedMoBoData(MoBBoDeviceUDP moboDev)
    {
        if (moboDev != null)
        {
            StringBuilder strBldr = new StringBuilder();
            strBldr.Append($"[{moboDev.ID,3:X}]({moboDev.Time,8:N3}ms) ");
            strBldr.Append($"Pos(cm) [{moboDev.X,10:N3} | {moboDev.Y,10:N3}] ");
            strBldr.Append($"[{moboDev.ReservedByte1:X2}{moboDev.ReservedByte2:X2}{moboDev.ReservedByte3:X2}]");
            return strBldr.ToString();
        }
        return null;
    }

    public void StartAllDevs()
    {
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.StartAll();
        }
    }

    public void StopAllDevs()
    {
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.StopAll();
        }
        // Get status
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.GetStatus();
        }
    }

    public void ResetTime()
    {
        // Send timer reset command to all clients.
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.ResetTimers();
        }
    }

    public void btnResetTimers_Click()
    {
        // Send timer reset command to all clients.
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.ResetTimers();
        }
    }

    public void btnGetStatus_Click()
    {
        // Send timer reset command to all clients.
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.GetStatus();
        }
    }

    public void MoboDiagnostics_Load()
    {

    }

    public void MoboDiagnostics_KeyUp()
    {
        if (Input.GetKey(KeyCode.F5))
        {
            _updateDevList = true;
        }
    }

    public void btnCallFroRegistration_Click()
    {
        // Send out registration call.
        for (int i = 0; i < 3; i++)
        {
            MoBBoServer.server.CallForRegistration();
        }

        // Enable update device list flag.
        _updateDevList = true;
        UnityEngine.Debug.Log(_updateDevList);
    }

    public void btnStartAll_Click()
    {
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.StartAll();
        }
    }

    public void btnStopAll_Click()
    {
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.StopAll();
        }
        // Get status
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.GetStatus();
        }
    }


    public void positionmatcher()
    {
        float x_diff = Mathf.Abs(tar_x_pos - MoBBoServer.COP.x);

        float y_diff = Mathf.Abs(tar_y_pos - MoBBoServer.COP.y);

        UnityEngine.Debug.Log("MOBBO X__POS IS............" + MoBBoServer.COP.x);
        UnityEngine.Debug.Log("MOBBO Y__POS IS............" + MoBBoServer.COP.y);
        UnityEngine.Debug.Log("TARGET X__POS IS............" + tar_x_pos);
        UnityEngine.Debug.Log("TARGET Y__POS IS............" + tar_y_pos);
        UnityEngine.Debug.Log("the x____diff is.............." + x_diff);
        UnityEngine.Debug.Log("the y____diff is.............." + y_diff);


        //  float z_diff = Mathf.Abs(tar_z_pos - MoBBoServer.COP.z);

        if (x_diff <= 250f && y_diff <= 250f)
        {
            UnityEngine.Debug.Log("x_matched");
            change_tar_x = true;
            //  change_pos();
        }




        //if (y_diff <= 50f)
        //{
        //    UnityEngine.Debug.Log("y_matched");
        //    change_tar_y = true;
        //    change_pos_x();
        //}
    }
    public void change_pos()
    {
        if (change_tar_x)
        {
            tar_x_pos_ = UnityEngine.Random.Range(20f, -250f);
            tar_y_pos_ = UnityEngine.Random.Range(130f, -235f);
            //target.GetComponent<RectTransform>().anchoredPosition = new Vector3(tar_x_pos_, tar_y_pos_, tar_z_pos);
            UnityEngine.Debug.Log("TARGET__CHANGED__ X__POS IS............" + tar_x_pos_);
            UnityEngine.Debug.Log("TARGET___CHANGED__ Y__POS IS............" + tar_y_pos_);
        }

    }

    public void btnResetAllIDs_Click()
    {
        // Reset IDs.
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.ResetIDs();
        }
        // Clear all devices and available IDs.
        MoBBoServer.server.ClearAllDevices();
    }

    public void tctBoxFilename_TextChanged()
    {
    }

    public void tctBoxFilename_KeyPress()
    {
        var regex = new Regex(@"[^a-zA-Z0-9\s]");
        //if (regex.IsMatch(e.KeyChar.ToString()))
        //{
        //    e.Handled = true;
        //}
    }

    public void btnStartSession_Click()
    {
        UnityEngine.Debug.Log("Starting session.");
        assess_timer = true;
       
    }

    public void btnGoBack_Click()
    {
        SceneManager.LoadScene("2mb");
    }

    public void txtBoxData_TextChanged()
    {

    }

   

    private void DrawOuterGridLines()
    {

        ClearRowSep();
        for (int i = 0; i <= AppData_WIFI.mGrid.height; i++)
        {
            if (i == 0 || i == AppData_WIFI.mGrid.height)
            {
                GameObject tempGO = new GameObject();
                tempGO.AddComponent<LineRenderer>();
                // tempGO.AddComponent<BoxCollider>();
                rowSep.Add(tempGO);
                rowLR.Add(tempGO.GetComponent<LineRenderer>());
                rowLR[rowLR.Count - 1].material = new Material(Shader.Find("Sprites/Default"));
                rowLR[rowLR.Count - 1].startColor = UnityEngine.Color.black;
                rowLR[rowLR.Count - 1].endColor = UnityEngine.Color.black;
                rowLR[rowLR.Count - 1].startWidth = 0.25f;
                rowLR[rowLR.Count - 1].positionCount = 2;
                // Update position.
                _p1 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(0, -AppConfig_WIFI.boardHeightTestScn, 0));
                _p2 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(0, -AppConfig_WIFI.boardHeightTestScn, 0)) +
                      AppData_WIFI.mGrid.width * (new Vector3(AppConfig_WIFI.boardWidthTestScn, 0, 0));

                rowLR[rowLR.Count - 1].SetPositions(new Vector3[] { _p1, _p2 });
                boundary_1.transform.position = _p1;
                boundary_2.transform.position = _p2;



                //  boundary_1.transform.localScale = new Vector3(AppData.mGrid.width*AppConfig.boardWidthTestScn, 2, 2);
                //   boundary_2.transform.localScale = new Vector3(2,AppData.mGrid.height* AppConfig.boardHeightTestScn,2);
            }

        }

        ClearColSep();
        for (int i = 0; i <= AppData_WIFI.mGrid.width; i++)
        {
            if (i == 0 || i == AppData_WIFI.mGrid.width)
            {
                GameObject tempGO = new GameObject();
                tempGO.AddComponent<LineRenderer>();
                // tempGO.AddComponent<Collider>();
                colSep.Add(tempGO);
                colLR.Add(tempGO.GetComponent<LineRenderer>());
                colLR[colLR.Count - 1].material = new Material(Shader.Find("Sprites/Default"));
                colLR[colLR.Count - 1].startColor = UnityEngine.Color.black;
                colLR[colLR.Count - 1].endColor = UnityEngine.Color.black;
                colLR[colLR.Count - 1].startWidth = 0.25f;
                colLR[colLR.Count - 1].positionCount = 2;
                // Update position.

                _p3 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(AppConfig_WIFI.boardWidthTestScn, 0, 0));
                _p4 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(AppConfig_WIFI.boardWidthTestScn, 0, 0)) +
                      AppData_WIFI.mGrid.height * (new Vector3(0, -AppConfig_WIFI.boardHeightTestScn, 0));
                colLR[colLR.Count - 1].SetPositions(new Vector3[] { _p3, _p4 });
                _p4 = AppConfig_WIFI.GridOriginTestScn + i * (new Vector3(AppConfig_WIFI.boardWidthTestScn, 0, 0)) - AppData_WIFI.mGrid.width * (new Vector3(AppConfig_WIFI.boardWidthTestScn, 0, 0));

                boundary_3.transform.position = _p3;

                boundary_4.transform.position = _p4;


                //  centre_point.transform.position = _P3;

                //   boundary_3.GetComponent<RectTransform>().anchoredPosition = (_p3+_p4)/2;
                //   boundary_4.GetComponent<RectTransform>().anchoredPosition = (_p4+_p1)/2;

                //  boundary_3.transform.localScale = new Vector3(AppData.mGrid.width * AppConfig.boardWidthTestScn, 2, 2);
                //  boundary_4.transform.localScale = new Vector3(2, AppData.mGrid.height * AppConfig.boardHeightTestScn, 2);
                //  boundary_3.transform.localScale=new Vector3()
            }
        }


        boundary_1.GetComponent<RectTransform>().anchoredPosition = (_p1 + _p2) / 2;
        boundary_2.GetComponent<RectTransform>().anchoredPosition = (_p2 + _p3) / 2;
        boundary_3.GetComponent<RectTransform>().anchoredPosition = (_p3 + _p4) / 2;
        boundary_4.GetComponent<RectTransform>().anchoredPosition = (_p4 + _p1) / 2;
        boundary_1.transform.localScale = new Vector3(AppData_WIFI.mGrid.width * AppConfig_WIFI.boardWidthTestScn + 1.25f, 2, 2);
        boundary_2.transform.localScale = new Vector3(2, (AppData_WIFI.mGrid.height * AppConfig_WIFI.boardHeightTestScn) + 1.25f, 2);
        boundary_3.transform.localScale = new Vector3(AppData_WIFI.mGrid.width * AppConfig_WIFI.boardWidthTestScn + 1.25f, 2, 2);
        boundary_4.transform.localScale = new Vector3(2, AppData_WIFI.mGrid.height * AppConfig_WIFI.boardHeightTestScn + 1.25f, 2);

    }
   

    private void ClearColSep()
    {
        for (int i = 0; i < colSep.Count; i++)
        {
            Destroy(colSep[i]);
        }
        colSep.Clear();
        colLR.Clear();
    }
    private void ClearRowSep()
    {
        for (int i = 0; i < rowSep.Count; i++)
        {
            Destroy(rowSep[i]);
        }
        rowSep.Clear();
        rowLR.Clear();
    }




}




