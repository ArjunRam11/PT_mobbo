using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class CsvAssesReader : MonoBehaviour
{
    /// <summary>
    /// Reads specific variables from a CSV file.
    /// </summary>
    /// <param name="filePath">Path to the CSV file.</param>
    /// <param name="variables">List of variable names to extract.</param>
    /// <returns>A list of dictionaries where each dictionary represents a row of the selected variables.</returns>
    public List<Dictionary<string, string>> ReadVariables(string filePath, List<string> variables)
    {
        var data = new List<Dictionary<string, string>>();

        if (!File.Exists(filePath))
        {
            Debug.LogError($"File not found: {filePath}");
            return data;
        }

        try
        {
            using (var reader = new StreamReader(filePath))
            {
                // Read the header and split it into columns
                var header = reader.ReadLine()?.Split(',');
                if (header == null)
                {
                    Debug.LogError("The CSV file is empty.");
                    return data;
                }

                // Map variable names to their column indices
                var columnIndices = new Dictionary<string, int>();
                for (int i = 0; i < header.Length; i++)
                {
                    if (variables.Contains(header[i]))
                    {
                        columnIndices[header[i]] = i;
                    }
                }

                // Check if all variables are present
                foreach (var variable in variables)
                {
                    if (!columnIndices.ContainsKey(variable))
                    {
                        Debug.LogError($"Variable '{variable}' not found in the CSV file.");
                        return data;
                    }
                }

                // Read the data rows
                string line;
                while ((line = reader.ReadLine()) != null)
                {
                    var values = line.Split(',');
                    var row = new Dictionary<string, string>();
                    foreach (var variable in columnIndices.Keys)
                    {
                        row[variable] = values[columnIndices[variable]];
                    }
                    data.Add(row);
                }
            }
        }
        catch (Exception ex)
        {
            Debug.LogError($"Error reading CSV file: {ex.Message}");
        }

        return data;
    }







}
