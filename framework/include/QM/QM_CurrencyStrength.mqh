#ifndef QM_CURRENCY_STRENGTH_MQH
#define QM_CURRENCY_STRENGTH_MQH

#include "QM_SymbolGuard.mqh"

#define QM_CSM_CURRENCY_COUNT 8
#define QM_CSM_PAIR_COUNT 28
#define QM_CSM_CROSSES_PER_CURRENCY 7

string QM_CSM_CCY[QM_CSM_CURRENCY_COUNT] =
  {"USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD"};

string QM_CSM_PAIRS[QM_CSM_PAIR_COUNT] =
  {
   "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX","USDJPY.DWX",
   "USDCHF.DWX","USDCAD.DWX","EURGBP.DWX","EURJPY.DWX","EURCHF.DWX",
   "EURAUD.DWX","EURNZD.DWX","EURCAD.DWX","GBPJPY.DWX","GBPCHF.DWX",
   "GBPAUD.DWX","GBPNZD.DWX","GBPCAD.DWX","AUDJPY.DWX","AUDCHF.DWX",
   "AUDNZD.DWX","AUDCAD.DWX","NZDJPY.DWX","NZDCHF.DWX","NZDCAD.DWX",
   "CADJPY.DWX","CADCHF.DWX","CHFJPY.DWX"
  };

struct QM_CSMReading
  {
   double strength[QM_CSM_CURRENCY_COUNT];
   double normalized[QM_CSM_CURRENCY_COUNT];
   double perf[QM_CSM_PAIR_COUNT];
   int    strong_idx;
   int    weak_idx;
   int    extreme_idx;
   int    extreme_sign;
   double max_abs_strength;
   double gap;
   double zero_sum;
  };

void QM_CSM_Reset(QM_CSMReading &reading)
  {
   for(int i = 0; i < QM_CSM_CURRENCY_COUNT; ++i)
     {
      reading.strength[i] = 0.0;
      reading.normalized[i] = 0.0;
     }
   for(int p = 0; p < QM_CSM_PAIR_COUNT; ++p)
      reading.perf[p] = 0.0;
   reading.strong_idx = -1;
   reading.weak_idx = -1;
   reading.extreme_idx = -1;
   reading.extreme_sign = 0;
   reading.max_abs_strength = 0.0;
   reading.gap = 0.0;
   reading.zero_sum = 0.0;
  }

int QM_CSM_CcyIndex(const string ccy)
  {
   for(int i = 0; i < QM_CSM_CURRENCY_COUNT; ++i)
      if(QM_CSM_CCY[i] == ccy)
         return i;
   return -1;
  }

string QM_CSM_PairBase(const string symbol)
  {
   return StringSubstr(symbol, 0, 3);
  }

string QM_CSM_PairQuote(const string symbol)
  {
   return StringSubstr(symbol, 3, 3);
  }

int QM_CSM_PairSlot(const string symbol)
  {
   for(int i = 0; i < QM_CSM_PAIR_COUNT; ++i)
      if(QM_CSM_PAIRS[i] == symbol)
         return i;
   return -1;
  }

bool QM_CSM_FindPair(const string ccy_a,
                     const string ccy_b,
                     string &out_symbol,
                     bool &out_inverted)
  {
   out_symbol = "";
   out_inverted = false;
   for(int i = 0; i < QM_CSM_PAIR_COUNT; ++i)
     {
      const string symbol = QM_CSM_PAIRS[i];
      const string base = QM_CSM_PairBase(symbol);
      const string quote = QM_CSM_PairQuote(symbol);
      if(base == ccy_a && quote == ccy_b)
        {
         out_symbol = symbol;
         return true;
        }
      if(base == ccy_b && quote == ccy_a)
        {
         out_symbol = symbol;
         out_inverted = true;
         return true;
        }
     }
   return false;
  }

int QM_CSM_Sign(const double value, const double eps = 1e-9)
  {
   if(value > eps)
      return 1;
   if(value < -eps)
      return -1;
   return 0;
  }

bool QM_CSM_BuildFromPerf(const double &perf[], QM_CSMReading &reading)
  {
   if(ArraySize(perf) < QM_CSM_PAIR_COUNT)
      return false;

   QM_CSM_Reset(reading);
   for(int i = 0; i < QM_CSM_PAIR_COUNT; ++i)
     {
      const string symbol = QM_CSM_PAIRS[i];
      const int base_idx = QM_CSM_CcyIndex(QM_CSM_PairBase(symbol));
      const int quote_idx = QM_CSM_CcyIndex(QM_CSM_PairQuote(symbol));
      if(base_idx < 0 || quote_idx < 0)
         return false;

      reading.perf[i] = perf[i];
      reading.strength[base_idx] += perf[i];
      reading.strength[quote_idx] -= perf[i];
     }

   double max_strength = -DBL_MAX;
   double min_strength = DBL_MAX;
   for(int c = 0; c < QM_CSM_CURRENCY_COUNT; ++c)
     {
      reading.zero_sum += reading.strength[c];
      const double abs_strength = MathAbs(reading.strength[c]);
      if(abs_strength > reading.max_abs_strength)
        {
         reading.max_abs_strength = abs_strength;
         reading.extreme_idx = c;
         reading.extreme_sign = QM_CSM_Sign(reading.strength[c]);
        }
      if(reading.strength[c] > max_strength)
        {
         max_strength = reading.strength[c];
         reading.strong_idx = c;
        }
      if(reading.strength[c] < min_strength)
        {
         min_strength = reading.strength[c];
         reading.weak_idx = c;
        }
     }

   if(reading.max_abs_strength > 0.0)
      for(int c = 0; c < QM_CSM_CURRENCY_COUNT; ++c)
         reading.normalized[c] = 100.0 * reading.strength[c] / reading.max_abs_strength;

   reading.gap = max_strength - min_strength;
   return (reading.strong_idx >= 0 && reading.weak_idx >= 0 && reading.extreme_idx >= 0);
  }

bool QM_CSM_ReadPerf(const string symbol,
                     const ENUM_TIMEFRAMES tf,
                     const int shift,
                     double &out_perf)
  {
   out_perf = 0.0;
   if(StringLen(symbol) <= 0)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;
   if(!SymbolSelect(symbol, true))
      return false;

   MqlRates rates[];
   if(CopyRates(symbol, tf, shift, 1, rates) != 1)
      return false;
   if(rates[0].open <= 0.0 || rates[0].close <= 0.0)
      return false;

   out_perf = ((rates[0].close - rates[0].open) / rates[0].open) * 100.0;
   return true;
  }

bool QM_CSM_LoadStrength(const ENUM_TIMEFRAMES tf,
                         QM_CSMReading &reading,
                         const int shift = 0)
  {
   double perf[];
   ArrayResize(perf, QM_CSM_PAIR_COUNT);
   for(int i = 0; i < QM_CSM_PAIR_COUNT; ++i)
     {
      double value = 0.0;
      if(!QM_CSM_ReadPerf(QM_CSM_PAIRS[i], tf, shift, value))
         return false;
      perf[i] = value;
     }
   return QM_CSM_BuildFromPerf(perf, reading);
  }

double QM_CSM_ProbabilityRatio(const QM_CSMReading &reading, const int currency_idx)
  {
   if(currency_idx < 0 || currency_idx >= QM_CSM_CURRENCY_COUNT)
      return 0.0;

   const int direction = QM_CSM_Sign(reading.strength[currency_idx]);
   if(direction == 0)
      return 0.0;

   int seen = 0;
   int agree = 0;
   const string ccy = QM_CSM_CCY[currency_idx];
   for(int i = 0; i < QM_CSM_PAIR_COUNT; ++i)
     {
      const string base = QM_CSM_PairBase(QM_CSM_PAIRS[i]);
      const string quote = QM_CSM_PairQuote(QM_CSM_PAIRS[i]);
      const int perf_sign = QM_CSM_Sign(reading.perf[i]);
      if(base == ccy)
        {
         ++seen;
         if(perf_sign == direction)
            ++agree;
        }
      else if(quote == ccy)
        {
         ++seen;
         if(perf_sign == -direction)
            ++agree;
        }
     }

   if(seen <= 0)
      return 0.0;
   return (double)agree / (double)seen;
  }

bool QM_CSM_IsExhausted(const QM_CSMReading &reading,
                        const int currency_idx,
                        const double threshold_norm)
  {
   if(currency_idx < 0 || currency_idx >= QM_CSM_CURRENCY_COUNT)
      return false;
   if(threshold_norm <= 0.0)
      return true;
   return (MathAbs(reading.normalized[currency_idx]) >= threshold_norm);
  }

#endif // QM_CURRENCY_STRENGTH_MQH
