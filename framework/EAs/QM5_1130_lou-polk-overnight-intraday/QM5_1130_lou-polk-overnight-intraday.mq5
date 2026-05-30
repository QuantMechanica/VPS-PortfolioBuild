#property strict
#property version   "5.0"
#property description "QM5_1130 Lou Polk Overnight Intraday"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 1130;
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
input int    strategy_timeframe_minutes     = 30;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 3.0;
input bool   strategy_skip_friday_entries   = true;
input bool   strategy_use_vol_regime_filter = true;
input int    strategy_vol_lookback_days     = 252;
input double strategy_vol_threshold_mult    = 1.5;
input int    strategy_entry_offset_minutes  = 0;
input int    strategy_exit_offset_minutes   = 0;
input int    strategy_max_spread_points     = 0;

int g_last_entry_date_key = 0;
int g_last_exit_date_key = 0;

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

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

int Strategy_YearOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
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

bool Strategy_SameDate(const datetime left, const datetime right)
  {
   return Strategy_DateFloor(left) == Strategy_DateFloor(right);
  }

bool Strategy_IsUsCashHoliday(const datetime local_time)
  {
   const datetime d = Strategy_DateFloor(local_time);
   const int y = Strategy_YearOf(d);
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
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 11, 4, 4)))
      return true;
   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 12, 25)))
      return true;
   return false;
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

int Strategy_SymbolSlot()
  {
   if(_Symbol == "NDX.DWX")
      return 0;
   if(_Symbol == "WS30.DWX")
      return 1;
   if(_Symbol == "SP500.DWX")
      return 2;
   if(_Symbol == "GDAXI.DWX")
      return 3;
   if(_Symbol == "UK100.DWX")
      return 4;
   return -1;
  }

bool Strategy_IsSupportedTimeframe()
  {
   if(strategy_timeframe_minutes == 60)
      return (_Period == PERIOD_H1);
   return (_Period == PERIOD_M30);
  }

int Strategy_LocalOffsetHours(const datetime utc)
  {
   if(_Symbol == "NDX.DWX" || _Symbol == "WS30.DWX" || _Symbol == "SP500.DWX")
      return QM_IsUSDSTUTC(utc) ? -4 : -5;
   if(_Symbol == "GDAXI.DWX")
      return Strategy_IsEuropeSummerUTC(utc) ? 2 : 1;
   if(_Symbol == "UK100.DWX")
      return Strategy_IsEuropeSummerUTC(utc) ? 1 : 0;
   return 0;
  }

datetime Strategy_BrokerToLocal(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + Strategy_LocalOffsetHours(utc) * 3600;
  }

bool Strategy_LocalSessionMinutes(int &open_minute, int &close_minute)
  {
   if(_Symbol == "NDX.DWX" || _Symbol == "WS30.DWX" || _Symbol == "SP500.DWX")
     {
      open_minute = 9 * 60 + 30;
      close_minute = 16 * 60;
      return true;
     }
   if(_Symbol == "GDAXI.DWX" || _Symbol == "UK100.DWX")
     {
      open_minute = 9 * 60;
      close_minute = 17 * 60 + 30;
      return true;
     }
   return false;
  }

bool Strategy_IsRegularSessionDay(const datetime local_time)
  {
   const int dow = Strategy_DayOfWeek(local_time);
   if(dow < 1 || dow > 5)
      return false;
   if(_Symbol == "NDX.DWX" || _Symbol == "WS30.DWX" || _Symbol == "SP500.DWX")
      return !Strategy_IsUsCashHoliday(local_time);
   return true;
  }

int Strategy_MinuteOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
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

bool Strategy_VolatilityAllowsEntry()
  {
   if(!strategy_use_vol_regime_filter)
      return true;

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   const int lookback = MathMax(strategy_atr_period + 1, strategy_vol_lookback_days);
   double sum = 0.0;
   int samples = 0;
   for(int shift = 2; shift < 2 + lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      sum += atr;
      ++samples;
     }

   if(samples < MathMax(20, strategy_atr_period))
      return false;

   const double avg_atr = sum / (double)samples;
   return (avg_atr > 0.0 && current_atr <= strategy_vol_threshold_mult * avg_atr);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_SymbolSlot() < 0)
      return true;
   if(!Strategy_IsSupportedTimeframe())
      return true;
   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
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
   req.reason = "LOU_POLK_OVERNIGHT_LONG";
   req.symbol_slot = Strategy_SymbolSlot();
   req.expiration_seconds = 0;

   if(req.symbol_slot < 0 || Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const datetime local_now = Strategy_BrokerToLocal(broker_now);
   if(!Strategy_IsRegularSessionDay(local_now))
      return false;
   if(strategy_skip_friday_entries && Strategy_DayOfWeek(local_now) == 5)
      return false;

   int open_minute = 0;
   int close_minute = 0;
   if(!Strategy_LocalSessionMinutes(open_minute, close_minute))
      return false;

   const int local_minute = Strategy_MinuteOfDay(local_now);
   const int entry_minute = close_minute - MathMax(0, strategy_entry_offset_minutes);
   if(local_minute < entry_minute)
      return false;

   const int date_key = Strategy_DateKey(local_now);
   if(g_last_entry_date_key == date_key)
      return false;
   if(!Strategy_VolatilityAllowsEntry())
      return false;

   const double entry = QM_EntryMarketPrice(QM_BUY);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
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
   // Card default: hold overnight only; no trailing, pyramiding, or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime local_now = Strategy_BrokerToLocal(TimeCurrent());
   if(!Strategy_IsRegularSessionDay(local_now))
      return false;

   int open_minute = 0;
   int close_minute = 0;
   if(!Strategy_LocalSessionMinutes(open_minute, close_minute))
      return false;

   const int exit_minute = open_minute + MathMax(0, strategy_exit_offset_minutes);
   if(Strategy_MinuteOfDay(local_now) < exit_minute)
      return false;

   const int date_key = Strategy_DateKey(local_now);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_1130\",\"card\":\"lou-polk-overnight-intraday\"}");
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

   const ENUM_TIMEFRAMES gate_tf = (strategy_timeframe_minutes == 60) ? PERIOD_H1 : PERIOD_M30;
   if(!QM_IsNewBar(_Symbol, gate_tf))
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
