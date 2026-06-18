#property strict
#property version   "5.0"
#property description "QM5_11765 ema5-ema13-fibonacci-cross-h1 — EMA5/EMA13 cross with gap+separation filter (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11765 ema5-ema13-fibonacci-cross-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "5 EMA and 13 EMA Fibonacci Numbers Trading System",
//         ForexStrategiesResources.com (~2015). Strategy #84.
// Card: artifacts/cards_approved/QM5_11765_ema5-ema13-fibonacci-cross-h1.md
//       (g0_status APPROVED).
//
// IMPORTANT — "Fibonacci" naming: the card explicitly states (body line 35)
// that "Fibonacci" here refers ONLY to the EMA periods (5 and 13 are Fibonacci
// sequence numbers) and that this is NOT a Fibonacci-retracement strategy. The
// approved mechanical body (## Mechanik + ## Implementation Notes) defines a
// pure EMA(5)/EMA(13) crossover system with a price-distance gap filter and a
// MA-separation filter. We implement the card verbatim; no retracement levels
// are computed. (Flagged in build_result open_questions vs the build-prompt's
// "compute Fib levels in-EA" wording — the card body is the binding spec, HR9.)
//
// Mechanics (closed-bar reads at shift 1; cross EVENT vs filter STATE):
//   Trigger EVENT (long) : EMA(5) crosses ABOVE EMA(13)
//                          ema5[2] <= ema13[2]  AND  ema5[1] > ema13[1].
//   Trigger EVENT (short): EMA(5) crosses BELOW EMA(13)
//                          ema5[2] >= ema13[2]  AND  ema5[1] < ema13[1].
//   Gap STATE   : |close[1] - ema13[1]| <= gap_max_pips  (don't enter when
//                 price is already very far from EMA13).
//   Sep STATE   : |ema5[1] - ema13[1]| >  min_sep_pips   (skip when the MAs
//                 are effectively touching / no clean separation).
//   Stop        : sl_pips beyond EMA(13) in the unfavorable direction
//                 (long: ema13[1] - sl_pips ; short: ema13[1] + sl_pips).
//   Trailing    : per closed bar, recompute EMA13-anchored stop and ratchet it
//                 only in the favourable direction (never loosen).
//   Exit        : reverse EMA(5)/EMA(13) cross -> close at next bar open.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11765;
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
input int    strategy_ema_fast_period   = 5;     // EMA(5) — fast (Fibonacci number)
input int    strategy_ema_slow_period   = 13;    // EMA(13) — slow (Fibonacci number)
input double strategy_gap_max_pips      = 100.0; // max |close - EMA13| at entry (gap filter)
input double strategy_min_sep_pips      = 1.0;   // min |EMA5 - EMA13| separation to enter
input double strategy_sl_pips           = 50.0;  // stop distance beyond EMA13 (also trailed)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread/session restriction in this strategy;
// the card defines no time/spread filter, so we never block here. (Fail-open on
// .DWX zero modeled spread by design — see .DWX invariant #1.)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The EMA cross is the single trigger EVENT; gap + separation are STATE filters
// evaluated on the same closed bar (no second cross event required).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema5_1  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema13_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema5_2  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema13_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema5_1 <= 0.0 || ema13_1 <= 0.0 || ema5_2 <= 0.0 || ema13_2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Trigger EVENT: a fresh EMA5/EMA13 cross on the just-closed bar ---
   const bool cross_up   = (ema5_2 <= ema13_2 && ema5_1 >  ema13_1);
   const bool cross_down = (ema5_2 >= ema13_2 && ema5_1 <  ema13_1);
   if(!cross_up && !cross_down)
      return false;

   // --- Filter STATES (scale-correct pip->price distances) ---
   const double gap_max  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_gap_max_pips);
   const double min_sep  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_min_sep_pips);
   const double sl_dist  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(sl_dist <= 0.0)
      return false;

   // Separation STATE: MAs must be clearly apart.
   if(MathAbs(ema5_1 - ema13_1) <= min_sep)
      return false;

   // Gap STATE: don't enter if price already far from EMA13.
   if(MathAbs(close1 - ema13_1) > gap_max)
      return false;

   // --- Build the entry. Stop is anchored sl_pips beyond EMA13. ---
   if(cross_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_TM_NormalizePrice(_Symbol, ema13_1 - sl_dist);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed target; exit via reverse cross / trailed SL
      req.reason = "ema5_13_cross_long";
      return true;
     }

   // cross_down
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_TM_NormalizePrice(_Symbol, ema13_1 + sl_dist);
   if(sl_s <= 0.0 || sl_s <= entry_s)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;
   req.reason = "ema5_13_cross_short";
   return true;
  }

// Trail the stop with EMA(13): keep the SL sl_pips beyond the current EMA13,
// moving it ONLY in the favourable direction (never loosen). Runs per tick but
// reads handle-pooled closed-bar EMA + current position SL — O(1).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double ema13_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema13_1 <= 0.0)
      return;
   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(sl_dist <= 0.0)
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

      const long   ptype   = PositionGetInteger(POSITION_TYPE);
      const double cur_sl  = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double new_sl = QM_TM_NormalizePrice(_Symbol, ema13_1 - sl_dist);
         if(new_sl > 0.0 && (cur_sl <= 0.0 || new_sl > cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "ema13_trail_long");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double new_sl = QM_TM_NormalizePrice(_Symbol, ema13_1 + sl_dist);
         if(new_sl > 0.0 && (cur_sl <= 0.0 || new_sl < cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "ema13_trail_short");
        }
     }
  }

// Exit: reverse EMA(5)/EMA(13) cross relative to the open position direction.
// One fresh cross event at shift 1 (ema*_2 -> ema*_1).
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

   // Determine current position direction; close on the opposing cross.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && cross_down)
      return true;
   if(have_short && cross_up)
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
