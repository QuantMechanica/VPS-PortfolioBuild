#property strict
#property version   "5.0"
#property description "QM5_1160 Quantpedia Gold Christmas Drift"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1160;
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
input int    strategy_entry_offset_trading_days = -2;
input int    strategy_exit_offset_trading_days  = 5;
input int    strategy_atr_period_d1             = 20;
input double strategy_atr_sl_mult               = 2.0;
input int    strategy_min_d1_bars               = 60;
input int    strategy_entry_hour_broker         = 20;
input int    strategy_exit_hour_broker          = 20;
input int    strategy_max_spread_points         = 300;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

int g_last_entry_year = 0;
int g_last_exit_day_key = 0;

datetime Strategy_Date(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   return StructToTime(dt);
  }

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_Year(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

datetime Strategy_ObservedHoliday(const int year, const int month, const int day)
  {
   const datetime actual = Strategy_Date(year, month, day);
   const int dow = Strategy_DayOfWeek(actual);
   if(dow == 6)
      return actual - 86400;
   if(dow == 0)
      return actual + 86400;
   return actual;
  }

bool Strategy_IsObservedHoliday(const datetime date_value)
  {
   const int key = Strategy_DayKey(date_value);
   const int year = Strategy_Year(date_value);
   if(key == Strategy_DayKey(Strategy_ObservedHoliday(year, 1, 1)))
      return true;
   if(key == Strategy_DayKey(Strategy_ObservedHoliday(year + 1, 1, 1)))
      return true;
   if(key == Strategy_DayKey(Strategy_ObservedHoliday(year, 12, 25)))
      return true;
   return false;
  }

bool Strategy_IsUSTradingDay(const datetime date_value)
  {
   const int dow = Strategy_DayOfWeek(date_value);
   if(dow == 0 || dow == 6)
      return false;
   return !Strategy_IsObservedHoliday(date_value);
  }

datetime Strategy_ChristmasDay(const int year)
  {
   return Strategy_Date(year, 12, 25);
  }

datetime Strategy_TradingDayOffsetFromChristmas(const int year, const int offset)
  {
   datetime cursor = Strategy_ChristmasDay(year);
   const int step = (offset < 0) ? -1 : 1;
   int remaining = MathAbs(offset);
   while(remaining > 0)
     {
      cursor += step * 86400;
      if(Strategy_IsUSTradingDay(cursor))
         --remaining;
     }
   return cursor;
  }

bool Strategy_SameDate(const datetime a, const datetime b)
  {
   return Strategy_DayKey(a) == Strategy_DayKey(b);
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
   if(strategy_entry_offset_trading_days >= 0)
      return true;
   if(strategy_exit_offset_trading_days <= 0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_min_d1_bars < 60)
      return true;
   if(strategy_entry_hour_broker < 0 || strategy_entry_hour_broker > 23)
      return true;
   if(strategy_exit_hour_broker < 0 || strategy_exit_hour_broker > 23)
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

   if(Bars(_Symbol, PERIOD_D1) < strategy_min_d1_bars)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime now_dt;
   TimeToStruct(broker_now, now_dt);
   if(now_dt.mon != 12 || now_dt.hour < strategy_entry_hour_broker)
      return false;
   if(g_last_entry_year == now_dt.year)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const datetime entry_day = Strategy_TradingDayOffsetFromChristmas(now_dt.year, strategy_entry_offset_trading_days);
   if(!Strategy_SameDate(broker_now, entry_day))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   req.reason = "QM5_1160_GOLD_CHRISTMAS_D2_LONG";
   g_last_entry_year = now_dt.year;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed ATR stop and mandatory calendar exit only.
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime now_dt;
   TimeToStruct(broker_now, now_dt);
   if(now_dt.hour < strategy_exit_hour_broker)
      return false;

   const int current_day_key = Strategy_DayKey(broker_now);
   if(g_last_exit_day_key == current_day_key)
      return false;

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

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at <= 0)
         continue;

      const int christmas_year = Strategy_Year(opened_at);
      const datetime exit_day = Strategy_TradingDayOffsetFromChristmas(christmas_year, strategy_exit_offset_trading_days);
      if(current_day_key >= Strategy_DayKey(exit_day))
        {
         g_last_exit_day_key = current_day_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1160\",\"ea\":\"qp-gold-christmas-drift\"}");
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
