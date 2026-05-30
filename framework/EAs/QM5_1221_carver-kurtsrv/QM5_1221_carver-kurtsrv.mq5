#property strict
#property version   "5.0"
#property description "QM5_1221 Carver relative-value kurtosis-conditioned skew"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1221;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.50;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_days       = 180;
input int    strategy_smooth_days         = 45;
input int    strategy_robust_vol_days     = 252;
input double strategy_forecast_scalar     = 1.0;
input double strategy_forecast_cap        = 20.0;
input double strategy_entry_forecast      = 2.0;
input int    strategy_min_group_symbols   = 4;
input int    strategy_max_slots_per_side  = 2;
input int    strategy_atr_period          = 20;
input double strategy_atr_stop_mult       = 3.0;
input int    strategy_spread_median_days  = 20;
input double strategy_spread_mult         = 2.0;
input bool   strategy_allow_fx_group      = true;
input bool   strategy_allow_index_group   = true;

#define QM5_1221_SYMBOL_COUNT 11
#define QM5_1221_INDEX_GROUP  1
#define QM5_1221_FX_GROUP     2

string g_symbols[QM5_1221_SYMBOL_COUNT] =
  {
   "GER40.DWX", "NDX.DWX", "WS30.DWX", "UK100.DWX", "FRA40.DWX",
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX", "USDCAD.DWX", "USDCHF.DWX"
  };

int g_groups[QM5_1221_SYMBOL_COUNT] =
  {
   QM5_1221_INDEX_GROUP, QM5_1221_INDEX_GROUP, QM5_1221_INDEX_GROUP,
   QM5_1221_INDEX_GROUP, QM5_1221_INDEX_GROUP,
   QM5_1221_FX_GROUP, QM5_1221_FX_GROUP, QM5_1221_FX_GROUP,
   QM5_1221_FX_GROUP, QM5_1221_FX_GROUP, QM5_1221_FX_GROUP
  };

datetime g_last_entry_bar = 0;

bool Strategy_IsFinite(const double value)
  {
   return (value == value && value != DBL_MAX && value != -DBL_MAX && MathIsValidNumber(value));
  }

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   return PERIOD_D1;
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1221_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentGroup()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return 0;
   return g_groups[idx];
  }

bool Strategy_GroupEnabled(const int group_id)
  {
   if(group_id == QM5_1221_INDEX_GROUP)
      return strategy_allow_index_group;
   if(group_id == QM5_1221_FX_GROUP)
      return strategy_allow_fx_group;
   return false;
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   double copy[];
   ArrayResize(copy, count);
   for(int i = 0; i < count; ++i)
      copy[i] = values[i];
   ArraySort(copy);

   if((count % 2) == 1)
      return copy[count / 2];
   return 0.5 * (copy[(count / 2) - 1] + copy[count / 2]);
  }

bool Strategy_EnsureSymbol(const string symbol)
  {
   if(symbol == _Symbol)
      return true;
   return SymbolSelect(symbol, true);
  }

bool Strategy_LogReturn(const string symbol, const int shift, double &ret)
  {
   ret = 0.0;
   const double c0 = iClose(symbol, PERIOD_D1, shift);
   const double c1 = iClose(symbol, PERIOD_D1, shift + 1);
   if(c0 <= 0.0 || c1 <= 0.0)
      return false;
   ret = MathLog(c0 / c1);
   return Strategy_IsFinite(ret);
  }

bool Strategy_Moments(const string symbol, const int start_shift, const int lookback, double &skew, double &excess_kurtosis)
  {
   skew = 0.0;
   excess_kurtosis = 0.0;
   if(lookback < 30 || !Strategy_EnsureSymbol(symbol))
      return false;
   if(iBars(symbol, PERIOD_D1) < start_shift + lookback + 1)
      return false;

   double returns[];
   ArrayResize(returns, lookback);
   double sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      double r = 0.0;
      if(!Strategy_LogReturn(symbol, start_shift + i, r))
         return false;
      returns[i] = r;
      sum += r;
     }

   const double mean = sum / (double)lookback;
   double m2 = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double d = returns[i] - mean;
      m2 += d * d;
     }
   m2 /= (double)lookback;
   if(m2 <= 0.0)
      return false;

   const double stdev = MathSqrt(m2);
   if(stdev <= 0.0)
      return false;

   double m3 = 0.0;
   double m4 = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double z = (returns[i] - mean) / stdev;
      const double z2 = z * z;
      m3 += z2 * z;
      m4 += z2 * z2;
     }

   skew = m3 / (double)lookback;
   excess_kurtosis = (m4 / (double)lookback) - 3.0;
   return Strategy_IsFinite(skew) && Strategy_IsFinite(excess_kurtosis);
  }

int Strategy_GroupMoments(const int group_id, const int start_shift, double &skews[], double &kurts[], string &symbols[])
  {
   ArrayResize(skews, 0);
   ArrayResize(kurts, 0);
   ArrayResize(symbols, 0);
   int count = 0;
   for(int i = 0; i < QM5_1221_SYMBOL_COUNT; ++i)
     {
      if(g_groups[i] != group_id)
         continue;
      double skew = 0.0;
      double kurt = 0.0;
      if(!Strategy_Moments(g_symbols[i], start_shift, strategy_lookback_days, skew, kurt))
         continue;
      ArrayResize(skews, count + 1);
      ArrayResize(kurts, count + 1);
      ArrayResize(symbols, count + 1);
      skews[count] = skew;
      kurts[count] = kurt;
      symbols[count] = g_symbols[i];
      ++count;
     }
   return count;
  }

bool Strategy_RVValues(const string symbol, const int group_id, const int start_shift, double &rv_kurt, double &rv_skew, int &valid_count)
  {
   rv_kurt = 0.0;
   rv_skew = 0.0;
   valid_count = 0;

   double skews[];
   double kurts[];
   string symbols[];
   const int count = Strategy_GroupMoments(group_id, start_shift, skews, kurts, symbols);
   valid_count = count;
   if(count < strategy_min_group_symbols)
      return false;

   double sum_skew = 0.0;
   double sum_kurt = 0.0;
   for(int i = 0; i < count; ++i)
     {
      sum_skew += skews[i];
      sum_kurt += kurts[i];
     }

   const double avg_skew = sum_skew / (double)count;
   const double avg_kurt = sum_kurt / (double)count;
   for(int i = 0; i < count; ++i)
      if(symbols[i] == symbol)
        {
         rv_skew = skews[i] - avg_skew;
         rv_kurt = kurts[i] - avg_kurt;
         return Strategy_IsFinite(rv_skew) && Strategy_IsFinite(rv_kurt);
        }

   return false;
  }

bool Strategy_RobustVolKurt(const string symbol, const int group_id, const int start_shift, double &vol)
  {
   vol = 0.0;
   if(strategy_robust_vol_days < 20)
      return false;

   double values[];
   ArrayResize(values, strategy_robust_vol_days);
   int count = 0;
   for(int i = 0; i < strategy_robust_vol_days; ++i)
     {
      double rv_kurt = 0.0;
      double rv_skew = 0.0;
      int valid_count = 0;
      if(!Strategy_RVValues(symbol, group_id, start_shift + i, rv_kurt, rv_skew, valid_count))
         continue;
      values[count] = rv_kurt;
      ++count;
     }

   if(count < MathMax(20, strategy_robust_vol_days / 2))
      return false;
   ArrayResize(values, count);
   const double median = Strategy_Median(values, count);

   double deviations[];
   ArrayResize(deviations, count);
   for(int i = 0; i < count; ++i)
      deviations[i] = MathAbs(values[i] - median);

   vol = Strategy_Median(deviations, count);
   return (vol > 0.0 && Strategy_IsFinite(vol));
  }

bool Strategy_RawFactor(const string symbol, const int group_id, const int start_shift, double &factor, int &valid_count)
  {
   factor = 0.0;
   valid_count = 0;
   double rv_kurt = 0.0;
   double rv_skew = 0.0;
   if(!Strategy_RVValues(symbol, group_id, start_shift, rv_kurt, rv_skew, valid_count))
      return false;

   double vol = 0.0;
   if(!Strategy_RobustVolKurt(symbol, group_id, start_shift, vol))
      return false;

   const double skew_sign = (rv_skew >= 0.0) ? 1.0 : -1.0;
   factor = (rv_kurt / vol) * skew_sign;
   return Strategy_IsFinite(factor);
  }

bool Strategy_ForecastFor(const string symbol, const int group_id, double &forecast, int &valid_count)
  {
   forecast = 0.0;
   valid_count = 0;
   if(strategy_smooth_days < 1 || strategy_forecast_scalar <= 0.0)
      return false;

   const int smooth = MathMin(strategy_smooth_days, 256);
   const double alpha = 2.0 / ((double)smooth + 1.0);
   bool has_ema = false;
   double ema = 0.0;

   for(int offset = smooth; offset >= 1; --offset)
     {
      double raw = 0.0;
      int count = 0;
      if(!Strategy_RawFactor(symbol, group_id, offset, raw, count))
         continue;
      valid_count = count;
      if(!has_ema)
        {
         ema = raw;
         has_ema = true;
        }
      else
         ema = alpha * raw + (1.0 - alpha) * ema;
     }

   if(!has_ema)
      return false;

   forecast = ema * strategy_forecast_scalar;
   if(forecast > strategy_forecast_cap)
      forecast = strategy_forecast_cap;
   if(forecast < -strategy_forecast_cap)
      forecast = -strategy_forecast_cap;
   return Strategy_IsFinite(forecast);
  }

int Strategy_SideRank(const string symbol, const int group_id, double &own_forecast, int &valid_count)
  {
   own_forecast = 0.0;
   valid_count = 0;
   double forecasts[];
   string symbols[];
   int count = 0;
   for(int i = 0; i < QM5_1221_SYMBOL_COUNT; ++i)
     {
      if(g_groups[i] != group_id)
         continue;
      double forecast = 0.0;
      int group_count = 0;
      if(!Strategy_ForecastFor(g_symbols[i], group_id, forecast, group_count))
         continue;
      ArrayResize(forecasts, count + 1);
      ArrayResize(symbols, count + 1);
      forecasts[count] = forecast;
      symbols[count] = g_symbols[i];
      valid_count = group_count;
      ++count;
     }

   if(count < strategy_min_group_symbols)
      return 999;

   bool found = false;
   for(int i = 0; i < count; ++i)
      if(symbols[i] == symbol)
        {
         own_forecast = forecasts[i];
         found = true;
        }
   if(!found || MathAbs(own_forecast) <= 0.0)
      return 999;

   int rank = 1;
   const int side = (own_forecast > 0.0) ? 1 : -1;
   for(int i = 0; i < count; ++i)
     {
      if(symbols[i] == symbol)
         continue;
      const int other_side = (forecasts[i] > 0.0) ? 1 : ((forecasts[i] < 0.0) ? -1 : 0);
      if(other_side == side && MathAbs(forecasts[i]) > MathAbs(own_forecast))
         ++rank;
     }

   return rank;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

bool Strategy_SpreadAllowed()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_mult <= 0.0)
      return true;

   MqlRates rates[];
   const int days = MathMin(strategy_spread_median_days, 64);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, days, rates); // perf-allowed: spread gate is reached only after the D1 signal-bar duplicate guard.
   if(copied < 3)
      return true;

   int spreads[];
   ArrayResize(spreads, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
      if(rates[i].spread > 0)
        {
         spreads[count] = rates[i].spread;
         ++count;
        }

   if(count < 3)
      return true;
   ArrayResize(spreads, count);
   ArraySort(spreads);
   const double median = ((count % 2) == 1)
                         ? (double)spreads[count / 2]
                         : 0.5 * ((double)spreads[(count / 2) - 1] + (double)spreads[count / 2]);
   const double current = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (median <= 0.0 || current <= strategy_spread_mult * median);
  }

bool Strategy_StopDistanceAllowed(const QM_OrderType type, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(type == QM_BUY && sl >= entry)
      return false;
   if(type == QM_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0 || idx != qm_magic_slot_offset)
      return true;
   const int group_id = Strategy_CurrentGroup();
   if(!Strategy_GroupEnabled(group_id))
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(strategy_lookback_days < 30 || strategy_smooth_days < 1 || strategy_robust_vol_days < 20)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_forecast_scalar <= 0.0 || strategy_forecast_cap <= 0.0)
      return true;
   if(strategy_min_group_symbols < 2 || strategy_max_slots_per_side < 1)
      return true;
   if(strategy_atr_period < 1 || strategy_atr_stop_mult <= 0.0)
      return true;
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
   if(!Strategy_SpreadAllowed())
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_entry_bar)
      return false;

   const int group_id = Strategy_CurrentGroup();
   double forecast = 0.0;
   int valid_count = 0;
   const int rank = Strategy_SideRank(_Symbol, group_id, forecast, valid_count);
   if(valid_count < strategy_min_group_symbols || rank > strategy_max_slots_per_side)
      return false;

   const bool long_signal = (forecast > strategy_entry_forecast);
   const bool short_signal = (forecast < -strategy_entry_forecast);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = NormalizeDouble(side == QM_BUY
                                     ? entry - atr * strategy_atr_stop_mult
                                     : entry + atr * strategy_atr_stop_mult,
                                     _Digits);
   if(!Strategy_StopDistanceAllowed(side, entry, sl))
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.reason = long_signal ? "CARVER_KURTSRV_LONG" : "CARVER_KURTSRV_SHORT";
   g_last_entry_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int group_id = Strategy_CurrentGroup();
   double forecast = 0.0;
   int valid_count = 0;
   if(!Strategy_ForecastFor(_Symbol, group_id, forecast, valid_count))
      return false;
   if(valid_count < strategy_min_group_symbols)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && forecast < 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && forecast > 0.0)
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
   for(int i = 0; i < QM5_1221_SYMBOL_COUNT; ++i)
      Strategy_EnsureSymbol(g_symbols[i]);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1221\",\"ea\":\"carver-kurtsrv\"}");
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
