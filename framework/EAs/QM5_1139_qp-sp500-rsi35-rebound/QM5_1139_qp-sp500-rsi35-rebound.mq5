#property strict
#property version   "5.0"
#property description "QM5_1139 Quantpedia RSI 35 Rebound - SP500"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1139;
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
input int    strategy_rsi_period          = 14;
input double strategy_entry_rsi           = 35.0;
input double strategy_exit_rsi            = 55.0;
input int    strategy_min_d1_closes       = 60;
input int    strategy_time_stop_days      = 10;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 2.0;
input double strategy_spread_median_mult  = 3.0;
input int    strategy_spread_lookback_days = 20;
input int    strategy_entry_hour_ny       = 9;
input int    strategy_entry_minute_ny     = 30;

datetime g_last_spread_h1_bar = 0;
double   g_cached_median_spread = 0.0;
int      g_pending_signal_date_key = 0;
int      g_last_entry_signal_date_key = 0;

datetime Strategy_MakeDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   return StructToTime(dt);
  }

datetime Strategy_DateFloor(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_NthWeekdayOfMonth(const int year, const int month, const int weekday, const int ordinal)
  {
   int seen = 0;
   for(int day = 1; day <= 31; ++day)
     {
      const datetime candidate = Strategy_MakeDate(year, month, day);
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(dt.day_of_week == weekday)
        {
         ++seen;
         if(seen == ordinal)
            return Strategy_DateFloor(candidate);
        }
     }
   return 0;
  }

datetime Strategy_LastWeekdayOfMonth(const int year, const int month, const int weekday)
  {
   datetime found = 0;
   for(int day = 1; day <= 31; ++day)
     {
      const datetime candidate = Strategy_MakeDate(year, month, day);
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(dt.day_of_week == weekday)
         found = Strategy_DateFloor(candidate);
     }
   return found;
  }

datetime Strategy_ObservedFixedHoliday(const int year, const int month, const int day)
  {
   const datetime actual = Strategy_MakeDate(year, month, day);
   const int dow = Strategy_DayOfWeek(actual);
   if(dow == 0)
      return actual + 86400;
   if(dow == 6)
      return actual - 86400;
   return actual;
  }

datetime Strategy_EasterSunday(const int year)
  {
   const int a = year % 19;
   const int b = year / 100;
   const int c = year % 100;
   const int d = b / 4;
   const int e = b % 4;
   const int f = (b + 8) / 25;
   const int g = (b - f + 1) / 3;
   const int h = (19 * a + b - d - g + 15) % 30;
   const int i = c / 4;
   const int k = c % 4;
   const int l = (32 + 2 * e + 2 * i - h - k) % 7;
   const int m = (a + 11 * h + 22 * l) / 451;
   const int month = (h + l - 7 * m + 114) / 31;
   const int day = ((h + l - 7 * m + 114) % 31) + 1;
   return Strategy_MakeDate(year, month, day);
  }

bool Strategy_SameDate(const datetime left, const datetime right)
  {
   return Strategy_DateFloor(left) == Strategy_DateFloor(right);
  }

bool Strategy_IsUsCashHoliday(const datetime value)
  {
   const datetime d = Strategy_DateFloor(value);
   MqlDateTime dt;
   TimeToStruct(d, dt);
   const int y = dt.year;

   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 1, 1)))
      return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 1, 1, 3)))
      return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 2, 1, 3)))
      return true;
   if(Strategy_SameDate(d, Strategy_EasterSunday(y) - 2 * 86400))
      return true;
   if(Strategy_SameDate(d, Strategy_LastWeekdayOfMonth(y, 5, 1)))
      return true;
   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 6, 19)))
      return true;
   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 7, 4)))
      return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 9, 1, 1)))
      return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 11, 2, 1)))
      return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 11, 4, 4)))
      return true;
   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 12, 25)))
      return true;

   return false;
  }

datetime Strategy_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   return utc + ny_offset_hours * 3600;
  }

bool Strategy_IsRegularUsCashDayNY(const datetime ny_date)
  {
   const int dow = Strategy_DayOfWeek(ny_date);
   return (dow >= 1 && dow <= 5 && !Strategy_IsUsCashHoliday(ny_date));
  }

bool Strategy_CurrentNyDateTime(MqlDateTime &ny)
  {
   const datetime ny_now = Strategy_BrokerToNewYork(TimeCurrent());
   TimeToStruct(ny_now, ny);
   return (ny.year > 2000);
  }

void Strategy_RefreshMedianSpread()
  {
   const datetime h1 = iTime(_Symbol, PERIOD_H1, 0);
   if(h1 <= 0 || h1 == g_last_spread_h1_bar)
      return;

   g_last_spread_h1_bar = h1;
   g_cached_median_spread = 0.0;

   const int lookback_bars = MathMax(1, strategy_spread_lookback_days) * 24;
   double values[];
   ArrayResize(values, lookback_bars);
   int samples = 0;
   for(int shift = 1; shift <= lookback_bars; ++shift)
     {
      const int spread_points = iSpread(_Symbol, PERIOD_H1, shift);
      if(spread_points <= 0)
         continue;
      values[samples] = (double)spread_points;
      ++samples;
     }

   if(samples < MathMax(10, strategy_spread_lookback_days))
      return;

   ArrayResize(values, samples);
   ArraySort(values);
   if((samples % 2) == 1)
      g_cached_median_spread = values[samples / 2];
   else
      g_cached_median_spread = 0.5 * (values[samples / 2 - 1] + values[samples / 2]);
  }

bool Strategy_SpreadOk()
  {
   Strategy_RefreshMedianSpread();
   if(g_cached_median_spread <= 0.0)
      return false;

   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   return ((double)current_spread <= g_cached_median_spread * strategy_spread_median_mult);
  }

bool Strategy_GetOurPosition(ulong &ticket_out)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket_out = ticket;
      return true;
     }
   return false;
  }

int Strategy_TradingDaysSince(const datetime since_broker)
  {
   datetime cursor = Strategy_DateFloor(Strategy_BrokerToNewYork(since_broker));
   const datetime today = Strategy_DateFloor(Strategy_BrokerToNewYork(TimeCurrent()));
   int days = 0;
   while(cursor < today)
     {
      cursor += 86400;
      if(Strategy_IsRegularUsCashDayNY(cursor))
         ++days;
      if(days > strategy_time_stop_days + 5)
         break;
     }
   return days;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "SP500.DWX")
      return true;

   MqlDateTime ny;
   if(!Strategy_CurrentNyDateTime(ny))
      return true;

   const datetime ny_date = Strategy_MakeDate(ny.year, ny.mon, ny.day);
   if(!Strategy_IsRegularUsCashDayNY(ny_date))
      return true;

   if(_Period != PERIOD_M15 && _Period != PERIOD_H1 && _Period != PERIOD_D1)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QP_SP500_RSI35_REBOUND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_d1_closes, strategy_rsi_period + strategy_atr_period + 5))
      return false;

   ulong existing_ticket = 0;
   if(Strategy_GetOurPosition(existing_ticket))
      return false;

   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   const int signal_key = Strategy_DateKey(d1_bar);
   if(signal_key > 0 && signal_key != g_last_entry_signal_date_key)
     {
      const double rsi_1 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
      const double rsi_2 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 2);
      if(rsi_1 > 0.0 && rsi_2 > 0.0 && rsi_2 >= strategy_entry_rsi && rsi_1 < strategy_entry_rsi)
        {
         g_pending_signal_date_key = signal_key;
         g_last_entry_signal_date_key = signal_key;
        }
     }

   if(g_pending_signal_date_key <= 0)
      return false;

   MqlDateTime ny;
   if(!Strategy_CurrentNyDateTime(ny))
      return false;
   if(ny.hour < strategy_entry_hour_ny)
      return false;
   if(ny.hour == strategy_entry_hour_ny && ny.min < strategy_entry_minute_ny)
      return false;

   if(!Strategy_SpreadOk())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   req.price = ask;
   g_pending_signal_date_key = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline uses only the initial ATR hard stop.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_GetOurPosition(ticket))
      return false;

   const double rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   if(rsi > strategy_exit_rsi)
      return true;

   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   if(Strategy_TradingDaysSince(opened) >= strategy_time_stop_days)
      return true;

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

   SymbolSelect("SP500.DWX", true);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1139\",\"ea\":\"qp-sp500-rsi35-rebound\"}");
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
