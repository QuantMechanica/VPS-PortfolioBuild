#property strict
#property version   "5.0"
#property description "QM5_10082 GitHub Victor Algo Daily DAX ADX SMA Direction"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_10082_gh-dax-adxday
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10082;
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
input int    strategy_entry_hour_broker  = 13;
input int    strategy_entry_min_broker   = 30;
input int    strategy_close_hour_broker  = 21;
input int    strategy_close_min_broker   = 30;
input int    strategy_adx_period_d1      = 14;
input double strategy_adx_threshold      = 25.0;
input int    strategy_sma_period_d1      = 10;
input int    strategy_atr_stop_period    = 14;
input double strategy_atr_stop_mult      = 1.5;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
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

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   if(now.hour != strategy_entry_hour_broker || now.min != strategy_entry_min_broker)
      return false;

   if(strategy_adx_period_d1 <= 0 || strategy_sma_period_d1 <= 0 ||
      strategy_atr_stop_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return false;

   const double adx_d1 = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period_d1, 1);
   const double sma_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period_d1, 1, PRICE_CLOSE);
   if(adx_d1 <= strategy_adx_threshold || sma_d1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ask > sma_d1)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_stop_period, strategy_atr_stop_mult);
      req.reason = "D1_ADX_SMA_1330_LONG";
     }
   else if(bid < sma_d1)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_stop_period, strategy_atr_stop_mult);
      req.reason = "D1_ADX_SMA_1330_SHORT";
     }
   else
     {
      return false;
     }

   if(req.sl <= 0.0)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   if(now.hour > strategy_close_hour_broker)
      return true;
   if(now.hour == strategy_close_hour_broker && now.min >= strategy_close_min_broker)
      return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10082_gh-dax-adxday\"}");
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

