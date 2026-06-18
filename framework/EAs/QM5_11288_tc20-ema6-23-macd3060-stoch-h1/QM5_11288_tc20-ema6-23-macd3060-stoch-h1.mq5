#property strict
#property version   "5.0"
#property description "QM5_11288 tc20-ema6-23-macd3060-stoch-h1 — EMA(6/23) cross + MACD(30,60,30) state + Stoch state (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11288 tc20-ema6-23-macd3060-stoch-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #3 (source_id e78a9f1f-4e6a-563c-a080-915133d6ed28).
// Card: artifacts/cards_approved/QM5_11288_tc20-ema6-23-macd3060-stoch-h1.md
//       (g0_status APPROVED).
//
// Multi-indicator confluence. To avoid the .DWX "two fresh crosses on the same
// bar => zero trades" trap, exactly ONE indicator supplies the trigger EVENT;
// the others are directional STATES checked on the same closed bar:
//
//   Trigger EVENT (LONG)  : EMA(6) crosses ABOVE EMA(23) at shift 1
//                           (ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now)
//   Trigger EVENT (SHORT) : EMA(6) crosses BELOW EMA(23) at shift 1.
//
//   STATE — MACD(30,60,30) main sign (zero-line filter, MAY be negative):
//           LONG  needs MACD_Main >= 0 ; SHORT needs MACD_Main <= 0.
//   STATE — Stochastic(5,3,3) directional position on the trigger bar:
//           LONG  needs K > D ; SHORT needs K < D.
//
//   Stop  : fixed pips (card 20-30; default 25), pip-scale-correct.
//   Take  : fixed pips (card 50-60; default 55), pip-scale-correct.
//   Defensive exit: reverse EMA(6/23) cross closes the open position.
//   Spread guard : block only a genuinely wide spread > cap pips
//                  (fail-OPEN on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11288;
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
input int    strategy_ema_fast_period    = 6;     // primary-trigger fast EMA
input int    strategy_ema_slow_period    = 23;    // primary-trigger slow EMA
input int    strategy_macd_fast          = 30;    // MACD fast EMA (non-standard)
input int    strategy_macd_slow          = 60;    // MACD slow EMA (non-standard)
input int    strategy_macd_signal        = 30;    // MACD signal EMA (zero-line filter uses main line)
input int    strategy_stoch_k            = 5;     // Stochastic %K period
input int    strategy_stoch_d            = 3;     // Stochastic %D period
input int    strategy_stoch_slowing      = 3;     // Stochastic slowing
input double strategy_sl_pips            = 25.0;  // fixed stop distance (pips) — card 20-30
input double strategy_tp_pips            = 55.0;  // fixed take distance (pips) — card 50-60
input double strategy_spread_cap_pips    = 20.0;  // skip only a genuinely wide spread (card cap)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero / negative modeled spread on .DWX — fail-OPEN

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance <= 0.0)
      return false;

   // Only a genuinely wide spread blocks.
   if(spread > cap_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// EMA(6/23) cross is the TRIGGER EVENT; MACD sign + Stoch position are STATES.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA(6/23) values at the last two closed bars (shift 1 and 2) ---
   const double ema_fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_now <= 0.0 || ema_slow_now <= 0.0 || ema_fast_prev <= 0.0 || ema_slow_prev <= 0.0)
      return false;

   const bool cross_up   = (ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now);
   const bool cross_down = (ema_fast_prev >= ema_slow_prev && ema_fast_now < ema_slow_now);
   if(!cross_up && !cross_down)
      return false; // no trigger EVENT this bar

   // --- STATE: MACD(30,60,30) main-line zero-line filter (can be negative) ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);
   // macd_main of exactly 0.0 is allowed as a boundary; a failed read returns 0.0
   // too, but the EMA-cross trigger already required valid bars so the indicator
   // history is warm — treat 0.0 as a neutral boundary (passes both sides).

   // --- STATE: Stochastic(5,3,3) directional position on the trigger bar ---
   const double stoch_k = QM_Stoch_K(_Symbol, _Period,
                                     strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, _Period,
                                     strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   if(stoch_k <= 0.0 && stoch_d <= 0.0)
      return false; // no valid stochastic read

   QM_OrderType dir;
   if(cross_up)
     {
      // LONG: MACD not bearish (>=0) AND stochastic %K above %D.
      if(macd_main < 0.0)
         return false;
      if(!(stoch_k > stoch_d))
         return false;
      dir = QM_BUY;
     }
   else
     {
      // SHORT: MACD not bullish (<=0) AND stochastic %K below %D.
      if(macd_main > 0.0)
         return false;
      if(!(stoch_k < stoch_d))
         return false;
      dir = QM_SELL;
     }

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, dir, entry, (int)strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, dir, entry, (int)strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "ema_cross_long" : "ema_cross_short";
   return true;
  }

// Fixed SL/TP only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: a reverse EMA(6/23) cross against the open position closes it.
// The OnTick loop closes any position for this magic when this returns true.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double ema_fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_now <= 0.0 || ema_slow_now <= 0.0 || ema_fast_prev <= 0.0 || ema_slow_prev <= 0.0)
      return false;

   const bool cross_up   = (ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now);
   const bool cross_down = (ema_fast_prev >= ema_slow_prev && ema_fast_now < ema_slow_now);
   if(!cross_up && !cross_down)
      return false;

   // Close on the cross opposite to the open direction.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
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
