//+------------------------------------------------------------------+
//| Export_Risk_Bars.mq5  (Claude 2026-06-09)                        |
//| Dump H1+D1 OHLC for the equity-index + gold cross-section to CSV |
//| (MQL5/Files) for risk-on/off cross-ASSET-CLASS edge discovery.   |
//| Run headless on the dedicated T_Export terminal via .ini         |
//| ([StartUp] Script=Export_Risk_Bars ShutdownTerminal=1).          |
//+------------------------------------------------------------------+
void DumpTF(const string sym, const ENUM_TIMEFRAMES tf, const string tfname)
{
   if(!SymbolSelect(sym, true)) { PrintFormat("SELECT_FAIL %s", sym); return; }
   MqlRates r[];
   ArraySetAsSeries(r, false);
   datetime from = D'2017.01.01 00:00';
   int n = CopyRates(sym, tf, from, TimeCurrent(), r);
   if(n <= 0) { PrintFormat("COPYRATES_0 %s %s err=%d", sym, tfname, GetLastError()); return; }
   string fn = sym + "_" + tfname + ".csv";
   int h = FileOpen(fn, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE) { PrintFormat("FOPEN_FAIL %s err=%d", fn, GetLastError()); return; }
   FileWrite(h, "time", "open", "high", "low", "close", "tickvol");
   for(int i = 0; i < n; i++)
      FileWrite(h, (long)r[i].time,
                DoubleToString(r[i].open, 3),
                DoubleToString(r[i].high, 3),
                DoubleToString(r[i].low, 3),
                DoubleToString(r[i].close, 3),
                (long)r[i].tick_volume);
   FileClose(h);
   PrintFormat("WROTE %s rows=%d first=%s last=%s", fn, n,
               TimeToString(r[0].time), TimeToString(r[n - 1].time));
}

void OnStart()
{
   string syms[] = { "NDX.DWX", "SP500.DWX", "GDAXI.DWX", "WS30.DWX", "XAUUSD.DWX" };
   for(int i = 0; i < ArraySize(syms); i++)
   {
      DumpTF(syms[i], PERIOD_H1, "H1");
      DumpTF(syms[i], PERIOD_D1, "D1");
   }
   Print("EXPORT_DONE");
}
