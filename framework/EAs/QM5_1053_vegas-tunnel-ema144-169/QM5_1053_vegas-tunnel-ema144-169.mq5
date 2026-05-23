#property strict
#property version   "5.0"
#property description "QM5_1053 Vegas Tunnel EMA144/169 Channel Breakout"

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
input int    qm_ea_id                   = 1053;
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
input int    strategy_ema_fast_period   = 144;
input int    strategy_ema_slow_period   = 169;
input int    strategy_swing_lookback    = 50;
input double strategy_fib_retrace       = 0.382;
input double strategy_tp_tunnel_mult    = 1.618;
input int    strategy_sl_buffer_points  = 20;
input int    strategy_max_spread_points = 20;
input bool   strategy_session_filter_enabled = false;
input int    strategy_session_start_hour_broker = 0;
input int    strategy_session_end_hour_broker   = 24;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   if(strategy_session_filter_enabled)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      if(strategy_session_start_hour_broker == strategy_session_end_hour_broker)
         return true;

      if(strategy_session_start_hour_broker < strategy_session_end_hour_broker)
        {
         if(dt.hour < strategy_session_start_hour_broker || dt.hour >= strategy_session_end_hour_broker)
            return true;
        }
      else
        {
         if(dt.hour < strategy_session_start_hour_broker && dt.hour >= strategy_session_end_hour_broker)
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

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_swing_lookback < 2)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double close_2 = iClose(_Symbol, _Period, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const double tunnel_high_1 = MathMax(ema_fast_1, ema_slow_1);
   const double tunnel_low_1 = MathMin(ema_fast_1, ema_slow_1);
   const double tunnel_high_2 = MathMax(ema_fast_2, ema_slow_2);
   const double tunnel_low_2 = MathMin(ema_fast_2, ema_slow_2);
   const double tunnel_width = MathAbs(ema_fast_1 - ema_slow_1);
   if(tunnel_width <= 0.0)
      return false;

   double swing_high = -DBL_MAX;
   double swing_low = DBL_MAX;
   for(int i = 1; i <= strategy_swing_lookback; ++i)
     {
      const double high_i = iHigh(_Symbol, _Period, i);
      const double low_i = iLow(_Symbol, _Period, i);
      if(high_i <= 0.0 || low_i <= 0.0)
         return false;
      swing_high = MathMax(swing_high, high_i);
      swing_low = MathMin(swing_low, low_i);
     }
   if(swing_high <= swing_low)
      return false;

   const double fib_long = swing_low + strategy_fib_retrace * (swing_high - swing_low);
   const double fib_short = swing_high - strategy_fib_retrace * (swing_high - swing_low);
   const double sl_buffer = strategy_sl_buffer_points * point;

   if(close_1 > tunnel_high_1 && close_2 <= tunnel_high_2 && close_1 > fib_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(tunnel_low_1 - sl_buffer, _Digits);
      req.tp = NormalizeDouble(entry + strategy_tp_tunnel_mult * tunnel_width, _Digits);
      req.reason = "VEGAS_TUNNEL_BREAKOUT_LONG";
      return (req.sl > 0.0 && req.sl < entry && req.tp > entry);
     }

   if(close_1 < tunnel_low_1 && close_2 >= tunnel_low_2 && close_1 < fib_short)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(tunnel_high_1 + sl_buffer, _Digits);
      req.tp = NormalizeDouble(entry - strategy_tp_tunnel_mult * tunnel_width, _Digits);
      req.reason = "VEGAS_TUNNEL_BREAKOUT_SHORT";
      return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding for P2.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_buy = false;
   bool has_sell = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         has_buy = true;
      if(ptype == POSITION_TYPE_SELL)
         has_sell = true;
     }
   if(!has_buy && !has_sell)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double close_1 = iClose(_Symbol, _Period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || close_1 <= 0.0)
      return false;

   const double tunnel_high = MathMax(ema_fast, ema_slow);
   const double tunnel_low = MathMin(ema_fast, ema_slow);
   if(close_1 < tunnel_low || close_1 > tunnel_high)
      return false;

   if(has_buy && close_1 <= tunnel_high)
      return true;
   if(has_sell && close_1 >= tunnel_low)
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
