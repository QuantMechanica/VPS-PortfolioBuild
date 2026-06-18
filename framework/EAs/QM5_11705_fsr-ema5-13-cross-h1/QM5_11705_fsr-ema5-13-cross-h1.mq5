#property strict
#property version   "5.0"
#property description "QM5_11705 fsr-ema5-13-cross-h1 — EMA5/EMA13 Fibonacci cross (both directions, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11705 fsr-ema5-13-cross-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "5 EMA and 13 EMA Fibonacci Numbers Trading System" (#84),
//         forexstrategiesresources.com, 2013.
// Card: artifacts/cards_approved/QM5_11705_fsr-ema5-13-cross-h1.md (g0 APPROVED).
//
// Mechanics (both directions, closed-bar reads; trade TF = H1):
//   Trigger EVENT (long) : EMA5 crosses ABOVE EMA13 on the just-closed bar
//                          EMA5[2] <= EMA13[2]  AND  EMA5[1] > EMA13[1].
//                          (ONE cross per direction — never two events/bar.)
//   Trigger EVENT (short): mirror — EMA5 crosses BELOW EMA13.
//   Filter 1 (gap)   : |EMA5[1] - EMA13[1]| must exceed gap_min_pips (cross
//                      too tight may reverse).
//   Filter 2 (risk)  : SL distance from entry must be < sl_max_pips; else skip.
//   Stop             : sl_offset_pips from EMA13 (below for long, above short).
//   Trailing stop    : on each new bar move SL to EMA13 -/+ sl_offset_pips only
//                      in the favourable direction (never loosen).
//   Safety TP        : tp_atr_mult * ATR(atr_period) hard cap (card note).
//   Defensive exit   : opposite EMA5/13 cross -> close the position.
//
// Pip distances go through QM_StopRulesPipsToPriceDistance so 5-digit and JPY
// symbols scale correctly. .DWX invariants honoured: spread guard fails open on
// zero modeled spread; QM_IsNewBar consumed once (framework OnTick); a single
// cross EVENT is the trigger (no two-cross-same-bar trap).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11705;
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
input int    strategy_ema_fast_period   = 5;     // Fibonacci fast EMA
input int    strategy_ema_slow_period   = 13;    // Fibonacci slow EMA
input double strategy_gap_min_pips      = 1.0;   // min |EMA5-EMA13| gap (Filter 1)
input double strategy_sl_offset_pips    = 50.0;  // SL distance from EMA13 (trailing anchor)
input double strategy_sl_max_pips       = 100.0; // skip if entry->SL distance exceeds this (Filter 2)
input int    strategy_atr_period        = 14;    // ATR period for the safety TP cap
input double strategy_tp_atr_mult       = 3.0;   // safety TP = mult * ATR (card note)
input double strategy_spread_pct_of_stop = 15.0; // skip only a genuinely wide spread

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Cap scales with the SL offset distance so the guard is symbol-agnostic.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_offset_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on a single EMA5/EMA13 cross EVENT (both directions). Caller guarantees
// QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Closed-bar EMA reads. shift 1 = just-closed bar, shift 2 = prior bar.
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   // ONE cross event per direction (never both on the same bar).
   const bool crossed_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool crossed_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);
   if(!crossed_up && !crossed_down)
      return false;

   // Filter 1: gap between the EMAs at the cross must exceed the minimum.
   const double gap_min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_gap_min_pips);
   if(MathAbs(ema_fast_1 - ema_slow_1) <= gap_min_dist)
      return false;

   const QM_OrderType otype = crossed_up ? QM_BUY : QM_SELL;

   // Entry at current market price for the cross direction.
   const double entry = crossed_up ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop: sl_offset_pips from EMA13 (below for long, above for short).
   const double sl_offset_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_offset_pips);
   if(sl_offset_dist <= 0.0)
      return false;
   double sl = crossed_up ? (ema_slow_1 - sl_offset_dist)
                          : (ema_slow_1 + sl_offset_dist);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   // Filter 2: entry->SL distance must be under the cap, and SL on the correct side.
   const double sl_distance = MathAbs(entry - sl);
   const double sl_max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_max_pips);
   if(sl_distance <= 0.0 || sl_distance >= sl_max_dist)
      return false;
   if(crossed_up && sl >= entry)
      return false;
   if(crossed_down && sl <= entry)
      return false;

   // Safety TP cap = tp_atr_mult * ATR (card note; no fixed TP in the source).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   double tp = 0.0;
   if(atr_value > 0.0)
      tp = QM_TakeATRFromValue(_Symbol, otype, entry, atr_value, strategy_tp_atr_mult);

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;    // 0.0 if ATR unavailable -> no TP, exit on reverse cross/SL
   req.reason = crossed_up ? "ema5_13_cross_long" : "ema5_13_cross_short";
   return true;
  }

// Trailing stop: move SL toward EMA13 -/+ sl_offset_pips, favourable direction
// only (never loosen). Runs per tick; cheap O(1) using pooled EMA reader.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_slow_1 <= 0.0)
      return;

   const double sl_offset_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_offset_pips);
   if(sl_offset_dist <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, ema_slow_1 - sl_offset_dist);
         if(new_sl > cur_sl) // tighten only
            QM_TM_MoveSL(ticket, new_sl, "ema13_trail");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, ema_slow_1 + sl_offset_dist);
         if(cur_sl <= 0.0 || new_sl < cur_sl) // tighten only
            QM_TM_MoveSL(ticket, new_sl, "ema13_trail");
        }
     }
  }

// Defensive exit: opposite EMA5/13 cross. One event at the just-closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool crossed_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool crossed_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);

   // Close a long on a fresh bearish cross; close a short on a fresh bullish cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && crossed_down)
         return true;
      if(pos_type == POSITION_TYPE_SELL && crossed_up)
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
