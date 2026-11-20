using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using System.IO;


public class login_list : MonoBehaviour
{
    
    // List of user IDs (you should populate this list before calling WriteToCSV)

    private List<int> userIds = new List<int>();

    // File path to save the CSV file (you can change the path and filename as needed)
    private string filePath = "Assets/Data/user_ids.csv";

    public void WriteToCSV()
    {
        // Convert the list of user IDs to a comma-separated string
        string csvData = string.Join(",", userIds);

        try
        {
            // Create or overwrite the CSV file
            using (StreamWriter writer = new StreamWriter(filePath))
            {
                // Write the data to the file
                writer.WriteLine(csvData);
            }

            Debug.Log("CSV file created successfully!");
        }
        catch (IOException e)
        {
            Debug.LogError("Error creating CSV file: " + e.Message);
        }
    }
}

 


