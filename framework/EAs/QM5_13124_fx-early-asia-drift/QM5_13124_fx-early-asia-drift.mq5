#property strict
#property version   "5.0"
#property description "QM5_13124 FX Early-Asia Drift"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13124;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_hour_utc       = 0;
input int    strategy_hold_minutes         = 60;
input int    strategy_atr_period           = 20;
input double strategy_stop_atr_mult        = 1.25;
input double strategy_max_spread_atr_frac  = 0.05;
input int    strategy_max_entry_delay_sec  = 120;

int g_last_entry_utc_date = 0;

datetime Strategy_ToUTC(const datetime broker_time)
  {
   return QM_BrokerToUTC(broker_time);
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_ExpectedBinding()
  {
   if(qm_magic_slot_offset == 0)
      return (_Symbol == "EURGBP.DWX" && strategy_entry_hour_utc == 0);
   if(qm_magic_slot_offset == 1)
      return (_Symbol == "GBPUSD.DWX" && strategy_entry_hour_utc == 0);
   if(qm_magic_slot_offset == 2)
      return (_Symbol == "EURAUD.DWX" && strategy_entry_hour_utc == 0);
   if(qm_magic_slot_offset == 3)
      return (_Symbol == "AUDJPY.DWX" && strategy_entry_hour_utc == 1);
   if(qm_magic_slot_offset == 4)
      return (_Symbol == "NZDUSD.DWX" && strategy_entry_hour_utc == 0);
   return false;
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_H1 || !Strategy_ExpectedBinding());
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_BUY;
   req.symbol_slot = qm_magic_slot_offset;

   if(Strategy_NoTradeFilter() || Strategy_HasOpenPosition())
      return false;
   if(strategy_hold_minutes != 60 || strategy_atr_period != 20 ||
      MathAbs(strategy_stop_atr_mult - 1.25) > 0.000001 ||
      MathAbs(strategy_max_spread_atr_frac - 0.05) > 0.000001 ||
      strategy_max_entry_delay_sec != 120)
      return false;

   const datetime utc_now = Strategy_ToUTC(TimeCurrent());
   if(utc_now <= 0)
      return false;

   MqlDateTime utc;
   ZeroMemory(utc);
   TimeToStruct(utc_now, utc);
   const int seconds_into_hour = utc.min * 60 + utc.sec;
   if(utc.hour != strategy_entry_hour_utc ||
      seconds_into_hour > strategy_max_entry_delay_sec)
      return false;

   const int date_key = Strategy_DateKey(utc_now);
   if(g_last_entry_utc_date == date_key)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   if((ask - bid) > atr * strategy_max_spread_atr_frac)
      return false;

   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_stop_atr_mult);
   req.tp = 0.0;
   req.reason = "FX_EARLY_ASIA_DRIFT_LONG";
   req.expiration_seconds = 0;
   if(req.sl <= 0.0)
      return false;

   g_last_entry_utc_date = date_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime broker_now = TimeCurrent();
   const int hold_seconds = strategy_hold_minutes * 60;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && broker_now - opened >= hold_seconds)
         return true;
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

   if(_Period != PERIOD_H1 || !Strategy_ExpectedBinding())
     {
      QM_LogEvent(QM_ERROR, "TARGET_BINDING_INVALID",
                  StringFormat("{\"symbol\":\"%s\",\"period\":%d,\"slot\":%d,\"entry_hour_utc\":%d}",
                               _Symbol, (int)_Period, qm_magic_slot_offset, strategy_entry_hour_utc));
      return INIT_FAILED;
     }

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

   if(QM_FrameworkHandleFridayClose())
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

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
      return;

   QM_EquityStreamOnNewBar();
   if(Strategy_NoTradeFilter())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
