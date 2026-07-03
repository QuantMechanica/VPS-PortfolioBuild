#property strict
#property version   "5.0"
#property description "QM5_12969 USDJPY Gotobi Nakane fix drift"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12969;
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
input int    strategy_entry_jst_hhmm             = 200;
input int    strategy_exit_jst_hhmm              = 955;
input bool   strategy_holiday_volume_proxy_enabled = true;
input int    strategy_risk_stop_pips             = 120;
input int    strategy_max_spread_points          = 0;

int g_last_entry_jst_day_key = 0;

bool Strategy_IsTarget()
  {
   return (_Symbol == "USDJPY.DWX" && _Period == PERIOD_M30 && qm_magic_slot_offset == 0);
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

datetime Strategy_BrokerToJST(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return utc_time + 9 * 3600;
  }

int Strategy_HHMMToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

int Strategy_MinutesOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

datetime Strategy_Midnight(const datetime value)
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

bool Strategy_IsNominalGotobiDate(const MqlDateTime &dt)
  {
   return (dt.day == 5 || dt.day == 10 || dt.day == 15 ||
           dt.day == 20 || dt.day == 25 || dt.day == 30);
  }

bool Strategy_IsJapanNewYearBankHoliday(const MqlDateTime &dt)
  {
   return (dt.mon == 1 && dt.day >= 1 && dt.day <= 3);
  }

bool Strategy_IsJapaneseBusinessDate(const MqlDateTime &dt)
  {
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   if(Strategy_IsJapanNewYearBankHoliday(dt))
      return false;
   return true;
  }

bool Strategy_IsGotobiSettlementDay(const datetime broker_time)
  {
   const datetime jst_now = Strategy_BrokerToJST(broker_time);
   MqlDateTime today;
   TimeToStruct(jst_now, today);
   if(!Strategy_IsJapaneseBusinessDate(today))
      return false;

   if(Strategy_IsNominalGotobiDate(today))
      return true;

   const datetime today_midnight = Strategy_Midnight(jst_now);
   for(int back = 1; back <= 7; ++back)
     {
      const datetime nominal_time = today_midnight - back * 86400;
      MqlDateTime nominal;
      TimeToStruct(nominal_time, nominal);
      if(!Strategy_IsNominalGotobiDate(nominal))
         continue;
      if(Strategy_IsJapaneseBusinessDate(nominal))
         continue;

      bool today_is_first_business_after_nominal = true;
      for(int forward = 1; forward < back; ++forward)
        {
         MqlDateTime between;
         TimeToStruct(nominal_time + forward * 86400, between);
         if(Strategy_IsJapaneseBusinessDate(between))
           {
            today_is_first_business_after_nominal = false;
            break;
           }
        }
      if(today_is_first_business_after_nominal)
         return true;
     }

   return false;
  }

bool Strategy_InEntryWindow(const datetime broker_time)
  {
   const int entry_minute = Strategy_HHMMToMinutes(strategy_entry_jst_hhmm);
   if(entry_minute < 0)
      return false;
   const int minute_of_day = Strategy_MinutesOfDay(Strategy_BrokerToJST(broker_time));
   return (minute_of_day >= entry_minute && minute_of_day < entry_minute + 30);
  }

bool Strategy_InExitWindow(const datetime broker_time)
  {
   const int exit_minute = Strategy_HHMMToMinutes(strategy_exit_jst_hhmm);
   if(exit_minute < 0)
      return false;
   const int exit_bar_open = (exit_minute / 30) * 30;
   const int minute_of_day = Strategy_MinutesOfDay(Strategy_BrokerToJST(broker_time));
   return (minute_of_day >= exit_bar_open);
  }

bool Strategy_HolidayVolumeProxyBlocks()
  {
   if(!strategy_holiday_volume_proxy_enabled)
      return false;
   const long recent_volume = iVolume(_Symbol, PERIOD_M30, 1); // perf-allowed: holiday proxy reads two closed M30 bars only on the entry path.
   const long prior_volume = iVolume(_Symbol, PERIOD_M30, 2);  // perf-allowed: holiday proxy reads two closed M30 bars only on the entry path.
   return (recent_volume <= 0 && prior_volume <= 0);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(Strategy_HHMMToMinutes(strategy_entry_jst_hhmm) < 0)
      return true;
   if(Strategy_HHMMToMinutes(strategy_exit_jst_hhmm) < 0)
      return true;
   if(strategy_risk_stop_pips <= 0)
      return true;
   if(Strategy_WideSpread())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "USDJPY_GOTOBI_NAKANE_FIX";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsGotobiSettlementDay(broker_now))
      return false;
   if(!Strategy_InEntryWindow(broker_now))
      return false;
   if(Strategy_HolidayVolumeProxyBlocks())
      return false;

   const int d1_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(d1_key <= 0)
      return false;

   const int jst_day_key = Strategy_DateKey(Strategy_BrokerToJST(broker_now));
   if(jst_day_key <= 0 || jst_day_key == g_last_entry_jst_day_key)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0)
      return false;
   req.sl = QM_StopFixedPips(_Symbol, QM_BUY, entry_price, strategy_risk_stop_pips);
   if(req.sl <= 0.0)
      return false;

   g_last_entry_jst_day_key = jst_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   return Strategy_InExitWindow(TimeCurrent());
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12969\",\"ea\":\"usdjpy-gotobi-nakane-fix\"}");
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
