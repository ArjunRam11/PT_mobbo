using System.Diagnostics;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using CodeMonkey.Utils;

public class MoBBoGrid
{
    public   static string set1_value, set2_value, set3_value;
    public  static  bool set1,set2,set3=false;  
    public int width { get; private set; }
    public int height { get; private set; }
    public int[,] values { get; private set; }
    
    public TextMesh[,] text;
    
    public Vector3 TextOrigin { get; private set; }
    public int cellWidth { get; private set; }
    public int cellHeight { get; private set; }
    private int[] valueOpts;
    private bool[] valueOptsAvailable;

    public MoBBoGrid(int w, int h, Vector3 org, int cellW, int cellH, int[] valopts)
    {
        width = w;
        height = h;
        values = new int[h, w];  
        text = new TextMesh[h, w];  
        TextOrigin = org;
        UnityEngine.Debug.Log(TextOrigin);
        cellHeight = cellH;
        cellWidth = cellW;

        // Initialize values
        for (int i = 0; i < h; i++)
        {
            for (int j = 0; j < w; j++)
            {
                values[i, j] = -1;
                text[i, j] = UtilsClass.CreateWorldText($"{values[i, j]}", null,
                                                        TextOrigin + new Vector3((j + 0.5f) * cellWidth, - (i + 0.5f) * cellHeight, 0),
                                                        25, UnityEngine.Color.black, TextAnchor.MiddleCenter);
           

            }
        }
        // Set option values
        valueOpts = valopts;
     
        valueOptsAvailable = new bool[valueOpts.Length];

        for (int i = 0; i < valueOpts.Length; i++)
        {
            
            valueOptsAvailable[i] = true;
          

        }
        // UnityEngine.Debug.Log(text+"lllll");
    }

    public void Clear()
    {
        for (int i = 0; i < height; i++)
        {
            for (int j = 0; j < width; j++)
            {
                values[i, j] = -1;
                Object.Destroy(text[i, j]);
            }
        }
    }

    public bool AllGridValueAssigned()
    {
        for (int i = 0; i < height; i++)
        {
            for (int j = 0; j < width; j++)
            {
                if (values[i, j] == -1)
                {
                    return false;
                }
            }
        }
        return true;
    }

    public void GetGridPos(Vector3 worldPos, out int x, out int y)
    {
        x = (int)((worldPos - (TextOrigin)).x / cellWidth);
        y = - (int)((worldPos - TextOrigin).y / cellHeight);
      
        
    }

    public void SetNextAvailableValue(Vector3 worldPos)
    {
        PrintValueAvailable();
        int x, y;
        GetGridPos(worldPos, out x, out y);
       //UnityEngine.Debug.Log($"{x}, {y}");
        // Make sure grid position makes sense.
        if (x >= 0 && x < width && y >= 0 && y < height)
        {
            // Assign the next available value to the grid position.
            int _val = GetNextAvailableValue(values[y, x]);
            if (_val != -1) {
                // First make the current value available.
                MakeValueAvailable(values[y, x]);
                values[y, x] = _val;
                // Udpate text.
                text[y, x].text = $"{_val}";
                MakeValueUnavailable(values[y, x]);
            }
        }
    }

    public void ClearCellValue(Vector3 worldPos)
    {
        PrintValueAvailable();
        int x, y;
        GetGridPos(worldPos, out x, out y);
      //  UnityEngine.Debug.Log($"{x}, {y}");
        // Make sure grid position makes sense.
        if (x >= 0 && x < width && y >= 0 && y < height)
        {
            // Assign the next available value to the grid position.
            // First make the current value available.
            MakeValueAvailable(values[y, x]);
            values[y, x] = -1;
            // Udpate text.
            text[y, x].text = "-1";
        }
    }

    private void MakeValueAvailable(int val)
    {
        for (int i = 0; i < valueOpts.Length; i++)
        {
            if (valueOpts[i] == val)
            {
                valueOptsAvailable[i] = true;
                return;
            }
        }
    }

    private void PrintValueAvailable()
    {
        string _str = "";
        for (int i = 0; i < valueOpts.Length; i++)
        {
            _str = $"{_str}, {valueOpts[i]}:{valueOptsAvailable[i]}";
        }
       // UnityEngine.Debug.Log(_str);
    }

    private void MakeValueUnavailable(int val)
    {
        for (int i = 0; i < valueOpts.Length; i++)
        {
            if (valueOpts[i] == val)
            {
                valueOptsAvailable[i] = false;
                return;
            }
        }
    }

    private int GetNextAvailableValue(int val)
    {
        int inx = (val == -1)? -1 : GetValueIndex(val);
        int cnt = 0;

        // Value is invalid.
        if (inx == -2)
            return -1;

        // Get the next available value for the given
        // valid value.
        while (cnt < valueOpts.Length)
        {
            inx = (inx + 1) % valueOpts.Length;
            if (valueOptsAvailable[inx])
                return valueOpts[inx];
            cnt++;
        }
        return -1;
    }

    private int GetValueIndex(int val)
    {
        for (int i = 0; i < valueOpts.Length; i++)
        {
            if (valueOpts[i] == val)
            {
                return i;
            }
        }
        return -2;
    }

    //public void UpdateTextMesh(Vector3 org, int cellW, int cellH, UnityEngine.Color color)
    //{
    //    TextOrigin = org;
    //    cellHeight = cellH;
    //    cellWidth = cellW;

    //    // Initialize values
    //    for (int i = 0; i < height; i++)
    //    {
    //        for (int j = 0; j < width; j++)
    //        {
    //            text[i, j] = UtilsClass.CreateWorldText($"{values[i, j]}", null,
    //                                                    TextOrigin + new Vector3(j * cellWidth + 0.1f * cellHeight,
    //                                                                             -(i + 0.1f) * cellHeight,
    //                                                                             0), 25, color, TextAnchor.UpperLeft);



    //            if (!l_set)
    //            {
    //                left_no = values[i, j].ToString();
    //                l_set = true;
    //                UnityEngine.Debug.Log(left_no + "left no");
    //            }



    //            if (j > 1 && !r_set)
    //            {
    //                right_no = values[i, j].ToString();
    //                UnityEngine.Debug.Log(right_no + "right no");
    //                r_set = true;
    //            }

    //        }

    //    }
    //}
  
    public void UpdateTextMesh_fat(Vector3 org, int cellW, int cellH, UnityEngine.Color color)
    {
        TextOrigin = org;
        cellHeight = cellH;
        cellWidth = cellW;

        //// Initialize values for each set
        //bool set1 = false;
        //bool set2 = false;
        //bool set3 = false;

        // Initialize values
        for (int i = 0; i < height; i++)
        {
            for (int j = 0; j < width; j++)
            {
                text[i, j] = UtilsClass.CreateWorldText($"{values[i, j]}", null,
                                                        TextOrigin + new Vector3(j * cellWidth + 0.1f * cellHeight,
                                                                                 -(i + 0.1f) * cellHeight,
                                                                                 0), 25, color, TextAnchor.UpperLeft);

                if (!set1)
                {
                    set1_value = values[i, j].ToString();
                    set1 = true;
                    UnityEngine.Debug.Log(set1_value + " Set 1");
                }

                if (j == 1 && !set2) // Set set2 only when column j == 1
                {
                    set2_value = values[i, j].ToString();
                    UnityEngine.Debug.Log(set2_value + " Set 2");
                    set2 = true;
                }

                if (j == 2 && !set3) // Set set3 only when column j == 2
                {
                    set3_value = values[i, j].ToString();
                    UnityEngine.Debug.Log(set3_value + " Set 3");
                    set3 = true;
                }
            }
        }
    }



    //public void UpdateTextMesh_tall(Vector3 org, int cellW, int cellH, UnityEngine.Color color)
    //{
    //    TextOrigin = org;
    //    cellHeight = cellH;
    //    cellWidth = cellW;

    //    //// Initialize values for each set
    //    //bool set1 = false;
    //    //bool set2 = false;
    //    //bool set3 = false;

    //    // Initialize values
    //    for (int i = 0; i < width; i++)
    //    {
    //        for (int j = 0; j < height; j++)
    //        {
    //            text[i, j] = UtilsClass.CreateWorldText($"{values[i, j]}", null,
    //                                                    TextOrigin + new Vector3(j * cellWidth + 0.1f * cellHeight,
    //                                                                             -(i + 0.1f) * cellHeight,
    //                                                                             0), 25, color, TextAnchor.UpperLeft);

    //            if (!set1)
    //            {
    //                set1_value = values[i, j].ToString();
    //                set1 = true;
    //                UnityEngine.Debug.Log(set1_value + " Set 1");
    //            }

    //            if (j == 1 && !set2) // Set set2 only when column j == 1
    //            {
    //                set2_value = values[i, j].ToString();
    //                UnityEngine.Debug.Log(set2_value + " Set 2");
    //                set2 = true;
    //            }

    //            if (j == 2 && !set3) // Set set3 only when column j == 2
    //            {
    //                set3_value = values[i, j].ToString();
    //                UnityEngine.Debug.Log(set3_value + " Set 3");
    //                set3 = true;
    //            }
    //        }
    //    }
    //}

}
