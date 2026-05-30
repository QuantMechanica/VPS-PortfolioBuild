#property strict
#property version   "5.0"
#property description "QM5_1180 Quantpedia Composite Seasonal Calendar - SP500"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 1180;
input int    qm_magic_slot_offset           = 0;
input uint   qm_rng_seed                    = 42;

input group "Risk"
input double RISK_PERCENT                   = 0.0;
input double RISK_FIXED                     = 1000.0;
input double PORTFOLIO_WEIGHT               = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours        = 336;
input string qm_news_min_impact             = "high";
input QM_NewsMode qm_news_mode_legacy       = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = true;
input int    qm_friday_close_hour_broker    = 21;

input group "Stress"
input double qm_stress_reject_probability   = 0.0;

input group "Strategy"
input int    strategy_sma_period_d1         = 200;
input int    strategy_min_d1_closes         = 260;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 2.0;
input bool   strategy_use_atr_stop          = true;
input int    strategy_max_hold_trading_days = 10;
input double strategy_spread_median_mult    = 3.0;
input int    strategy_spread_lookback_days  = 20;

datetime g_last_spread_d1_bar = 0;
double   g_cached_median_spread = 0.0;
int      g_last_entry_date_key = 0;
int      g_last_exit_date_key = 0;

const int FOMC_DATE_COUNT = 72;
int g_fomc_dates[72] =
  {
   20180131, 20180321, 20180502, 20180613, 20180801, 20180926, 20181108, 20181219,
   20190130, 20190320, 20190501, 20190619, 20190731, 20190918, 20191030, 20191211,
   20200129, 20200429, 20200610, 20200729, 20200916, 20201105, 20201216,
   20210127, 20210317, 20210428, 20210616, 20210728, 20210922, 20211103, 20211215,
   20220126, 20220316, 20220504, 20220615, 20220727, 20220921, 20221102, 20221214,
   20230201, 20230322, 20230503, 20230614, 20230726, 20230920, 20231101, 20231213,
   20240131, 20240320, 20240501, 20240612, 20240731, 20240918, 20241107, 20241218,
   20250129, 20250319, 20250507, 20250618, 20250730, 20250917, 20251029, 20251210,
   20260128, 20260318, 20260429, 20260617, 20260729, 20260916, 20261028, 20261209
  };

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
   if(value <= 0)
      return 0;
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

   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 1, 1))) return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 1, 1, 3))) return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 2, 1, 3))) return true;
   if(Strategy_SameDate(d, Strategy_EasterSunday(y) - 2 * 86400)) return true;
   if(Strategy_SameDate(d, Strategy_LastWeekdayOfMonth(y, 5, 1))) return true;
   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 6, 19))) return true;
   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 7, 4))) return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 9, 1, 1))) return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 11, 2, 1))) return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(y, 11, 4, 4))) return true;
   if(Strategy_SameDate(d, Strategy_ObservedFixedHoliday(y, 12, 25))) return true;
   return false;
  }

bool Strategy_IsRegularUsCashDay(const datetime value)
  {
   const int dow = Strategy_DayOfWeek(value);
   if(dow < 1 || dow > 5)
      return false;
   return !Strategy_IsUsCashHoliday(value);
  }

datetime Strategy_PrevTradingDay(datetime d)
  {
   d = Strategy_DateFloor(d) - 86400;
   for(int i = 0; i < 14; ++i)
     {
      if(Strategy_IsRegularUsCashDay(d))
         return d;
      d -= 86400;
     }
   return 0;
  }

datetime Strategy_NextTradingDay(datetime d)
  {
   d = Strategy_DateFloor(d) + 86400;
   for(int i = 0; i < 14; ++i)
     {
      if(Strategy_IsRegularUsCashDay(d))
         return d;
      d += 86400;
     }
   return 0;
  }

datetime Strategy_LastTradingDayOfMonth(const int year, const int month)
  {
   datetime found = 0;
   for(int day = 1; day <= 31; ++day)
     {
      const datetime candidate = Strategy_MakeDate(year, month, day);
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(Strategy_IsRegularUsCashDay(candidate))
         found = Strategy_DateFloor(candidate);
     }
   return found;
  }

datetime Strategy_FirstTradingDayOfMonth(const int year, const int month)
  {
   for(int day = 1; day <= 10; ++day)
     {
      const datetime candidate = Strategy_MakeDate(year, month, day);
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(Strategy_IsRegularUsCashDay(candidate))
         return Strategy_DateFloor(candidate);
     }
   return 0;
  }

bool Strategy_TurnOfMonthActive(const datetime d)
  {
   MqlDateTime dt;
   TimeToStruct(d, dt);
   if(Strategy_SameDate(d, Strategy_LastTradingDayOfMonth(dt.year, dt.mon)))
      return true;
   if(Strategy_SameDate(d, Strategy_FirstTradingDayOfMonth(dt.year, dt.mon)))
      return true;
   return false;
  }

bool Strategy_FomcActive(const datetime d)
  {
   const int today_key = Strategy_DateKey(d);
   for(int i = 0; i < FOMC_DATE_COUNT; ++i)
     {
      const datetime meeting = Strategy_MakeDate(g_fomc_dates[i] / 10000, (g_fomc_dates[i] / 100) % 100, g_fomc_dates[i] % 100);
      const int start_key = Strategy_DateKey(Strategy_PrevTradingDay(meeting));
      const int end_key = Strategy_DateKey(Strategy_NextTradingDay(meeting));
      if(today_key == start_key || today_key == g_fomc_dates[i] || today_key == end_key)
         return true;
     }
   return false;
  }

bool Strategy_OptionExpirationActive(const datetime d)
  {
   MqlDateTime dt;
   TimeToStruct(d, dt);
   const datetime second_saturday = Strategy_NthWeekdayOfMonth(dt.year, dt.mon, 6, 2);
   const datetime third_friday = Strategy_NthWeekdayOfMonth(dt.year, dt.mon, 5, 3);
   if(second_saturday <= 0 || third_friday <= 0)
      return false;
   const datetime start = second_saturday - 86400;
   const datetime end = third_friday - 86400;
   return (Strategy_DateFloor(d) >= Strategy_DateFloor(start) && Strategy_DateFloor(d) <= Strategy_DateFloor(end) &&
           Strategy_IsRegularUsCashDay(d));
  }

bool Strategy_PaydayActive(const datetime d)
  {
   MqlDateTime dt;
   TimeToStruct(d, dt);
   datetime payday = Strategy_MakeDate(dt.year, dt.mon, 15);
   for(int i = 0; i < 10; ++i)
     {
      if(Strategy_IsRegularUsCashDay(payday))
         return Strategy_SameDate(d, payday);
      payday += 86400;
     }
   return false;
  }

bool Strategy_CalendarActive(const datetime d)
  {
   return Strategy_TurnOfMonthActive(d) || Strategy_FomcActive(d) ||
          Strategy_OptionExpirationActive(d) || Strategy_PaydayActive(d);
  }

void Strategy_RefreshMedianSpread()
  {
   const datetime d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(d1 <= 0 || d1 == g_last_spread_d1_bar)
      return;

   g_last_spread_d1_bar = d1;
   g_cached_median_spread = 0.0;
   const int lookback = MathMax(1, strategy_spread_lookback_days);
   double values[];
   ArrayResize(values, lookback);
   int samples = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const int spread_points = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread_points <= 0)
         continue;
      values[samples] = (double)spread_points;
      ++samples;
     }
   if(samples <= 0)
      return;
   ArrayResize(values, samples);
   ArraySort(values);
   const int mid = samples / 2;
   g_cached_median_spread = ((samples % 2) == 1) ? values[mid] : (values[mid - 1] + values[mid]) * 0.5;
  }

bool Strategy_SpreadAllowsTrade()
  {
   if(strategy_spread_median_mult <= 0.0)
      return true;
   Strategy_RefreshMedianSpread();
   if(g_cached_median_spread <= 0.0)
      return true;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= strategy_spread_median_mult * g_cached_median_spread);
  }

bool Strategy_GetOurPosition(ulong &ticket, datetime &open_time)
  {
   ticket = 0;
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_HasWarmup()
  {
   if(strategy_sma_period_d1 <= 0 || strategy_min_d1_closes < strategy_sma_period_d1)
      return false;
   int valid_closes = 0;
   const int max_scan = MathMax(strategy_min_d1_closes + 10, strategy_sma_period_d1 + 10);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      if(iClose(_Symbol, PERIOD_D1, shift) > 0.0)
         ++valid_closes;
      if(valid_closes >= strategy_min_d1_closes)
         return true;
     }
   return false;
  }

bool Strategy_CloseAboveSma()
  {
   if(!Strategy_HasWarmup())
      return false;
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double sma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period_d1, 1);
   if(close1 <= 0.0 || sma1 <= 0.0)
      return false;
   return close1 > sma1;
  }

int Strategy_CompletedD1BarsSince(const datetime start_time)
  {
   if(start_time <= 0)
      return 0;
   int count = 0;
   for(int shift = 1; shift < 250; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift);
      if(bar_time <= 0)
         break;
      if(bar_time > start_time)
         ++count;
      else
         break;
     }
   return count;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "SP500.DWX")
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_SpreadAllowsTrade())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QP_COMPOSITE_SEASONALITY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   datetime open_time = 0;
   if(Strategy_GetOurPosition(ticket, open_time))
      return false;

   const datetime signal_day = Strategy_DateFloor(iTime(_Symbol, PERIOD_D1, 1));
   const int date_key = Strategy_DateKey(signal_day);
   if(date_key <= 0 || g_last_entry_date_key == date_key)
      return false;
   if(!Strategy_CalendarActive(signal_day))
      return false;
   if(!Strategy_CloseAboveSma())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   if(strategy_use_atr_stop)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
      if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
         return false;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;
     }

   req.price = ask;
   g_last_entry_date_key = date_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed initial ATR stop only; the no-stop variant disables it via setfile.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime open_time = 0;
   if(!Strategy_GetOurPosition(ticket, open_time))
      return false;

   const datetime signal_day = Strategy_DateFloor(iTime(_Symbol, PERIOD_D1, 1));
   const int date_key = Strategy_DateKey(signal_day);
   if(date_key <= 0 || g_last_exit_date_key == date_key)
      return false;

   if(!Strategy_CalendarActive(signal_day) || !Strategy_CloseAboveSma())
     {
      g_last_exit_date_key = date_key;
      return true;
     }

   if(strategy_max_hold_trading_days > 0 && Strategy_CompletedD1BarsSince(open_time) >= strategy_max_hold_trading_days)
     {
      g_last_exit_date_key = date_key;
      return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1180\",\"ea\":\"qp-composite-seasonality\"}");
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
