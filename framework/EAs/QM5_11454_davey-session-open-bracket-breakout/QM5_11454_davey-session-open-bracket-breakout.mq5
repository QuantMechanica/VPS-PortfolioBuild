#property strict
#property version   "5.0"
#property description "QM5_11454 Davey session-open bracket breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11454;
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
input int    strategy_session_open_utc_hour    = 8;
input int    strategy_session_open_utc_minute  = 0;
input int    strategy_session_close_utc_hour   = 21;
input int    strategy_session_close_utc_minute = 0;
input int    strategy_offset_pips              = 1;
input int    strategy_max_bracket_pips         = 60;
input int    strategy_atr_period               = 14;
input double strategy_tp_atr_mult              = 1.5;
input int    strategy_spread_cap_pips          = 20;

int    g_session_day_key       = -1;
bool   g_bracket_ready         = false;
bool   g_day_skipped           = false;
bool   g_oco_orders_placed     = false;
bool   g_trade_triggered_today = false;
double g_bracket_high          = 0.0;
double g_bracket_low           = 0.0;
ulong  g_buy_stop_ticket       = 0;
ulong  g_sell_stop_ticket      = 0;

int UtcDayKey(const datetime utc_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_time, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

datetime SessionTimeUTC(const datetime utc_ref, const int hour_value, const int minute_value)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_ref, dt);
   dt.hour = MathMax(0, MathMin(23, hour_value));
   dt.min = MathMax(0, MathMin(59, minute_value));
   dt.sec = 0;
   return StructToTime(dt);
  }

void ResetDayState(const int day_key)
  {
   g_session_day_key       = day_key;
   g_bracket_ready         = false;
   g_day_skipped           = false;
   g_oco_orders_placed     = false;
   g_trade_triggered_today = false;
   g_bracket_high          = 0.0;
   g_bracket_low           = 0.0;
   g_buy_stop_ticket       = 0;
   g_sell_stop_ticket      = 0;
  }

bool IsAtOrAfterSessionClose(const datetime broker_time)
  {
   const datetime utc_now = QM_BrokerToUTC(broker_time);
   const datetime close_utc = SessionTimeUTC(utc_now,
                                             strategy_session_close_utc_hour,
                                             strategy_session_close_utc_minute);
   return (utc_now >= close_utc);
  }

bool IsOpeningBarClosed(const datetime bar_open_utc)
  {
   const datetime session_open_utc = SessionTimeUTC(bar_open_utc,
                                                    strategy_session_open_utc_hour,
                                                    strategy_session_open_utc_minute);
   const datetime bar_close_utc = bar_open_utc + PeriodSeconds(PERIOD_H1);
   return (bar_open_utc <= session_open_utc && bar_close_utc > session_open_utc);
  }

bool SpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   return (spread > 0.0 && spread > cap);
  }

bool HasOurOpenPosition()
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

bool IsOurPendingStopOrderSelected()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return false;
   if((int)OrderGetInteger(ORDER_MAGIC) != magic)
      return false;

   const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int CountOurPendingStopOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(IsOurPendingStopOrderSelected())
         count++;
     }
   return count;
  }

void RemoveOurPendingStopOrders(const string reason)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(!IsOurPendingStopOrderSelected())
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }

   if(CountOurPendingStopOrders() == 0)
     {
      g_buy_stop_ticket = 0;
      g_sell_stop_ticket = 0;
     }
  }

bool CaptureOpeningBracketFromClosedBar()
  {
   // perf-allowed: fixed-session structural OHLC read from one closed H1 bar.
   const datetime bar_open_broker = iTime(_Symbol, PERIOD_H1, 1);
   if(bar_open_broker <= 0)
      return false;

   const datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   const int day_key = UtcDayKey(bar_open_utc);
   if(day_key != g_session_day_key)
      ResetDayState(day_key);

   if(g_bracket_ready || g_day_skipped)
      return g_bracket_ready;
   if(!IsOpeningBarClosed(bar_open_utc))
      return false;

   const double high_price = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed
   const double low_price = iLow(_Symbol, PERIOD_H1, 1);   // perf-allowed
   if(high_price <= 0.0 || low_price <= 0.0 || high_price <= low_price)
      return false;

   const double max_width = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_bracket_pips);
   if(max_width > 0.0 && (high_price - low_price) > max_width)
     {
      g_day_skipped = true;
      return false;
     }

   g_bracket_high = high_price;
   g_bracket_low = low_price;
   g_bracket_ready = true;
   return true;
  }

bool BuildBracketOrder(const QM_OrderType order_type,
                       const double entry_price,
                       const double sl_price,
                       const double atr_value,
                       const string reason,
                       QM_EntryRequest &req)
  {
   req.type = order_type;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry_price);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   req.tp = QM_TakeATRFromValue(_Symbol, order_type, req.price, atr_value, strategy_tp_atr_mult);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(order_type) && !(req.sl < req.price && req.tp > req.price))
      return false;
   if(!QM_OrderTypeIsBuy(order_type) && !(req.sl > req.price && req.tp < req.price))
      return false;

   return true;
  }

bool PlaceDailyOCOBracket()
  {
   if(g_oco_orders_placed || g_trade_triggered_today)
      return false;
   if(!g_bracket_ready || g_day_skipped)
      return false;
   if(HasOurOpenPosition() || CountOurPendingStopOrders() > 0)
      return false;
   if(SpreadTooWide())
     {
      g_day_skipped = true;
      return false;
     }

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(offset <= 0.0 || atr_value <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   if(!BuildBracketOrder(QM_BUY_STOP,
                         g_bracket_high + offset,
                         g_bracket_low - offset,
                         atr_value,
                         "davey_oco_buy_stop",
                         buy_req))
      return false;
   if(!BuildBracketOrder(QM_SELL_STOP,
                         g_bracket_low - offset,
                         g_bracket_high + offset,
                         atr_value,
                         "davey_oco_sell_stop",
                         sell_req))
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   ulong sell_ticket = 0;
   if(!QM_TM_OpenPosition(sell_req, sell_ticket))
     {
      if(buy_ticket > 0)
         QM_TM_RemovePendingOrder(buy_ticket, "oco_second_leg_failed");
      return false;
     }

   g_buy_stop_ticket = buy_ticket;
   g_sell_stop_ticket = sell_ticket;
   g_oco_orders_placed = true;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition() || CountOurPendingStopOrders() > 0)
      return false;
   if(IsAtOrAfterSessionClose(TimeCurrent()))
      return true;
   if(g_bracket_ready && !g_oco_orders_placed && SpreadTooWide())
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(IsAtOrAfterSessionClose(TimeCurrent()))
      return false;
   if(!CaptureOpeningBracketFromClosedBar())
      return false;

   PlaceDailyOCOBracket();
   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(IsAtOrAfterSessionClose(TimeCurrent()))
     {
      RemoveOurPendingStopOrders("session_close_cancel");
      return;
     }

   if(HasOurOpenPosition())
     {
      g_trade_triggered_today = true;
      RemoveOurPendingStopOrders("oco_opposite_cancel");
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;
   return IsAtOrAfterSessionClose(TimeCurrent());
  }

// News Filter Hook
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
