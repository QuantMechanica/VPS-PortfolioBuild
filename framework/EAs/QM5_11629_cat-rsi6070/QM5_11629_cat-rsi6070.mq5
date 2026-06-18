#property strict
#property version   "5.0"
#property description "QM5_11629 cat-rsi6070 — Catalyst RSI 60/70 mean-reversion (long-only, M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11629 cat-rsi6070
// -----------------------------------------------------------------------------
// Source: scrtlabs/catalyst, catalyst/examples/mean_reversion_simple.py
//   https://github.com/scrtlabs/catalyst/blob/master/catalyst/examples/mean_reversion_simple.py
// Card: artifacts/cards_approved/QM5_11629_cat-rsi6070.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1, M15):
//   Entry TRIGGER (EVENT): RSI(period) crosses DOWN through the entry level
//                          (rsi_prev > rsi_entry_level AND rsi_now <= rsi_entry_level).
//                          The source rule "enter long when RSI <= 60" is realised
//                          as the single fresh cross into the <=60 zone — this is
//                          ONE event per bar and avoids the two-cross zero-trade
//                          trap (the exit RSI>=70 is a STATE, not a second event).
//   Cadence STATE        : at most one NEW entry per broker calendar day
//                          ("one new action per calendar day" from the source).
//   Position STATE       : only enter while flat (one position per magic).
//   Exit (EVENT/STATE)   : close the long when RSI(period) >= rsi_exit_level.
//   Stop (V5 add)        : source has no protective stop; V5 adds an ATR
//                          catastrophic stop = entry - sl_atr_mult * ATR.
//                          No take-profit: the RSI>=70 exit IS the profit target.
//   Spread guard         : block only a genuinely wide spread (fail-open on the
//                          .DWX zero-modeled-spread tester).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11629;
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
input int    strategy_rsi_period         = 14;    // RSI lookback period
input double strategy_rsi_entry_level     = 60.0;  // long trigger: RSI crosses DOWN through this
input double strategy_rsi_exit_level      = 70.0;  // close long when RSI >= this
input int    strategy_atr_period          = 14;    // ATR period for the catastrophic stop
input double strategy_sl_atr_mult         = 2.0;   // catastrophic stop distance = mult * ATR
input double strategy_spread_pct_of_stop  = 15.0;  // block if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cadence state: broker calendar day of the last NEW entry.
// "One new action per calendar day" — strategy throttle, not a new-bar gate.
// -----------------------------------------------------------------------------
int g_last_entry_yday = -1;   // day-of-year of last entry (broker time)
int g_last_entry_year = -1;   // year of last entry (broker time)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; entry logic is on the closed-bar
// path inside Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Cadence STATE: at most one new entry per broker calendar day. ---
   const datetime bar_time = iTime(_Symbol, _Period, 0); // current bar open (broker time)
   MqlDateTime bt;
   TimeToStruct(bar_time, bt);
   if(bt.year == g_last_entry_year && bt.day_of_year == g_last_entry_yday)
      return false;

   // --- Trigger EVENT: RSI crosses DOWN through the entry level. ---
   // rsi_prev at shift 2, rsi_now at shift 1: a fresh downward cross into the
   // <= entry_level mean-reversion zone. ONE event per bar; the RSI>=exit_level
   // close is a STATE, so we never require two cross events on the same bar.
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;
   const bool crossed_down = (rsi_prev >  strategy_rsi_entry_level &&
                              rsi_now  <= strategy_rsi_entry_level);
   if(!crossed_down)
      return false;

   // --- ATR catastrophic stop (V5 add). No TP: RSI>=exit_level exits. ---
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
   req.tp     = 0.0;   // no fixed TP; RSI>=exit_level is the profit exit
   req.reason = "cat_rsi6070_long";

   // Record the cadence day for this new entry.
   g_last_entry_year = bt.year;
   g_last_entry_yday = bt.day_of_year;
   return true;
  }

// No active trade management beyond the fixed ATR catastrophic stop. The
// profit exit (RSI>=exit_level) lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Profit/mean-reversion exit: close the long when RSI >= exit level (STATE).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

   return (rsi_now >= strategy_rsi_exit_level);
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
