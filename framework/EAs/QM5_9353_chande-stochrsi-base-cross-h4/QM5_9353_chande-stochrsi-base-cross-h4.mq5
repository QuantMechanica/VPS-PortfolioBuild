#property strict
#property version   "5.0"
#property description "QM5_9353 Chande Stochastic-RSI Base Cross H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9353
// Strategy Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9353_chande-stochrsi-base-cross-h4.md
// Source: Tushar Chande / Stanley Kroll (6e967762-b26d-59a3-b076-35c17f2e7c36)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9353;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_rsi_period        = 14;
input int    strategy_stoch_period      = 14;
input int    strategy_k_period          = 3;
input int    strategy_d_period          = 3;
input int    strategy_trend_sma_period  = 200;
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 1.8;
input double strategy_oversold_threshold   = 0.20;
input double strategy_overbought_threshold = 0.80;
input double strategy_profit_exit_atr_mult = 1.0;
input int    strategy_time_stop_bars    = 25;
input double strategy_spread_max_atr    = 0.15;
input int    strategy_warmup_bars       = 220;

// -----------------------------------------------------------------------------
// StochRSI Helper Functions
// -----------------------------------------------------------------------------

bool Strategy_InputsValid()
{
   return (strategy_rsi_period >= 7 && strategy_rsi_period <= 30 &&
           strategy_stoch_period >= 7 && strategy_stoch_period <= 30 &&
           strategy_k_period >= 2 && strategy_k_period <= 10 &&
           strategy_d_period >= 2 && strategy_d_period <= 10 &&
           strategy_trend_sma_period >= 50 && strategy_trend_sma_period <= 300 &&
           strategy_atr_period >= 7 && strategy_atr_period <= 30 &&
           strategy_sl_atr_mult >= 1.0 && strategy_sl_atr_mult <= 4.0 &&
           strategy_oversold_threshold >= 0.05 && strategy_oversold_threshold <= 0.35 &&
           strategy_overbought_threshold >= 0.65 && strategy_overbought_threshold <= 0.95 &&
           strategy_oversold_threshold < strategy_overbought_threshold &&
           strategy_profit_exit_atr_mult >= 0.5 && strategy_profit_exit_atr_mult <= 3.0 &&
           strategy_time_stop_bars >= 10 && strategy_time_stop_bars <= 60 &&
           strategy_spread_max_atr >= 0.05 && strategy_spread_max_atr <= 0.50 &&
           strategy_warmup_bars >= 100 && strategy_warmup_bars <= 300);
}

double ComputeStochRSIRaw(const int shift)
{
   const double current_rsi = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift, PRICE_CLOSE);
   double min_rsi = current_rsi;
   double max_rsi = current_rsi;

   for(int i = 1; i < strategy_stoch_period; ++i)
   {
      const double r = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift + i, PRICE_CLOSE);
      if(r < min_rsi) min_rsi = r;
      if(r > max_rsi) max_rsi = r;
   }

   const double denom = max_rsi - min_rsi;
   if(denom <= 0.000001)
      return 0.5; // Chande neutral convention

   return (current_rsi - min_rsi) / denom;
}

double ComputePercentK(const int shift)
{
   double sum = 0.0;
   for(int i = 0; i < strategy_k_period; ++i)
      sum += ComputeStochRSIRaw(shift + i);
   return sum / (double)strategy_k_period;
}

double ComputePercentD(const int shift)
{
   double sum = 0.0;
   for(int i = 0; i < strategy_d_period; ++i)
      sum += ComputePercentK(shift + i);
   return sum / (double)strategy_d_period;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(iBars(_Symbol, PERIOD_H4) < strategy_warmup_bars) // perf-allowed: one H4 readiness check on the entry-only path after the new-bar gate.
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr > 0.0 && ask > bid && (ask - bid) > (strategy_spread_max_atr * atr))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(iBars(_Symbol, PERIOD_H4) < strategy_warmup_bars) // perf-allowed: fail-closed H4 warmup confirmation once per decision bar.
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double k1 = ComputePercentK(1);
   const double d1 = ComputePercentD(1);
   const double k2 = ComputePercentK(2);
   const double d2 = ComputePercentD(2);

   const double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: one completed H4 close behind the framework H4 new-bar gate.
   const double sma200 = QM_SMA(_Symbol, PERIOD_H4, strategy_trend_sma_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || sma200 <= 0.0)
      return false;

   // BUY Signal: %K crosses above %D from oversold (< 0.20) and Close > SMA(200)
   const bool buy_cross = (k2 <= d2 && k1 > d1);
   if(buy_cross && k2 < strategy_oversold_threshold && close1 > sma200)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "STOCHRSI_OVERSOLD_CROSS_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // SELL Signal: %K crosses below %D from overbought (> 0.80) and Close < SMA(200)
   const bool sell_cross = (k2 >= d2 && k1 < d1);
   if(sell_cross && k2 > strategy_overbought_threshold && close1 < sma200)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "STOCHRSI_OVERBOUGHT_CROSS_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_H4, open_time, false); // perf-allowed: one bounded position-age lookup for the card's H4 time stop.
      if(bars_held >= strategy_time_stop_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) == 0)
      return false;

   const double k1 = ComputePercentK(1);
   const double d1 = ComputePercentD(1);
   const double k2 = ComputePercentK(2);
   const double d2 = ComputePercentD(2);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

      if(ptype == POSITION_TYPE_BUY)
      {
         const bool cross_down = (k2 >= d2 && k1 < d1);
         if(cross_down)
         {
            // Primary exit: %K was in overbought when cross-down occurred
            if(k2 > strategy_overbought_threshold)
               return true;

            // Secondary exit: position in profit by at least 1.0 * ATR
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(atr > 0.0 && bid > 0.0 && (bid - open_price) >= (strategy_profit_exit_atr_mult * atr))
               return true;
         }
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         const bool cross_up = (k2 <= d2 && k1 > d1);
         if(cross_up)
         {
            // Primary exit: %K was in oversold when cross-up occurred
            if(k2 < strategy_oversold_threshold)
               return true;

            // Secondary exit: position in profit by at least 1.0 * ATR
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(atr > 0.0 && ask > 0.0 && (open_price - ask) >= (strategy_profit_exit_atr_mult * atr))
               return true;
         }
      }
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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        60, 60, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H4,
                                            QM_FRIDAY_CLOSE_CARD_RULE,
                                            "QM5_9353 Chande StochRSI base cross H4"))
      return INIT_FAILED;

   if(!Strategy_InputsValid())
   {
      QM_LogEvent(QM_ERROR, "SETUP_CONFIG_INVALID", "{\"component\":\"strategy_inputs\"}");
      return INIT_PARAMETERS_INCORRECT;
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(Strategy_NoTradeFilter())
      return;

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
