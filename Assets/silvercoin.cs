using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class silvercoin : MonoBehaviour
{
    main main;
    Transform tr;
    void Start()
    {
        tr = GetComponent<Transform>();
        main = GameObject.Find("fallscript").GetComponent<main>();
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        tr.position -= new Vector3(0f, 0.12f, 0f);
        if (tr.position.y < -7f) Destroy(this.gameObject);
    }
    private void OnTriggerEnter2D(Collider2D collision)
    {
        if (collision.gameObject.name == "collector")
        {
            Destroy(this.gameObject);
            Destroy(collision.gameObject);
            main.GameOver = true;
        }
    }
}
