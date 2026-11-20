using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ball_predictor : MonoBehaviour
{

    public Transform launchPoint; // The point from which the ball is launched
    public float launchAngle = 45f; // The launch angle in degrees
    public float launchSpeed = 10f; // The initial launch speed

    private Vector2 initialVelocity; // The initial velocity of the ball

    private void Start()
    {
        // Calculate the initial velocity based on launch angle and speed
        float launchAngleRad = Mathf.Deg2Rad * launchAngle;
        initialVelocity = new Vector2(launchSpeed * Mathf.Cos(launchAngleRad), launchSpeed * Mathf.Sin(launchAngleRad));
    }

    private void Update()
    {
        // Simulate ball path and draw trajectory using Debug.DrawLine()
        const float timeStep = 0.1f;
        float totalTime = 2f; // Adjust this to control the length of the prediction

        Vector2 currentPosition = launchPoint.position;
        Vector2 currentVelocity = initialVelocity;
        Physics2D.gravity = new Vector2(0f, -9.81f); // Set the gravity (adjust value as needed)

        for (float t = 0f; t <= totalTime; t += timeStep)
        {
            Vector2 nextPosition = currentPosition + currentVelocity * timeStep;
            Debug.DrawLine(currentPosition, nextPosition, Color.red, 0.1f);

            currentVelocity += Physics2D.gravity * timeStep;
            currentPosition = nextPosition;
        }
    }
}

