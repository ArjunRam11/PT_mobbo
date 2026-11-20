using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;

public class timer : MonoBehaviour
{
    [SerializeField] TextMeshProUGUI timerText;
    [SerializeField]  public float remTime;
    [SerializeField] LogicScript logic;
    private bool isTimerActive = false;

    // Update is called once per frame
    void Update()
    {
        if (remTime > 0)
        {
            remTime -= Time.deltaTime;
        }
        else if (remTime < 0)
        {
            remTime = 0;
            logic.gameOver();
            timerText.color = Color.red;
            pause();
        }
        int sec = Mathf.FloorToInt(remTime % 60);
        timerText.text = string.Format("{0:00}", sec);
    }

    public void pause()
    {
        Time.timeScale = 0; 
    }
    public void StopTimer()
    {
        remTime = 0; 
        pause(); 
    }
    }
