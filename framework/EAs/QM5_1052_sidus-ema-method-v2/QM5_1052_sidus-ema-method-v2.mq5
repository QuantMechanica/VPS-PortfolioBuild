#property strict
#property version   "5.0"
#property description "QM5_1052 Sidus EMA Method v2"

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
input int    qm_ea_id                   = 1052;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_wma_fast_period   = 5;
input int    strategy_wma_slow_period   = 8;
input int    strategy_ema_fast_period   = 18;
input int    strategy_ema_slow_period   = 28;
input int    strategy_sl_buffer_points  = 20;
input bool   strategy_use_rr_take_profit = false;
input double strategy_rr_target         = 1.5;
input int    strategy_spread_cap_points = 20;
input bool   strategy_session_filter_enabled = false;
input int    strategy_session_start_hour = 7;
input int    strategy_session_end_hour   = 17;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_spread_cap_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_spread_cap_points)
         return true;
     }

   if(strategy_session_filter_enabled)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int hour = dt.hour;
      if(strategy_session_start_hour == strategy_session_end_hour)
         return false;
      if(strategy_session_start_hour < strategy_session_end_hour)
        {
         if(hour < strategy_session_start_hour || hour >= strategy_session_end_hour)
            return true;
        }
      else
        {
         if(hour < strategy_session_start_hour && hour >= strategy_session_end_hour)
            return true;
        }
     }

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

   if(strategy_wma_fast_period <= 0 || strategy_wma_slow_period <= 0 ||
      strategy_ema_fast_period <= 0 || strategy_ema_slow_period <= 0 ||
      strategy_sl_buffer_points < 0 ||
      (strategy_use_rr_take_profit && strategy_rr_target <= 0.0))
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double wma_fast_1 = QM_WMA(_Symbol, tf, strategy_wma_fast_period, 1);
   const double wma_slow_1 = QM_WMA(_Symbol, tf, strategy_wma_slow_period, 1);
   const double wma_fast_2 = QM_WMA(_Symbol, tf, strategy_wma_fast_period, 2);
   const double wma_slow_2 = QM_WMA(_Symbol, tf, strategy_wma_slow_period, 2);
   const double ema_fast_1 = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 1);
   if(wma_fast_1 <= 0.0 || wma_slow_1 <= 0.0 || wma_fast_2 <= 0.0 ||
      wma_slow_2 <= 0.0 || ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0)
      return false;

   const bool bullish_cross = (wma_fast_2 <= wma_slow_2 && wma_fast_1 > wma_slow_1);
   const bool bearish_cross = (wma_fast_2 >= wma_slow_2 && wma_fast_1 < wma_slow_1);
   const double buffer = strategy_sl_buffer_points * point;

   if(bullish_cross &&
      wma_fast_1 > ema_fast_1 && wma_fast_1 > ema_slow_1 &&
      wma_slow_1 > ema_fast_1 && wma_slow_1 > ema_slow_1 &&
      ema_fast_1 > ema_slow_1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = NormalizeDouble(ema_slow_1 - buffer, _Digits);
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = strategy_use_rr_take_profit ? QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target) : 0.0;
      req.reason = "SIDUS_LONG_WMA_CROSS_EMA_TUNNEL";
      return (!strategy_use_rr_take_profit || req.tp > entry);
     }

   if(bearish_cross &&
      wma_fast_1 < ema_fast_1 && wma_fast_1 < ema_slow_1 &&
      wma_slow_1 < ema_fast_1 && wma_slow_1 < ema_slow_1 &&
      ema_fast_1 < ema_slow_1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = NormalizeDouble(ema_slow_1 + buffer, _Digits);
      if(entry <= 0.0 || sl <= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = strategy_use_rr_take_profit ? QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target) : 0.0;
      req.reason = "SIDUS_SHORT_WMA_CROSS_EMA_TUNNEL";
      return (!strategy_use_rr_take_profit || (req.tp > 0.0 && req.tp < entry));
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double wma_fast_1 = QM_WMA(_Symbol, tf, strategy_wma_fast_period, 1);
   const double wma_slow_1 = QM_WMA(_Symbol, tf, strategy_wma_slow_period, 1);
   const double wma_fast_2 = QM_WMA(_Symbol, tf, strategy_wma_fast_period, 2);
   const double wma_slow_2 = QM_WMA(_Symbol, tf, strategy_wma_slow_period, 2);
   if(wma_fast_1 <= 0.0 || wma_slow_1 <= 0.0 || wma_fast_2 <= 0.0 || wma_slow_2 <= 0.0)
      return false;

   const bool bullish_cross = (wma_fast_2 <= wma_slow_2 && wma_fast_1 > wma_slow_1);
   const bool bearish_cross = (wma_fast_2 >= wma_slow_2 && wma_fast_1 < wma_slow_1);

   if(position_type == POSITION_TYPE_BUY && bearish_cross)
      return true;
   if(position_type == POSITION_TYPE_SELL && bullish_cross)
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
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
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
