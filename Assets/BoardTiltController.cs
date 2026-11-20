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
using Color = UnityEngine.Color;

public class BoardTiltController : MonoBehaviour
{
    public float tiltSpeed = 15f; // Speed of tilt
    public float maxTiltAngle = 60f; // Maximum tilt angle in degrees
    public float weightLeft = 50f; // Weight percentage on the left leg (0-100)
    public float weightRight = 50f; // Weight percentage on the right leg (0-100)

    private Rigidbody2D ball_rigid_body; // Rigidbody for the ball
    public float ballSpeed; // Speed at which the ball rolls
    public float ballDrag = 2.5f; // Drag to slow down the ball
    public GameObject ball, optionscene; // The ball GameObject
    public float paddle_w;
    public float easySpeed = 100f;  
    public float easypaddle_w = 3.3f; // scaling width
    public float moderateSpeed = 300f;
    public float moderatepaddle_w= 0.3f;  //scaling width
    private Quaternion initialRotation;
    public int gamelevel  = 0;
    public Text leveltext;
    public float tiltAngle;
    public float newPaddleWidth;

    void Start()
    {
        // Store the initial rotation of the board
        initialRotation = transform.rotation;
        Directory.CreateDirectory(login_handlr.ball_roller_rawdata);
        Directory.CreateDirectory(login_handlr.ball_roller_gamedata);


        // Get the Rigidbody2D component from the ball
        if (ball != null)
        {
            ball_rigid_body = ball.GetComponent<Rigidbody2D>();
            if (ball_rigid_body != null)
            {
                ball_rigid_body.drag = ballDrag; // Set drag to control ball speed
            }
            else
            {
                //Debug.LogError("Rigidbody2D component missing on the ball GameObject.");
            }
        }
        else
        {
            //Debug.LogError("Ball GameObject is not assigned in the Inspector.");
        }

       
    }

    void Update()
    {
        // Update weight values from MoBBoServer
        weightLeft = MoBBoServer.W_player1;
        weightRight = MoBBoServer.W_player2;

        // Calculate tilt angle based on weight difference
        float weightDifference = weightRight - weightLeft;
        tiltAngle = Mathf.Clamp(weightDifference, -100, 100) / 100 * maxTiltAngle;

        // Smoothly tilt the board
        Quaternion targetRotation = Quaternion.Euler(0, 0, -tiltAngle); // Z-axis rotation
        transform.rotation = Quaternion.Lerp(transform.rotation, targetRotation, Time.deltaTime * tiltSpeed);

        // Apply force to the ball based on the tilt
        if (ball_rigid_body != null)
        {
            Vector2 tiltDirection = new Vector2(Mathf.Sin(Mathf.Deg2Rad * tiltAngle), -Mathf.Cos(Mathf.Deg2Rad * tiltAngle));
      
            
            ball_rigid_body.AddForce(tiltDirection * ballSpeed, ForceMode2D.Force);
          
        }
        if (Input.GetKeyDown(KeyCode.UpArrow))
        {
            IncrementLevel();
        }
        if (Input.GetKeyDown(KeyCode.DownArrow))
        {
            DecrementLevel();
        }
    }
    public void btnGoBack_Click()
    {
        SceneManager.LoadScene("2mb");
    }


    // Optional: Call this method to update weight percentages dynamically
    public void UpdateWeight(float left, float right)
    {
        weightLeft = left;
        weightRight = right;
    }
   
  
    private float GetPaddleWidth()
    {
        RectTransform rectTransform = GetComponent<RectTransform>();
        return rectTransform.localScale.x; // Returns the current width of the paddle
    }

    private void SetBallForce(float ballspeed)
    {
        ballSpeed = ballspeed;   // Update ball speed if needed elsewhere
           // Update spawn rate dynamically
    }
    private void SetPaddleWidth(float newWidth)
    {
        // Get the RectTransform component attached to the GameObject
        RectTransform rectTransform = GetComponent<RectTransform>();

        // Modify the sizeDelta to set the new width
        // Modify the sizeDelta to set the new width
        Vector3 currentSize = rectTransform.localScale;

        // Update the width while keeping the current height the same
        rectTransform.localScale = new Vector3(newWidth, currentSize.y, currentSize.z);
    }
    private void IncrementLevel()
    {
        // Increment ball speed and decrease paddle size
        if (gamelevel < 10) // Cap level at 10
        {
            ballSpeed = Mathf.Clamp(ballSpeed + 20f, easySpeed, moderateSpeed);
            newPaddleWidth = Mathf.Clamp(GetPaddleWidth() - 0.3f, moderatepaddle_w, easypaddle_w);
            SetPaddleWidth(newPaddleWidth);

            gamelevel++; // Increment game level
            UpdateLevelText(); // Update UI
            //Debug.Log($"Increased Level: Game Level = {gameLevel}, Ball Speed = {ballSpeed}, Paddle Width = {newPaddleWidth}");
        }
        else
        {
            //Debug.Log("Reached maximum level.");
        }
    }

    private void DecrementLevel()
    {
        // Decrement ball speed and increase paddle size
        if (gamelevel > 0) // Minimum level is 0
        {
            ballSpeed = Mathf.Clamp(ballSpeed - 20f, easySpeed, moderateSpeed);
            newPaddleWidth = Mathf.Clamp(GetPaddleWidth() + 0.3f, moderatepaddle_w, easypaddle_w);
            SetPaddleWidth(newPaddleWidth);
            gamelevel--; // Decrement game level
            UpdateLevelText(); // Update UI
            //Debug.Log($"Decreased Level: Game Level = {gameLevel}, Ball Speed = {ballSpeed}, Paddle Width = {newPaddleWidth}");
        }
        else
        {
           // Debug.Log("Reached minimum level.");
        }
    }
    private void UpdateLevelText()
    {
        if (leveltext != null)
        {
            leveltext.text = $"Level: {gamelevel}";
        }
        else
        {
          //  Debug.LogError("Level Text UI element is not assigned in the Inspector.");
        }
    }
}
