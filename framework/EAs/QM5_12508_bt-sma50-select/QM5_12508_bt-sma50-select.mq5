#property strict
#property version   "5.0"
#property description "QM5_12508 bt-sma50-select — SMA50 long/flat regime filter (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12508 bt-sma50-select
// -----------------------------------------------------------------------------
// Source: Philippe Morissette, "bt - Flexible Backtesting for Python"
//   (github.com/pmorissette/bt, docs SMA Strategy section, commit 2630651).
// Card: artifacts/cards_approved/QM5_12508_bt-sma50-select.md (g0_status APPROVED).
//
// The bt example selects securities above their 50-day SMA, equal-weights and
// rebalances. The MT5 port (per the card's Mechanik section) reduces this to an
// INDEPENDENT PER-SYMBOL long/flat regime filter — NOT a cross-sectional
// rotation. Each symbol runs this same EA on its own magic slot; there is no
// ranking across the universe. kind:single.
//
// Mechanics (long-only, closed-bar reads at shift 1):
//   Regime STATE : D1 close > SMA(50).
//   Entry  EVENT : the close crosses UP through SMA(50) on the just-closed bar
//                  (close[2] <= SMA[2] AND close[1] > SMA[1]). One event/bar.
//                  Using a cross EVENT (not the raw "close>SMA" state) means we
//                  open once when the regime turns bullish and hold while above;
//                  the state-based exit closes when the regime flips. This is
//                  the long/flat filter and avoids any two-cross-same-bar trap
//                  (entry = ONE cross event; exit = a STATE check, never a
//                  second simultaneous cross).
//   Exit   STATE : close <= SMA(50) on the just-closed bar -> close manually.
//   Emergency stop: entry - sl_atr_mult * ATR(atr_period). The re-entry-after-
//                  flat rule from the card is satisfied automatically: a stop-out
//                  goes flat; re-entry needs a fresh cross-UP event, which can
//                  only occur after the close has been at/below the SMA (i.e. a
//                  flat regime) and then crosses back above.
//   Spread guard : skip only a genuinely wide spread relative to the stop
//                  distance (fail-OPEN on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12508;
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
input int    strategy_sma_period         = 50;     // SMA period on D1 close (card: 50)
input int    strategy_atr_period         = 20;     // ATR period for the emergency stop (card: 20)
input double strategy_sl_atr_mult        = 3.0;    // emergency stop = mult * ATR below entry (card: 3.0)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
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

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Need >= strategy_sma_period completed D1 bars (card: no entry under 50).
   if(Bars(_Symbol, _Period) < strategy_sma_period + 3)
      return false;

   // --- SMA(50) on the just-closed bar (shift 1) and the prior bar (shift 2) ---
   const double sma1  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma2  = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Entry EVENT: close crosses UP through SMA(50) on the closed bar. ---
   // ONE trigger event (prior bar at/below, just-closed bar above). The exit is
   // the inverse STATE; the two are never required to coincide on one bar.
   const bool crossed_up = (close2 <= sma2 && close1 > sma1);
   if(!crossed_up)
      return false;

   // --- Emergency stop only: entry - sl_atr_mult * ATR. No TP (regime exit). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no take-profit; the SMA regime exit closes the trade
   req.reason = "sma50_regime_long";
   return true;
  }

// No active trade management beyond the fixed emergency ATR stop. The regime
// long/flat exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Regime exit STATE: close of the just-closed bar <= SMA(50) -> go flat.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double sma1   = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   if(sma1 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   return (close1 <= sma1);
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
