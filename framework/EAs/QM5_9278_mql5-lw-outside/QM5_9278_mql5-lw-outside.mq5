#property strict
#property version   "5.0"
#property description "QM5_9278 Larry Williams bearish outside-bar D1 reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9278;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_D1;
input double strategy_entry_factor       = 0.50;
input double strategy_stop_factor        = 0.50;
input double strategy_take_profit_r      = 3.0;
input int    strategy_max_hold_bars      = 5;
input int    strategy_pending_expiration_bars = 1;
input int    strategy_max_spread_points  = 0;
input bool   strategy_trade_monday       = true;
input bool   strategy_trade_tuesday      = true;
input bool   strategy_trade_wednesday    = true;
input bool   strategy_trade_thursday     = true;
input bool   strategy_trade_friday       = true;

bool Strategy_IsPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP);
  }

int Strategy_PeriodSeconds()
  {
   const int seconds = PeriodSeconds(strategy_timeframe);
   return (seconds > 0) ? seconds : 86400;
  }

bool Strategy_DayAllowed(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.day_of_week == 1)
      return strategy_trade_monday;
   if(dt.day_of_week == 2)
      return strategy_trade_tuesday;
   if(dt.day_of_week == 3)
      return strategy_trade_wednesday;
   if(dt.day_of_week == 4)
      return strategy_trade_thursday;
   if(dt.day_of_week == 5)
      return strategy_trade_friday;
   return false;
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

bool Strategy_HasOurPendingOrder()
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
      if(Strategy_IsPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_RemoveOurPendingOrders(const string reason)
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
      if(!Strategy_IsPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_RemoveExpiredPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int expiry_seconds = MathMax(1, strategy_pending_expiration_bars) * Strategy_PeriodSeconds();
   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= expiry_seconds)
         QM_TM_RemovePendingOrder(ticket, "lw_outside_pending_expired");
     }
  }

bool Strategy_PositionTimeStopDue()
  {
   if(strategy_max_hold_bars <= 0)
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   if(open_time <= 0)
      return false;

   const int bars_held = iBarShift(_Symbol, strategy_timeframe, open_time, false);
   return (bars_held >= strategy_max_hold_bars);
  }

bool Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No Trade Filter: fail-open spread guard for .DWX zero-spread tester quotes.
bool Strategy_NoTradeFilter()
  {
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points);
  }

// Trade Entry: D1 bearish outside-bar panic fade with next-day volatility trigger.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   Strategy_RemoveOurPendingOrders("lw_outside_new_d1_bar_refresh");

   if(strategy_timeframe != PERIOD_D1)
      return false;
   if(!Strategy_DayAllowed(TimeCurrent()))
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_HasOurPendingOrder())
      return false;
   if(strategy_entry_factor <= 0.0 || strategy_stop_factor <= 0.0 || strategy_take_profit_r <= 0.0)
      return false;

   const double open_0  = iOpen(_Symbol, strategy_timeframe, 0);   // perf-allowed: D1 OHLC structural setup, called only after QM_IsNewBar(_Symbol, PERIOD_D1).
   const double high_1  = iHigh(_Symbol, strategy_timeframe, 1);   // perf-allowed: D1 OHLC structural setup, called only after QM_IsNewBar(_Symbol, PERIOD_D1).
   const double low_1   = iLow(_Symbol, strategy_timeframe, 1);    // perf-allowed: D1 OHLC structural setup, called only after QM_IsNewBar(_Symbol, PERIOD_D1).
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);  // perf-allowed: D1 OHLC structural setup, called only after QM_IsNewBar(_Symbol, PERIOD_D1).
   const double high_2  = iHigh(_Symbol, strategy_timeframe, 2);   // perf-allowed: D1 OHLC structural setup, called only after QM_IsNewBar(_Symbol, PERIOD_D1).
   const double low_2   = iLow(_Symbol, strategy_timeframe, 2);    // perf-allowed: D1 OHLC structural setup, called only after QM_IsNewBar(_Symbol, PERIOD_D1).
   if(open_0 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || close_1 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0)
      return false;
   if(!(high_1 > high_2 && low_1 < low_2 && close_1 < low_2))
      return false;

   const double working_range = high_1 - low_1;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(working_range <= 0.0 || point <= 0.0)
      return false;

   const double trigger = QM_StopRulesNormalizePrice(_Symbol, open_0 + strategy_entry_factor * working_range);
   const double stop_distance = strategy_stop_factor * working_range;
   if(trigger <= 0.0 || stop_distance <= point)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.type = (ask >= trigger) ? QM_BUY : QM_BUY_STOP;
   req.price = (req.type == QM_BUY) ? 0.0 : trigger;

   const double entry_price = (req.type == QM_BUY) ? ask : trigger;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, entry_price - stop_distance);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, entry_price + strategy_take_profit_r * stop_distance);
   req.reason = "LW_OUTSIDE_D1_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = (req.type == QM_BUY_STOP)
                             ? MathMax(3600, MathMax(1, strategy_pending_expiration_bars) * Strategy_PeriodSeconds())
                             : 0;

   return (req.sl > 0.0 && req.tp > 0.0 && req.sl < entry_price && req.tp > entry_price);
  }

// Trade Management: cancel stale pending triggers; position risk lives on server SL/TP.
void Strategy_ManageOpenPosition()
  {
   Strategy_RemoveExpiredPendingOrders();
  }

// Trade Close: hard fail-safe after the configured number of completed D1 bars.
bool Strategy_ExitSignal()
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
      if(Strategy_PositionTimeStopDue())
         return true;
     }
   return false;
  }

// News Filter Hook: no card-specific override beyond the central framework axes.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9278\",\"ea\":\"mql5-lw-outside\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
