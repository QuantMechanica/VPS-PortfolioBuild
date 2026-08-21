#property strict
#property version   "5.0"
#property description "QM5_37001 Dr. Ernest P. Chan Ornstein-Uhlenbeck Stat-Arb Model"
// Strategy Card: QM5_37001 (ernest-chan-ornstein-uhlenbeck-statarb), G0 APPROVED.
// Source: Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. John Wiley & Sons.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37001 — Ornstein-Uhlenbeck Mean Reversion Model
// -----------------------------------------------------------------------------
// Continuous-time Ornstein-Uhlenbeck (OU) mean-reversion modeling on H1 bars.
// Discrete regression: delta x_t = a + b * x_{t-1} + e_t over lookback N bars.
// Speed of mean reversion: theta = -ln(1+b), Half-life tau = ln(2)/theta.
// Equilibrium mean: mu = -a / b, Dispersion: sigma.
// Normalized Z-score: Z_t = (x_t - mu) / sigma.
//
// Long Entry:  Z_t <= -2.00 AND tau in [5, 40] bars -> market buy
// Short Entry: Z_t >= +2.00 AND tau in [5, 40] bars -> market sell
// Exit Signal: Long closes when Z_t >= -0.15 (mean revert) or Z_t <= -3.50 (diverge)
//              Short closes when Z_t <= +0.15 (mean revert) or Z_t >= +3.50 (diverge)
//              Time stop: hold duration >= 2.5 * tau bars
// Safety Stop: Fixed ATR(14) stop at entry
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 37001;
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
input int    strategy_lookback_window   = 100;    // Rolling OLS estimation window (bars)
input double strategy_zscore_entry      = 2.0;    // Standard deviation entry threshold (|Z| >= 2.0)
input double strategy_zscore_exit_tp    = 0.15;   // Take profit threshold (|Z| <= 0.15)
input double strategy_zscore_exit_sl    = 3.5;    // Stop loss threshold (|Z| >= 3.5)
input double strategy_min_half_life     = 5.0;    // Minimum allowable half-life in bars
input double strategy_max_half_life     = 40.0;   // Maximum allowable half-life in bars
input double strategy_time_stop_mult    = 2.5;    // Time stop multiplier (max hold = mult * tau bars)
input int    strategy_atr_period        = 14;     // ATR period for safety stop and spread filter
input double strategy_atr_sl_mult       = 3.0;    // Safety stop distance = mult * ATR(14)
input double strategy_max_spread_atr    = 1.8;    // Spread filter: max spread as ATR multiplier
input int    strategy_max_spread_points = 300;    // Absolute point cap on spread

// -----------------------------------------------------------------------------
// OU Calculation Helper
// -----------------------------------------------------------------------------

struct OU_Result
{
   bool   valid;
   double z_score;
   double half_life;
   double mean;
   double sigma;
};

OU_Result ComputeOrnsteinUhlenbeck(const string sym, const ENUM_TIMEFRAMES tf, const int lookback)
{
   OU_Result res;
   res.valid = false;
   res.z_score = 0.0;
   res.half_life = 0.0;
   res.mean = 0.0;
   res.sigma = 0.0;

   if(lookback < 20) return res;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, tf, 1, lookback + 1, rates) < lookback + 1) // perf-allowed: closed-bar OLS regression
      return res;

   double sum_x = 0.0, sum_y = 0.0, sum_xx = 0.0, sum_xy = 0.0;
   for(int i = 0; i < lookback; ++i)
   {
      double x_val = rates[i + 1].close;
      double y_val = rates[i].close - rates[i + 1].close;
      sum_x += x_val;
      sum_y += y_val;
      sum_xx += x_val * x_val;
      sum_xy += x_val * y_val;
   }

   double n = (double)lookback;
   double denom = (n * sum_xx - sum_x * sum_x);
   if(MathAbs(denom) < 1e-12)
      return res;

   double b = (n * sum_xy - sum_x * sum_y) / denom;
   double a = (sum_y - b * sum_x) / n;

   // Mean reversion requires b < 0 and 1 + b > 0
   if(b >= 0.0 || (1.0 + b) <= 0.0)
      return res;

   double theta = -MathLog(1.0 + b);
   if(theta <= 1e-6)
      return res;

   double half_life = MathLog(2.0) / theta;
   double mean = -a / b;

   double sum_sq_diff = 0.0;
   for(int i = 0; i < lookback; ++i)
   {
      double diff = rates[i].close - mean;
      sum_sq_diff += diff * diff;
   }
   double sigma = MathSqrt(sum_sq_diff / n);
   if(sigma < 1e-8)
      return res;

   double z_score = (rates[0].close - mean) / sigma;

   res.valid = true;
   res.z_score = z_score;
   res.half_life = half_life;
   res.mean = mean;
   res.sigma = sigma;
   return res;
}

bool IsRolloverBlackout()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day <= 5)
      return true;
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(IsRolloverBlackout())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > (strategy_max_spread_atr * atr))
         return true;
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point > 0.0 && strategy_max_spread_points > 0 && (ask - bid) > (strategy_max_spread_points * point))
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   OU_Result ou = ComputeOrnsteinUhlenbeck(_Symbol, PERIOD_H1, strategy_lookback_window);
   if(!ou.valid)
      return false;

   if(ou.half_life < strategy_min_half_life || ou.half_life > strategy_max_half_life)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ou.z_score <= -strategy_zscore_entry)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37001_OU_BUY";
      req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
   }
   else if(ou.z_score >= strategy_zscore_entry)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37001_OU_SELL";
      req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
   }
   else
   {
      return false;
   }

   if(req.sl <= 0.0)
      return false;

   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int open_dir = 0;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      open_dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
   }

   if(open_dir == 0)
      return false;

   OU_Result ou = ComputeOrnsteinUhlenbeck(_Symbol, PERIOD_H1, strategy_lookback_window);
   if(ou.valid)
   {
      if(open_dir > 0)
      {
         // Long position: exit on mean reversion (Z >= -exit_tp) or divergence stop (Z <= -exit_sl)
         if(ou.z_score >= -strategy_zscore_exit_tp || ou.z_score <= -strategy_zscore_exit_sl)
            return true;
      }
      else if(open_dir < 0)
      {
         // Short position: exit on mean reversion (Z <= exit_tp) or divergence stop (Z >= exit_sl)
         if(ou.z_score <= strategy_zscore_exit_tp || ou.z_score >= strategy_zscore_exit_sl)
            return true;
      }
   }

   // Time stop exit: hold bars >= strategy_time_stop_mult * max_half_life
   if(open_time > 0)
   {
      int hold_seconds = (int)(TimeCurrent() - open_time);
      int max_hold_seconds = (int)(strategy_time_stop_mult * strategy_max_half_life * PeriodSeconds(PERIOD_H1));
      if(hold_seconds >= max_hold_seconds)
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_37001_ernest_chan_ou_statarb\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
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
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
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
   ZeroMemory(req);
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
