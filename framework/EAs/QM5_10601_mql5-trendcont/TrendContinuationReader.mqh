#ifndef QM5_10601_TRENDCONTINUATION_READER_MQH
#define QM5_10601_TRENDCONTINUATION_READER_MQH

int Strategy_TCHandle(const string indicator_name,
                      const ENUM_TIMEFRAMES timeframe,
                      const int n_period,
                      const int smooth_method,
                      const int x_period,
                      const int x_phase,
                      const int applied_price)
  {
   const string key = StringFormat("TCUSTOM|%s|%s|%d|%d|%d|%d|%d|%d",
                                   indicator_name,
                                   _Symbol,
                                   (int)timeframe,
                                   n_period,
                                   smooth_method,
                                   x_period,
                                   x_phase,
                                   applied_price);
   int handle = QM_IndicatorsLookup(key);
   if(handle != INVALID_HANDLE)
      return handle;

   handle = iCustom(_Symbol,
                    timeframe,
                    indicator_name,
                    (uint)n_period,
                    smooth_method,
                    (uint)x_period,
                    x_phase,
                    applied_price);
   return QM_IndicatorsRegister(key, handle);
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
   const int handle = Strategy_TCHandle(indicator_name,
                                        timeframe,
                                        n_period,
                                        smooth_method,
                                        x_period,
                                        x_phase,
                                        applied_price);
   if(handle == INVALID_HANDLE)
      return false;

   plus_value = QM_IndicatorReadBuffer(handle, 0, shift);
   minus_value = QM_IndicatorReadBuffer(handle, 1, shift);
   return (MathIsValidNumber(plus_value) && MathIsValidNumber(minus_value));
  }

#endif
