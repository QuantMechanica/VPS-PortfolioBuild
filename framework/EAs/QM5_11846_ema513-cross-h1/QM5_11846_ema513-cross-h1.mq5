#property strict
#property version   "5.0"
#property description "QM5_11846 ema513-cross-h1 — EMA(5)/EMA(13) Fibonacci crossover (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11846 ema513-cross-h1
// -----------------------------------------------------------------------------
// Source: forexstrategiesresources.com, "5 EMA and 13 EMA Fibonacci Numbers
//   Trading System" (~2013). Card:
//   artifacts/cards_approved/QM5_11846_ema513-cross-h1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trigger EVENT (long) : EMA(5) crosses ABOVE EMA(13). One cross only —
//                          ema5[2] <= ema13[2] AND ema5[1] > ema13[1].
//   Trigger EVENT (short): EMA(5) crosses BELOW EMA(13).
//   Spread STATE         : |EMA5 - EMA13| at shift 1 >= min_ema_spread_pips
//                          (skip too-narrow / choppy crosses).
//   SL-distance STATE    : |Close[1] - EMA13[1]| <= max_sl_distance_pips
//                          (skip when the implied stop would be too wide).
//   Stop                 : sl_pips fixed from EMA(13) at entry (50 pips default),
//                          measured as a price distance from the entry fill.
//   Take profit          : entry +/- tp_atr_mult * ATR(14) (factory hard TP).
//   Trade management      : trail SL toward EMA(13) on each new bar, never loosening.
//   Defensive exit        : opposite EMA(5)/EMA(13) cross -> close manually.
//   Spread guard          : block only a genuinely wide quoted spread
//                          (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11846;
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
input int    strategy_ema_fast_period    = 5;     // fast EMA (Fibonacci 5)
input int    strategy_ema_slow_period    = 13;    // slow EMA (Fibonacci 13)
input double strategy_min_ema_spread_pips = 1.0;  // skip if |EMA5-EMA13| < this (pips)
input double strategy_max_sl_distance_pips = 100.0; // skip if |Close-EMA13| > this (pips)
input double strategy_sl_pips            = 50.0;  // hard stop distance from entry (pips)
input int    strategy_atr_period         = 14;    // ATR period for the take-profit
input double strategy_tp_atr_mult        = 2.0;   // take-profit = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // block if quoted spread > this % of stop

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — the EMA cross / state filters
// live in Strategy_EntrySignal on the closed-bar path. Fail-open on the .DWX
// zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap, scaled to the symbol.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_pips));
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide quoted spread blocks; zero/negative modeled spread passes.
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

   // --- EMAs on the two most recent closed bars (shift 1 = last closed). ---
   const double ema5_1  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema13_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema5_2  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema13_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema5_1 <= 0.0 || ema13_1 <= 0.0 || ema5_2 <= 0.0 || ema13_2 <= 0.0)
      return false;

   // --- Trigger EVENT: a single fresh EMA5/EMA13 cross at shift 1. ---
   const bool cross_up   = (ema5_2 <= ema13_2 && ema5_1 >  ema13_1);
   const bool cross_down = (ema5_2 >= ema13_2 && ema5_1 <  ema13_1);
   if(!cross_up && !cross_down)
      return false;

   // --- Spread STATE: EMA separation must clear the minimum (pip distance). ---
   const double min_spread_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_min_ema_spread_pips));
   if(min_spread_dist > 0.0 && MathAbs(ema5_1 - ema13_1) < min_spread_dist)
      return false;

   // --- SL-distance STATE: distance from close to EMA13 must be within cap. ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   const double max_sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_max_sl_distance_pips));
   if(max_sl_dist > 0.0 && MathAbs(close1 - ema13_1) > max_sl_dist)
      return false;

   // --- Volatility for the take-profit. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   if(cross_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)MathRound(strategy_sl_pips));
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema513_cross_long";
      return true;
     }

   // cross_down -> short
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopFixedPips(_Symbol, QM_SELL, entry_s, (int)MathRound(strategy_sl_pips));
   const double tp_s = QM_TakeATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_tp_atr_mult);
   if(sl_s <= 0.0 || tp_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = tp_s;
   req.reason = "ema513_cross_short";
   return true;
  }

// Trade management: trail the stop toward EMA(13) once per closed bar, never
// loosening it. Card: "Trail SL to EMA(13) value on each bar."
void Strategy_ManageOpenPosition()
  {
   if(!QM_IsNewBar())
      return; // closed-bar cadence; the entry gate latches its own QM_IsNewBar

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double ema13_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema13_1 <= 0.0)
      return;
   const double new_sl = QM_TM_NormalizePrice(_Symbol, ema13_1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype   = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double open_p = PositionGetDouble(POSITION_PRICE_OPEN);

      if(ptype == POSITION_TYPE_BUY)
        {
         // Only trail up, and only when EMA13 sits below entry (protective).
         if(new_sl < open_p && (cur_sl == 0.0 || new_sl > cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "trail_ema13");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(new_sl > open_p && (cur_sl == 0.0 || new_sl < cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "trail_ema13");
        }
     }
  }

// Defensive exit: opposite EMA(5)/EMA(13) cross. One event at shift 1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema5_1  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema13_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema5_2  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema13_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema5_1 <= 0.0 || ema13_1 <= 0.0 || ema5_2 <= 0.0 || ema13_2 <= 0.0)
      return false;

   const bool cross_up   = (ema5_2 <= ema13_2 && ema5_1 >  ema13_1);
   const bool cross_down = (ema5_2 >= ema13_2 && ema5_1 <  ema13_1);

   // Close a long on a bearish cross, a short on a bullish cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_up)
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
