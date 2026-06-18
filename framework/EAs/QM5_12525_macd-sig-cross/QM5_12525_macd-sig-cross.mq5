#property strict
#property version   "5.0"
#property description "QM5_12525 macd-sig-cross — MACD signal-line crossover reversal (D1, FX majors)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12525 macd-sig-cross
// -----------------------------------------------------------------------------
// Source: Backtest Rookies "Backtrader MACD Indicator Review" (2017-10-03).
// Card: artifacts/cards_approved/QM5_12525_macd-sig-cross.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; "Signal Crossover" review rule):
//   MACD main line vs its signal line, computed on completed bars.
//   Entry LONG  : MACD main crosses ABOVE the signal line (one event/bar).
//   Entry SHORT : MACD main crosses BELOW the signal line (one event/bar).
//   Exit LONG   : MACD main crosses below the signal line (opposite cross).
//   Exit SHORT  : MACD main crosses above the signal line (opposite cross).
//   The opposite-cross exit and the reverse entry are the SAME event: the
//   open position is closed in Strategy_ExitSignal, then the fresh cross fires
//   a new entry in Strategy_EntrySignal on the same closed bar (reversal).
//   Protective stop : entry -/+ sl_atr_mult * ATR(atr_period) catastrophic stop.
//   No fixed TP — the primary close is the opposite MACD signal crossover.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-open on .DWX zero modeled spread).
//
// Two-cross trap: there is exactly ONE trigger event (the main/signal cross).
// The opposite cross is a DIFFERENT-bar event that closes the prior position
// and seeds the reverse. We never require two fresh crosses on the same bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12525;
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
input int    strategy_macd_fast         = 12;    // MACD fast EMA period
input int    strategy_macd_slow         = 26;    // MACD slow EMA period
input int    strategy_macd_signal       = 9;     // MACD signal SMA period
input int    strategy_atr_period        = 14;    // ATR period for protective stop
input double strategy_sl_atr_mult       = 3.0;   // catastrophic stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal: the signed state of the MACD main-vs-signal relationship at a given
// closed-bar shift. +1 = main above signal, -1 = main below signal, 0 = equal /
// not yet available. A cross EVENT is a sign change between two adjacent shifts.
// -----------------------------------------------------------------------------
int MacdRelationAt(const int shift)
  {
   const double main_v   = QM_MACD_Main(_Symbol, _Period,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, shift);
   const double signal_v = QM_MACD_Signal(_Symbol, _Period,
                                          strategy_macd_fast, strategy_macd_slow,
                                          strategy_macd_signal, shift);
   if(main_v > signal_v)
      return 1;
   if(main_v < signal_v)
      return -1;
   return 0;
  }

// +1 = fresh bullish cross (main crossed above signal) on the last closed bar,
// -1 = fresh bearish cross, 0 = no fresh cross. Compares shift 1 vs shift 2 so
// the trigger is the single most-recently-completed bar's event.
int MacdCrossEvent()
  {
   const int now  = MacdRelationAt(1);
   const int prev = MacdRelationAt(2);
   if(now == 0 || prev == 0)
      return 0;
   if(prev <= 0 && now > 0)
      return 1;   // bullish cross
   if(prev >= 0 && now < 0)
      return -1;  // bearish cross
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work runs on the
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

// Entry on a fresh MACD signal-line cross. Long on bullish cross, short on
// bearish cross. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic. If a position is still open here, the
   // opposite-cross exit (Strategy_ExitSignal) already ran this bar and closed
   // it; a same-bar reversal then opens the new direction below.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int cross = MacdCrossEvent();
   if(cross == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(cross > 0)
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
      req.tp     = 0.0;   // no fixed TP — exit on opposite cross
      req.reason = "macd_sig_cross_long";
      return true;
     }

   // cross < 0 — short
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
   req.reason = "macd_sig_cross_short";
   return true;
  }

// No active trade management — the protective ATR stop and the opposite-cross
// close (Strategy_ExitSignal) handle the position lifecycle.
void Strategy_ManageOpenPosition()
  {
  }

// Exit when the MACD main line crosses back across its signal line against the
// open position's direction. One cross event per closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int cross = MacdCrossEvent();
   if(cross == 0)
      return false;

   // Determine the open direction for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Bearish cross closes a long; bullish cross closes a short.
   if(cross < 0 && have_long)
      return true;
   if(cross > 0 && have_short)
      return true;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
