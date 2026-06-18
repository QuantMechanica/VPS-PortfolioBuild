#property strict
#property version   "5.0"
#property description "QM5_12411 Payday SP500 calendar anomaly"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12411;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_payday_day          = 15;
input int    strategy_entry_hour_broker   = 22;
input int    strategy_entry_minute_broker = 59;
input int    strategy_exit_hour_broker    = 22;
input int    strategy_exit_minute_broker  = 59;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_stop_mult       = 1.0;
input int    strategy_max_spread_points   = 0;

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_MinuteOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_IsAtOrAfterMinute(const datetime value,
                                const int hour_value,
                                const int minute_value)
  {
   if(hour_value < 0 || hour_value > 23 || minute_value < 0 || minute_value > 59)
      return false;
   return Strategy_MinuteOfDay(value) >= hour_value * 60 + minute_value;
  }

int Strategy_AdjustedPayday(const int year_value, const int month_value)
  {
   MqlDateTime payday;
   ZeroMemory(payday);
   payday.year = year_value;
   payday.mon = month_value;
   payday.day = strategy_payday_day;
   payday.hour = 0;
   payday.min = 0;
   payday.sec = 0;

   datetime payday_time = StructToTime(payday);
   if(payday_time <= 0)
      return -1;

   MqlDateTime resolved;
   TimeToStruct(payday_time, resolved);
   if(resolved.day_of_week == 6)
      return resolved.day - 1;
   if(resolved.day_of_week == 0)
      return resolved.day - 2;
   return resolved.day;
  }

bool Strategy_IsPaydayDate(const datetime broker_time)
  {
   MqlDateTime now_dt;
   TimeToStruct(broker_time, now_dt);
   if(now_dt.day_of_week == 0 || now_dt.day_of_week == 6)
      return false;

   const int adjusted_day = Strategy_AdjustedPayday(now_dt.year, now_dt.mon);
   if(adjusted_day <= 0)
      return false;

   return now_dt.day == adjusted_day;
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

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return false;
     }

   return true;
  }

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry.
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
   if(!Strategy_IsPaydayDate(broker_now))
      return false;
   if(!Strategy_IsAtOrAfterMinute(broker_now, strategy_entry_hour_broker, strategy_entry_minute_broker))
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_d1 <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr_d1, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = "PAYDAY_LONG_CLOSE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return req.sl > 0.0;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsAtOrAfterMinute(broker_now, strategy_exit_hour_broker, strategy_exit_minute_broker))
      return false;

   const int today_key = Strategy_DayKey(broker_now);
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
      if(opened_at > 0 && Strategy_DayKey(opened_at) != today_key)
         return true;
     }

   return false;
  }

// News Filter Hook.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12411_payday_sp500\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
