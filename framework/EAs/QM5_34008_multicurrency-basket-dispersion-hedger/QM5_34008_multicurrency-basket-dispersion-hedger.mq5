#property strict
#property version   "5.0"
#property description "QM5_34008 Multi-Currency Basket Correlation Dispersion Hedger"
// Strategy Card: QM5_34008 (multicurrency-basket-dispersion-hedger), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_34008
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 34008;
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
input int    strategy_lookback_hours      = 24;     // Basket mean rate-of-change lookback in hours
input double strategy_dispersion_dev      = 1.20;   // Standard deviation threshold for extreme pairs
input double strategy_target_profit_pct   = 1.5;    // Basket take-profit target in % of account balance
input double strategy_hard_stop_loss_pct  = 1.5;    // Basket hard stop-loss cutoff in % of account balance
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

int OpenPackageCount()
{
   int count = 0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      if((int)(magic / 10000) == qm_ea_id)
         count++;
   }
   return count;
}

double OpenPackagePnL()
{
   double total_pnl = 0.0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      if((int)(magic / 10000) == qm_ea_id)
         total_pnl += (PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP));
   }
   return total_pnl;
}

void CloseAllPackagePositions(const QM_ExitReason reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      if((int)(magic / 10000) == qm_ea_id)
         QM_TM_ClosePosition(ticket, reason);
   }
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

   if(OpenPackageCount() > 0)
      return false;

   const int lb = MathMax(5, strategy_lookback_hours);
   double usd_returns[BASKET_SIZE];

   for(int k = 0; k < BASKET_SIZE; ++k)
   {
      const string sym = g_basket_symbols[k];
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

   double sum_usd = 0.0;
   for(int k = 0; k < BASKET_SIZE; ++k)
      sum_usd += usd_returns[k];
   const double mean_usd = sum_usd / (double)BASKET_SIZE;

   double delta[BASKET_SIZE];
   double sum_sq_dev = 0.0;
   int min_idx = 0;
   int max_idx = 0;
   double min_delta = DBL_MAX;
   double max_delta = -DBL_MAX;

   for(int k = 0; k < BASKET_SIZE; ++k)
   {
      delta[k] = usd_returns[k] - mean_usd;
      sum_sq_dev += (delta[k] * delta[k]);
      if(delta[k] < min_delta)
      {
         min_delta = delta[k];
         min_idx = k;
      }
      if(delta[k] > max_delta)
      {
         max_delta = delta[k];
         max_idx = k;
      }
   }

   const double variance = sum_sq_dev / (double)BASKET_SIZE;
   if(variance <= 1e-10)
      return false;

   const double sigma = MathSqrt(variance);
   if(sigma <= 1e-6)
      return false;

   const double threshold = MathMax(0.5, strategy_dispersion_dev) * sigma;

   // Condition: min extremum <= -threshold AND max extremum >= +threshold
   if(min_delta > -threshold || max_delta < threshold || min_idx == max_idx)
      return false;

   const string sym_a = g_basket_symbols[min_idx];
   const int slot_a = min_idx;
   const QM_OrderType type_a = IsDirectUSDPair(sym_a) ? QM_BUY : QM_SELL;

   const string sym_b = g_basket_symbols[max_idx];
   const int slot_b = max_idx;
   const QM_OrderType type_b = IsDirectUSDPair(sym_b) ? QM_SELL : QM_BUY;

   const double atr_a = QM_ATR(sym_a, PERIOD_H1, strategy_atr_period, 1);
   const double point_a = SymbolInfoDouble(sym_a, SYMBOL_POINT);
   const double sl_pts_a = (atr_a > 0.0 && point_a > 0.0) ? (1.5 * atr_a / point_a) : 100.0;
   const double lots_a = QM_LotsForRisk(sym_a, sl_pts_a) * 0.5;

   const double atr_b = QM_ATR(sym_b, PERIOD_H1, strategy_atr_period, 1);
   const double point_b = SymbolInfoDouble(sym_b, SYMBOL_POINT);
   const double sl_pts_b = (atr_b > 0.0 && point_b > 0.0) ? (1.5 * atr_b / point_b) : 100.0;
   const double lots_b = QM_LotsForRisk(sym_b, sl_pts_b) * 0.5;

   if(lots_a <= 0.0 || lots_b <= 0.0)
      return false;

   QM_BasketOrderRequest req_a;
   req_a.symbol = sym_a;
   req_a.type = type_a;
   req_a.price = 0.0;
   req_a.sl = 0.0;
   req_a.tp = 0.0;
   req_a.lots = lots_a;
   req_a.reason = "Basket Dispersion Min-Delta Buy USD";
   req_a.symbol_slot = slot_a;
   req_a.expiration_seconds = 0;

   QM_BasketOrderRequest req_b;
   req_b.symbol = sym_b;
   req_b.type = type_b;
   req_b.price = 0.0;
   req_b.sl = 0.0;
   req_b.tp = 0.0;
   req_b.lots = lots_b;
   req_b.reason = "Basket Dispersion Max-Delta Sell USD";
   req_b.symbol_slot = slot_b;
   req_b.expiration_seconds = 0;

   ulong ticket_a = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, req_a, ticket_a))
      return false;

   ulong ticket_b = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, req_b, ticket_b))
   {
      CloseAllPackagePositions(QM_EXIT_STRATEGY);
      return false;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   // If package becomes unhedged / single orphan leg, close it out
   if(OpenPackageCount() == 1)
   {
      CloseAllPackagePositions(QM_EXIT_STRATEGY);
   }
}

bool Strategy_ExitSignal()
{
   if(OpenPackageCount() > 0)
   {
      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance > 0.0)
      {
         const double pnl = OpenPackagePnL();
         const double tp_val = balance * (strategy_target_profit_pct / 100.0);
         const double sl_val = balance * (strategy_hard_stop_loss_pct / 100.0);

         if(pnl >= tp_val || pnl <= -sl_val)
         {
            CloseAllPackagePositions(QM_EXIT_STRATEGY);
            return false;
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
      CloseAllPackagePositions(QM_EXIT_STRATEGY);
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
   Strategy_EntrySignal(req);
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
