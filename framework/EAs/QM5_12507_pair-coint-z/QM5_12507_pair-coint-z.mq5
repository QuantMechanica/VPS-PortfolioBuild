#property strict
#property version   "5.0"
#property description "QM5_12507 Pair Cointegration Z-Score"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12507;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    bandwidth_bars             = 250;
input double adf_pvalue_max             = 0.05;
input double z_entry                    = 1.0;
input double z_exit                     = 0.25;
input int    max_holding_bars           = 20;
input double residual_stop_mult         = 2.0;
input int    strategy_max_spread_points = 0;

#define STRATEGY_PAIR_COUNT 2
#define STRATEGY_SYMBOL_COUNT 4

string g_asset1[STRATEGY_PAIR_COUNT] = {"EURUSD.DWX", "NDX.DWX"};
string g_asset2[STRATEGY_PAIR_COUNT] = {"GBPUSD.DWX", "WS30.DWX"};
int    g_slot1[STRATEGY_PAIR_COUNT]  = {0, 2};
int    g_slot2[STRATEGY_PAIR_COUNT]  = {1, 3};

bool   g_basket_scope_ready = false;
int    g_active_pair = -1;
bool   g_state_ready = false;
bool   g_coint_valid = false;
double g_alpha = 0.0;
double g_beta = 0.0;
double g_residual_now = 0.0;
double g_residual_mean = 0.0;
double g_residual_sd = 0.0;
double g_z_now = 0.0;
double g_adf_t = 0.0;
double g_ecm_gamma = 0.0;
double g_entry_residual[STRATEGY_PAIR_COUNT] = {0.0, 0.0};
bool   g_entry_residual_set[STRATEGY_PAIR_COUNT] = {false, false};

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12507_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_PairIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      if(symbol == g_asset1[i] || symbol == g_asset2[i])
         return i;
     }
   return -1;
  }

int Strategy_SlotForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return qm_magic_slot_offset;
   if(symbol == g_asset1[pair_index])
      return g_slot1[pair_index];
   if(symbol == g_asset2[pair_index])
      return g_slot2[pair_index];
   return qm_magic_slot_offset;
  }

bool Strategy_IsPairLeg(const int pair_index, const string symbol)
  {
   return (pair_index >= 0 && pair_index < STRATEGY_PAIR_COUNT &&
           (symbol == g_asset1[pair_index] || symbol == g_asset2[pair_index]));
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   string allowed[STRATEGY_SYMBOL_COUNT] = {"EURUSD.DWX", "GBPUSD.DWX", "NDX.DWX", "WS30.DWX"};
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(allowed[i], true);

   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_H1, MathMax(bandwidth_bars + 10, 300));
   g_basket_scope_ready = true;
   return true;
  }

double Strategy_AdfCriticalFromP(const double p_value)
  {
   if(p_value <= 0.01)
      return -3.43;
   if(p_value <= 0.05)
      return -2.86;
   if(p_value <= 0.10)
      return -2.57;
   return -2.57;
  }

bool Strategy_CopyPairWindow(const int pair_index, const int count, double &x[], double &y[])
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || count < 30)
      return false;
   if(!Strategy_EnsureBasketScope())
      return false;
   if(!QM_SymbolAssertOrLog(g_asset1[pair_index]) || !QM_SymbolAssertOrLog(g_asset2[pair_index]))
      return false;

   datetime tx[];
   datetime ty[];
   ArraySetAsSeries(x, true);
   ArraySetAsSeries(y, true);
   ArraySetAsSeries(tx, true);
   ArraySetAsSeries(ty, true);

   // perf-allowed: called only after OnTick passes QM_IsNewBar(); bounded pair window.
   if(CopyClose(g_asset1[pair_index], (ENUM_TIMEFRAMES)_Period, 1, count, x) != count) // perf-allowed: bounded pair close read, called only from QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_asset2[pair_index], (ENUM_TIMEFRAMES)_Period, 1, count, y) != count) // perf-allowed: bounded pair close read, called only from QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyTime(g_asset1[pair_index], (ENUM_TIMEFRAMES)_Period, 1, count, tx) != count) // perf-allowed: bounded synchronization check, called only from QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyTime(g_asset2[pair_index], (ENUM_TIMEFRAMES)_Period, 1, count, ty) != count) // perf-allowed: bounded synchronization check, called only from QM_IsNewBar-gated EntrySignal.
      return false;

   for(int i = 0; i < count; ++i)
     {
      if(tx[i] != ty[i])
         return false;
      if(x[i] <= 0.0 || y[i] <= 0.0)
         return false;
      if(!MathIsValidNumber(x[i]) || !MathIsValidNumber(y[i]))
         return false;
     }
   return true;
  }

bool Strategy_OLS(const double &x[], const double &y[], const int count, double &alpha, double &beta)
  {
   alpha = 0.0;
   beta = 0.0;
   if(count < 30)
      return false;

   double sx = 0.0;
   double sy = 0.0;
   for(int i = 0; i < count; ++i)
     {
      sx += x[i];
      sy += y[i];
     }

   const double mx = sx / (double)count;
   const double my = sy / (double)count;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double dx = x[i] - mx;
      sxx += dx * dx;
      sxy += dx * (y[i] - my);
     }

   if(sxx <= DBL_EPSILON)
      return false;

   beta = sxy / sxx;
   alpha = my - beta * mx;
   return (MathIsValidNumber(alpha) && MathIsValidNumber(beta) && MathAbs(beta) > DBL_EPSILON);
  }

bool Strategy_BuildResiduals(const double &x[],
                             const double &y[],
                             const int count,
                             const double alpha,
                             const double beta,
                             double &residuals[])
  {
   ArrayResize(residuals, count);
   for(int i = 0; i < count; ++i)
     {
      residuals[i] = y[i] - (alpha + beta * x[i]);
      if(!MathIsValidNumber(residuals[i]))
         return false;
     }
   return true;
  }

bool Strategy_AdfTAndGamma(const double &residuals[], const int count, double &t_stat, double &gamma)
  {
   t_stat = 0.0;
   gamma = 0.0;
   const int obs = count - 1;
   if(obs < 20)
      return false;

   double sx = 0.0;
   double sy = 0.0;
   for(int i = 0; i < obs; ++i)
     {
      const double lagged = residuals[i + 1];
      const double delta = residuals[i] - residuals[i + 1];
      sx += lagged;
      sy += delta;
     }

   const double mx = sx / (double)obs;
   const double my = sy / (double)obs;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int i = 0; i < obs; ++i)
     {
      const double lagged = residuals[i + 1];
      const double delta = residuals[i] - residuals[i + 1];
      const double dx = lagged - mx;
      sxx += dx * dx;
      sxy += dx * (delta - my);
     }

   if(sxx <= DBL_EPSILON)
      return false;

   gamma = sxy / sxx;
   const double intercept = my - gamma * mx;
   double sse = 0.0;
   for(int i = 0; i < obs; ++i)
     {
      const double lagged = residuals[i + 1];
      const double delta = residuals[i] - residuals[i + 1];
      const double err = delta - (intercept + gamma * lagged);
      sse += err * err;
     }

   const double sigma2 = sse / (double)MathMax(1, obs - 2);
   if(sigma2 <= 0.0)
      return false;

   const double se = MathSqrt(sigma2 / sxx);
   if(se <= 0.0 || !MathIsValidNumber(se))
      return false;

   t_stat = gamma / se;
   return (MathIsValidNumber(t_stat) && MathIsValidNumber(gamma));
  }

bool Strategy_RefreshState(const int pair_index)
  {
   g_active_pair = pair_index;
   g_state_ready = false;
   g_coint_valid = false;
   g_alpha = 0.0;
   g_beta = 0.0;
   g_residual_now = 0.0;
   g_residual_mean = 0.0;
   g_residual_sd = 0.0;
   g_z_now = 0.0;
   g_adf_t = 0.0;
   g_ecm_gamma = 0.0;

   const int count = MathMax(30, bandwidth_bars);
   double x[];
   double y[];
   if(!Strategy_CopyPairWindow(pair_index, count, x, y))
      return false;
   if(!Strategy_OLS(x, y, count, g_alpha, g_beta))
      return false;

   double residuals[];
   if(!Strategy_BuildResiduals(x, y, count, g_alpha, g_beta, residuals))
      return false;
   if(!Strategy_AdfTAndGamma(residuals, count, g_adf_t, g_ecm_gamma))
      return false;

   g_coint_valid = (g_adf_t <= Strategy_AdfCriticalFromP(adf_pvalue_max) && g_ecm_gamma < 0.0);
   if(!g_coint_valid)
      return false;

   double sum = 0.0;
   for(int i = 0; i < count; ++i)
      sum += residuals[i];
   g_residual_mean = sum / (double)count;

   double var_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double d = residuals[i] - g_residual_mean;
      var_sum += d * d;
     }

   g_residual_sd = MathSqrt(var_sum / (double)MathMax(1, count - 1));
   if(g_residual_sd <= 0.0 || !MathIsValidNumber(g_residual_sd))
      return false;

   g_residual_now = residuals[0];
   g_z_now = (g_residual_now - g_residual_mean) / g_residual_sd;
   g_state_ready = MathIsValidNumber(g_z_now);
   return g_state_ready;
  }

bool Strategy_IsRegisteredPairPosition(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   if(!Strategy_IsPairLeg(pair_index, symbol))
      return false;

   const int slot = Strategy_SlotForSymbol(pair_index, symbol);
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
      if(Strategy_IsRegisteredPairPosition(pair_index))
         ++count;
     }
   return count;
  }

int Strategy_CurrentPairSide(const int pair_index)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsRegisteredPairPosition(pair_index))
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(symbol == g_asset1[pair_index])
         return (ptype == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

int Strategy_HeldBars(const int pair_index)
  {
   datetime first_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsRegisteredPairPosition(pair_index))
         continue;

      const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(first_time == 0 || pos_time < first_time)
         first_time = pos_time;
     }

   if(first_time <= 0)
      return 0;

   const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds <= 0)
      return 0;
   return (int)((TimeCurrent() - first_time) / seconds);
  }

void Strategy_ClosePair(const int pair_index, const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredPairPosition(pair_index))
         QM_TM_ClosePosition(ticket, reason);
     }

   if(pair_index >= 0 && pair_index < STRATEGY_PAIR_COUNT)
      g_entry_residual_set[pair_index] = false;
  }

bool Strategy_NewsAllowsPair(const int pair_index, const datetime broker_time)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return true;

   string symbols[2] = {g_asset1[pair_index], g_asset2[pair_index]};
   for(int i = 0; i < 2; ++i)
     {
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbols[i], broker_time, qm_news_temporal, qm_news_compliance))
            return false;
        }
      else if(!QM_NewsAllowsTrade(symbols[i], broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

bool Strategy_BuildLegRequest(const int pair_index,
                              const string symbol,
                              const int pair_side,
                              QM_BasketOrderRequest &req)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || pair_side == 0)
      return false;

   const bool is_asset1 = (symbol == g_asset1[pair_index]);
   const bool is_asset2 = (symbol == g_asset2[pair_index]);
   if(!is_asset1 && !is_asset2)
      return false;

   const bool buy_leg = is_asset1 ? (pair_side > 0) : (pair_side < 0);
   const QM_OrderType type = buy_leg ? QM_BUY : QM_SELL;
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0 || g_residual_sd <= 0.0)
      return false;

   const double beta_abs = MathMax(MathAbs(g_beta), DBL_EPSILON);
   const double residual_stop = residual_stop_mult * g_residual_sd;
   const double stop_dist = is_asset1 ? (residual_stop / beta_abs) : residual_stop;
   const double sl_points = stop_dist / point;
   if(sl_points <= 0.0 || !MathIsValidNumber(sl_points))
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = QM_TM_NormalizeVolume(symbol, QM_LotsForRisk(symbol, sl_points) * 0.5);
   req.reason = (pair_side > 0) ? "QM5_12507_LONG_ASSET1_SHORT_ASSET2"
                                : "QM5_12507_SHORT_ASSET1_LONG_ASSET2";
   req.symbol_slot = Strategy_SlotForSymbol(pair_index, symbol);
   req.expiration_seconds = 0;
   return (req.lots > 0.0);
  }

void Strategy_CopyLegRequestToEntry(const QM_BasketOrderRequest &src, QM_EntryRequest &dst)
  {
   dst.type = src.type;
   dst.price = src.price;
   dst.sl = src.sl;
   dst.tp = src.tp;
   dst.reason = src.reason;
   dst.symbol_slot = src.symbol_slot;
   dst.expiration_seconds = src.expiration_seconds;
  }

bool Strategy_OpenPair(const int pair_index, const int pair_side)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || pair_side == 0)
      return false;
   if(Strategy_OpenPairLegCount(pair_index) > 0)
      return false;

   QM_BasketOrderRequest req1;
   QM_BasketOrderRequest req2;
   if(!Strategy_BuildLegRequest(pair_index, g_asset1[pair_index], pair_side, req1))
      return false;
   if(!Strategy_BuildLegRequest(pair_index, g_asset2[pair_index], pair_side, req2))
      return false;

   QM_EntryRequest entry1;
   QM_EntryRequest entry2;
   Strategy_CopyLegRequestToEntry(req1, entry1);
   Strategy_CopyLegRequestToEntry(req2, entry2);

   ulong ticket1 = 0;
   if(req1.symbol == _Symbol)
     {
      if(!QM_TM_OpenPosition(entry1, ticket1))
         return false;
     }
   else if(req2.symbol == _Symbol)
     {
      if(!QM_TM_OpenPosition(entry2, ticket1))
         return false;
     }
   else
      return false;

   g_entry_residual[pair_index] = g_residual_now;
   g_entry_residual_set[pair_index] = true;
   return true;
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return true;

   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   if(qm_magic_slot_offset != Strategy_SlotForSymbol(pair_index, _Symbol))
      return true;

   if(strategy_max_spread_points > 0)
     {
      string symbols[2] = {g_asset1[pair_index], g_asset2[pair_index]};
      for(int i = 0; i < 2; ++i)
        {
         const long spread = SymbolInfoInteger(symbols[i], SYMBOL_SPREAD);
         if(spread <= 0 || spread > strategy_max_spread_points)
            return true;
        }
     }

   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return false;

   const int open_legs = Strategy_OpenPairLegCount(pair_index);
   if(!Strategy_RefreshState(pair_index))
     {
      if(open_legs > 0)
         Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
      return false;
     }

   int signal_side = 0;
   if(g_z_now > z_entry)
      signal_side = 1;
   else if(g_z_now < -z_entry)
      signal_side = -1;

   if(open_legs > 0)
     {
      const int current_side = Strategy_CurrentPairSide(pair_index);
      if(signal_side != 0 && current_side != 0 && signal_side != current_side)
        {
         Strategy_ClosePair(pair_index, QM_EXIT_OPPOSITE_SIGNAL);
         Strategy_OpenPair(pair_index, signal_side);
        }
      return false;
     }

   if(signal_side == 0)
      return false;

   Strategy_OpenPair(pair_index, signal_side);
   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return;

   const int legs = Strategy_OpenPairLegCount(pair_index);
   if(legs == 1)
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0 || Strategy_OpenPairLegCount(pair_index) <= 0)
      return false;

   if(g_state_ready)
     {
      const int side = Strategy_CurrentPairSide(pair_index);
      if(MathAbs(g_z_now) <= z_exit)
        {
         Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
         return false;
        }

      if(g_entry_residual_set[pair_index] && side != 0)
        {
         const double adverse = residual_stop_mult * g_residual_sd;
         if(side > 0 && g_residual_now >= g_entry_residual[pair_index] + adverse)
           {
            Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
            return false;
           }
         if(side < 0 && g_residual_now <= g_entry_residual[pair_index] - adverse)
           {
            Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
            return false;
           }
        }
     }

   if(max_holding_bars > 0 && Strategy_HeldBars(pair_index) >= max_holding_bars)
      Strategy_ClosePair(pair_index, QM_EXIT_TIME_STOP);

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index >= 0 && QM_FrameworkFridayCloseNow(broker_time))
     {
      Strategy_ClosePair(pair_index, QM_EXIT_FRIDAY_CLOSE);
      return true;
     }

   return !Strategy_NewsAllowsPair(pair_index, broker_time);
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
