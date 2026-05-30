#property strict
#property version   "5.0"
#property description "QM5_1144 Baur Gold Autumn Effect"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1144;
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
input string strategy_entry_months        = "9,11";
input bool   strategy_enable_october      = false;
input bool   strategy_half_month_hold     = false;
input int    strategy_atr_period_d1       = 14;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_entry_hour_broker   = 1;
input int    strategy_exit_hour_broker    = 20;
input bool   strategy_spread_filter_enabled = true;
input int    strategy_spread_days         = 20;
input double strategy_spread_median_mult  = 2.0;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

int g_last_entry_month_key = 0;
int g_last_exit_day_key    = 0;

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_MonthConfigured(const int month)
  {
   if(month == 10 && strategy_enable_october)
      return true;

   string parts[];
   const int count = StringSplit(strategy_entry_months, ',', parts);
   for(int i = 0; i < count; ++i)
     {
      StringTrimLeft(parts[i]);
      StringTrimRight(parts[i]);
      if((int)StringToInteger(parts[i]) == month)
         return true;
     }
   return false;
  }

bool Strategy_IsWeekday(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
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

int Strategy_DaysInMonth(const int year, const int month)
  {
   const int next_year = (month == 12) ? year + 1 : year;
   const int next_month = (month == 12) ? 1 : month + 1;
   MqlDateTime dt;
   TimeToStruct(Strategy_MakeDate(next_year, next_month, 1) - 86400, dt);
   return dt.day;
  }

int Strategy_LastWeekdayOfMonth(const int year, const int month)
  {
   for(int day = Strategy_DaysInMonth(year, month); day >= 1; --day)
     {
      if(Strategy_IsWeekday(Strategy_MakeDate(year, month, day)))
         return day;
     }
   return Strategy_DaysInMonth(year, month);
  }

bool Strategy_IsFirstTradingSessionOfMonth(const datetime broker_time)
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime previous_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || previous_d1 <= 0)
      return false;

   MqlDateTime now_dt;
   MqlDateTime current_dt;
   MqlDateTime previous_dt;
   TimeToStruct(broker_time, now_dt);
   TimeToStruct(current_d1, current_dt);
   TimeToStruct(previous_d1, previous_dt);

   return (current_dt.year == now_dt.year &&
           current_dt.mon == now_dt.mon &&
           previous_dt.mon != current_dt.mon);
  }

bool Strategy_IsExitSession(const datetime broker_time, const datetime opened_at)
  {
   MqlDateTime now_dt;
   MqlDateTime open_dt;
   TimeToStruct(broker_time, now_dt);
   TimeToStruct(opened_at, open_dt);

   if(now_dt.year != open_dt.year || now_dt.mon != open_dt.mon)
      return true;

   if(strategy_half_month_hold)
      return (now_dt.day >= 15 && now_dt.hour >= strategy_exit_hour_broker);

   const int last_day = Strategy_LastWeekdayOfMonth(now_dt.year, now_dt.mon);
   return (now_dt.day >= last_day && now_dt.hour >= strategy_exit_hour_broker);
  }

void Strategy_SortDouble(double &values[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }
  }

bool Strategy_SpreadAllowed()
  {
   if(!strategy_spread_filter_enabled)
      return true;
   if(strategy_spread_days <= 0 || strategy_spread_days > 64)
      return true;
   if(strategy_spread_median_mult <= 0.0)
      return false;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   double spreads[64];
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_days; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = (double)spread;
      ++count;
     }

   if(count < MathMin(10, strategy_spread_days))
      return true;

   Strategy_SortDouble(spreads, count);
   double median = 0.0;
   if((count % 2) == 1)
      median = spreads[count / 2];
   else
      median = 0.5 * (spreads[(count / 2) - 1] + spreads[count / 2]);

   return ((double)current_spread <= median * strategy_spread_median_mult);
  }

bool Strategy_HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
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
   if(_Period != PERIOD_H1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_entry_hour_broker < 0 || strategy_entry_hour_broker > 23)
      return true;
   if(strategy_exit_hour_broker < 0 || strategy_exit_hour_broker > 23)
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

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(!Strategy_MonthConfigured(dt.mon))
      return false;
   if(dt.hour < strategy_entry_hour_broker)
      return false;
   if(!Strategy_IsFirstTradingSessionOfMonth(broker_now))
      return false;

   const int month_key = Strategy_MonthKey(broker_now);
   if(g_last_entry_month_key == month_key)
      return false;
   g_last_entry_month_key = month_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowed())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   req.reason = "BAUR_GOLD_AUTUMN_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed ATR stop and calendar exits only.
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const int day_key = Strategy_DayKey(broker_now);
   if(g_last_exit_day_key == day_key)
      return false;

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

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at <= 0)
         continue;
      if(Strategy_IsExitSession(broker_now, opened_at))
        {
         g_last_exit_day_key = day_key;
         return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1144\",\"ea\":\"baur-gold-autumn-effect\"}");
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
