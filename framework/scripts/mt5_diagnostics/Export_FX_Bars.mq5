//+------------------------------------------------------------------+
//| Export_FX_Bars.mq5                                               |
//| One-shot exporter: dump H1 + D1 OHLC for the FX cross-section to |
//| CSV under <terminal>/MQL5/Files/ for cross-asset lead-lag /      |
//| relative-value edge DISCOVERY (Claude, 2026-06-09).              |
//|                                                                  |
//| Run headless on a DEDICATED terminal (never a factory-rotation   |
//| terminal) via an .ini:                                           |
//|   [StartUp]                                                      |
//|   Script=Export_FX_Bars                                          |
//|   ShutdownTerminal=1                                             |
//| No inputs / no script_show_inputs -> no blocking dialog headless.|
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
                DoubleToString(r[i].open, 6),
                DoubleToString(r[i].high, 6),
                DoubleToString(r[i].low, 6),
                DoubleToString(r[i].close, 6),
                (long)r[i].tick_volume);
   FileClose(h);
   PrintFormat("WROTE %s rows=%d first=%s last=%s", fn, n,
               TimeToString(r[0].time), TimeToString(r[n - 1].time));
}

void OnStart()
{
   string syms[] = {
      "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "USDCHF.DWX", "USDCAD.DWX",
      "AUDUSD.DWX", "NZDUSD.DWX", "EURJPY.DWX", "GBPJPY.DWX", "EURGBP.DWX",
      "AUDJPY.DWX", "EURAUD.DWX"
   };
   for(int i = 0; i < ArraySize(syms); i++)
   {
      DumpTF(syms[i], PERIOD_H1, "H1");
      DumpTF(syms[i], PERIOD_D1, "D1");
   }
   Print("EXPORT_DONE");
}
