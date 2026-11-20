using UnityEngine;

public class computer_paddle : MonoBehaviour
{
    // Speed of the enemy
    public static float speed = 1.9F;

    // The ball
    Transform pingball;

    // The ball's rigidbody 2D
    Rigidbody ballRig;

    // Bounds of enemy
    public float topBound = 3.0F;
    public float bottomBound = -3.0F;
    public float leftBound = -3.0F; // Define left boundary
    public float rightBound = 3.0F; // Define right boundary
    public static float stopWatch;

    // Use this for initialization
    private void Awake()
    {
        stopWatch = 0;
    }

    void Start()
    {
        // Continuously invoke Move every x seconds (values may differ)
        InvokeRepeating("Move", .02F, .02F);
    }

    private void Update()
    {
        stopWatch += Time.deltaTime;

        Debug.Log(stopWatch);
    }

    // Movement for the paddle
    void Move()
    {
        float currSpeed = Mathf.Clamp(speed - (stopWatch / 90 * speed * 0.3f), 0.6f * speed, speed);
        Debug.Log(currSpeed);

        // Finding the ball
        if (pingball == null)
        {
            UnityEngine.Debug.Log("its found");
            pingball = GameObject.FindGameObjectWithTag("target").transform;
        }

        // Setting the ball's rigidbody to a variable
        ballRig = pingball.GetComponent<Rigidbody>();

        // Checking x direction of the ball
        if (ballRig.velocity.y < 0)
        {
            // Checking y direction of ball
            if (pingball.position.x < this.transform.position.x - .3F)
            {
                // Move paddle down if the ball is lower than the paddle
                transform.Translate(Vector3.down * currSpeed * Time.deltaTime);
            }
            else if (pingball.position.x > this.transform.position.x + .3F)
            {
                // Move paddle up if the ball is higher than the paddle
                transform.Translate(Vector3.up * currSpeed * Time.deltaTime);
            }
        }

        // Set bounds of enemy vertically
        if (transform.position.y > topBound)
        {
            transform.position = new Vector3(transform.position.x, topBound, 0);
        }
        else if (transform.position.y < bottomBound)
        {
            transform.position = new Vector3(transform.position.x, bottomBound, 0);
        }

        // Set bounds of enemy horizontally
        if (transform.position.x < leftBound)
        {
            transform.position = new Vector3(leftBound, transform.position.y, 0);
        }
        else if (transform.position.x > rightBound)
        {
            transform.position = new Vector3(rightBound, transform.position.y, 0);
        }
    }
}
