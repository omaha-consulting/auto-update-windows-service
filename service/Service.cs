using System;
using System.IO;
using System.ServiceProcess;
using System.Timers;

namespace OmahaDemoService
{
    public partial class Service : ServiceBase
    {
        Timer timer = new Timer();
        string version = "0.0.0.2";
        public Service()
        {
            InitializeComponent();
        }
        protected override void OnStart(string[] args)
        {
            Log("started");
            timer.Elapsed += new ElapsedEventHandler(OnElapsedTime);
            timer.Interval = 5000;
            timer.Enabled = true;
        }
        protected override void OnStop()
        {
            Log("stopped");
        }
        private void OnElapsedTime(object source, ElapsedEventArgs e)
        {
            Log("still running");
        }
        public void Log(string Message)
        {
            string fullMessage = DateTime.Now + " v" + version + " " + Message;
            string filepath = "C:\\OmahaDemoService.log";
            if (!File.Exists(filepath))
            {
                // Create a file to write to.   
                using (StreamWriter sw = File.CreateText(filepath))
                {
                    sw.WriteLine(fullMessage);
                }
            }
            else
            {
                using (StreamWriter sw = File.AppendText(filepath))
                {
                    sw.WriteLine(fullMessage);
                }
            }
        }
    }
}