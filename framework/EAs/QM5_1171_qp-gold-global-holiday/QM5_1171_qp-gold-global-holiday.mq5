#property strict
#property version   "5.0"
#property description "QM5_1171 Quantpedia Gold Global Holiday Drift"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1171;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_offset_calendar_days = -1;
input int    strategy_exit_offset_calendar_days  = 2;
input int    strategy_atr_period_d1              = 20;
input double strategy_atr_sl_mult                = 2.0;
input int    strategy_time_stop_trading_days     = 7;
input int    strategy_min_d1_bars                = 80;
input int    strategy_max_spread_points          = 300;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

datetime g_last_entry_d1 = 0;
datetime g_last_exit_d1 = 0;

datetime DateFloor(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime MakeDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   return StructToTime(dt);
  }

int DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int DayOfWeek(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

bool IsTradingWeekday(const datetime value)
  {
   const int dow = DayOfWeek(value);
   return (dow >= 1 && dow <= 5);
  }

datetime AddCalendarDays(const datetime value, const int days)
  {
   return DateFloor(value) + days * 86400;
  }

datetime TradingDayOnOrBefore(const datetime value)
  {
   datetime candidate = DateFloor(value);
   for(int i = 0; i < 10; ++i)
     {
      if(IsTradingWeekday(candidate))
         return candidate;
      candidate -= 86400;
     }
   return 0;
  }

datetime TradingDayOnOrAfter(const datetime value)
  {
   datetime candidate = DateFloor(value);
   for(int i = 0; i < 10; ++i)
     {
      if(IsTradingWeekday(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

int TradingDaysBetween(const datetime start_date, const datetime end_date)
  {
   int count = 0;
   datetime cursor = DateFloor(start_date);
   const datetime limit = DateFloor(end_date);
   while(cursor < limit && count < 40)
     {
      cursor += 86400;
      if(IsTradingWeekday(cursor))
         count++;
     }
   return count;
  }

bool Strategy_HolidayDateByIndex(const int index, datetime &event_date)
  {
   static int dates[] =
     {
      20210101, 20210212, 20210513, 20211104, 20211225,
      20220131, 20220201, 20220502, 20221024, 20221225,
      20230122, 20230421, 20231112, 20231225,
      20240210, 20240410, 20241101, 20241225,
      20250129, 20250331, 20251020, 20251225,
      20260217, 20260320, 20261108, 20261225,
      20270206, 20270310, 20271029, 20271225,
      20280126, 20280227, 20281017, 20281225,
      20290213, 20290215, 20291105, 20291225,
      20300203, 20300205, 20301026, 20301225,
      20310123, 20310125, 20311014, 20311225,
      20320211, 20320114, 20321102, 20321225,
      20330131, 20330103, 20331223, 20331022, 20331225,
      20340219, 20341212, 20341109, 20341225,
      20350208, 20351201, 20351030, 20351225
     };

   if(index < 0 || index >= ArraySize(dates))
      return false;

   const int key = dates[index];
   const int year = key / 10000;
   const int month = (key / 100) % 100;
   const int day = key % 100;
   event_date = MakeDate(year, month, day);
   return (event_date > 0);
  }

bool Strategy_HasOpenPosition(datetime &open_time)
  {
   open_time = 0;
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

datetime Strategy_WindowStart(const datetime event_date)
  {
   return TradingDayOnOrBefore(AddCalendarDays(event_date, strategy_entry_offset_calendar_days));
  }

datetime Strategy_WindowEnd(const datetime event_date)
  {
   return TradingDayOnOrAfter(AddCalendarDays(event_date, strategy_exit_offset_calendar_days));
  }

bool Strategy_EntryDateMatches(const datetime current_d1)
  {
   for(int i = 0; i < 80; ++i)
     {
      datetime event_date = 0;
      if(!Strategy_HolidayDateByIndex(i, event_date))
         break;
      const datetime start_date = Strategy_WindowStart(event_date);
      if(start_date > 0 && DayKey(current_d1) == DayKey(start_date))
         return true;
     }
   return false;
  }

datetime Strategy_LastWindowEndSinceOpen(const datetime open_time)
  {
   datetime latest_end = 0;
   const datetime open_day = DateFloor(open_time);
   for(int i = 0; i < 80; ++i)
     {
      datetime event_date = 0;
      if(!Strategy_HolidayDateByIndex(i, event_date))
         break;

      const datetime start_date = Strategy_WindowStart(event_date);
      const datetime end_date = Strategy_WindowEnd(event_date);
      if(start_date <= 0 || end_date <= 0)
         continue;
      if(open_day <= end_date && start_date <= DateFloor(TimeCurrent()))
        {
         if(end_date > latest_end)
            latest_end = end_date;
        }
     }
   return latest_end;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_entry_offset_calendar_days > -1 || strategy_entry_offset_calendar_days < -2)
      return true;
   if(strategy_exit_offset_calendar_days < 1)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_time_stop_trading_days <= 0)
      return true;
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }
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

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_entry_d1)
      return false;
   if(Bars(_Symbol, PERIOD_D1) < strategy_min_d1_bars)
      return false;

   datetime open_time = 0;
   if(Strategy_HasOpenPosition(open_time))
      return false;
   if(!Strategy_EntryDateMatches(current_d1))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   req.reason = "QM5_1171_GLOBAL_GOLD_HOLIDAY";
   g_last_entry_d1 = current_d1;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed initial ATR stop plus calendar/time exits only.
  }

bool Strategy_ExitSignal()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_exit_d1)
      return false;

   datetime open_time = 0;
   if(!Strategy_HasOpenPosition(open_time))
      return false;

   const datetime latest_window_end = Strategy_LastWindowEndSinceOpen(open_time);
   if(latest_window_end > 0 && DateFloor(current_d1) > latest_window_end)
     {
      g_last_exit_d1 = current_d1;
      return true;
     }

   if(TradingDaysBetween(open_time, current_d1) >= strategy_time_stop_trading_days)
     {
      g_last_exit_d1 = current_d1;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1171\",\"ea\":\"qp-gold-global-holiday\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
