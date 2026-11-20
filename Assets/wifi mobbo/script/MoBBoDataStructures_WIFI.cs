using System;
using System.IO;
using System.Collections.Generic;
using UnityEngine;
using System.Text;

namespace MoBBoDataStructures_WIFI
{
    public enum ControlType
    {
        NONE = 0,
        POSITION = 1,
        ACTIVE = 2,
        ACTIVEASSIST = 3,
        RESIST = 4,
        FORCE = 6,
    }

    public enum Status
    {
        SENSORSTREAM = 0,
        SENSORPARAM = 1,
        DEVICEERROR = 2,
        CONTROLPARAM = 3,
        DIAGNOSTICS = 4
    }

    public enum ErrorType

    {
        ANGSENSERR = 1,
        VELSENSERR = 2,
        TORQSENSERR = 4,
        MCURRSENSERR = 8
    }

    static class DataTypeDefinitions
    {
        static public List<string[]> dataTypeDetails = new List<string[]>
        {
            new string[] { "SENSORSTREAM",
                "Ang R    ",
                "Ang L    ",
                "Force X  ",
                "Force Y  ",
                "Force Z  ",
                "Force R  ",
                "Force L  ",
                "X        ",
                "Y        ",
                "Len R    ",
                "Len L    ",
                "Ctrl R   ",
                "Ctrl L   ",
                "Battery  ",
                "Des X    ",
                "Des Y    ",
                "Des Fx   ",
                "Des Fy   ",
                "Des Fr   ",
                "Des Fl   ",
            },
            new string[] { "SENSORPARAM",
                "Torq m", "Torq c"
            },
            new string[] { "DEVICEERROR",
                "Angle", "Ang. Vel.", "Torque", "Motor Curr."
            }
        };

        static public string[] controlTypeDetails = new string[]
        {
            "None", "Position", "Active", "ActiveAssist", "Resist", "Calibration", "Force"
        };

        static public string[] calibTypeDetails = new string[] { "None", "Done" };
        static public List<string[]> errorTypes = new List<string[]>
        {
            new string[] { "Angle Left", "Angle Right", "X Velocity", "Y Velocity",
                           "Force X", "Force Y", "Force Z", "Battery" },
            new string[] { }
        };
    }

    static class UsefulFunctions
    {
        static public float[] CartToPolarCoords(float x, float y)
        {
            float[] _polpos = new float[2];
            _polpos[0] = (float) Math.Sqrt(Math.Pow(x, 2) + Math.Pow(y, 2));
            _polpos[1] = (float)Math.Atan2(y, x);
            return _polpos;
        }
    }

    public class SubjectData
    {
        public string hospnum { get; private set; }
        public int age { get; private set; }
        public string sex { get; private set; }
        public string cond { get; private set; }
        public int dur { get; private set; }
        public string side { get; private set; }

        // List of directories.
        public string baseDir => Get_Subj_Dir(hospnum);
        public string SessionFileDir => Get_Subj_SessionFile_Dir(hospnum);
        public string SetupFileDir => Get_Subj_SetupFile_Dir(hospnum);
        public string RawdataDir => Get_Subj_Rawdata_Dir(hospnum);
        public string AssessmentDir => Get_Subj_Assessment_Dir(hospnum);
        public string GameperfDir => Get_Subj_Gameperf_Dir(hospnum);

        public SubjectData()
        {
        }

        public SubjectData(string hnum)
        {
            string[] vals;
            using (StreamReader file = new StreamReader(Path.Combine(Get_Subj_Dir(hnum), "profile.csv")))
          //  using (StreamReader file = new StreamReader(Path.Combine(login_handlr.accessing_folder, "profile.csv")))
            {
                // Read the header out.
                file.ReadLine();
                
                // Read data
                vals = file.ReadLine().Split(',');

                // Update subject details
                hospnum = hnum;
                age = int.Parse(vals[1].Trim());
                sex = vals[2].Trim();
                cond = vals[3].Trim();
                dur = int.Parse(vals[4].Trim());
                side = vals[5].Trim();
            }
        }

        public void set(string hnum, int sub_age, string sub_sex, string sub_cond, int sub_dur, string sub_side)
        {
            hospnum = hnum;
            age = sub_age;
            sex = sub_sex;
            cond = sub_cond;
            dur = sub_dur;
            side = sub_side;
            create_subject_file();
        }

        //public void set(string hnum, int sub_age, string sub_sex, string sub_cond, int sub_dur, string sub_side)
        //{
        //    hospnum = hnum;
        //    age = sub_age;
        //    sex = sub_sex;
        //    cond = sub_cond;
        //    dur = sub_dur;//*************** use it for the older version:sir's version*********//
        //    side = sub_side;
        //    create_subject_file();
        //}

        private void create_subject_file()

        {
            //string profile_data = login_handlr.accessing_folder;
            string _sdir = Get_Subj_Dir(hospnum);
            Directory.CreateDirectory(_sdir);
            //string _sdir = Get_Subj_Dir(hospnum); this is what im trying to do to save the data in my way//
            //Directory.CreateDirectory(login_handlr.accessing_folder);

            // Create directory for session files
            Directory.CreateDirectory(Get_Subj_SessionFile_Dir(hospnum));

            // Create directory for any setup files
            Directory.CreateDirectory(Get_Subj_SetupFile_Dir(hospnum));

            // Create directory for raw game data files.
            Directory.CreateDirectory(Get_Subj_Rawdata_Dir(hospnum));
            
            // Create directory for assessment files.
            Directory.CreateDirectory(Get_Subj_Assessment_Dir(hospnum));
            ActiveRangeOfMotion.CreateAROMFile(Get_Subj_Assessment_Dir(hospnum), hospnum);
            PassiveRangeOfMotion.CreatePROMFile(Get_Subj_Assessment_Dir(hospnum), hospnum);

            // Create directory for game parameter sfiles.
            Directory.CreateDirectory(Get_Subj_Gameperf_Dir(hospnum));
            //TGCatcherLibrary.CreateGamePerformanceFile(hospnum);
            //TGShooterLibrary.CreateGamePerformanceFile(hospnum);

            using (StreamWriter file = new StreamWriter(Path.Combine(_sdir, "profile.csv"), true))
           // using (StreamWriter file = new StreamWriter(Path.Combine(login_handlr.accessing_folder, "profile.csv"), true))
            {
                file.WriteLine("hnum, age, sex, cond, dur, side");
                file.WriteLine(string.Format("{0}, {1}, {2}, {3}, {4}, {5}",
                    hospnum, age, sex, cond, dur, side));

                //file.WriteLine("hnum, age, sex, cond,name");
                //file.WriteLine(string.Format("{0}, {1}, {2}, {3}, {4}",
                //    hospnum, age, sex, cond));

            }
        }

        public static string Get_Subj_Dir(string hnum)
        {
            return Path.Combine(AppConfig_WIFI.subjs_dir, hnum);
        }

        public static string Get_Subj_SessionFile_Dir(string hnum)
        {
            return Path.Combine(Get_Subj_Dir(hnum), "session_files");
        }
        public static string Get_Subj_SetupFile_Dir(string hnum)
        {
            return Path.Combine(Get_Subj_Dir(hnum), "setup_files");
        }

        public static string Get_Subj_Rawdata_Dir(string hnum)
        {
            return Path.Combine(Get_Subj_Dir(hnum), "rawdata_files");
        }

        public static string Get_Subj_Assessment_Dir(string hnum)
        {
            return Path.Combine(Get_Subj_Dir(hnum), "assessment_files");
        }

        public static string Get_Subj_Gameperf_Dir(string hnum)
        {
            return Path.Combine(Get_Subj_Dir(hnum), "gameperf_files");
        }
    }

    public class FixedSizeQueue<T>
    {
        public T Last { get; private set; }
        public int Count {
            get {
                return _q.Count;
            }
        }
        private Queue<T> _q;
        private int _sz;
        public int size
        {
            get { return _sz; }
        }

        public FixedSizeQueue(int sz)
        {
            _sz = sz;
            _q = new Queue<T>();
        }

        public void Enqueue(T obj)
        {
            Last = obj;
            while (_q.Count > _sz)
            {
                _q.Dequeue();
            }
            _q.Enqueue(obj);
        }

        public T Dequeue()
        {
            return _q.Dequeue();
        }
    }
    // no need since it is for plaebo
    public class PlaeboRobotData
    {
        public const float wsHeight = 280;//465.0f;
        public const float wsWidth = 465;//760.0f;

        public byte status { get; private set; }
        public byte dtype {
            get
            {
                return (byte)((status >> 0x04) & 0x07);
            }
        }
        public byte ctrl
        {
            get
            {
                return (byte)((status >> 0x01) & 0x07);
            }
        }
        public byte calib
        {
            get
            {
                return (byte)(status & 0x01);
            }
        }
        public byte error1 { get; private set; }
        public byte error2 { get; private set; }

        // Time
        public float time
        {
            get { return lastVal(0);
            }
        }
        // Angle R
        public float angR
        {
            get { return lastVal(1); }
        }
        // Angle L
        public float angL
        {
            get { return lastVal(2); }
        }
        // Force X
        public float fx
        {
            get { return lastVal(3); }
        }
        // Force Y
        public float fy
        {
            get { return lastVal(4); }
        }
        // Force Z
        public float fz
        {
            get { return lastVal(5); }
        }
        // Force R
        public float fR
        {
            get { return lastVal(6); }
        }

        // Force L
        public float fL
        {
            get { return lastVal(7); }
        }
        // x
        public float x
        {
            get { return lastVal(8); }
        }
        // y
        public float y
        {
            get { return lastVal(9); }
        }
        // lR
        public float lR
        {
            get { return lastVal(10); }
        }
        // lL
        public float lL
        {
            get { return lastVal(11); }
        }
        // uR
        public float uR
        {
            get { return lastVal(12); }
        }
        // uL
        public float uL
        {
            get { return lastVal(13); }
        }
        // Battery
        public float battery
        {
            get { return lastVal(14); }
        }
        // des X
        public float tgtX
        {
            get { return lastVal(15); }
        }
        // des Y
        public float tgtY
        {
            get { return lastVal(16); }
        }
        // dexFx
        public float tgtFx
        {
            get { return lastVal(17); }
        }
        // dexFy
        public float tgtFy
        {
            get { return lastVal(18); }
        }

        // PLAEBO robot sensor data queue.
        static private int _sensQSz = 100;
        FixedSizeQueue<float[]> sensorDataQ;

        // PLAEBO message data.
        static private int _msgQSz = 100;
        public FixedSizeQueue<byte[]> msgQ;

        // PLAEBO sensor parameters
        // Sensor Parameters
        private float[] _sensorParam = new float[2] {
            1.0f, 0.0f
        };

        public float[] torqParam
        {
            get { return new float[] { _sensorParam[0], _sensorParam[1] }; }
            set
            {
                _sensorParam[0] = value[0];
                _sensorParam[1] = value[1];
            }
        }

        // Variable for calculating frame rate
        private float _prevTime;
        public float frameRate
        {
            get { return (_prevTime != time) ? (1.0f / (time - _prevTime)) : 0f; }
        }

        // PLAEBO control parameters
        public ControlType ctrlType;
        public bool TargetInfo;
        public bool ControlInfo;
        public float actValue = 0.0f;
        public float fcKl = 0.1f;
        public float fcKr = 0.1f;
        public float fcFth = 5.0f;
        public float desFx;
        public float desFy;

        public PlaeboRobotData(string paramFile)
        {
            sensorDataQ = new FixedSizeQueue<float[]>(_sensQSz);
            msgQ = new FixedSizeQueue<byte[]>(_msgQSz);

            // Read/parse PLUTO parameter file.
            List<string[]> _param = ReadParsePlutoParamFile(paramFile);

            // Assign parameter values.
            //for (int i = 0; i < _param.Count; i++)
            //{
            //    switch (_param[i][0])
            //    {
            //    }
            //}
        }

        public float lastVal(int inx)
        {
            return sensorDataQ.Count > 0 ? sensorDataQ.Last[inx] : 0f;
        }

        public void ParseRawBytesAndAdd(byte[] rawbytes)
        {
            // Update status and error bytes
            status = rawbytes[5];
            error1 = rawbytes[6];
            error2 = rawbytes[7];

            // Check status
            switch (dtype)
            {
                case (byte) Status.SENSORSTREAM:
                    // Parse sensor data and update sensor data queue.
                    float[] sensdata = new float[24];
                    // Time stamp
                    // Update previous time
                    _prevTime = time;
                    sensdata[0] = System.BitConverter.ToSingle(rawbytes, 1);
                    // Read floats
                    for (int i = 0; i < 20; i++)
                    {
                        sensdata[i + 1] = System.BitConverter.ToSingle(rawbytes, 4 * i + 8);
                    }
                    // Status
                    sensdata[21] = BitConverter.ToSingle(new byte[] { 0x00, 0x00, 0x00, status}, 0);
                    // Error1
                    sensdata[22] = BitConverter.ToSingle(new byte[] { 0x00, 0x00, 0x00, error1 }, 0);
                    // Error2
                    sensdata[23] = BitConverter.ToSingle(new byte[] { 0x00, 0x00, 0x00, error2 }, 0);
                    // Enqueue
                    sensorDataQ.Enqueue(sensdata);
                    break;
                default:
                    // Update message queue.
                    byte[] msgdata = new byte[rawbytes[0]];
                    for (int i = 0; i < rawbytes[0]; i++)
                    {
                        msgdata[i] = rawbytes[5 + i];
                    }
                    // Enqueue
                    msgQ.Enqueue(msgdata);
                    break;
            }
        }

        // Get byte array of sensor parameters
        public byte[] getByteArray4SensorParam()
        {
            byte[] _data = new byte[_sensorParam.Length * 4];
            Buffer.BlockCopy(_sensorParam, 0, _data, 0, _data.Length);
            return _data;
        }

        // Get byte array of control parameters
        public byte[] getByteArray4ControlParam()
        {
            //return new byte[0];
            switch (ctrlType)
            {
                case ControlType.ACTIVE:
                    return new byte[0];
                case ControlType.FORCE:
                    if (ControlInfo == true)
                    {
                        return new byte[0];
                    } else if (TargetInfo == true)
                    {
                        byte[] _data = new byte[8];
                        Buffer.BlockCopy(new float[] { AppData_WIFI.plaeboData.desFx, AppData_WIFI.plaeboData.desFy }, 0, _data, 0, _data.Length);
                        return _data;
                    } else
                    {
                        return new byte[0];
                    }
                default:
                    return new byte[0];
            }
        }

        static List<string[]> ReadParsePlutoParamFile(string paramFile)
        {
            List<string[]> plutoparams = new List<string[]>();
            StreamReader reader = File.OpenText(paramFile);
            string line;
            while ((line = reader.ReadLine()) != null)
            {
                // Check if this is a comment line
                if (line[0] == '#') continue;

                // Add parameters.
                plutoparams.Add(line.Split(' '));
            }
            return plutoparams;
        }
    }

    // Passive Range of motion
    public class PassiveRangeOfMotion
    {
        public string datetime { get; private set; }
        public string strttime { get; set; }
        public float dur { get; set; }
        public float segdur { get; set; }
        public float fmax { get; set; }
        public float[] thetarange { get; set; }
        public float[] strtpos { get; set; }
        public float[] theta { get; private set; }
        public float[] dist { get; private set; }
        public string rawfile { get; set; }
        private string _hnum;

        public PassiveRangeOfMotion(string hnum, float maxf, float segDur, bool fromdisk)
        {
            _hnum = hnum;
            // Is the data to be read from disk?
            if (fromdisk)
            {
                // Read the most recent AROM from the AROM file.
                string prevLine = "";
                string _fname = Path.Combine(SubjectData.Get_Subj_Assessment_Dir(hnum), "prom.csv");
                //Debug.Log(_fname);
                using (StreamReader file = new StreamReader(_fname))
                {
                    // Read the header out.
                    file.ReadLine();
                    file.ReadLine();
                    while (!file.EndOfStream)
                    {
                        prevLine = file.ReadLine();
                    }
                }
                // If prevLine is empty, then there is no previous data
                if (prevLine.Length == 0)
                {
                    datetime = null;
                    strttime = null;
                    dur = -1.0f;
                    fmax = -1.0f;
                    segdur = -1.0f;
                    thetarange = null;
                    strtpos = null;
                    theta = null;
                    dist = null;
                    rawfile = null;
                }
                else
                {
                    // Parse line to AROM data.
                    parseLineToPROM(prevLine);
                }
            }
            else
            {
                // New PROM.
                datetime = DateTime.Now.ToString("Dyyyy-MM-ddTHH-mm-ss");
                strtpos = new float[] { 0f, 0f };
                fmax = maxf;
                segdur = segDur;
                thetarange = new float[] { 0f, 0f };
                // Initialize theta and dist values
                theta = new float[37];
                dist = new float[37];
                for (int i = 0; i < theta.Length; i++)
                {
                    theta[i] = i * 5;
                    dist[i] = -1;
                }
            }
        }

        private void parseLineToPROM(string prevLine)
        {
            string[] _data = prevLine.Split(',');
            //Debug.Log(prevLine);
            // Date time, start time and duration.
            datetime = _data[0];
            strttime = _data[1];
            dur = float.Parse(_data[2]);
            fmax = float.Parse(_data[3]);
            segdur = float.Parse(_data[4]);

            // Theta range
            string[] _val = _data[5].Split('|');
            thetarange = new float[] { float.Parse(_val[0]), float.Parse(_val[1]) };
            
            // Start position
            string[] _pos = _data[6].Split('|');
            strtpos = new float[] { float.Parse(_pos[0]), float.Parse(_pos[1]) };

            // Theta and dist
            string[] _teta = _data[7].Split('|');
            string[] _dist = _data[8].Split('|');
            theta = new float[_teta.Length];
            dist = new float[_dist.Length];
            for (int i = 0; i < _teta.Length; i++)
            {
                theta[i] = float.Parse(_teta[i]);
                dist[i] = float.Parse(_dist[i]);
            }

            // Raw file
            rawfile = _data[9];
        }

        public void setPROMDist(float angle, float r)
        {
            // Make sure the angle is in range and r is positive.
            if (((180 / Math.PI) * angle >= theta[0]) &&
                ((180 / Math.PI) * angle <= theta[theta.Length - 1]) &&
                (r >= 0))
            {
                int inx = (int)Math.Round(theta.Length * angle / Math.PI);
                if (dist[inx] < r)
                {
                    dist[inx] = r;
                }
            }
        }

        public void WriteToAssessmentFile()
        {
            string _fname = Path.Combine(SubjectData.Get_Subj_Assessment_Dir(_hnum), "prom.csv");
            StringBuilder strbldr = new StringBuilder($"{datetime},{strttime},{dur:000.0},");
            strbldr.Append($"{fmax},{segdur},{thetarange[0]}|{thetarange[1]},");
            strbldr.Append($"{strtpos[0]}|{strtpos[1]},");
            // theta and distnace
            StringBuilder _t = new StringBuilder($"{theta[0]}");
            StringBuilder _d = new StringBuilder($"{dist[0]}");
            for (int i = 1; i < theta.Length; i++)
            {
                _t.Append($"|{theta[i]}");
                _d.Append($"|{dist[i]}");
            }
            strbldr.Append($"{_t.ToString()},{_d.ToString()},{rawfile}");
            using (StreamWriter file = new StreamWriter(_fname, true))
            {
                file.WriteLine(strbldr.ToString());
            }
        }

        public static void CreatePROMFile(string dir, string subj)
        {
            using (StreamWriter file = new StreamWriter(Path.Combine(dir, "prom.csv"), true))
            {
                file.WriteLine($"subj:{subj}\ndatetime,starttime,duration,startpos,theta distance,rawfile");
            }
        }
    }

    // Active Range of motion
    public class ActiveRangeOfMotion
    {
        public string datetime { get; private set; }
        public string strttime { get; set; }
        public float dur { get; set; }
        public float[] strtpos { get; set; }
        public float[] theta { get; private set; }
        public float[] dist { get; private set; }
        public string rawfile { get; set; }
        private string _hnum;

        public ActiveRangeOfMotion(string hnum, bool fromdisk)
        {
            _hnum = hnum;
            // Is the data to be read from disk?
            if (fromdisk)
            {
                // Read the most recent AROM from the AROM file.
                string prevLine = "";
                string _fname = Path.Combine(SubjectData.Get_Subj_Assessment_Dir(hnum), "arom.csv");
                using (StreamReader file = new StreamReader(_fname))
                {
                    // Read the header out.
                    file.ReadLine();
                    file.ReadLine();
                    while (!file.EndOfStream)
                    {
                        prevLine = file.ReadLine();
                    }
                }
                // If prevLine is empty, then there is no previous data
                //Debug.Log(prevLine);
                if (prevLine.Length == 0)
                {
                    datetime = null;
                    strttime = null;
                    dur = -1.0f;
                    strtpos = null;
                    theta = null;
                    dist = null;
                    rawfile = null;
                } else
                {
                    // Parse line to AROM data.
                    parseLineToAROM(prevLine);
                }
            } else
            {
                // New AROM.
                datetime = DateTime.Now.ToString("Dyyyy-MM-ddTHH-mm-ss");
                strtpos = new float[] { 0f, 0f };
                // Initialize theta and dist values
                theta = new float[37];
                dist = new float[37];
                for (int i = 0; i < theta.Length; i++)
                {
                    theta[i] = i * 5;
                    dist[i] = -1;
                }
            }
        }

        private void parseLineToAROM(string prevLine)
        {
            string[] _data = prevLine.Split(',');

            // Date time, start time and duration.
            datetime = _data[0];
            strttime = _data[1];
            dur = float.Parse(_data[2]);

            // Start position
            string[] _pos = _data[3].Split('|');
            strtpos = new float[] { float.Parse(_pos[0]), float.Parse(_pos[1]) };
            
            // Theta and dist
            string[] _teta = _data[4].Split('|');
            string[] _dist= _data[5].Split('|');
            theta = new float[_teta.Length];
            dist = new float[_dist.Length];
            for (int i = 0; i < _teta.Length; i++)
            {
                theta[i] = float.Parse(_teta[i]);
                dist[i] = float.Parse(_dist[i]);
            }

            // Raw file
            rawfile = _data[6];
        }

        public void setAROMDist(float angle, float r)
        {
            // Make sure the angle is in range and r is positive.
            if (((180 / Math.PI) * angle >= theta[0]) &&
                ((180 / Math.PI) * angle <= theta[theta.Length - 1]) &&
                (r >= 0))
            {
                int inx = (int)Math.Round(theta.Length * angle / Math.PI);
                if (dist[inx] < r)
                {
                    dist[inx] = r;
                }
            }
        }

        public void WriteToAssessmentFile()
        {
            string _fname = Path.Combine(SubjectData.Get_Subj_Assessment_Dir(_hnum), "arom.csv");
            StringBuilder strbldr = new StringBuilder($"{datetime},{strttime},{dur:000.0},");
            strbldr.Append($"{strtpos[0]}|{strtpos[1]},");
            // theta and distnace
            StringBuilder _t = new StringBuilder($"{theta[0]}");
            StringBuilder _d = new StringBuilder($"{dist[0]}");
            for (int i = 1; i < theta.Length; i++)
            {
                _t.Append($"|{theta[i]}");
                _d.Append($"|{dist[i]}");
            }
            strbldr.Append($"{_t.ToString()},{_d.ToString()},{rawfile}");
            using (StreamWriter file = new StreamWriter(_fname, true))
            {
                file.WriteLine(strbldr.ToString());
            }
        }

        public static void CreateAROMFile(string dir, string subj)
        {
            using (StreamWriter file = new StreamWriter(Path.Combine(dir, "arom.csv"), true))
            {
                file.WriteLine($"subj:{subj}\ndatetime,starttime,duration,startpos,theta distance,rawfile");
            }
        }
    }

    static public class PlaeboModel
    {
        // Robot mechanism parameters
        static public float a = 705f;
        static public float lMin = 560f;
        static public float lMax = 800f;

        static public float[,] getRobotBoundary(int N)
        {
            float[,] bndry = new float[N + 1, 2];
            // Go through the length values for the boundary
            // and get x,y position.
            float[] _pos;
            float _lL, _lR;
            float _dL = 4 * (lMax - lMin) / N;
            // Segment 1
            for (int seg = 0; seg < 4; seg++)
            {
                for (int i = 0; i < N / 4; i++)
                {
                    switch (seg)
                    {
                        case 0:
                            // lR Max, lL Max to Min
                            _lR = lMax;
                            _lL = lMax - _dL * i;
                            break;
                        case 1:
                            // lR Max to Min, lL Min
                            _lL = lMin;
                            _lR = lMax - _dL * i;
                            break;
                        case 2:
                            // lR Min, lL Min to Max
                            _lR = lMin;
                            _lL = lMin + _dL * i;
                            break;
                        default:
                            // lR Min to Max, lL Max
                            _lL = lMax;
                            _lR = lMin + _dL * i;
                            break;
                    }
                    _pos = ForwardKinematics_L2P(_lL, _lR);
                    bndry[(N * seg / 4) + i, 0] = _pos[0];
                    bndry[(N * seg / 4) + i, 1] = _pos[1];
                }
            }
            bndry[N, 0] = bndry[0, 0];
            bndry[N, 1] = bndry[0, 1];
            return bndry;
        }

        static public float[] robotWorkspaceCenter()
        {
            float[,] _bndry = getRobotBoundary(100);
            float _cx = 0f;
            float _cy = 0f;
            for (int i = 0; i < 100; i++)
            {
                _cx += _bndry[i, 0];
                _cy += _bndry[i, 1];
            }
            return new float[2] { _cx / 100, _cy / 100 };
        }

        static public float[] robotWorkspaceRectDim()
        {
            float[] _pos1 = ForwardKinematics_L2P(lMin, lMax);
            float[] _pos2 = ForwardKinematics_L2P(lMax, lMin);
            float[] _pos3 = ForwardKinematics_L2P(lMin, lMin);
            float[] _pos4 = ForwardKinematics_L2P(lMax, lMax);
            return new float[] { _pos2[0] - _pos1[0], _pos3[1] - _pos4[1] };
        }

        static public float[] ForwardKinematics_L2P(float lL, float lR)
        {
            float _x;
            // X position
            _x = (float) (Math.Pow(lL, 2) - Math.Pow(lR, 2)) / (2 * a);
            // Y position
            float _y1 = (float) Math.Sqrt(Math.Pow(lL, 2) - Math.Pow(0.5 * a + _x, 2));
            float _y2 = (float) Math.Sqrt(Math.Pow(lR, 2) - Math.Pow(0.5 * a - _x, 2));
            return new float[] { _x, - 0.5f * (_y1 + _y2) };
        }
    }
}