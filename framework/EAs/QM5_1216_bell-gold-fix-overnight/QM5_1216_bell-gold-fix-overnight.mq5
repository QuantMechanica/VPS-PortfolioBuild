#property strict
#property version   "5.0"
#property description "QM5_1216 Bell Gold London-Fix Overnight Hold"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1216;
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
input int    strategy_pm_fix_hour_london  = 15;
input int    strategy_pm_fix_min_london   = 0;
input int    strategy_am_fix_hour_london  = 10;
input int    strategy_am_fix_min_london   = 30;
input int    strategy_atr_period_h1       = 20;
input double strategy_atr_sl_mult         = 1.0;
input int    strategy_max_spread_points   = 300;
input int    strategy_missing_bar_grace_min = 15;
input int    strategy_min_h1_bars         = 80;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

int g_last_entry_date_key = 0;
int g_last_exit_date_key = 0;

int Strategy_ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
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

int Strategy_MinutesOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
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

datetime Strategy_ObservedUkFixedHoliday(const int year, const int month, const int day)
  {
   datetime actual = Strategy_MakeDate(year, month, day);
   const int dow = Strategy_DayOfWeek(actual);
   if(dow == 6)
      return actual + 2 * 86400;
   if(dow == 0)
      return actual + 86400;
   return actual;
  }

bool Strategy_SameDate(const datetime left, const datetime right)
  {
   return Strategy_DateFloor(left) == Strategy_DateFloor(right);
  }

bool Strategy_IsUkHoliday(const datetime london_time)
  {
   const datetime d = Strategy_DateFloor(london_time);
   MqlDateTime dt;
   TimeToStruct(d, dt);
   const int year = dt.year;
   const datetime easter = Strategy_EasterSunday(year);

   if(Strategy_SameDate(d, Strategy_ObservedUkFixedHoliday(year, 1, 1)))
      return true;
   if(Strategy_SameDate(d, easter - 2 * 86400))
      return true;
   if(Strategy_SameDate(d, easter + 86400))
      return true;
   if(Strategy_SameDate(d, Strategy_NthWeekdayOfMonth(year, 5, 1, 1)))
      return true;
   if(Strategy_SameDate(d, Strategy_LastWeekdayOfMonth(year, 5, 1)))
      return true;
   if(Strategy_SameDate(d, Strategy_LastWeekdayOfMonth(year, 8, 1)))
      return true;
   if(Strategy_SameDate(d, Strategy_ObservedUkFixedHoliday(year, 12, 25)))
      return true;
   if(Strategy_SameDate(d, Strategy_ObservedUkFixedHoliday(year, 12, 26)))
      return true;
   return false;
  }

bool Strategy_IsLondonSummerUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   const datetime start_utc = Strategy_LastWeekdayOfMonth(dt.year, 3, 0) + 1 * 3600;
   const datetime end_utc = Strategy_LastWeekdayOfMonth(dt.year, 10, 0) + 1 * 3600;
   return (utc_time >= start_utc && utc_time < end_utc);
  }

datetime Strategy_BrokerToLondon(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return utc_time + (Strategy_IsLondonSummerUTC(utc_time) ? 3600 : 0);
  }

int Strategy_PMFixMinute()
  {
   return Strategy_ClampInt(strategy_pm_fix_hour_london, 0, 23) * 60 +
          Strategy_ClampInt(strategy_pm_fix_min_london, 0, 59);
  }

int Strategy_AMFixMinute()
  {
   return Strategy_ClampInt(strategy_am_fix_hour_london, 0, 23) * 60 +
          Strategy_ClampInt(strategy_am_fix_min_london, 0, 59);
  }

bool Strategy_CrossedMinute(const datetime prev_broker, const datetime now_broker, const int target_minute)
  {
   const datetime prev_london = Strategy_BrokerToLondon(prev_broker);
   const datetime now_london = Strategy_BrokerToLondon(now_broker);
   const int prev_key = Strategy_DateKey(prev_london);
   const int now_key = Strategy_DateKey(now_london);
   const int prev_min = Strategy_MinutesOfDay(prev_london);
   const int now_min = Strategy_MinutesOfDay(now_london);

   if(prev_key == now_key)
      return (prev_min < target_minute && now_min >= target_minute);
   return (now_min >= target_minute);
  }

bool Strategy_IsTradingWeekday(const datetime london_time)
  {
   const int dow = Strategy_DayOfWeek(london_time);
   return (dow >= 1 && dow <= 5);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool Strategy_HasUsableFixBars()
  {
   const datetime bar0 = iTime(_Symbol, PERIOD_M5, 0);
   const datetime bar1 = iTime(_Symbol, PERIOD_M5, 1);
   const datetime bar2 = iTime(_Symbol, PERIOD_M5, 2);
   if(bar0 <= 0 || bar1 <= 0 || bar2 <= 0)
      return false;

   const int max_gap_seconds = MathMax(5, strategy_missing_bar_grace_min) * 60;
   if((bar0 - bar1) > max_gap_seconds)
      return false;
   if((bar1 - bar2) > max_gap_seconds)
      return false;
   return true;
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
   if(_Period != PERIOD_M5)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_atr_period_h1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(Bars(_Symbol, PERIOD_M5) < 100 || Bars(_Symbol, PERIOD_H1) < strategy_min_h1_bars)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "BELL_GOLD_FIX_OVERNIGHT_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime open_time = 0;
   if(Strategy_HasOpenPosition(open_time) || !Strategy_SpreadAllowsEntry())
      return false;

   const datetime bar_now = iTime(_Symbol, PERIOD_M5, 0);
   const datetime bar_prev = iTime(_Symbol, PERIOD_M5, 1);
   if(bar_now <= 0 || bar_prev <= 0)
      return false;

   const datetime london_now = Strategy_BrokerToLondon(bar_now);
   const int entry_date_key = Strategy_DateKey(london_now);
   if(g_last_entry_date_key == entry_date_key)
      return false;
   if(!Strategy_IsTradingWeekday(london_now) || Strategy_IsUkHoliday(london_now))
      return false;
   if(!Strategy_HasUsableFixBars())
      return false;
   if(!Strategy_CrossedMinute(bar_prev, bar_now, Strategy_PMFixMinute()))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, MathMax(1, strategy_atr_period_h1), 1);
   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   const double sl = entry - atr * strategy_atr_sl_mult;
   if(!Strategy_StopDistanceAllowed(entry, sl))
      return false;

   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   g_last_entry_date_key = entry_date_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_HasOpenPosition(open_time))
      return false;

   const datetime bar_now = iTime(_Symbol, PERIOD_M5, 0);
   const datetime bar_prev = iTime(_Symbol, PERIOD_M5, 1);
   if(bar_now <= 0 || bar_prev <= 0)
      return false;

   const datetime open_london = Strategy_BrokerToLondon(open_time);
   const datetime now_london = Strategy_BrokerToLondon(bar_now);
   const int now_key = Strategy_DateKey(now_london);
   if(now_key == Strategy_DateKey(open_london) || g_last_exit_date_key == now_key)
      return false;
   if(!Strategy_CrossedMinute(bar_prev, bar_now, Strategy_AMFixMinute()))
      return false;

   g_last_exit_date_key = now_key;
   return true;
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
