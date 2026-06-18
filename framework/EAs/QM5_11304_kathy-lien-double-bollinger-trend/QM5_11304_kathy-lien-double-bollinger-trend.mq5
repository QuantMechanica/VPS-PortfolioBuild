#property strict
#property version   "5.0"
#property description "QM5_11304 kathy-lien-double-bollinger-trend — Double Bollinger zone-entry trend (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11304 kathy-lien-double-bollinger-trend
// -----------------------------------------------------------------------------
// Source: Kathy Lien "Battle Tested Forex Trading Strategies" (double Bollinger).
// Card: artifacts/cards_approved/QM5_11304_kathy-lien-double-bollinger-trend.md
//       (g0_status APPROVED).
//
// Two Bollinger Band pairs, same period (20), different deviations:
//   BB1 = period/dev1 (inner, ~1 sigma)   BB2 = period/dev2 (outer, ~2 sigma)
// Four zones partition price:
//   Buy Zone  : bb1_upper < close <= bb2_upper   (trend up, tradeable)
//   Sell Zone : bb2_lower <= close <  bb1_lower   (trend down, tradeable)
//   No-Trade  : bb1_lower <= close <= bb1_upper   (chop, flat)
//   Extreme   : close beyond +-2 sigma            (overextended, not chased)
//
// Mechanics (all closed-bar reads at shift 1; the prior closed bar at shift 2):
//   Zone membership is a STATE. The CLOSE that first carries price INTO the
//   Buy/Sell zone (from the No-Trade zone) is the single EVENT that triggers
//   entry — per the card's "Enter on FIRST bar closing in the zone".
//
//   LONG entry  : close[1] in Buy Zone  AND close[2] was at/below bb1_upper[2]
//                 (i.e. close[2] NOT already in/above the Buy Zone).
//                 Reject if close[1] is already in the Extreme zone (> bb2_upper)
//                 — "no entry if price immediately enters the 2 sigma band".
//   SHORT entry : symmetric on the lower bands.
//   Exit LONG   : close[1] re-enters No-Trade zone (close[1] <= bb1_upper[1]).
//   Exit SHORT  : close[1] re-enters No-Trade zone (close[1] >= bb1_lower[1]).
//   Hard SL     : ATR(14) * sl_atr_mult safety net (no TP; hold to zone exit).
//   Spread guard: skip only a genuinely wide spread (> spread_pct_of_stop of the
//                 stop distance). Fail-open on .DWX zero modeled spread.
//
// One position per symbol/magic. Only the 5 Strategy_* hooks + Strategy inputs
// are EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11304;
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
input int    strategy_bb_period          = 20;    // common period for both BB pairs
input double strategy_bb_dev_inner       = 1.0;   // BB1 deviation (inner, ~1 sigma)
input double strategy_bb_dev_outer       = 2.0;   // BB2 deviation (outer, ~2 sigma)
input int    strategy_atr_period         = 14;    // ATR period for the hard safety stop
input double strategy_sl_atr_mult        = 2.0;   // hard SL distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — zone/signal work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands: inner (BB1) and outer (BB2) at the closed bar and the
   //     bar before it. The deviation arg is MANDATORY for each reader. ---
   const double bb1_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb2_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 1);
   const double bb1_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb2_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 1);
   const double bb1_up_2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 2);
   const double bb1_lo_2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 2);
   if(bb1_up_1 <= 0.0 || bb2_up_1 <= 0.0 || bb1_lo_1 <= 0.0 || bb2_lo_1 <= 0.0 ||
      bb1_up_2 <= 0.0 || bb1_lo_2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- LONG: close[1] is in the Buy Zone (between +1 and +2 sigma) and the
   //     prior bar was NOT yet in/above the Buy Zone -> first-bar EVENT. ---
   const bool buy_zone_now  = (close1 > bb1_up_1 && close1 <= bb2_up_1);
   const bool buy_zone_prev = (close2 > bb1_up_2); // already in/above buy zone last bar
   if(buy_zone_now && !buy_zone_prev)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no TP — hold to zone-exit signal
      req.reason = "dbb_buy_zone_entry";
      return true;
     }

   // --- SHORT: close[1] is in the Sell Zone (between -1 and -2 sigma) and the
   //     prior bar was NOT yet in/below the Sell Zone -> first-bar EVENT. ---
   const bool sell_zone_now  = (close1 < bb1_lo_1 && close1 >= bb2_lo_1);
   const bool sell_zone_prev = (close2 < bb1_lo_2); // already in/below sell zone last bar
   if(sell_zone_now && !sell_zone_prev)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no TP — hold to zone-exit signal
      req.reason = "dbb_sell_zone_entry";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR safety stop. The zone-exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Zone-exit: price re-enters the No-Trade zone (crosses back through the 1 sigma
// band). Direction-aware — only closes the side that has actually exited.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double bb1_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb1_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   if(bb1_up_1 <= 0.0 || bb1_lo_1 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine the open side. One position per magic, so the first match wins.
   bool is_long = false;
   bool have    = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have    = true;
      break;
     }
   if(!have)
      return false;

   // Exit LONG when price drops back to/below the inner upper band (No-Trade).
   if(is_long && close1 <= bb1_up_1)
      return true;
   // Exit SHORT when price rises back to/above the inner lower band (No-Trade).
   if(!is_long && close1 >= bb1_lo_1)
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
