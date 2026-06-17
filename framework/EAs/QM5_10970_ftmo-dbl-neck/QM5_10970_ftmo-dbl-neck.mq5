#property strict
#property version   "5.0"
#property description "QM5_10970 ftmo-dbl-neck — Double Top/Bottom Neckline Reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10970 ftmo-dbl-neck
// -----------------------------------------------------------------------------
// Source: FTMO Australia, "How to trade chart patterns?", 2025.
// Card: artifacts/cards_approved/QM5_10970_ftmo-dbl-neck.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H4):
//   SHORT (double top):
//     - Uptrend STATE : close[1] > EMA(100) AND 20-bar slope positive.
//     - Two swing highs separated by [5,30] H4 bars.
//     - Second peak within 0.5*ATR(14) of the first peak.
//     - Valley between peaks >= 1.0*ATR(14) below the lower peak.
//     - Neckline = valley low.
//     - Trigger: an H4 candle CLOSES below the neckline.
//     - SL = max(two peaks) + 0.25*ATR.
//   LONG (double bottom): mirror image.
//   Pattern-height filter: skip if height < 1.0*ATR or > 6.0*ATR.
//   Late-entry filter: skip if the breakout candle range > 2.5*ATR.
//   TP : pattern height projected from neckline, capped at 3.0R; fallback 2.0R.
//   Move SL to breakeven after +1.0R touch.
//   Time exit after 40 H4 bars.
//   One open position per symbol/magic.
//
// Swing detection uses raw iHigh/iLow at fixed closed-bar shifts (bespoke
// structural logic — no QM indicator covers fractal pivots). All such reads
// are // perf-allowed and run only on the QM_IsNewBar closed-bar path; the
// detection loop is bounded by strategy_lookback_bars (<=60).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10970;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period         = 100;   // trend-filter EMA period
input int    strategy_slope_bars         = 20;    // bars for the trend-slope check
input int    strategy_atr_period         = 14;    // ATR period (proximity/valley/stop/filters)
input int    strategy_lookback_bars      = 60;    // closed bars scanned for swing structure
input int    strategy_swing_strength     = 2;     // bars each side defining a swing pivot
input int    strategy_min_sep_bars       = 5;     // min bars between the two swings
input int    strategy_max_sep_bars       = 30;    // max bars between the two swings
input double strategy_peak_tol_atr       = 0.5;   // 2nd swing within this*ATR of the 1st
input double strategy_valley_min_atr      = 1.0;  // valley/peak depth >= this*ATR
input double strategy_height_min_atr      = 1.0;  // skip if pattern height < this*ATR
input double strategy_height_max_atr      = 6.0;  // skip if pattern height > this*ATR
input double strategy_sl_buffer_atr       = 0.25; // SL buffer beyond extreme = this*ATR
input double strategy_breakout_max_atr     = 2.5; // skip if breakout candle range > this*ATR
input double strategy_tp_rr_cap            = 3.0; // pattern-height TP capped at this R
input double strategy_tp_rr_fallback       = 2.0; // fallback TP R if height projection invalid
input int    strategy_time_exit_bars       = 40;  // time exit after this many H4 bars

// -----------------------------------------------------------------------------
// File-scope state: track entry bar-time for the 40-bar time exit and the +1R
// breakeven trigger. Advanced only on the closed-bar entry path / per tick read.
// -----------------------------------------------------------------------------
datetime g_entry_bar_time   = 0;     // bar-open time of the bar we entered on
double   g_entry_risk_dist  = 0.0;   // |entry - SL| at entry, for the 1R BE trigger
bool     g_be_done          = false; // breakeven already applied for current position

// -----------------------------------------------------------------------------
// Helpers (bespoke structural detection — closed-bar shifts only).
// -----------------------------------------------------------------------------

// Is shift `s` a swing HIGH: high[s] strictly >= the `strength` bars on each side
// (and strictly greater than at least the immediate neighbours).
bool IsSwingHigh(const int s, const int strength)
  {
   const double h = iHigh(_Symbol, _Period, s); // perf-allowed: structural pivot read
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= strength; ++k)
     {
      const double hl = iHigh(_Symbol, _Period, s + k); // perf-allowed
      const double hr = iHigh(_Symbol, _Period, s - k); // perf-allowed
      if(hl <= 0.0 || hr <= 0.0)
         return false;
      if(h < hl || h < hr)
         return false;
     }
   return true;
  }

// Is shift `s` a swing LOW: low[s] strictly <= the `strength` bars on each side.
bool IsSwingLow(const int s, const int strength)
  {
   const double l = iLow(_Symbol, _Period, s); // perf-allowed: structural pivot read
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= strength; ++k)
     {
      const double ll = iLow(_Symbol, _Period, s + k); // perf-allowed
      const double lr = iLow(_Symbol, _Period, s - k); // perf-allowed
      if(ll <= 0.0 || lr <= 0.0)
         return false;
      if(l > ll || l > lr)
         return false;
     }
   return true;
  }

// 20-bar slope of close: close[1] - close[1+slope_bars]. Positive => uptrend.
double CloseSlope(const int slope_bars)
  {
   const double c_now = iClose(_Symbol, _Period, 1);           // perf-allowed
   const double c_old = iClose(_Symbol, _Period, 1 + slope_bars); // perf-allowed
   if(c_now <= 0.0 || c_old <= 0.0)
      return 0.0;
   return (c_now - c_old);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No cheap per-tick regime gate needed; spread is fail-open on .DWX. Block
// nothing here — all structural work is on the closed-bar entry path.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Detect a double-top (short) or double-bottom (long) neckline break on the
// just-closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: breakout close
   if(close1 <= 0.0)
      return false;

   const int strength = strategy_swing_strength;
   const int scan_first = 1 + strength;                  // earliest valid pivot shift
   const int scan_last  = strategy_lookback_bars;        // bounded scan window
   const double slope = CloseSlope(strategy_slope_bars);

   // Breakout candle range filter (late-entry guard).
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0)
      return false;
   const double breakout_range = high1 - low1;
   if(breakout_range > strategy_breakout_max_atr * atr)
      return false;

   // ------------------------------------------------------------------
   // DOUBLE TOP (short). Require an uptrend STATE, then find the most
   // recent valid pair of swing highs with a qualifying valley, whose
   // neckline (valley low) the just-closed bar broke DOWN through.
   // ------------------------------------------------------------------
   if(close1 > ema && slope > 0.0)
     {
      // p2 = nearer (second) swing high; p1 = earlier (first) swing high.
      for(int p2 = scan_first; p2 <= scan_last - strategy_min_sep_bars; ++p2)
        {
         if(!IsSwingHigh(p2, strength))
            continue;
         const double peak2 = iHigh(_Symbol, _Period, p2); // perf-allowed

         const int p1_lo = p2 + strategy_min_sep_bars;
         const int p1_hi = p2 + strategy_max_sep_bars;
         for(int p1 = p1_lo; p1 <= p1_hi && p1 <= scan_last; ++p1)
           {
            if(!IsSwingHigh(p1, strength))
               continue;
            const double peak1 = iHigh(_Symbol, _Period, p1); // perf-allowed

            // Second peak within tolerance of the first (twin peaks).
            if(MathAbs(peak2 - peak1) > strategy_peak_tol_atr * atr)
               continue;

            // Valley = lowest low strictly between p1 and p2.
            double valley = DBL_MAX;
            for(int s = p2 + 1; s < p1; ++s)
              {
               const double lo = iLow(_Symbol, _Period, s); // perf-allowed
               if(lo > 0.0 && lo < valley)
                  valley = lo;
              }
            if(valley == DBL_MAX)
               continue;

            const double lower_peak = MathMin(peak1, peak2);
            // Valley must be >= valley_min_atr below the lower peak.
            if((lower_peak - valley) < strategy_valley_min_atr * atr)
               continue;

            const double neckline = valley;
            const double height   = lower_peak - neckline;
            // Pattern-height band filter.
            if(height < strategy_height_min_atr * atr || height > strategy_height_max_atr * atr)
               continue;

            // Trigger: the just-closed bar closed BELOW the neckline; the prior
            // bar had not yet (fresh break).
            const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
            if(!(close1 < neckline && close2 >= neckline))
               continue;

            // Build the short. SL above the higher peak + buffer.
            const double higher_peak = MathMax(peak1, peak2);
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entry <= 0.0)
               continue;
            const double sl = QM_StopRulesNormalizePrice(_Symbol,
                                 higher_peak + strategy_sl_buffer_atr * atr);
            if(sl <= entry)
               continue;
            const double risk = sl - entry;
            if(risk <= 0.0)
               continue;

            // TP = height projected from neckline, capped at tp_rr_cap R;
            // fallback to tp_rr_fallback R if the projection is degenerate.
            double tp_dist = height;
            const double cap_dist = strategy_tp_rr_cap * risk;
            if(tp_dist > cap_dist)
               tp_dist = cap_dist;
            if(tp_dist <= 0.0)
               tp_dist = strategy_tp_rr_fallback * risk;
            const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - tp_dist);
            if(tp >= entry)
               continue;

            req.type   = QM_SELL;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "dbl_top_neck_short";
            g_entry_bar_time  = iTime(_Symbol, _Period, 1); // perf-allowed: entry bar stamp
            g_entry_risk_dist = risk;
            g_be_done = false;
            return true;
           }
        }
     }

   // ------------------------------------------------------------------
   // DOUBLE BOTTOM (long). Mirror of the above.
   // ------------------------------------------------------------------
   if(close1 < ema && slope < 0.0)
     {
      for(int t2 = scan_first; t2 <= scan_last - strategy_min_sep_bars; ++t2)
        {
         if(!IsSwingLow(t2, strength))
            continue;
         const double trough2 = iLow(_Symbol, _Period, t2); // perf-allowed

         const int t1_lo = t2 + strategy_min_sep_bars;
         const int t1_hi = t2 + strategy_max_sep_bars;
         for(int t1 = t1_lo; t1 <= t1_hi && t1 <= scan_last; ++t1)
           {
            if(!IsSwingLow(t1, strength))
               continue;
            const double trough1 = iLow(_Symbol, _Period, t1); // perf-allowed

            if(MathAbs(trough2 - trough1) > strategy_peak_tol_atr * atr)
               continue;

            // Peak = highest high strictly between t1 and t2.
            double peak = -DBL_MAX;
            for(int s = t2 + 1; s < t1; ++s)
              {
               const double hi = iHigh(_Symbol, _Period, s); // perf-allowed
               if(hi > 0.0 && hi > peak)
                  peak = hi;
              }
            if(peak == -DBL_MAX)
               continue;

            const double higher_trough = MathMax(trough1, trough2);
            if((peak - higher_trough) < strategy_valley_min_atr * atr)
               continue;

            const double neckline = peak;
            const double height   = neckline - higher_trough;
            if(height < strategy_height_min_atr * atr || height > strategy_height_max_atr * atr)
               continue;

            const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
            if(!(close1 > neckline && close2 <= neckline))
               continue;

            const double lower_trough = MathMin(trough1, trough2);
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entry <= 0.0)
               continue;
            const double sl = QM_StopRulesNormalizePrice(_Symbol,
                                 lower_trough - strategy_sl_buffer_atr * atr);
            if(sl >= entry)
               continue;
            const double risk = entry - sl;
            if(risk <= 0.0)
               continue;

            double tp_dist = height;
            const double cap_dist = strategy_tp_rr_cap * risk;
            if(tp_dist > cap_dist)
               tp_dist = cap_dist;
            if(tp_dist <= 0.0)
               tp_dist = strategy_tp_rr_fallback * risk;
            const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist);
            if(tp <= entry)
               continue;

            req.type   = QM_BUY;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "dbl_bottom_neck_long";
            g_entry_bar_time  = iTime(_Symbol, _Period, 1); // perf-allowed: entry bar stamp
            g_entry_risk_dist = risk;
            g_be_done = false;
            return true;
           }
        }
     }

   return false;
  }

// Move SL to breakeven once price has travelled +1.0R from entry.
void Strategy_ManageOpenPosition()
  {
   if(g_be_done)
      return;
   if(g_entry_risk_dist <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(open_price <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && (bid - open_price) >= g_entry_risk_dist)
           {
            const double be = QM_StopRulesNormalizePrice(_Symbol, open_price);
            if(QM_TM_MoveSL(ticket, be, "breakeven_1R"))
               g_be_done = true;
           }
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && (open_price - ask) >= g_entry_risk_dist)
           {
            const double be = QM_StopRulesNormalizePrice(_Symbol, open_price);
            if(QM_TM_MoveSL(ticket, be, "breakeven_1R"))
               g_be_done = true;
           }
        }
     }
  }

// Time exit: close after strategy_time_exit_bars closed H4 bars since entry.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(g_entry_bar_time == 0)
      return false;

   const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time
   if(cur_bar <= 0)
      return false;

   const int period_secs = PeriodSeconds(_Period);
   if(period_secs <= 0)
      return false;

   const int bars_held = (int)((cur_bar - g_entry_bar_time) / period_secs);
   if(bars_held >= strategy_time_exit_bars)
      return true;

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
