#property strict
#property version   "5.0"
#property description "QM5_11662 fps-ema10-25-50-h1 — Triple EMA(10/25/50) trend follow (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11662 fps-ema10-25-50-h1
// -----------------------------------------------------------------------------
// Source: Anonymous (DayTradeForex.com), "Forex Profit System (FPS)", in:
//         9 Forex Systems (MoneyTec compilation, ~2006).
// Card: artifacts/cards_approved/QM5_11662_fps-ema10-25-50-h1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1/2; H1):
//   Trend STATE (long) : EMA10 > EMA25 > EMA50  (full bullish stack).
//   Trend STATE (short): EMA10 < EMA25 < EMA50  (full bearish stack).
//   Trigger EVENT      : ONE cross only — price closes through EMA10 in the
//                        stacked-trend direction:
//                          long : close[2] <= EMA10[2]  AND  close[1] >  EMA10[1]
//                          short: close[2] >= EMA10[2]  AND  close[1] <  EMA10[1]
//                        The EMA stack is a STATE, the close/EMA10 cross is the
//                        single EVENT — never two fresh crosses on the same bar
//                        (avoids the .DWX two-cross zero-trade trap).
//   Stop   : entry -/+ sl_atr_mult * ATR(atr_period)  (factory-standard ATR stop).
//   Take   : RR-multiple backstop TP (sl_distance * tp_rr).  Primary exit is the
//            EMA10 recross below.
//   Exit   : close LONG  when close[1] < EMA10[1];
//            close SHORT when close[1] > EMA10[1]  (card: "recross EMA10").
//   Spread : block only a genuinely wide spread (> spread_pct_of_stop of the
//            stop distance); fail-open on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11662;
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
input int    strategy_ema_fast_period    = 10;    // fast EMA (trigger MA)
input int    strategy_ema_mid_period     = 25;    // medium EMA (stack)
input int    strategy_ema_slow_period    = 50;    // slow EMA (stack)
input int    strategy_atr_period         = 14;    // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_tp_rr              = 3.0;   // RR-multiple backstop take-profit
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long/short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA stack (closed bar, shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   // --- Trigger EVENT: ONE cross of close through EMA10 (shift 2 -> shift 1) ---
   const double close1     = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2     = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || ema_fast_2 <= 0.0)
      return false;

   const bool bull_stack = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool bear_stack = (ema_fast < ema_mid && ema_mid < ema_slow);

   const bool cross_up   = (close2 <= ema_fast_2 && close1 >  ema_fast);
   const bool cross_down = (close2 >= ema_fast_2 && close1 <  ema_fast);

   QM_OrderType dir;
   if(bull_stack && cross_up)
      dir = QM_BUY;
   else if(bear_stack && cross_down)
      dir = QM_SELL;
   else
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "fps_ema_stack_long" : "fps_ema_stack_short";
   return true;
  }

// Fixed ATR stop / RR target + EMA10-recross exit. No active management.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: price recrosses EMA10 against the open position (closed bar).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_fast <= 0.0 || close1 <= 0.0)
      return false;

   // Determine the open direction from the live position for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && close1 < ema_fast)
      return true;   // long: close back below EMA10
   if(have_short && close1 > ema_fast)
      return true;   // short: close back above EMA10
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
