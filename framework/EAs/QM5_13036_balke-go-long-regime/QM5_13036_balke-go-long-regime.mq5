#property strict
#property version   "5.0"
#property description "QM5_13036 Balke Go Long regime-gated index day exposure"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 13036;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ndx_entry_hhmm      = 1005;
input int    strategy_ndx_exit_hhmm       = 2350;
input int    strategy_gdaxi_entry_hhmm    = 905;
input int    strategy_gdaxi_exit_hhmm     = 2255;
input int    strategy_entry_window_minutes = 30;
input int    strategy_regime_sma_period   = 200;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 2.5;
input int    strategy_max_spread_points   = 0;

int g_last_entry_day_key = 0;

int Strategy_HHMMToMinutes(const int hhmm)
  {
   const int hour_value = hhmm / 100;
   const int minute_value = hhmm % 100;
   if(hour_value < 0 || hour_value > 23 || minute_value < 0 || minute_value > 59)
      return -1;
   return hour_value * 60 + minute_value;
  }

int Strategy_BrokerMinutes(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_BrokerDayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "NDX.DWX")
      return 0;
   if(_Symbol == "GDAXI.DWX")
      return 1;
   return -1;
  }

bool Strategy_IsConfiguredSymbol()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   return (expected_slot >= 0 && qm_magic_slot_offset == expected_slot && _Period == PERIOD_M15);
  }

int Strategy_EntryMinutes()
  {
   if(_Symbol == "NDX.DWX")
      return Strategy_HHMMToMinutes(strategy_ndx_entry_hhmm);
   if(_Symbol == "GDAXI.DWX")
      return Strategy_HHMMToMinutes(strategy_gdaxi_entry_hhmm);
   return -1;
  }

int Strategy_ExitMinutes()
  {
   if(_Symbol == "NDX.DWX")
      return Strategy_HHMMToMinutes(strategy_ndx_exit_hhmm);
   if(_Symbol == "GDAXI.DWX")
      return Strategy_HHMMToMinutes(strategy_gdaxi_exit_hhmm);
   return -1;
  }

bool Strategy_MinuteInWindow(const int minute_now, const int start_minute, const int window_minutes)
  {
   if(start_minute < 0 || window_minutes <= 0)
      return false;

   const int end_minute = start_minute + window_minutes;
   if(end_minute <= 1440)
      return (minute_now >= start_minute && minute_now < end_minute);

   return (minute_now >= start_minute || minute_now < (end_minute - 1440));
  }

bool Strategy_ExitTimeElapsed(const datetime broker_time)
  {
   const int exit_minute = Strategy_ExitMinutes();
   if(exit_minute < 0)
      return false;

   const int minute_now = Strategy_BrokerMinutes(broker_time);
   return (minute_now >= exit_minute);
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

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points >= 0 && spread_points <= strategy_max_spread_points);
  }

bool Strategy_RegimeAllowsLong()
  {
   if(strategy_regime_sma_period <= 1)
      return false;

   const double sma_value = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   const double close_value = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: card-defined D1 regime gate needs the previous daily close.
   if(sma_value <= 0.0 || close_value <= 0.0)
      return false;

   return (close_value > sma_value);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsConfiguredSymbol())
      return true;
   if(Strategy_EntryMinutes() < 0 || Strategy_ExitMinutes() < 0)
      return true;
   if(strategy_entry_window_minutes <= 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0)
      return true;
   if(!Strategy_SpreadAllowsEntry())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "BALKE_GO_LONG_REGIME";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const int day_key = Strategy_BrokerDayKey(broker_now);
   if(day_key <= 0 || day_key == g_last_entry_day_key)
      return false;

   if(!Strategy_MinuteInWindow(Strategy_BrokerMinutes(broker_now),
                               Strategy_EntryMinutes(),
                               strategy_entry_window_minutes))
      return false;

   if(!Strategy_RegimeAllowsLong())
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr_value <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry_price, atr_value, strategy_sl_atr_mult);
   if(req.sl <= 0.0)
      return false;

   g_last_entry_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   return Strategy_ExitTimeElapsed(TimeCurrent());
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13036_balke-go-long-regime\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
