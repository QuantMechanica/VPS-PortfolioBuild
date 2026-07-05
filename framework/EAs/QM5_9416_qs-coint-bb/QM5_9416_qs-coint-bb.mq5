#property strict
#property version   "5.0"
#property description "QM5_9416 QuantStart Cointegrated Spread Bollinger Pair"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_9416 - QuantStart Cointegrated Spread Bollinger Pair (rebuild)
// -----------------------------------------------------------------------------
// D1 two-leg index-pair mean reversion, ported from the QuantStart ARNC/UNG
// cointegration article. Two host pairs share this EA:
//   pair 0: y=SP500.DWX (host, slot 0) / x=NDX.DWX  (slot 1)
//   pair 1: y=WS30.DWX  (host, slot 2) / x=NDX.DWX  (slot 1)
// The active pair is selected by the chart symbol (_Symbol). The EA opens BOTH
// legs from the host chart via QM_BasketOrder (QM_BasketOpenPosition), so a
// single Q02 work item per host symbol exercises the full spread trade.
//
// Mechanics per the approved card:
//   hedge ratio beta = OLS(y ~ x) over strategy_ols_period D1 closes,
//   re-estimated every strategy_reestimate_bars (~monthly). A CADF-style
//   single-lag Dickey-Fuller test on the OLS residuals gates entry; the
//   in-sample beta must also stay within [strategy_beta_min, strategy_beta_max].
//   spread_t = y_t - beta * x_t; z-score over the most recent
//   strategy_bb_period closes. |z| >= entry_z opens the spread; reversion to
//   |z| <= exit_z, |z| >= stop_z, or a scheduled cointegration/beta re-check
//   failure closes both legs.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9416;
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
input int    strategy_ols_period          = 252;   // OLS/CADF in-sample window (~1yr D1)
input int    strategy_reestimate_bars     = 21;     // hedge-ratio re-estimate cadence (~monthly)
input int    strategy_bb_period           = 15;     // spread mean/stdev lookback (card-fixed)
input double strategy_entry_z             = 1.5;
input double strategy_exit_z              = 0.5;
input double strategy_stop_z              = 4.0;
input double strategy_beta_min            = 0.25;
input double strategy_beta_max            = 4.0;
input double strategy_cadf_critical_value = -3.34;  // Engle-Granger 5% 2-var asymptotic critical value (MacKinnon)
input int    strategy_atr_period_d1       = 14;
input double strategy_atr_sizing_mult     = 2.0;
input int    strategy_deviation_points    = 20;

#define STRATEGY_PAIR_COUNT 2

string g_pair_y[STRATEGY_PAIR_COUNT]      = {"SP500.DWX", "WS30.DWX"};
string g_pair_x[STRATEGY_PAIR_COUNT]      = {"NDX.DWX",   "NDX.DWX"};
int    g_pair_y_slot[STRATEGY_PAIR_COUNT] = {0, 2};
int    g_pair_x_slot[STRATEGY_PAIR_COUNT] = {1, 1};

int      g_active_pair          = -1;
double   g_beta                 = 0.0;
bool     g_beta_valid           = false;
bool     g_cadf_valid           = false;
double   g_cadf_tstat           = 0.0;
int      g_bars_since_reestimate = 999999;
double   g_zscore               = 0.0;
double   g_spread_mean          = 0.0;
double   g_spread_sd            = 0.0;
bool     g_state_ready          = false;
datetime g_last_state_bar       = 0;
datetime g_pair_entry_time      = 0;

int Strategy_ActivePairIndex()
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
      if(_Symbol == g_pair_y[i])
         return i;
   return -1;
  }

int Strategy_SlotForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return -1;
   if(symbol == g_pair_y[pair_index])
      return g_pair_y_slot[pair_index];
   if(symbol == g_pair_x[pair_index])
      return g_pair_x_slot[pair_index];
   return -1;
  }

bool Strategy_IsPairLegPosition(const int pair_index)
  {
   if(pair_index < 0)
      return false;
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(pair_index, symbol);
   if(slot < 0)
      return false;
   const int expected_magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   return (expected_magic > 0 && (int)PositionGetInteger(POSITION_MAGIC) == expected_magic);
  }

int Strategy_OpenPairLegCount(const int pair_index)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairLegPosition(pair_index))
         ++count;
     }
   return count;
  }

int Strategy_CurrentPairDirection(const int pair_index)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pair_y[pair_index])
         continue;
      if(!Strategy_IsPairLegPosition(pair_index))
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         return 1;
      if(ptype == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

void Strategy_ClosePair(const int pair_index, const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairLegPosition(pair_index))
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_CopyPairCloses(const int pair_index, const int count, double &y[], double &x[])
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || count < 5)
      return false;

   ArraySetAsSeries(y, true);
   ArraySetAsSeries(x, true);
   if(CopyClose(g_pair_y[pair_index], PERIOD_D1, 1, count, y) != count) // perf-allowed: bounded D1 pair read, gated to at most once per closed bar via Strategy_RefreshState's bar-boundary guard.
      return false;
   if(CopyClose(g_pair_x[pair_index], PERIOD_D1, 1, count, x) != count) // perf-allowed: bounded D1 pair read, gated to at most once per closed bar via Strategy_RefreshState's bar-boundary guard.
      return false;

   for(int i = 0; i < count; ++i)
     {
      if(y[i] <= 0.0 || x[i] <= 0.0 || !MathIsValidNumber(y[i]) || !MathIsValidNumber(x[i]))
         return false;
     }
   return true;
  }

bool Strategy_EstimateOLS(const double &y[], const double &x[], const int n, double &beta)
  {
   beta = 0.0;
   if(n < 30)
      return false;

   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int i = 0; i < n; ++i)
     {
      sx  += x[i];
      sy  += y[i];
      sxx += x[i] * x[i];
      sxy += x[i] * y[i];
     }
   const double nd = (double)n;
   const double denom = nd * sxx - sx * sx;
   if(MathAbs(denom) <= 1.0e-9)
      return false;

   beta = (nd * sxy - sx * sy) / denom;
   return MathIsValidNumber(beta);
  }

// Single-lag Engle-Granger/CADF style test on the OLS residual series:
// delta_e_t = phi * e_(t-1) + u_t ; reject non-cointegration when the
// t-statistic on phi is below a fixed literature critical value (deterministic,
// no fitted/learned parameters beyond the closed-form regression itself).
bool Strategy_ComputeCADF(const double &y[], const double &x[], const double beta, const int n, double &tstat)
  {
   tstat = 0.0;
   if(n < 30)
      return false;

   double e[];
   ArrayResize(e, n);
   for(int i = 0; i < n; ++i)
     {
      e[i] = y[i] - beta * x[i];
      if(!MathIsValidNumber(e[i]))
         return false;
     }

   const int m = n - 1;
   double s_dl = 0.0, s_ll = 0.0;
   for(int i = 0; i < m; ++i)
     {
      const double delta_i  = e[i] - e[i + 1];
      const double lagged_i = e[i + 1];
      s_dl += delta_i * lagged_i;
      s_ll += lagged_i * lagged_i;
     }
   if(s_ll <= 1.0e-9)
      return false;

   const double phi = s_dl / s_ll;
   if(!MathIsValidNumber(phi))
      return false;

   double ssr = 0.0;
   for(int i = 0; i < m; ++i)
     {
      const double delta_i  = e[i] - e[i + 1];
      const double lagged_i = e[i + 1];
      const double u = delta_i - phi * lagged_i;
      ssr += u * u;
     }
   const int df = m - 1;
   if(df <= 0)
      return false;

   const double se = MathSqrt((ssr / (double)df) / s_ll);
   if(se <= 0.0 || !MathIsValidNumber(se))
      return false;

   tstat = phi / se;
   return MathIsValidNumber(tstat);
  }

void Strategy_ReestimateHedgeAndCADF(const int pair_index)
  {
   g_beta_valid = false;
   g_cadf_valid = false;

   double y[], x[];
   if(!Strategy_CopyPairCloses(pair_index, strategy_ols_period, y, x))
      return;

   double beta = 0.0;
   if(!Strategy_EstimateOLS(y, x, strategy_ols_period, beta))
      return;

   g_beta = beta;
   if(beta < strategy_beta_min || beta > strategy_beta_max)
      return; // out of range -> stays invalid, ExitSignal will close any open pair

   double tstat = 0.0;
   if(!Strategy_ComputeCADF(y, x, beta, strategy_ols_period, tstat))
      return;

   g_cadf_tstat = tstat;
   g_beta_valid = true;
   g_cadf_valid = (tstat <= strategy_cadf_critical_value);
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   if(g_active_pair < 0)
      return false;

   ++g_bars_since_reestimate;
   if(g_bars_since_reestimate >= strategy_reestimate_bars || !g_beta_valid)
     {
      Strategy_ReestimateHedgeAndCADF(g_active_pair);
      if(g_beta_valid)
         g_bars_since_reestimate = 0;
     }

   if(!g_beta_valid || !g_cadf_valid)
      return false;

   double y[], x[];
   if(!Strategy_CopyPairCloses(g_active_pair, strategy_bb_period, y, x))
      return false;

   double spreads[];
   ArrayResize(spreads, strategy_bb_period);
   double sum = 0.0;
   for(int i = 0; i < strategy_bb_period; ++i)
     {
      spreads[i] = y[i] - g_beta * x[i];
      if(!MathIsValidNumber(spreads[i]))
         return false;
      sum += spreads[i];
     }
   const double mean = sum / (double)strategy_bb_period;

   double var_sum = 0.0;
   for(int i = 0; i < strategy_bb_period; ++i)
     {
      const double d = spreads[i] - mean;
      var_sum += d * d;
     }
   const double sd = MathSqrt(var_sum / (double)MathMax(1, strategy_bb_period - 1));
   if(sd <= 0.0 || !MathIsValidNumber(sd))
      return false;

   g_spread_mean = mean;
   g_spread_sd   = sd;
   g_zscore      = (spreads[0] - mean) / sd;
   g_state_ready = MathIsValidNumber(g_zscore);
   if(g_state_ready)
      g_last_state_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cheap D1 timestamp guard after a successful state refresh.
   return g_state_ready;
  }

double Strategy_HedgeWeight(const int pair_index)
  {
   const double y_price = iClose(g_pair_y[pair_index], PERIOD_D1, 1); // perf-allowed: single cached D1 close read during new-bar entry sizing only.
   const double x_price = iClose(g_pair_x[pair_index], PERIOD_D1, 1); // perf-allowed: single cached D1 close read during new-bar entry sizing only.
   if(y_price <= 0.0 || x_price <= 0.0)
      return MathMax(0.01, MathAbs(g_beta));
   return MathMax(0.01, MathAbs(g_beta) * x_price / y_price);
  }

double Strategy_LotsForLeg(const string symbol, const double weight, const double weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || weight <= 0.0 || weight_sum <= 0.0)
      return 0.0;

   const double sizing_points = strategy_atr_sizing_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sizing_points) * weight / weight_sum;

   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

bool Strategy_OpenLeg(const int pair_index, const string symbol, const QM_OrderType type,
                      const double lots, const string reason)
  {
   const int slot = Strategy_SlotForSymbol(pair_index, symbol);
   if(slot < 0 || lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol             = symbol;
   req.type               = type;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.lots               = lots;
   req.reason             = reason;
   req.symbol_slot        = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int pair_index, const int direction)
  {
   if(pair_index < 0 || direction == 0 || Strategy_OpenPairLegCount(pair_index) > 0)
      return false;
   if(!g_beta_valid || !g_cadf_valid)
      return false;

   const string y_sym = g_pair_y[pair_index];
   const string x_sym = g_pair_x[pair_index];

   const double y_weight   = 1.0;
   const double x_weight   = Strategy_HedgeWeight(pair_index);
   const double weight_sum = y_weight + x_weight;

   const bool long_spread = (direction > 0);
   const QM_OrderType y_type = long_spread ? QM_BUY  : QM_SELL;
   const QM_OrderType x_type = long_spread ? QM_SELL : QM_BUY;
   const string reason = long_spread ? "COINT_BB_LONG_SPREAD" : "COINT_BB_SHORT_SPREAD";

   const double y_lots = Strategy_LotsForLeg(y_sym, y_weight, weight_sum);
   const double x_lots = Strategy_LotsForLeg(x_sym, x_weight, weight_sum);
   if(y_lots <= 0.0 || x_lots <= 0.0)
      return false;

   const bool x_ok = Strategy_OpenLeg(pair_index, x_sym, x_type, x_lots, reason);
   const bool y_ok = Strategy_OpenLeg(pair_index, y_sym, y_type, y_lots, reason);
   if(x_ok && y_ok)
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NewsAllowsPair(const datetime broker_time)
  {
   const int pair_index = Strategy_ActivePairIndex();
   if(pair_index < 0)
      return true;

   for(int leg = 0; leg < 2; ++leg)
     {
      const string symbol = (leg == 0) ? g_pair_y[pair_index] : g_pair_x[pair_index];
      bool ok = true;
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
         ok = QM_NewsAllowsTrade2(symbol, broker_time, qm_news_temporal, qm_news_compliance);
      else
         ok = QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy);
      if(!ok)
         return false;
     }
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int pair_index = Strategy_ActivePairIndex();
   if(pair_index < 0)
      return true;
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != g_pair_y_slot[pair_index])
      return true;
   if(strategy_ols_period < 30 || strategy_bb_period < 5)
      return true;
   if(strategy_entry_z <= 0.0 || strategy_exit_z < 0.0 || strategy_stop_z <= strategy_entry_z)
      return true;
   if(strategy_beta_min <= 0.0 || strategy_beta_max <= strategy_beta_min)
      return true;
   if(strategy_reestimate_bars < 5)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_active_pair = Strategy_ActivePairIndex();
   if(g_active_pair < 0 || Strategy_OpenPairLegCount(g_active_pair) > 0)
      return false;
   if(!Strategy_RefreshState())
      return false;

   int direction = 0;
   if(g_zscore < -strategy_entry_z)
      direction = 1;    // long spread: long y-leg, short beta-adjusted x-leg
   else if(g_zscore > strategy_entry_z)
      direction = -1;   // short spread: short y-leg, long beta-adjusted x-leg
   else
      return false;

   Strategy_OpenPair(g_active_pair, direction);
   return false; // legs already opened via QM_BasketOpenPosition above
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(g_active_pair < 0)
      g_active_pair = Strategy_ActivePairIndex();
   if(g_active_pair < 0)
      return false;

   const int legs = Strategy_OpenPairLegCount(g_active_pair);
   if(legs <= 0)
      return false;
   if(legs != 2)
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY); // leg unavailable
      return false;
     }

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cheap D1 timestamp guard before optional state refresh.
   if(current_bar > 0 && current_bar != g_last_state_bar)
      Strategy_RefreshState();
   if(!g_state_ready)
      return false;

   if(!g_beta_valid || !g_cadf_valid)
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY); // scheduled cointegration/beta re-check failed
      return false;
     }

   if(MathAbs(g_zscore) >= strategy_stop_z)
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   const int direction = Strategy_CurrentPairDirection(g_active_pair);
   if(direction > 0 && g_zscore >= -strategy_exit_z)
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
   else if(direction < 0 && g_zscore <= strategy_exit_z)
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const int pair_index = Strategy_ActivePairIndex();
   if(pair_index < 0)
      return false;
   if(QM_FrameworkFridayCloseNow(broker_time))
     {
      Strategy_ClosePair(pair_index, QM_EXIT_FRIDAY_CLOSE);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      SymbolSelect(g_pair_y[i], true);
      SymbolSelect(g_pair_x[i], true);
     }

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   string basket_symbols[3] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, strategy_ols_period + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9416\",\"ea\":\"qs-coint-bb\"}");
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

   // Friday-close forces both legs flat; must run ahead of management so a
   // basket EA (single host instance controlling two symbols) never carries
   // the non-host leg over the weekend.
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // News blackout gates NEW entries only (below). It must not sit above the
   // management/exit path above: neither leg carries a server-side SL, so the
   // zscore stop-out is the only protection and has to keep enforcing through
   // news windows (2026-07-02 audit finding; see QM5_12821 reference OnTick).
   if(!Strategy_NewsAllowsPair(broker_now))
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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
