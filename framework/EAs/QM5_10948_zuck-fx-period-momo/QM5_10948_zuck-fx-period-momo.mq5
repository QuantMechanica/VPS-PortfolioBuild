#property strict
#property version   "5.0"
#property description "QM5_10948 zuck-fx-period-momo — FX H1 period-momentum continuation (symmetric, time-stop + ATR stop)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10948 zuck-fx-period-momo
// -----------------------------------------------------------------------------
// Source: Gregory Zuckerman, "The Man Who Solved the Market" (2019), ISBN
//   9780735217980 — currency serial-correlation / consecutive-period momentum.
// Card: artifacts/cards_approved/QM5_10948_zuck-fx-period-momo.md (g0 APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads at shift 1; H1):
//   ret_1     = close[1] / close[2] - 1                          (1-bar return)
//   atr_frac  = ATR(period)[1] / close[1]                        (vol floor)
//   BUY  when ret_1 > +trigger_atr_frac * atr_frac
//   SELL when ret_1 < -trigger_atr_frac * atr_frac
//   Stop      = atr_stop_mult * ATR(period) hard stop from entry.
//   Exit      = time stop after hold_bars closed H1 bars (baseline 1 bar).
//   No TP — the time stop is the profit/loss-taking exit; ATR stop is the
//   emergency stop.
//
// Filters (## Zusaetzliche Filter):
//   - Trade only Mon 06:00 broker time .. Fri 18:00 broker time.
//   - Skip the first H1 bar after the weekend open (first Mon bar at/after 06:00
//     handled by the session start; broader weekend-open guard below).
//   - Skip if spread > spread_pct_of_atr % of ATR(period) (fail-open on .DWX
//     zero modeled spread).
//   - One position per magic; no pyramiding.
//
// Broker time: TimeCurrent() in the .DWX tester IS broker time (NY-close
// GMT+2/+3). The card specifies the session window in broker time, so the
// weekday/hour gate reads TimeCurrent() directly — no conversion needed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10948;
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
input int    strategy_atr_period        = 14;     // ATR period (vol floor + hard stop)
input double strategy_trigger_atr_frac  = 0.20;   // |ret_1| threshold as fraction of atr_frac
input int    strategy_hold_bars         = 1;      // time-stop hold duration in closed H1 bars
input double strategy_atr_stop_mult     = 1.0;    // emergency stop distance = mult * ATR
input double strategy_spread_pct_of_atr = 15.0;   // skip if spread > this % of ATR
input int    strategy_session_start_dow = 1;      // session start weekday (Mon=1)
input int    strategy_session_start_hour = 6;     // session start hour, broker time
input int    strategy_session_end_dow   = 5;      // session end weekday (Fri=5)
input int    strategy_session_end_hour  = 18;     // session end hour, broker time

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window, weekend-open skip, spread cap.
// Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_now, dt);
   const int dow  = dt.day_of_week;   // 0=Sun .. 6=Sat
   const int hour = dt.hour;

   // --- Session window: Mon 06:00 broker .. Fri 18:00 broker ---
   // Block weekends outright.
   if(dow < strategy_session_start_dow || dow > strategy_session_end_dow)
      return true;
   // Block before the Monday start hour.
   if(dow == strategy_session_start_dow && hour < strategy_session_start_hour)
      return true;
   // Block at/after the Friday end hour.
   if(dow == strategy_session_end_dow && hour >= strategy_session_end_hour)
      return true;

   // --- Skip the first H1 bar after the weekend open ---
   // The weekend open is the session-start hour on the start weekday; that whole
   // bar is skipped (entry only fires once price has one full in-session bar).
   if(dow == strategy_session_start_dow && hour == strategy_session_start_hour)
      return true;

   // --- Spread cap: only block a genuinely wide spread (fail-open on 0) ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value > 0.0)
        {
         const double spread = ask - bid;
         if(spread > (strategy_spread_pct_of_atr / 100.0) * atr_value)
            return true;
        }
     }

   return false;
  }

// Symmetric entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar returns: ret_1 = close[1]/close[2] - 1 ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;
   const double ret_1 = close1 / close2 - 1.0;

   // --- Volatility floor: atr_frac = ATR(period)[1] / close[1] ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double atr_frac = atr_value / close1;
   if(atr_frac <= 0.0)
      return false;

   const double threshold = strategy_trigger_atr_frac * atr_frac;

   QM_OrderType dir;
   if(ret_1 > threshold)
      dir = QM_BUY;
   else if(ret_1 < -threshold)
      dir = QM_SELL;
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (dir == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no TP — time stop closes the position
   req.reason = (dir == QM_BUY) ? "period_momo_long" : "period_momo_short";
   return true;
  }

// No active trade management beyond the fixed ATR hard stop. The time stop
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: close after strategy_hold_bars closed H1 bars have elapsed since
// the entry bar. Counts completed bars between the position-open bar and the
// most recent closed bar (shift 1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's open position and read its open time (broker time).
   datetime open_time = 0;
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      found = true;
      break;
     }
   if(!found)
      return false;

   // Bar-open time of the most recently CLOSED bar (shift 1).
   const datetime last_closed_bar = iTime(_Symbol, _Period, 1);
   if(last_closed_bar <= 0)
      return false;

   // The entry filled on the bar whose open time is the FIRST bar-open at/after
   // open_time. Count how many closed bars have completed since that entry bar.
   // Number of full H1 bars between the entry bar-open and the last closed bar.
   const int tf_seconds = PeriodSeconds(_Period);
   if(tf_seconds <= 0)
      return false;

   // Entry bar-open: floor open_time to the bar boundary.
   const datetime entry_bar_open = open_time - (open_time % tf_seconds);
   const long bars_elapsed = (long)((last_closed_bar - entry_bar_open) / tf_seconds);

   // hold_bars closed bars after the entry bar => exit.
   return (bars_elapsed >= (long)strategy_hold_bars);
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
