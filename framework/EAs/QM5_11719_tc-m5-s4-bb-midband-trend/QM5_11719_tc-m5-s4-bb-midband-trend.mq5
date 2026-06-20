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
//   Stop  : factory default fixed 15 pips. Optional card variant uses the
//           opposite band (lower for LONG / upper for SHORT) captured at entry.
//   Target: factory default fixed 15 pips. Optional card variant uses the
//           same-direction outer band (upper for LONG / lower for SHORT).
//   Filters: none specified by the card. Framework news, kill-switch, and
//            Friday close guards remain active.
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
input bool   strategy_require_candle    = true;   // require bullish/bearish trigger candle close
input bool   strategy_use_band_sl       = false;  // false = factory fixed 15-pip SL
input int    strategy_sl_fixed_pips     = 15;     // fixed SL distance in pips (card factory default)
input bool   strategy_use_band_tp       = false;  // false = factory fixed 15-pip TP
input int    strategy_tp_fixed_pips     = 15;     // fixed-pip TP distance (card default 15)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No strategy-specific no-trade filter is specified by the card. Framework
// kill-switch, news, and Friday-close gates remain active.
bool Strategy_NoTradeFilter()
  {
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

   // Closed bar[1] OHLC for the touch-and-resume event. Strategy_EntrySignal
   // is called only after the framework QM_IsNewBar() gate, so this is one
   // single-bar read per closed bar, not a per-tick history scan.
   MqlRates bar[1];
   if(CopyRates(_Symbol, _Period, 1, 1, bar) != 1) // perf-allowed
      return false;
   const double open1  = bar[0].open;
   const double low1   = bar[0].low;
   const double high1  = bar[0].high;
   const double close1 = bar[0].close;
   if(open1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0 || close1 <= 0.0)
      return false;

   const double sl_fixed_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_fixed_pips);
   const double tp_fixed_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_fixed_pips);
   if(sl_fixed_dist <= 0.0 || tp_fixed_dist <= 0.0)
      return false;

   // --- LONG: both bands rising + bar touched mid from above, closed back above ---
   const bool slope_up = (upper1 > upper_ref) && (lower1 > lower_ref);
   bool long_event = (low1 <= mid1 && close1 > mid1);
   if(strategy_require_candle)
      long_event = long_event && (close1 > open1);
   if(slope_up && long_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double sl = entry - sl_fixed_dist;
      if(strategy_use_band_sl)
         sl = lower1;
      if(sl >= entry)
         return false;         // degenerate geometry, skip

      double tp = entry + tp_fixed_dist;
      if(strategy_use_band_tp)
         tp = upper1;
      if(tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;        // framework fills market price at send
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "bb_mid_trend_long";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // --- SHORT: both bands falling + bar touched mid from below, closed back below ---
   const bool slope_down = (upper1 < upper_ref) && (lower1 < lower_ref);
   bool short_event = (high1 >= mid1 && close1 < mid1);
   if(strategy_require_candle)
      short_event = short_event && (close1 < open1);
   if(slope_down && short_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = entry + sl_fixed_dist;
      if(strategy_use_band_sl)
         sl = upper1;
      if(sl <= entry)
         return false;

      double tp = entry - tp_fixed_dist;
      if(strategy_use_band_tp)
         tp = lower1;
      if(tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "bb_mid_trend_short";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
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
