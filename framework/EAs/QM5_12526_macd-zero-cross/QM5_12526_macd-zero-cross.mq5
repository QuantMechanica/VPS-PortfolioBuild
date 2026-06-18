#property strict
#property version   "5.0"
#property description "QM5_12526 macd-zero-cross — MACD line zero-cross trend (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12526 macd-zero-cross
// -----------------------------------------------------------------------------
// Source: Backtest Rookies "Backtrader MACD Indicator Review" (2017-10-03),
//   "Zero Crossover" variant.
// Card: artifacts/cards_approved/QM5_12526_macd-zero-cross.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads; MACD MAIN line only — signal line unused):
//   Entry EVENT (long) : MACD main crosses ABOVE zero (main@2 <= 0 < main@1).
//   Entry EVENT (short): MACD main crosses BELOW zero (main@2 >= 0 > main@1).
//   Exit  EVENT (long) : MACD main crosses below zero -> close manually.
//   Exit  EVENT (short): MACD main crosses above zero -> close manually.
//   Protective stop    : entry -/+ sl_atr_mult * ATR(atr_period) catastrophic
//                        backstop; the primary close is the opposite zero cross.
//   Take profit        : none — the strategy is exit-on-opposite-cross.
//
// Two-cross trap note: entry and exit are OPPOSITE-direction events on the
// MACD main line, never both true on one bar. Entry is the single trigger
// EVENT; no second concurrent event is required (avoids the zero-trade trap).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12526;
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
input int    strategy_macd_fast_period   = 12;    // MACD fast EMA
input int    strategy_macd_slow_period   = 26;    // MACD slow EMA
input int    strategy_macd_signal_period = 9;     // MACD signal EMA (unused for decisions)
input int    strategy_atr_period         = 14;    // ATR period for protective stop
input double strategy_sl_atr_mult        = 3.0;   // catastrophic stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
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

// Entry on MACD main zero-cross. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // MACD main line on the two most-recent CLOSED bars.
   const double macd_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 2);

   // Single trigger EVENT: a fresh zero-line cross on the last closed bar.
   const bool crossed_up   = (macd_prev <= 0.0 && macd_now > 0.0);
   const bool crossed_down = (macd_prev >= 0.0 && macd_now < 0.0);
   if(!crossed_up && !crossed_down)
      return false;

   const QM_OrderType dir = crossed_up ? QM_BUY : QM_SELL;

   const double entry = (dir == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Protective catastrophic stop only; no take profit (exit = opposite cross).
   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — opposite zero cross closes the trade
   req.reason = crossed_up ? "macd_zero_cross_long" : "macd_zero_cross_short";
   return true;
  }

// No active management beyond the fixed ATR backstop. Primary close is the
// opposite zero cross handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit on opposite MACD main zero-cross. A long closes when main crosses below
// zero; a short closes when main crosses above zero. One event per bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double macd_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 2);

   const bool crossed_up   = (macd_prev <= 0.0 && macd_now > 0.0);
   const bool crossed_down = (macd_prev >= 0.0 && macd_now < 0.0);
   if(!crossed_up && !crossed_down)
      return false;

   // Determine open direction; close only on the opposite-direction cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && crossed_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && crossed_up)
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
