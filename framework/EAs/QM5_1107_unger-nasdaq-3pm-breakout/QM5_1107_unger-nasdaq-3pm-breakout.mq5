#property strict
#property version   "5.0"
#property description "QM5_1107 Unger Nasdaq 3PM Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1107;
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
input int    strategy_anchor_ny_hhmm        = 1500;
input int    strategy_entry_start_ny_hhmm   = 1505;
input int    strategy_entry_end_ny_hhmm     = 1555;
input int    strategy_exit_ny_hhmm          = 200;
input double strategy_long_pct              = 0.0008;
input double strategy_short_pct             = 0.0008;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 1.25;
input bool   strategy_use_rr_take_profit    = false;
input double strategy_take_profit_rr        = 2.0;
input int    strategy_max_spread_points     = 0;

CTrade   g_trade;
int      g_session_day_key       = 0;
bool     g_anchor_ready          = false;
bool     g_orders_armed_today    = false;
bool     g_trade_taken_today     = false;
double   g_base_close            = 0.0;
datetime g_last_entry_eval_bar   = 0;

int NyUtcOffsetHours(const datetime utc)
  {
   return QM_IsUSDSTUTC(utc) ? -4 : -5;
  }

datetime BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + NyUtcOffsetHours(utc) * 3600;
  }

int HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKeyFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool IsWeekdayNY(const datetime ny_time)
  {
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

bool IsFridayNY(const datetime ny_time)
  {
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return (dt.day_of_week == 5);
  }

bool IsMondayNY(const datetime ny_time)
  {
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return (dt.day_of_week == 1);
  }

datetime NYSessionTimeToBroker(const datetime ny_now, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(ny_now, dt);
   dt.hour = hhmm / 100;
   dt.min = hhmm % 100;
   dt.sec = 0;
   const datetime ny_target = StructToTime(dt);
   const datetime utc_guess = ny_target - NyUtcOffsetHours(QM_BrokerToUTC(TimeCurrent())) * 3600;
   return QM_UTCToBroker(utc_guess);
  }

void ResetSessionIfNeeded()
  {
   const int today_key = DayKeyFromTime(BrokerToNY(TimeCurrent()));
   if(today_key == g_session_day_key)
      return;

   g_session_day_key = today_key;
   g_anchor_ready = false;
   g_orders_armed_today = false;
   g_trade_taken_today = false;
   g_base_close = 0.0;
   g_last_entry_eval_bar = 0;
  }

bool HasOurOpenPosition()
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
         return true;
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

void CancelOurPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   g_trade.SetExpertMagicNumber(magic);
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         g_trade.OrderDelete(ticket);
     }
  }

bool SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   return ((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= strategy_max_spread_points);
  }

bool CaptureAnchorFromClosedBar()
  {
   if(g_anchor_ready)
      return true;

   const datetime bar_open = iTime(_Symbol, PERIOD_M5, 1);
   if(bar_open <= 0)
      return false;

   const datetime bar_close_ny = BrokerToNY(bar_open + PeriodSeconds(PERIOD_M5));
   if(DayKeyFromTime(bar_close_ny) != g_session_day_key)
      return false;
   if(HhmmFromTime(bar_close_ny) != strategy_entry_start_ny_hhmm)
      return false;

   const double close_price = iClose(_Symbol, PERIOD_M5, 1);
   if(close_price <= 0.0)
      return false;

   g_base_close = close_price;
   g_anchor_ready = true;
   return true;
  }

bool InEntryWindowNY(const datetime ny_now)
  {
   const int hhmm = HhmmFromTime(ny_now);
   return (hhmm >= strategy_entry_start_ny_hhmm && hhmm < strategy_entry_end_ny_hhmm);
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildPendingRequest(QM_EntryRequest &req,
                         const QM_OrderType type,
                         const double entry_price,
                         const double atr_value,
                         const datetime expiry_broker,
                         const string reason)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || atr_value <= 0.0)
      return false;

   req.type = type;
   req.price = NormalizeDouble(entry_price, _Digits);
   req.sl = QM_StopATRFromValue(_Symbol, type, req.price, atr_value, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || MathAbs(req.price - req.sl) / point <= 0.0)
      return false;

   req.tp = 0.0;
   if(strategy_use_rr_take_profit)
      req.tp = QM_TakeRR(_Symbol, type, req.price, req.sl, strategy_take_profit_rr);

   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = (int)MathMax(60, expiry_broker - TimeCurrent());
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   ResetSessionIfNeeded();

   const datetime ny_now = BrokerToNY(TimeCurrent());
   if(!IsWeekdayNY(ny_now) && !HasOurOpenPosition())
      return true;

   if(!HasOurOpenPosition() && !HasOurPendingOrder() && !SpreadAllowsEntry())
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);
   ResetSessionIfNeeded();

   if(_Period != PERIOD_M5)
      return false;
   if(g_trade_taken_today || g_orders_armed_today || HasOurOpenPosition() || HasOurPendingOrder())
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_M5, 1);
   if(signal_bar <= 0 || signal_bar == g_last_entry_eval_bar)
      return false;
   g_last_entry_eval_bar = signal_bar;

   const datetime ny_now = BrokerToNY(TimeCurrent());
   if(!IsWeekdayNY(ny_now) || !InEntryWindowNY(ny_now))
      return false;
   if(!CaptureAnchorFromClosedBar())
      return false;

   const double long_level = g_base_close * (1.0 + strategy_long_pct);
   const double short_level = g_base_close * (1.0 - strategy_short_pct);
   const double atr_value = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(long_level <= 0.0 || short_level <= 0.0 || short_level >= long_level || atr_value <= 0.0)
      return false;

   const datetime expiry_broker = NYSessionTimeToBroker(ny_now, strategy_entry_end_ny_hhmm);
   if(expiry_broker <= TimeCurrent())
      return false;

   const bool allow_long = !IsFridayNY(ny_now);
   const bool allow_short = !IsMondayNY(ny_now);
   if(!allow_long && !allow_short)
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   InitRequest(buy_req);
   InitRequest(sell_req);

   const bool have_buy = allow_long && BuildPendingRequest(buy_req,
                                                           QM_BUY_STOP,
                                                           long_level,
                                                           atr_value,
                                                           expiry_broker,
                                                           "UNGER_3PM_LONG_BREAKOUT");
   const bool have_sell = allow_short && BuildPendingRequest(sell_req,
                                                             QM_SELL_STOP,
                                                             short_level,
                                                             atr_value,
                                                             expiry_broker,
                                                             "UNGER_3PM_SHORT_BREAKOUT");
   if(!have_buy && !have_sell)
      return false;

   if(have_buy && have_sell)
     {
      ulong ticket = 0;
      if(!QM_TM_OpenPosition(buy_req, ticket))
         return false;
      req = sell_req;
      g_orders_armed_today = true;
      return true;
     }

   req = have_buy ? buy_req : sell_req;
   g_orders_armed_today = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(HasOurOpenPosition())
     {
      g_trade_taken_today = true;
      CancelOurPendingOrders();
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime ny_now = BrokerToNY(TimeCurrent());
   const int now_day_key = DayKeyFromTime(ny_now);
   const int now_hhmm = HhmmFromTime(ny_now);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_ny = BrokerToNY((datetime)PositionGetInteger(POSITION_TIME));
      const int open_day_key = DayKeyFromTime(open_ny);
      if(now_day_key != open_day_key && now_hhmm >= strategy_exit_ny_hhmm)
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
