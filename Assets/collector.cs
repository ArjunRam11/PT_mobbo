using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class collector : MonoBehaviour
{
    Transform tr;
    /*public Rigibody2D player_1;*/// Start is called before the first frame update
    void Start()
    {
        tr = GetComponent<Transform>();
    }

    // Update is  called once per frame
    void FixedUpdate()
    {
        //if (Input.GetKey("right") == true)
        //{
        //    if (tr.position.x < 8f) tr.position += new Vector3(0.2f, 0f, 0f);
        //}
        //if (Input.GetKey("left") == true)
        //{
        //    if (tr.position.x > -8f) tr.position += new Vector3(-0.2f, 0f, 0f);
        //}
        float gamemax = 8f;
        float gamemin = -8f;
        float left_limit = PlayerPrefs.GetFloat("left_limit");
        float right_limit = PlayerPrefs.GetFloat("Right_limit");

        float cop_x = MoBBoServer.COP.x;
        float boardcop = (gamemax - gamemin) / (right_limit - left_limit) * (cop_x - left_limit) + gamemin;
        transform.position = new Vector3(Mathf.Clamp(boardcop, -8f, 8f), -4f,0);

        //playerCOP();
    }
    //private void playerCOP()
    //{
    //    // First clear the current set of points in the LR.


    //    //*******here i interchenged the values for x and y because i flipped the board in the real world******//

    //    float left_limit = PlayerPrefs.GetFloat("left_limit");
    //    float right_limit = PlayerPrefs.GetFloat("Right_limit");

    //    float _new_dist = Mathf.Abs(right_limit - left_limit);
    //    org_p = GameObject.FindGameObjectWithTag("player1").transform;
    //    bound1 = GameObject.FindGameObjectWithTag("y_left").transform;
    //    bound2 = GameObject.FindGameObjectWithTag("y_right").transform;

    //    float U_org = (bound2.transform.position.x + bound1.transform.position.x) / 2f;
    //    float x_org = (left_limit + right_limit) / 2;
    //    //if (MoBBoServer.W_player1 > 2f || MoBBoServer.W_player2 > 2f)
    //    //{


    //    //    initial_offset = bound1.transform.position.x - org_p.transform.position.x;
    //    //}


    //    float new_x = U_org + ((MoBBoServer.COP.x - x_org) / (_new_dist)) * (Mathf.Abs(bound2.transform.position.x - bound1.transform.position.x));



    //    float _x = (MoBBoServer.COP.x * ((AppConfig_WIFI.boardping_width) / (1f * _new_dist)));//(AppConfig_WIFI.realBoardWidth)) ; ;//);//
    //    float _y = MoBBoServer.COP.y * (AppConfig_WIFI.boardping_height) / (AppConfig_WIFI.realBoardHeight);

    //    //  UnityEngine.Debug.Log("the right and the left limits are" +_new_dist+"the fieldis"+field);


    //    float corrected_x = _x;//-187f;       //initial_offset

    //    if (float.IsNaN(_x) || float.IsNaN(_y) || float.IsInfinity(_x) || float.IsInfinity(_y))
    //    {
    //        throw new ArithmeticException();
    //    }

    //    try
    //    {
    //        player_1.transform.position = new Vector3(Mathf.Clamp(new_x, -107f, -10f), -41f, 0);

    //    }
    //    catch (ArithmeticException)
    //    {

    //    }

    //}
}
