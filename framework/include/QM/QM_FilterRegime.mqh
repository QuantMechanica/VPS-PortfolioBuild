#ifndef QM_FILTER_REGIME_MQH
#define QM_FILTER_REGIME_MQH

// QuantMechanica V5 filter module: rule-based trend regime.
//
// Purpose: classify the market as bull, bear, or sideways from an N-bar
// closed-price return. This is deterministic and mechanical; it is not an HMM,
// classifier, clustering model, or any other ML regime detector.
//
// Parameters:
//   lookback_bars: closed-bar lookback window.
//   bull_return_pct: minimum positive return for bull state.
//   bear_return_pct: minimum absolute negative return for bear state.

enum QM_RegimeState
  {
   QM_REGIME_UNKNOWN = 0,
   QM_REGIME_BEAR = 1,
   QM_REGIME_SIDEWAYS = 2,
   QM_REGIME_BULL = 3
  };

QM_RegimeState QM_FilterRegimeState(const string symbol,
                                    const ENUM_TIMEFRAMES timeframe,
                                    const int lookback_bars,
                                    const double bull_return_pct,
                                    const double bear_return_pct,
                                    const int shift = 1)
  {
   if(lookback_bars < 2)
      return QM_REGIME_UNKNOWN;

   const double recent_close = iClose(symbol, timeframe, shift);
   const double prior_close = iClose(symbol, timeframe, shift + lookback_bars);
   if(recent_close <= 0.0 || prior_close <= 0.0)
      return QM_REGIME_UNKNOWN;

   const double return_pct = ((recent_close / prior_close) - 1.0) * 100.0;
   if(return_pct >= bull_return_pct)
      return QM_REGIME_BULL;
   if(return_pct <= -MathAbs(bear_return_pct))
      return QM_REGIME_BEAR;
   return QM_REGIME_SIDEWAYS;
  }

bool QM_FilterRegimeAllowsLong(const string symbol,
                               const ENUM_TIMEFRAMES timeframe,
                               const int lookback_bars,
                               const double bull_return_pct,
                               const double bear_return_pct,
                               const bool allow_sideways = false,
                               const int shift = 1)
  {
   const QM_RegimeState state = QM_FilterRegimeState(symbol, timeframe, lookback_bars,
                                                    bull_return_pct, bear_return_pct, shift);
   if(state == QM_REGIME_BULL)
      return true;
   return allow_sideways && state == QM_REGIME_SIDEWAYS;
  }

bool QM_FilterRegimeAllowsShort(const string symbol,
                                const ENUM_TIMEFRAMES timeframe,
                                const int lookback_bars,
                                const double bull_return_pct,
                                const double bear_return_pct,
                                const bool allow_sideways = false,
                                const int shift = 1)
  {
   const QM_RegimeState state = QM_FilterRegimeState(symbol, timeframe, lookback_bars,
                                                    bull_return_pct, bear_return_pct, shift);
   if(state == QM_REGIME_BEAR)
      return true;
   return allow_sideways && state == QM_REGIME_SIDEWAYS;
  }

#endif
