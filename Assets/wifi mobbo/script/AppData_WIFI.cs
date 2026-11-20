using System;
using System.IO;
//using System.Collections;
//using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.Diagnostics;
using MoBBoDataStructures_WIFI;
using System.Text;
using MoBBoLibrary_WIFI;


public static class AppData_WIFI {

    // Subject data details
    public static SubjectData subjd { get; private set; }
    
    // Selected subject.s
    //private static string _subjHospNum = "";
    public static string subjHospNum { get; private set; }

    // Session object
    static public TherapySession_WIFI session = null;
    
    // Data logging related stuff.
    private static string[] _dheader = new string[] {
        "time", "angr", "angl", "forcex", "forcey", "forcer", "forcel",
        "x", "y", "lenr", "lenl", "ctrlr", "ctrll", 
        "desx", "desy", "desfx", "desfy", "desfr", "desfl",
        "status", "error1", "erro2", "ctype", "dtye", "gamestate"
    };
    public static DataLogger dlog { get; private set; }
    public static bool isLogging { get; private set; }
    public static int SelectedGridRows { get; set; }
    public static int SelectedGridColumns { get; set; }
    public static string gamestate;

    // Performance variable counts for different games
    public static int[] GamePerfVarCount = new int[] {
        4, // Catcher
        5, // Carzy Pong
    };

    // MoBBo Server details.
    public static readonly int localPort = 23001;
    public static readonly int remotePort = 23000;

    // Some parameters when starting games.
    public static int nextGameLevel = 1;

    // Keeping track of time.
    static private double nanosecPerTick = 1.0 / Stopwatch.Frequency;
    static private Stopwatch stp_watch = new Stopwatch();
    static public double CurrentTime
    {
        get { return stp_watch.ElapsedTicks * nanosecPerTick; }
        //get { return DateTime.Now.ToString("h:mm:ss tt"); 
    }
    static public bool isTimerRunning
    {
        get { return stp_watch.IsRunning; }
    }

    // PLAEBO data.
    static string plaebo_path = login_handlr.file_path_root  + "\\data" ;
    static public PlaeboRobotData plaeboData = new PlaeboRobotData(Path.Combine(plaebo_path, "mobboparam"));

    // Counts to keep track of time for different GUI updatess
    public static int[] count = new int[] { 0, 0 };
    private static int[] _Th;
    public static int[] Th
    {
        get { return new int[] { 10, 50, }; }
    }

    // MoBBo grid
    public static MoBBoGrid mGrid = null;

    // Start application timer.
    static public void StartTimer()
    {   
        stp_watch.Start();
    }

    static public void StartDummySession()
    {

     //  string foldername = login_handlr.openfoldername;
      // StartSession(foldername);
        StartSession("000000g");

    }

    static public void StartSession(string hospno)
    {
        subjHospNum = hospno;

        // Read all relevant subject information.
      //  subjd = new SubjectData(subjHospNum);
        
        subjd = new SubjectData(subjHospNum);

        // Create a new therapy session
        session = new TherapySession_WIFI(hospno);
    }

    static public void StopSession()
    {
        session.CloseSessionFile();
    }

    static public void StartDataLog(string fname, string preheader)
    {







        // If you are already logging.
        if (dlog != null)
        {
            StopLogging();
        }
        // Start new logger
        if (fname != "")
        {
            dlog = new DataLogger(fname, $"{preheader}\n{string.Join(",", _dheader)}\n");
            isLogging = true;
        } else
        {
            dlog = null;
            isLogging = false;
        }
    }

    static public void LogData()
    {
        // Log onle if the current data is SENSORSTREAM
        if ((Status)plaeboData.dtype == Status.SENSORSTREAM)
        {
            string[] _data = new string[] {
                CurrentTime.ToString("G17"),
                //CurrentTime,
                plaeboData.angL.ToString("G17"),
                plaeboData.angR.ToString("G17"),
                plaeboData.fx.ToString("G17"),
                plaeboData.fy.ToString("G17"),
                plaeboData.fL.ToString("G17"),
                plaeboData.fR.ToString("G17"),
                plaeboData.x.ToString("G17"),
                plaeboData.y.ToString("G17"),
                plaeboData.lL.ToString("G17"),
                plaeboData.lR.ToString("G17"),
                plaeboData.uL.ToString("G17"),
                plaeboData.uR.ToString("G17"),
                plaeboData.tgtFx.ToString("G17"),
                plaeboData.tgtFy.ToString("G17"),
                (plaeboData.status & 0xFF).ToString("G"),
                (plaeboData.error1 & 0xFF).ToString("G"),
                (plaeboData.error2 & 0xFF).ToString("G"),
                plaeboData.ctrl.ToString("G"),
                plaeboData.dtype.ToString("G"),
                gamestate
            };
            string _dstring = string.Join(",", _data);
            _dstring += "\n";
            dlog.logData(_dstring);
        }
    }

    static public void StopLogging()
    {
        dlog.stopDataLog(true);
        dlog = null;
        isLogging = false;
    }

    static public string GetNewFileName(string fname)
    {
        //return Path.Combine(SubjectData.Get_Subj_Rawdata_Dir(subjHospNum), 
        //    type + "_" + DateTime.Now.ToString("Dyyyy-MM-ddTHH-mm-ss") + ".csv");
        return Path.Combine(SubjectData.Get_Subj_Rawdata_Dir(subjHospNum), fname);
    }

    // Pre-header for different scenes
    static public string GetPreHeader(string type, string hospnum, string dtnow)
    {
        return $"type:{type} subj:{hospnum} time:{dtnow}";
    }
}

/* Data logger for saving data coming in from
 * the robot.
 */
public class DataLogger
{
    public string curr_fname { get; private set; }
    public StringBuilder _filedata;
    public bool stillLogging
    {
        get { return (_filedata != null); }
    }

    public DataLogger(string filename, string header)
    {
        curr_fname = filename;
        _filedata = new StringBuilder(header);
    }

    public void stopDataLog(bool log = true)
    {
        if (log)
        {
            File.AppendAllText(curr_fname, _filedata.ToString());
        }
        curr_fname = "";
        _filedata = null;
    }

    public void logData(string data)
    {
        if (_filedata != null)
        {
            _filedata.Append(data);
        }
    }
}

/*
 * Class containing function to interact with the boards.
 */
public static class MoBBoServer
{
    // MoBBo UDP Server
    public static MoBBoUdpServer server = null;
    public static Vector2 _COP = new Vector2(-999, -999);
    private static float _W;
    public static float _W_p1;
    public static float _W_p2;
    public static float _W_p1_ap;
    public static float _W_p2_ap;



    public static float W
    {
        get
        {
            _W = 0;
            if (AppData_WIFI.mGrid != null)
            {
                for (int i = 0; i < AppData_WIFI.mGrid.height; i++)
                {
                    for (int j = 0; j < AppData_WIFI.mGrid.width; j++)
                    {
                        if (server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F > 1.0f)
                        {
                            _W += server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F;
                        }
                    }
                }
            }
            return _W;
        }
    }
    // look here to calculate the value of the each board weight
    public static float W_player1
    {
        get
        {
           
            _W_p1 = 0;

            if (AppData_WIFI.mGrid != null)
            {
                for (int i = 0; i < AppData_WIFI.mGrid.height; i++)
                {
                    for (int j = 0; j < AppData_WIFI.mGrid.width/2; j++)
                    {
                        if (server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F > 1.0f)
                        {
                            _W_p1 += server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F;
                        }
                    }
                }
            }
            return _W_p1;
        }
    }
    public static float W_player2
    {
        get
        {
            _W_p2 = 0;
            if (AppData_WIFI.mGrid != null)
            {
                for (int i = 0; i < AppData_WIFI.mGrid.height; i++)
                {
                    int o = AppData_WIFI.mGrid.width / 2;
                    for (int j = o; j < AppData_WIFI.mGrid.width ; j++)
                    {
                        if (server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F > 1.0f)
                        {
                            _W_p2 += server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F;
                        }
                    }
                }
            }
            return  _W_p2;
        }
    }
    public static float W_player1_ap
    {
        get
        {
            _W_p1_ap = 0;

            if (AppData_WIFI.mGrid != null)
            {
                // Iterate through the entire width (columns) of the grid
                for (int i = 0; i < AppData_WIFI.mGrid.width; i++)
                {
                    // Iterate through the top half (rows)
                    for (int j = 0; j < AppData_WIFI.mGrid.height / 2; j++)
                    {
                        // Check and sum forces
                        int index = AppData_WIFI.mGrid.values[j, i] - 1;
                        if (index >= 0 && server.mobboDevs[index].F > 1.0f)
                        {
                            _W_p1_ap += server.mobboDevs[index].F;
                        }
                    }
                }
            }
            return _W_p1_ap;
        }
    }

    public static float W_player2_ap
    {
        get
        {
            _W_p2_ap = 0;

            if (AppData_WIFI.mGrid != null)
            {
                // Iterate through the entire width (columns) of the grid
                for (int i = 0; i < AppData_WIFI.mGrid.width; i++)
                {
                    // Iterate through the bottom half (rows)
                    for (int j = AppData_WIFI.mGrid.height / 2; j < AppData_WIFI.mGrid.height; j++)
                    {
                        // Check and sum forces
                        int index = AppData_WIFI.mGrid.values[j, i] - 1;
                        if (index >= 0 && server.mobboDevs[index].F > 1.0f)
                        {
                            _W_p2_ap += server.mobboDevs[index].F;
                        }
                    }
                }
            }
            return _W_p2_ap;
        }
    }




    public static Vector2 COP
    {
        get
        {
            float xval, yval, fval;
            if (W == 0)
            {
                _COP.x = -999;
                _COP.y = -999;

            }
            else
            {
                _COP.x = 0;
                _COP.y = 0;
                for(int i = 0; i < AppData_WIFI.mGrid.height; i++)
                {
                    for (int j = 0; j < AppData_WIFI.mGrid.width; j++)
                    {
                      
                        xval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].X;
                        yval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].Y;
                        fval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F;
                        if (fval > 1.0f)
                        {
                            _COP.x += fval * (xval + (j + 0.5f) *AppConfig_WIFI.realBoardWidth);
                            _COP.y += fval * (yval - (i + 0.5f) *AppConfig_WIFI.realBoardHeight);
                        }
                    }
                }
                _COP.x = _COP.x / W;
                _COP.y = _COP.y / W;
            }
            return _COP;
        }
    }

    

    public static Vector2 COP_player1
    {
        get
        {
            float xval, yval, fval;
            if (W_player1 == 0)
            {
                _COP.x = -999;
                _COP.y = -999;

            }
            else
            {
                _COP.x = 0;
                _COP.y = 0;
                for (int i = 0; i < AppData_WIFI.mGrid.height; i++)
                {
                    for (int j = 0; j < AppData_WIFI.mGrid.width/2; j++)
                    {
                        UnityEngine.Debug.Log("height:" + AppData_WIFI.mGrid.height);
                        UnityEngine.Debug.Log("width :" + AppData_WIFI.mGrid.width);
                        xval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].X;
                        yval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].Y;
                        fval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F;
                        if (fval > 1.0f)
                        {
                            _COP.x += fval * (-xval + (j + 0.5f) *AppConfig_WIFI.realBoardWidth);
                            _COP.y += fval * (-yval - (i + 0.5f) *AppConfig_WIFI.realBoardHeight);
                        }
                    }
                }
                _COP.x = _COP.x / W_player1;
                _COP.y = _COP.y / W_player1;
            }
            return _COP;
        }
    }
    public static Vector2 COP_player2
    {
        get
        {
            float xval, yval, fval;
            if (W_player2 == 0)
            {
                _COP.x = -999;
                _COP.y = -999;  

            }
            else
            {
                _COP.x = 0;
                _COP.y = 0;
                for (int i = 0; i < AppData_WIFI.mGrid.height; i++)
                { int o = AppData_WIFI.mGrid.width / 2;
                    for (int j =o ; j < AppData_WIFI.mGrid.width; j++)
                    {
                        UnityEngine.Debug.Log("height:" + AppData_WIFI.mGrid.height);
                        UnityEngine.Debug.Log("width :" + AppData_WIFI.mGrid.width);
                        xval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].X;
                        yval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].Y;
                        fval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F;
                        if (fval > 1.0f)
                        {
                            _COP.x += fval * (-xval + (j + 0.5f) *AppConfig_WIFI.realBoardWidth);
                            _COP.y += fval * (-yval - (i + 0.5f) *AppConfig_WIFI.realBoardHeight);
                        }
                    }
                }
                _COP.x = _COP.x / W_player2;
                _COP.y = _COP.y / W_player2;
            }
            return _COP;
        }
    }

    public static Vector2 COP_TopBoard
    {
        get
        {
            float xval, yval, fval;
            if (W_player1_ap == 0)
            {
                _COP.x = -999;
                _COP.y = -999;
            }
            else
            {
                _COP.x = 0;
                _COP.y = 0;
                for (int i = 0; i < AppData_WIFI.mGrid.height / 2; i++) // Top half rows
                {
                    for (int j = 0; j < AppData_WIFI.mGrid.width; j++) // All columns
                    {
                        xval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].X;
                        yval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].Y;
                        fval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F;

                        if (fval > 5.0f)
                        {
                            _COP.x += fval * (xval + (j + 0.5f) * AppConfig_WIFI.realBoardWidth);
                            _COP.y += fval * (yval - (i + 0.5f) * AppConfig_WIFI.realBoardHeight);
                        }
                    }
                }
                _COP.x = _COP.x / W_player1_ap;
                _COP.y = _COP.y / W_player1_ap;
            }
            return _COP;
        }
    }

    public static Vector2 COP_BottomBoard
    {
        get
        {
            float xval, yval, fval;
            if (W_player2_ap == 0)
            {
                _COP.x = -999;
                _COP.y = -999;
            }
            else
            {
                _COP.x = 0;
                _COP.y = 0;
                for (int i = AppData_WIFI.mGrid.height / 2; i < AppData_WIFI.mGrid.height; i++) // Bottom half rows
                {
                    for (int j = 0; j < AppData_WIFI.mGrid.width; j++) // All columns
                    {
                        xval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].X;
                        yval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].Y;
                        fval = server.mobboDevs[AppData_WIFI.mGrid.values[i, j] - 1].F;

                        if (fval > 5.0f)
                        {
                            _COP.x += fval * (xval + (j + 0.5f) * AppConfig_WIFI.realBoardWidth);
                            _COP.y += fval * (yval - (i + 0.5f) * AppConfig_WIFI.realBoardHeight);
                        }
                    }
                }
                _COP.x = _COP.x / W_player2_ap;
                _COP.y = _COP.y / W_player2_ap;
            }
            return _COP;
        }
    }



    public static bool started
    {
        get { return server != null; }
    }
    private static bool _updateDevList = false;

    public static void Start()
    {
        try
        {
            // Initialize server.
            server = new MoBBoUdpServer(AppData_WIFI.localPort, AppData_WIFI.remotePort);

            // Start receiving data.
            server.StartReceivingData();

            // first reset IDs.
            for (int i = 0; i < 3; i++)
            {
                server.ResetIDs();
            }

            // Send out registration call.
            for (int i = 0; i < 3; i++)
            {
                server.CallForRegistration();
            }

            // Enable update device list flag.
            _updateDevList = true;

            // Start all devices.
            server.StartAll();

        } catch
        {
            server = null;
            UnityEngine.Debug.Log("Could not start server.");
        }
    }

    public static void Stop()
    {
        UnityEngine.Debug.Log("disconnected");
        if (server != null)
        {
            server.DisableBroadcast();
            server = null;
            UnityEngine.Debug.Log("disconnected");
        }
    }
}


///*
// * Class containing a set of fucntions to handle connecting
// * to the robot.
// */
//public static class ConnectToRobot
//{
//    //private static string _port = "COM4";

//    public static void Connect(string port)
//    {
//        //if (MySerialThread.serPort == null)
//        //{
//        //    // Setup serial communication with the robot.
//        //    MySerialThread.InitSerialComm(port);
//        //}

//        //if (MySerialThread.serPort.IsOpen == false)
//        //{
//        //    MySerialThread.Connect();
//        //    //AppData.WriteSessionInfo("Connecting to robot.");
//        //}

//        // Start the application timer.
//        if (AppData.isTimerRunning == false)
//        {
//            AppData.StartTimer();
//            //AppData.WriteSessionInfo("Timer started.");
//        }

//        // Intialize count
//        AppData.count[0] = 0;
//        AppData.count[1] = 0;
//    }
//}

///*
// * Class containing a set of functions to handle sending information
// * to the robot.
// */
//public static class SendToRobot
//{
//    static public void TorqueSensorParam()
//    {
//        //MySerialThread.writeSerialPacket(0x03, 0x00, AppData.plaeboData.getByteArray4SensorParam());
//    }

//    static public void Calibrate()
//    {
//        // Send message to calibrate the robot sensors
//        //MySerialThread.writeSerialPacket(0x07, 0x01, new byte[0]);
//    }

//    static public void ControlParam(ControlType ctrlType, bool tgtInfo, bool ctrlInfo)
//    {
//        byte msgDetail = (byte)ctrlType;

//        // Update control type  and target/control info.
//        AppData.plaeboData.ctrlType = ctrlType;
//        AppData.plaeboData.TargetInfo = tgtInfo;
//        AppData.plaeboData.ControlInfo = ctrlInfo;

//        // Update target/control info
//        if (tgtInfo)
//        {
//            msgDetail = (byte)(msgDetail | 0x08);
//        }
//        else if (ctrlInfo)
//        {
//            msgDetail = (byte)(msgDetail | 0x10);
//        }

//        // Send data aross.
//        //MySerialThread.writeSerialPacket(0x05, msgDetail, AppData.plaeboData.getByteArray4ControlParam());
//    }

//    static public void StartStream()
//    {
//        //MySerialThread.writeSerialPacket(0x01, 0x00, new byte[0]);
//    }

//    static public void StopStream()
//    {
//        //MySerialThread.writeSerialPacket(0x02, 0x00, new byte[0]);
//    }
//}