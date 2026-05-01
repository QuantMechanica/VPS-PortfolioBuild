//+------------------------------------------------------------------+
//|                                  Compile_Custom_Bars_QM_v2.mq5   |
//|                                              QuantMechanica V5    |
//|                                                                   |
//|  v2 — Aggregates existing in-MT5 ticks into M1 bars and writes    |
//|  via CustomRatesUpdate. Replaces v1 which used CopyRates and      |
//|  failed because CopyRates does NOT synthesize bars from ticks —   |
//|  it only reads pre-existing .hcc files.                           |
//|                                                                   |
//|  Process: for each symbol → for each year (2017..2024) →           |
//|  for each month → CopyTicksRange → aggregate ticks to M1 →        |
//|  CustomRatesUpdate.                                                |
//|                                                                   |
//|  Origin: Board Advisor 2026-05-01 at OWNER directive.              |
//|  Authority: QUA-684 D2; DL-054 Gate 1.                             |
//|  Audit: docs/ops/QUA-684_D2_BAR_COMPILATION_AUDIT_2026-05-01.md   |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict
#property copyright "QuantMechanica V5 / Board Advisor"
#property version "2.00"
#property description "Aggregate in-MT5 ticks to M1 bars; write via CustomRatesUpdate."

input int    YearFrom = 2017;
input int    YearTo   = 2024;       // up to and including
input int    MinBarsToSkip = 50000; // if Bars(symbol, M1) >= this at start, skip the symbol
input bool   DryRun = false;        // log only, do not call CustomRatesUpdate

// 33 missing-history .DWX symbols. EURUSD/WS30/XTIUSD already have full history.
string g_symbols[] = {
   "AUDCAD.DWX","AUDCHF.DWX","AUDJPY.DWX","AUDNZD.DWX","AUDUSD.DWX",
   "CADCHF.DWX","CADJPY.DWX","CHFJPY.DWX",
   "EURAUD.DWX","EURCAD.DWX","EURCHF.DWX","EURGBP.DWX","EURJPY.DWX","EURNZD.DWX",
   "GBPAUD.DWX","GBPCAD.DWX","GBPCHF.DWX","GBPJPY.DWX","GBPNZD.DWX","GBPUSD.DWX",
   "GDAXIm.DWX","JPN225.DWX","NDXm.DWX","UK100.DWX",
   "NZDCAD.DWX","NZDCHF.DWX","NZDJPY.DWX","NZDUSD.DWX",
   "USDCAD.DWX","USDCHF.DWX","USDJPY.DWX",
   "XAGUSD.DWX","XAUUSD.DWX","XBRUSD.DWX","XNGUSD.DWX"
};

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

// First/last day-of-month in seconds since epoch.
long MonthStartMs(int year, int month)
  {
   MqlDateTime dt; ZeroMemory(dt);
   dt.year = year; dt.mon = month; dt.day = 1;
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return (long)StructToTime(dt) * 1000;
  }

long MonthEndMs(int year, int month)
  {
   int ny = year, nm = month + 1;
   if(nm > 12) { nm = 1; ny++; }
   return MonthStartMs(ny, nm) - 1;
  }

// Aggregate ticks into M1 bars.
int AggregateTicksToM1(MqlTick &ticks[], int n_ticks, MqlRates &out_bars[])
  {
   ArrayResize(out_bars, 0);
   if(n_ticks <= 0) return 0;

   datetime cur_minute = 0;
   MqlRates bar; ZeroMemory(bar);
   bool have_bar = false;

   for(int i = 0; i < n_ticks; i++)
     {
      double price = ticks[i].bid;
      if(price <= 0.0) price = ticks[i].last;
      if(price <= 0.0) continue;

      // Tick time in msc → seconds → minute boundary.
      datetime t_sec = (datetime)(ticks[i].time_msc / 1000);
      datetime minute = t_sec - (t_sec % 60);

      if(minute != cur_minute)
        {
         if(have_bar)
           {
            int sz = ArraySize(out_bars);
            ArrayResize(out_bars, sz + 1);
            out_bars[sz] = bar;
           }
         ZeroMemory(bar);
         bar.time = minute;
         bar.open = price;
         bar.high = price;
         bar.low  = price;
         bar.close = price;
         bar.tick_volume = 1;
         bar.real_volume = 0;
         bar.spread = (int)((ticks[i].ask - ticks[i].bid) * 100000.0);
         cur_minute = minute;
         have_bar = true;
        }
      else
        {
         if(price > bar.high) bar.high = price;
         if(price < bar.low)  bar.low  = price;
         bar.close = price;
         bar.tick_volume++;
        }
     }
   if(have_bar)
     {
      int sz = ArraySize(out_bars);
      ArrayResize(out_bars, sz + 1);
      out_bars[sz] = bar;
     }
   return ArraySize(out_bars);
  }

// Process one symbol.
bool ProcessSymbol(const string sym, int &out_total_bars_written)
  {
   out_total_bars_written = 0;
   if(!SymbolSelect(sym, true))
     {
      Log(StringFormat("[FAIL_SELECT] %s err=%d", sym, GetLastError()));
      return false;
     }

   int existing = (int)Bars(sym, PERIOD_M1);
   if(existing >= MinBarsToSkip)
     {
      Log(StringFormat("[SKIP] %s already has Bars(M1)=%d (>= %d)", sym, existing, MinBarsToSkip));
      return true;
     }

   ulong t0 = GetTickCount64();
   long total_written = 0;

   for(int y = YearFrom; y <= YearTo; y++)
     {
      for(int m = 1; m <= 12; m++)
        {
         long from_ms = MonthStartMs(y, m);
         long to_ms   = MonthEndMs(y, m);

         MqlTick ticks[];
         int n = CopyTicksRange(sym, ticks, COPY_TICKS_INFO, from_ms, to_ms);
         if(n <= 0) continue;

         MqlRates bars[];
         int b = AggregateTicksToM1(ticks, n, bars);
         if(b <= 0) continue;

         if(!DryRun)
           {
            ResetLastError();
            int updated = CustomRatesUpdate(sym, bars);
            if(updated < 0)
              {
               Log(StringFormat("[ERR_RATES_UPDATE] %s %d-%02d ticks=%d bars=%d err=%d",
                                sym, y, m, n, b, GetLastError()));
               return false;
              }
            total_written += updated;
           }
         else
           {
            total_written += b;
           }
        }
      // brief breath to let MT5 flush
      Sleep(50);
     }

   ulong elapsed_s = (GetTickCount64() - t0) / 1000;
   int bars_after = (int)Bars(sym, PERIOD_M1);
   out_total_bars_written = (int)total_written;

   if(total_written > 0)
     {
      Log(StringFormat("[OK] %s wrote=%I64d bars Bars()=%d in %I64us",
                       sym, total_written, bars_after, elapsed_s));
      return true;
     }
   Log(StringFormat("[FAIL] %s wrote=0 bars Bars()=%d in %I64us", sym, bars_after, elapsed_s));
   return false;
  }

void OnStart()
  {
   datetime now = TimeGMT();
   string ts = TimeToString(now, TIME_DATE|TIME_SECONDS);
   StringReplace(ts, ":", ""); StringReplace(ts, ".", ""); StringReplace(ts, " ", "_");
   g_log_path = "compile_custom_bars_v2_" + ts + ".log";

   int n = ArraySize(g_symbols);
   Log(StringFormat("[Compile_Custom_Bars_QM_v2] start: n=%d years=%d..%d dry=%s",
                    n, YearFrom, YearTo, DryRun ? "true" : "false"));

   int ok = 0, fail = 0, skip = 0;
   long grand_total = 0;
   for(int i = 0; i < n; i++)
     {
      int written = 0;
      bool ok_b = ProcessSymbol(g_symbols[i], written);
      if(written > 0 && ok_b) { ok++; grand_total += written; }
      else if(ok_b)           { skip++; }
      else                    { fail++; }
     }

   Log(StringFormat("[Compile_Custom_Bars_QM_v2] done: ok=%d skip=%d fail=%d total_bars=%I64d",
                    ok, skip, fail, grand_total));
   Log(StringFormat("[Compile_Custom_Bars_QM_v2] log file: %s\\Files\\%s",
                    TerminalInfoString(TERMINAL_DATA_PATH), g_log_path));
  }
//+------------------------------------------------------------------+
