#ifndef QM_FILTER_VOLATILITY_MQH
#define QM_FILTER_VOLATILITY_MQH

// QuantMechanica V5 filter module: volatility state.
//
// Purpose: classify current volatility as compression, normal, or expansion
// using current ATR versus its own recent average. This is deterministic and
// mechanical; it carries only three parameters.
//
// Parameters:
//   atr_period: ATR calculation period.
//   lookback_bars: number of closed ATR samples used for the baseline average.
//   compression_ratio / expansion_ratio: current ATR divided by baseline ATR.

#include "QM_Indicators.mqh"

enum QM_VolatilityState
  {
   QM_VOL_UNKNOWN = 0,
   QM_VOL_COMPRESSION = 1,
   QM_VOL_NORMAL = 2,
   QM_VOL_EXPANSION = 3
  };

double QM_FilterVolatilityAtrAverage(const string symbol,
                                     const ENUM_TIMEFRAMES timeframe,
                                     const int atr_period,
                                     const int lookback_bars,
                                     const int shift = 1)
  {
   if(atr_period < 1 || lookback_bars < 2)
      return 0.0;

   double total = 0.0;
   int count = 0;
   for(int i = 0; i < lookback_bars; ++i)
     {
      const double value = QM_ATR(symbol, timeframe, atr_period, shift + i);
      if(value <= 0.0)
         continue;
      total += value;
      count++;
     }
   if(count <= 0)
      return 0.0;
   return total / (double)count;
  }

QM_VolatilityState QM_FilterVolatilityState(const string symbol,
                                            const ENUM_TIMEFRAMES timeframe,
                                            const int atr_period,
                                            const int lookback_bars,
                                            const double compression_ratio,
                                            const double expansion_ratio,
                                            const int shift = 1)
  {
   const double current_atr = QM_ATR(symbol, timeframe, atr_period, shift);
   const double baseline_atr = QM_FilterVolatilityAtrAverage(symbol, timeframe,
                                                            atr_period, lookback_bars, shift + 1);
   if(current_atr <= 0.0 || baseline_atr <= 0.0)
      return QM_VOL_UNKNOWN;

   const double ratio = current_atr / baseline_atr;
   if(ratio <= compression_ratio)
      return QM_VOL_COMPRESSION;
   if(ratio >= expansion_ratio)
      return QM_VOL_EXPANSION;
   return QM_VOL_NORMAL;
  }

bool QM_FilterVolatilityAllowsExpansion(const string symbol,
                                        const ENUM_TIMEFRAMES timeframe,
                                        const int atr_period,
                                        const int lookback_bars,
                                        const double compression_ratio,
                                        const double expansion_ratio,
                                        const int shift = 1)
  {
   return QM_FilterVolatilityState(symbol, timeframe, atr_period, lookback_bars,
                                  compression_ratio, expansion_ratio, shift) == QM_VOL_EXPANSION;
  }

bool QM_FilterVolatilityAllowsNonExpansion(const string symbol,
                                           const ENUM_TIMEFRAMES timeframe,
                                           const int atr_period,
                                           const int lookback_bars,
                                           const double compression_ratio,
                                           const double expansion_ratio,
                                           const int shift = 1)
  {
   const QM_VolatilityState state = QM_FilterVolatilityState(symbol, timeframe, atr_period,
                                                            lookback_bars, compression_ratio,
                                                            expansion_ratio, shift);
   return state == QM_VOL_COMPRESSION || state == QM_VOL_NORMAL;
  }

#endif
