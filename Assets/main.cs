using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI; // Add this if using Unity UI's Text
// using TMPro; // Uncomment this if using TextMeshProUGUI

public class main : MonoBehaviour
{
    public int score;
    public bool GameOver;
    public Transform title; // Corrected from "titlr" to "title"
    public Text scoreboard; // Ensure you have assigned this in the Inspector
    // public TextMeshProUGUI scoreboard; // Uncomment this if using TextMeshPro

    void Start()
    {
        score = 0;
        GameOver = false;
        scoreboard.text = "0";
    }

    void Update()
    {
        if (GameOver == true)
        {
            title.localPosition = new Vector3(0f, 0f, 0f);
            GameOver = false;
        }
        if (Input.GetKey(KeyCode.B))
        {
            SceneManager.LoadScene("2mb");
            //rawdata_stop_saving();
        }
    }
    public void btnGoBack_Click()
    {
        SceneManager.LoadScene("2mb");
    }

    public void ScoreAdd()
    {
        score++;
        UnityEngine.Debug.Log("Score updated to: " + score);
        scoreboard.text = score.ToString();
    }

    public void NewGame()
    {
        SceneManager.LoadScene(0); // Corrected from "ScenManager" to "SceneManager"
    }
}
