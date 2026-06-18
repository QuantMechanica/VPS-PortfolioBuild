#property strict
#property version   "5.0"
#property description "QM5_12493 lean-fx-sma-rev — Lean FX SMA intraday reversal (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12493 lean-fx-sma-rev
// -----------------------------------------------------------------------------
// Source: QuantConnect Lean Algorithm.Python/Alphas/
//         IntradayReversalCurrencyMarketsAlpha.py (commit 261366a7…).
// Card: artifacts/cards_approved/QM5_12493_lean-fx-sma-rev.md (g0_status APPROVED).
//
// Mechanics (mean-reversion around SMA, closed-bar reads at shift 1):
//   Stretch STATE : closed price sits ABOVE or BELOW SMA(period) (the side).
//   Trigger EVENT : a fresh cross of the SMA on the last closed bar —
//                     close[2] >= SMA  AND  close[1] < SMA  -> price crossed
//                     BELOW the mean -> stretched down -> go LONG (reversion up).
//                     close[2] <= SMA  AND  close[1] > SMA  -> price crossed
//                     ABOVE the mean -> stretched up   -> go SHORT (reversion down).
//                   Exactly ONE cross event is required (no two-cross trap; the
//                   long and short conditions are mutually exclusive on a bar).
//   Session GATE  : only enter while NY local time is inside [start, end).
//                   DXZ NY-Close broker time = NY local + 7h (US DST shifts both
//                   UTC offsets together, so the NY->broker offset is constant).
//                   NY 10:00->broker 17:00 ; NY 15:00->broker 22:00.
//   Re-entry rule : do NOT open a new position in the SAME direction as the
//                   currently/last signalled direction (Lean: skip same-side).
//   Exit          : (a) time exit at NY end+1min (15:01) -> flat;
//                   (b) opposite cross signal closes the open position.
//   Stop          : ATR(period) * sl_atr_mult hard stop (source silent — V5
//                   default; swept in Q03). No fixed TP (reversion exits on
//                   the time stop or the opposite signal).
//   Spread guard  : block only a genuinely wide spread (> spread_pct_of_stop of
//                   the stop distance); fail-open on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12493;
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
input int    strategy_sma_period         = 5;      // SMA period on H1 closes
input int    strategy_session_start_ny   = 10;     // NY local hour, window opens (inclusive)
input int    strategy_session_end_ny     = 15;     // NY local hour, window closes (last entry < this)
input int    strategy_time_exit_ny_min   = 1;      // minutes past session_end_ny for the flat-exit (15:01)
input int    strategy_atr_period         = 14;     // ATR period for the hard stop
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// DXZ NY-Close broker time leads NY local time by a constant 7 hours
// (broker = UTC + {2 std,3 dst}; NY local = UTC - {5 std,4 dst}; difference = 7).
#define QM12493_NY_TO_BROKER_HOURS 7

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Broker-time hour-of-day for a given NY local hour (wraps into 0..23).
int QM12493_NyHourToBrokerHour(const int ny_hour)
  {
   int h = ny_hour + QM12493_NY_TO_BROKER_HOURS;
   h %= 24;
   if(h < 0)
      h += 24;
   return h;
  }

// True while the broker clock is inside the NY entry window [start, end).
bool QM12493_InEntrySession(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int now_min   = dt.hour * 60 + dt.min;
   const int start_min = QM12493_NyHourToBrokerHour(strategy_session_start_ny) * 60;
   const int end_min   = QM12493_NyHourToBrokerHour(strategy_session_end_ny) * 60;

   if(start_min == end_min)
      return false;
   if(start_min < end_min)
      return (now_min >= start_min && now_min < end_min);
   // window wraps past broker midnight
   return (now_min >= start_min || now_min < end_min);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — session/signal work runs on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
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

// Mean-reversion entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Session GATE: only enter inside the NY window (broker time) ---
   if(!QM12493_InEntrySession(TimeCurrent()))
      return false;

   // --- SMA + closed-bar prices (shift 1 = last closed bar, shift 2 = prior) ---
   const double sma   = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   if(sma <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Trigger EVENT: ONE fresh cross of the SMA on the last closed bar ---
   // Price crossed BELOW the mean -> stretched down -> go LONG (revert up).
   const bool crossed_below = (close2 >= sma && close1 < sma);
   // Price crossed ABOVE the mean -> stretched up   -> go SHORT (revert down).
   const bool crossed_above = (close2 <= sma && close1 > sma);
   if(crossed_below == crossed_above)
      return false; // neither, or the degenerate equal case — no single trigger

   const double entry = SymbolInfoDouble(_Symbol, crossed_below ? SYMBOL_ASK : SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   if(crossed_below)
     {
      const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — reversion exits on time stop / opposite signal
      req.reason = "lean_sma_rev_long";
      return true;
     }

   // crossed_above -> SHORT
   const double sl = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = "lean_sma_rev_short";
   return true;
  }

// No active management beyond the fixed ATR stop. Time/opposite exits live in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit on: (a) time stop at NY end+1min (15:01); (b) opposite SMA cross.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // --- (a) Time exit: flat once the broker clock reaches NY end + N minutes ---
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int now_min  = dt.hour * 60 + dt.min;
   const int exit_min = QM12493_NyHourToBrokerHour(strategy_session_end_ny) * 60
                        + strategy_time_exit_ny_min;
   // Treat the 60-minute band starting at the exit minute as "session over"
   // (H1 bars land on the hour; this fires on the first tick at/after 15:01 NY).
   if(now_min >= exit_min && now_min < exit_min + 60)
      return true;

   // --- (b) Opposite-signal exit: a fresh SMA cross against the open side ---
   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   if(sma <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const bool crossed_below = (close2 >= sma && close1 < sma); // would trigger LONG
   const bool crossed_above = (close2 <= sma && close1 > sma); // would trigger SHORT

   // Find the open side for this magic and close it on the opposing cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && crossed_above)
         return true; // long open, fresh short signal
      if(ptype == POSITION_TYPE_SELL && crossed_below)
         return true; // short open, fresh long signal
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
