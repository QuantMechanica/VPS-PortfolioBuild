//+------------------------------------------------------------------+
//|  QM_Recover_DWX_Symbols.mq5                                      |
//|                                                                  |
//|  Recovery script: after the 2026-05-22 unclean reboot the custom |
//|  symbol DEFINITIONS were lost in all factory terminals, but the  |
//|  native tick/history caches survived intact under                |
//|     bases\Custom\ticks\<SYM>\*.tkc                               |
//|     bases\Custom\history\<SYM>\*.hcc                             |
//|                                                                  |
//|  MT5 keys those caches by symbol NAME. Re-creating each custom   |
//|  symbol with the SAME name (cloning specs from the broker source)|
//|  should re-attach the surviving cache - no data re-import.       |
//|                                                                  |
//|  This script ONLY calls CustomSymbolCreate + spec patch. It      |
//|  NEVER deletes a symbol and NEVER touches the .tkc/.hcc files,   |
//|  so it cannot destroy the surviving data.                        |
//|                                                                  |
//|  InpTestOnly = true  -> re-create EURUSD.DWX only (safe probe).  |
//|  InpTestOnly = false -> re-create all 40 DWX symbols.            |
//|                                                                  |
//|  Run: Navigator -> Scripts -> drag onto any chart. Read the      |
//|  result in the Experts/Journal log.                              |
//+------------------------------------------------------------------+
#property copyright "QuantMechanica"
#property version   "1.00"
#property strict
#property script_show_inputs

input bool InpTestOnly = true;   // true: EURUSD.DWX only (probe). false: all 40.

// The 40 surviving custom symbols (from bases\Custom\ticks\).
string g_targets[40] =
  {
   "AUDCAD.DWX","AUDCHF.DWX","AUDJPY.DWX","AUDNZD.DWX","AUDUSD.DWX",
   "CADCHF.DWX","CADJPY.DWX","CHFJPY.DWX","EURAUD.DWX","EURCAD.DWX",
   "EURCHF.DWX","EURGBP.DWX","EURJPY.DWX","EURNZD.DWX","EURUSD.DWX",
   "GBPAUD.DWX","GBPCAD.DWX","GBPCHF.DWX","GBPJPY.DWX","GBPNZD.DWX",
   "GBPUSD.DWX","GDAXI.DWX","JPN225.DWX","NDX.DWX","NDXm.DWX",
   "NZDCAD.DWX","NZDCHF.DWX","NZDJPY.DWX","NZDUSD.DWX","SP500.DWX",
   "UK100.DWX","USDCAD.DWX","USDCHF.DWX","USDJPY.DWX","WS30.DWX",
   "XAGUSD.DWX","XAUUSD.DWX","XBRUSD.DWX","XNGUSD.DWX","XTIUSD.DWX"
  };

//+--- robust symbol existence check --------------------------------+
bool SymExists(const string name)
  {
   const int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
      if(SymbolName(i, false) == name)
         return true;
   return false;
  }

//+--- group path for the custom symbol, derived from broker source -+
string CustomGroupFor(const string source)
  {
   string p = SymbolInfoString(source, SYMBOL_PATH);   // e.g. "Forex\Majors\EURUSD"
   const int cut = StringLen(p);
   int last = -1;
   for(int i = 0; i < cut; i++)
      if(StringGetCharacter(p, i) == '\\')
         last = i;
   if(last < 0)
      return "Custom";
   return "Custom\\" + StringSubstr(p, 0, last);
  }

//+--- re-create one symbol; report cache re-attach -----------------+
void RecoverOne(const string target, int &created, int &skipped, int &failed)
  {
   if(SymExists(target))
     {
      PrintFormat("[skip] %s already registered", target);
      skipped++;
      return;
     }

   const string source = StringSubstr(target, 0, StringLen(target) - 4); // strip ".DWX"
   if(!SymExists(source))
     {
      PrintFormat("[FAIL] %s: broker source symbol '%s' not found - terminal connected to Darwinex?",
                  target, source);
      failed++;
      return;
     }
   SymbolSelect(source, true);

   const string group = CustomGroupFor(source);
   ResetLastError();
   if(!CustomSymbolCreate(target, group, source))
     {
      PrintFormat("[FAIL] CustomSymbolCreate(%s, group=%s, src=%s) err=%d",
                  target, group, source, GetLastError());
      failed++;
      return;
     }
   SymbolSelect(target, true);

   // TDS imports default profit/loss tick value to 0 - mirror the source.
   const double tv = SymbolInfoDouble(target, SYMBOL_TRADE_TICK_VALUE);
   CustomSymbolSetDouble(target, SYMBOL_TRADE_TICK_VALUE_PROFIT, tv);
   CustomSymbolSetDouble(target, SYMBOL_TRADE_TICK_VALUE_LOSS,   tv);

   // --- did the surviving .tkc/.hcc cache re-attach? ---
   MqlRates r[];
   const int got = CopyRates(target, PERIOD_D1, 0, 100000, r);
   const long d1bars = SeriesInfoInteger(target, PERIOD_D1, SERIES_BARS_COUNT);
   if(got > 0)
     {
      PrintFormat("[ OK ] %s created (group=%s) | D1: CopyRates=%d bars=%I64d | first=%s last=%s",
                  target, group, got, d1bars,
                  TimeToString(r[0].time, TIME_DATE), TimeToString(r[got - 1].time, TIME_DATE));
     }
   else
     {
      PrintFormat("[WARN] %s created (group=%s) but D1 history NOT visible yet "
                  "(CopyRates=%d bars=%I64d, err=%d) - cache may need a moment or a reload",
                  target, group, got, d1bars, GetLastError());
     }
   created++;
  }

void OnStart()
  {
   PrintFormat("=== QM_Recover_DWX_Symbols  (TestOnly=%s) ===", (string)InpTestOnly);
   int created = 0, skipped = 0, failed = 0;
   for(int i = 0; i < ArraySize(g_targets); i++)
     {
      if(InpTestOnly && g_targets[i] != "EURUSD.DWX")
         continue;
      RecoverOne(g_targets[i], created, skipped, failed);
     }
   PrintFormat("=== done: created=%d  skipped=%d  failed=%d ===", created, skipped, failed);
   if(InpTestOnly)
      Print(">>> PROBE: if EURUSD.DWX shows [ OK ] with first=2017.. last=2026.. then the "
            "cache re-attaches. Re-run with InpTestOnly=false to recover all 40.");
  }
//+------------------------------------------------------------------+
