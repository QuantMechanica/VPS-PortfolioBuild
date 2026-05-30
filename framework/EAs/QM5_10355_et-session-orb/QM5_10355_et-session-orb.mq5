#property strict
#property version   "5.0"
#property description "QM5_10355 Elite Trader Session Opening Range Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10355;
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
input int    strategy_opening_bars      = 3;
input int    strategy_breakout_ticks    = 3;
input double strategy_target_rr         = 1.0;
input double strategy_stop_cap_range_mult = 1.5;
input double strategy_spread_median_mult = 2.5;
input int    strategy_spread_median_bars = 48;
input int    strategy_session_start_hour = -1;
input int    strategy_session_start_min  = -1;
input int    strategy_session_end_hour   = -1;
input int    strategy_session_end_min    = -1;

int      g_trade_day_key = 0;
int      g_range_bars_collected = 0;
bool     g_range_ready = false;
bool     g_orders_placed_today = false;
bool     g_position_seen_today = false;
double   g_opening_high = 0.0;
double   g_opening_low = 0.0;
double   g_spread_points[256];
int      g_spread_count = 0;
double   g_median_spread_points = 0.0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

void Strategy_DefaultSession(int &start_hour, int &start_min, int &end_hour, int &end_min)
  {
   start_hour = strategy_session_start_hour;
   start_min = strategy_session_start_min;
   end_hour = strategy_session_end_hour;
   end_min = strategy_session_end_min;

   if(start_hour >= 0 && start_min >= 0 && end_hour >= 0 && end_min >= 0)
      return;

   if(_Symbol == "GDAXI.DWX")
     {
      start_hour = 10;
      start_min = 0;
      end_hour = 18;
      end_min = 30;
      return;
     }

   if(_Symbol == "EURUSD.DWX")
     {
      start_hour = 9;
      start_min = 0;
      end_hour = 17;
      end_min = 0;
      return;
     }

   start_hour = 16;
   start_min = 30;
   end_hour = 22;
   end_min = 45;
  }

bool Strategy_InSession(const datetime t)
  {
   int sh, sm, eh, em;
   Strategy_DefaultSession(sh, sm, eh, em);
   const int now_min = Strategy_MinuteOfDay(t);
   const int start_minute = sh * 60 + sm;
   const int end_minute = eh * 60 + em;
   if(start_minute <= end_minute)
      return (now_min >= start_minute && now_min < end_minute);
   return (now_min >= start_minute || now_min < end_minute);
  }

bool Strategy_AfterSessionEnd(const datetime t)
  {
   int sh, sm, eh, em;
   Strategy_DefaultSession(sh, sm, eh, em);
   const int now_min = Strategy_MinuteOfDay(t);
   const int start_minute = sh * 60 + sm;
   const int end_minute = eh * 60 + em;
   if(start_minute <= end_minute)
      return (now_min >= end_minute);
   return (now_min >= end_minute && now_min < start_minute);
  }

int Strategy_SecondsToSessionEnd(const datetime t)
  {
   int sh, sm, eh, em;
   Strategy_DefaultSession(sh, sm, eh, em);
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = eh;
   dt.min = em;
   dt.sec = 0;
   datetime end_time = StructToTime(dt);
   if(end_time <= t)
      end_time += 86400;
   return (int)MathMax(60, end_time - t);
  }

void Strategy_ResetDay(const datetime t)
  {
   const int day_key = Strategy_DayKey(t);
   if(day_key == g_trade_day_key)
      return;

   g_trade_day_key = day_key;
   g_range_bars_collected = 0;
   g_range_ready = false;
   g_orders_placed_today = false;
   g_position_seen_today = false;
   g_opening_high = 0.0;
   g_opening_low = 0.0;
  }

double Strategy_CurrentSpreadPoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return 0.0;
   return (ask - bid) / point;
  }

void Strategy_UpdateSpreadMedian()
  {
   const double spread = Strategy_CurrentSpreadPoints();
   if(spread <= 0.0)
      return;

   const int max_bars = (int)MathMin((double)strategy_spread_median_bars, 256.0);
   if(max_bars <= 0)
      return;

   if(g_spread_count < max_bars)
      g_spread_points[g_spread_count++] = spread;
   else
     {
      for(int i = 1; i < max_bars; ++i)
         g_spread_points[i - 1] = g_spread_points[i];
      g_spread_points[max_bars - 1] = spread;
      g_spread_count = max_bars;
     }

   double sorted[256];
   for(int i = 0; i < g_spread_count; ++i)
      sorted[i] = g_spread_points[i];

   for(int i = 1; i < g_spread_count; ++i)
     {
      const double value = sorted[i];
      int j = i - 1;
      while(j >= 0 && sorted[j] > value)
        {
         sorted[j + 1] = sorted[j];
         --j;
        }
      sorted[j + 1] = value;
     }

   const int mid = g_spread_count / 2;
   if((g_spread_count % 2) == 0 && g_spread_count > 1)
      g_median_spread_points = (sorted[mid - 1] + sorted[mid]) * 0.5;
   else
      g_median_spread_points = sorted[mid];
  }

bool Strategy_SpreadOK()
  {
   if(g_median_spread_points <= 0.0 || strategy_spread_median_mult <= 0.0)
      return true;
   const double spread = Strategy_CurrentSpreadPoints();
   if(spread <= 0.0)
      return false;
   return (spread <= g_median_spread_points * strategy_spread_median_mult);
  }

bool Strategy_HasOurPosition()
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
      g_position_seen_today = true;
      return true;
     }
   return false;
  }

bool Strategy_IsOurPendingType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurPendingOrder()
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
      if(Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelOurPendingOrders()
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
      if(!Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;
      request.symbol = _Symbol;
      request.comment = "session_orb_cancel_pending";

      string error_class = BROKER_OTHER;
      QM_TradeContextSend(request, result, error_class);
     }
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_BuildStopRequest(const QM_OrderType type,
                               const double entry,
                               const double sl,
                               const int expiration_seconds,
                               const string reason,
                               QM_EntryRequest &req)
  {
   req.type = type;
   req.price = Strategy_NormalizePrice(entry);
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = QM_TakeRR(_Symbol, type, req.price, req.sl, strategy_target_rr);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;

   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(type == QM_BUY_STOP && !(req.sl < req.price && req.tp > req.price))
      return false;
   if(type == QM_SELL_STOP && !(req.sl > req.price && req.tp < req.price))
      return false;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetDay(now);

   if(Strategy_HasOurPosition() || Strategy_HasOurPendingOrder())
      return false;

   if(!Strategy_InSession(now))
      return true;

   if(!Strategy_SpreadOK())
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   Strategy_ResetDay(bar_time);
   Strategy_UpdateSpreadMedian();

   if(strategy_opening_bars <= 0 || strategy_breakout_ticks < 0 || strategy_target_rr <= 0.0)
      return false;
   if(g_orders_placed_today || g_position_seen_today || Strategy_HasOurPendingOrder())
      return false;
   if(!Strategy_InSession(bar_time) || !Strategy_SpreadOK())
      return false;

   if(!g_range_ready)
     {
      if(g_range_bars_collected >= strategy_opening_bars)
         g_range_ready = true;
      else
        {
         const double high = iHigh(_Symbol, _Period, 1);
         const double low = iLow(_Symbol, _Period, 1);
         if(high <= 0.0 || low <= 0.0)
            return false;

         if(g_range_bars_collected == 0)
           {
            g_opening_high = high;
            g_opening_low = low;
           }
         else
           {
            g_opening_high = MathMax(g_opening_high, high);
            g_opening_low = MathMin(g_opening_low, low);
           }

         ++g_range_bars_collected;
         if(g_range_bars_collected < strategy_opening_bars)
            return false;
         g_range_ready = true;
        }
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return false;

   const double range_width = g_opening_high - g_opening_low;
   const double spread_price = Strategy_CurrentSpreadPoints() * point;
   if(range_width <= 0.0 || spread_price <= 0.0 || range_width < spread_price * 4.0)
      return false;

   const double breakout_offset = strategy_breakout_ticks * tick_size;
   const double buy_price = g_opening_high + breakout_offset;
   const double sell_price = g_opening_low - breakout_offset;
   double buy_sl = g_opening_low - tick_size;
   double sell_sl = g_opening_high + tick_size;

   const double stop_cap = range_width * strategy_stop_cap_range_mult;
   if(stop_cap > 0.0)
     {
      if((buy_price - buy_sl) > stop_cap)
         buy_sl = buy_price - stop_cap;
      if((sell_sl - sell_price) > stop_cap)
         sell_sl = sell_price + stop_cap;
     }

   const int expiry_seconds = Strategy_SecondsToSessionEnd(TimeCurrent());
   QM_EntryRequest buy_req;
   if(!Strategy_BuildStopRequest(QM_BUY_STOP, buy_price, buy_sl, expiry_seconds, "ET_SESSION_ORB_BUY_STOP", buy_req))
      return false;
   if(!Strategy_BuildStopRequest(QM_SELL_STOP, sell_price, sell_sl, expiry_seconds, "ET_SESSION_ORB_SELL_STOP", req))
      return false;

   ulong buy_ticket = 0;
   QM_TM_OpenPosition(buy_req, buy_ticket);
   g_orders_placed_today = true;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetDay(now);

   if(Strategy_HasOurPosition() || Strategy_AfterSessionEnd(now))
      Strategy_CancelOurPendingOrders();
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;
   return Strategy_AfterSessionEnd(TimeCurrent());
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10355_et-session-orb\"}");
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
