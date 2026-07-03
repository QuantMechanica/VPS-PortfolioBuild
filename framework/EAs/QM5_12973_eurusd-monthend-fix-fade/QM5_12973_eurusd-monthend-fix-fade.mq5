#property strict
#property version   "5.0"
#property description "QM5_12973 EURUSD/GBPUSD month-end WMR-fix fade"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12973;
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
input int    strategy_fix_start_london_hhmm = 1500;
input int    strategy_fix_end_london_hhmm   = 1600;
input int    strategy_entry_after_hhmm      = 1605;
input int    strategy_entry_until_hhmm      = 1700;
input int    strategy_exit_london_hhmm      = 1800;
input int    strategy_daily_atr_period      = 14;
input int    strategy_m5_atr_period         = 14;
input double strategy_trigger_atr_frac      = 0.5;
input double strategy_stop_atr_mult         = 1.0;
input int    strategy_max_spread_points     = 0;

int g_last_entry_london_day_key = 0;

int Strategy_HHMMToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

int Strategy_HHMM(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4) == 0 && (year % 100) != 0) || ((year % 400) == 0);
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

int Strategy_DayOfWeekForDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = 12;
   dt.min = 0;
   dt.sec = 0;
   MqlDateTime out;
   TimeToStruct(StructToTime(dt), out);
   return out.day_of_week;
  }

int Strategy_LastSundayOfMonth(const int year, const int month)
  {
   for(int day = Strategy_DaysInMonth(year, month); day >= 1; --day)
     {
      if(Strategy_DayOfWeekForDate(year, month, day) == 0)
         return day;
     }
   return 0;
  }

datetime Strategy_UKDSTStartUTC(const int year)
  {
   const int day = Strategy_LastSundayOfMonth(year, 3);
   if(day <= 0)
      return 0;
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = 3;
   dt.day = day;
   dt.hour = 1;
   return StructToTime(dt);
  }

datetime Strategy_UKDSTEndUTC(const int year)
  {
   const int day = Strategy_LastSundayOfMonth(year, 10);
   if(day <= 0)
      return 0;
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = 10;
   dt.day = day;
   dt.hour = 1;
   return StructToTime(dt);
  }

bool Strategy_IsUKDSTUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   const datetime start_utc = Strategy_UKDSTStartUTC(dt.year);
   const datetime end_utc = Strategy_UKDSTEndUTC(dt.year);
   if(start_utc <= 0 || end_utc <= 0)
      return false;
   return (utc_time >= start_utc && utc_time < end_utc);
  }

datetime Strategy_BrokerToLondon(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return utc_time + (Strategy_IsUKDSTUTC(utc_time) ? 3600 : 0);
  }

bool Strategy_IsLastWeekdayOfMonth(const datetime london_time)
  {
   MqlDateTime dt;
   TimeToStruct(london_time, dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;

   const int days = Strategy_DaysInMonth(dt.year, dt.mon);
   for(int day = dt.day + 1; day <= days; ++day)
     {
      const int dow = Strategy_DayOfWeekForDate(dt.year, dt.mon, day);
      if(dow != 0 && dow != 6)
         return false;
     }
   return true;
  }

int Strategy_SlotForSymbol()
  {
   if(_Symbol == "EURUSD.DWX")
      return 0;
   if(_Symbol == "GBPUSD.DWX")
      return 1;
   return -1;
  }

bool Strategy_IsTarget()
  {
   const int slot = Strategy_SlotForSymbol();
   if(slot < 0)
      return false;
   return (_Period == PERIOD_M5 && qm_magic_slot_offset == slot);
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

bool Strategy_LondonTimeInWindow(const datetime broker_time, const int start_hhmm, const int end_hhmm)
  {
   const int start_min = Strategy_HHMMToMinutes(start_hhmm);
   const int end_min = Strategy_HHMMToMinutes(end_hhmm);
   if(start_min < 0 || end_min < 0)
      return false;
   const datetime london_time = Strategy_BrokerToLondon(broker_time);
   MqlDateTime dt;
   TimeToStruct(london_time, dt);
   const int now_min = dt.hour * 60 + dt.min;
   if(start_min <= end_min)
      return (now_min >= start_min && now_min < end_min);
   return (now_min >= start_min || now_min < end_min);
  }

int Strategy_FindLondonBarShift(const int london_day_key, const int london_hhmm, const int max_back_bars)
  {
   for(int shift = 1; shift <= max_back_bars; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_M5, shift); // perf-allowed: bounded M5 clock lookup for the WMR-fix window.
      if(bar_time <= 0)
         break;
      const datetime london_bar_time = Strategy_BrokerToLondon(bar_time);
      if(Strategy_DateKey(london_bar_time) == london_day_key && Strategy_HHMM(london_bar_time) == london_hhmm)
         return shift;
     }
   return -1;
  }

bool Strategy_LoadFixMove(const int london_day_key, double &move)
  {
   const int start_shift = Strategy_FindLondonBarShift(london_day_key, strategy_fix_start_london_hhmm, 400);
   const int end_shift = Strategy_FindLondonBarShift(london_day_key, strategy_fix_end_london_hhmm, 400);
   if(start_shift < 0 || end_shift < 0)
      return false;

   const double start_close = iClose(_Symbol, PERIOD_M5, start_shift); // perf-allowed: two exact M5 closes define the structural fix move.
   const double end_close = iClose(_Symbol, PERIOD_M5, end_shift);     // perf-allowed: two exact M5 closes define the structural fix move.
   if(start_close <= 0.0 || end_close <= 0.0)
      return false;

   move = end_close - start_close;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(Strategy_HHMMToMinutes(strategy_fix_start_london_hhmm) < 0)
      return true;
   if(Strategy_HHMMToMinutes(strategy_fix_end_london_hhmm) < 0)
      return true;
   if(Strategy_HHMMToMinutes(strategy_entry_after_hhmm) < 0)
      return true;
   if(Strategy_HHMMToMinutes(strategy_entry_until_hhmm) < 0)
      return true;
   if(Strategy_HHMMToMinutes(strategy_exit_london_hhmm) < 0)
      return true;
   if(strategy_daily_atr_period <= 0 || strategy_m5_atr_period <= 0)
      return true;
   if(strategy_trigger_atr_frac <= 0.0 || strategy_stop_atr_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "MONTHEND_WMR_FIX_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition() || Strategy_WideSpread())
      return false;

   const datetime broker_now = TimeCurrent();
   const datetime london_now = Strategy_BrokerToLondon(broker_now);
   const int london_day_key = Strategy_DateKey(london_now);
   if(london_day_key <= 0 || london_day_key == g_last_entry_london_day_key)
      return false;
   if(!Strategy_IsLastWeekdayOfMonth(london_now))
      return false;
   if(!Strategy_LondonTimeInWindow(broker_now, strategy_entry_after_hhmm, strategy_entry_until_hhmm))
      return false;

   double fix_move = 0.0;
   if(!Strategy_LoadFixMove(london_day_key, fix_move))
      return false;

   const double daily_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_daily_atr_period, 1);
   if(daily_atr <= 0.0 || MathAbs(fix_move) < strategy_trigger_atr_frac * daily_atr)
      return false;

   const QM_OrderType side = (fix_move > 0.0) ? QM_SELL : QM_BUY;
   const double entry_price = QM_EntryMarketPrice(side);
   const double m5_atr = QM_ATR(_Symbol, PERIOD_M5, strategy_m5_atr_period, 1);
   if(entry_price <= 0.0 || m5_atr <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry_price, m5_atr, strategy_stop_atr_mult);
   if(req.sl <= 0.0)
      return false;

   g_last_entry_london_day_key = london_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   return Strategy_LondonTimeInWindow(TimeCurrent(), strategy_exit_london_hhmm, 2359);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12973\",\"ea\":\"eurusd-monthend-fix-fade\"}");
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
