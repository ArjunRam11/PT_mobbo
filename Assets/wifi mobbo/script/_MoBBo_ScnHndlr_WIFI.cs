using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using System;

public class _MoBBo_ScnHndlr : MonoBehaviour
{

    public Dropdown hospNums;
    public Button startBtn;
    public Button createnewBtn;

    // Use this for initialization
    void Start()
    {
        Update_Controls();
        startBtn.GetComponent<Button>().onClick.AddListener(StartBtn_Clicked);
    }

    // Update is called once per frame
    void Update()
    {
        // Handle keyboard inputs.
        HandleKeyboardInputs();
    }

    private void HandleKeyboardInputs()
    {
        if (Input.GetKeyDown(KeyCode.D))
        {
            SceneManager.LoadScene("MoBBoDiagnostics");
        }
    }

    private void Update_Controls()
    {
        // Get the list of all subjects.
        hospNums.options.Clear();
        foreach (string subj in AppConfig_WIFI.Get_Subjects_List())
        {
            hospNums.options.Add(new Dropdown.OptionData() { text = subj });
        }
        hospNums.RefreshShownValue();
    }

    // Login Button Clicked
    public void StartBtn_Clicked()
    {
        UnityEngine.Debug.Log(hospNums.options[hospNums.value].text);
        // Start session.
        AppData_WIFI.StartSession(hospNums.options[hospNums.value].text);
        // Go to Game menu
        AppData_WIFI.mGrid = null;
        SceneManager.LoadScene("MoBBoMenu");
    }

    // New user button clicked.
    public void NewUserBtn_Clicked()
    {
        // Load the new user form scene.
        SceneManager.LoadScene("NewUser");
    }
}
