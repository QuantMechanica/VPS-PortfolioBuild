#property strict
#property version   "5.0"
#property description "QM5_1231 Carver PCA Alpha Persistence"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1231;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.0909;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_d1         = 252;
input int    strategy_num_pc              = 3;
input int    strategy_norm_stddev_days    = 25;
input double strategy_entry_forecast      = 5.0;
input int    strategy_max_longs           = 2;
input int    strategy_max_shorts          = 2;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 2.5;
input int    strategy_spread_median_days  = 20;
input double strategy_spread_mult         = 2.0;

#define QM5_1231_SYMBOL_COUNT 11
#define QM5_1231_MAX_LOOKBACK 300
#define QM5_1231_MAX_PC       3

string g_symbols[QM5_1231_SYMBOL_COUNT] =
  {
   "GER40.DWX", "NDX.DWX", "WS30.DWX", "UK100.DWX", "FRA40.DWX",
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "USDJPY.DWX", "USDCHF.DWX", "USDCAD.DWX"
  };

int g_last_entry_month = 0;
int g_last_exit_month  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1231_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_MonthKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthlyRebalance()
  {
   const datetime last_closed = iTime(_Symbol, PERIOD_D1, 1);
   const datetime prior = iTime(_Symbol, PERIOD_D1, 2);
   if(last_closed <= 0 || prior <= 0)
      return false;
   return (Strategy_MonthKey(last_closed) != Strategy_MonthKey(prior));
  }

bool Strategy_SelectSymbols()
  {
   bool ok = true;
   for(int i = 0; i < QM5_1231_SYMBOL_COUNT; ++i)
      ok = (SymbolSelect(g_symbols[i], true) && ok);
   return ok;
  }

bool Strategy_HasOpenPosition(ulong &ticket, int &direction)
  {
   ticket = 0;
   direction = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = pos_ticket;
      direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }
   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

double Strategy_StdDevReturns(const string symbol, const int shift, const int period)
  {
   if(period <= 1 || period > 128)
      return 0.0;
   double values[128];
   int count = 0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double c0 = iClose(symbol, PERIOD_D1, i);
      const double c1 = iClose(symbol, PERIOD_D1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      values[count] = (c0 - c1) / c1;
      ++count;
     }
   double mean = 0.0;
   for(int i = 0; i < count; ++i)
      mean += values[i];
   mean /= (double)count;
   double var = 0.0;
   for(int i = 0; i < count; ++i)
      var += (values[i] - mean) * (values[i] - mean);
   var /= (double)MathMax(count - 1, 1);
   return MathSqrt(var);
  }

double Strategy_NormalizedReturn(const string symbol, const int shift)
  {
   const double c0 = iClose(symbol, PERIOD_D1, shift);
   const double c1 = iClose(symbol, PERIOD_D1, shift + 1);
   const double sd = Strategy_StdDevReturns(symbol, shift, strategy_norm_stddev_days);
   if(c0 <= 0.0 || c1 <= 0.0 || sd <= 0.0)
      return 0.0;
   const double raw = ((c0 - c1) / c1) / sd;
   return MathMax(-6.0, MathMin(6.0, raw));
  }

void Strategy_NormalizeSeries(double &raw[][QM5_1231_MAX_LOOKBACK],
                              double &z[][QM5_1231_MAX_LOOKBACK],
                              const int symbol_count,
                              const int lookback)
  {
   for(int s = 0; s < symbol_count; ++s)
     {
      double mean = 0.0;
      for(int t = 0; t < lookback; ++t)
         mean += raw[s][t];
      mean /= (double)lookback;

      double var = 0.0;
      for(int t = 0; t < lookback; ++t)
         var += (raw[s][t] - mean) * (raw[s][t] - mean);
      var /= (double)MathMax(lookback - 1, 1);
      const double sd = MathSqrt(var);

      for(int t = 0; t < lookback; ++t)
         z[s][t] = (sd > 0.0) ? ((raw[s][t] - mean) / sd) : 0.0;
     }
  }

void Strategy_BuildCovariance(double &z[][QM5_1231_MAX_LOOKBACK],
                              double &cov[][QM5_1231_SYMBOL_COUNT],
                              const int symbol_count,
                              const int lookback)
  {
   for(int i = 0; i < symbol_count; ++i)
     {
      for(int j = 0; j < symbol_count; ++j)
        {
         double sum = 0.0;
         for(int t = 0; t < lookback; ++t)
            sum += z[i][t] * z[j][t];
         cov[i][j] = sum / (double)MathMax(lookback - 1, 1);
        }
     }
  }

double Strategy_VectorNorm(double &values[], const int count)
  {
   double sum = 0.0;
   for(int i = 0; i < count; ++i)
      sum += values[i] * values[i];
   return MathSqrt(sum);
  }

void Strategy_PowerIteration(double &cov[][QM5_1231_SYMBOL_COUNT],
                             double &weights[],
                             double &eigen_value,
                             const int symbol_count)
  {
   for(int i = 0; i < symbol_count; ++i)
      weights[i] = 1.0 / MathSqrt((double)symbol_count);

   double next[QM5_1231_SYMBOL_COUNT];
   for(int iter = 0; iter < 30; ++iter)
     {
      for(int i = 0; i < symbol_count; ++i)
        {
         next[i] = 0.0;
         for(int j = 0; j < symbol_count; ++j)
            next[i] += cov[i][j] * weights[j];
        }
      const double norm = Strategy_VectorNorm(next, symbol_count);
      if(norm <= 0.0)
         break;
      for(int i = 0; i < symbol_count; ++i)
         weights[i] = next[i] / norm;
     }

   eigen_value = 0.0;
   for(int i = 0; i < symbol_count; ++i)
     {
      double row = 0.0;
      for(int j = 0; j < symbol_count; ++j)
         row += cov[i][j] * weights[j];
      eigen_value += weights[i] * row;
     }
   if(eigen_value < 0.0)
      eigen_value = 0.0;
  }

void Strategy_Deflate(double &cov[][QM5_1231_SYMBOL_COUNT],
                      double &weights[],
                      const double eigen_value,
                      const int symbol_count)
  {
   if(eigen_value <= 0.0)
      return;
   for(int i = 0; i < symbol_count; ++i)
      for(int j = 0; j < symbol_count; ++j)
         cov[i][j] -= eigen_value * weights[i] * weights[j];
  }

bool Strategy_Forecasts(double &forecasts[])
  {
   const int lookback = MathMax(60, MathMin(strategy_lookback_d1, QM5_1231_MAX_LOOKBACK));
   const int pc_count = MathMax(1, MathMin(strategy_num_pc, QM5_1231_MAX_PC));
   if(QM5_1231_SYMBOL_COUNT < 8)
      return false;

   for(int s = 0; s < QM5_1231_SYMBOL_COUNT; ++s)
      if(Bars(g_symbols[s], PERIOD_D1) < lookback + strategy_norm_stddev_days + strategy_atr_period_d1 + 10)
         return false;

   double raw[QM5_1231_SYMBOL_COUNT][QM5_1231_MAX_LOOKBACK];
   double z[QM5_1231_SYMBOL_COUNT][QM5_1231_MAX_LOOKBACK];
   for(int s = 0; s < QM5_1231_SYMBOL_COUNT; ++s)
      for(int t = 0; t < lookback; ++t)
         raw[s][t] = Strategy_NormalizedReturn(g_symbols[s], t + 1);

   Strategy_NormalizeSeries(raw, z, QM5_1231_SYMBOL_COUNT, lookback);

   double cov[QM5_1231_SYMBOL_COUNT][QM5_1231_SYMBOL_COUNT];
   Strategy_BuildCovariance(z, cov, QM5_1231_SYMBOL_COUNT, lookback);

   double vectors[QM5_1231_MAX_PC][QM5_1231_SYMBOL_COUNT];
   double eigen = 0.0;
   for(int pc = 0; pc < pc_count; ++pc)
     {
      double vec[QM5_1231_SYMBOL_COUNT];
      Strategy_PowerIteration(cov, vec, eigen, QM5_1231_SYMBOL_COUNT);
      for(int s = 0; s < QM5_1231_SYMBOL_COUNT; ++s)
         vectors[pc][s] = vec[s];
      Strategy_Deflate(cov, vec, eigen, QM5_1231_SYMBOL_COUNT);
     }

   double pc_values[QM5_1231_MAX_PC][QM5_1231_MAX_LOOKBACK];
   for(int pc = 0; pc < pc_count; ++pc)
     {
      for(int t = 0; t < lookback; ++t)
        {
         pc_values[pc][t] = 0.0;
         for(int s = 0; s < QM5_1231_SYMBOL_COUNT; ++s)
            pc_values[pc][t] += vectors[pc][s] * z[s][t];
        }
     }

   double alpha[QM5_1231_SYMBOL_COUNT];
   for(int s = 0; s < QM5_1231_SYMBOL_COUNT; ++s)
     {
      double mean_y = 0.0;
      for(int t = 0; t < lookback; ++t)
         mean_y += raw[s][t];
      mean_y /= (double)lookback;

      double fitted_mean = 0.0;
      for(int pc = 0; pc < pc_count; ++pc)
        {
         double mean_x = 0.0;
         for(int t = 0; t < lookback; ++t)
            mean_x += pc_values[pc][t];
         mean_x /= (double)lookback;

         double cov_xy = 0.0;
         double var_x = 0.0;
         for(int t = 0; t < lookback; ++t)
           {
            cov_xy += (raw[s][t] - mean_y) * (pc_values[pc][t] - mean_x);
            var_x += (pc_values[pc][t] - mean_x) * (pc_values[pc][t] - mean_x);
           }
         const double beta = (var_x > 0.0) ? (cov_xy / var_x) : 0.0;
         fitted_mean += beta * mean_x;
        }
      alpha[s] = mean_y - fitted_mean;
     }

   double sorted_alpha[QM5_1231_SYMBOL_COUNT];
   for(int s = 0; s < QM5_1231_SYMBOL_COUNT; ++s)
      sorted_alpha[s] = alpha[s];
   Strategy_Median(sorted_alpha, QM5_1231_SYMBOL_COUNT);
   const int lo_idx = (int)MathFloor(0.10 * (double)(QM5_1231_SYMBOL_COUNT - 1));
   const int hi_idx = (int)MathCeil(0.90 * (double)(QM5_1231_SYMBOL_COUNT - 1));
   const double lo = sorted_alpha[lo_idx];
   const double hi = sorted_alpha[hi_idx];

   double abs_alpha[QM5_1231_SYMBOL_COUNT];
   for(int s = 0; s < QM5_1231_SYMBOL_COUNT; ++s)
     {
      alpha[s] = MathMax(lo, MathMin(hi, alpha[s]));
      abs_alpha[s] = MathAbs(alpha[s]);
     }
   const double med_abs = Strategy_Median(abs_alpha, QM5_1231_SYMBOL_COUNT);
   if(med_abs <= 0.0)
      return false;

   for(int s = 0; s < QM5_1231_SYMBOL_COUNT; ++s)
      forecasts[s] = MathMax(-20.0, MathMin(20.0, 20.0 * alpha[s] / med_abs));
   return true;
  }

bool Strategy_IsAllowedRank(const int own, double &forecasts[], const int direction)
  {
   if(own < 0)
      return false;
   int rank = 1;
   for(int i = 0; i < QM5_1231_SYMBOL_COUNT; ++i)
     {
      if(i == own)
         continue;
      if(direction > 0 && forecasts[i] > forecasts[own])
         ++rank;
      if(direction < 0 && forecasts[i] < forecasts[own])
         ++rank;
     }
   if(direction > 0)
      return (rank <= MathMax(1, strategy_max_longs));
   return (rank <= MathMax(1, strategy_max_shorts));
  }

int Strategy_CurrentForecast(double &forecast)
  {
   forecast = 0.0;
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return 0;

   double forecasts[QM5_1231_SYMBOL_COUNT];
   if(!Strategy_Forecasts(forecasts))
      return 0;

   forecast = forecasts[idx];
   if(forecast > strategy_entry_forecast && Strategy_IsAllowedRank(idx, forecasts, 1))
      return 1;
   if(forecast < -strategy_entry_forecast && Strategy_IsAllowedRank(idx, forecasts, -1))
      return -1;
   return 0;
  }

double Strategy_MedianDailySpreadPoints()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_median_days > 64)
      return 0.0;
   double values[64];
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_median_days; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
     }
   if(count <= 0)
      return 0.0;
   return Strategy_Median(values, count);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_StopDistanceAllowed(const ENUM_ORDER_TYPE type, const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0 || stops <= 0)
      return true;
   const double min_dist = (double)stops * point;
   if(type == ORDER_TYPE_BUY)
      return (entry - sl >= min_dist);
   return (sl - entry >= min_dist);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 1231)
      return true;
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   if(qm_magic_slot_offset != index)
      return true;
   if(strategy_lookback_d1 < 60 || strategy_lookback_d1 > QM5_1231_MAX_LOOKBACK)
      return true;
   if(strategy_num_pc < 1 || strategy_num_pc > QM5_1231_MAX_PC)
      return true;
   if(strategy_norm_stddev_days < 5 || strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1231_CARVER_PCA_ALPHA";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalance())
      return false;

   const int month_key = Strategy_MonthKey(iTime(_Symbol, PERIOD_D1, 1));
   if(month_key <= 0 || month_key == g_last_entry_month)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   ulong ticket = 0;
   int open_direction = 0;
   if(Strategy_HasOpenPosition(ticket, open_direction))
      return false;

   double forecast = 0.0;
   const int direction = Strategy_CurrentForecast(forecast);
   if(direction == 0)
      return false;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = entry;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   req.symbol_slot = qm_magic_slot_offset;
   if(!Strategy_StopDistanceAllowed((direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), entry, req.sl))
      return false;

   g_last_entry_month = month_key;
   QM_LogEvent(QM_INFO, "CARVER_PCA_ALPHA_SIGNAL_ON",
               StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"forecast\":%.4f,\"direction\":%d}",
                            _Symbol, req.symbol_slot, forecast, direction));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthlyRebalance())
      return false;

   ulong ticket = 0;
   int open_direction = 0;
   if(!Strategy_HasOpenPosition(ticket, open_direction))
      return false;

   const int month_key = Strategy_MonthKey(iTime(_Symbol, PERIOD_D1, 1));
   if(month_key <= 0 || month_key == g_last_exit_month)
      return false;

   double forecast = 0.0;
   Strategy_CurrentForecast(forecast);
   if((open_direction > 0 && forecast <= 0.0) || (open_direction < 0 && forecast >= 0.0))
     {
      g_last_exit_month = month_key;
      return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_SelectSymbols();

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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_lookback_d1 + strategy_norm_stddev_days + strategy_atr_period_d1 + 20);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1231\",\"strategy\":\"carver-pca-alpha\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
