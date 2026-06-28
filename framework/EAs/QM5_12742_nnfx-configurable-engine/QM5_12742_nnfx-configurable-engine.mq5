#property strict
#property version   "5.0"
#property description "QM5_12742 NNFX configurable legal-combo engine"

#include <QM/QM_Common.mqh>

enum NNFXBaseline
  {
   NNFX_BASELINE_KIJUN = 0,
   NNFX_BASELINE_HMA = 1,
   NNFX_BASELINE_T3 = 2,
   NNFX_BASELINE_ALMA = 3,
   NNFX_BASELINE_MCGINLEY = 4,
   NNFX_BASELINE_ZLSMA = 5,
   NNFX_BASELINE_EMA = 6
  };

enum NNFXConfirm
  {
   NNFX_C1_SUPERTREND = 0,
   NNFX_C1_SSL = 1,
   NNFX_C1_AROON = 2,
   NNFX_C1_VORTEX = 3,
   NNFX_C1_STC = 4,
   NNFX_C1_QQE = 5,
   NNFX_C1_FISHER = 6
  };

enum NNFXConfirm2
  {
   NNFX_C2_OFF = 0,
   NNFX_C2_VORTEX = 1,
   NNFX_C2_AROON = 2,
   NNFX_C2_TRIX = 3
  };

enum NNFXVolumeGate
  {
   NNFX_VOLUME_ATR_EXPANSION = 0,
   NNFX_VOLUME_ADX_RISING = 1,
   NNFX_VOLUME_CMF = 2,
   NNFX_VOLUME_WAE = 3
  };

enum NNFXExitMode
  {
   NNFX_EXIT_PSAR = 0,
   NNFX_EXIT_C1_FLIP = 1,
   NNFX_EXIT_KIJUN_RECROSS = 2,
   NNFX_EXIT_CHANDELIER = 3
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12742;
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
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_D1;
input NNFXBaseline    nnfx_baseline      = NNFX_BASELINE_HMA;
input NNFXConfirm     nnfx_c1            = NNFX_C1_STC;
input NNFXConfirm2    nnfx_c2            = NNFX_C2_OFF;
input NNFXVolumeGate  nnfx_volume        = NNFX_VOLUME_ATR_EXPANSION;
input NNFXExitMode    nnfx_exit          = NNFX_EXIT_PSAR;
input int    nnfx_entry_window_bars      = 7;
input double nnfx_proximity_atr_mult     = 1.0;
input int    strategy_baseline_period    = 34;
input int    strategy_kijun_period       = 26;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 1.5;
input double strategy_tp_half_atr_mult   = 1.0;
input double strategy_partial_fraction   = 0.5;
input int    strategy_warmup_bars        = 240;
input int    strategy_max_spread_points  = 500;
input int    strategy_ssl_period         = 10;
input int    strategy_aroon_period       = 25;
input int    strategy_vortex_period      = 14;
input int    strategy_supertrend_period  = 10;
input double strategy_supertrend_mult    = 3.0;
input int    strategy_stc_cycle          = 10;
input int    strategy_qqe_rsi_period     = 14;
input int    strategy_fisher_period      = 10;
input int    strategy_trix_period        = 15;
input int    strategy_adx_period         = 14;
input double strategy_adx_threshold      = 20.0;
input int    strategy_cmf_period         = 20;
input double strategy_atr_expansion_mult = 0.90;
input int    strategy_wae_fast           = 20;
input int    strategy_wae_slow           = 40;
input int    strategy_wae_signal         = 9;
input double strategy_wae_sensitivity    = 150.0;
input int    strategy_wae_bb_period      = 20;
input double strategy_wae_bb_deviation   = 2.0;
input int    strategy_wae_deadzone_pts   = 150;
input double strategy_psar_step          = 0.02;
input double strategy_psar_maximum       = 0.20;
input int    strategy_chandelier_period  = 22;
input double strategy_chandelier_mult    = 3.0;
input double strategy_alma_offset        = 0.85;
input double strategy_alma_sigma         = 6.0;
input double strategy_t3_vfactor         = 0.70;

double Strategy_Close(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(sym, tf, shift); // perf-allowed: fixed closed-bar primitive for selectable NNFX component math.
  }

double Strategy_High(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iHigh(sym, tf, shift); // perf-allowed: fixed closed-bar primitive for selectable NNFX component math.
  }

double Strategy_Low(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iLow(sym, tf, shift); // perf-allowed: fixed closed-bar primitive for selectable NNFX component math.
  }

double Strategy_Volume(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return (double)iVolume(sym, tf, shift); // perf-allowed: closed-bar tick-volume primitive for CMF gate.
  }

int Strategy_Sign(const double value)
  {
   if(value > 0.0)
      return 1;
   if(value < 0.0)
      return -1;
   return 0;
  }

double Strategy_LSMA(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period < 2 || shift < 1)
      return 0.0;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double x = (double)i;
      const double y = Strategy_Close(sym, tf, shift + period - 1 - i);
      if(y <= 0.0)
         return 0.0;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double n = (double)period;
   const double denom = n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) <= 0.0)
      return 0.0;
   const double slope = (n * sum_xy - sum_x * sum_y) / denom;
   const double intercept = (sum_y - slope * sum_x) / n;
   return intercept + slope * (n - 1.0);
  }

double Strategy_ZLSMA(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period < 2 || shift < 1)
      return 0.0;
   const double lsma = Strategy_LSMA(sym, tf, period, shift);
   if(lsma <= 0.0)
      return 0.0;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double x = (double)i;
      const double y = Strategy_LSMA(sym, tf, period, shift + period - 1 - i);
      if(y <= 0.0)
         return 0.0;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double n = (double)period;
   const double denom = n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) <= 0.0)
      return 0.0;
   const double slope = (n * sum_xy - sum_x * sum_y) / denom;
   const double intercept = (sum_y - slope * sum_x) / n;
   const double lsma_of_lsma = intercept + slope * (n - 1.0);
   return lsma + (lsma - lsma_of_lsma);
  }

double Strategy_ALMA(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period < 2 || shift < 1 || strategy_alma_sigma <= 0.0)
      return 0.0;
   const double m = strategy_alma_offset * (double)(period - 1);
   const double s = (double)period / strategy_alma_sigma;
   double weighted = 0.0;
   double weights = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double price = Strategy_Close(sym, tf, shift + period - 1 - i);
      if(price <= 0.0)
         return 0.0;
      const double weight = MathExp(-((double)i - m) * ((double)i - m) / (2.0 * s * s));
      weighted += price * weight;
      weights += weight;
     }
   if(weights <= 0.0)
      return 0.0;
   return weighted / weights;
  }

double Strategy_McGinley(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period < 2 || shift < 1 || strategy_warmup_bars < 10)
      return 0.0;
   const int start = shift + strategy_warmup_bars;
   double md = Strategy_Close(sym, tf, start);
   if(md <= 0.0)
      return 0.0;

   for(int s = start - 1; s >= shift; --s)
     {
      const double close_price = Strategy_Close(sym, tf, s);
      if(close_price <= 0.0 || md <= 0.0)
         return 0.0;
      const double ratio = close_price / md;
      const double denom = (double)period * MathPow(ratio, 4.0);
      if(denom <= 0.0)
         return 0.0;
      md = md + (close_price - md) / denom;
     }
   return md;
  }

double Strategy_T3(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period < 2 || shift < 1 || strategy_warmup_bars < 10)
      return 0.0;
   const int start = shift + strategy_warmup_bars;
   double e1 = Strategy_Close(sym, tf, start);
   if(e1 <= 0.0)
      return 0.0;
   double e2 = e1, e3 = e1, e4 = e1, e5 = e1, e6 = e1;
   const double alpha = 2.0 / ((double)period + 1.0);
   for(int s = start - 1; s >= shift; --s)
     {
      const double close_price = Strategy_Close(sym, tf, s);
      if(close_price <= 0.0)
         return 0.0;
      e1 = alpha * close_price + (1.0 - alpha) * e1;
      e2 = alpha * e1 + (1.0 - alpha) * e2;
      e3 = alpha * e2 + (1.0 - alpha) * e3;
      e4 = alpha * e3 + (1.0 - alpha) * e4;
      e5 = alpha * e4 + (1.0 - alpha) * e5;
      e6 = alpha * e5 + (1.0 - alpha) * e6;
     }

   const double v = MathMax(0.0, MathMin(1.0, strategy_t3_vfactor));
   const double c1 = -v * v * v;
   const double c2 = 3.0 * v * v + 3.0 * v * v * v;
   const double c3 = -6.0 * v * v - 3.0 * v - 3.0 * v * v * v;
   const double c4 = 1.0 + 3.0 * v + v * v * v + 3.0 * v * v;
   return c1 * e6 + c2 * e5 + c3 * e4 + c4 * e3;
  }

double Strategy_BaselineValue(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   const int period = MathMax(2, strategy_baseline_period);
   switch(nnfx_baseline)
     {
      case NNFX_BASELINE_KIJUN:
         return QM_Ichimoku_KijunSen(sym, tf, 9, MathMax(2, strategy_kijun_period), 52, shift);
      case NNFX_BASELINE_HMA:
         return QM_HMA(sym, tf, period, shift);
      case NNFX_BASELINE_T3:
         return Strategy_T3(sym, tf, period, shift);
      case NNFX_BASELINE_ALMA:
         return Strategy_ALMA(sym, tf, period, shift);
      case NNFX_BASELINE_MCGINLEY:
         return Strategy_McGinley(sym, tf, period, shift);
      case NNFX_BASELINE_ZLSMA:
         return Strategy_ZLSMA(sym, tf, period, shift);
      case NNFX_BASELINE_EMA:
         return QM_EMA(sym, tf, period, shift, PRICE_CLOSE);
     }
   return 0.0;
  }

int Strategy_BaselineState(const int shift)
  {
   const double close_price = Strategy_Close(_Symbol, strategy_timeframe, shift);
   const double baseline = Strategy_BaselineValue(_Symbol, strategy_timeframe, shift);
   if(close_price <= 0.0 || baseline <= 0.0)
      return 0;
   if(close_price > baseline)
      return 1;
   if(close_price < baseline)
      return -1;
   return 0;
  }

int Strategy_BaselineRecentCross()
  {
   const int lookback = MathMax(1, nnfx_entry_window_bars);
   for(int k = 0; k < lookback; ++k)
     {
      const int shift = 1 + k;
      const double close_now = Strategy_Close(_Symbol, strategy_timeframe, shift);
      const double close_prev = Strategy_Close(_Symbol, strategy_timeframe, shift + 1);
      const double base_now = Strategy_BaselineValue(_Symbol, strategy_timeframe, shift);
      const double base_prev = Strategy_BaselineValue(_Symbol, strategy_timeframe, shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0 || base_now <= 0.0 || base_prev <= 0.0)
         continue;
      if(close_prev <= base_prev && close_now > base_now)
         return 1;
      if(close_prev >= base_prev && close_now < base_now)
         return -1;
     }
   return 0;
  }

bool Strategy_ProximityPass(const int direction)
  {
   const double close_price = Strategy_Close(_Symbol, strategy_timeframe, 1);
   const double baseline = Strategy_BaselineValue(_Symbol, strategy_timeframe, 1);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(close_price <= 0.0 || baseline <= 0.0 || atr <= 0.0 || nnfx_proximity_atr_mult <= 0.0)
      return false;
   if(direction > 0 && close_price <= baseline)
      return false;
   if(direction < 0 && close_price >= baseline)
      return false;
   return (MathAbs(close_price - baseline) <= atr * nnfx_proximity_atr_mult);
  }

int Strategy_SSLSignal(const int shift)
  {
   const double close_price = Strategy_Close(_Symbol, strategy_timeframe, shift);
   const double high_ma = QM_SMA(_Symbol, strategy_timeframe, MathMax(2, strategy_ssl_period), shift, PRICE_HIGH);
   const double low_ma = QM_SMA(_Symbol, strategy_timeframe, MathMax(2, strategy_ssl_period), shift, PRICE_LOW);
   if(close_price <= 0.0 || high_ma <= 0.0 || low_ma <= 0.0)
      return 0;
   if(close_price > high_ma)
      return 1;
   if(close_price < low_ma)
      return -1;
   return 0;
  }

int Strategy_AroonSignal(const int shift)
  {
   const int period = MathMax(2, strategy_aroon_period);
   int highest_idx = 0;
   int lowest_idx = 0;
   double highest = Strategy_High(_Symbol, strategy_timeframe, shift);
   double lowest = Strategy_Low(_Symbol, strategy_timeframe, shift);
   if(highest <= 0.0 || lowest <= 0.0)
      return 0;

   for(int i = 1; i < period; ++i)
     {
      const double high_i = Strategy_High(_Symbol, strategy_timeframe, shift + i);
      const double low_i = Strategy_Low(_Symbol, strategy_timeframe, shift + i);
      if(high_i <= 0.0 || low_i <= 0.0)
         return 0;
      if(high_i > highest)
        {
         highest = high_i;
         highest_idx = i;
        }
      if(low_i < lowest)
        {
         lowest = low_i;
         lowest_idx = i;
        }
     }

   const double aroon_up = 100.0 * ((double)period - (double)highest_idx) / (double)period;
   const double aroon_down = 100.0 * ((double)period - (double)lowest_idx) / (double)period;
   if(aroon_up > aroon_down)
      return 1;
   if(aroon_down > aroon_up)
      return -1;
   return 0;
  }

bool Strategy_Vortex(const int period, const int shift, double &vi_plus, double &vi_minus)
  {
   vi_plus = 0.0;
   vi_minus = 0.0;
   if(period < 2 || shift < 1)
      return false;
   double sum_vmp = 0.0;
   double sum_vmm = 0.0;
   double sum_tr = 0.0;
   for(int k = 0; k < period; ++k)
     {
      const int s = shift + k;
      const double high_now = Strategy_High(_Symbol, strategy_timeframe, s);
      const double low_now = Strategy_Low(_Symbol, strategy_timeframe, s);
      const double high_prev = Strategy_High(_Symbol, strategy_timeframe, s + 1);
      const double low_prev = Strategy_Low(_Symbol, strategy_timeframe, s + 1);
      const double close_prev = Strategy_Close(_Symbol, strategy_timeframe, s + 1);
      if(high_now <= 0.0 || low_now <= 0.0 || high_prev <= 0.0 || low_prev <= 0.0 || close_prev <= 0.0)
         return false;
      sum_vmp += MathAbs(high_now - low_prev);
      sum_vmm += MathAbs(low_now - high_prev);
      double tr = high_now - low_now;
      tr = MathMax(tr, MathAbs(high_now - close_prev));
      tr = MathMax(tr, MathAbs(low_now - close_prev));
      sum_tr += tr;
     }
   if(sum_tr <= 0.0)
      return false;
   vi_plus = sum_vmp / sum_tr;
   vi_minus = sum_vmm / sum_tr;
   return true;
  }

int Strategy_VortexSignal(const int shift)
  {
   double vi_plus = 0.0;
   double vi_minus = 0.0;
   if(!Strategy_Vortex(MathMax(2, strategy_vortex_period), shift, vi_plus, vi_minus))
      return 0;
   if(vi_plus > vi_minus)
      return 1;
   if(vi_minus > vi_plus)
      return -1;
   return 0;
  }

int Strategy_SuperTrendDir(const int shift)
  {
   const int period = MathMax(2, strategy_supertrend_period);
   if(strategy_supertrend_mult <= 0.0 || strategy_warmup_bars < 10)
      return 0;
   const int start = shift + strategy_warmup_bars;
   int dir = 1;
   double final_upper = 0.0;
   double final_lower = 0.0;
   bool seeded = false;

   for(int s = start; s >= shift; --s)
     {
      const double high_price = Strategy_High(_Symbol, strategy_timeframe, s);
      const double low_price = Strategy_Low(_Symbol, strategy_timeframe, s);
      const double close_price = Strategy_Close(_Symbol, strategy_timeframe, s);
      const double atr = QM_ATR(_Symbol, strategy_timeframe, period, s);
      if(high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0 || atr <= 0.0)
         return 0;
      const double mid = (high_price + low_price) / 2.0;
      const double basic_upper = mid + strategy_supertrend_mult * atr;
      const double basic_lower = mid - strategy_supertrend_mult * atr;
      if(!seeded)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         dir = (close_price >= mid) ? 1 : -1;
         seeded = true;
         continue;
        }

      const double close_prev = Strategy_Close(_Symbol, strategy_timeframe, s + 1);
      if(close_prev <= 0.0)
         return 0;
      if(basic_upper < final_upper || close_prev > final_upper)
         final_upper = basic_upper;
      if(basic_lower > final_lower || close_prev < final_lower)
         final_lower = basic_lower;
      if(dir == 1 && close_price < final_lower)
         dir = -1;
      else if(dir == -1 && close_price > final_upper)
         dir = 1;
     }

   return dir;
  }

double Strategy_STCValue(const int shift)
  {
   const int cycle = MathMax(3, strategy_stc_cycle);
   double macd_min = 0.0;
   double macd_max = 0.0;
   bool seeded = false;
   for(int i = 0; i < cycle; ++i)
     {
      const double macd = QM_MACD_Main(_Symbol, strategy_timeframe, 23, 50, 10, shift + i, PRICE_CLOSE);
      if(!seeded)
        {
         macd_min = macd;
         macd_max = macd;
         seeded = true;
        }
      else
        {
         macd_min = MathMin(macd_min, macd);
         macd_max = MathMax(macd_max, macd);
        }
     }
   const double current = QM_MACD_Main(_Symbol, strategy_timeframe, 23, 50, 10, shift, PRICE_CLOSE);
   const double range = macd_max - macd_min;
   if(range <= 0.0)
      return 50.0;
   return 100.0 * (current - macd_min) / range;
  }

int Strategy_STCSignal(const int shift)
  {
   const double stc_now = Strategy_STCValue(shift);
   const double stc_prev = Strategy_STCValue(shift + 1);
   if(stc_now > 50.0 && stc_now >= stc_prev)
      return 1;
   if(stc_now < 50.0 && stc_now <= stc_prev)
      return -1;
   return 0;
  }

int Strategy_QQESignal(const int shift)
  {
   const double rsi_now = QM_RSI(_Symbol, strategy_timeframe, MathMax(2, strategy_qqe_rsi_period), shift, PRICE_CLOSE);
   const double rsi_prev = QM_RSI(_Symbol, strategy_timeframe, MathMax(2, strategy_qqe_rsi_period), shift + 1, PRICE_CLOSE);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return 0;
   if(rsi_now > 50.0 && rsi_now >= rsi_prev)
      return 1;
   if(rsi_now < 50.0 && rsi_now <= rsi_prev)
      return -1;
   return 0;
  }

double Strategy_FisherValue(const int shift)
  {
   const int period = MathMax(3, strategy_fisher_period);
   double highest = Strategy_High(_Symbol, strategy_timeframe, shift);
   double lowest = Strategy_Low(_Symbol, strategy_timeframe, shift);
   if(highest <= 0.0 || lowest <= 0.0)
      return 0.0;
   for(int i = 1; i < period; ++i)
     {
      const double high_i = Strategy_High(_Symbol, strategy_timeframe, shift + i);
      const double low_i = Strategy_Low(_Symbol, strategy_timeframe, shift + i);
      if(high_i <= 0.0 || low_i <= 0.0)
         return 0.0;
      highest = MathMax(highest, high_i);
      lowest = MathMin(lowest, low_i);
     }
   const double median = (Strategy_High(_Symbol, strategy_timeframe, shift) + Strategy_Low(_Symbol, strategy_timeframe, shift)) / 2.0;
   const double range = highest - lowest;
   if(range <= 0.0 || median <= 0.0)
      return 0.0;
   double x = 2.0 * ((median - lowest) / range - 0.5);
   x = MathMax(-0.999, MathMin(0.999, x));
   return 0.5 * MathLog((1.0 + x) / (1.0 - x));
  }

int Strategy_FisherSignal(const int shift)
  {
   const double fisher_now = Strategy_FisherValue(shift);
   const double fisher_prev = Strategy_FisherValue(shift + 1);
   if(fisher_now > 0.0 && fisher_now >= fisher_prev)
      return 1;
   if(fisher_now < 0.0 && fisher_now <= fisher_prev)
      return -1;
   return 0;
  }

double Strategy_TripleEMA(const int period, const int shift)
  {
   if(period < 2 || shift < 1 || strategy_warmup_bars < 10)
      return 0.0;
   const int start = shift + strategy_warmup_bars;
   double e1 = Strategy_Close(_Symbol, strategy_timeframe, start);
   if(e1 <= 0.0)
      return 0.0;
   double e2 = e1;
   double e3 = e1;
   const double alpha = 2.0 / ((double)period + 1.0);
   for(int s = start - 1; s >= shift; --s)
     {
      const double close_price = Strategy_Close(_Symbol, strategy_timeframe, s);
      if(close_price <= 0.0)
         return 0.0;
      e1 = alpha * close_price + (1.0 - alpha) * e1;
      e2 = alpha * e1 + (1.0 - alpha) * e2;
      e3 = alpha * e2 + (1.0 - alpha) * e3;
     }
   return e3;
  }

int Strategy_TRIXSignal(const int shift)
  {
   const int period = MathMax(2, strategy_trix_period);
   const double trix_now = Strategy_TripleEMA(period, shift);
   const double trix_prev = Strategy_TripleEMA(period, shift + 1);
   if(trix_now <= 0.0 || trix_prev <= 0.0)
      return 0;
   if(trix_now > trix_prev)
      return 1;
   if(trix_now < trix_prev)
      return -1;
   return 0;
  }

int Strategy_C1Signal(const int shift)
  {
   switch(nnfx_c1)
     {
      case NNFX_C1_SUPERTREND:
         return Strategy_SuperTrendDir(shift);
      case NNFX_C1_SSL:
         return Strategy_SSLSignal(shift);
      case NNFX_C1_AROON:
         return Strategy_AroonSignal(shift);
      case NNFX_C1_VORTEX:
         return Strategy_VortexSignal(shift);
      case NNFX_C1_STC:
         return Strategy_STCSignal(shift);
      case NNFX_C1_QQE:
         return Strategy_QQESignal(shift);
      case NNFX_C1_FISHER:
         return Strategy_FisherSignal(shift);
     }
   return 0;
  }

int Strategy_C2Signal(const int shift)
  {
   switch(nnfx_c2)
     {
      case NNFX_C2_OFF:
         return 0;
      case NNFX_C2_VORTEX:
         return Strategy_VortexSignal(shift);
      case NNFX_C2_AROON:
         return Strategy_AroonSignal(shift);
      case NNFX_C2_TRIX:
         return Strategy_TRIXSignal(shift);
     }
   return 0;
  }

int Strategy_WAESignal(const int shift)
  {
   const double macd_now = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, shift, PRICE_CLOSE);
   const double macd_prev = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, shift + 1, PRICE_CLOSE);
   const double bb_upper = QM_BB_Upper(_Symbol, strategy_timeframe, strategy_wae_bb_period, strategy_wae_bb_deviation, shift, PRICE_CLOSE);
   const double bb_lower = QM_BB_Lower(_Symbol, strategy_timeframe, strategy_wae_bb_period, strategy_wae_bb_deviation, shift, PRICE_CLOSE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || point <= 0.0)
      return 0;
   const double momentum = (macd_now - macd_prev) * strategy_wae_sensitivity;
   const double explosion = MathAbs(bb_upper - bb_lower);
   const double deadzone = strategy_wae_deadzone_pts * point;
   const double threshold = MathMax(explosion, deadzone);
   if(momentum > threshold)
      return 1;
   if(-momentum > threshold)
      return -1;
   return 0;
  }

double Strategy_CMF(const int period, const int shift)
  {
   if(period < 2 || shift < 1)
      return 0.0;
   double mfv_sum = 0.0;
   double vol_sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const int s = shift + i;
      const double high_price = Strategy_High(_Symbol, strategy_timeframe, s);
      const double low_price = Strategy_Low(_Symbol, strategy_timeframe, s);
      const double close_price = Strategy_Close(_Symbol, strategy_timeframe, s);
      const double vol = Strategy_Volume(_Symbol, strategy_timeframe, s);
      if(high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0 || vol <= 0.0)
         continue;
      const double range = high_price - low_price;
      if(range <= 0.0)
         continue;
      const double multiplier = ((close_price - low_price) - (high_price - close_price)) / range;
      mfv_sum += multiplier * vol;
      vol_sum += vol;
     }
   if(vol_sum <= 0.0)
      return 0.0;
   return mfv_sum / vol_sum;
  }

bool Strategy_VolumePass(const int direction)
  {
   switch(nnfx_volume)
     {
      case NNFX_VOLUME_ATR_EXPANSION:
        {
         const double atr_now = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
         if(atr_now <= 0.0)
            return false;
         double atr_sum = 0.0;
         int count = 0;
         for(int i = 2; i <= 11; ++i)
           {
            const double atr_i = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, i);
            if(atr_i > 0.0)
              {
               atr_sum += atr_i;
               ++count;
              }
           }
         if(count <= 0)
            return false;
         const double atr_avg = atr_sum / (double)count;
         return (atr_now >= atr_avg * strategy_atr_expansion_mult);
        }
      case NNFX_VOLUME_ADX_RISING:
        {
         const double adx_now = QM_ADX(_Symbol, strategy_timeframe, strategy_adx_period, 1);
         const double adx_prev = QM_ADX(_Symbol, strategy_timeframe, strategy_adx_period, 2);
         return (adx_now >= strategy_adx_threshold && adx_now > adx_prev);
        }
      case NNFX_VOLUME_CMF:
        {
         const double cmf = Strategy_CMF(MathMax(2, strategy_cmf_period), 1);
         return (direction > 0) ? (cmf > 0.0) : (cmf < 0.0);
        }
      case NNFX_VOLUME_WAE:
        {
         return (Strategy_WAESignal(1) == direction);
        }
     }
   return false;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_ParameterGuard()
  {
   if(strategy_timeframe != PERIOD_D1 && strategy_timeframe != PERIOD_H4)
      return false;
   if(strategy_baseline_period < 2 || strategy_kijun_period < 2 || strategy_atr_period < 1)
      return false;
   if(nnfx_entry_window_bars < 1 || nnfx_proximity_atr_mult <= 0.0)
      return false;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp_half_atr_mult <= 0.0)
      return false;
   if(strategy_partial_fraction <= 0.0 || strategy_partial_fraction >= 1.0)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;
   if(!Strategy_ParameterGuard())
      return true;
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }
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

   if(Strategy_HasOpenPosition())
      return false;

   const int cross_dir = Strategy_BaselineRecentCross();
   if(cross_dir == 0)
      return false;
   if(Strategy_BaselineState(1) != cross_dir)
      return false;
   if(!Strategy_ProximityPass(cross_dir))
      return false;
   if(Strategy_C1Signal(1) != cross_dir)
      return false;
   if(nnfx_c2 != NNFX_C2_OFF && Strategy_C2Signal(1) != cross_dir)
      return false;
   if(!Strategy_VolumePass(cross_dir))
      return false;

   req.type = (cross_dir > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr, strategy_sl_atr_mult);
   if(req.sl <= 0.0)
      return false;
   req.tp = 0.0;
   req.reason = (cross_dir > 0) ? "NNFX_CONFIG_LONG" : "NNFX_CONFIG_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;
   const double target_distance = atr * strategy_tp_half_atr_mult;
   if(target_distance <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0 || volume <= 0.0)
         continue;
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      const bool moved_to_be = is_buy ? (current_sl >= open_price - _Point * 0.5)
                                      : (current_sl > 0.0 && current_sl <= open_price + _Point * 0.5);
      if(moved < target_distance || moved_to_be)
         continue;

      const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_fraction);
      if(close_lots > 0.0 && close_lots < volume)
         QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL);
      const double be = QM_TM_NormalizePrice(_Symbol, open_price);
      QM_TM_MoveSL(ticket, be, "nnfx_partial_runner_be");
     }
  }

double Strategy_ChandelierStop(const bool is_buy)
  {
   const int period = MathMax(2, strategy_chandelier_period);
   double extreme = is_buy ? Strategy_High(_Symbol, strategy_timeframe, 1)
                           : Strategy_Low(_Symbol, strategy_timeframe, 1);
   if(extreme <= 0.0)
      return 0.0;
   for(int i = 2; i <= period; ++i)
     {
      const double value = is_buy ? Strategy_High(_Symbol, strategy_timeframe, i)
                                  : Strategy_Low(_Symbol, strategy_timeframe, i);
      if(value <= 0.0)
         return 0.0;
      extreme = is_buy ? MathMax(extreme, value) : MathMin(extreme, value);
     }
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_chandelier_mult <= 0.0)
      return 0.0;
   return is_buy ? (extreme - strategy_chandelier_mult * atr)
                 : (extreme + strategy_chandelier_mult * atr);
  }

bool Strategy_ExitForPosition(const ENUM_POSITION_TYPE ptype)
  {
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double close_price = Strategy_Close(_Symbol, strategy_timeframe, 1);
   if(close_price <= 0.0)
      return false;

   switch(nnfx_exit)
     {
      case NNFX_EXIT_PSAR:
        {
         const double sar = QM_SAR(_Symbol, strategy_timeframe, strategy_psar_step, strategy_psar_maximum, 1);
         if(sar <= 0.0)
            return false;
         return is_buy ? (close_price < sar) : (close_price > sar);
        }
      case NNFX_EXIT_C1_FLIP:
        {
         const int c1 = Strategy_C1Signal(1);
         return is_buy ? (c1 < 0) : (c1 > 0);
        }
      case NNFX_EXIT_KIJUN_RECROSS:
        {
         const double kijun = QM_Ichimoku_KijunSen(_Symbol, strategy_timeframe, 9, MathMax(2, strategy_kijun_period), 52, 1);
         if(kijun <= 0.0)
            return false;
         return is_buy ? (close_price < kijun) : (close_price > kijun);
        }
      case NNFX_EXIT_CHANDELIER:
        {
         const double stop = Strategy_ChandelierStop(is_buy);
         if(stop <= 0.0)
            return false;
         return is_buy ? (close_price < stop) : (close_price > stop);
        }
     }
   return false;
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(Strategy_ExitForPosition(ptype))
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12742\",\"ea\":\"nnfx-configurable-engine\"}");
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
