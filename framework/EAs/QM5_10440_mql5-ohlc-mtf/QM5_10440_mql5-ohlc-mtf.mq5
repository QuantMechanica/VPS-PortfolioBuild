#property strict
#property version   "5.0"
#property description "QM5_10440 MQL5 OHLC multi-timeframe structure breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10440;
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

bool Strategy_LongRoleReversal(const double level, double &rr_low)
  {
   rr_low = DBL_MAX;
   const int bars = MathMax(1, strategy_role_reversal_bars);
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double low = iLow(_Symbol, PERIOD_H1, shift);
      const double close = iClose(_Symbol, PERIOD_H1, shift);
      if(low <= 0.0 || close <= 0.0)
         return false;
      if(low <= level && close > level)
         rr_low = MathMin(rr_low, low);
     }
   return (rr_low < DBL_MAX);
  }

bool Strategy_ShortRoleReversal(const double level, double &rr_high)
  {
   rr_high = -DBL_MAX;
   const int bars = MathMax(1, strategy_role_reversal_bars);
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_H1, shift);
      const double close = iClose(_Symbol, PERIOD_H1, shift);
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

   const double h1_high = iHigh(_Symbol, PERIOD_H1, 1);
   const double h1_low = iLow(_Symbol, PERIOD_H1, 1);
   const double h4_high = iHigh(_Symbol, PERIOD_H4, 1);
   const double h4_low = iLow(_Symbol, PERIOD_H4, 1);
   const double m5_close = iClose(_Symbol, PERIOD_M5, 1);
   const double m30_close = iClose(_Symbol, PERIOD_M30, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(h1_high <= 0.0 || h1_low <= 0.0 || h4_high <= 0.0 || h4_low <= 0.0 ||
      m5_close <= 0.0 || m30_close <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   const bool bullish_structure = (h1_high > h4_high && h1_low > h4_low);
   const bool bearish_structure = (h1_low < h4_low && h1_high < h4_high);

   if(Strategy_HasOurPendingStop())
     {
      const bool opposite_for_pending = (bullish_structure && (m5_close > h4_high || m30_close > h4_high)) ||
                                        (bearish_structure && (m5_close < h4_low || m30_close < h4_low));
      if(opposite_for_pending)
         Strategy_CancelOurPendingStops("opposite_structure");
      return false;
     }

   const double offset = atr * strategy_entry_atr_offset_mult;
   const double min_stop = atr * strategy_stop_min_atr_mult;
   const double max_stop = atr * strategy_stop_max_atr_mult;
   const double stop_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(offset <= 0.0 || min_stop <= 0.0 || max_stop <= 0.0)
      return false;

   if(bullish_structure && (m5_close > h4_high || m30_close > h4_high))
     {
      double rr_low = 0.0;
      if(!Strategy_LongRoleReversal(h4_high, rr_low))
         return false;

      const double entry = h4_high + offset;
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0 || entry <= ask + stop_level)
         return false;

      const double structural_dist = entry - rr_low;
      if(structural_dist < min_stop)
         return false;

      const double stop_dist = MathMin(structural_dist, max_stop);
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(entry - stop_dist, _Digits);
      req.tp = NormalizeDouble(entry + stop_dist * strategy_take_profit_r, _Digits);
      req.reason = "QM5_10440_LONG_MTF_STRUCTURE";
      req.expiration_seconds = MathMax(1, strategy_pending_expiry_minutes) * 60;
      return true;
     }

   if(bearish_structure && (m5_close < h4_low || m30_close < h4_low))
     {
      double rr_high = 0.0;
      if(!Strategy_ShortRoleReversal(h4_low, rr_high))
         return false;

      const double entry = h4_low - offset;
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || entry >= bid - stop_level)
         return false;

      const double structural_dist = rr_high - entry;
      if(structural_dist < min_stop)
         return false;

      const double stop_dist = MathMin(structural_dist, max_stop);
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(entry + stop_dist, _Digits);
      req.tp = NormalizeDouble(entry - stop_dist * strategy_take_profit_r, _Digits);
      req.reason = "QM5_10440_SHORT_MTF_STRUCTURE";
      req.expiration_seconds = MathMax(1, strategy_pending_expiry_minutes) * 60;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10440_mql5-ohlc-mtf\"}");
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
