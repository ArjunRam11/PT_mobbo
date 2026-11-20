using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using System;
using System.Text;
using MoBBoLibrary_WIFI;

public class _Menu_ScnHndlr : MonoBehaviour
{
    public Text userno;
    public Text status;
    public Text debug;
    private bool _debugdisplay;
    private const int StatusUpdateCount = 10;
    private int _statusUpdateCount = 0;


    // Start is called before the first frame update
    void Start()
    {
        // Check if session is none. Then use default dummy patient sesson.
        if (AppData_WIFI.session == null)
        {
            AppData_WIFI.StartDummySession();
        }
        
        // Update controls.
        UpdateControls();

        // Start UDP server.
        StartMoBBoServer();

        // Disable debug display.
        _debugdisplay = false;
    }

    private void StartMoBBoServer()
    {
        UpdateStatus("Starting server.");
        try
        {
            MoBBoServer.Start();
        }
        catch
        {
            return;
        }
        if (MoBBoServer.started)
        {
            UpdateStatus($"[{MoBBoServer.server.GetNumberOfRegisteredDevices()}]");
            for (int i=0; i < MoBBoServer.server.AvailableID.Length; i++)
            {
                UnityEngine.Debug.Log($"{i} {MoBBoServer.server.AvailableID[i]}");
            }
        } else
        {
            UpdateStatus("Could not start.");
        }
    }

    // Update is called once per frame
    void Update()
    {
        // Handle keyboard inputs.
        HandleKeyboardInputs();

        // Update debug display.
        if (_debugdisplay)
        {
            // Do something only when the server is running.
            if (MoBBoServer.started)
            {
                // If the list of devices is empty, the clear all display.
                if (MoBBoServer.server.GetNumberOfRegisteredDevices() == 0)
                {
                    debug.text = "";
                }
                
                // Update current data text.
                UpdateDeviceDataDisplay();
            }
        } else
        {
            debug.text = "";
        }

        // Update status.
        _RegularStatusUpdate();
    }

    private void _RegularStatusUpdate()
    {
        _statusUpdateCount = (++_statusUpdateCount) % StatusUpdateCount;
        if (_statusUpdateCount == 0)
        {
            if (MoBBoServer.started)
            {
                UpdateStatus($"[{MoBBoServer.server.GetNumberOfRegisteredDevices()}]");
            }
            else
            {
                UpdateStatus("Could not start.");
            }
        }
    }

    private void UpdateDeviceDataDisplay()
    {
        // Update text display.
        debug.text = "";

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
        debug.text = _strBldr.ToString();
    }

    
    public string GetFormattedMoBoData(MoBBoDeviceUDP moboDev)
    {
        if (moboDev != null)
        {
            StringBuilder strBldr = new StringBuilder();
            //strBldr.Append($"[{moboDev.ID,3:X}]({moboDev.Time,8:N3}ms) ");
           
            strBldr.Append($"Force(Kg) [{moboDev.F1:N3} | {moboDev.F2:N3} | {moboDev.F3:N3} | {moboDev.F4:N3}] ");
            strBldr.Append($"Pos(cm) [{moboDev.X:N3} | {moboDev.Y:N3}] ");
            //strBldr.Append($"[{moboDev.ReservedByte1:X2}{moboDev.ReservedByte2:X2}{moboDev.ReservedByte3:X2}]");
            strBldr.Append($" @ {moboDev.DataRate:N1} fps");
            return strBldr.ToString();
        }
        return null;
    }

    private void HandleKeyboardInputs()
    {
        if (Input.GetKeyDown(KeyCode.F5))
        {
            // First stop the server.
            MoBBoServer.Stop();

            // Start UDP server.
            StartMoBBoServer();
        } else if (Input.GetKeyDown(KeyCode.F1))
        {
            _debugdisplay = !_debugdisplay;
        }
    }

    private void UpdateControls()
    {
        // Set user number.
        userno.text = $"User: {AppData_WIFI.subjHospNum}";
    }

    private void UpdateStatus(string msg)
    {
        string _servstate = MoBBoServer.started ? "Running" : "Stopped";
        status.text = $"{_servstate} | {msg}";
    }
}
