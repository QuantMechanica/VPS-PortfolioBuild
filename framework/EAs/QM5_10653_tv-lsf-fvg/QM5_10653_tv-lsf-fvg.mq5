#property strict
#property version   "5.0"
#property description "QM5_10653 TradingView Liquidity Sweep + FVG (HTF sweep -> FVG-break entry)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10653 — TradingView Liquidity Sweep & FVG Strategy (mehmettopbas_)
// -----------------------------------------------------------------------------
// Mechanics (closed-bar, framework-native, .DWX-safe):
//   1. HTF liquidity = prior-Daily high / low (the levels stops cluster behind).
//   2. Liquidity sweep = intraday bar trades THROUGH the prior-Daily high (high
//      sweep -> SHORT bias) or prior-Daily low (low sweep -> LONG bias). A sweep
//      arms a directional bias that stays valid for a bounded number of bars.
//   3. Fair Value Gap = 3-bar imbalance on the execution TF:
//        bullish FVG  -> low[i-2] > high[i]      (gap up, unfilled)
//        bearish FVG  -> high[i-2] < low[i]      (gap down, unfilled)
//      Gap size must clear an ATR-relative threshold (noise filter).
//      FVGs are detected when they FORM, stored, then armed. Entry fires on a
//      LATER retrace/break bar, NOT on the same bar the gap forms.
//   4. Entry (closed-bar confirmation):
//        LONG  : low-sweep bias active AND close breaks ABOVE a qualifying
//                bearish-FVG upper boundary.
//        SHORT : high-sweep bias active AND close breaks BELOW a qualifying
//                bullish-FVG lower boundary.
//   5. Block entries when BOTH Daily high and low were swept in the same window
//      (two-sided manipulation = no clean bias).
//   6. Per-sweep attempt limit (default 1 attempt per active sweep bias).
//   7. Session filter (broker time, DST-aware) + Friday hard-close (framework).
//   8. Stop = recent structural swing (lookback) with a max-distance ATR cap.
//      TP  = RR-multiple of the realised stop distance (baseline full-close TP1).
//
// All strategy state is advanced ONCE per closed bar (AdvanceState_OnNewBar),
// keeping OnTick O(1) per the framework intraday discipline.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10653;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// --- HTF liquidity (prior-Daily high/low) ---
// Sweep bias stays valid for this many execution-TF bars after the sweep bar.
input int    sweep_bias_max_bars        = 24;
// --- Fair Value Gap detection (execution TF, 3-bar imbalance) ---
input int    fvg_atr_period             = 14;     // ATR for gap-size threshold + SL cap
input double fvg_min_atr_mult           = 0.25;   // gap must be >= this * ATR to qualify
input int    fvg_max_active             = 8;      // ring-buffer capacity of live FVGs
input int    fvg_max_age_bars           = 48;     // drop FVGs older than this (bars)
// --- Entry control ---
input int    max_attempts_per_sweep     = 1;      // per-sweep attempt limit
// --- Session filter (broker time, DST-aware). 0..24; wrap-safe. ---
input bool   use_session_filter         = true;
input int    session_start_hour_broker  = 9;      // ~London/EU + US overlap window
input int    session_end_hour_broker    = 22;
// --- Stop / target ---
input int    sl_structure_lookback      = 12;     // swing lookback for structural stop
input double sl_atr_cap_mult            = 3.0;    // max stop distance = this * ATR
input double sl_atr_buffer_mult         = 0.10;   // padding beyond the swing extreme
input double tp_rr                       = 2.0;    // TP1 RR multiple (full close baseline)

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced once per closed bar).
// -----------------------------------------------------------------------------

// Sweep bias: +1 long (low swept), -1 short (high swept), 0 none.
int      g_bias_dir          = 0;
int      g_bias_age          = 0;       // bars since the sweep that set the bias
int      g_bias_attempts     = 0;       // entries taken against the current bias
double   g_swept_day_high    = 0.0;     // the prior-Daily high level that was swept
double   g_swept_day_low     = 0.0;     // the prior-Daily low level that was swept
bool     g_high_swept_window = false;   // both-sides-swept guard, current bias window
bool     g_low_swept_window  = false;

double   g_cur_day_high      = 0.0;     // prior-Daily high/low for the current day
double   g_cur_day_low       = 0.0;
datetime g_cur_day_stamp     = 0;

double   g_last_atr          = 0.0;

// Active FVG store (ring buffer). dir: +1 bullish gap, -1 bearish gap.
int      g_fvg_dir[64];
double   g_fvg_upper[64];                // upper boundary of the gap
double   g_fvg_lower[64];                // lower boundary of the gap
int      g_fvg_age[64];                  // bars since the gap formed
bool     g_fvg_used[64];                 // already triggered an entry
int      g_fvg_count        = 0;         // live count (<= fvg_max_active, <=64)

datetime g_last_state_bar    = 0;

// Pending entry computed at AdvanceState (closed bar) and consumed by OnTick.
bool        g_entry_ready    = false;
QM_OrderType g_entry_type    = QM_BUY;
double      g_entry_price    = 0.0;
double      g_entry_sl       = 0.0;
double      g_entry_tp       = 0.0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

void ResetBias()
  {
   g_bias_dir          = 0;
   g_bias_age          = 0;
   g_bias_attempts     = 0;
   g_swept_day_high    = 0.0;
   g_swept_day_low     = 0.0;
   g_high_swept_window = false;
   g_low_swept_window  = false;
  }

// Refresh the prior-Daily high/low once per new Daily bar (structural read,
// perf-allowed: runs only inside the closed-bar gate).
void RefreshDailyLevels()
  {
   datetime d1_stamp = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_stamp <= 0)
      return;
   if(d1_stamp == g_cur_day_stamp)
      return;

   double prev_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar gated
   double prev_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: closed-bar gated
   if(prev_high <= 0.0 || prev_low <= 0.0)
      return;

   g_cur_day_high  = prev_high;
   g_cur_day_low   = prev_low;
   g_cur_day_stamp = d1_stamp;
  }

void ExpireFVGs()
  {
   int w = 0;
   for(int i = 0; i < g_fvg_count; ++i)
     {
      g_fvg_age[i]++;
      if(g_fvg_used[i])
         continue;
      if(g_fvg_age[i] > fvg_max_age_bars)
         continue;
      // compact-in-place to slot w
      g_fvg_dir[w]   = g_fvg_dir[i];
      g_fvg_upper[w] = g_fvg_upper[i];
      g_fvg_lower[w] = g_fvg_lower[i];
      g_fvg_age[w]   = g_fvg_age[i];
      g_fvg_used[w]  = false;
      w++;
     }
   g_fvg_count = w;
  }

void PushFVG(const int dir, const double upper, const double lower)
  {
   int cap = fvg_max_active;
   if(cap > 64) cap = 64;
   if(cap < 1)  cap = 1;

   if(g_fvg_count >= cap)
     {
      // drop the oldest (index 0) by shifting left
      for(int i = 1; i < g_fvg_count; ++i)
        {
         g_fvg_dir[i - 1]   = g_fvg_dir[i];
         g_fvg_upper[i - 1] = g_fvg_upper[i];
         g_fvg_lower[i - 1] = g_fvg_lower[i];
         g_fvg_age[i - 1]   = g_fvg_age[i];
         g_fvg_used[i - 1]  = g_fvg_used[i];
        }
      g_fvg_count = cap - 1;
     }

   g_fvg_dir[g_fvg_count]   = dir;
   g_fvg_upper[g_fvg_count] = upper;
   g_fvg_lower[g_fvg_count] = lower;
   g_fvg_age[g_fvg_count]   = 0;
   g_fvg_used[g_fvg_count]  = false;
   g_fvg_count++;
  }

// Detect a 3-bar FVG that just FULLY FORMED on the last closed bar.
// Bars (closed): a = shift 3, b = shift 2 (middle/displacement), c = shift 1.
//   bullish FVG : low[a] > high[c]  -> gap = [high[c], low[a]]
//   bearish FVG : high[a] < low[c]  -> gap = [high[a], low[c]]
// Store it; it is armed for entry on a LATER retrace/break bar.
void DetectFVGOnNewBar()
  {
   double high_a = iHigh(_Symbol, _Period, 3); // perf-allowed: closed-bar gated
   double low_a  = iLow(_Symbol,  _Period, 3);
   double high_c = iHigh(_Symbol, _Period, 1);
   double low_c  = iLow(_Symbol,  _Period, 1);
   if(high_a <= 0.0 || low_a <= 0.0 || high_c <= 0.0 || low_c <= 0.0)
      return;

   double min_gap = (g_last_atr > 0.0) ? (g_last_atr * fvg_min_atr_mult) : 0.0;

   // bullish gap (gap up)
   if(low_a > high_c)
     {
      double gap = low_a - high_c;
      if(gap >= min_gap && gap > 0.0)
         PushFVG(+1, low_a, high_c); // upper=low_a, lower=high_c
      return;
     }
   // bearish gap (gap down)
   if(high_a < low_c)
     {
      double gap = low_c - high_a;
      if(gap >= min_gap && gap > 0.0)
         PushFVG(-1, low_c, high_a); // upper=low_c, lower=high_a
     }
  }

// Update sweep bias from the last closed bar against prior-Daily levels.
void UpdateSweepBias()
  {
   double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar gated
   double bar_low  = iLow(_Symbol,  _Period, 1);
   if(bar_high <= 0.0 || bar_low <= 0.0)
      return;

   bool high_sweep = (g_cur_day_high > 0.0 && bar_high > g_cur_day_high);
   bool low_sweep  = (g_cur_day_low  > 0.0 && bar_low  < g_cur_day_low);

   // Age / expire an existing bias.
   if(g_bias_dir != 0)
     {
      g_bias_age++;
      if(g_bias_age > sweep_bias_max_bars)
         ResetBias();
     }

   // A low sweep arms LONG bias; a high sweep arms SHORT bias.
   if(low_sweep)
     {
      g_low_swept_window = true;
      if(g_bias_dir != +1)
        {
         g_bias_dir       = +1;
         g_bias_age       = 0;
         g_bias_attempts  = 0;
         g_swept_day_low  = g_cur_day_low;
        }
     }
   if(high_sweep)
     {
      g_high_swept_window = true;
      if(g_bias_dir != -1)
        {
         g_bias_dir       = -1;
         g_bias_age       = 0;
         g_bias_attempts  = 0;
         g_swept_day_high = g_cur_day_high;
        }
     }
  }

// Within the broker-time trading session? Wrap-safe (start may exceed end).
bool InSession(const datetime broker_now)
  {
   if(!use_session_filter)
      return true;
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_now, dt);
   int h = dt.hour;
   int s = session_start_hour_broker;
   int e = session_end_hour_broker;
   if(s == e)
      return true;
   if(s < e)
      return (h >= s && h < e);
   return (h >= s || h < e); // wrap past midnight
  }

// Build SL/TP for a side given the entry price; returns false if invalid.
bool BuildStops(const QM_OrderType side, const double entry, double &out_sl, double &out_tp)
  {
   out_sl = 0.0;
   out_tp = 0.0;
   if(entry <= 0.0)
      return false;

   double sl = QM_StopStructure(_Symbol, side, entry, sl_structure_lookback);
   if(sl <= 0.0)
      return false;

   // Pad beyond the swing extreme by a small ATR buffer.
   double buffer = (g_last_atr > 0.0) ? (g_last_atr * sl_atr_buffer_mult) : 0.0;
   if(buffer > 0.0)
      sl = QM_OrderTypeIsBuy(side) ? (sl - buffer) : (sl + buffer);

   // Enforce a maximum stop distance (ATR cap); recompute SL at the cap if wider.
   double dist = MathAbs(entry - sl);
   double cap  = (g_last_atr > 0.0) ? (g_last_atr * sl_atr_cap_mult) : 0.0;
   if(cap > 0.0 && dist > cap)
     {
      sl   = QM_OrderTypeIsBuy(side) ? (entry - cap) : (entry + cap);
      dist = cap;
     }

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(MathAbs(entry - sl) <= 0.0)
      return false;

   double tp = QM_TakeRR(_Symbol, side, entry, sl, tp_rr);
   if(tp <= 0.0)
      return false;

   out_sl = sl;
   out_tp = tp;
   return true;
  }

// Closed-bar entry evaluation. Sets the pending g_entry_* on a valid setup.
void EvaluateEntryOnNewBar()
  {
   g_entry_ready = false;

   if(g_bias_dir == 0)
      return;
   // Both-sides-swept manipulation window => no clean directional bias.
   if(g_high_swept_window && g_low_swept_window)
      return;
   if(g_bias_attempts >= max_attempts_per_sweep)
      return;

   double close_c = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar gated
   if(close_c <= 0.0)
      return;

   if(g_bias_dir == +1)
     {
      // LONG: close breaks ABOVE a qualifying bearish-FVG upper boundary.
      int best = -1;
      double best_boundary = 0.0;
      for(int i = 0; i < g_fvg_count; ++i)
        {
         if(g_fvg_used[i])            continue;
         if(g_fvg_dir[i] != -1)       continue; // bearish gap boundary for longs
         double boundary = g_fvg_upper[i];
         if(close_c > boundary)
           {
            // pick the highest broken boundary (most decisive break)
            if(best < 0 || boundary > best_boundary)
              {
               best = i;
               best_boundary = boundary;
              }
           }
        }
      if(best < 0)
         return;

      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         entry = close_c;
      double sl, tp;
      if(!BuildStops(QM_BUY, entry, sl, tp))
         return;

      g_entry_ready  = true;
      g_entry_type   = QM_BUY;
      g_entry_price  = 0.0;   // market fill at send
      g_entry_sl     = sl;
      g_entry_tp     = tp;
      g_fvg_used[best] = true;
      g_bias_attempts++;
      return;
     }

   // SHORT: close breaks BELOW a qualifying bullish-FVG lower boundary.
   int best_s = -1;
   double best_boundary_s = 0.0;
   for(int i = 0; i < g_fvg_count; ++i)
     {
      if(g_fvg_used[i])          continue;
      if(g_fvg_dir[i] != +1)     continue; // bullish gap boundary for shorts
      double boundary = g_fvg_lower[i];
      if(close_c < boundary)
        {
         if(best_s < 0 || boundary < best_boundary_s)
           {
            best_s = i;
            best_boundary_s = boundary;
           }
        }
     }
   if(best_s < 0)
      return;

   double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      entry_s = close_c;
   double sl_s, tp_s;
   if(!BuildStops(QM_SELL, entry_s, sl_s, tp_s))
      return;

   g_entry_ready  = true;
   g_entry_type   = QM_SELL;
   g_entry_price  = 0.0;
   g_entry_sl     = sl_s;
   g_entry_tp     = tp_s;
   g_fvg_used[best_s] = true;
   g_bias_attempts++;
  }

// Advance ALL closed-bar state exactly once per new execution-TF bar.
void AdvanceState_OnNewBar()
  {
   g_last_atr = QM_ATR(_Symbol, _Period, fvg_atr_period, 1);

   RefreshDailyLevels();
   ExpireFVGs();
   DetectFVGOnNewBar();
   UpdateSweepBias();
   EvaluateEntryOnNewBar();
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Only one position per EA at a time (single-entry baseline).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return true;
   if(!InSession(TimeCurrent()))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_entry_ready)
      return false;
   g_entry_ready = false; // consume the pending signal once

   req.type   = g_entry_type;
   req.price  = g_entry_price;   // 0.0 -> framework fills market
   req.sl     = g_entry_sl;
   req.tp     = g_entry_tp;
   req.reason = "lsweep_fvg_break";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Baseline: full close at TP1 (TP set on entry). No trailing / partials.
  }

bool Strategy_ExitSignal()
  {
   // Exits handled by SL/TP set at entry (full-close TP1 baseline).
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   ResetBias();
   g_fvg_count    = 0;
   g_cur_day_stamp = 0;
   g_last_state_bar = 0;
   g_entry_ready  = false;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // FIRST: advance closed-bar strategy state once per new bar.
   if(QM_IsNewBar())
     {
      QM_EquityStreamOnNewBar();
      AdvanceState_OnNewBar();
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
