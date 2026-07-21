#property strict
#property version   "5.0"
#property description "QM5_10001 ForexFactory Static Fib Open Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10001;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
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
input int    strategy_tokyo_open_hour_broker = 0;
input int    strategy_tokyo_open_minute      = 0;
input int    strategy_time_stop_hour_broker  = 20;
input int    strategy_entry_offset_pips      = 34;
input int    strategy_tp1_offset_pips        = 89;
input int    strategy_runner_offset_pips     = 144;
input bool   strategy_use_runner_target      = false;
input int    strategy_sma_period_h1          = 70;
input int    strategy_rsi_period_h1          = 21;
input int    strategy_stoch_k_m15            = 15;
input int    strategy_stoch_d_m15            = 3;
input int    strategy_stoch_slow_m15         = 3;
input double strategy_stoch_long_min         = 60.0;
input double strategy_stoch_short_max        = 30.0;
input int    strategy_atr_period_m15         = 14;
input double strategy_min_entry_atr_mult     = 0.4;
input double strategy_max_entry_atr_mult     = 2.5;
input int    strategy_be_trigger_pips        = 20;
input int    strategy_be_buffer_pips         = 3;
input int    strategy_max_spread_points      = 35;
input int    strategy_news_blackout_minutes  = 15;

datetime g_custom_news_cache_bucket = 0;
bool     g_custom_news_cache_blocked = false;

datetime Strategy_TimeBucket(const datetime broker_time)
  {
   int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds <= 0)
      seconds = 60;

   const long epoch = (long)broker_time;
   return (datetime)(epoch - (epoch % seconds));
  }

bool IsTimeStopActive()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_time_stop_hour_broker);
  }

bool HasOurPendingStopOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }

   return false;
  }

void CancelOurPendingStopOrders()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      MqlTradeRequest request;
      ZeroMemory(request);
      request.action = TRADE_ACTION_REMOVE;
      request.order = order_ticket;

      MqlTradeResult result;
      ZeroMemory(result);
      string error_class = "";
      QM_TradeContextSend(request, result, error_class);
     }
  }

bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_entry_offset_pips <= 0 ||
      strategy_tp1_offset_pips <= strategy_entry_offset_pips ||
      strategy_runner_offset_pips <= strategy_entry_offset_pips ||
      strategy_sma_period_h1 < 1 ||
      strategy_rsi_period_h1 < 1 ||
      strategy_stoch_k_m15 < 1 ||
      strategy_stoch_d_m15 < 1 ||
      strategy_stoch_slow_m15 < 1 ||
      strategy_atr_period_m15 < 1 ||
      strategy_min_entry_atr_mult <= 0.0 ||
      strategy_max_entry_atr_mult <= strategy_min_entry_atr_mult)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.hour != strategy_tokyo_open_hour_broker ||
      now_dt.min != strategy_tokyo_open_minute)
      return false;

   if(HasOurPendingStopOrder())
      return false;

   const double open_price = iOpen(_Symbol, PERIOD_M15, 0); // perf-allowed: card anchors static levels to the current Tokyo-open bar.
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed-bar bias read after QM_IsNewBar gate.
   if(open_price <= 0.0 || h1_close <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return false;

   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   const double entry_offset = (double)strategy_entry_offset_pips * pip;
   const double target_offset = (double)(strategy_use_runner_target ? strategy_runner_offset_pips : strategy_tp1_offset_pips) * pip;
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
   const double sma = QM_SMA(_Symbol, PERIOD_H1, strategy_sma_period_h1, 1, PRICE_CLOSE);
   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period_h1, 1, PRICE_CLOSE);
   const double stoch_k = QM_Stoch_K(_Symbol, PERIOD_M15, strategy_stoch_k_m15, strategy_stoch_d_m15, strategy_stoch_slow_m15, 1);
   if(atr <= 0.0 || sma <= 0.0 || rsi <= 0.0 || stoch_k <= 0.0)
      return false;

   if(entry_offset < strategy_min_entry_atr_mult * atr ||
      entry_offset > strategy_max_entry_atr_mult * atr)
      return false;

   now_dt.hour = strategy_time_stop_hour_broker;
   now_dt.min = 0;
   now_dt.sec = 0;
   const datetime expiry = StructToTime(now_dt);
   req.expiration_seconds = (expiry > TimeCurrent()) ? (int)(expiry - TimeCurrent()) : 0;

   if(h1_close > sma &&
      rsi > 50.0 &&
      stoch_k > strategy_stoch_long_min)
     {
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(open_price + entry_offset, _Digits);
      req.sl = NormalizeDouble(open_price, _Digits);
      req.tp = NormalizeDouble(open_price + target_offset, _Digits);
      req.reason = "STATIC_FIB_OPEN_LONG";
      return true;
     }

   if(h1_close < sma &&
      rsi < 50.0 &&
      stoch_k < strategy_stoch_short_max)
     {
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(open_price - entry_offset, _Digits);
      req.sl = NormalizeDouble(open_price, _Digits);
      req.tp = NormalizeDouble(open_price - target_offset, _Digits);
      req.reason = "STATIC_FIB_OPEN_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(IsTimeStopActive())
     {
      static datetime cancel_bucket = 0;
      const datetime bucket = Strategy_TimeBucket(TimeCurrent());
      if(bucket != cancel_bucket)
        {
         CancelOurPendingStopOrders();
         cancel_bucket = bucket;
        }
     }

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      CancelOurPendingStopOrders();
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, strategy_be_buffer_pips);
     }
  }

bool Strategy_ExitSignal()
  {
   return IsTimeStopActive();
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(strategy_news_blackout_minutes <= 0)
      return false;

   const datetime bucket = Strategy_TimeBucket(broker_time);
   if(bucket == g_custom_news_cache_bucket)
      return g_custom_news_cache_blocked;

   g_custom_news_cache_bucket = bucket;
   g_custom_news_cache_blocked = false;

   // FrameworkInit normally loads the calendar once because the default
   // compliance profile is active.  Do not call QM_NewsInit on every M15
   // cache miss: it clears, reparses, and reindexes the full calendar.
   if(!QM_NewsIsLoaded() &&
      !QM_NewsInit("D:\\QM\\data\\news_calendar",
                   qm_news_stale_max_hours,
                   30,
                   30,
                   qm_news_min_impact))
     {
      g_custom_news_cache_blocked = true;
      return g_custom_news_cache_blocked;
     }
   if(!QM_NewsIsAvailable())
     {
      g_custom_news_cache_blocked = true;
      return g_custom_news_cache_blocked;
     }

   datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      utc_time = TimeGMT();
   g_custom_news_cache_blocked = QM_NewsInWindow(utc_time,
                                                 _Symbol,
                                                 strategy_news_blackout_minutes,
                                                 0,
                                                 "high");
   return g_custom_news_cache_blocked;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10001_ff-static-fib-open\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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

   // This system only evaluates entries on a closed M15 bar.  Keep calendar
   // lookups below the new-bar gate so Model-4 ticks do not repeat the same
   // entry-only news work thousands of times per bar.  Position management
   // and exits above remain active throughout news windows.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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
