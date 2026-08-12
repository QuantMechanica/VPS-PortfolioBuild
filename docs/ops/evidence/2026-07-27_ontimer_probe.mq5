#property strict
#property version   "1.0"
#property description "RECON A OnTimer tester-semantics probe (backtest-only, no framework, no trading)"

// =============================================================================
// PURPOSE: Empirically establish MT5 Strategy Tester OnTimer semantics against
// THIS installation and our custom .DWX symbols. Bare EA — no QM framework, no
// magic, no orders, no live path. It only measures and logs.
//
// Measures, per handler invocation:
//   * whether OnTimer fires in the tester at all
//   * simulated time (TimeCurrent) vs wall-clock (GetTickCount64) per fire
//     -> proves model-time vs wall-clock cadence
//   * a single monotonic sequence shared by OnTick and OnTimer -> ordering
//   * cross-symbol reads of a NON-host symbol's completed bars from OnTimer
//     (iTime/iClose) -> feasibility + look-ahead hazard
// Counters run in memory for every call; disk/journal writes are throttled so a
// fast timer cannot log-bomb the tester journal.
// =============================================================================

input string Probe_Secondary  = "XAUUSD.DWX"; // non-host symbol to poll from OnTimer
input bool   Probe_UseMsTimer = true;         // true=EventSetMillisecondTimer, false=EventSetTimer(sec)
input int    Probe_TimerMs    = 100;          // ms interval when Probe_UseMsTimer
input int    Probe_TimerSec   = 1;            // sec interval when !Probe_UseMsTimer
input int    Probe_MaxCsvRows = 6000;         // hard cap on CSV rows (disk safety)
input int    Probe_LogEveryN  = 1000;         // after warmup, sample 1 row per N calls of each handler
input int    Probe_WarmRows   = 300;          // log the first N calls of each handler verbatim

long   g_seq        = 0;   // monotonic sequence across BOTH handlers
long   g_tick_no    = 0;
long   g_timer_no   = 0;
ulong  g_wall_start = 0;
datetime g_sim_start = 0;
datetime g_sim_last  = 0;
int    g_fh         = INVALID_HANDLE;
int    g_csv_rows   = 0;
int    g_warm_bars  = 0;
// fires-per-sim-second histogram helpers
datetime g_cur_sec  = 0;
int      g_fires_this_sec = 0;
int      g_max_fires_per_sec = 0;

void ProbeLogRow(const string handler)
  {
   if(g_fh == INVALID_HANDLE)
      return;
   if(g_csv_rows >= Probe_MaxCsvRows)
      return;

   datetime sim        = TimeCurrent();
   datetime host_b0    = iTime(_Symbol, PERIOD_H1, 0);
   datetime host_b1    = iTime(_Symbol, PERIOD_H1, 1);
   datetime sec_b0     = iTime(Probe_Secondary, PERIOD_H1, 0);
   datetime sec_b1     = iTime(Probe_Secondary, PERIOD_H1, 1);
   double   sec_c1     = iClose(Probe_Secondary, PERIOD_H1, 1);
   // look-ahead flags:
   //  la_forming: secondary exposes a bar that OPENS in the future vs sim time
   //  la_closed : secondary's "last closed" bar has not yet closed in sim time
   int la_forming = (sec_b0 > sim) ? 1 : 0;
   int la_closed  = ((sec_b1 + 3600) > sim) ? 1 : 0;

   FileWrite(g_fh,
             (string)g_seq, handler, (string)g_tick_no, (string)g_timer_no,
             TimeToString(sim, TIME_DATE|TIME_SECONDS), (string)(long)sim,
             (string)(long)(GetTickCount64() - g_wall_start),
             TimeToString(host_b0, TIME_DATE|TIME_MINUTES),
             TimeToString(host_b1, TIME_DATE|TIME_MINUTES),
             TimeToString(sec_b0, TIME_DATE|TIME_MINUTES),
             TimeToString(sec_b1, TIME_DATE|TIME_MINUTES),
             DoubleToString(sec_c1, 3),
             (string)la_forming, (string)la_closed);
   g_csv_rows++;
  }

int OnInit()
  {
   g_wall_start = GetTickCount64();
   g_sim_start  = TimeCurrent();
   g_sim_last   = g_sim_start;

   // FW9-style secondary history sync: SymbolSelect alone does NOT load a
   // secondary symbol's history in the tester; a CopyClose forces the sync.
   SymbolSelect(Probe_Secondary, true);
   double warm[];
   ArraySetAsSeries(warm, true);
   g_warm_bars = CopyClose(Probe_Secondary, PERIOD_H1, 0, 300, warm);

   PrintFormat("PROBE_INIT host=%s sec=%s sec_warm_bars=%d in_tester=%d in_opt=%d use_ms=%d ms=%d sec=%d sim_start=%s",
               _Symbol, Probe_Secondary, g_warm_bars,
               (int)MQLInfoInteger(MQL_TESTER), (int)MQLInfoInteger(MQL_OPTIMIZATION),
               (int)Probe_UseMsTimer, Probe_TimerMs, Probe_TimerSec,
               TimeToString(g_sim_start, TIME_DATE|TIME_SECONDS));

   g_fh = FileOpen("QM_PROBE\\ontimer_probe.csv",
                   FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
   if(g_fh != INVALID_HANDLE)
      FileWrite(g_fh, "seq", "handler", "tick_no", "timer_no",
                "sim_iso", "sim_epoch", "wall_ms",
                "host_b0_open", "host_b1_open", "sec_b0_open", "sec_b1_open",
                "sec_close1", "la_forming", "la_closed");
   else
      PrintFormat("PROBE_WARN csv_open_failed err=%d", GetLastError());

   if(Probe_UseMsTimer)
      EventSetMillisecondTimer(Probe_TimerMs);
   else
      EventSetTimer(Probe_TimerSec);

   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   g_seq++;
   g_tick_no++;
   if(g_tick_no <= Probe_WarmRows || (g_tick_no % Probe_LogEveryN) == 0)
      ProbeLogRow("TICK");
  }

void OnTimer()
  {
   g_seq++;
   g_timer_no++;

   datetime sim = TimeCurrent();
   if(sim == g_cur_sec)
     {
      g_fires_this_sec++;
     }
   else
     {
      if(g_fires_this_sec > g_max_fires_per_sec)
         g_max_fires_per_sec = g_fires_this_sec;
      g_cur_sec = sim;
      g_fires_this_sec = 1;
     }
   g_sim_last = sim;

   if(g_timer_no <= Probe_WarmRows || (g_timer_no % Probe_LogEveryN) == 0)
      ProbeLogRow("TIMER");
  }

void OnDeinit(const int reason)
  {
   if(g_fires_this_sec > g_max_fires_per_sec)
      g_max_fires_per_sec = g_fires_this_sec;
   ulong wall_ms = GetTickCount64() - g_wall_start;
   long  sim_span = (long)(g_sim_last - g_sim_start);
   double fires_per_sim_sec = (sim_span > 0) ? (double)g_timer_no / (double)sim_span : 0.0;
   PrintFormat("PROBE_DONE reason=%d ticks=%d timers=%d sim_span_s=%d wall_ms=%I64u csv_rows=%d fires_per_sim_sec=%.4f max_fires_per_sim_sec=%d warm_bars=%d",
               reason, (int)g_tick_no, (int)g_timer_no, (int)sim_span, wall_ms,
               g_csv_rows, fires_per_sim_sec, g_max_fires_per_sec, g_warm_bars);
   if(g_fh != INVALID_HANDLE)
      FileClose(g_fh);
   if(Probe_UseMsTimer)
      EventKillTimer();
   else
      EventKillTimer();
  }
