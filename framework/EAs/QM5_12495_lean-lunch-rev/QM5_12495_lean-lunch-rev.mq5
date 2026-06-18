#property strict
#property version   "5.0"
#property description "QM5_12495 lean-lunch-rev — Lunch-break mean reversion (H1, US indices)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12495 lean-lunch-rev
// -----------------------------------------------------------------------------
// Source: QuantConnect Lean Algorithm.Python/Alphas/MeanReversionLunchBreakAlpha.py
//         (commit 261366a7...). Card: artifacts/cards_approved/QM5_12495_lean-lunch-rev.md
//         (g0_status APPROVED).
//
// Thesis (Lean): intraday volume is J-shaped; the quiet lunch hour tends to
// mean-revert the morning move. At the lunch hour, fade the close-to-noon move.
//
// Mechanics (H1, closed-bar reads at shift 1; all session math in BROKER time
// converted to US Eastern via QM_BrokerToUTC + QM_IsUSDSTUTC):
//   Lunch-window STATE : bar-open hour, expressed in US Eastern time, equals
//                        strategy_lunch_hour_et (default 12). DXZ broker time is
//                        UTC+2 / UTC+3 (US-DST-aware), ET is UTC-5 / UTC-4, so
//                        the window is derived robustly via UTC, not a raw offset.
//   Morning-move ROC   : RateOfChangePercent(roc_period) on closed H1 closes =
//                        100 * (close[1] - close[1+roc_period]) / close[1+roc_period].
//   Trigger EVENT      : the FIRST H1 bar of the lunch hour each trading day
//                        (one-trade-per-day latch). Single event — no two-cross.
//                        ROC > +deadband  -> SHORT (fade the up move).
//                        ROC < -deadband  -> LONG  (fade the down move).
//   Stop               : ATR(atr_period) * atr_stop_mult hard stop.
//   Exit               : time stop — close after hold_hours closed H1 bars.
//   Spread guard       : block only a genuinely wide spread (fail-open on the
//                        .DWX zero-modeled-spread tester).
//
// One position per magic. RISK_FIXED in tester / RISK_PERCENT live. No ML.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12495;
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
input int    strategy_lunch_hour_et      = 12;    // lunch hour in US Eastern time (sweep 11/12/13)
input int    strategy_roc_period         = 3;     // RateOfChange lookback in H1 bars (sweep 2..5)
input int    strategy_hold_hours         = 1;     // time-stop: close after N closed H1 bars (sweep 1..3)
input int    strategy_atr_period         = 14;    // ATR period for the hard stop
input double strategy_atr_stop_mult      = 2.0;   // stop distance = mult * ATR (sweep 1.5..3.0)
input double strategy_roc_deadband_pct   = 0.0;   // min |ROC%| to act (0 = any non-zero move)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope state
// -----------------------------------------------------------------------------
// One-trade-per-day latch: the ET calendar day on which we last entered.
datetime g_last_entry_et_day  = 0;
// Bar-open broker time of the bar on which the open position was entered.
datetime g_entry_bar_time     = 0;

// -----------------------------------------------------------------------------
// Helpers (closed-bar / session math)
// -----------------------------------------------------------------------------

// Convert a broker datetime to US Eastern time (DST-aware via UTC).
datetime BrokerToEastern(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int et_offset = QM_IsUSDSTUTC(utc) ? -4 : -5; // EDT / EST
   return utc + (et_offset * 3600);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate, do not block here

   const double stop_distance = strategy_atr_stop_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Lunch-break reversion entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Lunch-window STATE: this bar opens in the lunch hour (US Eastern). ---
   // Key off the bar-open time (shift 0), not the per-tick clock, so the gate
   // is exact on the .DWX tester.
   const datetime bar_open_broker = iTime(_Symbol, _Period, 0); // perf-allowed: bar-open timestamp
   if(bar_open_broker <= 0)
      return false;
   const datetime bar_open_et = BrokerToEastern(bar_open_broker);

   MqlDateTime et;
   ZeroMemory(et);
   TimeToStruct(bar_open_et, et);
   if(et.hour != strategy_lunch_hour_et)
      return false;

   // --- Trigger EVENT: one entry per ET trading day (first lunch bar). ---
   // ET calendar-day key = midnight-of-the-ET-day.
   const datetime et_day = bar_open_et - (et.hour * 3600 + et.min * 60 + et.sec);
   if(g_last_entry_et_day == et_day)
      return false; // already entered (or attempted) today

   // --- Morning move: ROC(period) over closed H1 bars (close-to-noon proxy). ---
   const double close_now  = iClose(_Symbol, _Period, 1);                       // perf-allowed: single closed-bar read
   const double close_past = iClose(_Symbol, _Period, 1 + strategy_roc_period); // perf-allowed: single closed-bar read
   if(close_now <= 0.0 || close_past <= 0.0)
      return false;
   const double roc_pct = 100.0 * (close_now - close_past) / close_past;

   const double deadband = (strategy_roc_deadband_pct > 0.0 ? strategy_roc_deadband_pct : 0.0);

   QM_OrderType side;
   if(roc_pct > deadband)
      side = QM_SELL;        // morning rallied -> fade short
   else if(roc_pct < -deadband)
      side = QM_BUY;         // morning fell    -> fade long
   else
     {
      // Flat morning: no reversion edge. Latch the day so we don't re-scan
      // every lunch bar, preserving one-attempt-per-day semantics.
      g_last_entry_et_day = et_day;
      return false;
     }

   // --- Stop from ATR. No fixed TP (source exits on the time stop). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // time-stop exit, no take-profit
   req.reason = (side == QM_BUY) ? "lunch_rev_long" : "lunch_rev_short";

   // Latch the day and the entry bar for the time stop.
   g_last_entry_et_day = et_day;
   g_entry_bar_time    = bar_open_broker;
   return true;
  }

// No active management beyond the ATR stop + time-stop exit.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: close after strategy_hold_hours closed H1 bars from entry.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(g_entry_bar_time <= 0)
      return false;

   const datetime bar_open_broker = iTime(_Symbol, _Period, 0); // perf-allowed: bar-open timestamp
   if(bar_open_broker <= 0)
      return false;

   const int hold = (strategy_hold_hours > 0 ? strategy_hold_hours : 1);
   // PeriodSeconds gives the H1 bar length; close once `hold` bars have elapsed.
   const int bars_elapsed = (int)((bar_open_broker - g_entry_bar_time) / PeriodSeconds(_Period));
   if(bars_elapsed >= hold)
     {
      g_entry_bar_time = 0;
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
