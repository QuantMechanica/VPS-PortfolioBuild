#ifndef QM5_10601_TRENDCONTINUATION_READER_MQH
#define QM5_10601_TRENDCONTINUATION_READER_MQH

int    g_tc_handle = INVALID_HANDLE;
string g_tc_key = "";

bool Strategy_TCEnsureHandle(const string indicator_name,
                             const ENUM_TIMEFRAMES timeframe,
                             const int n_period,
                             const int smooth_method,
                             const int x_period,
                             const int x_phase,
                             const int applied_price)
  {
   const string key = StringFormat("%s|%d|%d|%d|%d|%d|%d",
                                   indicator_name,
                                   (int)timeframe,
                                   n_period,
                                   smooth_method,
                                   x_period,
                                   x_phase,
                                   applied_price);
   if(g_tc_handle != INVALID_HANDLE && g_tc_key == key)
      return true;

   g_tc_handle = iCustom(_Symbol,
                         timeframe,
                         indicator_name,
                         (uint)n_period,
                         smooth_method,
                         (uint)x_period,
                         x_phase,
                         applied_price);
   g_tc_key = key;
   return (g_tc_handle != INVALID_HANDLE);
  }

bool Strategy_TCReadBuffers(const string indicator_name,
                            const ENUM_TIMEFRAMES timeframe,
                            const int n_period,
                            const int smooth_method,
                            const int x_period,
                            const int x_phase,
                            const int applied_price,
                            const int shift,
                            double &plus_value,
                            double &minus_value)
  {
   plus_value = 0.0;
   minus_value = 0.0;

   if(shift < 1)
      return false;
   if(!Strategy_TCEnsureHandle(indicator_name,
                               timeframe,
                               n_period,
                               smooth_method,
                               x_period,
                               x_phase,
                               applied_price))
      return false;

   plus_value = QM_IndicatorReadBuffer(g_tc_handle, 0, shift);
   minus_value = QM_IndicatorReadBuffer(g_tc_handle, 1, shift);
   return (MathIsValidNumber(plus_value) && MathIsValidNumber(minus_value));
  }

#endif
