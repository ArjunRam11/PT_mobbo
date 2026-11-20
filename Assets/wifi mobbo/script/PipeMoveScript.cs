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
using Debug = UnityEngine.Debug;

public class PipeMoveScript : MonoBehaviour
{
    public float moveSpeed;
    public float deadZone = -45f; // The position where the pipe is destroyed
    public float p_movespeed_max = 12f;
    public float p_movespeed_min = 2f;
    public float p_moveSpeed = 2f;
    public int gamelevel_ = 0;



   

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.UpArrow))
        {
            Incrementspeed();
        }
        if (Input.GetKeyDown(KeyCode.DownArrow))
        {
            Decrementspeed();
        }

        // Move the assigned pipe GameObject
        transform.position += Vector3.left * p_moveSpeed * Time.deltaTime;

            // Check if the pipe has moved past the deadZone
            if (transform.position.x < deadZone)
            {
                Debug.Log("Pipe Destroyed");
                Destroy(gameObject); // Destroy the assigned pipe GameObject
            }

        
    }

    private void Incrementspeed()
    {
        // Increment spawn rate and decrease height offset
        if (gamelevel_ < 10) // Maximum level cap
        {
            p_moveSpeed = Mathf.Clamp(p_moveSpeed + 1f, p_movespeed_min, p_movespeed_max);

           gamelevel_++; // Increment level
         
        }
    }

    private void Decrementspeed()
    {
        // Decrease spawn rate and increase height offset
        if (gamelevel_ > 0) // Minimum level cap
        {
       
            p_moveSpeed = Mathf.Clamp(p_moveSpeed - 1f, p_movespeed_min, p_movespeed_max);

         gamelevel_--; // Decrement level
        
        }
    }



}
