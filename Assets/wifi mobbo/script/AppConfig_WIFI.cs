using System.Collections;
using System.IO;
using System.Collections.Generic;
using UnityEngine;
using System;
using MoBBoDataStructures_WIFI;

public static class AppConfig_WIFI
{
    /* A bunch of static variables that contain information that 
     * will be used across the different scenes.
     * */


    static string plaebo_path = login_handlr.file_path_root + "\\data";
    public static string subjs_dir = Path.Combine(plaebo_path, "subjects");

    // Board grid arrangements
    public static int[,] AllGridOptions = new int[35, 3] { 
        { 1, 1, 1},
        { 2, 1, 2}, { 2, 2, 1},
        { 3, 1, 3}, { 3, 3, 1}, 
        { 4, 1, 4}, { 4, 2, 2}, { 4, 4, 1},
        { 5, 1, 5}, { 5, 5, 1},
        { 6, 1, 6}, { 6, 2, 3}, { 6, 3, 2}, { 6, 6, 1},
        { 7, 1, 7}, { 7, 7, 1},
        { 8, 1, 8}, { 8, 2, 4}, { 8, 4, 2}, { 8, 8, 1},
        { 9, 1, 9}, { 9, 3, 3}, { 9, 9, 1},
        { 10, 1, 10}, { 10, 2, 5}, { 10, 5, 2}, { 10, 10, 1},
        { 11, 1, 11}, { 11, 11, 1},
        { 12, 1, 12}, { 12, 2, 6}, { 12, 3, 4}, { 12, 4, 3}, { 12, 6, 2}, { 12, 12, 1},
    };

    // MoBBo Actual board sizes.
    public static float realBoardWidth =57f; //Actual Board Width in Normal position
    public static float realBoardHeight =27.5f; //Actual Board Height in Normal position
   
  
    // MoBBo Grid Renderer start location for Setup Scene.
    public static Vector3 GridOrigin = new Vector3(-35, 10, 1);
    public static int boardWidth = 18; //for normal board placing
    public static int boardHeight = 9;
    //public static int boardWidth = 9;
    //public static int boardHeight = 18; // for inverted setup


    // MoBBo Grid Renderer start location for Test Scene.
    public static Vector3 GridOriginTestScn= new Vector3(-110,24, 1);
    public static int boardWidthTestScn = (int)(2.1*boardWidth);
    public static int boardHeightTestScn = (int)(2.1*boardHeight);

    public static Vector3 GridOriginTestScnn = new Vector3(-135 ,28, 1);
    public static int boardping_width = (int)(2.6* boardWidth);
    public static int boardping_height = (int)(8* boardHeight);


  

// Set of parameters for PROM assessment.
public static float promFMax = 20.0f;
    public static float promAngMin = 30f;
    public static float promAngMax = 150f;
    public static float promAngRes = 2f;
    public static float promDur = 1f;
    public static float promWait = 2f;

    // Robot extreme positions
    public static float[] robotRestPos = new float[] { 0f, -722f };

    public static string[] Get_Subjects_List()
    {
        List<string> subjlist = new List<string>();

        // Get the list of all directories in subjects directory.
        string[] dirs = Directory.GetDirectories(subjs_dir);
        string _temp;
        for (int i = 0; i < dirs.Length; i++)
        {
            _temp = new DirectoryInfo(@dirs[i]).Name;
            if (_temp != "config")
            {
                subjlist.Add(_temp);
            }
        }
        return subjlist.ToArray();
    }

    // Does subject exist?
    static public bool DoesSubjectExist(string subj)
    {
        return Array.IndexOf(Get_Subjects_List(), subj) >= 0;
    }

    // Create new subject.
    static public void CreateNewSubject(string subj, string cond)
    {
        SubjectData _subj = new SubjectData();
        _subj.set(subj, 0, "Male", cond, 0, "Right");

    }

    public static List<int[]> GetGridOptions(int noboards)
    {
        List<int[]> gridOpts = new List<int[]>();
        for(int i = 0; i < AllGridOptions.GetLength(0); i++)
        {
            if (AllGridOptions[i, 0] == noboards)
            {
                gridOpts.Add(new int[] { AllGridOptions[i, 1], AllGridOptions[i, 2] });
            }
        }
        return gridOpts;
    }
}
