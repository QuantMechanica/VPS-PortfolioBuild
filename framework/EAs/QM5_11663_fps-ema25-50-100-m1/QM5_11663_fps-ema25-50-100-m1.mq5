#property strict
#property version   "5.0"
#property description "QM5_11663 fps-ema25-50-100-m1 — Triple EMA(25/50/100) M1 scalp, session-timed"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11663 fps-ema25-50-100-m1
// -----------------------------------------------------------------------------
// Source: Anonymous (DayTradeForex.com), "'Scalp' Trading the 1min Charts",
//         in: 9 Forex Systems (MoneyTec compilation). source_id c6118ff9.
// Card: artifacts/cards_approved/QM5_11663_fps-ema25-50-100-m1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, M1):
//   Trend STATE (long) : EMA(25) > EMA(50) > EMA(100)   (stacked-bullish)
//   Trend STATE (short): EMA(25) < EMA(50) < EMA(100)   (stacked-bearish)
//   Trigger STATE      : just-closed bar's close is above EMA(25) for long,
//                        or below EMA(25) for short, while the EMA stack is
//                        aligned in the same direction. The card does not require
//                        a fresh EMA cross event.
//   Stop Loss          : fixed 10 pips (QM_StopFixedPips, pip-scale correct).
//   Take Profit        : fixed 7 pips  (QM_StopFixedPips on the opposite side).
//   Exit               : SL/TP only (fixed-pip scalp); no discretionary exit.
//   Session filter     : trade only inside London-open 07:00-10:00 UTC and
//                        NY-open 12:00-15:00 UTC. Window evaluated in UTC via
//                        QM_BrokerToUTC (broker = DXZ NY-Close GMT+2/+3 DST-aware),
//                        so the windows track the card's stated UTC hours under DST.
//   Spread guard       : block only a genuinely wide spread (>1.5 pips, expressed
//                        as 15% of the 10-pip stop). Fail-open on .DWX zero spread.
//
// NOTE (M1 history): M1 EAs require M1 history in the tester window. DWX M1
// availability is limited pre-2023 — Q02/Q03 setfiles should use a >=2023 window.
// Flagged in build_result.flags / setfile_flags.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11663;
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
input int    strategy_ema_fast_period    = 25;     // fast EMA (stack top / trigger reference)
input int    strategy_ema_mid_period     = 50;     // mid EMA (stack middle)
input int    strategy_ema_slow_period    = 100;    // slow EMA (stack bottom)
input int    strategy_sl_pips            = 10;     // fixed stop-loss distance, pips
input int    strategy_tp_pips            = 7;      // fixed take-profit distance, pips
input double strategy_spread_pct_of_stop = 15.0;   // block if spread > this % of stop distance
// Session windows in UTC (card: London open + NY open). Wrap-safe half-open [start,end).
input int    strategy_sess1_start_utc    = 7;      // London open window start (UTC hour)
input int    strategy_sess1_end_utc      = 10;     // London open window end   (UTC hour)
input int    strategy_sess2_start_utc    = 12;     // NY open window start      (UTC hour)
input int    strategy_sess2_end_utc      = 15;     // NY open window end        (UTC hour)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// True if `hour` is inside the half-open [start,end) window (wrap-safe).
bool HourInWindow(const int hour, const int start_h, const int end_h)
  {
   if(start_h == end_h)
      return false;
   if(start_h < end_h)
      return (hour >= start_h && hour < end_h);
   // wrap across midnight
   return (hour >= start_h || hour < end_h);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Session window (UTC) + spread guard. The trend/trigger
// work is on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   // --- Session filter in UTC. broker -> UTC via the DST-aware helper. ---
   const datetime broker_now = TimeCurrent();
   const datetime utc_now     = QM_BrokerToUTC(broker_now);
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   const int h = dt.hour;
   const bool in_session = HourInWindow(h, strategy_sess1_start_utc, strategy_sess1_end_utc) ||
                           HourInWindow(h, strategy_sess2_start_utc, strategy_sess2_end_utc);
   if(!in_session)
      return true; // outside both open windows — block

   // --- Spread guard. Fail-open on .DWX zero modeled spread. ---
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

   // --- EMA stack STATE on the just-closed bar (shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period,  1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool stacked_long  = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool stacked_short = (ema_fast < ema_mid && ema_mid < ema_slow);
   if(!stacked_long && !stacked_short)
      return false;

   // --- Trigger STATE: just-closed price relative to EMA25 ---
   const int price_vs_fast = QM_Sig_Price_Above_MA(_Symbol, _Period, strategy_ema_fast_period, 0.0, 1);

   QM_OrderType side;
   if(stacked_long && price_vs_fast > 0)
      side = QM_BUY;
   else if(stacked_short && price_vs_fast < 0)
      side = QM_SELL;
   else
      return false;

   // --- Fixed-pip SL/TP (scale-correct via QM_StopFixedPips) ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "fps_ema_stack_long" : "fps_ema_stack_short";
   return true;
  }

// Fixed-pip scalp: SL/TP do all the work. No active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — positions close at fixed SL or TP.
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
