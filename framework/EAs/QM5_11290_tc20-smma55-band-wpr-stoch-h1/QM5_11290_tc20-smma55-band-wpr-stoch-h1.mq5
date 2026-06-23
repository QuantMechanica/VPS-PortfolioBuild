#property strict
#property version   "5.0"
#property description "QM5_11290 TC20 SMMA55 Band WPR Stoch H1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 11290;
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
input int    strategy_smma_period         = 55;
input int    strategy_wpr_period          = 55;
input double strategy_wpr_long_level      = -25.0;
input double strategy_wpr_short_level     = -75.0;
input int    strategy_stoch_k             = 5;
input int    strategy_stoch_d             = 5;
input int    strategy_stoch_slowing       = 5;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_rr_tp               = 2.0;
input int    strategy_spread_cap_pips     = 20;

bool Strategy_ReadClosedCloses(double &close_1, double &close_2)
  {
   close_1 = QM_SMA(_Symbol, PERIOD_CURRENT, 1, 1, PRICE_CLOSE);
   close_2 = QM_SMA(_Symbol, PERIOD_CURRENT, 1, 2, PRICE_CLOSE);
   return (close_1 > 0.0 && close_2 > 0.0);
  }

bool Strategy_WPRCrossRecent(const bool long_side)
  {
   const int lookback = 4;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double wpr_curr = QM_WPR(_Symbol, PERIOD_CURRENT, strategy_wpr_period, shift);
      const double wpr_prev = QM_WPR(_Symbol, PERIOD_CURRENT, strategy_wpr_period, shift + 1);
      if(long_side)
        {
         if(wpr_prev <= strategy_wpr_long_level && wpr_curr > strategy_wpr_long_level)
            return true;
        }
      else
        {
         if(wpr_prev >= strategy_wpr_short_level && wpr_curr < strategy_wpr_short_level)
            return true;
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;

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

   if(strategy_smma_period < 2 || strategy_wpr_period < 2 ||
      strategy_stoch_k < 1 || strategy_stoch_d < 1 || strategy_stoch_slowing < 1 ||
      strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0 || strategy_rr_tp <= 0.0)
      return false;

   double close_1 = 0.0;
   double close_2 = 0.0;
   if(!Strategy_ReadClosedCloses(close_1, close_2))
      return false;

   const double smma_high_1 = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_smma_period, 1, PRICE_HIGH);
   const double smma_low_1  = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_smma_period, 1, PRICE_LOW);
   const double stoch_k_1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d_1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   if(smma_high_1 <= 0.0 || smma_low_1 <= 0.0)
      return false;

   const bool long_channel_state = (close_1 > smma_high_1);
   const bool long_wpr_cross = Strategy_WPRCrossRecent(true);
   const bool long_stoch = (stoch_k_1 > stoch_d_1);

   const bool short_channel_state = (close_1 < smma_low_1);
   const bool short_wpr_cross = Strategy_WPRCrossRecent(false);
   const bool short_stoch = (stoch_k_1 < stoch_d_1);

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(long_channel_state && long_wpr_cross && long_stoch)
     {
      side = QM_BUY;
      reason = "TC20_S5_LONG";
     }
   else if(short_channel_state && short_wpr_cross && short_stoch)
     {
      side = QM_SELL;
      reason = "TC20_S5_SHORT";
     }
   else
      return false;

   double entry = 0.0;
   if(side == QM_BUY)
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   else
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      entry = close_1;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_tp);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, scale-in, or partial-close management.
  }

bool Strategy_ExitSignal()
  {
   double close_1 = 0.0;
   double close_2 = 0.0;
   if(!Strategy_ReadClosedCloses(close_1, close_2))
      return false;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         const double smma_high_1 = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_smma_period, 1, PRICE_HIGH);
         if(smma_high_1 > 0.0 && close_1 < smma_high_1)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double smma_low_1 = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_smma_period, 1, PRICE_LOW);
         if(smma_low_1 > 0.0 && close_1 > smma_low_1)
            return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11290\",\"ea\":\"QM5_11290_tc20_smma55_band_wpr_stoch_h1\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
