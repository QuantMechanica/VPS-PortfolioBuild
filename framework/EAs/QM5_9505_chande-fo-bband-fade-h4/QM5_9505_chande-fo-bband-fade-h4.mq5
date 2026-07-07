#property strict
#property version   "5.0"
#property description "QM5_9505 Chande Forecast Oscillator sigma-band fade H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9505 - Chande Forecast Oscillator sigma-band fade
// -----------------------------------------------------------------------------
// H4 price-only mean reversion:
//   1. Compute Chande's forecast oscillator from a prior-bar linear regression.
//   2. Fade closed-bar penetrations beyond the FO rolling 2-sigma envelope.
//   3. Trade only in low-volatility-ratio consolidation regimes.
// Runtime uses MT5 OHLC only; no external feed, optimizer state, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9505;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lr_period           = 14;
input int    strategy_fo_mean_lookback    = 60;
input double strategy_band_devs           = 2.0;
input int    strategy_vr_fast_atr         = 7;
input int    strategy_vr_slow_atr         = 28;
input double strategy_vr_max              = 0.7;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 1.0;
input int    strategy_max_hold_bars       = 14;
input double strategy_bar_confirm_frac    = 0.30;
input double strategy_slope_frac_max      = 0.005;
input double strategy_spread_atr_frac_max = 0.20;

double   g_fo_now          = 0.0;
double   g_fo_prev         = 0.0;
double   g_mean_now        = 0.0;
double   g_mean_prev       = 0.0;
double   g_sd_now          = 0.0;
double   g_sd_prev         = 0.0;
double   g_slope_now       = 0.0;
double   g_trigger_high    = 0.0;
double   g_trigger_low     = 0.0;
bool     g_state_ready     = false;
bool     g_new_bar_this_tick = false;

bool Strategy_CalcForecastOscillator(const double &closes[],
                                     const int index,
                                     const int period,
                                     double &fo,
                                     double &slope)
  {
   if(period < 2 || closes[index] <= 0.0)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;

   for(int i = 0; i < period; ++i)
     {
      const int close_index = index + period - i;
      const double x = (double)i;
      const double y = closes[close_index];
      if(y <= 0.0 || !MathIsValidNumber(y))
         return false;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double n = (double)period;
   const double denom = n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) <= DBL_EPSILON)
      return false;

   slope = (n * sum_xy - sum_x * sum_y) / denom;
   const double intercept = (sum_y - slope * sum_x) / n;
   const double forecast = intercept + slope * n;
   if(forecast <= 0.0 || !MathIsValidNumber(forecast))
      return false;

   fo = 100.0 * (closes[index] - forecast) / closes[index];
   return MathIsValidNumber(fo);
  }

bool Strategy_Stats(const double &values[],
                    const int start,
                    const int count,
                    double &mean,
                    double &sd)
  {
   if(count <= 1)
      return false;

   double sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double v = values[start + i];
      if(!MathIsValidNumber(v))
         return false;
      sum += v;
     }
   mean = sum / (double)count;

   double var_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double d = values[start + i] - mean;
      var_sum += d * d;
     }

   sd = MathSqrt(var_sum / (double)MathMax(1, count - 1));
   return (sd > 0.0 && MathIsValidNumber(sd));
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;

   const int lr_period = MathMax(2, strategy_lr_period);
   const int mean_lookback = MathMax(10, strategy_fo_mean_lookback);
   const int fo_count = mean_lookback + 1;
   const int close_count = mean_lookback + lr_period + 2;

   double closes[];
   double highs[];
   double lows[];
   ArraySetAsSeries(closes, true);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   if(CopyClose(_Symbol, PERIOD_H4, 1, close_count, closes) != close_count) // perf-allowed: bounded H4 FO window, called once per new bar.
      return false;
   if(CopyHigh(_Symbol, PERIOD_H4, 1, 1, highs) != 1) // perf-allowed: single closed trigger-bar high.
      return false;
   if(CopyLow(_Symbol, PERIOD_H4, 1, 1, lows) != 1) // perf-allowed: single closed trigger-bar low.
      return false;

   double fo_values[];
   ArrayResize(fo_values, fo_count);
   for(int i = 0; i < fo_count; ++i)
     {
      double slope = 0.0;
      if(!Strategy_CalcForecastOscillator(closes, i, lr_period, fo_values[i], slope))
         return false;
      if(i == 0)
         g_slope_now = slope;
     }

   if(!Strategy_Stats(fo_values, 0, mean_lookback, g_mean_now, g_sd_now))
      return false;
   if(!Strategy_Stats(fo_values, 1, mean_lookback, g_mean_prev, g_sd_prev))
      return false;

   g_fo_now = fo_values[0];
   g_fo_prev = fo_values[1];
   g_trigger_high = highs[0];
   g_trigger_low = lows[0];
   g_state_ready = true;
   return true;
  }

bool Strategy_HasOpenPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

void Strategy_CloseByMagic(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

int Strategy_PositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

datetime Strategy_OldestOpenTime()
  {
   datetime oldest = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened <= 0)
         continue;
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

bool Strategy_SpreadAllowed(const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return false;

   if(ask > bid && strategy_spread_atr_frac_max > 0.0)
     {
      const double spread_price = ask - bid;
      if(spread_price > strategy_spread_atr_frac_max * atr)
         return false;
     }
   return true;
  }

bool Strategy_BuildRequest(const QM_OrderType side, QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || !Strategy_SpreadAllowed(atr))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = QM_OrderTypeIsBuy(side) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl = 0.0;
   if(QM_OrderTypeIsBuy(side))
     {
      sl = g_trigger_low - strategy_sl_atr_mult * atr;
      if(sl <= 0.0 || sl >= entry)
         sl = entry - strategy_sl_atr_mult * atr;
     }
   else
     {
      sl = g_trigger_high + strategy_sl_atr_mult * atr;
      if(sl <= entry)
         sl = entry + strategy_sl_atr_mult * atr;
     }

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, digits);
   req.tp = 0.0;
   req.reason = QM_OrderTypeIsBuy(side) ? "QM5_9505_FO_SIGMA_FADE_LONG"
                                        : "QM5_9505_FO_SIGMA_FADE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4)
      return true;
   if(qm_magic_slot_offset < 0)
      return true;
   if(strategy_lr_period < 2)
      return true;
   if(strategy_fo_mean_lookback < 10)
      return true;
   if(strategy_band_devs <= 0.0)
      return true;
   if(strategy_vr_fast_atr <= 0 || strategy_vr_slow_atr <= 0)
      return true;
   if(strategy_vr_max <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0)
      return true;
   if(strategy_bar_confirm_frac < 0.0 || strategy_bar_confirm_frac > 1.0)
      return true;
   if(strategy_slope_frac_max <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_ready && !Strategy_RefreshState())
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const double atr_fast = QM_ATR(_Symbol, PERIOD_H4, strategy_vr_fast_atr, 1);
   const double atr_slow = QM_ATR(_Symbol, PERIOD_H4, strategy_vr_slow_atr, 1);
   if(atr_fast <= 0.0 || atr_slow <= 0.0)
      return false;
   const double vr = atr_fast / atr_slow;
   if(vr >= strategy_vr_max)
      return false;

   double close_buf[];
   ArraySetAsSeries(close_buf, true);
   if(CopyClose(_Symbol, PERIOD_H4, 1, 1, close_buf) != 1) // perf-allowed: one closed trigger close on H4 entry evaluation.
      return false;

   const double trigger_close = close_buf[0];
   const double bar_range = g_trigger_high - g_trigger_low;
   if(trigger_close <= 0.0 || bar_range <= 0.0)
      return false;
   if(MathAbs(g_slope_now) >= strategy_slope_frac_max * trigger_close)
      return false;

   const double upper_now = g_mean_now + strategy_band_devs * g_sd_now;
   const double upper_prev = g_mean_prev + strategy_band_devs * g_sd_prev;
   const double lower_now = g_mean_now - strategy_band_devs * g_sd_now;
   const double lower_prev = g_mean_prev - strategy_band_devs * g_sd_prev;

   const bool crossed_upper = (g_fo_prev <= upper_prev && g_fo_now > upper_now);
   const bool crossed_lower = (g_fo_prev >= lower_prev && g_fo_now < lower_now);
   const bool short_bar_confirm = (trigger_close < g_trigger_high - strategy_bar_confirm_frac * bar_range);
   const bool long_bar_confirm = (trigger_close > g_trigger_low + strategy_bar_confirm_frac * bar_range);

   if(crossed_upper && short_bar_confirm)
      return Strategy_BuildRequest(QM_SELL, req);
   if(crossed_lower && long_bar_confirm)
      return Strategy_BuildRequest(QM_BUY, req);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime opened = Strategy_OldestOpenTime();
   const int hold_seconds = MathMax(1, strategy_max_hold_bars) * PeriodSeconds(PERIOD_H4);
   if(opened > 0 && TimeCurrent() - opened >= hold_seconds)
     {
      Strategy_CloseByMagic(QM_EXIT_STRATEGY);
      return false;
     }

   if(!g_state_ready)
      return false;

   const int direction = Strategy_PositionDirection();
   if(direction > 0 && g_fo_prev <= g_mean_prev && g_fo_now > g_mean_now)
      Strategy_CloseByMagic(QM_EXIT_STRATEGY);
   else if(direction < 0 && g_fo_prev >= g_mean_prev && g_fo_now < g_mean_now)
      Strategy_CloseByMagic(QM_EXIT_STRATEGY);
   return false;
  }

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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9505\",\"ea\":\"chande-fo-bband-fade-h4\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   g_new_bar_this_tick = QM_IsNewBar();
   if(g_new_bar_this_tick)
     {
      QM_EquityStreamOnNewBar();
      if(Strategy_HasOpenPosition())
         Strategy_RefreshState();
      else
         g_state_ready = false;
     }

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!g_new_bar_this_tick)
      return;

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
