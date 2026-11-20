using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;




public class next_scene : MonoBehaviour
{
    public Button Loadscene;
    // Start is called before the first frame update
    void Start()
    {

    }
    public void loadsetupscene ()
        {
        SceneManager.LoadScene("mainscene");
        }

    // Update is called once per frame
    void Update()
    {
        
    }
}
