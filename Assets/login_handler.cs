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
public class login_handler : MonoBehaviour
{
    public InputField user_name;
    public InputField condition;
    public InputField age;
    public InputField gender;

    public Button login;
    public Button signup;
    public GameObject login_popup;
    public GameObject signin_popup;
    public bool login_on = false;
    public bool signup_on = false;

    public InputField passwordInput_l;
    public  static InputField usernameInput_s, usernameInput_l;
    public InputField passwordInput_s;
    public Text messageText;
    public string new_path_signin;
 

    private string savedPasswordKey = "SavedPassword";
    private List<string> savedUsernames = new List<string>();

    // Start is called before the first frame update
    void Start()
    {
        LoadSavedUsernames();

        
        login_popup.SetActive(false);
        signin_popup.SetActive(false);  

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
        
    }
   
    private string savedUsernameKey = "SavedUsername";
   

    public void Login_____()
    {
      
        string savedUsername = PlayerPrefs.GetString(savedUsernameKey);
        string savedPassword = PlayerPrefs.GetString(savedPasswordKey);

        string inputUsername = usernameInput_l.text;
        string inputPassword = passwordInput_l.text;

        if (AppData_WIFI.session == null)
        {
            AppData_WIFI.StartDummySession();
        }

        if (inputUsername.Equals(savedUsername) && inputPassword.Equals(savedPassword))
        {
            SceneManager.LoadScene("2mb");
            messageText.text = "Login successful!";
            usernameInput_l.text = string.Empty;
            passwordInput_l.text = string.Empty;
            
        }
        else
        {
            if(inputUsername!=savedUsername)
            {
                usernameInput_l.text = string.Empty;
                messageText.text = "Invalid username";


            }
            if(inputPassword!= savedPassword)
            {
                passwordInput_l.text = string.Empty;
                messageText.text = "Invalid password";
            }
        }
    }

    public void SignUp_____()
    {
        string inputUsername_sign = usernameInput_s.text;
        string inputPassword_sign = passwordInput_s.text;

        PlayerPrefs.SetString(savedUsernameKey, inputUsername_sign);
        PlayerPrefs.SetString(savedPasswordKey, inputPassword_sign);
        new_path_signin = "\"D:\\CMC\\w_mobbo\\w_mobbo\\data\\Trail_data\"" + inputUsername_sign;
        Directory.CreateDirectory(new_path_signin);
        //Directory.CreateDirectory(Path.Combine(new_path_signin, "FORENOON_SESSION"));
        //Directory.CreateDirectory(Path.Combine(new_path_signin, "AFTERNOON_SESSION"));

        messageText.text = "Sign up successful!";
        usernameInput_s.text = string.Empty;
        passwordInput_s.text = string.Empty;
        messageText.text = string.Empty;


    }
    public void create_date_time_folders()
    {
        //DateTime currentime = DateTime.Now;
        //int hour = currentime.Hour;
        //if(hour<12f&& hour>5f)
        
            Directory.CreateDirectory(Path.Combine(new_path_signin, "FORENOON_SESSION"));
       
        //else
        //{
        //    Directory.CreateDirectory(Path.Combine(new_path_signin, "AFTERNOON_SESSION"));
        //}
        
    }


    private void LoadSavedUsernames()
    {
        if (PlayerPrefs.HasKey(savedPasswordKey))
        {
            string savedUsernamesString = PlayerPrefs.GetString(savedPasswordKey);
            savedUsernames = new List<string>(savedUsernamesString.Split(';'));
        }
    }

    private void SaveUsernames()
    {
        string savedUsernamesString = string.Join(";", savedUsernames);
        PlayerPrefs.SetString(savedPasswordKey, savedUsernamesString);
        PlayerPrefs.Save();
    }

    public void SignUp()
    {
        string inputUsername = usernameInput_s.text;
        string inputPassword = passwordInput_s.text;

        if (savedUsernames.Contains(inputUsername))
        {
            messageText.text = "Username already exists. Please choose a different username.";
            return;
        }

        savedUsernames.Add(inputUsername);
        PlayerPrefs.SetString(inputUsername, inputPassword);
        SaveUsernames();

        messageText.text = "Sign up successful!";
    }
    public void loginpop_up()
    {
        if (login_on)
        {
            signin_popup.SetActive(false);
            login_on = false;
        
        }
        if(signup_on)
        {
            login_popup.SetActive(false);
            signup_on = false;
        }
    }


}
