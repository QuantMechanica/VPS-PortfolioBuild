#property strict
#property version   "5.0"
#property description "QM5_12846 Euro Night MR EURUSD H1"

#include <QM/QM_Common.mqh>

enum QM12846_TakeProfitMode
  {
   QM12846_TP_FIXED_ATR = 0,
   QM12846_TP_FIXED_PCT = 1
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12846;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_bars       = 20;
input double strategy_atr_mult            = 2.0;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 2.0;
input QM12846_TakeProfitMode strategy_tp_mode = QM12846_TP_FIXED_ATR;
input double strategy_tp_atr_mult         = 1.5;
input double strategy_tp_fixed_pct        = 0.20;
input int    strategy_entry_start_hour    = 0;
input int    strategy_entry_end_hour      = 7;
input int    strategy_exit_hour           = 13;

int QM12846_ClampHour(const int hour_value)
  {
   if(hour_value < 0)
      return 0;
   if(hour_value > 23)
      return 23;
   return hour_value;
  }

int QM12846_BrokerHour(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour;
  }

datetime QM12846_TimeAtBrokerHour(const datetime broker_time, const int raw_hour)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   dt.hour = QM12846_ClampHour(raw_hour);
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool QM12846_HourInWindow(const datetime broker_time, const int raw_start_hour, const int raw_end_hour)
  {
   const int start_hour = QM12846_ClampHour(raw_start_hour);
   const int end_hour = QM12846_ClampHour(raw_end_hour);
   const int hour_now = QM12846_BrokerHour(broker_time);

   if(start_hour == end_hour)
      return false;
   if(start_hour < end_hour)
      return (hour_now >= start_hour && hour_now < end_hour);
   return (hour_now >= start_hour || hour_now < end_hour);
  }

bool QM12846_ExitWindowElapsed(const datetime broker_time)
  {
   const int start_hour = QM12846_ClampHour(strategy_entry_start_hour);
   const int exit_hour = QM12846_ClampHour(strategy_exit_hour);
   const int hour_now = QM12846_BrokerHour(broker_time);

   if(start_hour <= exit_hour)
      return (hour_now >= exit_hour);
   return (hour_now >= exit_hour && hour_now < start_hour);
  }

int QM12846_SecondsUntilEntryEnd(const datetime broker_time)
  {
   datetime end_time = QM12846_TimeAtBrokerHour(broker_time, strategy_entry_end_hour);
   if(end_time <= broker_time)
      end_time += 86400;

   int seconds_left = (int)(end_time - broker_time);
   if(seconds_left < 60)
      seconds_left = 60;
   return seconds_left;
  }

bool QM12846_HasOurOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }

   return false;
  }

bool QM12846_HasOurPendingOrder()
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

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }

   return false;
  }

void QM12846_CancelPendingOrders(const string reason)
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

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_LIMIT && order_type != ORDER_TYPE_SELL_LIMIT)
         continue;

      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool QM12846_AverageHighLow(const int bars, double &avg_high, double &avg_low)
  {
   avg_high = 0.0;
   avg_low = 0.0;
   if(bars < 2)
      return false;

   double high_sum = 0.0;
   double low_sum = 0.0;
   int samples = 0;

   // perf-allowed: card requires bounded H1 rolling high/low means; this runs only once per new bar.
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double bar_high = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded card-required H1 rolling mean.
      const double bar_low = iLow(_Symbol, _Period, shift);   // perf-allowed: bounded card-required H1 rolling mean.
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high < bar_low)
         return false;

      high_sum += bar_high;
      low_sum += bar_low;
      samples++;
     }

   if(samples != bars)
      return false;

   avg_high = high_sum / samples;
   avg_low = low_sum / samples;
   return (avg_high > 0.0 && avg_low > 0.0 && avg_high > avg_low);
  }

bool QM12846_BuildRequest(const QM_OrderType side,
                          const double entry_price,
                          const double atr_value,
                          QM_EntryRequest &req)
  {
   if(entry_price <= 0.0 || atr_value <= 0.0)
      return false;

   const double sl_price = QM_StopATRFromValue(_Symbol, side, entry_price, atr_value, strategy_sl_atr_mult);
   double tp_price = 0.0;
   if(strategy_tp_mode == QM12846_TP_FIXED_PCT)
     {
      const double pct_distance = entry_price * strategy_tp_fixed_pct / 100.0;
      tp_price = QM_StopRulesTakeFromDistance(_Symbol, side, entry_price, pct_distance);
     }
   else
     {
      tp_price = QM_TakeATRFromValue(_Symbol, side, entry_price, atr_value, strategy_tp_atr_mult);
     }

   if(sl_price <= 0.0 || tp_price <= 0.0)
      return false;

   req.type = side;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry_price);
   req.sl = sl_price;
   req.tp = tp_price;
   req.reason = (side == QM_BUY_LIMIT) ? "EURO_NIGHT_BUY_LIMIT" : "EURO_NIGHT_SELL_LIMIT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = QM12846_SecondsUntilEntryEnd(TimeCurrent());
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!QM12846_HourInWindow(broker_now, strategy_entry_start_hour, strategy_entry_end_hour))
      return false;
   if(QM12846_ExitWindowElapsed(broker_now))
      return false;
   if(QM12846_HasOurOpenPosition() || QM12846_HasOurPendingOrder())
      return false;
   if(strategy_lookback_bars < 2 || strategy_atr_period < 1 || strategy_atr_mult <= 0.0 ||
      strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
      return false;

   double avg_high = 0.0;
   double avg_low = 0.0;
   if(!QM12846_AverageHighLow(strategy_lookback_bars, avg_high, avg_low))
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double buy_limit = avg_high - (strategy_atr_mult * atr_value);
   const double sell_limit = avg_low + (strategy_atr_mult * atr_value);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const bool buy_valid = (buy_limit > 0.0 && buy_limit < bid);
   const bool sell_valid = (sell_limit > 0.0 && sell_limit > ask);
   if(!buy_valid && !sell_valid)
      return false;

   const double midpoint = (avg_high + avg_low) * 0.5;
   const double reference_price = (bid + ask) * 0.5;

   if(buy_valid && sell_valid)
     {
      if(reference_price >= midpoint)
         return QM12846_BuildRequest(QM_SELL_LIMIT, sell_limit, atr_value, req);
      return QM12846_BuildRequest(QM_BUY_LIMIT, buy_limit, atr_value, req);
     }

   if(buy_valid)
      return QM12846_BuildRequest(QM_BUY_LIMIT, buy_limit, atr_value, req);
   return QM12846_BuildRequest(QM_SELL_LIMIT, sell_limit, atr_value, req);
  }

void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   if(!QM12846_HourInWindow(broker_now, strategy_entry_start_hour, strategy_entry_end_hour) ||
      QM12846_ExitWindowElapsed(broker_now))
      QM12846_CancelPendingOrders("euro_night_session_closed");
  }

bool Strategy_ExitSignal()
  {
   if(!QM12846_HasOurOpenPosition())
      return false;

   if(QM12846_ExitWindowElapsed(TimeCurrent()))
     {
      QM12846_CancelPendingOrders("euro_night_time_exit");
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12846_euro-night-mr-eurusd\"}");
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
