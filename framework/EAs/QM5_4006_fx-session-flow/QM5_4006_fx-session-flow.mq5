#property strict
#property version   "5.0"
#property description "SRC09 EURUSD London/New-York session-flow replication"

#include <QM/QM_Common.mqh>
#include "Strategy_SessionClock.mqh"

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 4006;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input bool   strategy_enable_eu_leg         = true;
input bool   strategy_enable_us_leg         = true;
input int    strategy_entry_delay_max_seconds = 300;
input int    strategy_exit_retry_interval_seconds = 5;
input int    strategy_exit_escalation_seconds = 60;
input int    strategy_stop_atr_period_d1    = 20;
input double strategy_stop_atr_mult         = 1.0;
input int    strategy_max_spread_points     = 30;

struct Strategy_DaySchedule
  {
   bool     valid;
   int      day_key;
   datetime eu_entry_utc;
   datetime eu_entry_broker;
   datetime eu_exit_us_entry_utc;
   datetime eu_exit_us_entry_broker;
   datetime us_exit_utc;
   datetime us_exit_broker;
  };

int      g_strategy_eu_attempt_day = 0;
int      g_strategy_us_attempt_day = 0;
bool     g_strategy_halt = false;
int      g_strategy_halt_day_key = 0;
datetime g_strategy_last_exit_attempt_utc = 0;
bool     g_strategy_exit_alerted = false;

int Strategy_DayKey(const MqlDateTime &dt)
  {
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_SameCivilDate(const MqlDateTime &a,const MqlDateTime &b)
  {
   return (a.year == b.year && a.mon == b.mon && a.day == b.day);
  }

bool Strategy_IsBusinessDate(const MqlDateTime &date_value)
  {
   MqlDateTime probe = date_value;
   probe.hour = 12;
   probe.min = 0;
   probe.sec = 0;
   const datetime serial = StructToTime(probe);
   if(serial <= 0)
      return false;
   MqlDateTime checked;
   ZeroMemory(checked);
   TimeToStruct(serial, checked);
   return (checked.day_of_week >= 1 && checked.day_of_week <= 5);
  }

bool Strategy_BuildSchedule(const MqlDateTime &london_date,Strategy_DaySchedule &schedule)
  {
   ZeroMemory(schedule);
   if(!Strategy_IsBusinessDate(london_date))
      return false;

   MqlDateTime eu_local = london_date;
   eu_local.hour = 7;
   eu_local.min = 0;
   eu_local.sec = 0;

   MqlDateTime ny_entry_local = london_date;
   ny_entry_local.hour = 8;
   ny_entry_local.min = 0;
   ny_entry_local.sec = 0;

   MqlDateTime ny_exit_local = london_date;
   ny_exit_local.hour = 16;
   ny_exit_local.min = 0;
   ny_exit_local.sec = 0;

   if(!Strategy_ResolveLondonLocal(eu_local, schedule.eu_entry_utc, schedule.eu_entry_broker))
      return false;
   if(!Strategy_ResolveNewYorkLocal(ny_entry_local,
                                    schedule.eu_exit_us_entry_utc,
                                    schedule.eu_exit_us_entry_broker))
      return false;
   if(!Strategy_ResolveNewYorkLocal(ny_exit_local, schedule.us_exit_utc, schedule.us_exit_broker))
      return false;

   if(schedule.eu_entry_utc >= schedule.eu_exit_us_entry_utc ||
      schedule.eu_exit_us_entry_utc >= schedule.us_exit_utc)
      return false;

   MqlDateTime eu_roundtrip;
   MqlDateTime ny_entry_roundtrip;
   MqlDateTime ny_exit_roundtrip;
   ZeroMemory(eu_roundtrip);
   ZeroMemory(ny_entry_roundtrip);
   ZeroMemory(ny_exit_roundtrip);
   TimeToStruct(Strategy_UTCToLondon(schedule.eu_entry_utc), eu_roundtrip);
   TimeToStruct(Strategy_UTCToNewYork(schedule.eu_exit_us_entry_utc), ny_entry_roundtrip);
   TimeToStruct(Strategy_UTCToNewYork(schedule.us_exit_utc), ny_exit_roundtrip);
   if(!Strategy_SameCivilDate(london_date, eu_roundtrip) ||
      !Strategy_SameCivilDate(london_date, ny_entry_roundtrip) ||
      !Strategy_SameCivilDate(london_date, ny_exit_roundtrip))
      return false;

   schedule.day_key = Strategy_DayKey(london_date);
   schedule.valid = true;
   return true;
  }

bool Strategy_CurrentSchedule(Strategy_DaySchedule &schedule)
  {
   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime london_now;
   ZeroMemory(london_now);
   TimeToStruct(Strategy_UTCToLondon(now_utc), london_now);
   london_now.hour = 0;
   london_now.min = 0;
   london_now.sec = 0;
   return Strategy_BuildSchedule(london_now, schedule);
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                datetime &open_broker,
                                string &comment)
  {
   const int magic = QM_FrameworkMagic();
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_broker = (datetime)PositionGetInteger(POSITION_TIME);
      comment = PositionGetString(POSITION_COMMENT);
      return true;
     }
   return false;
  }

bool Strategy_HasOurPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_broker = 0;
   string comment = "";
   return Strategy_SelectOurPosition(ticket, position_type, open_broker, comment);
  }

void Strategy_LatchDayHalt(const int day_key,const string reason)
  {
   const bool new_latch = (!g_strategy_halt || g_strategy_halt_day_key != day_key);
   g_strategy_halt = true;
   g_strategy_halt_day_key = day_key;
   if(!new_latch)
      return;
   QM_LogEvent(QM_ERROR,
               "SESSION_DAY_HALT_LATCHED",
               StringFormat("{\"day_key\":%d,\"reason\":\"%s\"}",
                            day_key,
                            QM_LoggerEscapeJson(reason)));
  }

void Strategy_ReleaseExpiredDayHalt()
  {
   if(!g_strategy_halt || Strategy_HasOurPosition())
      return;
   Strategy_DaySchedule current;
   if(!Strategy_CurrentSchedule(current) || !current.valid)
      return;
   if(g_strategy_halt_day_key <= 0 || current.day_key == g_strategy_halt_day_key)
      return;
   QM_LogEvent(QM_INFO,
               "SESSION_DAY_HALT_RELEASED",
               StringFormat("{\"halt_day_key\":%d,\"current_day_key\":%d}",
                            g_strategy_halt_day_key,
                            current.day_key));
   g_strategy_halt = false;
   g_strategy_halt_day_key = 0;
   g_strategy_exit_alerted = false;
  }

bool Strategy_HistoryWindow(const Strategy_DaySchedule &schedule)
  {
   const datetime from_broker = schedule.eu_entry_broker - 3600;
   datetime to_broker = TimeCurrent();
   const datetime hard_end = schedule.us_exit_broker + 24 * 3600;
   if(to_broker > hard_end)
      to_broker = hard_end;
   if(to_broker < from_broker)
      to_broker = from_broker;
   return HistorySelect(from_broker, to_broker);
  }

bool Strategy_LegSeen(const Strategy_DaySchedule &schedule,
                      const bool eu_leg,
                      bool &query_ok)
  {
   query_ok = Strategy_HistoryWindow(schedule);
   if(!query_ok)
      return false;

   const string wanted = eu_leg ? "FX_SESSION_EU" : "FX_SESSION_US";
   const ENUM_DEAL_TYPE wanted_type = eu_leg ? DEAL_TYPE_SELL : DEAL_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      if((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE) != wanted_type)
         continue;
      if(StringFind(HistoryDealGetString(deal, DEAL_COMMENT), wanted) >= 0)
         return true;
     }
   return false;
  }

double Strategy_RealizedFamilyPnL(const Strategy_DaySchedule &schedule,bool &query_ok)
  {
   query_ok = Strategy_HistoryWindow(schedule);
   if(!query_ok)
      return 0.0;
   double pnl = 0.0;
   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < HistoryDealsTotal(); ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      pnl += HistoryDealGetDouble(deal, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(deal, DEAL_SWAP);
      pnl += HistoryDealGetDouble(deal, DEAL_COMMISSION);
     }
   return pnl;
  }

double Strategy_PlannedLegRiskMoney()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED * PORTFOLIO_WEIGHT;
   return AccountInfoDouble(ACCOUNT_EQUITY) * (RISK_PERCENT / 100.0) * PORTFOLIO_WEIGHT;
  }

string Strategy_AttemptKey(const int day_key,const bool eu_leg)
  {
   return StringFormat("QM5.4006.%I64d.%d.%s",
                       AccountInfoInteger(ACCOUNT_LOGIN),
                       day_key,
                       eu_leg ? "EU" : "US");
  }

bool Strategy_AttemptAlreadyRecorded(const int day_key,const bool eu_leg)
  {
   if(eu_leg && g_strategy_eu_attempt_day == day_key)
      return true;
   if(!eu_leg && g_strategy_us_attempt_day == day_key)
      return true;
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return false;
   return GlobalVariableCheck(Strategy_AttemptKey(day_key, eu_leg));
  }

bool Strategy_RecordAttempt(const int day_key,const bool eu_leg)
  {
   if(eu_leg)
      g_strategy_eu_attempt_day = day_key;
   else
      g_strategy_us_attempt_day = day_key;
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return true;
   const datetime written = GlobalVariableSet(Strategy_AttemptKey(day_key, eu_leg), (double)TimeCurrent());
   if(written != 0)
      return true;
   Strategy_LatchDayHalt(day_key, "attempt_state_persistence_failed");
   QM_LogEvent(QM_ERROR,
               "SESSION_ATTEMPT_STATE_FAILED",
               StringFormat("{\"day_key\":%d,\"leg\":\"%s\"}", day_key, eu_leg ? "EU" : "US"));
   return false;
  }

bool Strategy_SpreadAllowsEntry(const MqlTick &tick)
  {
   if(tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
      return false;
   if(strategy_max_spread_points <= 0)
      return true;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double spread_points = (tick.ask - tick.bid) / point;
   return (spread_points <= (double)strategy_max_spread_points + 1e-9);
  }

bool Strategy_BuildEntryRequest(const bool eu_leg,
                                const Strategy_DaySchedule &schedule,
                                QM_EntryRequest &req)
  {
   MqlTick tick;
   ZeroMemory(tick);
   if(!SymbolInfoTick(_Symbol, tick) || !Strategy_SpreadAllowsEntry(tick))
      return false;

   const QM_OrderType side = eu_leg ? QM_SELL : QM_BUY;
   const double entry_price = eu_leg ? tick.bid : tick.ask;
   const double prior_d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_stop_atr_period_d1, 1);
   if(prior_d1_atr <= 0.0)
      return false;
   const double stop = QM_StopATRFromValue(_Symbol,
                                           side,
                                           entry_price,
                                           prior_d1_atr,
                                           strategy_stop_atr_mult);
   if(stop <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = eu_leg ? "FX_SESSION_EU" : "FX_SESSION_US";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   QM_LogEvent(QM_INFO,
               "SESSION_ENTRY_ARMED",
               StringFormat("{\"day_key\":%d,\"leg\":\"%s\",\"scheduled_utc\":%I64d,\"actual_utc\":%I64d,\"spread_points\":%.2f,\"atr_d1\":%.8f}",
                            schedule.day_key,
                            eu_leg ? "EU" : "US",
                            (long)(eu_leg ? schedule.eu_entry_utc : schedule.eu_exit_us_entry_utc),
                            (long)QM_BrokerToUTC(TimeCurrent()),
                            (tick.ask - tick.bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT),
                            prior_d1_atr));
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurPosition())
      return false;
   Strategy_ReleaseExpiredDayHalt();
   return g_strategy_halt;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ReleaseExpiredDayHalt();
   if(g_strategy_halt || Strategy_HasOurPosition())
      return false;

   Strategy_DaySchedule schedule;
   if(!Strategy_CurrentSchedule(schedule) || !schedule.valid)
      return false;

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const bool eu_window = strategy_enable_eu_leg &&
                          !Strategy_AttemptAlreadyRecorded(schedule.day_key, true) &&
                          now_utc >= schedule.eu_entry_utc &&
                          now_utc <= schedule.eu_entry_utc + strategy_entry_delay_max_seconds;
   const bool us_window = strategy_enable_us_leg &&
                          !Strategy_AttemptAlreadyRecorded(schedule.day_key, false) &&
                          now_utc >= schedule.eu_exit_us_entry_utc &&
                          now_utc <= schedule.eu_exit_us_entry_utc + strategy_entry_delay_max_seconds;
   if(!eu_window && !us_window)
      return false;

   bool query_ok = false;
   if(eu_window)
     {
      const bool eu_seen = Strategy_LegSeen(schedule, true, query_ok);
      if(!query_ok || eu_seen)
         return false;
      if(!Strategy_BuildEntryRequest(true, schedule, req))
         return false;
      return Strategy_RecordAttempt(schedule.day_key, true);
     }

   const bool us_seen = Strategy_LegSeen(schedule, false, query_ok);
   if(!query_ok || us_seen)
      return false;
   const bool eu_seen = Strategy_LegSeen(schedule, true, query_ok);
   if(!query_ok)
      return false;

   bool pnl_ok = false;
   const double realized_family_pnl = Strategy_RealizedFamilyPnL(schedule, pnl_ok);
   if(!pnl_ok)
      return false;
   const double one_leg_budget = Strategy_PlannedLegRiskMoney();
   if(eu_seen && one_leg_budget > 0.0 && realized_family_pnl <= -one_leg_budget)
     {
      Strategy_RecordAttempt(schedule.day_key, false);
      QM_LogEvent(QM_WARN,
                  "SESSION_FAMILY_RISK_LOCK",
                  StringFormat("{\"day_key\":%d,\"realized_pnl\":%.2f,\"one_leg_budget\":%.2f}",
                               schedule.day_key,
                               realized_family_pnl,
                               one_leg_budget));
      return false;
     }

   if(!Strategy_BuildEntryRequest(false, schedule, req))
      return false;
   return Strategy_RecordAttempt(schedule.day_key, false);
  }

void Strategy_ManageOpenPosition()
  {
   // Source-defined management is clock-only. The catastrophic SL is frozen at entry.
  }

bool Strategy_PositionSchedule(const ENUM_POSITION_TYPE position_type,
                               const datetime open_broker,
                               const string comment,
                               Strategy_DaySchedule &schedule,
                               bool &eu_leg)
  {
   const datetime open_utc = QM_BrokerToUTC(open_broker);
   eu_leg = (StringFind(comment, "FX_SESSION_EU") >= 0);
   const bool tagged_us = (StringFind(comment, "FX_SESSION_US") >= 0);
   if(!eu_leg && !tagged_us)
      eu_leg = (position_type == POSITION_TYPE_SELL);

   const datetime civil_time = eu_leg ? Strategy_UTCToLondon(open_utc)
                                      : Strategy_UTCToNewYork(open_utc);
   MqlDateTime civil_date;
   ZeroMemory(civil_date);
   TimeToStruct(civil_time, civil_date);
   civil_date.hour = 0;
   civil_date.min = 0;
   civil_date.sec = 0;
   return Strategy_BuildSchedule(civil_date, schedule);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_broker = 0;
   string comment = "";
   if(!Strategy_SelectOurPosition(ticket, position_type, open_broker, comment))
     {
      g_strategy_last_exit_attempt_utc = 0;
      g_strategy_exit_alerted = false;
      return false;
     }

   Strategy_DaySchedule schedule;
   bool eu_leg = false;
   if(!Strategy_PositionSchedule(position_type, open_broker, comment, schedule, eu_leg))
     {
      Strategy_DaySchedule current;
      const int halt_day = Strategy_CurrentSchedule(current) ? current.day_key : 0;
      Strategy_LatchDayHalt(halt_day, "position_clock_unresolved");
      QM_LogEvent(QM_ERROR, "SESSION_POSITION_CLOCK_UNRESOLVED", StringFormat("{\"ticket\":%I64u}", ticket));
      return true;
     }

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime due_utc = eu_leg ? schedule.eu_exit_us_entry_utc : schedule.us_exit_utc;
   if(now_utc < due_utc)
     {
      g_strategy_last_exit_attempt_utc = 0;
      g_strategy_exit_alerted = false;
      return false;
     }

   if(now_utc - due_utc >= strategy_exit_escalation_seconds)
     {
      Strategy_LatchDayHalt(schedule.day_key, "mandatory_exit_unconfirmed_60s");
      if(!g_strategy_exit_alerted)
        {
         g_strategy_exit_alerted = true;
         QM_LogEvent(QM_ERROR,
                     "SESSION_EXIT_ESCALATED",
                     StringFormat("{\"ticket\":%I64u,\"leg\":\"%s\",\"due_utc\":%I64d,\"late_seconds\":%d}",
                                  ticket,
                                  eu_leg ? "EU" : "US",
                                  (long)due_utc,
                                  (int)(now_utc - due_utc)));
        }
     }

   if(g_strategy_last_exit_attempt_utc > 0 &&
      now_utc - g_strategy_last_exit_attempt_utc < strategy_exit_retry_interval_seconds)
      return false;
   g_strategy_last_exit_attempt_utc = now_utc;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(qm_ea_id != 4006 || qm_magic_slot_offset != 0 || _Symbol != "EURUSD.DWX")
      return INIT_PARAMETERS_INCORRECT;
   if(strategy_entry_delay_max_seconds <= 0 ||
      strategy_exit_retry_interval_seconds <= 0 ||
      strategy_exit_escalation_seconds < strategy_exit_retry_interval_seconds ||
      strategy_stop_atr_period_d1 < 2 ||
      strategy_stop_atr_mult <= 0.0 ||
      strategy_max_spread_points < 0 ||
      qm_friday_close_enabled)
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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_M15,
         QM_FRIDAY_CLOSE_DISABLED,
         "SRC09_S01 owns mandatory Friday 16:00 America/New_York exit; no weekend hold"))
      return INIT_FAILED;
   if(!Strategy_SessionClockSelfTest())
     {
      QM_LogEvent(QM_ERROR, "SESSION_CLOCK_FIXTURE_FAILED", "{}");
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"strategy_id\":\"SRC09_S01\"}");
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
   ZeroMemory(req);
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
