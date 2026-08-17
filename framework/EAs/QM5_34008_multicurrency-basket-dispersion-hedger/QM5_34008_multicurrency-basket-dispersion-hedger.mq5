#property strict
#property version   "5.0"
#property description "QM5_34008 Multi-Currency Basket Correlation Dispersion Hedger"
// Strategy Card: QM5_34008 (multicurrency-basket-dispersion-hedger), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_34008
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 34008;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.5;
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
input int    strategy_lookback_hours      = 24;     // Basket mean rate-of-change lookback in hours
input double strategy_dispersion_dev      = 1.20;   // Standard deviation threshold for extreme pairs
input double strategy_tp_rr_mult          = 2.0;    // 1:2.0 Risk:Reward multiplier for TP
input int    strategy_atr_period          = 14;     // ATR lookback period for SL/spread
input double strategy_spread_atr_mult     = 1.8;    // Spread filter ATR multiplier

// -----------------------------------------------------------------------------
// Constants & Basket Universe
// -----------------------------------------------------------------------------

#define BASKET_SIZE 7
string g_basket_symbols[BASKET_SIZE] = {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "AUDUSD.DWX",
   "NZDUSD.DWX",
   "USDCAD.DWX",
   "USDCHF.DWX",
   "USDJPY.DWX"
};

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool IsDirectUSDPair(const string sym)
{
   return (StringFind(sym, "USD") == 0);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const int lb = MathMax(5, strategy_lookback_hours);
   double usd_returns[BASKET_SIZE];
   int my_index = -1;

   for(int k = 0; k < BASKET_SIZE; ++k)
   {
      const string sym = g_basket_symbols[k];
      if(sym == _Symbol)
         my_index = k;

      const double c1 = iClose(sym, PERIOD_H1, 1); // perf-allowed: closed-bar basket read behind QM_IsNewBar()
      const double c0 = iClose(sym, PERIOD_H1, 1 + lb); // perf-allowed: closed-bar basket read behind QM_IsNewBar()
      if(c1 <= 0.0 || c0 <= 0.0)
         return false;

      const double roc = (c1 - c0) / c0;
      if(IsDirectUSDPair(sym))
         usd_returns[k] = roc;
      else
         usd_returns[k] = -roc;
   }

   if(my_index < 0)
      return false;

   double sum_usd = 0.0;
   for(int k = 0; k < BASKET_SIZE; ++k)
      sum_usd += usd_returns[k];
   const double mean_usd = sum_usd / (double)BASKET_SIZE;

   double dev[BASKET_SIZE];
   double sum_sq_dev = 0.0;
   for(int k = 0; k < BASKET_SIZE; ++k)
   {
      dev[k] = usd_returns[k] - mean_usd;
      sum_sq_dev += (dev[k] * dev[k]);
   }

   const double variance = sum_sq_dev / (double)BASKET_SIZE;
   if(variance <= 1e-10)
      return false;

   const double sigma = MathSqrt(variance);
   if(sigma <= 1e-6)
      return false;

   const double my_z = dev[my_index] / sigma;
   const double threshold = MathMax(0.5, strategy_dispersion_dev);

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double min_sl_dist = (atr_1 > 0.0) ? (1.5 * atr_1) : (30.0 * point);
   const double sl_dist = min_sl_dist;
   const double tp_dist = strategy_tp_rr_mult * sl_dist;

   const bool is_direct = IsDirectUSDPair(_Symbol);

   // If my_z <= -threshold (USD lagged heavily vs this currency):
   // For direct pair (USD base): Buy pair to expect USD mean-reversion recovery
   // For inverted pair (USD quote): Sell pair to expect pair mean-reversion decline
   if(my_z <= -threshold)
   {
      if(is_direct)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double close_1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar read behind QM_IsNewBar()
         const double exec_price = (ask > 0.0) ? ask : close_1;
         req.type = QM_BUY;
         req.price = exec_price;
         req.sl = exec_price - sl_dist;
         req.tp = exec_price + tp_dist;
         req.reason = "Basket Dispersion USD Lag Long";
         return true;
      }
      else
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double close_1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar read behind QM_IsNewBar()
         const double exec_price = (bid > 0.0) ? bid : close_1;
         req.type = QM_SELL;
         req.price = exec_price;
         req.sl = exec_price + sl_dist;
         req.tp = exec_price - tp_dist;
         req.reason = "Basket Dispersion USD Lag Short";
         return true;
      }
   }

   // If my_z >= +threshold (USD gained excessively vs this currency):
   // For direct pair: Sell pair (expect USD to revert lower)
   // For inverted pair: Buy pair (expect pair to revert higher)
   if(my_z >= threshold)
   {
      if(is_direct)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double close_1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar read behind QM_IsNewBar()
         const double exec_price = (bid > 0.0) ? bid : close_1;
         req.type = QM_SELL;
         req.price = exec_price;
         req.sl = exec_price + sl_dist;
         req.tp = exec_price - tp_dist;
         req.reason = "Basket Dispersion USD Lead Short";
         return true;
      }
      else
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double close_1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar read behind QM_IsNewBar()
         const double exec_price = (ask > 0.0) ? ask : close_1;
         req.type = QM_BUY;
         req.price = exec_price;
         req.sl = exec_price - sl_dist;
         req.tp = exec_price + tp_dist;
         req.reason = "Basket Dispersion USD Lead Long";
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

   QM_SymbolGuardInit(g_basket_symbols);
   QM_BasketWarmupHistory(g_basket_symbols, PERIOD_H1, MathMax(60, strategy_lookback_hours + 10));

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
