#property strict
#property version   "5.0"
#property description "QM5_11719 tc-m5-s4-bb-midband-trend — BB(20,2) both-band slope + midband touch-resume (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11719 tc-m5-s4-bb-midband-trend
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         Strategy #4, self-published 2014 (367145560).
// Card: artifacts/cards_approved/QM5_11719_tc-m5-s4-bb-midband-trend.md
//       (g0_status APPROVED). Source ID 40a4454c-64ff-5015-8538-9f7b32abc0e9.
//
// Mechanics (closed-bar reads at shift 1; the card's bar[0] = last closed bar
// = shift 1, the card's bar[5] = shift 1+slope_lookback. BB(period,deviation),
// M5):
//   Trend STATE  : both Bollinger bands slope in the trade direction over
//                  slope_lookback bars.
//                  LONG : upper[1] > upper[1+lookback] AND lower[1] > lower[1+lookback].
//                  SHORT: upper[1] < upper[1+lookback] AND lower[1] < lower[1+lookback].
//                  The slope is the regime; it is NOT the trigger.
//   Pullback+resume EVENT (the single trigger, one event per bar):
//     LONG : the closed bar[1] touched the midband from above
//            (low[1] <= mid[1]) AND closed back above it (close[1] > mid[1])
//            AND the bar was bullish (close[1] > open[1]).
//     SHORT: bar[1] touched the midband from below (high[1] >= mid[1]) AND
//            closed back below it (close[1] < mid[1]) AND bar was bearish.
//   The touch-and-resume off the midline is the ONE trigger EVENT. The two band
//   slopes and the band geometry are STATES — we never demand two fresh cross
//   EVENTS on the same bar (the .DWX two-cross-same-bar zero-trade trap).
//   Stop  : opposite band (lower for LONG / upper for SHORT) at entry, capped to
//           sl_max_pips so the modeled loss never exceeds it (TIGHTER of the two).
//   Target: same-direction band (upper for LONG / lower for SHORT), captured at
//           entry. Optional fixed-pip TP via use_fixed_tp / tp_fixed_pips.
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread). Optional no-Friday-entry filter.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11719;
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
input int    strategy_bb_period         = 20;     // Bollinger period (sweep 14/20/25)
input double strategy_bb_deviation      = 2.0;    // Bollinger deviation
input int    strategy_slope_lookback    = 5;      // bars back for band slope (card: [0] vs [5])
input double strategy_slope_min_pips    = 0.5;    // min band slope magnitude, in pips
input bool   strategy_require_candle    = true;   // require bullish/bearish trigger candle close
input double strategy_sl_max_pips       = 15.0;   // max stop distance cap, in pips (card default)
input bool   strategy_use_fixed_tp      = false;  // true = fixed-pip TP instead of opposite band
input double strategy_tp_fixed_pips     = 15.0;   // fixed-pip TP distance (card default 15)
input bool   strategy_no_friday_entry   = true;   // skip new entries on Friday
input double strategy_spread_max_pips    = 5.0;   // skip only genuinely wide spreads

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No-Friday-entry + spread guard only; the band /
// slope / pullback work lives in Strategy_EntrySignal on the closed-bar path.
// Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   // No-Friday-entry filter. Friday = day-of-week 5 in broker time.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_max_pips);
   const double spread     = ask - bid;
   if(spread_cap > 0.0 && spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bands at the last closed bar (shift 1). deviation arg is MANDATORY. ---
   const double mid1   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(mid1 <= 0.0 || upper1 <= 0.0 || lower1 <= 0.0)
      return false;

   // Band slope STATE: compare the band at shift 1 to shift 1+lookback.
   const int slope_shift = 1 + strategy_slope_lookback;
   const double upper_ref = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, slope_shift);
   const double lower_ref = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, slope_shift);
   if(upper_ref <= 0.0 || lower_ref <= 0.0)
      return false;

   const double slope_min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_slope_min_pips);

   // Closed bar[1] OHLC for the touch-and-resume event (perf-allowed: single
   // closed-bar reads, no loops).
   const double open1  = iOpen(_Symbol, _Period, 1);   // perf-allowed
   const double low1   = iLow(_Symbol, _Period, 1);    // perf-allowed
   const double high1  = iHigh(_Symbol, _Period, 1);   // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed
   if(open1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0 || close1 <= 0.0)
      return false;

   const double sl_cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_max_pips);
   if(sl_cap_dist <= 0.0)
      return false;

   // --- LONG: both bands rising + bar touched mid from above, closed back above ---
   const bool slope_up = ((upper1 - upper_ref) >= slope_min_dist) &&
                         ((lower1 - lower_ref) >= slope_min_dist);
   bool long_event = (low1 <= mid1 && close1 > mid1);
   if(strategy_require_candle)
      long_event = long_event && (close1 > open1);
   if(slope_up && long_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // Stop: lower band, but never wider than the pip cap (tighter of the two).
      double sl = lower1;
      const double cap_sl = entry - sl_cap_dist;
      if(sl < cap_sl)
         sl = cap_sl;          // lower band too far → tighten to the cap
      if(sl >= entry)
         return false;         // degenerate geometry, skip

      // Target: opposite (upper) band at entry, or a fixed-pip TP.
      double tp = upper1;
      if(strategy_use_fixed_tp)
         tp = entry + QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_fixed_pips);
      if(tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;        // framework fills market price at send
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "bb_mid_trend_long";
      return true;
     }

   // --- SHORT: both bands falling + bar touched mid from below, closed back below ---
   const bool slope_down = ((upper_ref - upper1) >= slope_min_dist) &&
                           ((lower_ref - lower1) >= slope_min_dist);
   bool short_event = (high1 >= mid1 && close1 < mid1);
   if(strategy_require_candle)
      short_event = short_event && (close1 < open1);
   if(slope_down && short_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      // Stop: upper band, but never wider than the pip cap (tighter of the two).
      double sl = upper1;
      const double cap_sl = entry + sl_cap_dist;
      if(sl > cap_sl)
         sl = cap_sl;          // upper band too far → tighten to the cap
      if(sl <= entry)
         return false;

      // Target: opposite (lower) band at entry, or a fixed-pip TP.
      double tp = lower1;
      if(strategy_use_fixed_tp)
         tp = entry - QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_fixed_pips);
      if(tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "bb_mid_trend_short";
      return true;
     }

   return false;
  }

// Fixed band-derived SL/TP set at entry; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the band SL/TP.
bool Strategy_ExitSignal()
  {
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
