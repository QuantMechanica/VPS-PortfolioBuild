//+------------------------------------------------------------------+
//|  QM_Probe_NewsFile.mq5                                           |
//|                                                                  |
//|  Diagnostic probe: determine WHICH FileOpen path MT5 can use to  |
//|  reach the QM news calendar. The EA's QM_NewsInit calls          |
//|     FileOpen("D:\QM\data\news_calendar\news_calendar_2015_2025.csv")
//|  and that fails post-reboot. This probe tries that exact path    |
//|  plus sandbox-relative / colon-stripped / Common-folder variants |
//|  and reports which one yields a valid handle.                    |
//|                                                                  |
//|  Run: Navigator -> Scripts -> drag onto any chart.               |
//|  Read the result in the Experts log (Toolbox -> Experts).        |
//+------------------------------------------------------------------+
#property copyright "QuantMechanica"
#property version   "1.00"
#property strict
#property description "Probe which FileOpen path reaches the news calendar CSV"

void Probe(const string label, const string path, const int extraFlags)
  {
   ResetLastError();
   int h = FileOpen(path, FILE_READ | FILE_BIN | FILE_SHARE_READ | extraFlags);
   const int err = GetLastError();
   if(h != INVALID_HANDLE)
     {
      const ulong sz = FileSize(h);
      FileClose(h);
      PrintFormat("[ OPEN OK ] %-8s size=%I64u  path=%s", label, sz, path);
     }
   else
     {
      PrintFormat("[open FAIL] %-8s err=%d  path=%s", label, err, path);
     }
  }

void OnStart()
  {
   Print("===== QM_Probe_NewsFile =====");
   PrintFormat("MQL_TESTER          = %d", (int)MQLInfoInteger(MQL_TESTER));
   PrintFormat("TERMINAL_DATA_PATH  = %s", TerminalInfoString(TERMINAL_DATA_PATH));
   PrintFormat("TERMINAL_COMMONDATA = %s", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
   Print("--- FileOpen news_calendar_2015_2025.csv: SANDBOX vs COMMON ---");

   string cands[5];
   cands[0] = "D:\\QM\\data\\news_calendar\\news_calendar_2015_2025.csv"; // exact EA call (absolute)
   cands[1] = "news_calendar_2015_2025.csv";                              // bare, sandbox/common root
   cands[2] = "D\\QM\\data\\news_calendar\\news_calendar_2015_2025.csv";  // colon-stripped mirror
   cands[3] = "QM\\news_calendar_2015_2025.csv";                          // QM subfolder
   cands[4] = "news_calendar\\news_calendar_2015_2025.csv";               // news_calendar subfolder

   for(int i = 0; i < 5; i++)
     {
      Probe("SANDBOX", cands[i], 0);
      Probe("COMMON",  cands[i], FILE_COMMON);
     }
   Print("===== probe done =====");
   Print(">>> Send the [ OPEN OK ] lines back. That path is where the news CSV must live.");
  }
//+------------------------------------------------------------------+
