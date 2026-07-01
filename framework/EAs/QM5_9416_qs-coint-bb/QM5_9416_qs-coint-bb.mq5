#property strict
#property version   "5.0"
#property description "QM5_9416 QuantStart Cointegrated Spread Bollinger Pair"

#include <QM/QM_Common.mqh>

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
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_x_symbol       = "NDX.DWX";
input int    strategy_bb_period       = 15;
input double strategy_entry_z         = 1.5;
input double strategy_exit_z          = 0.5;
input double strategy_stop_z          = 4.0;
input int    strategy_ols_period      = 252;
input int    strategy_reestimate_bars = 21;
input double strategy_beta_min        = 0.25;
input double strategy_beta_max        = 4.0;
input int    strategy_atr_period      = 14;
input double strategy_atr_sl_mult     = 2.0;

double  g_beta                  = 0.0;
double  g_zscore                = 0.0;
bool    g_warmup_complete       = false;
bool    g_beta_valid            = false;
int     g_bars_since_reestimate = 9999;

bool ComputeOLSBeta(const string sym_y, const string sym_x, const int n, double &out_beta)
  {
   out_beta = 1.0;
   MqlRates ry[], rx[];
   ArraySetAsSeries(ry, true);
   ArraySetAsSeries(rx, true);
   if(CopyRates(sym_y, PERIOD_D1, 1, n, ry) != n) return false;
   if(CopyRates(sym_x, PERIOD_D1, 1, n, rx) != n) return false;

   double sx = 0.0, sy = 0.0;
   for(int i = 0; i < n; ++i)
     {
      if(ry[i].close <= 0.0 || rx[i].close <= 0.0) return false;
      sx += MathLog(rx[i].close);
      sy += MathLog(ry[i].close);
     }
   const double mx = sx / n;
   const double my = sy / n;

   double cov = 0.0, var_x = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double dx = MathLog(rx[i].close) - mx;
      cov   += dx * (MathLog(ry[i].close) - my);
      var_x += dx * dx;
     }
   if(var_x <= 0.0) return false;
   out_beta = cov / var_x;
   return MathIsValidNumber(out_beta) && out_beta > 0.0;
  }

bool ComputeZScore(const string sym_y, const string sym_x, const int period,
                   const double beta, double &out_z)
  {
   out_z = 0.0;
   MqlRates ry[], rx[];
   ArraySetAsSeries(ry, true);
   ArraySetAsSeries(rx, true);
   if(CopyRates(sym_y, PERIOD_D1, 1, period, ry) != period) return false;
   if(CopyRates(sym_x, PERIOD_D1, 1, period, rx) != period) return false;

   double spreads[];
   ArrayResize(spreads, period);
   for(int i = 0; i < period; ++i)
     {
      if(ry[i].close <= 0.0 || rx[i].close <= 0.0) return false;
      spreads[i] = MathLog(ry[i].close) - beta * MathLog(rx[i].close);
     }

   double sum = 0.0;
   for(int i = 0; i < period; ++i) sum += spreads[i];
   const double mean = sum / period;

   double var = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double d = spreads[i] - mean;
      var += d * d;
     }
   if(var <= 0.0) return false;
   const double std_dev = MathSqrt(var / (double)(period - 1));
   if(std_dev <= 0.0) return false;

   out_z = (spreads[0] - mean) / std_dev;
   return MathIsValidNumber(out_z);
  }

void AdvanceState_OnNewBar()
  {
   g_warmup_complete = false;
   g_beta_valid = false;
   g_zscore = 0.0;

   const int need = strategy_ols_period + strategy_bb_period + 5;
   MqlRates probe[];
   ArraySetAsSeries(probe, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, need, probe) < need) return;
   g_warmup_complete = true;

   ++g_bars_since_reestimate;
   if(g_bars_since_reestimate >= strategy_reestimate_bars)
     {
      double new_beta = 0.0;
      if(ComputeOLSBeta(_Symbol, strategy_x_symbol, strategy_ols_period, new_beta) &&
         new_beta >= strategy_beta_min && new_beta <= strategy_beta_max)
         g_beta = new_beta;
      g_bars_since_reestimate = 0;
     }

   g_beta_valid = (g_beta >= strategy_beta_min && g_beta <= strategy_beta_max);

   if(g_beta_valid && strategy_bb_period >= 5)
     {
      double z = 0.0;
      if(ComputeZScore(_Symbol, strategy_x_symbol, strategy_bb_period, g_beta, z))
         g_zscore = z;
     }
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!g_warmup_complete) return true;
   if(!g_beta_valid)      return true;
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0) return false;

   if(g_zscore < -strategy_entry_z)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;
      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      req.tp     = 0.0;
      req.reason = "COINT_BB_LONG_SPREAD";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(g_zscore > strategy_entry_z)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;
      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
      req.tp     = 0.0;
      req.reason = "COINT_BB_SHORT_SPREAD";
      return (req.sl > 0.0 && req.sl > bid);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(!g_beta_valid) return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         if(g_zscore >= -strategy_exit_z) return true;
         if(g_zscore <= -strategy_stop_z) return true;
        }
      else
        {
         if(g_zscore <= strategy_exit_z) return true;
         if(g_zscore >= strategy_stop_z) return true;
        }
      break;
     }
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   string allowed[] = {_Symbol, strategy_x_symbol};
   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_D1, strategy_ols_period + strategy_bb_period + 10);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"x_sym\":\"%s\",\"bb\":%d,\"entry_z\":%.2f,\"ols\":%d}",
                            strategy_x_symbol, strategy_bb_period,
                            strategy_entry_z, strategy_ols_period));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_FrameworkHandleFridayClose()) return;

   const bool nb = QM_IsNewBar();
   if(nb)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(Strategy_NoTradeFilter()) return;
   if(!nb) return;

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
