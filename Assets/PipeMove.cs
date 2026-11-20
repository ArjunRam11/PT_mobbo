using UnityEngine;

public class PipeMove : MonoBehaviour
{
    private float moveSpeed;
    private float deadZone;
    private PipeSpawnScript pipeSpawner; // Reference to PipeSpawnScript

    public void Initialize(float speed, float zone)
    {
        moveSpeed = speed;
        deadZone = zone;
        //pipeSpawner = spawner; // Assign the PipeSpawnScript reference
    }

    // Single Update method
    void Update()
    {
        if (pipeSpawner != null && pipeSpawner.IsGameOver) // Check if game is over
        {
            Destroy(gameObject); // Destroy the pipe
        }
        // Add movement logic
        transform.position += Vector3.left * moveSpeed * Time.deltaTime;

        // Add destruction logic
        if (transform.position.x < deadZone)
        {
            Debug.Log("Pipe Destroyed");
            Destroy(gameObject);
        }

        // (Preserve any additional functionality from the existing Update method)
    }
}
