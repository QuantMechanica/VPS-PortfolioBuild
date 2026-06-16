#property strict
#property version   "5.0"
#property description "QM5_1158 French Weekend Effect (Avoid-Monday Index Long)"
// rework v2 2026-06-16 — add Mon-Fri weekday + full-day session fallback when SymbolInfoSessionTrade reports no schedule (DWX custom symbols return no sessions in tester) so entry/exit fire instead of 0 trades

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1158;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_day_of_week       = 2;
input int    strategy_latest_entry_day        = 4;
input int    strategy_exit_day_of_week        = 5;
input int    strategy_fallback_exit_day       = 4;
input int    strategy_entry_window_minutes    = 90;
input int    strategy_exit_before_close_min   = 30;
input int    strategy_atr_period              = 14;
input double strategy_atr_stop_mult           = 3.0;
input bool   strategy_block_news_wed_fri      = true;
input bool   strategy_require_m30_execution   = true;
input int    strategy_max_spread_points       = 0;

int g_last_entry_week_key = -1;

datetime Strategy_DateFloor(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_WeekKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   int days_from_monday = dt.day_of_week - 1;
   if(days_from_monday < 0)
      days_from_monday = 6;

   const datetime monday = Strategy_DateFloor(value) - (days_from_monday * 86400);
   MqlDateTime md;
   TimeToStruct(monday, md);
   return (md.year * 1000) + md.day_of_year;
  }

int Strategy_MinuteOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.hour * 60) + dt.min;
  }

int Strategy_SessionMinute(const datetime session_value)
  {
   long seconds = (long)session_value;
   seconds = seconds % 86400;
   if(seconds < 0)
      seconds += 86400;
   return (int)(seconds / 60);
  }

bool Strategy_HasScheduledSession(const int day_of_week)
  {
   datetime session_from = 0;
   datetime session_to = 0;
   for(uint session = 0; session < 10; ++session)
     {
      if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)day_of_week, session, session_from, session_to))
         return true;
     }
   // Fallback: DWX custom index symbols report no session schedule in the
   // tester; treat any weekday Mon-Fri as a tradeable session (matches siblings
   // QM5_1100 / QM5_10888 / QM5_1124). Without this, entry/exit never fire.
   return (day_of_week >= 1 && day_of_week <= 5);
  }

bool Strategy_SessionBounds(const int day_of_week, int &start_minute, int &close_minute)
  {
   bool found = false;
   start_minute = 1440;
   close_minute = 0;

   datetime session_from = 0;
   datetime session_to = 0;
   for(uint session = 0; session < 10; ++session)
     {
      if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)day_of_week, session, session_from, session_to))
         continue;

      int from_minute = Strategy_SessionMinute(session_from);
      int to_minute = Strategy_SessionMinute(session_to);
      if(to_minute == 0 && from_minute > 0)
         to_minute = 1440;

      if(from_minute < start_minute)
         start_minute = from_minute;
      if(to_minute > close_minute)
         close_minute = to_minute;
      found = true;
     }

   if(!found && day_of_week >= 1 && day_of_week <= 5)
     {
      // Fallback for DWX custom symbols with no reported session schedule:
      // assume a full trading day [00:00, 24:00) so the entry-near-open and
      // exit-near-close windows still resolve instead of collapsing to false.
      start_minute = 0;
      close_minute = 1440;
      return true;
     }

   return found;
  }

bool Strategy_NearSessionOpen(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   int start_minute = 0;
   int close_minute = 0;
   if(!Strategy_SessionBounds(dt.day_of_week, start_minute, close_minute))
      return false;

   const int minute_now = Strategy_MinuteOfDay(broker_time);
   const int entry_window = MathMax(1, strategy_entry_window_minutes);
   return (minute_now >= start_minute && minute_now < start_minute + entry_window);
  }

bool Strategy_NearSessionClose(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   int start_minute = 0;
   int close_minute = 0;
   if(!Strategy_SessionBounds(dt.day_of_week, start_minute, close_minute))
      return false;

   const int minute_now = Strategy_MinuteOfDay(broker_time);
   const int lead = MathMax(1, strategy_exit_before_close_min);
   return (minute_now >= close_minute - lead);
  }

bool Strategy_HasOurPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

bool Strategy_WeekNewsBlocksEntry(const datetime broker_time)
  {
   if(!strategy_block_news_wed_fri)
      return false;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const datetime day_start = Strategy_DateFloor(broker_time);

   for(int dow = 3; dow <= 5; ++dow)
     {
      const int add_days = dow - dt.day_of_week;
      if(add_days < 0)
         continue;

      const datetime check_day = day_start + (add_days * 86400);
      if(QM_NewsDayHasEvent(check_day, _Symbol))
         return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_require_m30_execution && _Period != PERIOD_M30)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
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

   if(dt.day_of_week < strategy_entry_day_of_week || dt.day_of_week > strategy_latest_entry_day)
      return false;
   if(!Strategy_HasScheduledSession(dt.day_of_week))
      return false;

   const int week_key = Strategy_WeekKey(broker_now);
   if(week_key == g_last_entry_week_key)
      return false;
   if(Strategy_HasOurPosition())
      return false;
   if(!Strategy_NearSessionOpen(broker_now))
      return false;
   if(Strategy_WeekNewsBlocksEntry(broker_now))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   req.price = ask;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = "FRENCH_WEEKEND_EFFECT_TUE_FRI_LONG";
   if(req.sl <= 0.0 || req.sl >= ask || ((ask - req.sl) / point) <= 0.0)
      return false;

   g_last_entry_week_key = week_key;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // The card specifies only the initial ATR hard stop and a weekly time stop.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);

   if(dt.day_of_week == strategy_exit_day_of_week)
      return Strategy_NearSessionClose(broker_now);

   if(dt.day_of_week == strategy_fallback_exit_day && !Strategy_HasScheduledSession(strategy_exit_day_of_week))
      return Strategy_NearSessionClose(broker_now);

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1158\",\"ea\":\"french_weekend_effect_idx\"}");
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
