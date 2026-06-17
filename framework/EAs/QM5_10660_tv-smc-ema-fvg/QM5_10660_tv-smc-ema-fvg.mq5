#property strict
#property version   "5.0"
#property description "QM5_10660 TradingView SMC Trend Filter (D1 EMA50/200 + BOS + OB + FVG)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10660 — TradingView "SMC Trend Filter Strategy (EMA50/EMA200 + FVG)"
// author handle SMCFVL, https://www.tradingview.com/script/pMKsPFWQ/
// -----------------------------------------------------------------------------
// Mechanics (closed-bar, framework-native, .DWX-safe). Per the .DWX invariants
// these are STATES + ONE trigger (detect-then-arm), not "all on the same bar":
//
//   1. TREND FILTER (state) — Daily EMA50 vs EMA200.
//        long bias allowed  only when D1 EMA50 > D1 EMA200
//        short bias allowed only when D1 EMA50 < D1 EMA200
//   2. CONFIRMED SWINGS (state) — on the execution TF a swing high/low is a
//        fractal pivot: a bar whose high is the strict max (low the strict min)
//        of `swing_lookback` bars on each side. Confirmation lags by
//        `swing_lookback` closed bars (no repaint). We keep the most recent
//        confirmed swing-high and swing-low price levels.
//   3. BOS (the TRIGGER) — bullish BOS = last closed bar CLOSES above the most
//        recent confirmed swing high; bearish BOS = closes below the most recent
//        confirmed swing low. The BOS bar is the event that arms a directional
//        setup; trend + swings are pre-existing states.
//   4. ORDER BLOCK (state captured at BOS) — the candle just before the BOS bar
//        marks the OB zone (its high/low). The initial stop sits beyond this
//        zone plus an ATR buffer.
//   5. FVG CONFIRMATION (state) — a 3-bar fair-value gap in the bias direction
//        present within `fvg_confirm_window` recent bars:
//          bullish FVG : low[a] > high[c]   (gap up, unfilled)
//          bearish FVG : high[a] < low[c]   (gap down, unfilled)
//        Gap must clear an ATR-relative size threshold (noise filter).
//   6. ENTRY — fires market on the next confirmed bar once BOS (trigger) has
//        armed a setup AND a qualifying FVG is present AND trend agrees. One
//        position per magic (single-entry framework path; framework sizes lots).
//   7. STOP — beyond the OB zone +/- ATR buffer, capped at sl_atr_cap_mult*ATR;
//        TP = RR multiple of realised stop distance (baseline full-close TP1).
//   8. MANAGEMENT — ATR trailing stop (atr_trail_period / atr_trail_mult).
//   9. EXIT — opposite BOS OR Daily-EMA trend flip closes any open position;
//        optional time-stop after `time_stop_bars` execution-TF bars.
//
// All strategy state is advanced ONCE per closed bar (AdvanceState_OnNewBar);
// OnTick stays O(1) per the framework intraday discipline.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10660;
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
// --- Daily EMA trend filter ---
input int    ema_fast_period            = 50;     // D1 EMA50
input int    ema_slow_period            = 200;    // D1 EMA200
// --- Confirmed swing (fractal) detection on the execution TF ---
input int    swing_lookback             = 3;      // bars each side of a pivot
// --- Fair Value Gap confirmation (3-bar imbalance, execution TF) ---
input int    atr_period                 = 14;     // ATR for FVG threshold + SL
input double fvg_min_atr_mult           = 0.25;   // gap must be >= this * ATR
input int    fvg_confirm_window         = 6;      // FVG must be within N bars of BOS
// --- Setup arming control ---
input int    bos_setup_max_bars         = 6;      // armed BOS expires after N bars
// --- Session filter (broker time, DST-aware). 0..24; wrap-safe. ---
input bool   use_session_filter         = true;
input int    session_start_hour_broker  = 9;      // EU/London + US overlap window
input int    session_end_hour_broker    = 22;
// --- Stop / target ---
input double sl_atr_buffer_mult         = 0.50;   // OB-zone padding (card: 0.5x ATR)
input double sl_atr_cap_mult            = 3.0;    // max stop distance = this * ATR
input double tp_rr                       = 2.0;    // TP1 RR multiple (full close)
// --- Trade management / exits ---
input int    atr_trail_period           = 14;     // ATR trailing-stop period
input double atr_trail_mult             = 2.0;    // card: 2.0x ATR trailing
input int    time_stop_bars             = 36;     // ~3 sessions on the exec TF; 0=off

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced once per closed bar).
// -----------------------------------------------------------------------------

double   g_last_atr            = 0.0;

// Daily trend: +1 EMA50>EMA200, -1 EMA50<EMA200, 0 unknown/equal.
int      g_trend_dir           = 0;

// Most recent CONFIRMED swing levels (fractal pivots, lag = swing_lookback).
double   g_swing_high          = 0.0;
double   g_swing_low           = 0.0;
bool     g_have_swing_high     = false;
bool     g_have_swing_low      = false;

// FVG presence (refreshed each bar): is a qualifying gap in each direction
// present within fvg_confirm_window recent bars?
bool     g_fvg_bull_recent     = false;
bool     g_fvg_bear_recent     = false;

// Armed BOS setup: dir +1 long / -1 short / 0 none, with captured OB zone.
int      g_setup_dir           = 0;
int      g_setup_age           = 0;
double   g_ob_high             = 0.0;   // order-block zone high (candle before BOS)
double   g_ob_low              = 0.0;   // order-block zone low

// Last BOS direction (for opposite-BOS exit). +1/-1/0.
int      g_last_bos_dir        = 0;

// Bars the current open position has been held (for time stop).
int      g_position_age_bars   = 0;

// Pending entry computed at AdvanceState (closed bar) and consumed by OnTick.
bool         g_entry_ready     = false;
QM_OrderType g_entry_type      = QM_BUY;
double       g_entry_price     = 0.0;
double       g_entry_sl        = 0.0;
double       g_entry_tp        = 0.0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

void ResetSetup()
  {
   g_setup_dir = 0;
   g_setup_age = 0;
   g_ob_high   = 0.0;
   g_ob_low    = 0.0;
  }

// Refresh the Daily EMA trend filter (closed Daily bar = shift 1).
void RefreshTrend()
  {
   double ema_fast = QM_EMA(_Symbol, PERIOD_D1, ema_fast_period, 1);
   double ema_slow = QM_EMA(_Symbol, PERIOD_D1, ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
     {
      g_trend_dir = 0;
      return;
     }
   if(ema_fast > ema_slow)
      g_trend_dir = +1;
   else if(ema_fast < ema_slow)
      g_trend_dir = -1;
   else
      g_trend_dir = 0;
  }

// Update the most recent CONFIRMED fractal swing high/low. A pivot at shift
// `p = swing_lookback + 1` is confirmed when its high is the strict max (low the
// strict min) of the `swing_lookback` bars on EACH side. All bars are closed.
// perf-allowed: bounded loop (2*swing_lookback), runs only inside new-bar gate.
void RefreshSwings()
  {
   int n = swing_lookback;
   if(n < 1)
      n = 1;
   int p = n + 1; // the candidate pivot shift (center of the 2n+1 window)

   double pivot_high = iHigh(_Symbol, _Period, p); // perf-allowed: closed-bar gated
   double pivot_low  = iLow(_Symbol,  _Period, p);
   if(pivot_high <= 0.0 || pivot_low <= 0.0)
      return;

   bool is_swing_high = true;
   bool is_swing_low  = true;
   for(int k = 1; k <= n; ++k)
     {
      double h_left  = iHigh(_Symbol, _Period, p + k);
      double h_right = iHigh(_Symbol, _Period, p - k);
      double l_left  = iLow(_Symbol,  _Period, p + k);
      double l_right = iLow(_Symbol,  _Period, p - k);
      if(h_left <= 0.0 || h_right <= 0.0 || l_left <= 0.0 || l_right <= 0.0)
        {
         is_swing_high = false;
         is_swing_low  = false;
         break;
        }
      if(!(pivot_high > h_left && pivot_high > h_right))
         is_swing_high = false;
      if(!(pivot_low < l_left && pivot_low < l_right))
         is_swing_low = false;
     }

   if(is_swing_high)
     {
      g_swing_high      = pivot_high;
      g_have_swing_high = true;
     }
   if(is_swing_low)
     {
      g_swing_low      = pivot_low;
      g_have_swing_low = true;
     }
  }

// Refresh whether a qualifying 3-bar FVG (gap >= fvg_min_atr_mult*ATR) exists in
// each direction within the last `fvg_confirm_window` closed bars.
// 3-bar window at offset s: a = s+2, b = s+1 (displacement), c = s.
//   bullish FVG : low[a] > high[c]
//   bearish FVG : high[a] < low[c]
// perf-allowed: bounded loop (fvg_confirm_window), runs only inside new-bar gate.
void RefreshFVGPresence()
  {
   g_fvg_bull_recent = false;
   g_fvg_bear_recent = false;

   double min_gap = (g_last_atr > 0.0) ? (g_last_atr * fvg_min_atr_mult) : 0.0;
   int w = fvg_confirm_window;
   if(w < 1)
      w = 1;

   for(int s = 1; s <= w; ++s)
     {
      double high_a = iHigh(_Symbol, _Period, s + 2); // perf-allowed: closed-bar gated
      double low_a  = iLow(_Symbol,  _Period, s + 2);
      double high_c = iHigh(_Symbol, _Period, s);
      double low_c  = iLow(_Symbol,  _Period, s);
      if(high_a <= 0.0 || low_a <= 0.0 || high_c <= 0.0 || low_c <= 0.0)
         continue;

      if(low_a > high_c)
        {
         double gap = low_a - high_c;
         if(gap > 0.0 && gap >= min_gap)
            g_fvg_bull_recent = true;
        }
      else if(high_a < low_c)
        {
         double gap = low_c - high_a;
         if(gap > 0.0 && gap >= min_gap)
            g_fvg_bear_recent = true;
        }
     }
  }

// Detect a BOS on the last closed bar (shift 1) against the most recent
// confirmed swing. A BOS captures the order-block zone (candle before BOS =
// shift 2) and arms a directional setup. The BOS is the TRIGGER; trend + FVG
// are checked as states at entry evaluation.
void DetectBOS()
  {
   double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar gated
   if(close_1 <= 0.0)
      return;

   // Bullish BOS: close breaks above the most recent confirmed swing high.
   if(g_have_swing_high && close_1 > g_swing_high)
     {
      double ob_high = iHigh(_Symbol, _Period, 2); // candle before the BOS bar
      double ob_low  = iLow(_Symbol,  _Period, 2);
      if(ob_high > 0.0 && ob_low > 0.0)
        {
         g_setup_dir    = +1;
         g_setup_age    = 0;
         g_ob_high      = ob_high;
         g_ob_low       = ob_low;
         g_last_bos_dir = +1;
        }
      // Consume the swing so the same level is not re-broken every bar.
      g_have_swing_high = false;
      return;
     }

   // Bearish BOS: close breaks below the most recent confirmed swing low.
   if(g_have_swing_low && close_1 < g_swing_low)
     {
      double ob_high = iHigh(_Symbol, _Period, 2);
      double ob_low  = iLow(_Symbol,  _Period, 2);
      if(ob_high > 0.0 && ob_low > 0.0)
        {
         g_setup_dir    = -1;
         g_setup_age    = 0;
         g_ob_high      = ob_high;
         g_ob_low       = ob_low;
         g_last_bos_dir = -1;
        }
      g_have_swing_low = false;
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

// Build SL/TP for a side using the captured OB zone + ATR buffer/cap.
// LONG  stop = OB low  - buffer; SHORT stop = OB high + buffer.
bool BuildStops(const QM_OrderType side, const double entry, double &out_sl, double &out_tp)
  {
   out_sl = 0.0;
   out_tp = 0.0;
   if(entry <= 0.0)
      return false;
   if(g_ob_high <= 0.0 || g_ob_low <= 0.0)
      return false;

   double buffer = (g_last_atr > 0.0) ? (g_last_atr * sl_atr_buffer_mult) : 0.0;

   double sl;
   if(QM_OrderTypeIsBuy(side))
      sl = g_ob_low - buffer;
   else
      sl = g_ob_high + buffer;

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
   // Stop must be on the correct side of entry.
   if(QM_OrderTypeIsBuy(side) && sl >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(side) && sl <= entry)
      return false;

   double tp = QM_TakeRR(_Symbol, side, entry, sl, tp_rr);
   if(tp <= 0.0)
      return false;

   out_sl = sl;
   out_tp = tp;
   return true;
  }

// Closed-bar entry evaluation. Sets the pending g_entry_* when an armed BOS
// setup is confirmed by trend agreement + a recent qualifying FVG.
void EvaluateEntryOnNewBar()
  {
   g_entry_ready = false;

   if(g_setup_dir == 0)
      return;

   // Expire a stale armed setup.
   g_setup_age++;
   if(g_setup_age > bos_setup_max_bars)
     {
      ResetSetup();
      return;
     }

   // Trend must agree with the setup direction (D1 EMA50/200 filter).
   if(g_trend_dir != g_setup_dir)
      return;

   // FVG confirmation in the setup direction must be present.
   if(g_setup_dir == +1 && !g_fvg_bull_recent)
      return;
   if(g_setup_dir == -1 && !g_fvg_bear_recent)
      return;

   QM_OrderType side = (g_setup_dir == +1) ? QM_BUY : QM_SELL;

   double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      entry = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar gated

   double sl, tp;
   if(!BuildStops(side, entry, sl, tp))
      return;

   g_entry_ready = true;
   g_entry_type  = side;
   g_entry_price = 0.0;   // market fill at send
   g_entry_sl    = sl;
   g_entry_tp    = tp;

   // One entry per armed setup.
   ResetSetup();
  }

// Advance ALL closed-bar state exactly once per new execution-TF bar.
void AdvanceState_OnNewBar()
  {
   g_last_atr = QM_ATR(_Symbol, _Period, atr_period, 1);

   RefreshTrend();
   RefreshSwings();
   RefreshFVGPresence();
   DetectBOS();
   EvaluateEntryOnNewBar();

   // Age the open position for the time stop (one increment per closed bar).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      g_position_age_bars++;
   else
      g_position_age_bars = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Single position per EA at a time (single-entry baseline).
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
   req.reason = "smc_ema_bos_ob_fvg";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // ATR trailing stop from the source (card: ATR(14) x2.0 trail).
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_TrailATR(ticket, atr_trail_period, atr_trail_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Determine the side of the open position for this magic.
   const int magic = QM_FrameworkMagic();
   int pos_dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      pos_dir = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(pos_dir == 0)
      return false;

   // Daily-EMA trend flip against the position closes it.
   if(g_trend_dir != 0 && g_trend_dir != pos_dir)
      return true;

   // Opposite BOS against the position closes it.
   if(g_last_bos_dir != 0 && g_last_bos_dir != pos_dir)
      return true;

   // Optional time stop after time_stop_bars execution-TF bars.
   if(time_stop_bars > 0 && g_position_age_bars >= time_stop_bars)
      return true;

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

   g_last_atr          = 0.0;
   g_trend_dir         = 0;
   g_swing_high        = 0.0;
   g_swing_low         = 0.0;
   g_have_swing_high   = false;
   g_have_swing_low    = false;
   g_fvg_bull_recent   = false;
   g_fvg_bear_recent   = false;
   ResetSetup();
   g_last_bos_dir      = 0;
   g_position_age_bars = 0;
   g_entry_ready       = false;

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
     {
      // Even when blocked from NEW entries, still honour discretionary exits.
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
      // Trailing management also runs while a position is open.
      Strategy_ManageOpenPosition();
      return;
     }

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
