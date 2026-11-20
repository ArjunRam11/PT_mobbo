//using System.Collections;
//using System.Collections.Generic;
//using UnityEngine;
//using UnityEngine.UI;

//public class options : MonoBehaviour
//{
//    public GameObject optionsMenu;  // Reference to the options menu UI
//    public BallMovement ballMovement;  // Reference to the ball movement script
//    public Button easyButton;  // Reference to the easy button
//    public Button moderateButton;  // Reference to the moderate button
//    // Start is called before the first frame update
//    void Start()
//    {
//        optionsMenu.SetActive(true);  // Show the options menu at the start

//        // Set up button click listeners
//        easyButton.onClick.AddListener(() => SetBallSpeed(5f));  // Set easy speed
//        moderateButton.onClick.AddListener(() => SetBallSpeed(10f));  // Set moderate speed

//    }
//    private void SetBallSpeed(float speed)
//    {
//        ballMovement.SetSpeed(speed);  // Pass the selected speed to the ball movement script
//        optionsMenu.SetActive(false);  // Hide the options menu after selection
//    }

//    public void ShowOptionsMenu()
//    {
//        optionsMenu.SetActive(true);  // Show the options menu during the game
//    }
//}


