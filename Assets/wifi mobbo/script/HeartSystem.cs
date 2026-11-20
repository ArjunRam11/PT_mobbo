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

public class HeartSystem : MonoBehaviour
{
    [SerializeField] private Image[] heartImages; // Array of heart images in the UI
    [SerializeField] private Sprite fullHeart;
    [SerializeField] private Sprite emptyHeart;
    private int maxLives = 5; // Total number of hearts
    public int currentLives;
    public PipeSpawnScript pipe__;
    private LogicScript logic;

    private void Start()
    {
        currentLives = maxLives;
        logic = GameObject.FindGameObjectWithTag("logic_object").GetComponent<LogicScript>();
        UpdateHeartUI();
    }

    public void LoseLife()
    {
        if (currentLives > 0)
        {
            currentLives--;
            UpdateHeartUI();
            if (currentLives <= 0)
            {
                pipe__.StopTrial(); // Call gameOver() in LogicScript
            }
        }
    }

    public void UpdateHeartUI()
    {
        for (int i = 0; i < heartImages.Length; i++)
        {
            heartImages[i].sprite = i < currentLives ? fullHeart : emptyHeart;
        }
    }
}
