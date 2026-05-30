#property strict
#property version   "5.0"
#property description "QM5_1146 Unger DAX Overnight Bias"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 1146;
input int    qm_magic_slot_offset           = 0;
input uint   qm_rng_seed                    = 42;

input group "Risk"
input double RISK_PERCENT                   = 0.0;
input double RISK_FIXED                     = 1000.0;
input double PORTFOLIO_WEIGHT               = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_SKIP_DAY;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours        = 336;
input string qm_news_min_impact             = "high";
input QM_NewsMode qm_news_mode_legacy       = QM_NEWS_SKIP_DAY;

input group "Friday Close"
input bool   qm_friday_close_enabled        = true;
input int    qm_friday_close_hour_broker    = 21;

input group "Stress"
input double qm_stress_reject_probability   = 0.0;

input group "Strategy"
input int    strategy_timeframe_minutes     = 15;
input int    strategy_entry_hour_berlin     = 17;
input int    strategy_entry_minute_berlin   = 15;
input int    strategy_exit_hour_berlin      = 9;
input int    strategy_exit_minute_berlin    = 0;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 1.5;
input int    strategy_spread_lookback_days  = 20;
input double strategy_spread_median_mult    = 2.0;
input bool   strategy_allow_ports           = true;

int g_last_entry_date_key = 0;
int g_last_exit_date_key = 0;

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

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

int Strategy_YearOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
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

bool Strategy_IsEuropeSummerUTC(const datetime utc)
  {
   MqlDateTime dt;
   TimeToStruct(utc, dt);
   const datetime start_day = Strategy_LastWeekdayOfMonth(dt.year, 3, 0);
   const datetime end_day = Strategy_LastWeekdayOfMonth(dt.year, 10, 0);
   const datetime start_utc = start_day + 1 * 3600;
   const datetime end_utc = end_day + 1 * 3600;
   return (utc >= start_utc && utc < end_utc);
  }

datetime Strategy_BrokerToBerlin(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (Strategy_IsEuropeSummerUTC(utc) ? 2 : 1) * 3600;
  }

bool Strategy_IsGermanCashHoliday(const datetime berlin_time)
  {
   const datetime d = Strategy_DateFloor(berlin_time);
   const int y = Strategy_YearOf(d);
   const datetime easter = Strategy_EasterSunday(y);
   if(Strategy_SameDate(d, Strategy_MakeDate(y, 1, 1)))
      return true;
   if(Strategy_SameDate(d, easter - 2 * 86400))
      return true;
   if(Strategy_SameDate(d, easter + 1 * 86400))
      return true;
   if(Strategy_SameDate(d, Strategy_MakeDate(y, 5, 1)))
      return true;
   if(Strategy_SameDate(d, Strategy_MakeDate(y, 10, 3)))
      return true;
   if(Strategy_SameDate(d, Strategy_MakeDate(y, 12, 24)))
      return true;
   if(Strategy_SameDate(d, Strategy_MakeDate(y, 12, 25)))
      return true;
   if(Strategy_SameDate(d, Strategy_MakeDate(y, 12, 26)))
      return true;
   if(Strategy_SameDate(d, Strategy_MakeDate(y, 12, 31)))
      return true;
   return false;
  }

bool Strategy_IsRegularBerlinCashOpen(const datetime berlin_time)
  {
   const int dow = Strategy_DayOfWeek(berlin_time);
   if(dow < 1 || dow > 5)
      return false;
   return !Strategy_IsGermanCashHoliday(berlin_time);
  }

int Strategy_MinuteOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_SymbolSlot()
  {
   if(_Symbol == "GDAXI.DWX")
      return 0;
   if(strategy_allow_ports && _Symbol == "NDX.DWX")
      return 1;
   if(strategy_allow_ports && _Symbol == "WS30.DWX")
      return 2;
   return -1;
  }

ENUM_TIMEFRAMES Strategy_GateTimeframe()
  {
   if(strategy_timeframe_minutes == 5)
      return PERIOD_M5;
   return PERIOD_M15;
  }

bool Strategy_IsSupportedTimeframe()
  {
   if(strategy_timeframe_minutes == 5)
      return (_Period == PERIOD_M5);
   return (_Period == PERIOD_M15);
  }

bool Strategy_HasOpenPosition()
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

datetime Strategy_NextCalendarDay(const datetime berlin_time)
  {
   return Strategy_DateFloor(berlin_time) + 86400;
  }

bool Strategy_EntryDayAllowsNextCashOpen(const datetime berlin_now)
  {
   const int dow = Strategy_DayOfWeek(berlin_now);
   if(dow > 4)
      return false;

   datetime next_day = Strategy_NextCalendarDay(berlin_now);
   for(int i = 0; i < 4; ++i)
     {
      if(Strategy_IsRegularBerlinCashOpen(next_day))
         return true;
      const int next_dow = Strategy_DayOfWeek(next_day);
      if(next_dow == 6 || next_dow == 0)
         return false;
      next_day += 86400;
     }
   return false;
  }

double Strategy_MedianSpreadPoints()
  {
   if(strategy_spread_lookback_days <= 0 || strategy_spread_lookback_days > 64)
      return 0.0;

   const int bars_per_day = (strategy_timeframe_minutes == 5) ? 288 : 96;
   double values[64];
   int count = 0;
   for(int day = 1; day <= strategy_spread_lookback_days; ++day)
     {
      const int shift = day * bars_per_day;
      const long spread_i = iSpread(_Symbol, Strategy_GateTimeframe(), shift);
      if(spread_i <= 0)
         continue;
      values[count] = (double)spread_i;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_median_mult <= 0.0)
      return true;
   const double median_spread = Strategy_MedianSpreadPoints();
   if(median_spread <= 0.0)
      return true;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_median_mult);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_SymbolSlot() < 0)
      return true;
   if(!Strategy_IsSupportedTimeframe())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "UNGER_DAX_OVERNIGHT_BIAS";
   req.symbol_slot = Strategy_SymbolSlot();
   req.expiration_seconds = 0;

   if(req.symbol_slot < 0 || Strategy_HasOpenPosition())
      return false;

   const datetime berlin_now = Strategy_BrokerToBerlin(TimeCurrent());
   const int entry_minute = strategy_entry_hour_berlin * 60 + strategy_entry_minute_berlin;
   if(Strategy_MinuteOfDay(berlin_now) < entry_minute)
      return false;

   const int date_key = Strategy_DateKey(berlin_now);
   if(g_last_entry_date_key == date_key)
      return false;
   if(!Strategy_EntryDayAllowsNextCashOpen(berlin_now))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double entry = QM_EntryMarketPrice(QM_BUY);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.sl = NormalizeDouble(entry - strategy_atr_sl_mult * atr, _Digits);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   g_last_entry_date_key = date_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card default: fixed overnight hold; no trailing, pyramiding, or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime berlin_now = Strategy_BrokerToBerlin(TimeCurrent());
   if(!Strategy_IsRegularBerlinCashOpen(berlin_now))
      return false;

   const int exit_minute = strategy_exit_hour_berlin * 60 + strategy_exit_minute_berlin;
   if(Strategy_MinuteOfDay(berlin_now) < exit_minute)
      return false;

   const int date_key = Strategy_DateKey(berlin_now);
   if(g_last_exit_date_key == date_key)
      return false;

   g_last_exit_date_key = date_key;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(strategy_timeframe_minutes != 5 && strategy_timeframe_minutes != 15)
      return INIT_PARAMETERS_INCORRECT;
   if(strategy_entry_hour_berlin < 0 || strategy_entry_hour_berlin > 23)
      return INIT_PARAMETERS_INCORRECT;
   if(strategy_entry_minute_berlin < 0 || strategy_entry_minute_berlin > 59)
      return INIT_PARAMETERS_INCORRECT;
   if(strategy_exit_hour_berlin < 0 || strategy_exit_hour_berlin > 23)
      return INIT_PARAMETERS_INCORRECT;
   if(strategy_exit_minute_berlin < 0 || strategy_exit_minute_berlin > 59)
      return INIT_PARAMETERS_INCORRECT;
   if(strategy_atr_period < 2 || strategy_atr_sl_mult <= 0.0)
      return INIT_PARAMETERS_INCORRECT;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_1146\",\"card\":\"unger-dax-overnight-bias\"}");
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

   if(!QM_IsNewBar(_Symbol, Strategy_GateTimeframe()))
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
