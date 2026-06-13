#property strict
#property version   "5.0"
#property description "QM5_1062 Unger Opening-Range Breakout Index CFD Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1062;
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
input int    strategy_or_window_minutes = 30;
input int    strategy_atr_period_d1     = 14;
input double strategy_atr_cap_mult      = 2.0;
input double strategy_narrow_atr_mult   = 0.5;
input int    strategy_entry_offset_pips = 1;
input int    strategy_spread_samples    = 20;

datetime g_session_day = 0;
bool     g_or_ready = false;
bool     g_orders_armed_today = false;
bool     g_trade_taken_today = false;
double   g_or_high = 0.0;
double   g_or_low = 0.0;
int      g_spread_ring[256];
int      g_spread_count = 0;
int      g_spread_pos = 0;

datetime Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_NthSunday(const int year, const int month, const int n)
  {
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = 1;
   dt.hour = 2;
   dt.min = 0;
   dt.sec = 0;
   datetime t = StructToTime(dt);
   TimeToStruct(t, dt);
   const int add_days = ((7 - dt.day_of_week) % 7) + ((n - 1) * 7);
   return t + add_days * 86400;
  }

bool Strategy_UsDstActive(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const datetime dst_start = Strategy_NthSunday(dt.year, 3, 2);
   const datetime dst_end = Strategy_NthSunday(dt.year, 11, 1);
   return (broker_time >= dst_start && broker_time < dst_end);
  }

void Strategy_SessionTimes(datetime &session_open,
                           datetime &or_end,
                           datetime &expiry,
                           datetime &session_close)
  {
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   const datetime day = StructToTime(dt);

   int open_h = 9;
   int open_m = 0;
   int close_h = 17;
   int close_m = 30;
   if(_Symbol == "NDX.DWX" || _Symbol == "WS30.DWX")
     {
      const bool us_dst = Strategy_UsDstActive(now);
      open_h = us_dst ? 15 : 16;
      open_m = 30;
      close_h = us_dst ? 22 : 23;
      close_m = 0;
     }

   session_open = day + open_h * 3600 + open_m * 60;
   or_end = session_open + strategy_or_window_minutes * 60;
   session_close = day + close_h * 3600 + close_m * 60;
   expiry = session_close - 5 * 60;
  }

double Strategy_PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

void Strategy_ResetNewSessionIfNeeded()
  {
   const datetime today = Strategy_DateKey(TimeCurrent());
   if(today == g_session_day)
      return;

   g_session_day = today;
   g_or_ready = false;
   g_orders_armed_today = false;
   g_trade_taken_today = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_spread_count = 0;
   g_spread_pos = 0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasPendingStop()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

void Strategy_CancelPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_RecordSpreadSample()
  {
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return;

   const int cap = MathMax(1, MathMin(strategy_spread_samples, 256));
   g_spread_ring[g_spread_pos % cap] = spread;
   g_spread_pos = (g_spread_pos + 1) % cap;
   if(g_spread_count < cap)
      ++g_spread_count;
  }

int Strategy_MedianSpread()
  {
   if(g_spread_count <= 0)
      return 0;

   int tmp[256];
   for(int i = 0; i < g_spread_count; ++i)
      tmp[i] = g_spread_ring[i];

   for(int i = 1; i < g_spread_count; ++i)
     {
      const int key = tmp[i];
      int j = i - 1;
      while(j >= 0 && tmp[j] > key)
        {
         tmp[j + 1] = tmp[j];
         --j;
        }
      tmp[j + 1] = key;
     }

   return tmp[g_spread_count / 2];
  }

bool Strategy_SpreadAllowsEntry()
  {
   const int current = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const int median = Strategy_MedianSpread();
   if(current <= 0 || median <= 0)
      return true;
   return (current <= 2 * median);
  }

bool Strategy_BuildOpeningRange(const datetime session_open, const datetime or_end)
  {
   if(strategy_or_window_minutes < 5 || (strategy_or_window_minutes % 5) != 0)
      return false;

   double high = -DBL_MAX;
   double low = DBL_MAX;
   int found = 0;
   for(int shift = 1; shift <= 96; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_M5, shift); // perf-allowed: bounded M5 OR scan on framework new-bar path.
      if(bar_time <= 0)
         break;
      if(bar_time < session_open)
         break;
      if(bar_time >= or_end)
         continue;

      const double h = iHigh(_Symbol, PERIOD_M5, shift); // perf-allowed: bounded M5 OR scan on framework new-bar path.
      const double l = iLow(_Symbol, PERIOD_M5, shift);  // perf-allowed: bounded M5 OR scan on framework new-bar path.
      if(h <= 0.0 || l <= 0.0)
         return false;

      high = MathMax(high, h);
      low = MathMin(low, l);
      ++found;
     }

   const int bars_needed = strategy_or_window_minutes / 5;
   if(found < bars_needed || high <= low)
      return false;

   g_or_high = high;
   g_or_low = low;
   g_or_ready = true;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   Strategy_ResetNewSessionIfNeeded();

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.day_of_week == 0 || dt.day_of_week == 6) && !Strategy_HasOpenPosition())
      return true;

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

   Strategy_ResetNewSessionIfNeeded();
   Strategy_RecordSpreadSample();

   if(g_trade_taken_today || g_orders_armed_today || Strategy_HasOpenPosition() || Strategy_HasPendingStop())
      return false;

   datetime session_open, or_end, expiry, session_close;
   Strategy_SessionTimes(session_open, or_end, expiry, session_close);
   const datetime now = TimeCurrent();
   if(now < or_end || now >= expiry)
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   if(!g_or_ready && !Strategy_BuildOpeningRange(session_open, or_end))
      return false;

   const double pip = Strategy_PipDistance();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip <= 0.0 || point <= 0.0)
      return false;

   const double or_size = g_or_high - g_or_low;
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(or_size <= 0.0 || atr_d1 <= 0.0)
      return false;

   if(or_size < strategy_narrow_atr_mult * atr_d1)
     {
      g_orders_armed_today = true;
      return false;
     }

   const double offset = strategy_entry_offset_pips * pip;
   const double buy_price = NormalizeDouble(g_or_high + offset, _Digits);
   const double sell_price = NormalizeDouble(g_or_low - offset, _Digits);
   const double atr_cap = strategy_atr_cap_mult * atr_d1;
   const double buy_sl_range = g_or_low - offset;
   const double sell_sl_range = g_or_high + offset;
   const double buy_sl_cap = buy_price - atr_cap;
   const double sell_sl_cap = sell_price + atr_cap;
   const double buy_sl = NormalizeDouble(MathMax(buy_sl_range, buy_sl_cap), _Digits);
   const double sell_sl = NormalizeDouble(MathMin(sell_sl_range, sell_sl_cap), _Digits);
   if(buy_price <= 0.0 || sell_price <= 0.0 || buy_sl <= 0.0 || sell_sl <= 0.0)
      return false;
   if((buy_price - buy_sl) / point <= 0.0 || (sell_sl - sell_price) / point <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_price;
   buy_req.sl = buy_sl;
   buy_req.tp = 0.0;
   buy_req.reason = "UNGER_ORB_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = (int)MathMax(60.0, (double)(expiry - now));

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   req.type = QM_SELL_STOP;
   req.price = sell_price;
   req.sl = sell_sl;
   req.tp = 0.0;
   req.reason = "UNGER_ORB_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = (int)MathMax(60.0, (double)(expiry - now));

   g_orders_armed_today = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime session_open, or_end, expiry, session_close;
   Strategy_SessionTimes(session_open, or_end, expiry, session_close);

   if(Strategy_HasOpenPosition())
     {
      g_trade_taken_today = true;
      Strategy_CancelPendingStops("oco_fill");
      return;
     }

   if(TimeCurrent() >= expiry)
      Strategy_CancelPendingStops("session_expiry");
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   datetime session_open, or_end, expiry, session_close;
   Strategy_SessionTimes(session_open, or_end, expiry, session_close);
   return (TimeCurrent() >= session_close - 5 * 60);
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
