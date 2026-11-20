//using System.Collections;
//using System.Collections.Generic;
//using UnityEngine;

//public class MiddleScript : MonoBehaviour
//{
//    public LogicScript logic;
//    // Start is called before the first frame update
//    void Start()
//    {
//        logic = GameObject.FindGameObjectWithTag("logic_object").GetComponent<LogicScript>();
//    }

//    // Update is called once per frame
//    void Update()
//    {
        
//    }
//    private void OnTriggerEnter2D(Collider2D collision)
//    {
//        UnityEngine.Debug.Log("counter score1");
//        if (collision.gameObject.layer == 3)
//        {
//            logic.addScore(1);
//        }
        
//    }
//}



using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MiddleScript : MonoBehaviour
{
    public LogicScript logic;
    // Start is called before the first frame update
    void Start()
    {
        logic = GameObject.FindGameObjectWithTag("logic_object").GetComponent<LogicScript>();
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    private void OnTriggerEnter2D(Collider2D collision)
    {
        UnityEngine.Debug.Log("counter score1");
        UnityEngine.Debug.Log(collision.gameObject.CompareTag("Middle"));
        if (collision.gameObject.layer == 3)
        {
            logic.addScore(1);
        }

    }
}

