using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class genrator : MonoBehaviour
{
    float timer = 1;
    public GameObject[] gm;

    void Start()
    {

    }

    void Update()
    {
        if (timer > 0)
        {
            timer -= Time.deltaTime;
        }
        else
        {
            if (gm.Length > 1)
            {
                int chance = Random.Range(1, 101);
                float pos_x = Random.Range(-8.0f, 8.0f);

                if (chance <= 20)
                {
                    Instantiate(gm[1], new Vector3(pos_x, 6.0f, 0.1f), Quaternion.identity);
                }
                else
                {
                    Instantiate(gm[0], new Vector3(pos_x, 6.0f, 0.1f), Quaternion.identity);
                }

                timer = 2.0f;
            }
            else
            {
                Debug.LogError("The gm array does not have enough elements!");
            }
        }
    }
}
