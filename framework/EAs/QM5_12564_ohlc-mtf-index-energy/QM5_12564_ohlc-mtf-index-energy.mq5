#property strict
#property version   "5.0"
#property description "QM5_12564 ohlc-mtf-index-energy — port of QM5_10440_mql5-ohlc-mtf"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12564;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period              = 14;
input double strategy_entry_atr_offset_mult   = 0.10;
input double strategy_stop_min_atr_mult       = 0.50;
input double strategy_stop_max_atr_mult       = 2.50;
input double strategy_take_profit_r           = 2.00;
input int    strategy_role_reversal_bars      = 3;
input int    strategy_pending_expiry_minutes  = 240;
input int    strategy_day_blackout_minutes    = 30;
input int    strategy_time_exit_h1_bars       = 40;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_MinutesOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasOurPendingStop()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

// Checks whether the prior resistance level at `level` was retested as support
// within the last `strategy_role_reversal_bars` H1 bars.
// Sets rr_low = the lowest low of bars that wicked below `level` but closed above it.
bool Strategy_LongRoleReversal(const double level, double &rr_low)
  {
   rr_low = DBL_MAX;
   const int bars = MathMax(1, strategy_role_reversal_bars);
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double low   = iLow(_Symbol, PERIOD_H1, shift);    // perf-allowed — bespoke structural role-reversal scan, per-bar O(role_reversal_bars) max 3 bars, gated by QM_IsNewBar
      const double close = iClose(_Symbol, PERIOD_H1, shift);  // perf-allowed — bespoke structural role-reversal scan, gated by QM_IsNewBar
      if(low <= 0.0 || close <= 0.0)
         return false;
      if(low <= level && close > level)
         rr_low = MathMin(rr_low, low);
     }
   return (rr_low < DBL_MAX);
  }

// Checks whether the prior support level at `level` was retested as resistance
// within the last `strategy_role_reversal_bars` H1 bars.
bool Strategy_ShortRoleReversal(const double level, double &rr_high)
  {
   rr_high = -DBL_MAX;
   const int bars = MathMax(1, strategy_role_reversal_bars);
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double high  = iHigh(_Symbol, PERIOD_H1, shift);   // perf-allowed — bespoke structural role-reversal scan, per-bar O(role_reversal_bars) max 3 bars, gated by QM_IsNewBar
      const double close = iClose(_Symbol, PERIOD_H1, shift);  // perf-allowed — bespoke structural role-reversal scan, gated by QM_IsNewBar
      if(high <= 0.0 || close <= 0.0)
         return false;
      if(high >= level && close < level)
         rr_high = MathMax(rr_high, high);
     }
   return (rr_high > -DBL_MAX);
  }

bool Strategy_NoTradeFilter()
  {
   const int minute = Strategy_MinutesOfDay(TimeCurrent());
   const int blackout = MathMax(0, strategy_day_blackout_minutes);
   if(blackout > 0 && (minute < blackout || minute >= 1440 - blackout))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(Strategy_HasOurOpenPosition())
      return false;

   // Read prior closed bars from multiple timeframes for structure analysis.
   // Shift=1 reads the last fully-closed bar; all reads are inside QM_IsNewBar gate.
   const double h1_high   = iHigh(_Symbol,  PERIOD_H1,  1);    // perf-allowed — bespoke MTF structural read, shift=1 closed bar, gated by QM_IsNewBar in OnTick
   const double h1_low    = iLow(_Symbol,   PERIOD_H1,  1);    // perf-allowed — bespoke MTF structural read, shift=1 closed bar, gated by QM_IsNewBar in OnTick
   const double h4_high   = iHigh(_Symbol,  PERIOD_H4,  1);    // perf-allowed — bespoke MTF structural read, shift=1 closed bar, gated by QM_IsNewBar in OnTick
   const double h4_low    = iLow(_Symbol,   PERIOD_H4,  1);    // perf-allowed — bespoke MTF structural read, shift=1 closed bar, gated by QM_IsNewBar in OnTick
   const double m5_close  = iClose(_Symbol, PERIOD_M5,  1);    // perf-allowed — bespoke MTF structural read, shift=1 closed bar, gated by QM_IsNewBar in OnTick
   const double m30_close = iClose(_Symbol, PERIOD_M30, 1);    // perf-allowed — bespoke MTF structural read, shift=1 closed bar, gated by QM_IsNewBar in OnTick
   const double atr       = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(h1_high <= 0.0 || h1_low <= 0.0 || h4_high <= 0.0 || h4_low <= 0.0 ||
      m5_close <= 0.0 || m30_close <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   // MTF structure: H1 range is inside an H4 breakout direction
   const bool bullish_structure = (h1_high > h4_high && h1_low > h4_low);
   const bool bearish_structure = (h1_low  < h4_low  && h1_high < h4_high);

   // If a pending stop already exists, check whether to cancel it
   if(Strategy_HasOurPendingStop())
     {
      const bool cancel_long  = bearish_structure && (m5_close < h4_low  || m30_close < h4_low);
      const bool cancel_short = bullish_structure && (m5_close > h4_high || m30_close > h4_high);
      if(cancel_long || cancel_short)
         Strategy_CancelOurPendingStops("opposite_structure");
      return false;
     }

   const double offset    = atr * strategy_entry_atr_offset_mult;
   const double min_stop  = atr * strategy_stop_min_atr_mult;
   const double max_stop  = atr * strategy_stop_max_atr_mult;
   const double stop_dist_min = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   if(offset <= 0.0 || min_stop <= 0.0 || max_stop <= 0.0)
      return false;

   // LONG: M5 or M30 close breaks above H4 high in a bullish-structure bar
   if(bullish_structure && (m5_close > h4_high || m30_close > h4_high))
     {
      double rr_low = 0.0;
      if(!Strategy_LongRoleReversal(h4_high, rr_low))
         return false;

      const double entry = h4_high + offset;
      const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0 || entry <= ask + stop_dist_min)
         return false;

      const double structural_dist = entry - rr_low;
      if(structural_dist < min_stop)
         return false;

      const double stop_dist = MathMin(structural_dist, max_stop);
      req.type               = QM_BUY_STOP;
      req.price              = NormalizeDouble(entry,                             _Digits);
      req.sl                 = NormalizeDouble(entry - stop_dist,                 _Digits);
      req.tp                 = NormalizeDouble(entry + stop_dist * strategy_take_profit_r, _Digits);
      req.reason             = "MTF_OHLC_LONG_STRUCTURE";
      req.expiration_seconds = MathMax(1, strategy_pending_expiry_minutes) * 60;
      return true;
     }

   // SHORT: M5 or M30 close breaks below H4 low in a bearish-structure bar
   if(bearish_structure && (m5_close < h4_low || m30_close < h4_low))
     {
      double rr_high = 0.0;
      if(!Strategy_ShortRoleReversal(h4_low, rr_high))
         return false;

      const double entry = h4_low - offset;
      const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || entry >= bid - stop_dist_min)
         return false;

      const double structural_dist = rr_high - entry;
      if(structural_dist < min_stop)
         return false;

      const double stop_dist = MathMin(structural_dist, max_stop);
      req.type               = QM_SELL_STOP;
      req.price              = NormalizeDouble(entry,                             _Digits);
      req.sl                 = NormalizeDouble(entry + stop_dist,                 _Digits);
      req.tp                 = NormalizeDouble(entry - stop_dist * strategy_take_profit_r, _Digits);
      req.reason             = "MTF_OHLC_SHORT_STRUCTURE";
      req.expiration_seconds = MathMax(1, strategy_pending_expiry_minutes) * 60;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing stop on this strategy (exit is TP, SL, or time exit via ExitSignal).
  }

bool Strategy_ExitSignal()
  {
   // Time exit: close after strategy_time_exit_h1_bars H1 bars have elapsed since open.
   const int max_bars = MathMax(1, strategy_time_exit_h1_bars);
   const int magic    = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time   = (datetime)PositionGetInteger(POSITION_TIME);
      const datetime broker_now  = TimeCurrent();
      const int bars_elapsed     = (int)((broker_now - open_time) / (PeriodSeconds(PERIOD_H1)));
      if(bars_elapsed >= max_bars)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12564_ohlc-mtf-index-energy\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
