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

public class MobboDiagnostics : MonoBehaviour
{
    //Using Scene handler
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
    public Text txtBoxData;
    public Dropdown lstBoxMoBoards;
    public Text Weight;
    public Text COPx_y;

    // Data Logging Mobbo
    public Button btnStrtStpLogging;
    public InputField txtBoxFilename;

    // COP and position of board_boundaries
    public List<GameObject> boards;
    public float W, w0, w1, w2, w3, w4, w5;
    public GameObject COP;

    // Data logging folder.
    string dataDir = "data";
    // MoBBo UDP Server
    //MoBBoUdpServer server;
    bool _updateDevList = false;

    public void SetUpServer()
    {
        // Initialize server.
        MoBBoServer.Start();
        //server = new MoBBoUdpServer(23001, 23000);

        //// Send out registration call.
        //for (int i = 0; i < 3; i++)
        //{
        //    server.CallForRegistration();
        //}

        // Enable update device list flag.
        _updateDevList = true;

        // Start receiving data.
        //server.StartReceivingData();

        // Disable button.
        btnStartStopServer.enabled = false;

        // Start data rate timer
        //DisplayTimer.Start();
    }

    public void btnStartStopServer_Click()
    {
        SetUpServer();
    }

    void Update()
    {
        // Do something only when the server is running.
        if (MoBBoServer.started)
        {
            // Enable call for registration and reset ID buttons
            btnCallFroRegistration.enabled = true;
            btnResetAllIDs.enabled = true;

            // If the list of devices is empty, the clear all display.
            if (lstBoxMoBoards.options.Count == 0)
            {
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

            //COP_localPosition of each board     
            //for (int i = 0; i < Params.MaxNoOfDevs; i++)
            //{
            //    //COP.transform.position = new Vector2(MoBBoServer.server.mobboDevs[i].X, MoBBoServer.server.mobboDevs[i].Y);
            //    boards[i].transform.Find("COP").transform.localPosition = new Vector2(MoBBoServer.server.mobboDevs[i].X / 60, MoBBoServer.server.mobboDevs[i].Y / 30);
            //    COPx_y.text = "COPx,y = " + boards[i].transform.Find("COP").transform.localPosition;
            //}

            //for (int i = 0; i < Params.MaxNoOfDevs; i++)
            //{
            //    if (W > 2)
            //    {
            //        COP.SetActive(true);
            //    }
            //    else if (W < 2)
            //    {
            //        COP.SetActive(false);
            //    }
            //    COP.transform.localPosition = new Vector2(MoBBoServer.server.mobboDevs[0].X, MoBBoServer.server.mobboDevs[0].Y);
            //    W = MoBBoServer.server.mobboDevs[0].F1 + MoBBoServer.server.mobboDevs[0].F2 + MoBBoServer.server.mobboDevs[0].F3 + MoBBoServer.server.mobboDevs[0].F4;
            //    Weight.text = "W = " + W;
            //    COPx_y.text = "COPx,y = " + COP.transform.localPosition;
            //}

            for (int i = 0; i < Params.MaxNoOfDevs; i++)
            {
                if (W > 2)
                {
                    COP.SetActive(true);
                }
                else if (W < 2)
                {
                    COP.SetActive(false);
                }
                w0 = MoBBoServer.server.mobboDevs[0].F1 + MoBBoServer.server.mobboDevs[0].F2 + MoBBoServer.server.mobboDevs[0].F3 + MoBBoServer.server.mobboDevs[0].F4;
                w1 = MoBBoServer.server.mobboDevs[1].F1 + MoBBoServer.server.mobboDevs[1].F2 + MoBBoServer.server.mobboDevs[1].F3 + MoBBoServer.server.mobboDevs[1].F4;
                w2 = MoBBoServer.server.mobboDevs[2].F1 + MoBBoServer.server.mobboDevs[2].F2 + MoBBoServer.server.mobboDevs[2].F3 + MoBBoServer.server.mobboDevs[2].F4;
                w3 = MoBBoServer.server.mobboDevs[3].F1 + MoBBoServer.server.mobboDevs[3].F2 + MoBBoServer.server.mobboDevs[3].F3 + MoBBoServer.server.mobboDevs[3].F4;
                w4 = MoBBoServer.server.mobboDevs[4].F1 + MoBBoServer.server.mobboDevs[4].F2 + MoBBoServer.server.mobboDevs[4].F3 + MoBBoServer.server.mobboDevs[4].F4;
                w5 = MoBBoServer.server.mobboDevs[5].F1 + MoBBoServer.server.mobboDevs[5].F2 + MoBBoServer.server.mobboDevs[5].F3 + MoBBoServer.server.mobboDevs[5].F4;
                W = w0 + w1 + w2 + w3 + w4 + w5;
                Weight.text = "W = " + W;
                COPx_y.text = "COPx,y = " + COP.transform.localPosition;
                //COP.transform.localPosition = new Vector2((((MoBBoServer.server.mobboDevs[0].X + 30) * w0) + ((MoBBoServer.server.mobboDevs[1].X + 30) * w1) + ((MoBBoServer.server.mobboDevs[2].X + 30) * w2) + ((MoBBoServer.server.mobboDevs[3].X + 90) * w3) + ((MoBBoServer.server.mobboDevs[4].X + 90) * w4) + ((MoBBoServer.server.mobboDevs[5].X + 90) * w5)) / W, (((MoBBoServer.server.mobboDevs[0].Y + 75) * w0) + ((MoBBoServer.server.mobboDevs[1].Y + 45) * w1) + ((MoBBoServer.server.mobboDevs[2].Y + 15) * w2) + ((MoBBoServer.server.mobboDevs[3].Y + 15) * w3) + ((MoBBoServer.server.mobboDevs[4].Y + 45) * w4) + ((MoBBoServer.server.mobboDevs[5].Y + 75) * w5)) / W);
                //COP.transform.localPosition = new Vector2((((MoBBoServer.server.mobboDevs[0].X + 30) * w0) + ((MoBBoServer.server.mobboDevs[1].X + 30) * w1) + ((MoBBoServer.server.mobboDevs[2].X + 30) * w2)) / W, (((MoBBoServer.server.mobboDevs[0].Y + 75) * w0) + ((MoBBoServer.server.mobboDevs[1].Y + 45) * w1) + ((MoBBoServer.server.mobboDevs[2].Y + 15) * w2)) / W);
                COP.transform.localPosition = new Vector2(((MoBBoServer.server.mobboDevs[0].X * w0) + (MoBBoServer.server.mobboDevs[1].X * w1) + (MoBBoServer.server.mobboDevs[2].X * w2) + ((MoBBoServer.server.mobboDevs[3].X + 56.5f) * w3) + ((MoBBoServer.server.mobboDevs[4].X + 56.5f) * w4) + ((MoBBoServer.server.mobboDevs[5].X + 56.5f) * w5)) / W, (((MoBBoServer.server.mobboDevs[0].Y + 27.5f) * w0) + (MoBBoServer.server.mobboDevs[1].Y * w1) + ((MoBBoServer.server.mobboDevs[2].Y - 27.5f) * w2) + ((MoBBoServer.server.mobboDevs[3].Y - 27.5f) * w3) + (MoBBoServer.server.mobboDevs[4].Y * w4) + ((MoBBoServer.server.mobboDevs[5].Y + 27.5f) * w5)) / W);
                //COP.transform.localPosition = new Vector2(((MoBBoServer.server.mobboDevs[0].X * w0) + (MoBBoServer.server.mobboDevs[1].X * w1) + (MoBBoServer.server.mobboDevs[2].X * w2)) / W, (((MoBBoServer.server.mobboDevs[0].Y + 30) * w0) + (MoBBoServer.server.mobboDevs[1].Y * w1) + ((MoBBoServer.server.mobboDevs[2].Y - 30) * w2)) / W);
                //COP.transform.localPosition = new Vector2(MoBBoServer.server.mobboDevs[0].X, MoBBoServer.server.mobboDevs[0].Y);
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
        }
    }

    public void UpdateGUIButtons()
    {
        // Check and update button text.
        // Get the MoBo device that is selected.
        if (lstBoxMoBoards.value != -1)
        {
            string _selip = lstBoxMoBoards.options[lstBoxMoBoards.value].text.ToString().Split(':')[0];
            byte devId = MoBBoServer.server.GetIdForIp(_selip, false);
            if (devId != 0)
            {
                // Start/Stop streaming button
                if (MoBBoServer.server.mobboDevs[devId - 1].Streaming && btnStartStopStream.GetComponentInChildren<Text>().text == "Start Stream")
                {
                    btnStartStopStream.GetComponentInChildren<Text>().text = "Stop Stream";
                }
                else if (MoBBoServer.server.mobboDevs[devId - 1].Streaming == false && btnStartStopStream.GetComponentInChildren<Text>().text == "Stop Stream")
                {
                    btnStartStopStream.GetComponentInChildren<Text>().text = "Start Stream";
                }

                // LED On/Off button
                if (MoBBoServer.server.mobboDevs[devId - 1].LEDOn && btnLedOnOff.GetComponentInChildren<Text>().text == "LED On")
                {
                    btnLedOnOff.GetComponentInChildren<Text>().text = "LED Off";
                }
                else if (MoBBoServer.server.mobboDevs[devId - 1].LEDOn == false && btnLedOnOff.GetComponentInChildren<Text>().text == "LED Off")
                {
                    btnLedOnOff.GetComponentInChildren<Text>().text = "LED On";
                }

                // Vibrate On/Off button
                if (MoBBoServer.server.mobboDevs[devId - 1].VibrateOn && btnVibrateOnOff.GetComponentInChildren<Text>().text == "Vibrate On")
                {
                    btnVibrateOnOff.GetComponentInChildren<Text>().text = "Vibrate Off";
                }
                else if (MoBBoServer.server.mobboDevs[devId - 1].VibrateOn == false && btnVibrateOnOff.GetComponentInChildren<Text>().text == "Vibrate Off")
                {
                    btnVibrateOnOff.GetComponentInChildren<Text>().text = "Vibrate On";
                }
            }
        }
    }

    public void UpdateMoBBoList()
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
                    //lstBoxMoBoards.Items.Add($"{server.mobboDevs[i].Address}:{server.mobboDevs[i].Port}");
                    List<string> m_DropOptions = new List<string> { $"{MoBBoServer.server.mobboDevs[i].Address}:{MoBBoServer.server.mobboDevs[i].Port}" };
                    lstBoxMoBoards.AddOptions(m_DropOptions);
                }
            }
            _updateDevList = false;
        }
    }

    public void UpdateDeviceDataDisplay()
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
            strBldr.Append($"[{moboDev.ID,3:X}]({moboDev.Time,8:N3}ms) ");
            strBldr.Append($"Force(N) [{moboDev.F1,8:N3} | {moboDev.F2,8:N3} | {moboDev.F3,8:N3} | {moboDev.F4,8:N3}] ");
            strBldr.Append($"Pos(mm) [{moboDev.X,8:N3} | {moboDev.Y,8:N3}] ");
            strBldr.Append($"[{moboDev.ReservedByte1:X2}{moboDev.ReservedByte2:X2}{moboDev.ReservedByte3:X2}]");
            strBldr.Append($" @ {moboDev.DataRate:N1} fps");
            return strBldr.ToString();
        }
        return null;
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
                }
            }
        }
    }

    public void lstBoxMoBoards_SelectedIndexChanged()
    {
        // Get the MoBo device that is selected.
        if (lstBoxMoBoards.value != -1)
        {
            string _selip = lstBoxMoBoards.options[lstBoxMoBoards.value].text.ToString().Split(':')[0];
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
     
    public void btnStrtStpLogging_Click()
    {
        // Check logging status
        if (MoBBoServer.server.isLogging)
        {
            MoBBoServer.server.StopLogging();
            btnStrtStpLogging.GetComponentInChildren<Text>().text = "Start Logging";
            txtBoxFilename.enabled = true;
            txtBoxFilename.text = "";
        }
        else
        {
            MoBBoServer.server.StartLogging($"{dataDir}\\{txtBoxFilename.text}");
            btnStrtStpLogging.GetComponentInChildren<Text>().text = "Stop Logging";
            txtBoxFilename.enabled = false;
        }
    }

    public void txtBoxData_TextChanged()
    {

    }
}

