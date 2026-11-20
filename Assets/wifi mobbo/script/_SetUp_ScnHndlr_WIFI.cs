using System.Net.Mime;
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

public class _SetUp_ScnHndlr_WIFI : MonoBehaviour
{
    //Using Scene handler
    public MoBBoUdpServer moBBoUdpServer;
    public Dropdown choose_game;
    public Button btnStartStopServer;
    public Button btnCallFroRegistration;
    public Button btnResetTimers;
    public Button btnGetStatus;
    public Button btnStartAll;
    public Button btnStopAll;
    public Button btnResetAllIDs;
    public Button btnStartStopStream;
    public Button btnLedOnOff;
    public Button btnVibrateOnOff;
    public Button btnStrtStpLogging;
    public Button btnStartTestScene;
    public Text txtBoxData;
    public Dropdown lstBoxMoBoards;
    public Dropdown lstBoxGridSelect;
    public Toggle toggleAnnotation;
    public UnityEngine.UI.Image game_1;
    public UnityEngine.UI.Image game_2;
    public UnityEngine.UI.Image game_3;
    public UnityEngine.UI.Image game_4;
    public UnityEngine.UI.Image connection;
    public UnityEngine.UI.Text connection_text;
    

    // Data Logging Mobbo
    public InputField txtBoxFilename;
    public InputField txtBoxAnnotation;
    public string grid_mat;
    public AudioSource audioSource;
     
   
    // COP and position of board_boundaries
    //public List<GameObject> boards;
    //public float W, w0, w1, w2;
    //public GameObject COP;

    // Data logging folder.
    // string dataDir = "data";
    // MoBBo UDP Server
    bool _updateDevList = false;

    // MoBBo grid
    private List<int[]> _currGridOpts;
    //private MoBBoGrid mGrid;
    private List<GameObject> colSep;
    private List<LineRenderer> colLR;
    private List<GameObject> rowSep;
    private List<LineRenderer> rowLR;
   
    public string[] list_of_IDs;
    public static string setup_folder;
    public bool reset_id=false;


    void Start()
    {
        setup_folder = login_handlr.boardset_up_folder;
        if (audioSource != null && !audioSource.isPlaying)
        {
            audioSource.Play(); // Start playing audio
        }


        // Check if session is none. Then use default dummy patient sesson.
        if (AppData_WIFI.session == null)
        {
            AppData_WIFI.StartDummySession();


        }
       // btnStartStopServer_Click(); 

        // Register call back functions.
      btnStartStopServer.GetComponent<Button>().onClick.AddListener(btnStartStopServer_Click);// because i called it in the start itself.

     //  btnCallFroRegistration.GetComponent<Button>().onClick.AddListener(btnCallFroRegistration_Click);
       // btnResetTimers.GetComponent<Button>().onClick.AddListener(btnResetTimers_Click);
      // btnGetStatus.GetComponent<Button>().onClick.AddListener(btnGetStatus_Click);
        btnStartAll.GetComponent<Button>().onClick.AddListener(btnStartAll_Click);
        btnStopAll.GetComponent<Button>().onClick.AddListener(btnStopAll_Click);
        btnResetAllIDs.GetComponent<Button>().onClick.AddListener(btnResetAllIDs_Click);
      // btnStartStopStream.GetComponent<Button>().onClick.AddListener(btnStartStopStream_Click);
        btnLedOnOff.GetComponent<Button>().onClick.AddListener(btnLedOnOff_Click);
     //   btnVibrateOnOff.GetComponent<Button>().onClick.AddListener(btnVibrateOnOff_Click);
        btnStartTestScene.GetComponent<Button>().onClick.AddListener(btnStartTestScene_Click_);
        btnStrtStpLogging.GetComponent<Button>().onClick.AddListener(btnStrtStpLogging_Click);
        lstBoxGridSelect.GetComponent<Dropdown>().onValueChanged.AddListener(lstBoxGridSelect_Change);
        //toggleAnnotation.GetComponent<Toggle>().onValueChanged.AddListener(toggleAnnotate_Change);


       // UnityEngine.Debug.Log($"{MoBBoServer.server.mobboDevs[0].Address}:{MoBBoServer.server.mobboDevs[0].Port}");
       
        // Initialize MoBBo grid.
        //AppData.mGrid = null;

        // Intiailize line renders
        colSep = new List<GameObject>();
        colLR = new List<LineRenderer>();
        rowSep = new List<GameObject>();
        rowLR = new List<LineRenderer>();

        // Disable annotation.
        toggleAnnotation.enabled = false;
        txtBoxAnnotation.enabled = false;
        txtBoxAnnotation.text = "";
    }

    public void exit_app()
    {
        Application.Quit();
        
    }
    private void toggleAnnotate_Change(bool arg0)
    {
        // Check if toggle button is checked
        if (arg0 == true)
        {
            // Set annotation value.
            MoBBoDeviceUDP.annotation = txtBoxAnnotation.text == "" ? "1" : txtBoxAnnotation.text;
        } else
        {
            MoBBoDeviceUDP.annotation = "0";
        }
    }
    public void OnApplicationQuit()
    {
        MoBBoServer.Stop();
        Color32 color = new Color32(233, 0, 66, 255);
        connection.color = color;
        connection_text.text = "Disconnected";

    }

    public void disocnnect_boards()
    {
        MoBBoServer.Stop();
        btnStartStopServer.enabled =true;
        Color32 color = new Color32(233, 0, 66, 255);
        connection.color = color;
        connection_text.text = "Disconnected";

    }
    void Update()
    {
        // Do something only when the server is running.
        if (MoBBoServer.started)

        {
            connection.color = UnityEngine.Color.green;
            connection_text.text = "connected";
            //UnityEngine.Debug.Log(MoBBoServer.server.mobboDevs.ToString());
            // UnityEngine.Debug.Log("server started");
            // Disable start button.
            btnStartStopServer.enabled = false;

            // Enable call for registration and reset ID buttons
            btnCallFroRegistration.enabled = true;
            btnResetAllIDs.enabled = true;

            // If the list of devices is empty, the clear all display.
            if (lstBoxMoBoards.options.Count == 0)
            {
                //  UnityEngine.Debug.Log("no boards");

                txtBoxData.text = "";
                txtBoxFilename.text = "";
                txtBoxFilename.enabled = false;
                btnStrtStpLogging.enabled = false;
            }

            // Update list of MoBBoards
            UpdateMoBBoList();

            // Update current data text.
            UpdateDeviceDataDisplay();

            // Update the GUI buttons
            UpdateGUIButtons();

            // Check if the grid select text box is empty.
            if (lstBoxGridSelect.options.Count != MoBBoServer.server.GetNumberOfRegisteredDevices())
            {
                // Add options.
                _currGridOpts = AppConfig_WIFI.GetGridOptions(lstBoxMoBoards.options.Count);
                lstBoxGridSelect.options.Clear();
                foreach (int[] opts in _currGridOpts)
                {
                    lstBoxGridSelect.options.Add(new Dropdown.OptionData($"{opts[0]} x {opts[1]}"));
                }
            }

            if (lstBoxMoBoards.options.Count > 0)
            {
                // Enable reset timer.
                btnResetTimers.enabled = true;
                // Enable get status.
                btnGetStatus.enabled = true;
                // Enable start/stop buttons
                btnStartAll.enabled = true;
                btnStopAll.enabled = true;
                // Enable data logging if not already logging.
                if (MoBBoServer.server.isLogging)
                {
                    txtBoxFilename.enabled = false;
                    btnStartStopStream.enabled = true;
                }
                else
                {
                    txtBoxFilename.enabled = true;
                    if (txtBoxFilename.text.Length > 0)
                    {
                        btnStrtStpLogging.enabled = true;
                    }
                    else
                    {
                        btnStrtStpLogging.enabled = false;
                    }
                }
            }
            else
            {
                // Disable reset timer.
                btnResetTimers.enabled = false;
                // Disable get status.
                btnGetStatus.enabled = false;
                // Disable start/stop buttons
                btnStartAll.enabled = false;
                btnStopAll.enabled = false;
            }

            // Handle mouse input.
            if (AppData_WIFI.mGrid != null)
            {
                // Make sure no UI element is clicked.
                if (UnityEngine.EventSystems.EventSystem.current.IsPointerOverGameObject())
                {
                    return;
                }
                // Left/Right mouse click handling
                if (Input.GetMouseButtonUp(0))
                {
                    //UnityEngine.Debug.Log(UtilsClass.GetMouseWorldPosition() -AppConfig_WIFI.GridOrigin);
                    AppData_WIFI.mGrid.SetNextAvailableValue(UtilsClass.GetMouseWorldPosition());
                }
                else if (Input.GetMouseButtonUp(1))
                {
                    // UnityEngine.Debug.Log(UtilsClass.GetMouseWorldPosition() -AppConfig_WIFI.GridOrigin);
                    AppData_WIFI.mGrid.ClearCellValue(UtilsClass.GetMouseWorldPosition());
                }
            }

            // Handle keyboard inputs.
            HandleKeyboardInputs();


        }
        //    for (int i = 0; i < Params.MaxNoOfDevs; i++)
        // {
        //   if (MoBBoServer.server.IsRegisteredID(i + 1))
        //   {
        //  MoBBoDeviceUDP device = MoBBoServer.server.mobboDevs[i];
        //  string formattedData = GetFormattedMoBoData(device);
        // UnityEngine.Debug.Log(formattedData);
        // }
        //}
        
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
        else if (Input.GetKeyUp(KeyCode.A))
        {
            return 10;
        }
        else if (Input.GetKeyUp(KeyCode.B))
        {
            return 11;
        }
        else if (Input.GetKeyUp(KeyCode.C))
        {
            return 12;
        }
        else if (Input.GetKeyUp(KeyCode.D))
        {
            return 13;
        }
        else if (Input.GetKeyUp(KeyCode.E))
        {
            return 14;
        }
        else if (Input.GetKeyUp(KeyCode.F))
        {
            return 15;
        }
        return -1;
    }

    private void UpdateGUIButtons()
    {
        // Check and update button text.
        //// Get the MoBo device that is selected.
        //if (lstBoxMoBoards.value != -1)
        //{
        //    string _selip = lstBoxMoBoards.options[lstBoxMoBoards.value].text.ToString().Split(':')[0];
        //    byte devId = MoBBoServer.server.GetIdForIp(_selip, false);
        //    if (devId != 0)
        //    {
        //        // Start/Stop streaming button
        //        if (MoBBoServer.server.mobboDevs[devId - 1].Streaming && btnStartStopStream.GetComponentInChildren<Text>().text == "Start Stream")
        //        {
        //            btnStartStopStream.GetComponentInChildren<Text>().text = "Stop Stream";
        //        }
        //        else if (MoBBoServer.server.mobboDevs[devId - 1].Streaming == false && btnStartStopStream.GetComponentInChildren<Text>().text == "Stop Stream")
        //        {
        //            btnStartStopStream.GetComponentInChildren<Text>().text = "Start Stream";
        //        }

        //        // LED On/Off button
        //        if (MoBBoServer.server.mobboDevs[devId - 1].LEDOn && btnLedOnOff.GetComponentInChildren<Text>().text == "LED On")
        //        {
        //            btnLedOnOff.GetComponentInChildren<Text>().text = "LED Off";
        //        }
        //        else if (MoBBoServer.server.mobboDevs[devId - 1].LEDOn == false && btnLedOnOff.GetComponentInChildren<Text>().text == "LED Off")
        //        {
        //            btnLedOnOff.GetComponentInChildren<Text>().text = "LED On";
        //        }

        //        // Vibrate On/Off button
        //        if (MoBBoServer.server.mobboDevs[devId - 1].VibrateOn && btnVibrateOnOff.GetComponentInChildren<Text>().text == "Vibrate On")
        //        {
        //            btnVibrateOnOff.GetComponentInChildren<Text>().text = "Vibrate Off";
        //        }
        //        else if (MoBBoServer.server.mobboDevs[devId - 1].VibrateOn == false && btnVibrateOnOff.GetComponentInChildren<Text>().text == "Vibrate Off")
        //        {
        //            btnVibrateOnOff.GetComponentInChildren<Text>().text = "Vibrate On";
        //        }
        //    }
        //}

        // Check if a grid arrangement has been selected.
        if (AppData_WIFI.mGrid != null)
        {
            //UnityEngine.Debug.Log(AppData.mGrid.AllGridValueAssigned());
            btnStartTestScene.enabled = AppData_WIFI.mGrid.AllGridValueAssigned();
        } else
        {
            btnStartTestScene.enabled = false;
        }
        
    }

    private void UpdateMoBBoList()
    {
        // Does the device list need to be updates?
        if (_updateDevList)
        {
           
            // Add row to list of deivces.
            lstBoxMoBoards.options.Clear();
            for (int i = 0; i < Params.MaxNoOfDevs; i++)
            {
                if (MoBBoServer.server.IsRegisteredID(i + 1))
                {
                    lstBoxMoBoards.options.Add(new Dropdown.OptionData($"{MoBBoServer.server.mobboDevs[i].Address}:{MoBBoServer.server.mobboDevs[i].Port}"));
                    UnityEngine.Debug.Log("boards  available");
                    UnityEngine.Debug.Log($"{MoBBoServer.server.mobboDevs[i].Address}:{MoBBoServer.server.mobboDevs[i].Port}");

                }
            }
            _updateDevList = false;
        }
    }

    private void UpdateDeviceDataDisplay()
    {
        // Update text display.
        txtBoxData.text = "";

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
        txtBoxData.text = _strBldr.ToString();
    }

       

    public string GetFormattedMoBoData(MoBBoDeviceUDP moboDev)
    {
        if (moboDev != null)
        {
            StringBuilder strBldr = new StringBuilder();
            //strBldr.Append($"[{moboDev.ID,3:X}]({moboDev.Time,8:N3}ms) ");

            strBldr.Append($"Force(Kg) [{moboDev.F1:N3} | {moboDev.F2:N3} | {moboDev.F3:N3} | {moboDev.F4:N3}] ");
            strBldr.Append($"Pos(cm) [{moboDev.X:N3} | {moboDev.Y:N3}] ");
            strBldr.Append($"[{moboDev.ReservedByte1:X2}{moboDev.ReservedByte2:X2}{moboDev.ReservedByte3:X2}]");
            strBldr.Append($" @ {moboDev.DataRate:N1} fps");
            string result = strBldr.ToString();
            //UnityEngine.Debug.Log(result);
            return result;
            
        }
        return null;
    }

 
        


    public void SetUpServer()
    {
        // Initialize server.
        MoBBoServer.Start();

        // Enable update device list flag.
        _updateDevList = true;

        // Disable button.
        btnStartStopServer.enabled = false;
    }

    public void btnStartStopServer_Click()
    {
        SetUpServer();
    }

    public void btnStartStopStream_Click()
    {
        // Get the MoBo device that is selected.
        string _selip = lstBoxMoBoards.options[lstBoxMoBoards.value].text.ToString().Split(':')[0];
        byte devId = MoBBoServer.server.GetIdForIp(_selip, false);
        if (devId != 0)
        {
            // Check if the device is currently streaming.
            if (MoBBoServer.server.mobboDevs[devId - 1].Streaming)
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.STREAM_OFF, });
                }
                // Get status
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
                }
            }
            else
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.STREAM_ON, });
                    UnityEngine.Debug.Log("started streaming");
                }
            }
        }
    }

    public void lstBoxMoBoards_SelectedIndexChanged()// look for to get the ids of the board
    {
        // Get the MoBo device that is selected.
        if (lstBoxMoBoards.value != -1)
        {
            string _selip = lstBoxMoBoards.options[lstBoxMoBoards.value].text.ToString().Split(':')[0];
            UnityEngine.Debug.Log("IPS ARE"+_selip);
            int devId = MoBBoServer.server.GetIdForIp(_selip, false);
            if (devId != 0)
            {
                // Enable buttons.
                btnStartStopStream.enabled = true;
                btnLedOnOff.enabled = true;
                btnVibrateOnOff.enabled = true;
                btnStartStopStream.GetComponentInChildren<Text>().text = MoBBoServer.server.mobboDevs[devId - 1].Streaming == true ? "Stop Stream" : "Start Stream";
                btnLedOnOff.GetComponentInChildren<Text>().text = MoBBoServer.server.mobboDevs[devId - 1].LEDOn == true ? "LED Off" : "LED On";
                btnVibrateOnOff.GetComponentInChildren<Text>().text = MoBBoServer.server.mobboDevs[devId - 1].VibrateOn == true ? "Vibrate Off" : "Vibrate On";
            }
            else
            {
                // Disable buttons.
                btnStartStopStream.enabled = false;
                btnLedOnOff.enabled = false;
                btnVibrateOnOff.enabled = false;
            }
        }

    }

    public void lstBoxMoBoards_DoubleClick()
    {
        // Unselect item.
        lstBoxMoBoards.value = -1;
    }

    public void btnLedOnOff_Click()
    {
        // Get the MoBo device that is selected.
        string _selip = lstBoxMoBoards.options[lstBoxMoBoards.value].text.ToString().Split(':')[0];
        byte devId = MoBBoServer.server.GetIdForIp(_selip, false);
        if (devId != 0)
        {
            // Check if the device is currently streaming.
            if (MoBBoServer.server.mobboDevs[devId - 1].LEDOn)
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.LED_OFF, });
                }
                // Get status
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
                }
            }
            else
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.LED_ON, });
                }
                // Get status
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
                }
            }
        }
    }

    public void btnVibrateOnOff_Click()
    {
        // Get the MoBo device that is selected.
        string _selip = lstBoxMoBoards.options[lstBoxMoBoards.value].text.ToString().Split(':')[0];
        byte devId = MoBBoServer.server.GetIdForIp(_selip, false);
        if (devId != 0)
        {
            // Check if the device is currently streaming.
            if (MoBBoServer.server.mobboDevs[devId - 1].VibrateOn)
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.VIBRATE_OFF, });
                }
                // Get status
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
                }
            }
            else
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.VIBRATE_ON, });
                }
                // Get status
                for (int i = 0; i < Params.reTxMsgCount; i++)
                {
                    MoBBoServer.server.SendToID(devId, new byte[] { (byte)MoBBoCommands.GET_STATUS, });
                }
            }
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
       //    UnityEngine.Debug.Log(_updateDevList);
    }

    public void btnStartAll_Click()
    {
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
          
            MoBBoServer.server.StartAll();
        }
        //writrecsvfor_boardsetting();
    }


    public void btnStopAll_Click()
    {
        for (int i = 0; i < Params.reTxMsgCount; i++)
        {
            MoBBoServer.server.StopAll();
            MoBBoServer.server.ResetTimers();
            MoBBoServer.server.GetStatus();
        }
      
    }

    public void btnResetAllIDs_Click() // to reset and call for registration this single function can be used
    {
        { // Reset IDs.
            if (!reset_id)
            {
                for (int i = 0; i < Params.reTxMsgCount; i++)
              {
                 MoBBoServer.server.ResetIDs();
               }
            reset_id= true;
            MoBBoServer.server.ClearAllDevices();
            }

            if (reset_id)
            {
                // Send out registration call.
                for (int i = 0; i < 3; i++)
                {
                    MoBBoServer.server.CallForRegistration();
                }

                // Enable update device list flag.
                _updateDevList = true;

            }
            // Clear all devices and available IDs.

        }
       
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

    public void btnStrtStpLogging_Click()   
    {
        // Check logging status
        if (MoBBoServer.server.isLogging)
        {
            UnityEngine.Debug.Log("Stopped logging");
            MoBBoServer.server.StopLogging();
            btnStrtStpLogging.GetComponentInChildren<Text>().text = "Start Logging";
            txtBoxFilename.enabled = true;
            txtBoxFilename.text = " ";
            // Enable annotation.
            toggleAnnotation.enabled = false;
            txtBoxAnnotation.enabled = false;
            txtBoxAnnotation.text = "";
        }
        else
        {
            //string _fname = AppData_WIFI.subjd.SetupFileDir +
            //                $"\\setup_{txtBoxFilename.text}_" +
            //                DateTime.Now.ToString("Dyyyy-MM-dd_THH-mm-ss");
            string fname = setup_folder + "//";
            UnityEngine.Debug.Log(fname);
            MoBBoServer.server.StartLogging(fname);
            btnStrtStpLogging.GetComponentInChildren<Text>().text = "Stop Logging";
            txtBoxFilename.enabled = false;
            // Enable annotation.
            toggleAnnotation.enabled = true;
            txtBoxAnnotation.enabled = true;
        }
    }

    public void btnStartTestScene_Click()
    {

        string game = choose_game.options[choose_game.value].text;

        if (game == "Assessment")
        {
            SceneManager.LoadScene("MoBBoTestScene");
        }
        if (game == "FloppyBird")
        {
            SceneManager.LoadScene("floppy_bird");
        }
        if (game == "PingPong")
        { 
            SceneManager.LoadScene("ping_pong");
        }
        if (game == "Spaceshooter")
        {
            SceneManager.LoadScene("Space");
        }
        if (game == "CoinCollector")
        {
            SceneManager.LoadScene("coin_collector");
        }
        if (game == "Force_display")
        {
            SceneManager.LoadScene("force_display");
        }
        if (game == "ball_Tilt")
        {
            SceneManager.LoadScene("weight_shifting");
        }
        if (game == "Stepper")
        {
            SceneManager.LoadScene("stepper");
        }

    }
    public void btnStartTestScene_Click_()
    {
        string game = choose_game.options[choose_game.value].text;

        switch (game)
        {
            case "Assessment":
                SceneManager.LoadScene("MoBBoTestScene");
                break;

            case "FloppyBird":
                SceneManager.LoadScene("floppy_bird");
                break;

            case "PingPong":
                SceneManager.LoadScene("ping_pong");
                break;

            case "Spaceshooter":
                SceneManager.LoadScene("Space");
                break;

            case "CoinCollector":
                SceneManager.LoadScene("coin_collector");
                break;

            case "Force_display":
                SceneManager.LoadScene("force_display");
                break;

            case "ball_Tilt":
                SceneManager.LoadScene("weight_shifting");
                break;

            case "Stepper":
                SceneManager.LoadScene("stepper");
                break;

        }
    }


    public void txtBoxData_TextChanged()
    {

    }

    public void lstBoxGridSelect_Change(int arg0)
    {
        int selectedRows = _currGridOpts[lstBoxGridSelect.value][0];
        int selectedColumns = _currGridOpts[lstBoxGridSelect.value][1];

        // Assign the selected values to global variables
        AppData_WIFI.SelectedGridRows = selectedRows;
        AppData_WIFI.SelectedGridColumns = selectedColumns;
        // Intialize grid.   
        if (AppData_WIFI.mGrid != null)
        {
            AppData_WIFI.mGrid.Clear();
        }
        AppData_WIFI.mGrid = new MoBBoGrid(_currGridOpts[lstBoxGridSelect.value][1], _currGridOpts[lstBoxGridSelect.value][0],//change.
                             AppConfig_WIFI.GridOrigin,AppConfig_WIFI.boardWidth,AppConfig_WIFI.boardHeight,
                              MoBBoServer.server.GetRegisteredIDs());
        //UnityEngine.Debug.Log($"{AppData_WIFI.mGrid.height}, {AppData_WIFI.mGrid.width}");
        UnityEngine.Debug.Log($"{selectedRows},{selectedColumns}");

        









        // Draw grid lines
        // Column lines
        DrawColumnLines();

        // Row lines
        DrawRowLines();
    }


    private void DrawRowLines()
    { Vector3 _p1, _p2;
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
            _p1 = AppConfig_WIFI.GridOrigin + i * (new Vector3(AppConfig_WIFI.boardWidth, 0, 0));
            _p2 = AppConfig_WIFI.GridOrigin + i * (new Vector3(AppConfig_WIFI.boardWidth, 0, 0)) +AppData_WIFI.mGrid.height * (new Vector3(0, -AppConfig_WIFI.boardHeight, 0));
            colLR[colLR.Count - 1].SetPositions(new Vector3[] { _p1, _p2 });

        }
    }

    private void DrawColumnLines()
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

            _p1 = AppConfig_WIFI.GridOrigin + i * (new Vector3(0, -AppConfig_WIFI.boardHeight, 0));
            _p2 = AppConfig_WIFI.GridOrigin + i * (new Vector3(0, -AppConfig_WIFI.boardHeight, 0)) +
                  AppData_WIFI.mGrid.width * (new Vector3(AppConfig_WIFI.boardWidth, 0, 0));
            rowLR[rowLR.Count - 1].SetPositions(new Vector3[] { _p1, _p2 });
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

