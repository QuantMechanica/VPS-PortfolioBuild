#property strict
#property version   "5.0"
#property description "QM5_11029 atc-time-momo — Fixed-Time Intraday Momentum (M5, FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11029 atc-time-momo
// -----------------------------------------------------------------------------
// Source: Sergey Abramov, Interview ATC 2012, MQL5 Articles #606.
// Card: artifacts/cards_approved/QM5_11029_atc-time-momo.md (g0_status APPROVED).
//
// Mechanic (M5, FX, one fixed daily attempt):
//   Once per trading day, on the first M5 closed bar whose UTC open-time
//   minute-of-day lands inside the entry window [entry_utc_minutes,
//   entry_utc_minutes + 5), evaluate prior momentum and enter WITH it.
//
//   Time-of-day discipline (build NOTE): the entry/EOD windows are derived from
//   the bar's BROKER timestamp converted to UTC via QM_BrokerToUTC — never a
//   fixed wall-clock broker assumption. The window params are UTC minutes-of-day
//   so the rule is DST-robust (DXZ broker is UTC+2/+3).
//
//   Prior movement = close[1] - close[1 + lookback_bars]  (close-to-close;
//   gapless .DWX CFDs => use prior CLOSE, never range).
//   Long  : movement >=  min_movement_atr * ATR(14,M5)  -> buy with momentum.
//   Short : movement <= -min_movement_atr * ATR(14,M5)  -> sell with momentum.
//   Stop  : sl_atr_mult * ATR (price via QM_StopATRFromValue).
//   Take  : strong_tp_atr_mult * ATR when |movement| >= strong_movement_atr*ATR
//           (momentum already extended -> nearer target), else normal_tp_atr_mult.
//   EOD   : flat by end of day — close any open position once the bar UTC
//           minute-of-day reaches eod_utc_minutes.
//   One open position per symbol/magic. Fixed params, no re-optimization.
//   Spread guard fail-OPEN on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11029;
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
// Entry window in UTC minutes-of-day. Default 510 = 08:30 UTC (the source's
// ~10:36 broker server time mapped to the London-morning underlying market).
// On M5, a bar opening within [entry, entry+5) UTC is the single daily attempt.
input int    strategy_entry_utc_minutes   = 510;    // 08:30 UTC
// End-of-day flat window in UTC minutes-of-day. Default 1200 = 20:00 UTC.
input int    strategy_eod_utc_minutes     = 1200;   // 20:00 UTC
input int    strategy_lookback_bars       = 12;     // prior-movement window in M5 bars (12*5=60min)
input int    strategy_atr_period          = 14;     // ATR(14,M5): movement scale, stop, target
input double strategy_min_movement_atr    = 0.50;   // |move| must be >= this * ATR to trade
input double strategy_strong_movement_atr = 1.50;   // |move| >= this * ATR => use the nearer (strong) TP
input double strategy_sl_atr_mult         = 0.80;   // stop distance = mult * ATR
input double strategy_tp_normal_atr_mult  = 1.20;   // target when movement is normal
input double strategy_tp_strong_atr_mult  = 0.80;   // target when movement is already strong
input double strategy_spread_pct_of_stop  = 25.0;   // skip if spread > this % of stop distance

// File-scope: once-per-day attempt latch, keyed by the bar's UTC calendar day.
// This is a per-day trade-attempt dedupe (the source fires ONE setup per day),
// NOT a new-bar reimplementation — the framework QM_IsNewBar still gates cadence.
datetime g_last_attempt_day_utc = 0;

// Day index (UTC) of a bar's broker open time, used to dedupe one attempt/day.
datetime UtcDayOfBarOpen()
  {
   // iTime returns the bar OPEN in BROKER time. Convert to UTC, then truncate to
   // the UTC calendar day. perf-allowed: single closed-bar timestamp read.
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return 0;
   const datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   return (datetime)((bar_open_utc / 86400) * 86400);
  }

// Minute-of-day (UTC) of the last closed bar's open time.
int UtcMinuteOfBarOpen()
  {
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return -1;
   const datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(bar_open_utc, dt);
   return dt.hour * 60 + dt.min;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Fixed-time momentum entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Time-of-day gate (UTC, derived from the bar timestamp) ---
   const int minute_of_day = UtcMinuteOfBarOpen();
   if(minute_of_day < 0)
      return false;
   // M5 bar must open inside the entry window [entry, entry + 5) UTC.
   if(minute_of_day < strategy_entry_utc_minutes ||
      minute_of_day >= strategy_entry_utc_minutes + 5)
      return false;

   // One attempt per UTC trading day.
   const datetime day_utc = UtcDayOfBarOpen();
   if(day_utc == 0 || day_utc == g_last_attempt_day_utc)
      return false;
   // Latch the attempt regardless of whether the momentum condition fires:
   // the source evaluates the setup once per day and does not re-poll.
   g_last_attempt_day_utc = day_utc;

   // --- Prior movement: close-to-close over the lookback window ---
   const double close_recent = iClose(_Symbol, _Period, 1);                          // perf-allowed: closed-bar read
   const double close_past   = iClose(_Symbol, _Period, 1 + strategy_lookback_bars); // perf-allowed: closed-bar read
   if(close_recent <= 0.0 || close_past <= 0.0)
      return false;
   const double movement = close_recent - close_past;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double min_move    = strategy_min_movement_atr * atr_value;
   const double strong_move = strategy_strong_movement_atr * atr_value;
   const double abs_move    = MathAbs(movement);
   if(abs_move < min_move)
      return false; // momentum too small — no trade today

   // Strong-momentum => nearer take profit.
   const double tp_mult = (abs_move >= strong_move)
                          ? strategy_tp_strong_atr_mult
                          : strategy_tp_normal_atr_mult;

   QM_OrderType side = (movement > 0.0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, tp_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "atc_time_momo";
   return true;
  }

// No active trade management beyond the fixed ATR stop/target.
void Strategy_ManageOpenPosition()
  {
  }

// End-of-day flat: close the open position once the bar UTC minute-of-day
// reaches the EOD window. SL/TP otherwise handle the exit.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int minute_of_day = UtcMinuteOfBarOpen();
   if(minute_of_day < 0)
      return false;

   return (minute_of_day >= strategy_eod_utc_minutes);
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
