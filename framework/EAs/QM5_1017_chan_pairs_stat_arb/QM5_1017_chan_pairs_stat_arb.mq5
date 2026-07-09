#property strict
#property version   "5.1"
#property description "QM5_1017 Chan AUDUSD NZDUSD Cointegration Pair"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1017;
input int    qm_magic_slot_offset         = 4;     // AUDUSD.DWX registry slot; NZDUSD.DWX uses slot 26.

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false; // CEO-approved waiver recorded in the Strategy Card.
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input string pair_symbol_1                = "AUDUSD.DWX";
input string pair_symbol_2                = "NZDUSD.DWX";
input bool   cadf_gate_enabled            = true;
input double cointegration_significance   = 0.05;
input int    training_lookback            = 252;
input double entry_z                      = 2.0;
input double exit_z                       = 1.0;
input int    deployment_halflife_cap_days = 30;
input double time_stop_multiplier         = 1.0;
input int    strategy_deviation_points    = 20;

#define STRATEGY_SYMBOL_COUNT 2
#define STRATEGY_PRIMARY_SLOT 4
#define STRATEGY_HEDGE_SLOT   26

string g_pair_symbols[STRATEGY_SYMBOL_COUNT];
int    g_pair_slots[STRATEGY_SYMBOL_COUNT] = {STRATEGY_PRIMARY_SLOT, STRATEGY_HEDGE_SLOT};

bool     g_basket_scope_ready = false;
bool     g_model_ready = false;
bool     g_deployment_gate_pass = false;
double   g_hedge_ratio = 0.0;
double   g_spread_mean = 0.0;
double   g_spread_stdev = 0.0;
double   g_adf_t_stat = 0.0;
double   g_halflife_days = 0.0;
double   g_z_now = 0.0;
int      g_fit_year = -1;
datetime g_last_signal_bar = 0;

string Strategy_BoolJson(const bool value)
  {
   return value ? "true" : "false";
  }

int Strategy_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(symbol == g_pair_symbols[i])
         return i;
   return -1;
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   const int index = Strategy_SymbolIndex(symbol);
   if(index < 0)
      return -1;
   return g_pair_slots[index];
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   if(g_pair_symbols[0] == "" || g_pair_symbols[1] == "" || g_pair_symbols[0] == g_pair_symbols[1])
      return false;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(!SymbolSelect(g_pair_symbols[i], true))
         return false;

   QM_SymbolGuardInit(g_pair_symbols);
   QM_BasketWarmupHistory(g_pair_symbols, PERIOD_D1, MathMax(training_lookback + 20, 300));
   g_basket_scope_ready = true;
   return true;
  }

bool Strategy_CopyTrainingCloses(double &leg1[], double &leg2[])
  {
   if(training_lookback < 30 || !Strategy_EnsureBasketScope())
      return false;

   const int count = training_lookback + 2;
   ArraySetAsSeries(leg1, true);
   ArraySetAsSeries(leg2, true);
   if(CopyClose(g_pair_symbols[0], PERIOD_D1, 1, count, leg1) != count) // perf-allowed: bounded D1 pair read, called only from the D1 new-bar path.
      return false;
   if(CopyClose(g_pair_symbols[1], PERIOD_D1, 1, count, leg2) != count) // perf-allowed: bounded D1 pair read, called only from the D1 new-bar path.
      return false;

   for(int i = 0; i < count; ++i)
     {
      if(leg1[i] <= 0.0 || leg2[i] <= 0.0)
         return false;
      if(!MathIsValidNumber(leg1[i]) || !MathIsValidNumber(leg2[i]))
         return false;
     }
   return true;
  }

double Strategy_CadfCriticalValue(const double significance)
  {
   if(significance <= 0.01)
      return -3.819;
   if(significance <= 0.05)
      return -3.343;
   return -3.042;
  }

bool Strategy_AdfOneLagTStat(const double &residuals[], const int count, double &t_stat)
  {
   t_stat = 0.0;
   if(count < 30)
      return false;

   double n = 0.0;
   double sx1 = 0.0, sx2 = 0.0;
   double sx1x1 = 0.0, sx1x2 = 0.0, sx2x2 = 0.0;
   double sy = 0.0, sx1y = 0.0, sx2y = 0.0;

   for(int i = 2; i < count; ++i)
     {
      const double y = residuals[i] - residuals[i - 1];
      const double x1 = residuals[i - 1];
      const double x2 = residuals[i - 1] - residuals[i - 2];
      n += 1.0;
      sx1 += x1;
      sx2 += x2;
      sx1x1 += x1 * x1;
      sx1x2 += x1 * x2;
      sx2x2 += x2 * x2;
      sy += y;
      sx1y += x1 * y;
      sx2y += x2 * y;
     }

   if(n <= 3.0)
      return false;

   const double determinant =
      n * (sx1x1 * sx2x2 - sx1x2 * sx1x2)
      - sx1 * (sx1 * sx2x2 - sx2 * sx1x2)
      + sx2 * (sx1 * sx1x2 - sx2 * sx1x1);
   if(MathAbs(determinant) < 1e-20)
      return false;

   const double inv00 = (sx1x1 * sx2x2 - sx1x2 * sx1x2) / determinant;
   const double inv01 = (sx2 * sx1x2 - sx1 * sx2x2) / determinant;
   const double inv02 = (sx1 * sx1x2 - sx2 * sx1x1) / determinant;
   const double inv11 = (n * sx2x2 - sx2 * sx2) / determinant;
   const double inv12 = (sx1 * sx2 - n * sx1x2) / determinant;
   const double inv22 = (n * sx1x1 - sx1 * sx1) / determinant;

   const double intercept = inv00 * sy + inv01 * sx1y + inv02 * sx2y;
   const double gamma = inv01 * sy + inv11 * sx1y + inv12 * sx2y;
   const double lag_delta = inv02 * sy + inv12 * sx1y + inv22 * sx2y;

   double sse = 0.0;
   for(int i = 2; i < count; ++i)
     {
      const double y = residuals[i] - residuals[i - 1];
      const double x1 = residuals[i - 1];
      const double x2 = residuals[i - 1] - residuals[i - 2];
      const double error = y - (intercept + gamma * x1 + lag_delta * x2);
      sse += error * error;
     }

   const double variance = sse / (n - 3.0);
   const double gamma_variance = variance * inv11;
   if(gamma_variance <= 0.0 || !MathIsValidNumber(gamma_variance))
      return false;

   t_stat = gamma / MathSqrt(gamma_variance);
   return MathIsValidNumber(t_stat);
  }

bool Strategy_OuHalfLife(const double &residuals[], const int count, const double mean, double &halflife)
  {
   halflife = 0.0;
   if(count < 30)
      return false;

   double sxx = 0.0;
   double sxy = 0.0;
   for(int i = 1; i < count; ++i)
     {
      const double x = residuals[i - 1] - mean;
      const double y = residuals[i] - residuals[i - 1];
      sxx += x * x;
      sxy += x * y;
     }

   if(sxx <= 0.0)
      return false;
   const double theta = sxy / sxx;
   if(theta >= 0.0 || !MathIsValidNumber(theta))
      return false;

   halflife = -MathLog(2.0) / theta;
   return (halflife > 0.0 && MathIsValidNumber(halflife));
  }

bool Strategy_FitModel(const int fit_year)
  {
   double leg1[];
   double leg2[];
   if(!Strategy_CopyTrainingCloses(leg1, leg2))
      return false;

   double sxx = 0.0;
   double sxy = 0.0;
   for(int series_index = training_lookback; series_index >= 1; --series_index)
     {
      const double x = leg2[series_index];
      const double y = leg1[series_index];
      sxx += x * x;
      sxy += x * y;
     }
   if(sxx <= 0.0)
      return false;

   const double beta = sxy / sxx;
   if(beta <= 0.0 || beta > 20.0 || !MathIsValidNumber(beta))
      return false;

   double residuals[];
   ArrayResize(residuals, training_lookback);
   double spread_sum = 0.0;
   int output_index = 0;
   for(int series_index = training_lookback; series_index >= 1; --series_index)
     {
      const double residual = leg1[series_index] - beta * leg2[series_index];
      residuals[output_index++] = residual;
      spread_sum += residual;
     }

   const double mean = spread_sum / (double)training_lookback;
   double variance_sum = 0.0;
   for(int i = 0; i < training_lookback; ++i)
     {
      const double delta = residuals[i] - mean;
      variance_sum += delta * delta;
     }
   const double stdev = MathSqrt(variance_sum / (double)MathMax(1, training_lookback - 1));
   if(stdev <= 0.0 || !MathIsValidNumber(stdev))
      return false;

   double adf_t = 0.0;
   double halflife = 0.0;
   if(!Strategy_AdfOneLagTStat(residuals, training_lookback, adf_t))
      return false;
   if(!Strategy_OuHalfLife(residuals, training_lookback, mean, halflife))
      return false;

   g_hedge_ratio = beta;
   g_spread_mean = mean;
   g_spread_stdev = stdev;
   g_adf_t_stat = adf_t;
   g_halflife_days = halflife;
   g_fit_year = fit_year;
   g_model_ready = true;

   const double critical = Strategy_CadfCriticalValue(cointegration_significance);
   const bool cadf_pass = (!cadf_gate_enabled || adf_t <= critical);
   const bool halflife_pass = (halflife <= (double)deployment_halflife_cap_days);
   g_deployment_gate_pass = cadf_pass && halflife_pass;

   QM_LogEvent(g_deployment_gate_pass ? QM_INFO : QM_WARN,
               "PAIR_MODEL_FIT",
               StringFormat("{\"fit_year\":%d,\"beta\":%.8f,\"spread_mean\":%.8f,\"spread_stdev\":%.8f,\"adf_t\":%.6f,\"adf_critical\":%.6f,\"halflife_days\":%.3f,\"cadf_pass\":%s,\"halflife_pass\":%s}",
                            fit_year,
                            g_hedge_ratio,
                            g_spread_mean,
                            g_spread_stdev,
                            g_adf_t_stat,
                            critical,
                            g_halflife_days,
                            Strategy_BoolJson(cadf_pass),
                            Strategy_BoolJson(halflife_pass)));
   return true;
  }

bool Strategy_EnsureModel()
  {
   const datetime closed_bar_time = iTime(g_pair_symbols[0], PERIOD_D1, 1); // perf-allowed: annual walk-forward anchor, called only on the D1 new-bar path.
   if(closed_bar_time <= 0)
      return false;

   MqlDateTime closed_bar;
   TimeToStruct(closed_bar_time, closed_bar);
   if(g_model_ready && g_fit_year == closed_bar.year)
      return true;

   return Strategy_FitModel(closed_bar.year);
  }

bool Strategy_RefreshState()
  {
   if(!Strategy_EnsureModel())
      return false;

   double leg1[];
   double leg2[];
   ArraySetAsSeries(leg1, true);
   ArraySetAsSeries(leg2, true);
   if(CopyClose(g_pair_symbols[0], PERIOD_D1, 1, 1, leg1) != 1) // perf-allowed: one closed D1 price after the D1 new-bar gate.
      return false;
   if(CopyClose(g_pair_symbols[1], PERIOD_D1, 1, 1, leg2) != 1) // perf-allowed: one closed D1 price after the D1 new-bar gate.
      return false;
   if(leg1[0] <= 0.0 || leg2[0] <= 0.0)
      return false;

   const double spread = leg1[0] - g_hedge_ratio * leg2[0];
   g_z_now = (spread - g_spread_mean) / g_spread_stdev;
   return MathIsValidNumber(g_z_now);
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   const long magic = PositionGetInteger(POSITION_MAGIC);
   return (magic == (long)QM_Magic(qm_ea_id, slot));
  }

int Strategy_OpenPairLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         ++count;
     }
   return count;
  }

datetime Strategy_OldestPairOpenTime()
  {
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_NewsAllowsPair(const datetime broker_time)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(!QM_NewsAllowsTrade(g_pair_symbols[i], broker_time, qm_news_mode))
         return false;
   return true;
  }

bool Strategy_CalculatePairLots(double &leg1_lots, double &leg2_lots)
  {
   leg1_lots = 0.0;
   leg2_lots = 0.0;
   if(!g_model_ready || g_spread_stdev <= 0.0 || g_hedge_ratio <= 0.0)
      return false;

   // Card section 7 delegates fixed-risk sizing to a catastrophic 4-sigma spread
   // distance while explicitly forbidding a native stop. This distance sizes the
   // package only; order SL remains zero per the approved strategy.
   const double tail_sigma = MathMax(1.0, 4.0 - MathAbs(entry_z));
   const double spread_risk_distance = tail_sigma * g_spread_stdev;
   const double leg1_price_distance = spread_risk_distance * 0.5;
   const double leg2_price_distance = spread_risk_distance * 0.5 / g_hedge_ratio;
   const double point1 = SymbolInfoDouble(g_pair_symbols[0], SYMBOL_POINT);
   const double point2 = SymbolInfoDouble(g_pair_symbols[1], SYMBOL_POINT);
   if(point1 <= 0.0 || point2 <= 0.0 || leg1_price_distance <= 0.0 || leg2_price_distance <= 0.0)
      return false;

   const double full_risk_lots_1 = QM_LotsForRisk(g_pair_symbols[0], leg1_price_distance / point1);
   const double full_risk_lots_2 = QM_LotsForRisk(g_pair_symbols[1], leg2_price_distance / point2);
   if(full_risk_lots_1 <= 0.0 || full_risk_lots_2 <= 0.0)
      return false;

   const double denominator = (1.0 / full_risk_lots_1) + (g_hedge_ratio / full_risk_lots_2);
   if(denominator <= 0.0)
      return false;

   const double base_lots = 1.0 / denominator;
   leg1_lots = QM_TM_NormalizeVolume(g_pair_symbols[0], base_lots);
   leg2_lots = QM_TM_NormalizeVolume(g_pair_symbols[1], base_lots * g_hedge_ratio);
   return (leg1_lots > 0.0 && leg2_lots > 0.0);
  }

bool Strategy_OpenLeg(const int index, const bool buy_leg, const double lots, const string reason)
  {
   if(index < 0 || index >= STRATEGY_SYMBOL_COUNT || lots <= 0.0)
      return false;

   QM_BasketOrderRequest request;
   request.symbol = g_pair_symbols[index];
   request.type = buy_leg ? QM_BUY : QM_SELL;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.lots = lots;
   request.reason = reason;
   request.symbol_slot = g_pair_slots[index];
   request.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode, strategy_deviation_points, request, ticket);
  }

bool Strategy_OpenPair(const int spread_direction)
  {
   if(spread_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;

   double leg1_lots = 0.0;
   double leg2_lots = 0.0;
   if(!Strategy_CalculatePairLots(leg1_lots, leg2_lots))
      return false;

   const bool long_spread = (spread_direction > 0);
   const string reason = long_spread ? "SRC02_S01_LONG_SPREAD" : "SRC02_S01_SHORT_SPREAD";
   const bool leg2_ok = Strategy_OpenLeg(1, !long_spread, leg2_lots, reason);
   const bool leg1_ok = Strategy_OpenLeg(0, long_spread, leg1_lots, reason);
   const int legs_after_open = Strategy_OpenPairLegCount();

   QM_LogEvent((leg1_ok && leg2_ok) ? QM_INFO : QM_WARN,
               "PAIR_OPEN_RESULT",
               StringFormat("{\"spread_direction\":%d,\"leg1_ok\":%s,\"leg2_ok\":%s,\"leg1_lots\":%.4f,\"leg2_lots\":%.4f,\"legs\":%d,\"z\":%.6f}",
                            spread_direction,
                            Strategy_BoolJson(leg1_ok),
                            Strategy_BoolJson(leg2_ok),
                            leg1_lots,
                            leg2_lots,
                            legs_after_open,
                            g_z_now));

   if(leg1_ok && leg2_ok)
      return true;

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1 || _Symbol != g_pair_symbols[0])
      return true;
   if(qm_magic_slot_offset != STRATEGY_PRIMARY_SLOT)
      return true;
   if(training_lookback < 30 || entry_z <= 0.0 || exit_z < 0.0 || exit_z >= entry_z)
      return true;
   if(cointegration_significance <= 0.0 || cointegration_significance > 0.10)
      return true;
   if(deployment_halflife_cap_days <= 0 || time_stop_multiplier <= 0.0)
      return true;
   return !Strategy_EnsureBasketScope();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "SRC02_S01_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_model_ready || !g_deployment_gate_pass || Strategy_OpenPairLegCount() > 0)
      return false;

   int spread_direction = 0;
   if(g_z_now <= -entry_z)
      spread_direction = 1;
   else if(g_z_now >= entry_z)
      spread_direction = -1;
   else
      return false;

   QM_LogEvent(QM_INFO,
               "PAIR_ENTRY_SIGNAL",
               StringFormat("{\"spread_direction\":%d,\"z\":%.6f,\"entry_z\":%.6f,\"beta\":%.8f,\"adf_t\":%.6f,\"halflife_days\":%.3f}",
                            spread_direction,
                            g_z_now,
                            entry_z,
                            g_hedge_ratio,
                            g_adf_t_stat,
                            g_halflife_days));
   Strategy_OpenPair(spread_direction);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_OpenPairLegCount() == 1)
     {
      QM_LogEvent(QM_WARN, "PAIR_PARTIAL_ROLLBACK", "{\"reason\":\"single_leg_detected\"}");
      Strategy_ClosePair(QM_EXIT_STRATEGY);
     }
  }

bool Strategy_ExitSignal()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return false;
   if(open_legs != STRATEGY_SYMBOL_COUNT)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   if(g_model_ready && MathAbs(g_z_now) <= exit_z)
     {
      QM_LogEvent(QM_INFO,
                  "PAIR_EXIT_MEAN_REACH",
                  StringFormat("{\"z\":%.6f,\"exit_z\":%.6f}", g_z_now, exit_z));
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   const datetime oldest = Strategy_OldestPairOpenTime();
   const int max_hold_days = (int)MathMax(1.0, MathCeil(g_halflife_days * time_stop_multiplier));
   if(oldest > 0 && TimeCurrent() - oldest >= max_hold_days * 86400)
     {
      QM_LogEvent(QM_INFO,
                  "PAIR_EXIT_TIME_STOP",
                  StringFormat("{\"max_hold_days\":%d,\"halflife_days\":%.3f,\"multiplier\":%.3f}",
                               max_hold_days,
                               g_halflife_days,
                               time_stop_multiplier));
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
     }
   return false;
  }

int OnInit()
  {
   g_pair_symbols[0] = pair_symbol_1;
   g_pair_symbols[1] = pair_symbol_2;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   if(!Strategy_EnsureBasketScope())
      return INIT_FAILED;

   if(!QM_MagicRegistered(qm_ea_id, STRATEGY_PRIMARY_SLOT) ||
      !QM_MagicRegistered(qm_ea_id, STRATEGY_HEDGE_SLOT))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"card\":\"SRC02_S01\",\"pair\":\"%s/%s\",\"primary_slot\":%d,\"hedge_slot\":%d}",
                            QM_LoggerEscapeJson(g_pair_symbols[0]),
                            QM_LoggerEscapeJson(g_pair_symbols[1]),
                            STRATEGY_PRIMARY_SLOT,
                            STRATEGY_HEDGE_SLOT));
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
   if(!Strategy_NewsAllowsPair(TimeCurrent()))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;
   QM_EquityStreamOnNewBar();

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: deduplicates the closed-bar pair signal.
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return;
   g_last_signal_bar = signal_bar;

   if(!Strategy_RefreshState())
      return;

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
