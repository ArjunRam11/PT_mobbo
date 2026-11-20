using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using MoBBoLibrary_WIFI;
using UnityEngine.SceneManagement;

[System.Serializable]
public class BoundaryDefault
{
    public float xMin, xMax, zMin, zMax;
}

public class PlayerControllerDefault : MonoBehaviour
{
    public float speed;
    public float tilt;
    public BoundaryDefault boundary;

    public GameObject shot;
    public Transform shotSpawn;
    public float fireRate = 2f;
    public static float playSize;
    private Rigidbody rb;
    private float nextFire;
    static float topbound = 17F;
    static float bottombound = -17F;

    public int MovingAverageLength = 10;
    private int count;
    private float movingAverage;

    private string filePath;

    void Start()
    {
        rb = GetComponent<Rigidbody>();
        playSize = 30f;
        rawdata_start_saving();

        // Set up the file path
        string assessFolder = login_handlr.Space_gamedata; // Ensure this is accessible in your script
        filePath = Path.Combine(assessFolder, "Space_gamedata.csv");

        // Optionally, create the file and write the header if not already created
        if (!File.Exists(filePath))
        {
            using (StreamWriter writer = new StreamWriter(filePath, true))
            {
                writer.WriteLine("Time,X,Y,Z");
            }
        }
    }

    void Update()
    {
        if (Time.time > nextFire)
        {
            nextFire = Time.time + fireRate - 0.5f;

            Instantiate(shot, shotSpawn.position, shotSpawn.rotation);
            GetComponent<AudioSource>().Play();
        }
        if (Input.GetKey(KeyCode.B))
        {
            SceneManager.LoadScene("2mb");
            rawdata_stop_saving();
        }
        PlayerControllerInput();
    }

    private void StorePosition(Vector3 position)
    {
        string positionData = Time.time + "," + position.x + "," + position.y + "," + position.z + "\n";
        File.AppendAllText(filePath, positionData);
    }

    public void rawdata_start_saving()
    {
        string test_scene_data_folder = login_handlr.Space_rawdata + "//" + DateTime.Now.ToString("Dyyyy-MM-dd_THH-mm-ss");
        UnityEngine.Debug.Log("started saving file at" + test_scene_data_folder);
        MoBBoServer.server.StartLogging(test_scene_data_folder);
    }

    public void rawdata_stop_saving()
    {
        if (MoBBoServer.server.isLogging)
        {
            UnityEngine.Debug.Log("Stopped logging");
            MoBBoServer.server.StopLogging();
        }
    }

    public void PlayerControllerInput()
    {
        float left_limit = PlayerPrefs.GetFloat("left_limit");
        float right_limit = PlayerPrefs.GetFloat("Right_limit");

        float _new_dist = Mathf.Abs(right_limit - left_limit);

        float U_org = (topbound + bottombound) / 2f;
        float x_org = (left_limit + right_limit) / 2;

        float new_x = U_org + ((MoBBoServer.COP.x - x_org) / (_new_dist)) * (Mathf.Abs(topbound - bottombound));
        rb.position = new Vector3(Mathf.Clamp(new_x, -15f, 15f), 0, 0);
        rb.rotation = Quaternion.Euler(0.0f, 0.0f, rb.velocity.x * -tilt);
    }

    public static float Angle2Screen(float angle)
    {
        float AngMin = PlayerPrefs.GetFloat("Handle Ang Min");
        float AngMax = PlayerPrefs.GetFloat("Handle Ang Max");

        return Mathf.Clamp(-15f + ((angle - AngMin) * (playSize) / (AngMax - AngMin)), bottombound, topbound);
    }

    public float MovingAverage(float values)
    {
        count++;

        if (count > MovingAverageLength)
        {
            movingAverage = movingAverage + (values - movingAverage) / (MovingAverageLength + 1);
        }
        else
        {
            movingAverage += values;

            if (count == MovingAverageLength)
            {
                movingAverage = movingAverage / count;
            }
        }
        return movingAverage;
    }
}
