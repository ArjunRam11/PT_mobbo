using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MoBBoDataStructures_WIFI;

/* Class for handling therapy session details.
 */
public class TherapySession_WIFI
{
    public enum AssessmentGames
    {
        AROM = 0,
        PROM = 1
    }
    public enum TrainingGames
    {
        CATCHER = 0,
        SHOOTER = 1,
        CRAZYPONG = 2,
    }
    public enum TherapyModes
    {
        ACTIVE = 0,
        ASSISTED = 1,
        PASSIVE = 2
    }
    public static string[] AGNames = new string[] { "AROM", "PROM" };
    public static string[] TGNames = new string[] { "CATCHER", "SHOOTER", "CRAZYPONG" };
    public static string[] TMNames = new string[] { "ACTIVE", "ASSISTED", "PASSIVE" };

    public DateTime strtTime { get; private set; }
    public List<ushort> activityCode { get; private set; }
    public List<DateTime[]> activityTimes { get; private set; }
    public List<int> activityLevel { get; private set; }
    public string directory { get; private set; }
    public string sessFileName { get; private set; }
    public int currActInx
    {
        get { return activityCode.Count - 1; }
    }
    public int currActLevel
    {
        get { return activityLevel[currActInx]; }
    }

    public TherapyModes _currTherapyMode;
    public TherapyModes currTherapyMode { 
        get { return _currTherapyMode; }
        set
        {
            _currTherapyMode = value;
            WriteSessionInfo($"Therapy mode set to {(TherapyModes)currTherapyMode}");
        }
    }

    public TherapySession_WIFI(string subjHospNum, TherapyModes tmode = TherapyModes.ACTIVE)
    {
        strtTime = DateTime.Now;
        activityCode = new List<ushort>();
        activityTimes = new List<DateTime[]>();
        activityLevel = new List<int>();
        
        // Start session file.
        StartSessionFile(subjHospNum);
        currTherapyMode = tmode;
    }

    public void InitActivity(bool trainassess, byte mode, byte game, int level)
    {
        // Initialize all activity related variables.
        activityCode.Add(GetActivityCodeLSB(trainassess, mode, game));
        activityLevel.Add(level);
        //activityPerf.Add(new float[AppData.GamePerfVarCount[game]]);
        activityTimes.Add(new DateTime[] { DateTime.MinValue, DateTime.MinValue });
        Debug.Log(currActInx);
    }

    public void SetStartTime()
    {
        activityTimes[currActInx][0] = DateTime.Now;
    }

    public void SetStopTime()
    {
        activityTimes[currActInx][1] = DateTime.Now;
    }

    public void SetExitCode(bool success)
    {
        if (success)
        {
            activityCode[currActInx] = (ushort) ((0x01 << 8) | activityCode[currActInx]);
        }
    }

    private void StartSessionFile(string subjHospNum)
    {
        // Set session directroy
        directory = Path.Combine(SubjectData.Get_Subj_SessionFile_Dir(subjHospNum),
                                 DateTime.Now.ToString("Dyyyy-MM-ddTHH-mm-ss"));
        Directory.CreateDirectory(directory);
        sessFileName = Path.Combine(directory, "sessfile.sfl");
        WriteSessionInfo($"Subj {subjHospNum}, Session started.");
    }

    public void CloseSessionFile()
    {
        WriteSessionInfo($"Session closed.");

        // Write Activity details to the end of this file.
        WriteActivityToSessionFile();
    }

    private void WriteActivityToSessionFile()
    {
        using (StreamWriter file = new StreamWriter(sessFileName, true))
        {
            file.WriteLine("");
            file.WriteLine("Session activity");
            file.WriteLine("code, starttime, stoptime, level");
            for (int i = 0; i < activityCode.Count; i++)
            {
                file.WriteLine($"{activityCode[i]}, {activityTimes[i][0]}, {activityTimes[i][1]}, {activityLevel[i]}");
            }
            file.Flush();
        }
    }

    public DateTime WriteSessionInfo(string info)
    {
        DateTime dtnow = DateTime.Now;
        try
        {
            using (StreamWriter file = new StreamWriter(sessFileName, true))
            {
                file.WriteLine($"{dtnow.ToString("yyyy-MM-dd HH:mm:ss")}, {info}");
                file.Flush();
            }
        }
        catch
        {

        }
        // UnityEngine.Debug.Log(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "\t" + info);
        return dtnow;
    }

    static public byte GetActivityCodeLSB(bool trainassess, byte mode, byte game)
    {
        // Byte encoding.
        // AG/TG (1) | Therapy Mode (3) | Game code (4)
        byte _code = (byte)(trainassess ? 0x00 : 0x80);
        _code = (byte) (_code | (mode << 4) | game);
        return _code;
    }
}
