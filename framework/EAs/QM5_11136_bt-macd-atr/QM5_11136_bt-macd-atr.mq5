#property strict
#property version   "5.0"
#property description "QM5_11136 bt-macd-atr — MACD-cross reversal + ATR trailing stop (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11136 bt-macd-atr
// -----------------------------------------------------------------------------
// Source: Daniel Rodriguez / backtrader, samples/macd-settings/macd-settings.py
//   https://github.com/mementum/backtrader/blob/master/samples/macd-settings/macd-settings.py
// Card: artifacts/cards_approved/QM5_11136_bt-macd-atr.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads; D1 baseline):
//   Trigger EVENT : MACD main line crosses ABOVE the MACD signal line.
//                   Evaluated as main@2 <= signal@2 AND main@1 > signal@1
//                   (one fresh cross event per bar). MACD line CAN be negative —
//                   no <=0 / sign guard; the cross is the only condition.
//   Regime STATE  : SMA(30) slope is negative, i.e. SMA@1 - SMA@(1+slope_look)
//                   < 0. A reversal entry: bullish MACD turn after a prior
//                   down-slope of the SMA.
//   Stop / exit   : ATR(14) * 3.0 trailing stop. Initialised at entry to
//                   close - mult*ATR; each closed bar it ratchets UP to
//                   max(existing_sl, close - mult*ATR) and never down. If the
//                   closed-bar close is below the current stop, close the long.
//                   The hard SL on the position also catches it intrabar.
//   No short side in this baseline.
//
// .DWX invariants honoured:
//   - No spread/swap gate (NoTradeFilter fail-OPEN; zero modeled spread/swap).
//   - MACD line may be negative — no positivity guard.
//   - Cross is the EVENT, SMA-slope is a STATE (never two same-bar events).
//   - QM_IsNewBar consumed once by the framework OnTick entry gate.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11136;
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
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 9;      // MACD signal SMA period
input int    strategy_sma_period        = 30;     // trend-slope SMA period
input int    strategy_sma_slope_look    = 10;     // bars back for SMA-slope (SMA@1 - SMA@1+look)
input int    strategy_atr_period        = 14;     // ATR period for the trailing stop
input double strategy_atr_mult          = 3.0;    // trailing-stop distance = mult * ATR

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread/swap gate on .DWX (fail-OPEN). The card
// defines no session / time / regime intraday filter, so nothing blocks here.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: MACD main crosses ABOVE signal (one fresh cross/bar) ---
   // MACD line CAN be negative — do NOT add a <=0 guard. The cross is the event.
   const double macd_main_prev   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                                 strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_prev    = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                                   strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_main_now    = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                                 strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_now     = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                                   strategy_macd_slow, strategy_macd_signal, 1);
   const bool crossed_up = (macd_main_prev <= macd_sig_prev && macd_main_now > macd_sig_now);
   if(!crossed_up)
      return false;

   // --- Regime STATE: SMA(period) slope negative (prior down move) ---
   const double sma_now  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma_back = QM_SMA(_Symbol, _Period, strategy_sma_period, 1 + strategy_sma_slope_look);
   if(sma_now <= 0.0 || sma_back <= 0.0)
      return false;
   if(!((sma_now - sma_back) < 0.0))   // SMA direction must be negative
      return false;

   // --- ATR for the initial trailing stop ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   // Initial stop = entry - mult*ATR (ratcheted up each bar by ManageOpenPosition).
   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — exit is the trailing stop
   req.reason = "macd_atr_reversal_long";
   return true;
  }

// Ratchet the trailing stop UP each closed bar to max(existing_sl, close-mult*ATR).
// Never lowers the stop. Per-tick safe: only the QM_IsNewBar-gated entry path
// produces new bars, but ratcheting here every tick is O(1) and idempotent.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return;

   const double candidate_sl = close1 - strategy_atr_mult * atr_value;
   if(candidate_sl <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double cur_sl = PositionGetDouble(POSITION_SL);
      // Ratchet up only — never lower the stop.
      if(candidate_sl > cur_sl)
         QM_TM_MoveSL(ticket, candidate_sl, "atr_trail_ratchet");
     }
  }

// Defensive bar-close exit: if the closed-bar close is below the current stop,
// close the long. The hard SL also catches it intrabar; this honours the card's
// explicit "if close is below the current stop, close the long" rule at bar close.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double cur_sl = PositionGetDouble(POSITION_SL);
      if(cur_sl > 0.0 && close1 < cur_sl)
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
