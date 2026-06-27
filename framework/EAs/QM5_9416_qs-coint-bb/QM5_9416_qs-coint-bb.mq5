#property strict
#property version   "5.0"
#property description "QM5_9416 QuantStart Cointegrated Spread Bollinger Pair"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9416;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf        = PERIOD_D1;
input int    strategy_warmup_bars               = 252;
input int    strategy_ols_lookback_bars         = 252;
input int    strategy_spread_lookback_bars      = 15;
input double strategy_entry_z                   = 1.5;
input double strategy_exit_z                    = 0.5;
input double strategy_stop_z                    = 4.0;
input double strategy_cadf_t_threshold          = -2.0;
input double strategy_beta_min                  = 0.25;
input double strategy_beta_max                  = 4.00;
input int    strategy_sizing_pips               = 200;
input int    strategy_max_spread_points         = 80;
input int    strategy_deviation_points          = 20;

#define STRATEGY_PAIR_COUNT 2

string g_pair_y[STRATEGY_PAIR_COUNT] = {"SP500.DWX", "WS30.DWX"};
string g_pair_x[STRATEGY_PAIR_COUNT] = {"NDX.DWX", "NDX.DWX"};
int    g_pair_y_slot[STRATEGY_PAIR_COUNT] = {0, 2};
int    g_pair_x_slot[STRATEGY_PAIR_COUNT] = {1, 1};

int    g_active_pair = -1;
double g_pair_alpha[STRATEGY_PAIR_COUNT] = {0.0, 0.0};
double g_pair_beta[STRATEGY_PAIR_COUNT] = {1.0, 1.0};
double g_pair_cadf_t[STRATEGY_PAIR_COUNT] = {0.0, 0.0};
int    g_pair_model_month[STRATEGY_PAIR_COUNT] = {0, 0};
bool   g_pair_model_ready[STRATEGY_PAIR_COUNT] = {false, false};

double g_spread = 0.0;
double g_spread_mean = 0.0;
double g_spread_std = 0.0;
double g_signal_z = 0.0;
bool   g_state_ready = false;

int Strategy_MonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_PairIndexForSymbol(const string symbol)
  {
   if(symbol == "SP500.DWX")
      return 0;
   if(symbol == "WS30.DWX")
      return 1;
   return -1;
  }

bool Strategy_HostSymbolAllowed()
  {
   return (Strategy_PairIndexForSymbol(_Symbol) >= 0);
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

double Strategy_MidPrice(const string symbol)
  {
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
      return (bid + ask) * 0.5;
   if(bid > 0.0)
      return bid;
   if(ask > 0.0)
      return ask;
   return 0.0;
  }

bool Strategy_SpreadAllows(const string symbol)
  {
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return false;
   if(ask > bid && strategy_max_spread_points > 0)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > strategy_max_spread_points)
         return false;
     }
   return true;
  }

bool Strategy_LoadLogCloses(const string symbol, double &out[], const int bars)
  {
   if(bars <= 0)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, strategy_signal_tf, 1, bars, closes); // perf-allowed: D1 pair state is called only behind the framework QM_IsNewBar gate.
   if(copied != bars)
      return false;

   ArrayResize(out, bars);
   ArraySetAsSeries(out, true);
   for(int i = 0; i < bars; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      out[i] = MathLog(closes[i]);
     }
   return true;
  }

double Strategy_SpreadAt(const double &y[], const double &x[], const int index, const double alpha, const double beta)
  {
   return y[index] - (alpha + beta * x[index]);
  }

bool Strategy_OLS(const double &y[], const double &x[], const int count, double &alpha, double &beta)
  {
   if(count < 30)
      return false;

   double sum_y = 0.0;
   double sum_x = 0.0;
   for(int i = 0; i < count; ++i)
     {
      sum_y += y[i];
      sum_x += x[i];
     }

   const double mean_y = sum_y / (double)count;
   const double mean_x = sum_x / (double)count;
   double cov = 0.0;
   double var_x = 0.0;
   for(int j = 0; j < count; ++j)
     {
      const double dy = y[j] - mean_y;
      const double dx = x[j] - mean_x;
      cov += dy * dx;
      var_x += dx * dx;
     }

   if(var_x <= 0.0)
      return false;

   beta = cov / var_x;
   alpha = mean_y - beta * mean_x;
   if(!MathIsValidNumber(alpha) || !MathIsValidNumber(beta))
      return false;
   if(beta < strategy_beta_min || beta > strategy_beta_max)
      return false;
   return true;
  }

bool Strategy_CADFResidualGate(const double &y[], const double &x[], const int count, const double alpha, const double beta, double &t_stat)
  {
   t_stat = 0.0;
   if(count < 32)
      return false;

   const int n = count - 1;
   double sum_lag = 0.0;
   double sum_delta = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double e_now = Strategy_SpreadAt(y, x, i, alpha, beta);
      const double e_lag = Strategy_SpreadAt(y, x, i + 1, alpha, beta);
      sum_lag += e_lag;
      sum_delta += (e_now - e_lag);
     }

   const double mean_lag = sum_lag / (double)n;
   const double mean_delta = sum_delta / (double)n;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int j = 0; j < n; ++j)
     {
      const double e_now = Strategy_SpreadAt(y, x, j, alpha, beta);
      const double e_lag = Strategy_SpreadAt(y, x, j + 1, alpha, beta);
      const double lag_dev = e_lag - mean_lag;
      const double delta_dev = (e_now - e_lag) - mean_delta;
      sxx += lag_dev * lag_dev;
      sxy += lag_dev * delta_dev;
     }

   if(sxx <= 0.0)
      return false;

   const double phi = sxy / sxx;
   const double intercept = mean_delta - phi * mean_lag;
   double sse = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const double e_now = Strategy_SpreadAt(y, x, k, alpha, beta);
      const double e_lag = Strategy_SpreadAt(y, x, k + 1, alpha, beta);
      const double fitted = intercept + phi * e_lag;
      const double err = (e_now - e_lag) - fitted;
      sse += err * err;
     }

   if(n <= 2)
      return false;
   const double sigma2 = sse / (double)(n - 2);
   if(sigma2 <= 0.0)
      return false;

   const double se_phi = MathSqrt(sigma2 / sxx);
   if(se_phi <= 0.0)
      return false;

   t_stat = phi / se_phi;
   if(!MathIsValidNumber(t_stat))
      return false;
   return (phi < 0.0 && t_stat <= strategy_cadf_t_threshold);
  }

bool Strategy_RefreshMonthlyModel(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const int month_key = Strategy_MonthKey();
   if(g_pair_model_ready[pair_index] && g_pair_model_month[pair_index] == month_key)
      return true;

   const int bars = MathMax(strategy_warmup_bars, strategy_ols_lookback_bars);
   if(bars < 32)
      return false;

   double y[];
   double x[];
   if(!Strategy_LoadLogCloses(g_pair_y[pair_index], y, bars) ||
      !Strategy_LoadLogCloses(g_pair_x[pair_index], x, bars))
      return false;

   double alpha = 0.0;
   double beta = 1.0;
   if(!Strategy_OLS(y, x, strategy_ols_lookback_bars, alpha, beta))
      return false;

   double cadf_t = 0.0;
   if(!Strategy_CADFResidualGate(y, x, strategy_ols_lookback_bars, alpha, beta, cadf_t))
      return false;

   g_pair_alpha[pair_index] = alpha;
   g_pair_beta[pair_index] = beta;
   g_pair_cadf_t[pair_index] = cadf_t;
   g_pair_model_month[pair_index] = month_key;
   g_pair_model_ready[pair_index] = true;
   return true;
  }

bool Strategy_RefreshSpreadState(const int pair_index)
  {
   g_state_ready = false;
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   if(strategy_spread_lookback_bars < 5)
      return false;
   if(!Strategy_RefreshMonthlyModel(pair_index))
      return false;

   const int bars = strategy_spread_lookback_bars;
   double y[];
   double x[];
   if(!Strategy_LoadLogCloses(g_pair_y[pair_index], y, bars) ||
      !Strategy_LoadLogCloses(g_pair_x[pair_index], x, bars))
      return false;

   const double alpha = g_pair_alpha[pair_index];
   const double beta = g_pair_beta[pair_index];
   double sum = 0.0;
   for(int i = 0; i < bars; ++i)
      sum += Strategy_SpreadAt(y, x, i, alpha, beta);

   const double mean = sum / (double)bars;
   double var = 0.0;
   for(int j = 0; j < bars; ++j)
     {
      const double d = Strategy_SpreadAt(y, x, j, alpha, beta) - mean;
      var += d * d;
     }

   const double std = MathSqrt(var / (double)MathMax(bars - 1, 1));
   if(std <= 0.0 || !MathIsValidNumber(std))
      return false;

   g_spread = Strategy_SpreadAt(y, x, 0, alpha, beta);
   g_spread_mean = mean;
   g_spread_std = std;
   g_signal_z = (g_spread - g_spread_mean) / g_spread_std;
   g_state_ready = MathIsValidNumber(g_signal_z);
   return g_state_ready;
  }

bool Strategy_HasPositionForSymbolSlot(const string symbol, const int slot)
  {
   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_PairHasYLeg(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   return Strategy_HasPositionForSymbolSlot(g_pair_y[pair_index], g_pair_y_slot[pair_index]);
  }

bool Strategy_PairHasAnyLeg(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   return Strategy_HasPositionForSymbolSlot(g_pair_y[pair_index], g_pair_y_slot[pair_index]) ||
          Strategy_HasPositionForSymbolSlot(g_pair_x[pair_index], g_pair_x_slot[pair_index]);
  }

int Strategy_CurrentPairDirection(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return 0;

   const int magic = QM_MagicChecked(qm_ea_id, g_pair_y_slot[pair_index], g_pair_y[pair_index]);
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pair_y[pair_index])
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return (type == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

bool Strategy_ClosePositionForSymbolSlot(const string symbol, const int slot, const QM_ExitReason reason)
  {
   bool closed_any = false;
   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         closed_any = true;
     }
   return closed_any;
  }

bool Strategy_ClosePairPositions(const int pair_index, const QM_ExitReason reason)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   bool closed_any = false;
   if(Strategy_ClosePositionForSymbolSlot(g_pair_y[pair_index], g_pair_y_slot[pair_index], reason))
      closed_any = true;
   if(Strategy_ClosePositionForSymbolSlot(g_pair_x[pair_index], g_pair_x_slot[pair_index], reason))
      closed_any = true;
   return closed_any;
  }

double Strategy_SizingLots(const string symbol, const double leg_scale)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double price_distance = QM_StopRulesPipsToPriceDistance(symbol, strategy_sizing_pips);
   if(point <= 0.0 || price_distance <= 0.0 || leg_scale <= 0.0)
      return 0.0;

   const double sl_points = price_distance / point;
   const double lots = QM_LotsForRisk(symbol, sl_points) * leg_scale * 0.5;
   return QM_TM_NormalizeVolume(symbol, lots);
  }

bool Strategy_OpenPair(const int pair_index, const int direction)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || direction == 0)
      return false;
   if(Strategy_PairHasAnyLeg(pair_index))
      return false;

   const string y_symbol = g_pair_y[pair_index];
   const string x_symbol = g_pair_x[pair_index];
   const double y_lots = Strategy_SizingLots(y_symbol, 1.0);
   const double x_lots = Strategy_SizingLots(x_symbol, MathAbs(g_pair_beta[pair_index]));
   if(y_lots <= 0.0 || x_lots <= 0.0)
      return false;

   QM_BasketOrderRequest y_req;
   y_req.symbol = y_symbol;
   y_req.type = (direction > 0) ? QM_BUY : QM_SELL;
   y_req.price = 0.0;
   y_req.sl = 0.0;
   y_req.tp = 0.0;
   y_req.lots = y_lots;
   y_req.reason = (direction > 0) ? "QS_COINT_LONG_Y" : "QS_COINT_SHORT_Y";
   y_req.symbol_slot = g_pair_y_slot[pair_index];
   y_req.expiration_seconds = 0;

   QM_BasketOrderRequest x_req;
   x_req.symbol = x_symbol;
   x_req.type = (direction > 0) ? QM_SELL : QM_BUY;
   x_req.price = 0.0;
   x_req.sl = 0.0;
   x_req.tp = 0.0;
   x_req.lots = x_lots;
   x_req.reason = (direction > 0) ? "QS_COINT_SHORT_X" : "QS_COINT_LONG_X";
   x_req.symbol_slot = g_pair_x_slot[pair_index];
   x_req.expiration_seconds = 0;

   ulong y_ticket = 0;
   ulong x_ticket = 0;
   const bool opened_y = QM_BasketOpenPosition(qm_ea_id, QM_NEWS_OFF, strategy_deviation_points, y_req, y_ticket);
   const bool opened_x = opened_y ? QM_BasketOpenPosition(qm_ea_id, QM_NEWS_OFF, strategy_deviation_points, x_req, x_ticket) : false;
   if(opened_y && !opened_x)
      Strategy_ClosePositionForSymbolSlot(y_symbol, g_pair_y_slot[pair_index], QM_EXIT_STRATEGY);
   return (opened_y && opened_x);
  }

bool Strategy_PairNewsBlocked(const datetime broker_time)
  {
   if(g_active_pair < 0 || g_active_pair >= STRATEGY_PAIR_COUNT)
      return true;

   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_pair_y[g_active_pair], broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_pair_x[g_active_pair], broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_pair_y[g_active_pair], broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_pair_x[g_active_pair], broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_HostSymbolAllowed())
      return true;
   if(g_active_pair < 0)
      return true;
   if(!Strategy_SpreadAllows(g_pair_y[g_active_pair]))
      return true;
   if(!Strategy_SpreadAllows(g_pair_x[g_active_pair]))
      return true;
   if(Strategy_MidPrice(g_pair_y[g_active_pair]) <= 0.0 ||
      Strategy_MidPrice(g_pair_x[g_active_pair]) <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QS_COINT_PAIR_HOST";
   req.symbol_slot = Strategy_SlotForSymbol(g_active_pair, _Symbol);
   req.expiration_seconds = 0;

   if(g_active_pair < 0 || req.symbol_slot < 0)
      return false;
   if(Strategy_PairHasAnyLeg(g_active_pair))
      return false;
   if(!Strategy_RefreshSpreadState(g_active_pair))
      return false;

   int direction = 0;
   if(g_signal_z < -strategy_entry_z)
      direction = 1;
   else if(g_signal_z > strategy_entry_z)
      direction = -1;

   if(direction == 0)
      return false;

   Strategy_OpenPair(g_active_pair, direction);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(g_active_pair < 0 || !Strategy_PairHasYLeg(g_active_pair))
      return false;

   if(!Strategy_RefreshSpreadState(g_active_pair))
     {
      Strategy_ClosePairPositions(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   const int direction = Strategy_CurrentPairDirection(g_active_pair);
   if(direction > 0 && g_signal_z >= -strategy_exit_z)
      Strategy_ClosePairPositions(g_active_pair, QM_EXIT_STRATEGY);
   else if(direction < 0 && g_signal_z <= strategy_exit_z)
      Strategy_ClosePairPositions(g_active_pair, QM_EXIT_STRATEGY);
   else if(MathAbs(g_signal_z) >= strategy_stop_z)
      Strategy_ClosePairPositions(g_active_pair, QM_EXIT_STRATEGY);

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!Strategy_HostSymbolAllowed())
      return true;
   return Strategy_PairNewsBlocked(broker_time);
  }

int OnInit()
  {
   g_active_pair = Strategy_PairIndexForSymbol(_Symbol);
   if(g_active_pair < 0)
      return INIT_FAILED;

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

   string symbols[3];
   symbols[0] = "SP500.DWX";
   symbols[1] = "NDX.DWX";
   symbols[2] = "WS30.DWX";
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, strategy_signal_tf, MathMax(strategy_warmup_bars, strategy_ols_lookback_bars) + 5);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9416\",\"strategy\":\"qs_coint_bb\"}");
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

   if(QM_FrameworkFridayCloseNow())
     {
      if(Strategy_PairHasYLeg(g_active_pair))
         Strategy_ClosePairPositions(g_active_pair, QM_EXIT_FRIDAY_CLOSE);
      return;
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

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
