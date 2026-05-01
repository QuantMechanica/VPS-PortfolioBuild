//+------------------------------------------------------------------+
//|                                       Compile_Custom_Bars_QM.mq5 |
//|                                              QuantMechanica V5    |
//|                                                                   |
//|  Forces MT5 to compile M1 bar history from existing tick data    |
//|  for custom .DWX symbols. Run once per terminal (T1..T5) by       |
//|  drag-dropping onto any chart.                                    |
//|                                                                   |
//|  Origin: Board Advisor 2026-05-01 at OWNER directive.             |
//|  Authority: QUA-684 D2; DL-054 Gate 1.                            |
//|  Audit: D:\QM\reports\setup\tick-data-timezone\                   |
//|         QUA-684_D2_BAR_COMPILATION_AUDIT_2026-05-01.md            |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict
#property copyright "QuantMechanica V5 / Board Advisor"
#property version "1.00"
#property description "Compile M1 bars from ticks for missing-history custom symbols."

input string Symbols =
   "AUDCAD.DWX,AUDCHF.DWX,AUDJPY.DWX,AUDNZD.DWX,AUDUSD.DWX,"
   "CADCHF.DWX,CADJPY.DWX,CHFJPY.DWX,"
   "EURAUD.DWX,EURCAD.DWX,EURCHF.DWX,EURGBP.DWX,EURJPY.DWX,EURNZD.DWX,"
   "GBPAUD.DWX,GBPCAD.DWX,GBPCHF.DWX,GBPJPY.DWX,GBPNZD.DWX,GBPUSD.DWX,"
   "GDAXIm.DWX,JPN225.DWX,NDXm.DWX,UK100.DWX,"
   "NZDCAD.DWX,NZDCHF.DWX,NZDJPY.DWX,NZDUSD.DWX,"
   "USDCAD.DWX,USDCHF.DWX,USDJPY.DWX,"
   "XAGUSD.DWX,XAUUSD.DWX,XBRUSD.DWX,XNGUSD.DWX";  // 33 missing-history symbols (EURUSD/WS30/XTIUSD already compiled)

input datetime FromDate = D'2017.01.01 00:00';
input datetime ToDate   = D'2026.05.01 00:00';

string g_log_path;

void Log(const string msg)
  {
   Print(msg);
   if(g_log_path != "")
     {
      int h = FileOpen(g_log_path, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
      if(h != INVALID_HANDLE)
        {
         FileSeek(h, 0, SEEK_END);
         FileWriteString(h, msg + "\r\n");
         FileClose(h);
        }
     }
  }

void OnStart()
  {
   datetime now_utc = TimeGMT();
   string ts = TimeToString(now_utc, TIME_DATE|TIME_SECONDS);
   StringReplace(ts, ":", "");
   StringReplace(ts, ".", "");
   StringReplace(ts, " ", "_");
   g_log_path = "compile_custom_bars_" + ts + ".log";

   string syms[];
   int n = StringSplit(Symbols, ',', syms);
   Log(StringFormat("[Compile_Custom_Bars_QM] start: n=%d range=%s..%s",
                    n,
                    TimeToString(FromDate, TIME_DATE),
                    TimeToString(ToDate, TIME_DATE)));

   int ok_count = 0;
   int fail_count = 0;

   for(int i = 0; i < n; i++)
     {
      string sym = syms[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(StringLen(sym) == 0) continue;

      if(!SymbolSelect(sym, true))
        {
         Log(StringFormat("[FAIL_SELECT] %s", sym));
         fail_count++;
         continue;
        }

      // Force MT5 to load tick history for the requested range, then build M1 bars.
      MqlTick ticks[];
      int tick_n = CopyTicksRange(sym, ticks, COPY_TICKS_ALL,
                                  (long)FromDate * 1000,
                                  (long)ToDate   * 1000);

      // Then request M1 bars over the full range.
      MqlRates rates[];
      int rates_n = CopyRates(sym, PERIOD_M1, FromDate, ToDate, rates);

      // Then check Bars() to confirm.
      int bars_now = Bars(sym, PERIOD_M1);

      datetime first_bar = (rates_n > 0) ? rates[0].time : 0;
      datetime last_bar  = (rates_n > 0) ? rates[rates_n-1].time : 0;

      if(rates_n > 0 && bars_now > 0)
        {
         ok_count++;
         Log(StringFormat("[OK] %s: ticks=%d rates=%d Bars=%d first=%s last=%s",
                          sym, tick_n, rates_n, bars_now,
                          TimeToString(first_bar, TIME_DATE),
                          TimeToString(last_bar, TIME_DATE)));
        }
      else
        {
         fail_count++;
         Log(StringFormat("[FAIL] %s: ticks=%d rates=%d Bars=%d err=%d",
                          sym, tick_n, rates_n, bars_now, GetLastError()));
        }

      // Brief pause to let MT5 flush .hcc to disk.
      Sleep(200);
     }

   Log(StringFormat("[Compile_Custom_Bars_QM] done: ok=%d fail=%d total=%d",
                    ok_count, fail_count, n));
   Log(StringFormat("[Compile_Custom_Bars_QM] log: %s\\Files\\%s",
                    TerminalInfoString(TERMINAL_DATA_PATH), g_log_path));
   Log("[Compile_Custom_Bars_QM] After completion, verify with:");
   Log("  python D:\\QM\\mt5\\T1\\dwx_import\\verify_import.py");
   Log("[Compile_Custom_Bars_QM] If T1 OK, copy bases\\Custom\\history\\ to T2..T5.");
  }
//+------------------------------------------------------------------+
