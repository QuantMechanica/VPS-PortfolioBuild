#property strict
#property version   "5.0"
#property description "QM5_1140 Quantpedia SP500 MA10 Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 1140;
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
input int    strategy_sma_period_d1         = 10;
input int    strategy_min_d1_closes         = 60;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 2.0;
input double strategy_spread_median_mult    = 3.0;
input int    strategy_spread_lookback_days  = 20;
input bool   strategy_fixed_hold_enabled    = false;
input int    strategy_fixed_hold_days       = 3;
input int    strategy_entry_hour_ny         = 9;
input int    strategy_entry_minute_ny       = 30;
input int    strategy_safety_exit_hour_ny   = 15;
input int    strategy_safety_exit_minute_ny = 55;

datetime g_last_spread_m30_bar = 0;
double   g_cached_median_spread = 0.0;
int      g_last_entry_date_key = 0;
int      g_last_exit_date_key = 0;

int Strategy_DateKey(const datetime t)
  {
   if(t <= 0)
      return 0;
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

bool Strategy_IsRegularUsCashDay(const datetime broker_time)
  {
   const datetime ny_time = Strategy_BrokerToNewYork(broker_time);
   const int dow = Strategy_DayOfWeek(ny_time);
   if(dow < 1 || dow > 5)
      return false;
   if(Strategy_IsUsCashHoliday(ny_time))
      return false;
   return true;
  }

bool Strategy_IsSupportedSymbol()
  {
   return (_Symbol == "SP500.DWX" || _Symbol == "NDX.DWX" || _Symbol == "WS30.DWX");
  }

bool Strategy_IsSupportedTimeframe()
  {
   return (_Period == PERIOD_M15);
  }

bool Strategy_IsCashOpenBar(const datetime broker_bar_time)
  {
   if(broker_bar_time <= 0)
      return false;

   MqlDateTime ny;
   TimeToStruct(Strategy_BrokerToNewYork(broker_bar_time), ny);
   return (ny.hour == strategy_entry_hour_ny && ny.min == strategy_entry_minute_ny);
  }

bool Strategy_IsSafetyExitTime(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;

   MqlDateTime ny;
   TimeToStruct(Strategy_BrokerToNewYork(broker_time), ny);
   if(ny.hour > strategy_safety_exit_hour_ny)
      return true;
   if(ny.hour == strategy_safety_exit_hour_ny && ny.min >= strategy_safety_exit_minute_ny)
      return true;
   return false;
  }

void Strategy_RefreshMedianSpread()
  {
   const datetime m30 = iTime(_Symbol, PERIOD_M30, 0);
   if(m30 <= 0 || m30 == g_last_spread_m30_bar)
      return;

   g_last_spread_m30_bar = m30;
   g_cached_median_spread = 0.0;

   const int lookback_bars = MathMax(1, strategy_spread_lookback_days) * 48;
   double values[];
   ArrayResize(values, lookback_bars);
   int samples = 0;

   for(int shift = 1; shift <= lookback_bars; ++shift)
     {
      const int spread_points = iSpread(_Symbol, PERIOD_M30, shift);
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
   if((samples % 2) == 1)
      g_cached_median_spread = values[mid];
   else
      g_cached_median_spread = (values[mid - 1] + values[mid]) * 0.5;
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
   if(strategy_sma_period_d1 <= 0 || strategy_min_d1_closes < strategy_sma_period_d1 ||
      strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   int valid_closes = 0;
   const int max_scan = MathMax(strategy_min_d1_closes + strategy_sma_period_d1 + 5, 90);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const double close = iClose(_Symbol, PERIOD_D1, shift);
      if(close > 0.0)
         ++valid_closes;
      if(valid_closes >= strategy_min_d1_closes)
         return true;
     }

   return false;
  }

bool Strategy_CrossedAboveSma()
  {
   if(!Strategy_HasWarmup())
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double close2 = iClose(_Symbol, PERIOD_D1, 2);
   const double sma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period_d1, 1);
   const double sma2 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period_d1, 2);

   if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0)
      return false;

   return (close1 > sma1 && close2 <= sma2);
  }

bool Strategy_CrossedBelowSma()
  {
   if(!Strategy_HasWarmup())
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double close2 = iClose(_Symbol, PERIOD_D1, 2);
   const double sma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period_d1, 1);
   const double sma2 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period_d1, 2);

   if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0)
      return true;

   return (close1 < sma1 && close2 >= sma2);
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
   if(!Strategy_IsSupportedSymbol())
      return true;
   if(!Strategy_IsSupportedTimeframe())
      return true;
   if(!Strategy_IsRegularUsCashDay(TimeCurrent()))
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime bar_time = iTime(_Symbol, PERIOD_M15, 0);
   if(!Strategy_IsCashOpenBar(bar_time))
      return false;

   const int date_key = Strategy_DateKey(Strategy_BrokerToNewYork(bar_time));
   if(date_key <= 0 || g_last_entry_date_key == date_key)
      return false;

   ulong ticket = 0;
   datetime open_time = 0;
   if(Strategy_GetOurPosition(ticket, open_time))
      return false;

   if(!Strategy_CrossedAboveSma())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   req.price = ask;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   req.reason = "QP_SP500_MA10_BREAKOUT";
   g_last_entry_date_key = date_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial close.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime open_time = 0;
   if(!Strategy_GetOurPosition(ticket, open_time))
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_M15, 0);
   const int date_key = Strategy_DateKey(Strategy_BrokerToNewYork(bar_time));
   if(date_key <= 0 || g_last_exit_date_key == date_key)
      return false;

   if(strategy_fixed_hold_enabled)
     {
      if(Strategy_CompletedD1BarsSince(open_time) < MathMax(1, strategy_fixed_hold_days))
         return false;
      if(Strategy_IsSafetyExitTime(TimeCurrent()) || Strategy_IsCashOpenBar(bar_time))
        {
         g_last_exit_date_key = date_key;
         return true;
        }
      return false;
     }

   if(!Strategy_IsCashOpenBar(bar_time))
      return false;

   if(Strategy_CrossedBelowSma())
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

   SymbolSelect(_Symbol, true);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1140\",\"ea\":\"qp-sp500-ma10-breakout\"}");
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
