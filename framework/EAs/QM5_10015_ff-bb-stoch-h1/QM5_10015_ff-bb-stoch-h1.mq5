#property strict
#property version   "5.0"
#property description "QM5_10015 ForexFactory BB Stoch H1 reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10015;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H1;
input int    strategy_bb_period         = 20;
input double strategy_bb_deviation      = 2.0;
input int    strategy_stoch_k           = 14;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input int    strategy_fx_sl_pips        = 50;
input int    strategy_fx_tp_pips        = 50;
input int    strategy_trail_trigger_pips = 20;
input int    strategy_trail_step_pips   = 15;
input int    strategy_xau_atr_period    = 14;
input double strategy_xau_atr_mult      = 1.0;
input double strategy_max_spread_stop_fraction = 0.10;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_bb_period <= 0 || strategy_bb_deviation <= 0.0 ||
      strategy_stoch_k <= 0 || strategy_stoch_d <= 0 || strategy_stoch_slowing <= 0)
      return false;

   const double open1 = iOpen(_Symbol, strategy_tf, 1);
   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double low2 = iLow(_Symbol, strategy_tf, 2);
   const double high2 = iHigh(_Symbol, strategy_tf, 2);
   const double close2 = iClose(_Symbol, strategy_tf, 2);
   if(open1 <= 0.0 || close1 <= 0.0 || low2 <= 0.0 || high2 <= 0.0 || close2 <= 0.0)
      return false;

   const double lower2 = QM_BB_Lower(_Symbol, strategy_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double upper2 = QM_BB_Upper(_Symbol, strategy_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double stoch_k1 = QM_Stoch_K(_Symbol, strategy_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d1 = QM_Stoch_D(_Symbol, strategy_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   if(lower2 <= 0.0 || upper2 <= 0.0 || stoch_k1 == EMPTY_VALUE || stoch_d1 == EMPTY_VALUE)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const bool is_xau = (StringFind(_Symbol, "XAUUSD") >= 0);
   const bool long_setup = ((close2 < lower2) || (low2 < lower2 && close2 > lower2)) &&
                           close1 > open1 &&
                           stoch_k1 > stoch_d1 &&
                           stoch_k1 < 80.0;
   const bool short_setup = ((close2 > upper2) || (high2 > upper2 && close2 < upper2)) &&
                            close1 < open1 &&
                            stoch_k1 < stoch_d1 &&
                            stoch_k1 > 20.0;

   if(!long_setup && !short_setup)
      return false;

   req.type = long_setup ? QM_BUY : QM_SELL;
   const double entry = long_setup ? ask : bid;
   req.price = 0.0;

   if(is_xau)
     {
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_xau_atr_period, strategy_xau_atr_mult);
      req.tp = QM_TakeATR(_Symbol, req.type, entry, strategy_xau_atr_period, strategy_xau_atr_mult);
     }
   else
     {
      req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_fx_sl_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, entry, strategy_fx_tp_pips);
     }

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - req.sl);
   const double spread_distance = ask - bid;
   if(stop_distance <= 0.0 || spread_distance <= 0.0 ||
      spread_distance > stop_distance * strategy_max_spread_stop_fraction)
      return false;

   req.reason = long_setup ? "QM5_10015_LONG_BB_STOCH" : "QM5_10015_SHORT_BB_STOCH";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_TrailStep(ticket, strategy_trail_trigger_pips, strategy_trail_step_pips);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   bool have_buy = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_position = true;
      have_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }

   if(!have_position)
      return false;

   const double open1 = iOpen(_Symbol, strategy_tf, 1);
   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double low2 = iLow(_Symbol, strategy_tf, 2);
   const double high2 = iHigh(_Symbol, strategy_tf, 2);
   const double close2 = iClose(_Symbol, strategy_tf, 2);
   if(open1 <= 0.0 || close1 <= 0.0 || low2 <= 0.0 || high2 <= 0.0 || close2 <= 0.0)
      return false;

   const double lower2 = QM_BB_Lower(_Symbol, strategy_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double upper2 = QM_BB_Upper(_Symbol, strategy_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double stoch_k1 = QM_Stoch_K(_Symbol, strategy_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d1 = QM_Stoch_D(_Symbol, strategy_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   if(lower2 <= 0.0 || upper2 <= 0.0 || stoch_k1 == EMPTY_VALUE || stoch_d1 == EMPTY_VALUE)
      return false;

   const bool long_signal = ((close2 < lower2) || (low2 < lower2 && close2 > lower2)) &&
                            close1 > open1 &&
                            stoch_k1 > stoch_d1 &&
                            stoch_k1 < 80.0;
   const bool short_signal = ((close2 > upper2) || (high2 > upper2 && close2 < upper2)) &&
                             close1 < open1 &&
                             stoch_k1 < stoch_d1 &&
                             stoch_k1 > 20.0;

   if(have_buy && short_signal)
      return true;
   if(!have_buy && long_signal)
      return true;
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
