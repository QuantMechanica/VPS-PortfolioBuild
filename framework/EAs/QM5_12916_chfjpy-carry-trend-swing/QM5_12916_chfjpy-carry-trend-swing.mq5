#property strict
#property version   "5.0"
#property description "QM5_12916 CHFJPY carry trend swing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12916;
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
input int    strategy_sma_regime_period = 200;
input int    strategy_momentum_lookback = 63;
input int    strategy_sma_entry_period  = 10;
input int    strategy_sma_exit_period   = 50;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 3.0;

bool Strategy_IsTarget()
  {
   return (_Symbol == "CHFJPY.DWX" && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
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

double Strategy_Close(const ENUM_TIMEFRAMES tf, const int shift)
  {
   if(shift < 0)
      return 0.0;
   double values[];
   ArrayResize(values, 1);
   if(CopyClose(_Symbol, tf, shift, 1, values) != 1) // perf-allowed: reached only through D1 new-bar strategy flow.
      return 0.0;
   return values[0];
  }

bool Strategy_RegimeOk()
  {
   const double close1 = Strategy_Close(PERIOD_D1, 1);
   const double close_mom = Strategy_Close(PERIOD_D1, 1 + strategy_momentum_lookback);
   const double sma200 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_regime_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || close_mom <= 0.0 || sma200 <= 0.0)
      return false;
   return (close1 > sma200 && close1 > close_mom);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(strategy_sma_regime_period <= 1 || strategy_momentum_lookback <= 1)
      return true;
   if(strategy_sma_entry_period <= 1 || strategy_sma_exit_period <= 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "CHFJPY_CARRY_TREND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_RegimeOk())
      return false;

   const double close1 = Strategy_Close(PERIOD_D1, 1);
   const double close2 = Strategy_Close(PERIOD_D1, 2);
   const double sma10_1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_entry_period, 1, PRICE_CLOSE);
   const double sma10_2 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_entry_period, 2, PRICE_CLOSE);
   if(close1 <= 0.0 || close2 <= 0.0 || sma10_1 <= 0.0 || sma10_2 <= 0.0)
      return false;
   if(!(close1 > sma10_1 && close2 <= sma10_2))
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0)
      return false;
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double close1 = Strategy_Close(PERIOD_D1, 1);
   const double sma50 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_exit_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || sma50 <= 0.0)
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
      if(close1 < sma50)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12916\",\"ea\":\"chfjpy-carry-trend-swing\"}");
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
