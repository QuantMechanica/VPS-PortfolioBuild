#property strict
#property version   "5.0"
#property description "QM5_10331 Treasury Pairs"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10331;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_hedge_days          = 20;
input int    strategy_corr_days           = 60;
input int    strategy_bars_per_day        = 96;
input double strategy_entry_z             = 2.0;
input double strategy_exit_z              = 0.0;
input double strategy_stop_z              = 3.5;
input double strategy_min_corr            = 0.75;
input int    strategy_max_hold_bars       = 16;
input double strategy_loss_r_mult         = 1.25;
input double strategy_spread_percentile   = 80.0;
input int    strategy_deviation_points    = 20;
input double strategy_min_beta            = 0.05;
input double strategy_max_beta            = 20.0;

string   g_pair_a = "";
string   g_pair_b = "";
int      g_pair_a_slot = -1;
int      g_pair_b_slot = -1;
double   g_beta = 1.0;
double   g_spread_mean = 0.0;
double   g_spread_sd = 0.0;
double   g_current_z = 0.0;
bool     g_state_ready = false;
datetime g_entry_time = 0;
int      g_entry_direction = 0; // +1 long spread, -1 short spread.

int SymbolSlot(const string symbol)
  {
   if(symbol == "GDAXI.DWX")
      return 0;
   if(symbol == "UK100.DWX")
      return 1;
   if(symbol == "SP500.DWX")
      return 2;
   if(symbol == "NDX.DWX")
      return 3;
   if(symbol == "WS30.DWX")
      return 4;
   return -1;
  }

bool ResolvePairForHost(const string host, string &a, string &b)
  {
   if(host == "GDAXI.DWX" || host == "UK100.DWX")
     {
      a = "GDAXI.DWX";
      b = "UK100.DWX";
      return true;
     }

   if(host == "SP500.DWX" || host == "NDX.DWX")
     {
      a = "SP500.DWX";
      b = "NDX.DWX";
      return true;
     }

   if(host == "WS30.DWX")
     {
      a = "SP500.DWX";
      b = "WS30.DWX";
      return true;
     }

   a = "";
   b = "";
   return false;
  }

bool ResolvePair()
  {
   if(!ResolvePairForHost(_Symbol, g_pair_a, g_pair_b))
      return false;

   g_pair_a_slot = SymbolSlot(g_pair_a);
   g_pair_b_slot = SymbolSlot(g_pair_b);
   if(g_pair_a_slot < 0 || g_pair_b_slot < 0)
      return false;

   SymbolSelect(g_pair_a, true);
   SymbolSelect(g_pair_b, true);
   return true;
  }

bool ReadCloses(const string symbol, const int count, double &closes[])
  {
   if(count < 3)
      return false;
   ArrayResize(closes, count);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_M15, 1, count, closes); // perf-allowed: bounded pair close window, called only from framework QM_IsNewBar-gated EntrySignal.
   if(copied != count)
      return false;
   for(int i = 0; i < count; ++i)
     {
      if(closes[i] <= 0.0 || !MathIsValidNumber(closes[i]))
         return false;
     }
   return true;
  }

bool EstimateHedgeRatio(const double &a[], const double &b[], const int count, double &beta)
  {
   double mean_a = 0.0;
   double mean_b = 0.0;
   for(int i = 0; i < count; ++i)
     {
      mean_a += a[i];
      mean_b += b[i];
     }
   mean_a /= (double)count;
   mean_b /= (double)count;

   double cov = 0.0;
   double var_b = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double da = a[i] - mean_a;
      const double db = b[i] - mean_b;
      cov += da * db;
      var_b += db * db;
     }

   if(var_b <= 0.0)
      return false;
   beta = cov / var_b;
   return (MathIsValidNumber(beta) && MathAbs(beta) >= strategy_min_beta && MathAbs(beta) <= strategy_max_beta);
  }

bool SpreadStats(const double &a[], const double &b[], const int count, const double beta,
                 double &mean, double &sd, double &z)
  {
   double spreads[];
   ArrayResize(spreads, count);
   mean = 0.0;
   for(int i = 0; i < count; ++i)
     {
      spreads[i] = a[i] - beta * b[i];
      mean += spreads[i];
     }
   mean /= (double)count;

   double var = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double d = spreads[i] - mean;
      var += d * d;
     }
   sd = MathSqrt(var / (double)MathMax(1, count - 1));
   if(sd <= 0.0 || !MathIsValidNumber(sd))
      return false;

   z = (spreads[0] - mean) / sd;
   return MathIsValidNumber(z);
  }

bool CorrelationOk(const string a_symbol, const string b_symbol)
  {
   const int bars = MathMax(3, strategy_corr_days * strategy_bars_per_day + 1);
   double a[], b[];
   if(!ReadCloses(a_symbol, bars, a) || !ReadCloses(b_symbol, bars, b))
      return false;

   const int n = bars - 1;
   double mean_a = 0.0;
   double mean_b = 0.0;
   double ret_a[];
   double ret_b[];
   ArrayResize(ret_a, n);
   ArrayResize(ret_b, n);
   for(int i = 0; i < n; ++i)
     {
      ret_a[i] = MathLog(a[i] / a[i + 1]);
      ret_b[i] = MathLog(b[i] / b[i + 1]);
      mean_a += ret_a[i];
      mean_b += ret_b[i];
     }
   mean_a /= (double)n;
   mean_b /= (double)n;

   double cov = 0.0;
   double var_a = 0.0;
   double var_b = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double da = ret_a[i] - mean_a;
      const double db = ret_b[i] - mean_b;
      cov += da * db;
      var_a += da * da;
      var_b += db * db;
     }
   if(var_a <= 0.0 || var_b <= 0.0)
      return false;

   const double corr = cov / MathSqrt(var_a * var_b);
   return (MathIsValidNumber(corr) && corr >= strategy_min_corr);
  }

double PercentileNearestRank(const int &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   int sorted[];
   ArrayResize(sorted, count);
   for(int i = 0; i < count; ++i)
      sorted[i] = values[i];
   ArraySort(sorted);

   double pct = percentile;
   if(pct < 0.0)
      pct = 0.0;
   if(pct > 100.0)
      pct = 100.0;
   int idx = (int)MathCeil((pct / 100.0) * (double)count) - 1;
   idx = MathMax(0, MathMin(count - 1, idx));
   return (double)sorted[idx];
  }

bool SpreadCostFilterOk(const string symbol)
  {
   const int lookback = MathMax(20, strategy_hedge_days * strategy_bars_per_day);
   int spreads[];
   ArrayResize(spreads, lookback);
   ArraySetAsSeries(spreads, true);
   const int copied = CopySpread(symbol, PERIOD_M15, 1, lookback, spreads); // perf-allowed: bounded pair spread-cost percentile, called only from framework QM_IsNewBar-gated EntrySignal.
   if(copied != lookback)
      return false;

   long current_spread = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_SPREAD, current_spread))
      return false;
   if(current_spread < 0)
      return false;

   const double p80 = PercentileNearestRank(spreads, lookback, strategy_spread_percentile);
   return ((double)current_spread <= p80);
  }

bool RefreshPairState()
  {
   g_state_ready = false;
   if(!ResolvePair())
      return false;
   if(qm_magic_slot_offset != SymbolSlot(_Symbol))
      return false;

   const int hedge_bars = MathMax(30, strategy_hedge_days * strategy_bars_per_day);
   double a[], b[];
   if(!ReadCloses(g_pair_a, hedge_bars, a) || !ReadCloses(g_pair_b, hedge_bars, b))
      return false;

   if(!EstimateHedgeRatio(a, b, hedge_bars, g_beta))
      return false;
   if(!SpreadStats(a, b, hedge_bars, g_beta, g_spread_mean, g_spread_sd, g_current_z))
      return false;
   if(!CorrelationOk(g_pair_a, g_pair_b))
      return false;
   if(!SpreadCostFilterOk(g_pair_a) || !SpreadCostFilterOk(g_pair_b))
      return false;

   g_state_ready = true;
   return true;
  }

bool IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   if(symbol != g_pair_a && symbol != g_pair_b)
      return false;

   const int slot = SymbolSlot(symbol);
   if(slot < 0)
      return false;

   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_Magic(qm_ea_id, slot));
  }

bool HasPairPosition()
  {
   if(!ResolvePair())
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
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

double PairOpenPnL()
  {
   double pnl = 0.0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!IsPairPosition())
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

int PairDirectionFromPositions()
  {
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!IsPairPosition())
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pair_a)
         continue;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return g_entry_direction;
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

double PlannedRiskMoney()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED * PORTFOLIO_WEIGHT;
   return AccountInfoDouble(ACCOUNT_EQUITY) * (RISK_PERCENT / 100.0) * PORTFOLIO_WEIGHT;
  }

double NormalizedLots(const string symbol, const double lots)
  {
   if(lots <= 0.0)
      return 0.0;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   double normalized = MathFloor(lots / step) * step;
   if(normalized < min_lot)
      normalized = min_lot;
   if(normalized > max_lot)
      normalized = max_lot;
   return NormalizeDouble(normalized, 8);
  }

bool SendLeg(const string symbol, const int slot, const bool buy, const double weight,
             const double weight_sum, const double spread_stop_distance)
  {
   if(slot < 0 || weight_sum <= 0.0 || spread_stop_distance <= 0.0)
      return false;

   const int framework_magic = QM_FrameworkMagic();
   if(framework_magic <= 0)
      return false;

   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || digits < 0)
      return false;

   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double price = buy ? ask : bid;
   const double leg_stop_distance = (symbol == g_pair_b)
                                    ? spread_stop_distance / MathMax(MathAbs(g_beta), strategy_min_beta)
                                    : spread_stop_distance;
   const double sl_points = MathMax(1.0, leg_stop_distance / point);
   const double base_lots = QM_LotsForRisk(symbol, sl_points);
   const double lots = NormalizedLots(symbol, base_lots * MathAbs(weight) / weight_sum);
   if(lots <= 0.0)
      return false;

   const double sl = buy ? price - leg_stop_distance : price + leg_stop_distance;

   QM_BasketOrderRequest request;
   request.symbol = symbol;
   request.type = buy ? QM_BUY : QM_SELL;
   request.price = NormalizeDouble(price, digits);
   request.sl = NormalizeDouble(sl, digits);
   request.tp = 0.0;
   request.lots = lots;
   request.reason = "QM5_10331_PAIR";
   request.symbol_slot = slot;
   request.expiration_seconds = 0;

   ulong ticket = 0;
   const bool ok = QM_BasketOpenPosition(qm_ea_id,
                                         qm_news_mode_legacy,
                                         strategy_deviation_points,
                                         request,
                                         ticket);
   if(!ok)
     {
      QM_LogEvent(QM_WARN, "PAIR_LEG_OPEN_FAILED",
                  StringFormat("{\"symbol\":\"%s\",\"slot\":%d}",
                               QM_LoggerEscapeJson(symbol), slot));
      return false;
     }
   return true;
  }

bool OpenPair(const int direction)
  {
   if(direction == 0 || !g_state_ready)
      return false;

   const double distance_to_stop_z = MathMax(0.25, strategy_stop_z - MathAbs(g_current_z));
   const double spread_stop_distance = distance_to_stop_z * g_spread_sd;
   if(spread_stop_distance <= 0.0)
      return false;

   const double weight_a = 1.0;
   const double weight_b = MathAbs(g_beta);
   const double weight_sum = weight_a + weight_b;

   const bool buy_a = (direction > 0);
   const bool buy_b = (direction < 0);
   const bool a_ok = SendLeg(g_pair_a, g_pair_a_slot, buy_a, weight_a, weight_sum, spread_stop_distance);
   const bool b_ok = SendLeg(g_pair_b, g_pair_b_slot, buy_b, weight_b, weight_sum, spread_stop_distance);

   if(a_ok && b_ok)
     {
      g_entry_time = TimeCurrent();
      g_entry_direction = direction;
      QM_LogEvent(QM_INFO, "PAIR_OPENED",
                  StringFormat("{\"pair\":\"%s/%s\",\"direction\":%d,\"z\":%.4f,\"beta\":%.6f}",
                               QM_LoggerEscapeJson(g_pair_a), QM_LoggerEscapeJson(g_pair_b),
                               direction, g_current_z, g_beta));
      return true;
     }

   ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!ResolvePair())
      return true;
   if(qm_magic_slot_offset != SymbolSlot(_Symbol))
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10331_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!RefreshPairState())
      return false;
   if(HasPairPosition())
      return false;

   if(g_current_z >= strategy_entry_z)
      OpenPair(-1);
   else if(g_current_z <= -strategy_entry_z)
      OpenPair(1);

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!ResolvePair() || !HasPairPosition())
      return;

   const double planned_risk = PlannedRiskMoney();
   if(planned_risk > 0.0 && PairOpenPnL() <= -strategy_loss_r_mult * planned_risk)
      ClosePair(QM_EXIT_STRATEGY);
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!ResolvePair() || !HasPairPosition())
      return false;

   const int direction = PairDirectionFromPositions();
   if(g_state_ready)
     {
      if((direction > 0 && g_current_z >= strategy_exit_z) ||
         (direction < 0 && g_current_z <= -strategy_exit_z))
        {
         ClosePair(QM_EXIT_STRATEGY);
         return false;
        }

      if((direction > 0 && g_current_z <= -strategy_stop_z) ||
         (direction < 0 && g_current_z >= strategy_stop_z))
        {
         ClosePair(QM_EXIT_STRATEGY);
         return false;
        }
     }

   const datetime oldest = OldestPairOpenTime();
   const int max_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_M15);
   if(oldest > 0 && max_seconds > 0 && TimeCurrent() - oldest >= max_seconds)
     {
      ClosePair(QM_EXIT_TIME_STOP);
      return false;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!ResolvePair())
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

   ResolvePair();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10331\",\"strategy\":\"treasury-pairs\"}");
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
