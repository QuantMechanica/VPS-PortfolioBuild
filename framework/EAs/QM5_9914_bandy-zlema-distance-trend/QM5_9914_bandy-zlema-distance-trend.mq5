#property strict
#property version   "5.0"
#property description "QM5_9914 Bandy ZLEMA Distance Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9914
// Strategy Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9914_bandy-zlema-distance-trend.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9914;
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
input int    strategy_zlema_period      = 20;
input int    strategy_zlema_lag         = 10;
input int    strategy_atr_period        = 14;
input double strategy_distance_atr_mult = 1.0;
input int    strategy_regime_sma_period = 200;
input double strategy_sl_atr_mult       = 3.0;
input int    strategy_time_stop_days    = 30;
input double strategy_spread_max_atr    = 0.25;
input int    strategy_warmup_bars       = 250;

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

double ComputeZLEMA(const int period, const int lag, const int shift=1)
{
   const int warmup = period * 5 + lag + 10;
   if(iBars(_Symbol, PERIOD_D1) < warmup + shift)
      return 0.0;

   const double alpha = 2.0 / (period + 1.0);
   const int oldest_bar = warmup + shift - 1;
   const double c_old = iClose(_Symbol, PERIOD_D1, oldest_bar); // perf-allowed: ZLEMA lag calculation
   const double c_lag_old = iClose(_Symbol, PERIOD_D1, oldest_bar + lag); // perf-allowed: ZLEMA lag calculation
   if(c_old <= 0.0 || c_lag_old <= 0.0)
      return 0.0;

   double zlema = 2.0 * c_old - c_lag_old;
   for(int b = oldest_bar - 1; b >= shift; --b)
   {
      const double c = iClose(_Symbol, PERIOD_D1, b); // perf-allowed: ZLEMA lag calculation
      const double c_lag = iClose(_Symbol, PERIOD_D1, b + lag); // perf-allowed: ZLEMA lag calculation
      const double val = 2.0 * c - c_lag;
      zlema = alpha * val + (1.0 - alpha) * zlema;
   }
   return zlema;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr > 0.0 && ask > bid && (ask - bid) > (strategy_spread_max_atr * atr))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: signal bar close
   const double atr14  = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double regime = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   const double zlema  = ComputeZLEMA(strategy_zlema_period, strategy_zlema_lag, 1);

   if(close1 <= 0.0 || atr14 <= 0.0 || regime <= 0.0 || zlema <= 0.0)
      return false;

   const double distance = close1 - zlema;

   if(distance >= (strategy_distance_atr_mult * atr14) && close1 > regime)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "BANDY_ZLEMA_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }
   else if(distance <= -(strategy_distance_atr_mult * atr14) && close1 < regime)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "BANDY_ZLEMA_SELL";
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

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: signal bar close
   const double zlema  = ComputeZLEMA(strategy_zlema_period, strategy_zlema_lag, 1);

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
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(bars_held >= strategy_time_stop_days)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      if(zlema > 0.0 && close1 > 0.0)
      {
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pos_type == POSITION_TYPE_BUY && close1 < zlema)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         }
         else if(pos_type == POSITION_TYPE_SELL && close1 > zlema)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         }
      }
   }
}

bool Strategy_ExitSignal()
{
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
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}

