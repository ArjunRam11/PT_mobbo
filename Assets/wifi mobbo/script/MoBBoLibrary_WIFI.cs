  using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

namespace MoBBoLibrary_WIFI
{
    /// <summary>
    /// MoBoCommands are the command send to control different aspects
    /// of the board. The commands are all single byte command, with the
    /// MSB 4 bits used as commands, and the LSB 4 bits used for parameter
    /// values.
    /// </summary>
    public enum MoBBoCommands
    {
        SET_ID = 0x00,
        STREAM_OFF = 0x10,
        STREAM_ON = 0x11,
        LED_OFF = 0x20,
        LED_ON = 0x21,
        VIBRATE_OFF = 0x30,
        VIBRATE_ON = 0x31,
        RESET_TIMER = 0x40,
        GET_STATUS = 0x50,
        REGISTER = 0x80,
    }

    // Some static constant parameter definitions.
    public static class Params
    {
        public const byte PacketSize = 32;
        public const byte BufferSize = 10;
        public const int MaxNoOfDevs = 15;
        public const int reTxMsgCount = 5;
    }

    /// <summary>
    /// Class for handling data logging.
    /// </summary>
    public class DataLogger
    {
        private string _currfilename;
        public string curr_fname
        {
            get { return _currfilename; }
        }
        public StringBuilder _filedata;
        public bool stillLogging
        {
            get { return (_filedata != null); }
        }

        public DataLogger(string filename, string header)
        {
            _currfilename = filename;
            _filedata = new StringBuilder(header);
        }

        //public void stopDataLog(bool log = true)
        //{
        //    if (log)
        //    {
        //        File.AppendAllText(_currfilename, _filedata.ToString());
        //    }
        //    _currfilename = "";
        //    _filedata = null;
        //}
        public void stopDataLog(bool log = true)
        {
            if (log)
            {
                UnityEngine.Debug.Log("stop: " + _currfilename);
                if (!string.IsNullOrEmpty(_currfilename) && _filedata != null)
                {
                    try
                    {
                        // Append data to the existing file
                        File.AppendAllText(_currfilename, _filedata.ToString());
                        _currfilename = null;
                        //_dlogger = null;
                    }
                    catch (Exception ex)
                    {
                        UnityEngine.Debug.LogError($"Failed to write to log file: {_currfilename}. Error: {ex.Message}");
                    }
                }
                else
                {
                    UnityEngine.Debug.LogWarning("Log file name or data is null/empty. Skipping file write.");
                }
            }

            UnityEngine.Debug.Log("Data appended to log file without resetting.");
        }


        public void logData(string data)
        {
            if (_filedata != null)
            {
                _filedata.Append(data);
            }
        }
    }

    public class MoBBoUdpServer
    {
        public MoBBoDeviceUDP[] mobboDevs { get; }
        public bool[] AvailableID { get; }
        private Dictionary<string, byte> IpIDMap { get; }

        public UdpClient mUdpClient;
        public IPEndPoint mLocalEP { get; }
        public IPEndPoint mRemoteEP { get; }
        public int mLocalPort { get; }
        public int mRemotePort { get; }
        public byte[] mOutBuffer;
        public byte[] mInBuffer;
        private Stopwatch _stpWatch;
        public bool isLogging => logdetailfile != null;
        private DataLogger logdetailfile;

        public MoBBoUdpServer(int _localPort, int _remotePort)
        {
            mLocalPort = _localPort;
            mLocalEP = new IPEndPoint(IPAddress.Any, mLocalPort);
            mRemotePort = _remotePort;
            mRemoteEP = null;


           

            // Initialize and bind socket.
            mUdpClient = new UdpClient(mLocalPort);
            
            mUdpClient.EnableBroadcast = true;
           
          
            // Initialize the list of devices.

            mobboDevs = new MoBBoDeviceUDP[Params.MaxNoOfDevs];
           // UnityEngine.Debug.Log("ARJUN" + Params.MaxNoOfDevs);
            //UnityEngine.Debug.Log(mLocalPort.ToString());
            //UnityEngine.Debug.Log(mRemotePort.ToString());
            //UnityEngine.Debug.Log(mobboDevs.Length.ToString());

            //  UnityEngine.Debug.Log(mobboDevs.ToString());
            AvailableID = CreateAvailableIDs();
            IpIDMap = new Dictionary<string, byte>();
            //  
            
            // Start with logging disabled
            logdetailfile = null;

            // Start timer.
            _stpWatch = new Stopwatch();
            _stpWatch.Start();
        }


        public void DisableBroadcast()
        {
            try
            {
                if (mUdpClient != null)
                {
                    // Disable broadcast capability
                    mUdpClient.EnableBroadcast = false;

                    // Optionally close the client
                    mUdpClient.Close();
                    mUdpClient = null;

                    UnityEngine.Debug.Log("Broadcasting disabled and UDP client closed.");
                }
            }
            catch (Exception e)
            {
                UnityEngine.Debug.LogError("Error while disabling broadcasting: " + e.Message);
            }
        }


        public void StartLogging(string fname)
        {
            if (logdetailfile == null)
            {
                logdetailfile = new DataLogger($"{fname}-logdetials.ldt", "Raw data logging details\n");
            }
            else
            {
                UnityEngine.Debug.Log("Reusing existing log detail file.");
            }

            // Create the names of the files.
            logdetailfile = new DataLogger($"{fname}-logdetials.ldt", "Raw data logging details\n");
            // Go through each device and start it corresponding logger.
            for (int i = 0; i < mobboDevs.Length; i++)
            {
                if (mobboDevs[i] != null)
                {
                    logdetailfile.logData($"DevID {mobboDevs[i].ID} {mobboDevs[i].StartLogger(fname)}\n");
                }
            }
            // Start time.
            string _currtime = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss.fff");
            logdetailfile.logData($"LogStart {_currtime} {_stpWatch.ElapsedMilliseconds}\n");
            UnityEngine.Debug.Log("Logging started successfully.");
        }
        public void StartLogging_p(string fname, int trial)
        {
            if (logdetailfile == null)
            {
                logdetailfile = new DataLogger($"{fname}-logdetials.ldt", "Raw data logging details\n");
            }
            else
            {
                UnityEngine.Debug.Log("Reusing existing log detail file.");
            }

            // Create the names of the files.
            logdetailfile = new DataLogger($"{fname}-logdetials.ldt", "Raw data logging details\n");
            // Go through each device and start it corresponding logger.
            for (int i = 0; i < mobboDevs.Length; i++)
            {
                if (mobboDevs[i] != null)
                {
                    logdetailfile.logData($"DevID {mobboDevs[i].ID} {mobboDevs[i].StartLogger_(fname, trial)}\n");
                }
            }
            // Start time.
            string _currtime = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss.fff");
            logdetailfile.logData($"LogStart {_currtime} {_stpWatch.ElapsedMilliseconds}\n");
            UnityEngine.Debug.Log("Logging started successfully.");
        }





        public void LogMessage(string msg)
        {
            if (logdetailfile != null)
            {
                // UnityEngine.Debug.Log($"{msg} {_stpWatch.ElapsedMilliseconds}\n");
                logdetailfile.logData($"{msg} {_stpWatch.ElapsedMilliseconds}\n");
            }
        }


        public void StopLogging()
        {
            if (logdetailfile == null)
            {
                UnityEngine.Debug.LogWarning("No active logging session to stop.");
                return;
            }
            // Stop time.
            string _currtime = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss.fff");
            // Go through each device and start it corresponding logger.
            for (int i = 0; i < mobboDevs.Length; i++)
            {
                if (mobboDevs[i] != null)
                {
                    mobboDevs[i].StopLogger();
                    UnityEngine.Debug.Log("stopped successfully");
                }
            }
            logdetailfile.logData($"LogStop {_currtime} {_stpWatch.ElapsedMilliseconds}\n");
            logdetailfile.stopDataLog(true);
            logdetailfile = null;
           
        }

        public void ClearAllDevices()
        {
            for (int i = 0; i < Params.MaxNoOfDevs; i++)
            {
                AvailableID[i] = true;
                mobboDevs[i] = null;
            }
            IpIDMap.Clear();
        }

        public void Broadcast(byte[] msg)
        {
            if (msg == null || msg.Length == 0)
            {
                UnityEngine.Debug.Log("Nothing to broadcast.");
                return;
            }
            mUdpClient.BeginSend(msg, msg.Length, new IPEndPoint(IPAddress.Broadcast, mRemotePort),
                DataSenderHandler, mUdpClient);
        }

        public void CallForRegistration()
        {
            Broadcast(new byte[] { (byte)MoBBoCommands.REGISTER, });
        }

        public void ResetTimers()
        {
            Broadcast(new byte[] { (byte)MoBBoCommands.RESET_TIMER, });
            LogMessage("ResetTime");
        }

        public void GetStatus()
        {
            Broadcast(new byte[] { (byte)MoBBoCommands.GET_STATUS, });
        }

        public void StartAll()
        {
            Broadcast(new byte[] { (byte)MoBBoCommands.STREAM_ON, });
            LogMessage("StartAll");
        }

        public void StopAll()
        {
            Broadcast(new byte[] { (byte)MoBBoCommands.STREAM_OFF, });
            LogMessage("StopAll");
        }

        public void ResetIDs()
        {
            Broadcast(new byte[] { (byte)MoBBoCommands.SET_ID, });
            LogMessage("ResetID");
        }

        public void SendToIPEP(IPEndPoint ipep, byte[] msg)
        {
            if (msg == null || msg.Length == 0)
            {
                UnityEngine.Debug.Log("Nothing to send.");
                return;
            }
            mUdpClient.BeginSend(msg, msg.Length, ipep, DataSenderHandler, mUdpClient);
        }

        public void SendToID(byte id, byte[] msg)
        { 
            if (id == 0 || msg == null || msg.Length == 0)
            {
                UnityEngine.Debug.Log("Nothing to send.");
                return;
            }
            SendToIPEP(mobboDevs[id - 1].DevIpEp, msg);
        }

        public void StartReceivingData()
        {
            try
            {
                mUdpClient.BeginReceive(new AsyncCallback(DataReceiverHandler), null);
            }
            catch (Exception e)
            {
                UnityEngine.Debug.Log(e.ToString());
            }
        }

        //CallBack
        private void DataReceiverHandler(IAsyncResult res)
        {
            IPEndPoint RemoteIpEndPoint = new IPEndPoint(IPAddress.Any, mRemotePort);
            mInBuffer = mUdpClient.EndReceive(res, ref RemoteIpEndPoint);

            // Process codes
            _HandleReceivedMessage(RemoteIpEndPoint);

            mUdpClient.BeginReceive(new AsyncCallback(DataReceiverHandler), null);
        }

        private void DataSenderHandler(IAsyncResult res)
        {
            UdpClient uc = (UdpClient)res.AsyncState;
           // UnityEngine.Debug.Log($"Message sent! [{uc.EndSend(res)}]");
            
        }

        private void _HandleReceivedMessage(IPEndPoint remoteEP)
        {
            if (mInBuffer == null || mInBuffer.Length == 0)
            {
                return;
            }

            // Check if this is data from a registered device.
            if (IsRegisteredID(mInBuffer[0]))
            {
                
                // Registered device. Handle appropriately.
                byte _id = mInBuffer[0];
                mobboDevs[_id - 1].AddPacket(mInBuffer, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff"), _stpWatch.ElapsedMilliseconds);
            }
            else
            {
                // Possibly new device. Check if the its a registration request, 
                // else ignore.
                if (mInBuffer[1] == (byte)MoBBoCommands.REGISTER)
                {
                    // Register device.
                    byte _id = GetIdForIp(remoteEP.Address.ToString());
                    if (_id == 0)
                    {
                        UnityEngine.Debug.Log("Can't register device!");
                    }
                    else
                    {
                        if (mobboDevs[_id - 1] == null)
                        {
                            mobboDevs[_id - 1] = new MoBBoDeviceUDP(_id, remoteEP);
                           // UnityEngine.Debug.Log($"New device registerted at {_id}[{remoteEP.Address}]");
                            // Set device ID.
                            for (int i = 0; i < Params.reTxMsgCount; i++)
                            {
                                SetDeviceID(_id);
                            }
                        }
                        else
                        {
                            //UnityEngine.Debug.Log($"Device exists at {_id}[{remoteEP.Address}]");
                        }
                    }
                }
            }
        }

        private void SetDeviceID(byte id)
        {
            // Send message to the the MoBBo device.
            byte _msg = (byte)((byte)MoBBoCommands.SET_ID | id);
           // UnityEngine.Debug.Log($"Setting ID {id}[{mobboDevs[id - 1].DevIpEp.Address.ToString()}]");
            SendToIPEP(mobboDevs[id - 1].DevIpEp, new byte[] { _msg });
        }

        private bool CheckIfRegisteredDevice(byte[] buffdata)
        {
            if (buffdata[0] == 0)
            {
                // 0 is not a valid ID.
                return false;
            }
            else
            {
                return IsRegisteredID(buffdata[0]);
            }
        }

        private static bool[] CreateAvailableIDs()
        {
            bool[] _id = new bool[Params.MaxNoOfDevs];
            for (int i = 0; i < Params.MaxNoOfDevs; i++)
            {
                _id[i] = true;
            }
            return _id;
        }

        public byte GetNewID()
        {
            for (int i = 0; i < AvailableID.Length; i++)
            {
                if (AvailableID[i])
                {
                    AvailableID[i] = false;
                    return (byte)(i + 1);
                }
            }
            return 0x00;
        }

        public byte GetIdForIp(string ip, bool newid=true)
        {
            // Get device IP address.
            if (!IpIDMap.ContainsKey(ip))
            {
                if (newid)
                {
                    // Get new ID.
                    IpIDMap[ip] = GetNewID();
                }
                else
                {
                    return 0x00;
                }
            }
            return IpIDMap[ip];
        }

        public bool IsRegisteredID(int id)
        {
            if (id == 0 || id >= Params.MaxNoOfDevs)
            {
                return false;
            }
            else
            {
                return !AvailableID[id - 1];
            }
        }

        public int GetNumberOfRegisteredDevices()
        {
            int cnt = 0;
            for (int i = 0; i < AvailableID.Length; i++)
            {
                if (AvailableID[i] == false)
                {
                    cnt++;
                }
            }
            return cnt;
        }

        public int[] GetRegisteredIDs()
        {
            int[] _Ids = new int[GetNumberOfRegisteredDevices()];
            int cnt = 0;
            for (int i = 0; i < AvailableID.Length; i++)
            {
                if (AvailableID[i] == false)
                {
                    _Ids[cnt++] = mobboDevs[i].ID; ;
                }
            }
            return _Ids;
        }
    }

    /// <summary>
    /// Fixed length queue to keep only the last N data.
    /// Source: https://stackoverflow.com/a/5852926
    /// </summary>
    /// 
    public class FixedSizeQueue<T>
    {
        private Queue<T> q;
        public T Last { get; private set; }
        public int Limit { get; private set; }
        public bool IsFull => q.Count == Limit;
        public int Count => q.Count;

        public FixedSizeQueue(int limit)
        {
            q = new Queue<T>();
            Limit = limit;
        }

        public void Enqueue(T obj)
        {
            Last = obj;
            q.Enqueue(obj);
            if (q.Count > Limit)
            {
                q.Dequeue();
            }
        }
    }

    /// <summary>
    /// TemporaryByteArray Buffer that acts a temporary array for doing stuff.
    /// </summary>
    /// 
    public class TemporaryByteArray
    {
        private byte[] _Data;
        public byte[] Data
        {
            get
            {
                byte[] _temp = new byte[EndIndex];
                Buffer.BlockCopy(_Data, 0, _temp, 0, EndIndex);
                return _temp;
            }
        }
        public int Size { get; private set; }
        public int EndIndex { get; private set; }

        public TemporaryByteArray(int size)
        {
            Size = size;
            _Data = new byte[Size];
            EndIndex = 0;
        }

        public void OverWrite(byte[] newdata)
        {
            Buffer.BlockCopy(newdata, 0, _Data, 0, newdata.Length);
            EndIndex = newdata.Length;
        }

        public void Append(byte[] newdata)
        {
            Buffer.BlockCopy(newdata, 0, _Data, EndIndex, newdata.Length);
            EndIndex += newdata.Length;
        }

        public void Clear()
        {
            EndIndex = 0;
        }
    }

    /// <summary>
    /// The UDP MoBBo only Handles data and does not do any communication 
    /// functions.
    /// </summary>
    public class MoBBoDeviceUDP
    {
        // Static annotation for data logging purposes.
        private static string _annotation = "0";
        public static string annotation
        {
            get { return _annotation; }
            set
            {
                if (value == "")
                {
                    _annotation = "0";
                } else
                {
                    _annotation = value;
                }
            }
        }

        public byte ID { get; private set; }
        private bool _active;
        public bool Active { get => _active; }
        public IPEndPoint DevIpEp { get; }
        public string Address => DevIpEp.Address.ToString();
        public int Port => DevIpEp.Port;
        public float DataRate { get; private set; }
        private long _currTime;
        private long _prevTime;
        private DataLogger _dlogger;

        public FixedSizeQueue<byte[]> RawBytes { get; private set; }
        public FixedSizeQueue<float[]> RawData { get; private set; }
        public byte ReservedByte1 => RawBytes.Count > 0 ? RawBytes.Last[1] : (byte)0;
        public byte ReservedByte2 => RawBytes.Count > 0 ? RawBytes.Last[2] : (byte)0;
        public byte ReservedByte3 => RawBytes.Count > 0 ? RawBytes.Last[3] : (byte)0;
        public float Time => RawData.Count > 0 ? RawData.Last[1] : 0f;
        public float F1 => RawData.Count > 0 ? RawData.Last[2] : 0f;
        public float F2 => RawData.Count > 0 ? RawData.Last[3] : 0f;
        public float F3 => RawData.Count > 0 ? RawData.Last[4] : 0f;
        public float F4 => RawData.Count > 0 ? RawData.Last[5] : 0f;
        public float F => RawData.Count > 0 ? RawData.Last[2] + RawData.Last[3] + RawData.Last[4] + RawData.Last[5] : 0f;
        public float X => RawData.Count > 0 ? RawData.Last[6] : 0f;
        public float Y => RawData.Count > 0 ? RawData.Last[7] : 0f;
        public bool LEDOn => (ReservedByte1 & 0x80) == 0x80;
        public bool VibrateOn => (ReservedByte1 & 0x40) == 0x40;
        public bool Streaming => (ReservedByte1 & 0x20) == 0x20;
        public bool islogging => _dlogger != null;

        // Variables for handling incoming data
        private byte[] recvBuffer = new byte[128];

        // Data header
        private static readonly string[] headernames = {"ID", "systime", "devtime", "f1", "f2", "f3", "f4", "x", "y", "F", "annotation"};
        public static readonly string DataHeader = $"{String.Join(",", MoBBoDeviceUDP.headernames)}\n";

        public MoBBoDeviceUDP(byte id, IPEndPoint ipep)
        {
            ID = id;
            // Add device IP address and port
            DevIpEp = ipep;
            _active = true;
            DataRate = 0;

            // Initialize buffers.
            RawBytes = new FixedSizeQueue<byte[]>(5);
            RawData = new FixedSizeQueue<float[]>(5);

            // Initialize timing variables
            //_stpWatch = new Stopwatch();
            //_stpWatch.Start();
            _currTime = 0;

            // Initialize data logger.
            _dlogger = null;
        }

        public string StartLogger(string fname)
        {
           
            // If not logging, start logger.
            if (_dlogger == null)
            {
                _dlogger = new DataLogger($"{fname}-{ID}.csv", MoBBoDeviceUDP.DataHeader);
            }
            return _dlogger.curr_fname;
        }
        public string StartLogger_(string fname, int trial)
        {
            // If not logging, start logger
            UnityEngine.Debug.Log(fname + "csvfilepath");
            UnityEngine.Debug.Log(_dlogger);

            UnityEngine.Debug.Log(trial);
            _dlogger = new DataLogger($"{fname}-{trial}-{ID}.csv", MoBBoDeviceUDP.DataHeader);
  
            return _dlogger.curr_fname;
        }

        public void StopLogger()
        {
            _dlogger.stopDataLog(true);
        }

        public void AddPacket(byte[] _tempRecvdBytes, string systime, long millis)
        {
            // Update timing variables
            _currTime = millis;

            float[] _floats = new float[(int) Params.PacketSize / 4];
            byte[] _bytes = new byte[Params.PacketSize];
            Buffer.BlockCopy(_tempRecvdBytes, 0, _bytes, 0, _tempRecvdBytes.Length); 
            Buffer.BlockCopy(_tempRecvdBytes, 0, _floats, 0, _tempRecvdBytes.Length);
            RawBytes.Enqueue(_bytes);
            RawData.Enqueue(_floats);
            // Update data rate.
            UpdateDataRate(0.001f * (_currTime - _prevTime));
            _prevTime = _currTime;

            // If a logger is set up, then save the data.
            if (_dlogger != null)
            {
                // Format current data packet.
                _dlogger.logData(MoBBoDeviceUDP.GetFormatedPacket(systime, ID, _floats));
            }
        }

        public static string GetFormatedPacket(string currTime, byte id, float[] floats)
        {
            string[] _strvals = new string[11];
            _strvals[0] = id.ToString();
            _strvals[1] = currTime;
            for (int i = 2; i < 9; i++)
            {
                _strvals[i] = floats[i - 1].ToString("F10");
            }
            float _F = floats[2] + floats[3] + floats[4] + floats[5];
            _strvals[9] = _F.ToString("F10");
            _strvals[10] = MoBBoDeviceUDP.annotation;
            return $"{String.Join(", ", _strvals)}\n";
        }

        public static byte[] StringToByteArray(string hex)
        {
            return Enumerable.Range(0, hex.Length)
                             .Where(x => x % 2 == 0)
                             .Select(x => Convert.ToByte(hex.Substring(x, 2), 16))
                             .ToArray();
        }

        public void UpdateDataRate(float dt)
        {
            if (float.IsInfinity(DataRate))
            {
                DataRate = -1f;
            } else
            {
                if (dt != 0)
                {
                    DataRate = 0.7f * DataRate + 0.3f / dt;
                }
            }
        }
    }
}
