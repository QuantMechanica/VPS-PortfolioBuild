#property strict
#property version   "5.0"
#property description "QM5_11003 the5ers-ma-macd-filter — EMA 5/35 crossover with MACD main-line sign filter (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11003 the5ers-ma-macd-filter
// -----------------------------------------------------------------------------
// Source: The5ers blog "How To Use A Moving Average For Trend Following"
//         (https://the5ers.com/moving-average-for-trend-following/, 2021-07-04).
// Card: artifacts/cards_approved/QM5_11003_the5ers-ma-macd-filter.md (g0 APPROVED).
//
// Mechanics (closed-bar reads; EMA cross is the EVENT, MACD sign is a STATE):
//   Long  ENTRY : EMA(fast)[2] <= EMA(slow)[2] AND EMA(fast)[1] > EMA(slow)[1]
//                 (fresh bullish cross EVENT) AND MACD main[1] > 0 (STATE)
//                 AND no open position under this magic.
//   Short ENTRY : EMA(fast)[2] >= EMA(slow)[2] AND EMA(fast)[1] < EMA(slow)[1]
//                 (fresh bearish cross EVENT) AND MACD main[1] < 0 (STATE)
//                 AND no open position under this magic.
//   Stop loss   : long  = entry - sl_atr_mult * ATR(atr_period)
//                 short = entry + sl_atr_mult * ATR(atr_period)  (fixed at entry)
//   Exit (long) : EMA(fast) crosses below EMA(slow)  OR  MACD main < 0.
//   Exit (short): EMA(fast) crosses above EMA(slow)  OR  MACD main > 0.
//   Time stop   : close after time_stop_bars closed H1 bars in the position.
//   Spread guard: skip only a genuinely wide spread > spread_pct_of_stop of the
//                 stop distance (fail-OPEN on .DWX zero modeled spread).
//
// NOTE: MACD main line CAN be negative — the sign IS the directional filter.
// There is deliberately no `macd <= 0 -> reject` guard; long wants >0, short <0.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11003;
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
input int    strategy_ema_fast_period    = 5;      // fast EMA (crossover trigger)
input int    strategy_ema_slow_period    = 35;     // slow EMA (crossover trigger)
input int    strategy_macd_fast          = 12;     // MACD fast EMA
input int    strategy_macd_slow          = 26;     // MACD slow EMA
input int    strategy_macd_signal        = 9;      // MACD signal EMA
input int    strategy_atr_period         = 14;     // ATR period for the stop
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input int    strategy_time_stop_bars     = 72;     // close after N closed bars
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
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
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // EMA stack at shift 2 (prior) and shift 1 (last closed bar).
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   // MACD main line at shift 1. CAN be negative — the sign is the filter.
   const double macd_main_1 = QM_MACD_Main(_Symbol, _Period,
                                           strategy_macd_fast, strategy_macd_slow,
                                           strategy_macd_signal, 1);

   // ATR for the stop distance.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Long: fresh bullish EMA cross EVENT + MACD positive STATE ---
   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1);

   if(cross_up && macd_main_1 > 0.0)
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
      req.tp     = 0.0;   // no fixed target; exit on signal / time stop
      req.reason = "ma_macd_long";
      return true;
     }

   // --- Short: fresh bearish EMA cross EVENT + MACD negative STATE ---
   if(cross_down && macd_main_1 < 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "ma_macd_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop only; no active trailing. Exit logic is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit:
//   Long : EMA(fast) crosses below EMA(slow)  OR  MACD main < 0  OR  time stop.
//   Short: EMA(fast) crosses above EMA(slow)  OR  MACD main > 0  OR  time stop.
// Direction is read from the currently-open position under this magic.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Resolve the open position's direction + open time for this magic.
   bool   is_long   = false;
   bool   have_pos  = false;
   datetime open_tm = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_tm  = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // Time stop: close after N closed bars held.
   const int secs_per_bar = PeriodSeconds(_Period);
   if(secs_per_bar > 0 && open_tm > 0)
     {
      const int bars_held = (int)((TimeCurrent() - open_tm) / secs_per_bar);
      if(bars_held >= strategy_time_stop_bars)
         return true;
     }

   // EMA cross + MACD-sign exit on closed bars.
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const double macd_main_1 = QM_MACD_Main(_Symbol, _Period,
                                           strategy_macd_fast, strategy_macd_slow,
                                           strategy_macd_signal, 1);

   if(is_long)
     {
      const bool ema_cross_down = (fast_prev >= slow_prev && fast_now < slow_now);
      if(ema_cross_down || macd_main_1 < 0.0)
         return true;
     }
   else
     {
      const bool ema_cross_up = (fast_prev <= slow_prev && fast_now > slow_now);
      if(ema_cross_up || macd_main_1 > 0.0)
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
