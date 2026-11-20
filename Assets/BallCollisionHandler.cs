using UnityEngine;

public class BallCollisionHandler : MonoBehaviour
{
    public GameObject ground; // Reference to the ground GameObject
    private bool trialComplete = false;
    private bool ballHitGround = false;

    void OnCollisionEnter2D(Collision2D collision)
    {
        if (collision.gameObject.CompareTag("ground_border"))
        {
            UnityEngine.Debug.Log("Ball hit the ground. Trial failed!");
            trialComplete = true;
            ballHitGround = true;
            // Handle trial failure (e.g., reset game, update UI)
        }
        //else if (collision.gameObject.CompareTag("ground_border"))
        //{
        //    UnityEngine.Debug.Log("Ball collided with the border.");
        //    // Handle collision with border (optional, e.g., bounce logic)
        //}
    }
    public bool DidBallHitGround()
    {
        return ballHitGround;
    }

    public bool IsTrialComplete()
    {
        return trialComplete;
    }

    public void ResetTrial()
    {   
        trialComplete = false;
        ballHitGround = false;
    }
}

