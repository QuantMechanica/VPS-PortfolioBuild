#property strict
#property version   "5.0"
#property description "QM5_10309 Cointegrated HFT Pairs Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10309;
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
input int    strategy_formation_days       = 90;
input int    strategy_residual_days        = 20;
input int    strategy_coint_exit_days      = 30;
input double strategy_coint_pvalue_max     = 0.05;
input double strategy_coint_exit_pvalue    = 0.20;
input double strategy_entry_z              = 2.0;
input double strategy_exit_z               = 0.0;
input double strategy_stop_z               = 3.5;
input int    strategy_min_half_life_bars   = 2;
input int    strategy_max_half_life_bars   = 96;
input int    strategy_max_hold_bars        = 48;
input double strategy_max_spread_cost_frac = 0.15;
input double strategy_vol_stop_mult        = 3.5;

string   g_allowed_symbols[6] = {"EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX", "SP500.DWX", "NDX.DWX"};
string   g_symbol_a = "";
string   g_symbol_b = "";
int      g_slot_a = -1;
int      g_slot_b = -1;
double   g_alpha = 0.0;
double   g_beta = 1.0;
double   g_residual_mean = 0.0;
double   g_residual_sd = 0.0;
double   g_current_z = 0.0;
double   g_current_adf_t = 0.0;
double   g_exit_adf_t = 0.0;
double   g_half_life = 0.0;
bool     g_state_ready = false;
datetime g_entry_bar_time = 0;

int BarsPerTradingDay()
  {
   return 96;
  }

int SlotForSymbol(const string symbol)
  {
   if(symbol == "EURUSD.DWX") return 0;
   if(symbol == "GBPUSD.DWX") return 1;
   if(symbol == "AUDUSD.DWX") return 2;
   if(symbol == "NZDUSD.DWX") return 3;
   if(symbol == "SP500.DWX")  return 4;
   if(symbol == "NDX.DWX")    return 5;
   return -1;
  }

bool ResolvePairForHost()
  {
   if(_Symbol == "EURUSD.DWX" || _Symbol == "GBPUSD.DWX")
     {
      g_symbol_a = "EURUSD.DWX";
      g_symbol_b = "GBPUSD.DWX";
     }
   else if(_Symbol == "AUDUSD.DWX" || _Symbol == "NZDUSD.DWX")
     {
      g_symbol_a = "AUDUSD.DWX";
      g_symbol_b = "NZDUSD.DWX";
     }
   else if(_Symbol == "SP500.DWX" || _Symbol == "NDX.DWX")
     {
      g_symbol_a = "SP500.DWX";
      g_symbol_b = "NDX.DWX";
     }
   else
      return false;

   g_slot_a = SlotForSymbol(g_symbol_a);
   g_slot_b = SlotForSymbol(g_symbol_b);
   return (g_slot_a >= 0 && g_slot_b >= 0);
  }

double AdfCriticalFromP(const double p_value)
  {
   if(p_value <= 0.01)
      return -3.43;
   if(p_value <= 0.05)
      return -2.86;
   return -2.57;
  }

bool ReadLogCloses(const string symbol, double &out[], const int bars)
  {
   ArrayResize(out, bars);
   ArraySetAsSeries(out, true);

   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(symbol, PERIOD_M15, 1, bars, closes) != bars) // perf-allowed: called only from Strategy_EntrySignal after the framework QM_IsNewBar gate.
      return false;

   for(int i = 0; i < bars; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      out[i] = MathLog(closes[i]);
     }
   return true;
  }

bool EstimateOls(const double &loga[], const double &logb[], const int bars, double &alpha, double &beta)
  {
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double x = logb[i];
      const double y = loga[i];
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
     }

   const double n = (double)bars;
   const double denom = sxx - sx * sx / n;
   if(MathAbs(denom) < 1e-12)
      return false;

   beta = (sxy - sx * sy / n) / denom;
   alpha = sy / n - beta * sx / n;
   return (MathIsValidNumber(alpha) && MathIsValidNumber(beta) && MathAbs(beta) > 0.01 && MathAbs(beta) < 20.0);
  }

void BuildResiduals(const double &loga[], const double &logb[], const int bars, double &residuals[])
  {
   ArrayResize(residuals, bars);
   ArraySetAsSeries(residuals, true);
   for(int i = 0; i < bars; ++i)
      residuals[i] = loga[i] - (g_alpha + g_beta * logb[i]);
  }

bool ResidualStats(const double &residuals[], const int lookback, double &mean, double &sd)
  {
   if(lookback < 3)
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
   sd = MathSqrt(var / (double)(lookback - 1));
   return (sd > 0.0 && MathIsValidNumber(sd));
  }

bool AdfTStatAndHalfLife(const double &residuals[], const int bars, double &t_stat, double &half_life)
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
   if(MathAbs(denom) < 1e-12)
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

   if(n <= 2)
      return false;
   const double se = MathSqrt((sse / (double)(n - 2)) / denom);
   if(se <= 0.0)
      return false;

   t_stat = slope / se;
   if(slope >= 0.0)
      return false;

   half_life = -MathLog(2.0) / slope;
   return (MathIsValidNumber(t_stat) && MathIsValidNumber(half_life));
  }

double LogSpreadCost()
  {
   const double ask_a = SymbolInfoDouble(g_symbol_a, SYMBOL_ASK);
   const double bid_a = SymbolInfoDouble(g_symbol_a, SYMBOL_BID);
   const double ask_b = SymbolInfoDouble(g_symbol_b, SYMBOL_ASK);
   const double bid_b = SymbolInfoDouble(g_symbol_b, SYMBOL_BID);
   if(ask_a <= 0.0 || bid_a <= 0.0 || ask_b <= 0.0 || bid_b <= 0.0)
      return DBL_MAX;

   const double mid_a = 0.5 * (ask_a + bid_a);
   const double mid_b = 0.5 * (ask_b + bid_b);
   if(mid_a <= 0.0 || mid_b <= 0.0)
      return DBL_MAX;

   return MathAbs(MathLog(ask_a / bid_a)) + MathAbs(g_beta) * MathAbs(MathLog(ask_b / bid_b));
  }

bool RefreshState()
  {
   if(!ResolvePairForHost())
     {
      g_state_ready = false;
      return false;
     }

   SymbolSelect(g_symbol_a, true);
   SymbolSelect(g_symbol_b, true);

   const int bars_per_day = BarsPerTradingDay();
   const int formation_bars = MathMax(30, strategy_formation_days * bars_per_day);
   const int z_bars = MathMax(20, strategy_residual_days * bars_per_day);
   const int exit_bars = MathMax(30, strategy_coint_exit_days * bars_per_day);
   const int required_bars = MathMax(formation_bars, MathMax(z_bars + 2, exit_bars + 2));

   double loga[], logb[];
   if(!ReadLogCloses(g_symbol_a, loga, required_bars) || !ReadLogCloses(g_symbol_b, logb, required_bars))
     {
      g_state_ready = false;
      return false;
     }

   if(!EstimateOls(loga, logb, formation_bars, g_alpha, g_beta))
     {
      g_state_ready = false;
      return false;
     }

   double residuals[];
   BuildResiduals(loga, logb, required_bars, residuals);

   if(!ResidualStats(residuals, z_bars, g_residual_mean, g_residual_sd))
     {
      g_state_ready = false;
      return false;
     }

   if(!AdfTStatAndHalfLife(residuals, formation_bars, g_current_adf_t, g_half_life))
     {
      g_state_ready = false;
      return false;
     }

   double exit_half_life = 0.0;
   if(!AdfTStatAndHalfLife(residuals, exit_bars, g_exit_adf_t, exit_half_life))
     {
      g_state_ready = false;
      return false;
     }

   if(g_half_life < strategy_min_half_life_bars || g_half_life > strategy_max_half_life_bars)
     {
      g_state_ready = false;
      return false;
     }

   g_current_z = (residuals[0] - g_residual_mean) / g_residual_sd;
   g_state_ready = MathIsValidNumber(g_current_z);
   return g_state_ready;
  }

bool IsPackagePosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int magic = (int)PositionGetInteger(POSITION_MAGIC);
   if(symbol == g_symbol_a && magic == QM_MagicChecked(qm_ea_id, g_slot_a, g_symbol_a))
      return true;
   if(symbol == g_symbol_b && magic == QM_MagicChecked(qm_ea_id, g_slot_b, g_symbol_b))
      return true;
   return false;
  }

bool HasPackagePosition()
  {
   if(!ResolvePairForHost())
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(IsPackagePosition())
         return true;
     }
   return false;
  }

datetime OldestPackageOpenTime()
  {
   datetime oldest = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!IsPackagePosition())
         continue;
      const datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || t < oldest)
         oldest = t;
     }
   return oldest;
  }

int ClosePackage(const QM_ExitReason reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!IsPackagePosition())
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         ++closed;
     }
   return closed;
  }

double RecentVolDistance(const string symbol)
  {
   const int bars = MathMax(20, strategy_residual_days * BarsPerTradingDay());
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(symbol, PERIOD_M15, 1, bars + 1, closes) != bars + 1) // perf-allowed: called only from Strategy_EntrySignal after the framework QM_IsNewBar gate.
      return 0.0;

   double sum = 0.0;
   for(int i = 1; i <= bars; ++i)
      sum += MathAbs(closes[i - 1] - closes[i]);

   const double avg_move = sum / (double)bars;
   return avg_move * strategy_vol_stop_mult;
  }

bool OpenLeg(const string symbol,
             const int slot,
             const QM_OrderType type,
             const double weight,
             const double weight_sum,
             const string reason)
  {
   if(symbol != _Symbol)
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_dist = RecentVolDistance(symbol);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || stop_dist <= 0.0 || point <= 0.0 || weight_sum <= 0.0)
      return false;

   if(MathAbs(weight) <= 0.0)
      return false;

   QM_EntryRequest req;
   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? entry - stop_dist : entry + stop_dist;
   req.tp = 0.0;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;
   req.reason = reason;

   ulong ticket = 0;
   return QM_TM_OpenPosition(req, ticket);
  }

bool OpenPackage(const int direction)
  {
   const double weight_a = 1.0;
   const double weight_b = -g_beta;
   const double weight_sum = MathAbs(weight_a) + MathAbs(weight_b);
   if(weight_sum <= 0.0)
      return false;

   const QM_OrderType type_a = (direction > 0) ? QM_SELL : QM_BUY;
   const QM_OrderType type_b = (direction > 0) ? QM_BUY : QM_SELL;
   const string reason = (direction > 0) ? "COINTEG_SHORT_A_LONG_B" : "COINTEG_LONG_A_SHORT_B";

   bool opened = false;
   if(OpenLeg(g_symbol_a, g_slot_a, type_a, weight_a, weight_sum, reason))
      opened = true;
   if(OpenLeg(g_symbol_b, g_slot_b, type_b, weight_b, weight_sum, reason))
      opened = true;

   if(opened)
      g_entry_bar_time = TimeCurrent();
   return opened;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;
   if(!ResolvePairForHost())
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
   req.reason = "COINTEG_HOST_NOOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!RefreshState())
      return false;
   if(HasPackagePosition())
      return false;

   if(g_current_adf_t > AdfCriticalFromP(strategy_coint_pvalue_max))
      return false;

   const double entry_distance = MathAbs(g_current_z * g_residual_sd);
   if(entry_distance <= 0.0 || LogSpreadCost() > strategy_max_spread_cost_frac * entry_distance)
      return false;

   if(g_current_z >= strategy_entry_z)
      OpenPackage(1);
   else if(g_current_z <= -strategy_entry_z)
      OpenPackage(-1);

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!ResolvePairForHost() || !HasPackagePosition())
      return false;

   if(g_state_ready)
     {
      if(MathAbs(g_current_z) <= MathAbs(strategy_exit_z))
        {
         ClosePackage(QM_EXIT_STRATEGY);
         return false;
        }
      if(MathAbs(g_current_z) >= strategy_stop_z)
        {
         ClosePackage(QM_EXIT_STRATEGY);
         return false;
        }
      if(g_exit_adf_t > AdfCriticalFromP(strategy_coint_exit_pvalue))
        {
         ClosePackage(QM_EXIT_STRATEGY);
         return false;
        }
     }

   const datetime oldest = OldestPackageOpenTime();
   if(oldest > 0 && TimeCurrent() - oldest >= strategy_max_hold_bars * PeriodSeconds(PERIOD_M15))
     {
      ClosePackage(QM_EXIT_TIME_STOP);
      return false;
     }
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!ResolvePairForHost())
      return true;

   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_symbol_a, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_symbol_b, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_symbol_a, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_symbol_b, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
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

   QM_SymbolGuardInit(g_allowed_symbols);
   QM_BasketWarmupHistory(g_allowed_symbols, PERIOD_M15, MathMax(300, strategy_formation_days * BarsPerTradingDay()));

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
