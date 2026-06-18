#property strict
#property version   "5.0"
#property description "QM5_11530 carter-t-h1-sma9-100-cross — SMA(9/100) trend cross (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11530 carter-t-h1-sma9-100-cross
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         System #2, self-published 2014.
// Card: artifacts/cards_approved/QM5_11530_carter-t-h1-sma9-100-cross.md
//       (g0_status APPROVED).
//
// Mechanics (trend-following MA cross, closed-bar reads at shift 1):
//   Trigger EVENT (entry): SMA(fast=9) crosses SMA(slow=100) on H1.
//     LONG  : sma9@2 <= sma100@2  AND  sma9@1 > sma100@1  (fresh upward cross).
//     SHORT : sma9@2 >= sma100@2  AND  sma9@1 < sma100@1  (fresh downward cross).
//   The cross is the ONE trigger event. No second cross/oscillator event is
//   required on the same bar (avoids the two-cross zero-trade trap).
//   Stop loss   : 50 pips fixed (card-specified; P2 cap 50p).
//   Take profit : 100 pips fixed.
//   Reverse-cross exit: a fresh OPPOSITE cross closes the open position; the
//                       same new closed bar then opens the reverse trade.
//   Filters (STATE): spread cap (fail-open on .DWX zero modeled spread);
//                    no new entry on Friday (source rule).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11530;
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
input int    strategy_sma_fast_period   = 9;      // fast SMA (cross trigger)
input int    strategy_sma_slow_period   = 100;    // slow SMA (cross trigger)
input int    strategy_sl_pips           = 50;     // stop-loss distance in pips
input int    strategy_tp_pips           = 100;    // take-profit distance in pips
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance
input bool   strategy_no_friday_entry   = true;   // suppress new entries on Friday

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard + Friday no-entry STATE. Regime/signal
// work is in Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX
// zero modeled spread (ask == bid in the tester).
bool Strategy_NoTradeFilter()
  {
   // No new entries on Friday (source rule). MqlDateTime day_of_week: Fri = 5.
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

   // Stop distance (price) for the spread cap, scaled correctly via pip factor.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Returns +1 on a fresh upward SMA9/SMA100 cross, -1 on a fresh downward cross,
// 0 otherwise. Closed-bar reads: shift 1 = last closed bar, shift 2 = prior.
int SmaCrossEvent()
  {
   const double fast1 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double slow1 = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double fast2 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double slow2 = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(fast1 <= 0.0 || slow1 <= 0.0 || fast2 <= 0.0 || slow2 <= 0.0)
      return 0;

   if(fast2 <= slow2 && fast1 > slow1)
      return +1; // bullish cross
   if(fast2 >= slow2 && fast1 < slow1)
      return -1; // bearish cross
   return 0;
  }

// Trend-cross entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int cross = SmaCrossEvent();
   if(cross == 0)
      return false;

   if(cross > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "sma9_100_cross_long";
      return true;
     }
   else
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "sma9_100_cross_short";
      return true;
     }
  }

// No active management beyond the fixed SL/TP. Reverse-cross exit is handled in
// Strategy_ExitSignal (closed-bar event), keeping this O(1) per-tick.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive / reverse-cross exit: a fresh cross OPPOSITE to the open position's
// direction closes it. Evaluated on the closed-bar path (called every tick, but
// SmaCrossEvent only fires on a fresh cross at shift 1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int cross = SmaCrossEvent();
   if(cross == 0)
      return false;

   // Determine the open position's direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      // Long open + bearish cross => exit; Short open + bullish cross => exit.
      if(pos_type == POSITION_TYPE_BUY && cross < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && cross > 0)
         return true;
     }
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
