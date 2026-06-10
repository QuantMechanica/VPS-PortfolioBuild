#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — GitHub MACD Histogram Zero-Cross Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9463_gh-macd-zero
// Source: pipbolt.io MACD-EA.mq5, EntryStrategy=HISTOGRAM_CROSSES_ZERO
// Card: artifacts/cards_approved/QM5_9463_gh-macd-zero.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9463;
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
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double main0 = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                      strategy_macd_fast, strategy_macd_slow,
                                      strategy_macd_signal, 1);
   const double sig0  = QM_MACD_Signal(_Symbol, PERIOD_CURRENT,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_signal, 1);
   const double main1 = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                      strategy_macd_fast, strategy_macd_slow,
                                      strategy_macd_signal, 2);
   const double sig1  = QM_MACD_Signal(_Symbol, PERIOD_CURRENT,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_signal, 2);

   if(main0 == EMPTY_VALUE || sig0 == EMPTY_VALUE ||
      main1 == EMPTY_VALUE || sig1 == EMPTY_VALUE)
      return false;

   const double hist0 = main0 - sig0;
   const double hist1 = main1 - sig1;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(hist1 <= 0.0 && hist0 > 0.0)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = req.price - atr * strategy_atr_sl_mult;
      req.tp     = 0.0;
      req.reason = "MACD_HIST_CROSS_UP";
      return true;
     }

   if(hist1 >= 0.0 && hist0 < 0.0)
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = req.price + atr * strategy_atr_sl_mult;
      req.tp     = 0.0;
      req.reason = "MACD_HIST_CROSS_DOWN";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing/partial/BE logic; SL set at entry is the risk bound.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE pos_type  = POSITION_TYPE_BUY;
   bool               has_pos   = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_pos  = true;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      break;
     }

   if(!has_pos)
      return false;

   const double main_val = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);
   const double sig_val  = QM_MACD_Signal(_Symbol, PERIOD_CURRENT,
                                          strategy_macd_fast, strategy_macd_slow,
                                          strategy_macd_signal, 1);

   if(main_val == EMPTY_VALUE || sig_val == EMPTY_VALUE)
      return false;

   if(pos_type == POSITION_TYPE_BUY  && sig_val > main_val)  return true;
   if(pos_type == POSITION_TYPE_SELL && sig_val < main_val)  return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
