#property strict
#property version   "5.0"
#property description "QM5_13125 XAU US-Close Overnight Drift"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13125;
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
input int    strategy_entry_hour_broker    = 23;
input int    strategy_exit_hour_broker     = 16;
input int    strategy_atr_period           = 14;
input double strategy_stop_atr_mult        = 1.0;
input double strategy_max_spread_atr_frac  = 0.02;
input int    strategy_max_entry_delay_sec  = 120;
input int    strategy_max_hold_hours       = 72;

int g_last_entry_date = 0;

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_SelectPosition(ulong &ticket, datetime &opened)
  {
   ticket = 0;
   opened = 0;
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
      opened = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Symbol != "XAUUSD.DWX" || _Period != PERIOD_H1 ||
           qm_magic_slot_offset != 0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_BUY;
   req.symbol_slot = qm_magic_slot_offset;

   if(Strategy_NoTradeFilter())
      return false;
   if(strategy_entry_hour_broker != 23 || strategy_exit_hour_broker != 16 ||
      strategy_atr_period != 14 ||
      MathAbs(strategy_stop_atr_mult - 1.0) > 0.000001 ||
      MathAbs(strategy_max_spread_atr_frac - 0.02) > 0.000001 ||
      strategy_max_entry_delay_sec != 120 || strategy_max_hold_hours != 72)
      return false;

   ulong existing_ticket;
   datetime existing_opened;
   if(Strategy_SelectPosition(existing_ticket, existing_opened))
      return false;

   const datetime now = TimeCurrent();
   MqlDateTime broker;
   ZeroMemory(broker);
   TimeToStruct(now, broker);
   const int seconds_into_hour = broker.min * 60 + broker.sec;
   if(broker.hour != strategy_entry_hour_broker ||
      seconds_into_hour > strategy_max_entry_delay_sec)
      return false;
   if(broker.day_of_week < 1 || broker.day_of_week > 4)
      return false;

   const int date_key = Strategy_DateKey(now);
   if(g_last_entry_date == date_key)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   if((ask - bid) > atr * strategy_max_spread_atr_frac)
      return false;

   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr,
                                strategy_stop_atr_mult);
   req.tp = 0.0;
   req.reason = "XAU_USCLOSE_OVERNIGHT_LONG";
   req.expiration_seconds = 0;
   if(req.sl <= 0.0)
      return false;

   g_last_entry_date = date_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   datetime opened;
   if(!Strategy_SelectPosition(ticket, opened) || opened <= 0)
      return false;

   const datetime now = TimeCurrent();
   if(now - opened >= strategy_max_hold_hours * 3600)
      return true;

   MqlDateTime broker;
   ZeroMemory(broker);
   TimeToStruct(now, broker);
   return (Strategy_DateKey(now) != Strategy_DateKey(opened) &&
           broker.hour >= strategy_exit_hour_broker &&
           broker.hour < strategy_entry_hour_broker);
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

   if(Strategy_NoTradeFilter())
     {
      QM_LogEvent(QM_ERROR, "TARGET_BINDING_INVALID", "{}");
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
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
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
