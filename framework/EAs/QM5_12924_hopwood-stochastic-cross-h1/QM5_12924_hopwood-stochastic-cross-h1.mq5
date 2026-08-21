#property strict
#property version   "5.0"
#property description "QM5_12924 Hopwood Stochastic Cross H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12924 Hopwood Stochastic Cross H1 Trend-Follower
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12924;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_stoch_k           = 14;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input int    strategy_ema_period        = 200;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_tp_rr_mult        = 2.0;
input double strategy_oversold_level    = 30.0;
input double strategy_overbought_level  = 70.0;
input int    strategy_max_spread_points = 25;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(strategy_max_spread_points > 0)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(bid > 0.0 && ask > 0.0 && point > 0.0 && ask > bid &&
         (ask - bid) > strategy_max_spread_points * point)
         return true;
   }
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

   if(strategy_stoch_k <= 0 || strategy_stoch_d <= 0 || strategy_stoch_slowing <= 0 ||
      strategy_ema_period <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double k_1 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d_1 = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k_2 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d_2 = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const int price_ma_bias = QM_Sig_Price_Above_MA(_Symbol, PERIOD_H1, strategy_ema_period, 0.0, 1);

   if(k_1 < 0.0 || d_1 < 0.0 || k_2 < 0.0 || d_2 < 0.0 || atr_1 <= 0.0)
      return false;

   const bool bullish_cross = (k_1 > d_1 && k_2 <= d_2);
   const bool bearish_cross = (k_1 < d_1 && k_2 >= d_2);

   if(bullish_cross && k_1 < strategy_oversold_level && price_ma_bias > 0)
   {
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr_1, strategy_atr_sl_mult);
      if(req.sl > 0.0 && req.sl < ask)
      {
         const double sl_dist = ask - req.sl;
         req.tp = (strategy_tp_rr_mult > 0.0) ? (ask + sl_dist * strategy_tp_rr_mult) : 0.0;
         req.reason = "STOCH_CROSS_LONG";
         return true;
      }
   }

   if(bearish_cross && k_1 > strategy_overbought_level && price_ma_bias < 0)
   {
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, atr_1, strategy_atr_sl_mult);
      if(req.sl > bid)
      {
         const double sl_dist = req.sl - bid;
         req.tp = (strategy_tp_rr_mult > 0.0) ? (bid - sl_dist * strategy_tp_rr_mult) : 0.0;
         req.reason = "STOCH_CROSS_SHORT";
         return true;
      }
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   bool have_position = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
      break;
   }

   if(!have_position)
      return false;

   const double k_1 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d_1 = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k_2 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d_2 = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);

   if(k_1 < 0.0 || d_1 < 0.0 || k_2 < 0.0 || d_2 < 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
   {
      const bool bearish_cross = (k_1 < d_1 && k_2 >= d_2);
      if(bearish_cross)
         return true;
   }
   else if(pos_type == POSITION_TYPE_SELL)
   {
      const bool bullish_cross = (k_1 > d_1 && k_2 <= d_2);
      if(bullish_cross)
         return true;
   }

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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
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
