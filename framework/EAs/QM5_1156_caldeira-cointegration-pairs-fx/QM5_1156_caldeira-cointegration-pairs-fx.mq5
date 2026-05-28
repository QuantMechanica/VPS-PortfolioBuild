#property strict
#property version   "5.0"
#property description "QM5_1156 Caldeira Cointegration Pairs FX"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1156;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pair_slot           = 0;
input int    strategy_formation_days      = 60;
input int    strategy_zscore_days         = 60;
input double strategy_entry_z             = 2.0;
input double strategy_exit_abs_z          = 0.5;
input double strategy_stop_abs_z          = 4.0;
input double strategy_coint_entry_p       = 0.05;
input double strategy_coint_exit_p        = 0.10;
input int    strategy_max_hold_days       = 30;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 3.0;
input int    strategy_max_active_pairs    = 4;
input int    strategy_deviation_points    = 20;

string   g_symbols[6] = {"EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "USDCHF.DWX", "AUDUSD.DWX", "NZDUSD.DWX"};
string   g_pair_a = "";
string   g_pair_b = "";
double   g_alpha = 0.0;
double   g_beta = 1.0;
double   g_residual_mean = 0.0;
double   g_residual_sd = 0.0;
double   g_current_z = 0.0;
double   g_current_adf_t = 0.0;
bool     g_state_ready = false;
int      g_estimate_week_key = -1;
datetime g_entry_bar_time = 0;

bool ResolvePair(const int slot, string &a, string &b)
  {
   int current = 0;
   for(int i = 0; i < 6; ++i)
     {
      for(int j = i + 1; j < 6; ++j)
        {
         if(current == slot)
           {
            a = g_symbols[i];
            b = g_symbols[j];
            return true;
           }
         ++current;
        }
     }
   return false;
  }

int WeekKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
  }

bool IsFriday(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week == 5);
  }

double AdfCriticalFromP(const double p_value)
  {
   if(p_value <= 0.01)
      return -3.43;
   if(p_value <= 0.05)
      return -2.86;
   if(p_value <= 0.10)
      return -2.57;
   return -2.32;
  }

bool ReadLogCloses(const string symbol, double &out[], const int bars)
  {
   if(bars < 30)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(symbol, PERIOD_D1, 1, bars, closes) != bars) // perf-allowed: D1 evaluation runs behind the framework new-bar gate.
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

bool EstimateOls(const double &x[], const double &y[], const int bars, double &alpha, double &beta)
  {
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      sx += x[i];
      sy += y[i];
      sxx += x[i] * x[i];
      sxy += x[i] * y[i];
     }

   const double n = (double)bars;
   const double denom = sxx - sx * sx / n;
   if(MathAbs(denom) < 1e-12)
      return false;

   beta = (sxy - sx * sy / n) / denom;
   alpha = sy / n - beta * sx / n;
   return (MathIsValidNumber(alpha) && MathIsValidNumber(beta) && MathAbs(beta) >= 0.01 && MathAbs(beta) <= 20.0);
  }

void BuildResiduals(const double &x[], const double &y[], const int bars, double &residuals[])
  {
   ArrayResize(residuals, bars);
   ArraySetAsSeries(residuals, true);
   for(int i = 0; i < bars; ++i)
      residuals[i] = y[i] - (g_alpha + g_beta * x[i]);
  }

bool ResidualStats(const double &residuals[], const int lookback, double &mean, double &sd)
  {
   if(lookback < 10)
      return false;

   mean = 0.0;
   for(int i = 1; i <= lookback; ++i)
      mean += residuals[i];
   mean /= (double)lookback;

   double var = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double d = residuals[i] - mean;
      var += d * d;
     }

   sd = MathSqrt(var / (double)MathMax(1, lookback - 1));
   return (sd > 0.0 && MathIsValidNumber(sd));
  }

bool AdfTStat(const double &residuals[], const int bars, double &t_stat)
  {
   if(bars < 30)
      return false;

   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   int n = 0;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double lagged = residuals[i + 1];
      const double delta = residuals[i] - residuals[i + 1];
      sx += lagged;
      sy += delta;
      sxx += lagged * lagged;
      sxy += lagged * delta;
      ++n;
     }

   const double dn = (double)n;
   const double denom = sxx - sx * sx / dn;
   if(MathAbs(denom) < 1e-12 || n <= 2)
      return false;

   const double slope = (sxy - sx * sy / dn) / denom;
   const double intercept = sy / dn - slope * sx / dn;
   double sse = 0.0;
   for(int i = bars - 2; i >= 0; --i)
     {
      const double lagged = residuals[i + 1];
      const double delta = residuals[i] - residuals[i + 1];
      const double err = delta - (intercept + slope * lagged);
      sse += err * err;
     }

   const double se = MathSqrt((sse / (double)(n - 2)) / denom);
   if(se <= 0.0)
      return false;

   t_stat = slope / se;
   return MathIsValidNumber(t_stat);
  }

bool RefreshState()
  {
   if(!ResolvePair(strategy_pair_slot, g_pair_a, g_pair_b))
     {
      g_state_ready = false;
      return false;
     }

   SymbolSelect(g_pair_a, true);
   SymbolSelect(g_pair_b, true);

   const int formation = MathMax(30, strategy_formation_days);
   const int z_bars = MathMax(10, strategy_zscore_days);
   const int required = MathMax(formation, z_bars + 2);
   if(Bars(g_pair_a, PERIOD_D1) < required + 5 || Bars(g_pair_b, PERIOD_D1) < required + 5)
     {
      g_state_ready = false;
      return false;
     }

   double logx[], logy[];
   if(!ReadLogCloses(g_pair_a, logx, required) || !ReadLogCloses(g_pair_b, logy, required))
     {
      g_state_ready = false;
      return false;
     }

   const datetime last_d1 = iTime(g_pair_a, PERIOD_D1, 1);
   const int week_key = WeekKey(last_d1);
   if(g_estimate_week_key < 0 || (week_key != g_estimate_week_key && IsFriday(last_d1)))
     {
      if(!EstimateOls(logx, logy, formation, g_alpha, g_beta))
        {
         g_state_ready = false;
         return false;
        }
      g_estimate_week_key = week_key;
     }

   double residuals[];
   BuildResiduals(logx, logy, required, residuals);
   if(!ResidualStats(residuals, z_bars, g_residual_mean, g_residual_sd))
     {
      g_state_ready = false;
      return false;
     }
   if(!AdfTStat(residuals, formation, g_current_adf_t))
     {
      g_state_ready = false;
      return false;
     }

   g_current_z = (residuals[0] - g_residual_mean) / g_residual_sd;
   g_state_ready = MathIsValidNumber(g_current_z);
   return g_state_ready;
  }

bool IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int magic = (int)PositionGetInteger(POSITION_MAGIC);
   return ((symbol == g_pair_a || symbol == g_pair_b) && magic == QM_Magic(qm_ea_id, strategy_pair_slot));
  }

bool HasPairPosition()
  {
   if(!ResolvePair(strategy_pair_slot, g_pair_a, g_pair_b))
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(IsPairPosition())
         return true;
     }
   return false;
  }

int ActivePairCount()
  {
   int slots_seen[15];
   ArrayInitialize(slots_seen, 0);

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      const int min_magic = qm_ea_id * 10000;
      const int max_magic = min_magic + 14;
      if(magic < min_magic || magic > max_magic)
         continue;
      slots_seen[magic - min_magic] = 1;
     }

   int count = 0;
   for(int slot = 0; slot < 15; ++slot)
      count += slots_seen[slot];
   return count;
  }

datetime OldestPairOpenTime()
  {
   datetime oldest = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!IsPairPosition())
         continue;
      const datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || t < oldest)
         oldest = t;
     }
   return oldest;
  }

int ClosePair(const QM_ExitReason reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!IsPairPosition())
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         ++closed;
     }
   return closed;
  }

double LotsForLeg(const string symbol, const double weight, const double weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_stop_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * MathAbs(weight) / weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   return MathMax(min_lot, MathMin(max_lot, lots));
  }

bool SendLeg(const string symbol, const bool buy, const double weight, const double weight_sum)
  {
   const int magic = QM_Magic(qm_ea_id, strategy_pair_slot);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
   const double lots = LotsForLeg(symbol, weight, weight_sum);
   if(atr <= 0.0 || lots <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double price = buy ? ask : bid;
   const double sl = buy ? price - strategy_atr_stop_mult * atr
                         : price + strategy_atr_stop_mult * atr;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lots;
   request.type = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = price;
   request.sl = NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   request.tp = 0.0;
   request.deviation = strategy_deviation_points;
   request.magic = magic;
   request.comment = "QM5_1156_PAIR";
   request.type_filling = ORDER_FILLING_IOC;

   const bool ok = OrderSend(request, result);
   if(!ok || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED))
     {
      QM_LogEvent(QM_WARN, "PAIR_LEG_OPEN_FAIL",
                  StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"retcode\":%u}", symbol, strategy_pair_slot, result.retcode));
      return false;
     }
   return true;
  }

bool OpenPair(const int direction)
  {
   const double weight_y = 1.0;
   const double weight_x = MathAbs(g_beta);
   const double weight_sum = weight_y + weight_x;
   if(weight_sum <= 0.0)
      return false;

   const bool buy_y = (direction < 0);
   const bool buy_x = (direction > 0);
   bool opened = false;
   if(SendLeg(g_pair_b, buy_y, weight_y, weight_sum))
      opened = true;
   if(SendLeg(g_pair_a, buy_x, weight_x, weight_sum))
      opened = true;

   if(opened)
      g_entry_bar_time = TimeCurrent();
   else
      ClosePair(QM_EXIT_STRATEGY);
   return opened;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M30)
      return true;
   if(!ResolvePair(strategy_pair_slot, g_pair_a, g_pair_b))
      return true;
   return (_Symbol != g_pair_a && _Symbol != g_pair_b);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "COINTEG_PAIR_HOST";
   req.symbol_slot = strategy_pair_slot;
   req.expiration_seconds = 0;

   if(!RefreshState() || HasPairPosition())
      return false;
   if(ActivePairCount() >= strategy_max_active_pairs)
      return false;
   if(g_current_adf_t > AdfCriticalFromP(strategy_coint_entry_p))
      return false;

   if(g_current_z >= strategy_entry_z)
      OpenPair(1);
   else if(g_current_z <= -strategy_entry_z)
      OpenPair(-1);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasPairPosition())
      return false;

   if(g_state_ready)
     {
      if(MathAbs(g_current_z) <= strategy_exit_abs_z)
        {
         ClosePair(QM_EXIT_STRATEGY);
         return false;
        }
      if(MathAbs(g_current_z) >= strategy_stop_abs_z)
        {
         ClosePair(QM_EXIT_STRATEGY);
         return false;
        }
      if(g_current_adf_t > AdfCriticalFromP(strategy_coint_exit_p))
        {
         ClosePair(QM_EXIT_STRATEGY);
         return false;
        }
     }

   const datetime oldest = OldestPairOpenTime();
   if(oldest > 0 && TimeCurrent() - oldest >= strategy_max_hold_days * 86400)
     {
      ClosePair(QM_EXIT_TIME_STOP);
      return false;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!ResolvePair(strategy_pair_slot, g_pair_a, g_pair_b))
      return true;

   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_pair_a, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_pair_b, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_pair_a, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_pair_b, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < 6; ++i)
      SymbolSelect(g_symbols[i], true);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1156\",\"strategy\":\"caldeira-cointegration-pairs-fx\"}");
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
   Strategy_ExitSignal();

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   RefreshState();

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
