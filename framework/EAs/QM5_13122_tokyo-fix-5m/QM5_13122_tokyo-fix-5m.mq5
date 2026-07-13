#property strict
#property version   "5.0"
#property description "QM5_13122 exact Tokyo-fix five-minute long/short cycle"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13122;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_long_entry_jst_hhmm  = 950;
input int    strategy_switch_jst_hhmm      = 955;
input int    strategy_short_exit_jst_hhmm  = 1000;
input int    strategy_calendar_mode        = 0;   // 0 = all BOJ business days
input int    strategy_risk_stop_pips       = 30;
input int    strategy_max_spread_points    = 10;
input int    strategy_deviation_points     = 20;

// Cabinet Office national holidays plus Bank of Japan Dec-31/Jan-2/Jan-3
// closures. Source snapshot retrieved 2026-07-10; valid through 2027.
int g_japan_bank_closed[] =
  {
   20170101,20170102,20170103,20170109,20170211,20170320,20170429,20170503,20170504,20170505,20170717,20170811,
   20170918,20170923,20171009,20171103,20171123,20171223,20171231,20180101,20180102,20180103,20180108,20180211,
   20180212,20180321,20180429,20180430,20180503,20180504,20180505,20180716,20180811,20180917,20180923,20180924,
   20181008,20181103,20181123,20181223,20181224,20181231,20190101,20190102,20190103,20190114,20190211,20190321,
   20190429,20190430,20190501,20190502,20190503,20190504,20190505,20190506,20190715,20190811,20190812,20190916,
   20190923,20191014,20191022,20191103,20191104,20191123,20191231,20200101,20200102,20200103,20200113,20200211,
   20200223,20200224,20200320,20200429,20200503,20200504,20200505,20200506,20200723,20200724,20200810,20200921,
   20200922,20201103,20201123,20201231,20210101,20210102,20210103,20210111,20210211,20210223,20210320,20210429,
   20210503,20210504,20210505,20210722,20210723,20210808,20210809,20210920,20210923,20211103,20211123,20211231,
   20220101,20220102,20220103,20220110,20220211,20220223,20220321,20220429,20220503,20220504,20220505,20220718,
   20220811,20220919,20220923,20221010,20221103,20221123,20221231,20230101,20230102,20230103,20230109,20230211,
   20230223,20230321,20230429,20230503,20230504,20230505,20230717,20230811,20230918,20230923,20231009,20231103,
   20231123,20231231,20240101,20240102,20240103,20240108,20240211,20240212,20240223,20240320,20240429,20240503,
   20240504,20240505,20240506,20240715,20240811,20240812,20240916,20240922,20240923,20241014,20241103,20241104,
   20241123,20241231,20250101,20250102,20250103,20250113,20250211,20250223,20250224,20250320,20250429,20250503,
   20250504,20250505,20250506,20250721,20250811,20250915,20250923,20251013,20251103,20251123,20251124,20251231,
   20260101,20260102,20260103,20260112,20260211,20260223,20260320,20260429,20260503,20260504,20260505,20260506,
   20260720,20260811,20260921,20260922,20260923,20261012,20261103,20261123,20261231,20270101,20270102,20270103,
   20270111,20270211,20270223,20270321,20270322,20270429,20270503,20270504,20270505,20270719,20270811,20270920,
   20270923,20271011,20271103,20271123,20271231
  };

enum StrategyCycleState
  {
   CYCLE_IDLE = 0,
   CYCLE_LONG_ATTEMPTED,
   CYCLE_LONG_CLOSED_OK,
   CYCLE_SHORT_ATTEMPTED,
   CYCLE_LOCKED
  };

enum StrategyCloseTransition
  {
   CLOSE_TRANSITION_NONE = 0,
   CLOSE_TRANSITION_TO_SHORT,
   CLOSE_TRANSITION_LOCK
  };

int                     g_jst_day_key = 0;
StrategyCycleState      g_cycle_state = CYCLE_IDLE;
StrategyCloseTransition g_close_transition = CLOSE_TRANSITION_NONE;

datetime Strategy_BrokerToJST(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      return 0;
   return utc_time + 9 * 3600;
  }

int Strategy_DateKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesOfDay(const datetime value)
  {
   if(value <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_HHMMToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

bool Strategy_FindOwnedPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                datetime &position_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   position_time = 0;
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
      position_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_HasOwnedPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime position_time = 0;
   return Strategy_FindOwnedPosition(ticket, position_type, position_time);
  }

void Strategy_ResetForJSTDay(const datetime jst_now)
  {
   const int day_key = Strategy_DateKey(jst_now);
   if(day_key <= 0 || day_key == g_jst_day_key)
      return;
   g_jst_day_key = day_key;
   g_close_transition = CLOSE_TRANSITION_NONE;
   g_cycle_state = Strategy_HasOwnedPosition() ? CYCLE_LOCKED : CYCLE_IDLE;
  }

bool Strategy_IsBankClosedDate(const int date_key)
  {
   const int count = ArraySize(g_japan_bank_closed);
   for(int i = 0; i < count; ++i)
     {
      if(g_japan_bank_closed[i] == date_key)
         return true;
     }
   return false;
  }

bool Strategy_IsJapaneseBusinessDay(const datetime jst_now)
  {
   MqlDateTime dt;
   if(jst_now <= 0 || !TimeToStruct(jst_now, dt))
      return false;
   if(dt.year < 2017 || dt.year > 2027)
      return false;
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   return !Strategy_IsBankClosedDate(Strategy_DateKey(jst_now));
  }

bool Strategy_HistoryReady()
  {
   if(Bars(_Symbol, _Period) < 10)
      return false;
   return (bool)SeriesInfoInteger(_Symbol, _Period, SERIES_SYNCHRONIZED);
  }

bool Strategy_WideSpread()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;
   const double spread_points = (ask - bid) / point;
   return spread_points > (double)strategy_max_spread_points + 1e-6;
  }

bool Strategy_ConfigValid()
  {
   if(_Symbol != "USDJPY.DWX")
      return false;
   if(_Period != PERIOD_M1 && _Period != PERIOD_M5)
      return false;
   if(qm_ea_id != 13122 || qm_magic_slot_offset != 0)
      return false;
   if(strategy_calendar_mode != 0)
      return false;
   if(strategy_risk_stop_pips != 30 || strategy_max_spread_points != 10 || strategy_deviation_points != 20)
      return false;
   const int long_minute = Strategy_HHMMToMinutes(strategy_long_entry_jst_hhmm);
   const int switch_minute = Strategy_HHMMToMinutes(strategy_switch_jst_hhmm);
   const int short_exit_minute = Strategy_HHMMToMinutes(strategy_short_exit_jst_hhmm);
   return (long_minute == 9 * 60 + 50 && switch_minute == 9 * 60 + 55 && short_exit_minute == 10 * 60);
  }

bool Strategy_NoTradeFilter()
  {
   return !Strategy_ConfigValid();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime broker_now = TimeCurrent();
   const datetime jst_now = Strategy_BrokerToJST(broker_now);
   Strategy_ResetForJSTDay(jst_now);

   const int minute = Strategy_MinutesOfDay(jst_now);
   const int long_minute = Strategy_HHMMToMinutes(strategy_long_entry_jst_hhmm);
   const int switch_minute = Strategy_HHMMToMinutes(strategy_switch_jst_hhmm);
   const bool long_entry = (minute == long_minute && g_cycle_state == CYCLE_IDLE);
   const bool short_entry = (minute == switch_minute && g_cycle_state == CYCLE_LONG_CLOSED_OK);
   if(!long_entry && !short_entry)
      return false;
   if(Strategy_HasOwnedPosition() || !Strategy_IsJapaneseBusinessDay(jst_now) || !Strategy_HistoryReady() || Strategy_WideSpread())
      return false;

   req.type = long_entry ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.tp = 0.0;
   req.reason = long_entry ? "TOKYO_FIX_PRE_LONG" : "TOKYO_FIX_POST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;
   req.sl = QM_StopFixedPips(_Symbol, req.type, entry_price, strategy_risk_stop_pips);
   if(req.sl <= 0.0)
      return false;

   g_cycle_state = long_entry ? CYCLE_LONG_ATTEMPTED : CYCLE_SHORT_ATTEMPTED;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const datetime jst_now = Strategy_BrokerToJST(TimeCurrent());
   Strategy_ResetForJSTDay(jst_now);

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime position_time = 0;
   if(!Strategy_FindOwnedPosition(ticket, position_type, position_time))
      return false;

   const int minute = Strategy_MinutesOfDay(jst_now);
   const int position_day_key = Strategy_DateKey(Strategy_BrokerToJST(position_time));
   if(position_day_key <= 0 || position_day_key != g_jst_day_key)
     {
      g_close_transition = CLOSE_TRANSITION_LOCK;
      return true;
     }

   if(position_type == POSITION_TYPE_BUY && minute >= Strategy_HHMMToMinutes(strategy_switch_jst_hhmm))
     {
      g_close_transition = (g_cycle_state == CYCLE_LONG_ATTEMPTED)
                           ? CLOSE_TRANSITION_TO_SHORT
                           : CLOSE_TRANSITION_LOCK;
      return true;
     }
   if(position_type == POSITION_TYPE_SELL && minute >= Strategy_HHMMToMinutes(strategy_short_exit_jst_hhmm))
     {
      g_close_transition = CLOSE_TRANSITION_LOCK;
      return true;
     }
   return false;
  }

void Strategy_OnCloseResult(const bool success)
  {
   if(success && g_close_transition == CLOSE_TRANSITION_TO_SHORT && g_cycle_state == CYCLE_LONG_ATTEMPTED)
      g_cycle_state = CYCLE_LONG_CLOSED_OK;
   else
      g_cycle_state = CYCLE_LOCKED;
   g_close_transition = CLOSE_TRANSITION_NONE;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!Strategy_ConfigValid())
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

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     strategy_deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13122\",\"ea\":\"tokyo-fix-5m\"}");
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
      bool close_attempted = false;
      bool close_success = true;
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
         close_attempted = true;
         if(!QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            close_success = false;
        }
      if(close_attempted)
         Strategy_OnCloseResult(close_success);
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
