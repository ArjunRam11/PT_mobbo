
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
using System.Net.NetworkInformation;
using UnityEditor;


public class game_pong_ball : MonoBehaviour
{
    public GameObject pingball;
    public GameObject resett, start_game_scene;
    public Rigidbody pgb;
    public float Timer = 0f;
    public Button start_game;
    public int score_int_p1 = 0;
    public int score_int_p2 = 0;
    public Text Interval_text;
    public Text player1_score;
    public Text player2_score;
    public static bool score_inc_p1 = false;
    public static bool score_inc_p2 = false;

    public static bool stop_players = false;
    public Text DSCORE1;
    public Text DSCORE2;
    public Text gameover;

    public static bool hitball_right_p1 = false;
    public static bool hitball_centre_p1 = false;
    public static bool hitball_left_p1 = false;
    public static bool hitball_right_p2 = false;
    public static bool hitball_centre_p2 = false;
    public static bool hitball_left_p2 = false;
    public float ball_p1_diff;
    public float ball_p2_diff;
    public float paddleSpeed = 100f;
    public Text repetition_count;
    public int count = 1;

    public static bool stopwatch = false;
    public static bool reset_clck = false;
    public float timer__;
    public Text won;
    public GameObject player_2;
    public Transform comp_player, ping_balltransform;
    public static bool reset = false;
    public Text TIMER;
    public Transform bound_right;
    public Transform bound_left;
    public Text reset_timer;
    public float reset_time;
    public Renderer Br_Renderer;
    public Renderer Bl_Renderer;
    public Material onhit_boundary_material;
    public Material exist_boundary_material;
    public Renderer lowerboundary_colorchanger, upperboundary_colorchanger;
    public GameObject bound1;
    public GameObject bound2;
    public Transform player;
    public string game_time, ball_pos_x, ball_pos_y, player_paddle_x, player_paddle_y, comp_paddle_x, comp_paddle_y;
    public List<string> game_data = new List<string>();
    public bool is_header_written = false;

    public bool game_started = false;

    private Vector3 velocity = Vector3.zero; // Smoothing variable

    void Start()
    {
        timer__ = 3f;
        reset_time = 7f;
        start_game_scene.SetActive(true);

        pgb = pingball.GetComponent<Rigidbody>();
        pingball.GetComponent<Transform>().position = new Vector3(-67.1f, 0f, 0);
        resett.SetActive(false);
        player_2.GetComponent<Transform>().position = new Vector3(-67.1f, 25.3f, 0);

        player = GameObject.FindGameObjectWithTag("player1").transform;
        comp_player = GameObject.FindGameObjectWithTag("player2").transform;
        ping_balltransform = GameObject.FindGameObjectWithTag("target").transform;

        bound1 = GameObject.FindGameObjectWithTag("y_left");
        bound2 = GameObject.FindGameObjectWithTag("y_right");
        Bl_Renderer = bound1.GetComponent<Renderer>();
        Br_Renderer = bound2.GetComponent<Renderer>();

        rawdata_start_saving();
    }
    public void rawdata_start_saving()
    {
        string test_scene_data_folder = login_handlr.pingpong_rawdata + "//" + DateTime.Now.ToString("Dyyyy-MM-dd_THH-mm-ss");
        UnityEngine.Debug.Log("started saving file at" + test_scene_data_folder);
        MoBBoServer.server.StartLogging(test_scene_data_folder);
    }


    public void saveping_gamedata()
    {
        using (StreamWriter file = new StreamWriter(Path.Combine(login_handlr.pingpong_gamedata, "ping game_data.csv"), true))
        {
            if (!is_header_written)
            {
                file.WriteLine("Time,ball_x,ball_y,player_paddle_x,player_paddle_y,comp_paddle_x,comp_paddle_y");
                is_header_written = true;
            }
            foreach (string gamedata in game_data)
            {
                file.WriteLine(gamedata);
            }
        }
    }

    public void move_paddle()
    {
        // Smooth paddle movement with Lerp
        float currSpeed = Mathf.Clamp(paddleSpeed - (timer__ / 90 * paddleSpeed * 0.3f), 0.6f * paddleSpeed, paddleSpeed);
        currSpeed = 20;

        if (pgb.velocity.y > 0)
        {
            float targetPos = Mathf.Clamp(pgb.position.x, player_2.transform.position.x - 3f, player_2.transform.position.x + 3f); // Example movement range
            player_2.transform.position = Vector3.SmoothDamp(player_2.transform.position, new Vector3(targetPos, player_2.transform.position.y, player_2.transform.position.z), ref velocity, 0.3f);
        }

        if (player_2.transform.position.x > 13)
        {
            player_2.transform.position = new Vector3(transform.position.x, 13, 0);
        }
        else if (player_2.transform.position.y < -13)
        {
            player_2.transform.position = new Vector3(transform.position.x, -13, 0);
        }
    }

    public void startgame()
    {
        start_game_scene.SetActive(false);

        float rand = UnityEngine.Random.Range(0f, 2f);
        float y_vel_1 = UnityEngine.Random.Range(5f, 10f);
        float y_vel_2 = UnityEngine.Random.Range(-5f, -10f);
        stopwatch = true;

        if (rand <= 1)
        {
            pgb.velocity = new Vector3(1f, y_vel_1, 0);
        }
        if (rand <= 2 && rand > 1)
        {
            pgb.velocity = new Vector3(-1f, y_vel_2, 0);
        }
        game_started = true;
    }

    private void OnTriggerEnter(Collider collision)
    {
        float x_ball = pingball.GetComponent<Transform>().position.x;

        if (collision.gameObject.tag == "player1")
        {
            float x1 = collision.gameObject.transform.position.x;
            ball_p1_diff = x1 - x_ball;
            pgb.velocity = new Vector3(-ball_p1_diff * 2f, 20f, 0);
        }

        if (collision.gameObject.tag == "player2")
        {
            float x2 = collision.gameObject.transform.position.x;
            ball_p2_diff = x2 - x_ball;
            pgb.velocity = new Vector3(-ball_p2_diff * 2f, -20f, 0);
        }

        if (collision.gameObject.tag == "x_up")
        {
            var bound_up = collision.GetComponent<MeshRenderer>().material;
            bound_up.SetColor("_color", UnityEngine.Color.white);
            score_inc_p1 = true;
            reset = true;
            reset_clck = true;
            score_update();
            resett.SetActive(true);
            stop_players = true;
            DSCORE1.text = score_int_p1.ToString();
            stopwatch = true;
        }

        if (collision.gameObject.tag == "x_down")
        {
            var bound_down = collision.GetComponent<MeshRenderer>().material;
            bound_down.SetColor("_color", UnityEngine.Color.white);
            score_inc_p2 = true;
            lowerboundary_colorchanger.material = onhit_boundary_material;
            reset = true;
            reset_clck = true;
            score_update();
            resett.SetActive(true);
            stop_players = true;
            DSCORE2.text = score_int_p2.ToString();
            stopwatch = true;
        }

        if (collision.gameObject.tag == "y_left")
        {
            Bl_Renderer.material.color = UnityEngine.Color.green;
        }
        if (collision.gameObject.tag == "y_right")
        {
            Br_Renderer.material.color = UnityEngine.Color.green;
        }
    }

    public void score_update()
    {
        if (score_inc_p1)
        {
            score_int_p1 += 1;
            score_inc_p1 = false;
            player1_score.text = score_int_p1.ToString();
        }
        if (score_inc_p2)
        {
            score_int_p2 += 1;
            score_inc_p2 = false;
            player2_score.text = score_int_p2.ToString();
        }

        gameover_();
    }

    public void gameover_()
    {
        if (score_int_p1 == 5f)
        {
            won.text = " YOU WIN ";
        }
        if (score_int_p2 == 5f)
        {
            won.text = "COMPUTER WIN ";
        }

        if (score_int_p1 == 5f || score_int_p2 == 5f)
        {
            gameover.text = "GAMEOVER";
            stop_players = true;
        }
    }

    public void start_afterrestart()
    {
        resett.SetActive(false);
        pgb.position = new Vector3(-58.4f, -7.3f, 0);
        lowerboundary_colorchanger.material = exist_boundary_material;
        float rand = UnityEngine.Random.Range(0f, 2f);
        float y_vel_1 = UnityEngine.Random.Range(5f, 10f);
        float y_vel_2 = UnityEngine.Random.Range(-5f, -10f);
        stopwatch = true;

        if (rand <= 1)
        {
            pgb.velocity = new Vector3(1f, y_vel_1, 0);
        }
        if (rand <= 2 && rand > 1)
        {
            pgb.velocity = new Vector3(-1f, y_vel_2, 0);
        }
    }
}


