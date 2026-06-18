#property strict
#property version   "5.0"
#property description "QM5_11316 tc20-h1-9-ema5-12-34-psar — EMA5/12/34 cascade + PSAR flip (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11316 tc20-h1-9-ema5-12-34-psar
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #9. Card: artifacts/cards_approved/QM5_11316_tc20-h1-9-ema5-12-34-psar.md
//         (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; step 0.1 / max 0.2 PSAR per source):
//   Cascade STATE (long) : EMA(5) > EMA(12) > EMA(34).
//   Cascade STATE (short): EMA(5) < EMA(12) < EMA(34).
//   PSAR placement STATE : long needs SAR < EMA(5); short needs SAR > EMA(5).
//   Trigger EVENT (long) : PSAR FLIPS to the bullish side this bar — SAR was
//                          ABOVE EMA(5) on the prior closed bar (shift 2) and is
//                          now BELOW EMA(5) on the trigger bar (shift 1).
//   Trigger EVENT (short): PSAR flips bearish — SAR was below EMA(5) at shift 2,
//                          now above EMA(5) at shift 1.
//
//   The triple-EMA cascade is a STATE (alignment), the PSAR flip across EMA(5)
//   is the single EVENT. This avoids the "two fresh crossovers on the same bar"
//   zero-trade trap: only ONE fresh event is required, the cascade is a
//   standing condition, not a same-bar cross.
//
//   Stop   : fixed 30 pips (source), pip-scaled per symbol.
//   Target : fixed 50 pips (source), pip-scaled per symbol.
//   Defensive exit: opposite cascade STATE + opposite SAR placement.
//   Spread guard : block only a genuinely wide spread > spread_pct_of_stop of
//                  the 30-pip stop distance (fail-open on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11316;
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
input int    strategy_ema_fast_period   = 5;     // cascade fast EMA
input int    strategy_ema_mid_period    = 12;    // cascade middle EMA
input int    strategy_ema_slow_period   = 34;    // cascade slow EMA
input double strategy_sar_step          = 0.1;   // Parabolic SAR step (source: 0.1)
input double strategy_sar_max           = 0.2;   // Parabolic SAR maximum (source: 0.2)
input int    strategy_sl_pips           = 30;    // fixed stop (source: 30 pips)
input int    strategy_tp_pips           = 50;    // fixed target (source: 50 pips)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

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
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA cascade (closed bar, shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   // --- Parabolic SAR at trigger bar (shift 1) and prior bar (shift 2) ---
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar_now <= 0.0 || sar_prev <= 0.0)
      return false;

   // EMA(5) at the prior closed bar (shift 2) for the flip reference.
   const double ema_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   if(ema_fast_prev <= 0.0)
      return false;

   // LONG: cascade STATE 5>12>34, SAR placement STATE under EMA(5),
   //       and the PSAR FLIP EVENT (SAR above EMA5 last bar -> below now).
   const bool cascade_long = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool sar_under_now = (sar_now < ema_fast);
   const bool sar_flip_bull = (sar_prev >= ema_fast_prev && sar_now < ema_fast);
   if(cascade_long && sar_under_now && sar_flip_bull)
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
      req.reason = "ema_cascade_psar_long";
      return true;
     }

   // SHORT: cascade STATE 5<12<34, SAR placement STATE above EMA(5),
   //        and the PSAR FLIP EVENT (SAR below EMA5 last bar -> above now).
   const bool cascade_short = (ema_fast < ema_mid && ema_mid < ema_slow);
   const bool sar_above_now = (sar_now > ema_fast);
   const bool sar_flip_bear = (sar_prev <= ema_fast_prev && sar_now > ema_fast);
   if(cascade_short && sar_above_now && sar_flip_bear)
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
      req.reason = "ema_cascade_psar_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed stop/target. Defensive exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite EMA cascade STATE + opposite SAR placement STATE.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0 || sar_now <= 0.0)
      return false;

   // Determine the direction of the open position.
   bool is_long = false;
   bool found   = false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found = true;
      break;
     }
   if(!found)
      return false;

   if(is_long)
     {
      // Opposite cascade (5<12<34) AND SAR now above EMA(5).
      const bool opp_cascade = (ema_fast < ema_mid && ema_mid < ema_slow);
      const bool opp_sar = (sar_now > ema_fast);
      return (opp_cascade && opp_sar);
     }
   else
     {
      // Opposite cascade (5>12>34) AND SAR now below EMA(5).
      const bool opp_cascade = (ema_fast > ema_mid && ema_mid > ema_slow);
      const bool opp_sar = (sar_now < ema_fast);
      return (opp_cascade && opp_sar);
     }
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
