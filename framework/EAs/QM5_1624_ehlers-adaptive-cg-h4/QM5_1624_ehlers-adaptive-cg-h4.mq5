#property strict
#property version   "5.0"
#property description "QM5_1624 Ehlers Adaptive Center of Gravity H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1624
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1624;
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
input int    strategy_period_min        = 6;
input int    strategy_period_max        = 48;
input int    strategy_autocorr_lookback = 48;
input int    strategy_d1_ema_period     = 200;
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 2.0;
input double strategy_spread_atr_mult   = 0.3;
input double strategy_time_stop_mult    = 2.0; // time stop = 2.0 * P bars

// -----------------------------------------------------------------------------
// State variables
// -----------------------------------------------------------------------------
QM_ExitReason g_strategy_exit_reason  = QM_EXIT_STRATEGY;
datetime      g_last_trade_time       = 0;
int           g_last_trade_dir        = 0;
int           g_last_dominant_period  = 20;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
bool LoadRates(const ENUM_TIMEFRAMES tf, const int bars_needed, MqlRates &rates[])
{
   if(bars_needed <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, bars_needed, rates); // perf-allowed: bounded bespoke autocorrelation periodogram
   ArraySetAsSeries(rates, true);
   return (copied >= bars_needed);
}

int ComputeDominantPeriod(MqlRates &rates[], const int start_shift)
{
   const int min_p = MathMax(4, strategy_period_min);
   const int max_p = MathMin(64, strategy_period_max);
   const int lookback = MathMax(20, strategy_autocorr_lookback);

   double autocorr[65];
   ArrayInitialize(autocorr, 0.0);

   for(int lag = 1; lag <= max_p; ++lag)
   {
      double sum_xy = 0.0;
      double sum_xx = 0.0;
      double sum_yy = 0.0;
      for(int k = 0; k < lookback; ++k)
      {
         const int idx_x = start_shift + k;
         const int idx_y = start_shift + k + lag;
         const double x = rates[idx_x].close;
         const double y = rates[idx_y].close;
         sum_xy += x * y;
         sum_xx += x * x;
         sum_yy += y * y;
      }
      const double denom = MathSqrt(sum_xx * sum_yy);
      if(denom > DBL_EPSILON)
         autocorr[lag] = sum_xy / denom;
      else
         autocorr[lag] = 0.0;
   }

   double max_power = -1.0;
   int best_period = (min_p + max_p) / 2;
   const double pi2 = 6.28318530717958647692;

   for(int p = min_p; p <= max_p; ++p)
   {
      double cos_part = 0.0;
      double sin_part = 0.0;
      for(int lag = 1; lag <= max_p; ++lag)
      {
         const double angle = pi2 * (double)lag / (double)p;
         cos_part += autocorr[lag] * MathCos(angle);
         sin_part += autocorr[lag] * MathSin(angle);
      }
      const double power = cos_part * cos_part + sin_part * sin_part;
      if(power > max_power)
      {
         max_power = power;
         best_period = p;
      }
   }
   return best_period;
}

double ComputeCG(MqlRates &rates[], const int shift, const int length)
{
   if(length < 2)
      return 0.0;
   double num = 0.0;
   double den = 0.0;
   for(int i = 0; i < length; ++i)
   {
      const double price = rates[shift + i].close;
      num += (double)(1 + i) * price;
      den += price;
   }
   if(MathAbs(den) <= DBL_EPSILON)
      return 0.0;
   return num / den;
}

bool SpreadAllows(const double atr_value)
{
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread < DBL_EPSILON)
      return true;
   if(atr_value <= 0.0)
      return true;
   return (spread <= strategy_spread_atr_mult * atr_value);
}

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
{
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong cand = PositionGetTicket(i);
      if(cand == 0 || !PositionSelectByTicket(cand))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = cand;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int bars_needed = strategy_autocorr_lookback + strategy_period_max + 30;
   MqlRates h4[];
   if(!LoadRates(PERIOD_H4, bars_needed, h4))
      return false;

   const int p = ComputeDominantPeriod(h4, 1);
   const int n = MathMax(3, (int)MathRound((double)p / 2.0));

   const double cg0 = ComputeCG(h4, 1, n);
   const double cg1 = ComputeCG(h4, 2, n);
   const double cg2 = ComputeCG(h4, 3, n);

   const bool bullish = (cg1 <= cg2 && cg0 > cg1);
   const bool bearish = (cg1 >= cg2 && cg0 < cg1);
   if(!bullish && !bearish)
      return false;

   const double d1_ema_now = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);
   const double d1_ema_prev = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 2, PRICE_CLOSE);
   if(d1_ema_now <= 0.0 || d1_ema_prev <= 0.0)
      return false;

   const double ema_slope = d1_ema_now - d1_ema_prev;
   if(bullish && ema_slope <= 0.0)
      return false;
   if(bearish && ema_slope >= 0.0)
      return false;

   const int dir = bullish ? 1 : -1;
   const datetime current_h4_bar = (datetime)SeriesInfoInteger(_Symbol, PERIOD_H4, SERIES_LASTBAR_DATE);
   const int cooldown_bars = n;
   if(g_last_trade_dir == dir && current_h4_bar > 0 && g_last_trade_time > 0 &&
      current_h4_bar - g_last_trade_time < cooldown_bars * PeriodSeconds(PERIOD_H4))
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(!SpreadAllows(atr_value))
      return false;

   req.type = bullish ? QM_BUY : QM_SELL;
   const double entry = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_value, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.reason = bullish ? "ADAPTIVE_CG_BULL_CROSS" : "ADAPTIVE_CG_BEAR_CROSS";

   if(req.sl <= 0.0)
      return false;

   g_last_trade_time = current_h4_bar;
   g_last_trade_dir = dir;
   g_last_dominant_period = p;
   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   g_strategy_exit_reason = QM_EXIT_STRATEGY;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, position_type))
      return false;

   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   const int time_stop_bars = (int)MathRound(strategy_time_stop_mult * (double)g_last_dominant_period);
   if(opened > 0 && h4_seconds > 0 &&
      TimeCurrent() - opened >= time_stop_bars * h4_seconds)
   {
      g_strategy_exit_reason = QM_EXIT_TIME_STOP;
      return true;
   }

   const double d1_ema_now = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);
   const double d1_ema_prev = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 2, PRICE_CLOSE);
   if(d1_ema_now > 0.0 && d1_ema_prev > 0.0)
   {
      const double ema_slope = d1_ema_now - d1_ema_prev;
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      if(is_buy && ema_slope < 0.0)
      {
         g_strategy_exit_reason = QM_EXIT_STRATEGY;
         return true;
      }
      if(!is_buy && ema_slope > 0.0)
      {
         g_strategy_exit_reason = QM_EXIT_STRATEGY;
         return true;
      }
   }

   const int bars_needed = strategy_autocorr_lookback + strategy_period_max + 30;
   MqlRates h4[];
   if(!LoadRates(PERIOD_H4, bars_needed, h4))
      return false;

   const int p = ComputeDominantPeriod(h4, 1);
   const int n = MathMax(3, (int)MathRound((double)p / 2.0));
   const double cg0 = ComputeCG(h4, 1, n);
   const double cg1 = ComputeCG(h4, 2, n);

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   if(is_buy && cg0 < cg1)
   {
      g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
   }
   if(!is_buy && cg0 > cg1)
   {
      g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
      return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1624_ehlers-adaptive-cg-h4\"}");
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
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, g_strategy_exit_reason);
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
