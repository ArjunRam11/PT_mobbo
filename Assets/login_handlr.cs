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

public class login_handlr : MonoBehaviour
{ 
    public Button login,signup;
    public GameObject login_popup,signin_popup;
    public bool login_on = false, signup_on = false;
   // public InputField usernameInput_s;
    //public InputField passwordInput_s;
    public Text messageText;
    public  InputField usernameInput_s, usernameInput_l, Name, Age, Gender, diagnosis, passwordInput_l,amp_type,amp_side, trial_duration_ip;
    public static string new_path_signin, MOBBOmasterlist, session_folder,session_starter_name, openfoldername, age_,name_, cond_, gender_, hnum_,amp_side_,amp_type_, gamedata_folder, rawdata_folder, boardset_up_folder,assess_folder;
    public string searchValue_Mobbo;  
    private List<string> savedUsernames = new List<string>();
    public static string pingpong_rawdata, pingpong_gamedata;
    public static string Floppybird_rawdata,Floppybird_gamedata, ball_roller_gamedata, ball_roller_rawdata, stepper_rawdata,stepper_gamedata;
    public static string Space_rawdata, Space_gamedata;
    public static string file_path_root;
    public static int trial_duration=0;


    // Start is called before the first frame update
    void Start()
    {
        login_popup.SetActive(false);
        signin_popup.SetActive(false);

        //MOBBOmasterlist = "E:\\ARJUN\\PHD\\arjuun unity\\game repositories\\unity2D\\intro_setup\\w_mobbo_updated_2\\w_mobbo\\w_mobbo\\data\\MOBBO_MASTERLIST.csv";
        //new_path_signin = "E:\\ARJUN\\PHD\\arjuun unity\\game repositories\\unity2D\\intro_setup\\w_mobbo_updated_2\\w_mobbo\\w_mobbo\\data\\Trail_data";
        file_path_root = Application.dataPath;
        UnityEngine.Debug.Log(file_path_root + "");
        MOBBOmasterlist = file_path_root + "\\data\\MOBBO_MASTERLIST.csv";
        new_path_signin = file_path_root + "\\data\\Trail_data";
        

    }
    public void login_screen()
    {
        login_popup.SetActive(true);
        login_on = true;
        loginpop_up();

    }
    public void Signin_screen()
    {
        signin_popup.SetActive(true);
        signup_on = true;
        loginpop_up();
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKey(KeyCode.Return))
        {
            Lookforexistinguser();
            create_session_folders();
            //  

            //UnityEngine.Debug.Log("Return key was pressed.");
        }
    }

    //private string savedUsernameKey = "SavedUsername";


    public void Login_____()
    {


        openfoldername = usernameInput_l.text;
        searchValue_Mobbo = usernameInput_l.text;
        session_starter_name = usernameInput_l.text;
        age_ = Age.text; gender_ = Gender.text; cond_ = diagnosis.text; hnum_ = usernameInput_l.text; amp_side_ = amp_side.text;amp_type_ = amp_type.text;


        // UnityEngine.Debug.LogError("Error reading CSV file: " + openfoldername);
        //if (AppData_WIFI.session == null)

        //{
        //    //AppData_WIFI.StartDummySession();
        //    AppData_WIFI.StartSession(searchValue_Mobbo);
        //}

        Lookforexistinguser();
        create_session_folders();

       
    }

    public void SignUp_____()
    {
        string inputUsername_sign = usernameInput_s.text;

       // UnityEngine.Debug.Log("Error reading CSV file: ");
        Directory.CreateDirectory(new_path_signin+inputUsername_sign);
        messageText.text = "Sign up successful!";
        writetoMOBBO_userlist();


    }
    public void create_session_folders()
    {
 
        searchValue_Mobbo = usernameInput_l.text;
 
        session_folder = new_path_signin + searchValue_Mobbo + "\\" + "Session" + DateTime.Now.ToString("Dyyyy-MM-dd_THH-mm-ss");
        gamedata_folder = Path.Combine(session_folder, "Gamedata");
        rawdata_folder = Path.Combine(session_folder, "Rawdata");
        boardset_up_folder = Path.Combine(session_folder, "Board_setup");
        assess_folder= Path.Combine(session_folder, "assessment");
        pingpong_rawdata = Path.Combine(login_handlr.rawdata_folder, "pingpong.rawdata"); // to save the rawdata of the pingpong game
        pingpong_gamedata = Path.Combine(login_handlr.gamedata_folder, "pingpong.gamedata");
        Floppybird_rawdata = Path.Combine(login_handlr.rawdata_folder, "Floppybird.rawdata");
        ball_roller_rawdata = Path.Combine(login_handlr.rawdata_folder, "ball_roller.rawdata");
        Floppybird_gamedata = Path.Combine(login_handlr.gamedata_folder, "Floppybird.gamedata");
        ball_roller_gamedata = Path.Combine(login_handlr.gamedata_folder, "ball_roller.gamedata");
        Space_rawdata = Path.Combine(login_handlr.rawdata_folder, "Space.rawdata");
        Space_gamedata = Path.Combine(login_handlr.gamedata_folder, "Space.gamedata");
        stepper_gamedata = Path.Combine(login_handlr.gamedata_folder, "stepper.gamedata");
        stepper_rawdata = Path.Combine(login_handlr.rawdata_folder, "stepper.rawdata");
        //Directory.CreateDirectory(pingpong_rawdata);
        //Directory.CreateDirectory(pingpong_gamedata);
        //Directory.CreateDirectory(Floppybird_rawdata);
        //Directory.CreateDirectory(Floppybird_gamedata);
        //Directory.CreateDirectory(ball_roller_rawdata);
        //Directory.CreateDirectory(ball_roller_gamedata);
        //Directory.CreateDirectory(Space_rawdata);
        //Directory.CreateDirectory(Space_gamedata);
        //Directory.CreateDirectory(stepper_gamedata);
        //Directory.CreateDirectory(stepper_rawdata);
        Directory.CreateDirectory(session_folder);
        Directory.CreateDirectory(gamedata_folder);
        Directory.CreateDirectory(rawdata_folder);
        Directory.CreateDirectory(boardset_up_folder);
        Directory.CreateDirectory(assess_folder);


    }
    private void writetoMOBBO_userlist()
    {
         
        string existingContent;
        try
        {
            using (StreamReader reader = new StreamReader(MOBBOmasterlist))
            {
                existingContent = reader.ReadToEnd();
            }
        }
        catch (IOException e)
        {
            UnityEngine.Debug.LogError("Error reading CSV file: " + e.Message);
            return;
        }

        string _hosp_no = usernameInput_s.text;
        string _name = Name.text;
        string _gender = Gender.text;
        string _age = Age.text;
        string _diag = diagnosis.text;
        string _amp_s = amp_side.text;
        string _amp_t = amp_type.text;

        // Append the new data to the existing CSV contents
        string newcontent =_hosp_no +","+_name+ ","+ _gender+"," + _age +","+ _diag+","+_amp_s+","+_amp_t;
        UnityEngine.Debug.Log(newcontent);
        string updatedContent = existingContent + "\n" +newcontent;

        // Write the updated contents back to the CSV file
        try
        {
            using (StreamWriter writer = new StreamWriter(MOBBOmasterlist))
            {
                writer.Write(updatedContent);
            }

           UnityEngine.Debug.Log("Data appended to CSV file successfully!");
        }
        catch (IOException e)
        {
            UnityEngine.Debug.LogError("Error writing to CSV file: " + e.Message);
        }

    }



    private void Lookforexistinguser()
    {
        
        // Check if the file exists before reading
        if (!File.Exists(MOBBOmasterlist))
        {
            UnityEngine.Debug.LogError("CSV file does not exist!");
            return;
        }
        try
        {
            using (StreamReader reader = new StreamReader(MOBBOmasterlist))
            {
                // Read and ignore the first line (header)
                reader.ReadLine();

                // Loop through the rest of the lines in the CSV file
                while (!reader.EndOfStream)
                {
                    string line = reader.ReadLine();
                    string[] values = line.Split(',');

                    // Now you can access individual columns in the row using values[0], values[1], etc.
                    // For example, if you want to check a specific column for the searchValue:
                    // Assuming the value you want to check is in the second column (index 1)
                    string columnValue = values[0]; // Change the index according to your CSV structure

                  
                    if (searchValue_Mobbo!=null)
                    {
                        if (columnValue == searchValue_Mobbo)
                        {
                           // UnityEngine.Debug.Log("Found the value: " + searchValue_Mobbo);
                            SceneManager.LoadScene("2mb");
                            messageText.text = "Login successful!";                  // You can perform further actions here if needed
                            trial_duration = int.Parse(trial_duration_ip.text);
                            UnityEngine.Debug.Log("trial_)d" + trial_duration);
                            break; // If you want to stop searching after the first occurrence
                        }
                    }
                }
            }
        }
        catch (IOException e)
        {
            UnityEngine.Debug.LogError("Error reading CSV file: " + e.Message);
        }

    }
 




    public void SignUp()
    {
        string inputUsername = usernameInput_s.text;
        //string inputPassword = passwordInput_s.text;

        if (savedUsernames.Contains(inputUsername))
        {
            messageText.text = "Username already exists. Please choose a different username.";
            return;
        }

        savedUsernames.Add(inputUsername);
      //  PlayerPrefs.SetString(inputUsername, inputPassword);
       // SaveUsernames();

        messageText.text = "Sign up successful!";
    }
    public void loginpop_up()
    {
        if (login_on)
        {
            signin_popup.SetActive(false);
            login_on = false;

        }
        if (signup_on)
        {
            login_popup.SetActive(false);
            signup_on = false;
        }
    }
    public void exit_app()
    {
        Application.Quit();
    }


}
