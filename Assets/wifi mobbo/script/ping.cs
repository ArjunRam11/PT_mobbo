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


public class ping : MonoBehaviour
{
    //Using Scene handler
    public Button btnStartSession;
    public Button btnGoBack;
    public Button start_stop_logging;
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
    public bool change_tar_x = false;
    public bool change_tar_y = false;
    Vector3 _p1, _p2, _p4, _p3;
    Vector3 p1, p2, p3, p4;
    Vector3 t1, t2, t3, t4;
    public GameObject boundary_1;
    public GameObject boundary_2;
    public GameObject boundary_3;
    public GameObject boundary_4;
    public GameObject centre_point;
    public static float paddle_1_y =-42f;
    public static float paddle_2_y =42f;
    public static Vector3 GridOriginTestScn_pong_1 = new Vector3(-115f, -26.4f, 0);
    public static Vector3 GridOriginTestScn_pong_2 = new Vector3(-19.6f, 0f, 1);
    public static float realBoardWidth_p = 56.5f;
    public static float realBoardHeight_p = 42f;
    public static int boardWidth_pong = 9;
    public static int boardHeight_pong = 18;
    public static int boardWidthTestScn_p = (int)(3.8* boardWidth_pong);
    public static int boardHeightTestScn_p = (int)(8 * boardHeight_pong);
    public float paddleSpeed = 8f;  
 
    public GameObject computerPaddle;
    public Transform org_p;
    public Transform bound1;
    public Transform bound2;


    private Rigidbody playerPaddleRb;
    private Rigidbody computerPaddleRb;
    private Rigidbody ballRb;
    private Vector2 ballDirection;
    public float initial_offset;

    private int dispcnt = 0;
    //private RigidbodyType2D kinematic;
    
    public GameObject player_1;
   
    public float random_no_p1;
    public float random_no_p2;

    public int count = 0;
    public int window_length = 20;
    public float averaged_val;
    private float left_limit;
    private float right_limit;
   
    private string csvFilePath_ml;// Update this to the correct path in your project.

    // Start is called before the first frame update
    void Start()
    {
        // to create the folders to save the gamedata and rawdata of the game

      

        // Check if session is none. Then use default dummy patient sesson.
        if (AppData_WIFI.session == null)
        {
            AppData_WIFI.StartDummySession();
        }
        // Register call back functions.
        btnStartSession.GetComponent<Button>().onClick.AddListener(btnStartSession_Click);
        btnGoBack.GetComponent<Button>().onClick.AddListener(btnGoBack_Click);

        // Refresh grid text display
        AppData_WIFI.mGrid.UpdateTextMesh_fat(AppConfig_WIFI.GridOriginTestScn, AppConfig_WIFI.boardping_width,
                                                                                               AppConfig_WIFI.boardping_height, UnityEngine.Color.black);

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
                csvData[0].TryGetValue("max_gcop_x", out string maxGcopXString))
            {
                // Parse the strings to float
                if (float.TryParse(minGcopXString, out float minGcopX) &&
                    float.TryParse(maxGcopXString, out float maxGcopX))
                {
                    left_limit = minGcopX;
                    right_limit = maxGcopX;

                    //UnityEngine.Debug.Log($"Left Limit (min_gcop_x): {left_limit}");
                    //UnityEngine.Debug.Log($"Right Limit (max_gcop_x): {right_limit}");
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

        // Intiailize line rendersx 

        combCOP = new GameObject();
        combCOP.AddComponent<LineRenderer>();
 
        LineRenderer _lr = combCOP.GetComponent<LineRenderer>();
     
        _lr.material = new Material(Shader.Find("Sprites/Default"));
        _lr.startColor = UnityEngine.Color.black;
        _lr.endColor = UnityEngine.Color.black;
        _lr.startWidth = 1f;
        _lr.positionCount = 5;
        _lr.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero });

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
                _lr.positionCount = 3;
                _lr.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero });
            }
        }


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

     

        DrawOuterGridLines();

        dispcnt = 0;

       

    }
    IEnumerator StartDevices()
    {
        StartAllDevs();
        yield return new WaitForSeconds(1);
        ResetTime();
    }


    // Update is called once per frame
    void Update()
    {
   
        // Do something only when the server is running.
        if (MoBBoServer.started)
        {
            // Handle keyboard inputs.
           HandleKeyboardInputs();
        }

        // Update COP information.
         UpdateDeviceDataDisplay();

       // DrawOuterGridLines();

        // Update COP display on the boards.
        dispcnt++;
        dispcnt = dispcnt % 5;
        if (dispcnt == 0)
        {
            DisplayCOP();
        }

     
    }

   public float moving_avg_filter(float input_cop)
    {
        {
            float cop_xs_sum = 0f;
            count++;
            for (int i = 0; i <= window_length; i++)
            {
                cop_xs_sum = +input_cop;
            }

            averaged_val = cop_xs_sum / window_length;
        }
        return averaged_val;
    }
    private void DisplayCOP()
    {
        if (MoBBoServer.W > 0)
        {
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
                playerCOP();
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

    private void playerCOP()
    {


        if (!PlayerPrefs.HasKey("left_limit"))
        {
            PlayerPrefs.SetFloat("left_limit", 0f); // Default value
        }

        if (!PlayerPrefs.HasKey("Right_limit"))
        {
            PlayerPrefs.SetFloat("Right_limit", 60f); // Default value
        }
        // First clear the current set of points in the LR.


        //*******here i interchenged the values for x and y because i flipped the board in the real world******//

        //float left_limit = PlayerPrefs.GetFloat("left_limit");
        //float right_limit = PlayerPrefs.GetFloat("Right_limit");

        float _new_dist = Mathf.Abs(right_limit - left_limit);
        org_p = GameObject.FindGameObjectWithTag("player1").transform;
        bound1 = GameObject.FindGameObjectWithTag("y_left").transform;
        bound2 = GameObject.FindGameObjectWithTag("y_right").transform;

        float U_org = (bound2.transform.position.x + bound1.transform.position.x)/2f;
        float x_org = (left_limit + right_limit) / 2;
        //if (MoBBoServer.W_player1 > 2f || MoBBoServer.W_player2 > 2f)
        //{


        //    initial_offset = bound1.transform.position.x - org_p.transform.position.x;
        //}


        float new_x = U_org + ((MoBBoServer.COP.x - x_org) / (_new_dist)) * (Mathf.Abs(bound2.transform.position.x - bound1.transform.position.x));



        float _x = (MoBBoServer.COP.x * ((AppConfig_WIFI.boardping_width) / (1f*_new_dist)));//(AppConfig_WIFI.realBoardWidth)) ; ;//);//
      
        float _y = MoBBoServer.COP.y * (AppConfig_WIFI.boardping_height) / (AppConfig_WIFI.realBoardHeight);

        //  UnityEngine.Debug.Log("the right and the left limits are" +_new_dist+"the fieldis"+field);


        float corrected_x = _x;//-187f;       //initial_offset

        if (float.IsNaN(_x) || float.IsNaN(_y) || float.IsInfinity(_x) || float.IsInfinity(_y))
        {
            throw new ArithmeticException();
        }

        try
        {
            player_1.transform.position = new Vector3(Mathf.Clamp(new_x, -107f, -10f) ,- 41f, 0);
        
        }
        catch (ArithmeticException)
        {

        }  

    }
    private void ShowCombinedCOPLR()

    {

        // First clear the current set of points in the LR.
        Vector3 _p1, _p2, _p3, _p4;
      
        float _x = MoBBoServer.COP.x * (AppConfig_WIFI.boardping_width)/ ( AppConfig_WIFI.realBoardWidth);
        float _y = MoBBoServer.COP.y *( AppConfig_WIFI.boardping_height) / (AppConfig_WIFI.realBoardHeight);
        float x_pos = 56.5f;
        // player_1.transform.position = new Vector3( _x, _y, 0);
       

        if (float.IsNaN(_x) || float.IsNaN(_y) || float.IsInfinity(_x) || float.IsInfinity(_y)) 
        {
            throw new ArithmeticException();
        }

        try
        {
            player_1.transform.position = new Vector3(x_pos,(_y - 90f), 0);
          
        }
        catch (ArithmeticException)
        {

        }



        LineRenderer _lr = combCOP.GetComponent<LineRenderer>();
        float _del = 0.5f;
        Vector3 _off_p1 = GridOriginTestScn_pong_1;
        

        _p1 = new Vector3(_x - _del, _y + _del, 0) + _off_p1;
        _p2 = new Vector3(_x + _del, _y + _del, 0) + _off_p1;
        _p3 = new Vector3(_x + _del, _y - _del, 0) + _off_p1;
        _p4 = new Vector3(_x - _del, _y - _del, 0) + _off_p1;

        player_1.transform.position = _p1;

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
        float _x = -MoBBoServer.server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].X * AppConfig_WIFI.boardWidthTestScn / AppConfig_WIFI.realBoardWidth;
        float _y = -MoBBoServer.server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].Y * AppConfig_WIFI.boardHeightTestScn / AppConfig_WIFI.realBoardHeight;
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
    
            {
                _strBldr.AppendLine(GetFormattedMoBoData(MoBBoServer.server.mobboDevs[i]));
            }
        }
        _strBldr.AppendLine("\n\n");
        _strBldr.AppendLine($"X: {MoBBoServer.COP.x}, Y: {MoBBoServer.COP.y}");
        // UnityEngine. Debug.Log("mobo xpos"+MoBBoServer.COP.x);
        //UnityEngine.Debug.Log("mobo ypos"+MoBBoServer.COP.y);
        // Combine COP information from baords.
        txtBoxIndivDevData.text = _strBldr.ToString();
    }

    private void HandleKeyboardInputs()
    {
        // If key down?
        int kdwn = OneIDKeyDown();

        // If Key is down then swtich on the LED
        //if (kdwn != -1)
        //{
        //    // Check if the device is currently streaming.
        //    if (MoBBoServer.server.mobboDevs[kdwn - 1].LEDOn == false)
        //    {
        //        for (int i = 0; i < Params.reTxMsgCount; i++)
        //        {
        //            MoBBoServer.server.SendToID((byte)kdwn, new byte[] { (byte)MoBBoCommands.LED_ON, });
        //        }
        //        // Get status
        //        for (int i = 0; i < Params.reTxMsgCount; i++)
        //        {
        //            MoBBoServer.server.SendToID((byte)kdwn, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
        //        }
        //    }
        //}

        // If key up?
        int kup = OneIDKeyUp();
        if (kup > 0)
        {
            // Check if the device is currently streaming.
            //if (MoBBoServer.server.mobboDevs[kup - 1].LEDOn)
            //{
            //    for (int i = 0; i < Params.reTxMsgCount; i++)
            //    {
            //        MoBBoServer.server.SendToID((byte)kup, new byte[] { (byte)MoBBoCommands.LED_OFF, });
            //    }
            //    // Get status
            //    for (int i = 0; i < Params.reTxMsgCount; i++)
            //    {
            //        MoBBoServer.server.SendToID((byte)kup, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
            //    }
            //}
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
            strBldr.Append($"Pos(mm) [{moboDev.X,10:N3} | {moboDev.Y,10:N3}] ");
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
       
    }

    public void btnGoBack_Click()
    {
        SceneManager.LoadScene("2mb");
    }

    public void txtBoxData_TextChanged()
    {

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
                rowLR[rowLR.Count - 1].startColor = UnityEngine.Color.white;
                rowLR[rowLR.Count - 1].endColor = UnityEngine.Color.white;
                rowLR[rowLR.Count - 1].startWidth = 0.25f;
                rowLR[rowLR.Count - 1].positionCount = 2;
                // Update position.
                _p1 = AppConfig_WIFI.GridOriginTestScnn + i * (new Vector3(0, -AppConfig_WIFI.boardping_height, 0));
                _p2 = AppConfig_WIFI.GridOriginTestScnn + i * (new Vector3(0, -AppConfig_WIFI.boardping_height, 0)) +
                      AppData_WIFI.mGrid.width * (new Vector3(AppConfig_WIFI.boardping_width, 0, 0));

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
                colLR[colLR.Count - 1].material = new Material(Shader.Find("Sprites/Mask"));
                colLR[colLR.Count - 1].startColor = UnityEngine.Color.black;
                colLR[colLR.Count - 1].endColor = UnityEngine.Color.black;
                colLR[colLR.Count - 1].startWidth = 0.25f;
                colLR[colLR.Count - 1].positionCount = 2;
                // Update position.

                _p3 = AppConfig_WIFI.GridOriginTestScnn + i * (new Vector3(AppConfig_WIFI.boardping_width, 0, 0));
                _p4 = AppConfig_WIFI.GridOriginTestScnn + i * (new Vector3(AppConfig_WIFI.boardping_width, 0, 0)) +
                      AppData_WIFI.mGrid.height * (new Vector3(0, -AppConfig_WIFI.boardping_height, 0));
                colLR[colLR.Count - 1].SetPositions(new Vector3[] { _p3, _p4 });
                _p4 = AppConfig_WIFI.GridOriginTestScnn + i * (new Vector3(AppConfig_WIFI.boardping_width, 0, 0)) - AppData_WIFI.mGrid.width * (new Vector3(AppConfig_WIFI.boardping_width, 0, 0));

                boundary_3.transform.position = _p3;

                boundary_4.transform.position = _p4;


            }
        }


        boundary_1.GetComponent<RectTransform>().anchoredPosition = (_p1 + _p2) / 2;
        boundary_2.GetComponent<RectTransform>().anchoredPosition = (_p2 + _p3) / 2;
        boundary_3.GetComponent<RectTransform>().anchoredPosition = (_p3 + _p4) / 2;
        boundary_4.GetComponent<RectTransform>().anchoredPosition = (_p4 + _p1) / 2;
        boundary_1.transform.localScale = new Vector3(AppData_WIFI.mGrid.width * AppConfig_WIFI.boardping_width + 1.25f, 2, 2);
        boundary_2.transform.localScale = new Vector3(2, (AppData_WIFI.mGrid.height * AppConfig_WIFI.boardping_height) + 1.25f, 2);
        boundary_3.transform.localScale = new Vector3(AppData_WIFI.mGrid.width * AppConfig_WIFI.boardping_width + 1.25f, 2, 2);
        boundary_4.transform.localScale = new Vector3(2, AppData_WIFI.mGrid.height * AppConfig_WIFI.boardping_height + 1.25f, 2);


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



