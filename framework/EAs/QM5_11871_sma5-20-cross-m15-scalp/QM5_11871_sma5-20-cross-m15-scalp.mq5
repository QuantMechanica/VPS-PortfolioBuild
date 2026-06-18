#property strict
#property version   "5.0"
#property description "QM5_11871 sma5-20-cross-m15-scalp — SMA(5)/SMA(20) momentum cross scalp w/ SMA20 slope filter (M15, 5-pip TP/SL)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11871 sma5-20-cross-m15-scalp
// -----------------------------------------------------------------------------
// Source: Unknown author, 'My Top Three Scalping Trading Strategies', ~2020
//         (local PDF archive). source_id 182e6755-015a-50ff-a0c9-b5507c5308b4.
// Card: artifacts/cards_approved/QM5_11871_sma5-20-cross-m15-scalp.md (g0 APPROVED).
//
// Mechanics (closed-bar reads; M15):
//   Trigger EVENT (the ONLY trigger, one cross per direction):
//     LONG  cross : SMA(5) crosses ABOVE SMA(20) -> sma5[2] <= sma20[2] AND sma5[1] > sma20[1]
//     SHORT cross : SMA(5) crosses BELOW SMA(20) -> sma5[2] >= sma20[2] AND sma5[1] < sma20[1]
//   Trend filter STATE (card "Trend Filter" — confirmed directional structure,
//     implemented as SMA(20) slope over slope_lookback closed bars):
//     LONG  requires SMA20 sloping UP   : sma20[1] - sma20[1+lookback] >  slope_min_price
//     SHORT requires SMA20 sloping DOWN : sma20[1+lookback] - sma20[1] >  slope_min_price
//     (slope_min_price = slope_min_pips converted scale-correct; default 0 pips =
//      any non-flat slope in the trade direction qualifies.)
//   Stop  : fixed 5 pips from entry (scale-correct via QM_StopFixedPips).
//   Take  : fixed 5 pips from entry (1:1 RR via QM_TakeRR).
//   Position: max one per symbol/magic; a cross only fires when flat, so a
//             reversal naturally requires a fresh opposite cross after the prior
//             position has closed on its TP/SL.
//
// Two-cross trap avoided: the SMA5/20 cross is the SINGLE trigger EVENT. The
// SMA20 slope is a STATE (a level comparison over a lookback window), NOT a
// second simultaneous cross/event on the same bar — so entries are not starved.
// This is the card-mandated differentiator vs. the un-filtered sibling QM5_11782.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11871;
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
input int    strategy_sma_fast_period    = 5;     // fast SMA period (cross trigger)
input int    strategy_sma_slow_period    = 20;    // slow SMA period (cross trigger + slope filter)
input int    strategy_slope_lookback     = 3;     // bars back to measure SMA20 slope (trend filter)
input double strategy_slope_min_pips     = 0.0;   // min SMA20 slope magnitude in the trade dir, pips (0 = any non-flat)
input int    strategy_sl_pips            = 5;     // fixed stop-loss distance, pips
input double strategy_tp_rr              = 1.0;   // take-profit as RR multiple of the stop (1:1)
input double strategy_spread_pct_of_stop = 50.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fails OPEN on .DWX zero spread:
// a genuinely wide spread relative to the 5-pip stop blocks; zero/negative
// modeled spread passes through.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference (price units) for the spread cap, scale-correct.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The SMA(5)/SMA(20) cross is the SINGLE trigger event (one cross per direction);
// the SMA20 slope is a confirming STATE (trend filter), not a second event.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic. A cross only fires when flat, so this
   // also enforces "reverse only after a fresh opposite cross with no position".
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Closed-bar SMA values: shift 1 = last closed bar, shift 2 = the bar before.
   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   // Single trigger EVENT — a fresh cross on the last closed bar.
   const bool crossed_up   = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool crossed_down = (fast_prev >= slow_prev && fast_now < slow_now);
   if(!crossed_up && !crossed_down)
      return false;

   // Trend filter STATE — SMA20 slope over slope_lookback closed bars. The slope
   // is read at a shift PRECEDING/at the trigger bar (shift 1 vs shift 1+lookback),
   // never a second cross event, so it does not starve entries.
   const int lb = (strategy_slope_lookback < 1) ? 1 : strategy_slope_lookback;
   const double slow_ref = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1 + lb);
   if(slow_ref <= 0.0)
      return false;
   const double slope = slow_now - slow_ref; // >0 sloping up, <0 sloping down (price units)
   const double slope_min_price = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_slope_min_pips));

   if(crossed_up && !(slope > slope_min_price))
      return false;  // long requires SMA20 sloping up by at least the floor
   if(crossed_down && !(-slope > slope_min_price))
      return false;  // short requires SMA20 sloping down by at least the floor

   const QM_OrderType dir = crossed_up ? QM_BUY : QM_SELL;

   // Entry reference price at the relevant side.
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Fixed 5-pip stop (scale-correct) and 1:1 RR take-profit.
   const double sl = QM_StopFixedPips(_Symbol, dir, entry, strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = crossed_up ? "sma520_cross_long" : "sma520_cross_short";
   return true;
  }

// No active management — fixed 5-pip TP/SL only (no trailing per the card).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — the position closes on its fixed TP or SL. A reversal
// only happens after a fresh opposite cross fires (while flat, in a confirmed
// trend).
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
