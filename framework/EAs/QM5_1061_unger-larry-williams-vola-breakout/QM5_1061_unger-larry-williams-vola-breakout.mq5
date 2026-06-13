#property strict
#property version   "5.0"
#property description "QM5_1061 Unger/Larry Williams volatility breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1061;
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
input double strategy_k                  = 0.50;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 1.50;
input int    strategy_spread_days        = 20;

int  g_session_day_key = 0;
int  g_armed_day_key = 0;
bool g_trade_taken_today = false;

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

int MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 60 + dt.min);
  }

int DayOfWeekForDate(const int year, const int mon, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = mon;
   dt.day = day;
   const datetime stamp = StructToTime(dt);
   TimeToStruct(stamp, dt);
   return dt.day_of_week;
  }

int NthSunday(const int year, const int mon, const int nth)
  {
   int seen = 0;
   for(int day = 1; day <= 31; ++day)
     {
      if(DayOfWeekForDate(year, mon, day) != 0)
         continue;
      ++seen;
      if(seen == nth)
         return day;
     }
   return 0;
  }

bool IsUsDstDate(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int start_day = NthSunday(dt.year, 3, 2);
   const int end_day = NthSunday(dt.year, 11, 1);
   if(dt.mon > 3 && dt.mon < 11)
      return true;
   if(dt.mon < 3 || dt.mon > 11)
      return false;
   if(dt.mon == 3)
      return (dt.day >= start_day);
   return (dt.day < end_day);
  }

void SessionWindowMinutes(const datetime broker_time, int &start_min, int &close_min)
  {
   start_min = 8 * 60;
   close_min = 22 * 60;

   if(StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "GER40") >= 0)
     {
      start_min = 9 * 60;
      close_min = 17 * 60 + 30;
      return;
     }

   if(StringFind(_Symbol, "NDX") >= 0 || StringFind(_Symbol, "WS30") >= 0)
     {
      if(IsUsDstDate(broker_time))
        {
         start_min = 15 * 60 + 30;
         close_min = 22 * 60;
        }
      else
        {
         start_min = 16 * 60 + 30;
         close_min = 23 * 60;
        }
      return;
     }

   if(StringFind(_Symbol, "XAUUSD") >= 0)
     {
      start_min = 8 * 60;
      close_min = 22 * 60;
     }
  }

bool IsBeforeSession(const datetime broker_time)
  {
   int start_min = 0;
   int close_min = 0;
   SessionWindowMinutes(broker_time, start_min, close_min);
   return (MinutesOfDay(broker_time) < start_min);
  }

bool IsAtOrAfterSessionClose(const datetime broker_time)
  {
   int start_min = 0;
   int close_min = 0;
   SessionWindowMinutes(broker_time, start_min, close_min);
   return (MinutesOfDay(broker_time) >= close_min);
  }

bool IsFirstSessionBar(const datetime broker_time)
  {
   int start_min = 0;
   int close_min = 0;
   SessionWindowMinutes(broker_time, start_min, close_min);
   const int now_min = MinutesOfDay(broker_time);
   if(now_min < start_min || now_min >= close_min)
      return false;

   int grace_min = PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60;
   if(grace_min < 5)
      grace_min = 5;
   if(grace_min > 60)
      grace_min = 60;
   return ((now_min - start_min) <= grace_min);
  }

void RefreshDayState(const datetime broker_time)
  {
   const int key = DayKey(broker_time);
   if(key == g_session_day_key)
      return;
   g_session_day_key = key;
   g_armed_day_key = 0;
   g_trade_taken_today = false;
  }

bool IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool HasOurPendingOrders()
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
      if(IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void CancelOurPendingOrders(const string reason)
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
      if(!IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool SpreadAllowsEntry()
  {
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0 || strategy_spread_days <= 0)
      return true;

   int spreads[];
   ArrayResize(spreads, strategy_spread_days);
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_days; ++shift)
     {
      const int spread = (int)iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = spread;
      ++count;
     }
   if(count <= 0)
      return true;

   ArrayResize(spreads, count);
   ArraySort(spreads);
   const double median = (count % 2 == 1)
                         ? (double)spreads[count / 2]
                         : ((double)spreads[count / 2 - 1] + (double)spreads[count / 2]) * 0.5;
   if(median <= 0.0)
      return true;
   return ((double)current_spread <= 2.0 * median);
  }

bool BuildStopRequest(const QM_OrderType order_type,
                      const double entry_price,
                      const double atr_value,
                      const int expiration_seconds,
                      const string reason,
                      QM_EntryRequest &req)
  {
   req.type = order_type;
   req.price = NormalizeDouble(entry_price, _Digits);
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   req.reason = reason;
   req.sl = QM_StopATRFromValue(_Symbol, order_type, req.price, atr_value, strategy_sl_atr_mult);
   return (req.price > 0.0 && req.sl > 0.0);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   RefreshDayState(broker_now);

   if(IsBeforeSession(broker_now) && !HasOurOpenPosition() && !HasOurPendingOrders())
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

   const datetime broker_now = TimeCurrent();
   RefreshDayState(broker_now);

   if(g_trade_taken_today || g_armed_day_key == g_session_day_key)
      return false;
   if(HasOurOpenPosition() || HasOurPendingOrders())
      return false;
   if(!IsFirstSessionBar(broker_now))
      return false;
   if(!SpreadAllowsEntry())
      return false;

   int start_min = 0;
   int close_min = 0;
   SessionWindowMinutes(broker_now, start_min, close_min);
   const int seconds_to_close = (close_min - MinutesOfDay(broker_now)) * 60;
   if(seconds_to_close <= 0)
      return false;

   const double day_open = iOpen(_Symbol, PERIOD_D1, 0);       // perf-allowed: D1 session-open structural input, read once per new bar.
   const double prev_high = iHigh(_Symbol, PERIOD_D1, 1);      // perf-allowed: prior-day range structural input, read once per new bar.
   const double prev_low = iLow(_Symbol, PERIOD_D1, 1);        // perf-allowed: prior-day range structural input, read once per new bar.
   const double yr = prev_high - prev_low;
   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(day_open <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0 || yr <= 0.0 || atr_value <= 0.0)
      return false;

   const double buy_stop = day_open + strategy_k * yr;
   const double sell_stop = day_open - strategy_k * yr;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(buy_stop <= ask + point || sell_stop >= bid - point)
      return false;

   QM_EntryRequest buy_req;
   if(!BuildStopRequest(QM_BUY_STOP, buy_stop, atr_value, seconds_to_close, "VOLA_BO_BUY_STOP", buy_req))
      return false;
   if(!BuildStopRequest(QM_SELL_STOP, sell_stop, atr_value, seconds_to_close, "VOLA_BO_SELL_STOP", req))
      return false;

   ulong buy_ticket = 0;
   QM_TM_OpenPosition(buy_req, buy_ticket);
   g_armed_day_key = g_session_day_key;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   RefreshDayState(broker_now);

   if(HasOurOpenPosition())
     {
      g_trade_taken_today = true;
      CancelOurPendingOrders("oco_peer_cancel");
      return;
     }

   if(IsAtOrAfterSessionClose(broker_now))
      CancelOurPendingOrders("session_close");
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   RefreshDayState(broker_now);
   return (HasOurOpenPosition() && IsAtOrAfterSessionClose(broker_now));
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1061\",\"ea\":\"unger-larry-williams-vola-breakout\"}");
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
