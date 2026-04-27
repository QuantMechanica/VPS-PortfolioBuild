#ifndef QM_STOPRULES_MQH
#define QM_STOPRULES_MQH

#include <QM/QM_OrderTypes.mqh>

double QM_StopRulesNormalizePrice(const string symbol, const double price)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

double QM_StopRulesStopFromDistance(const string symbol,
                                    const QM_OrderType side,
                                    const double entry,
                                    const double distance)
  {
   if(entry <= 0.0 || distance <= 0.0)
      return 0.0;

   double stop = QM_OrderTypeIsBuy(side) ? (entry - distance) : (entry + distance);
   return QM_StopRulesNormalizePrice(symbol, stop);
  }

double QM_StopRulesTakeFromDistance(const string symbol,
                                    const QM_OrderType side,
                                    const double entry,
                                    const double distance)
  {
   if(entry <= 0.0 || distance <= 0.0)
      return 0.0;

   double take = QM_OrderTypeIsBuy(side) ? (entry + distance) : (entry - distance);
   return QM_StopRulesNormalizePrice(symbol, take);
  }

double QM_StopRulesPipsToPriceDistance(const string symbol, const int pips)
  {
   if(pips <= 0)
      return 0.0;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

bool QM_StopRulesReadATRValue(const string symbol,
                              const int atr_period,
                              const int shift,
                              double &out_atr)
  {
   out_atr = 0.0;
   if(atr_period <= 0 || shift < 0)
      return false;

   int handle = iATR(symbol, PERIOD_CURRENT, atr_period);
   if(handle == INVALID_HANDLE)
      return false;

   double values[];
   ArraySetAsSeries(values, true);
   int copied = CopyBuffer(handle, 0, shift, 1, values);
   IndicatorRelease(handle);

   if(copied != 1 || values[0] <= 0.0)
      return false;

   out_atr = values[0];
   return true;
  }

bool QM_StopRulesReadStructureExtremes(const string symbol,
                                       const int lookback_bars,
                                       double &out_lowest,
                                       double &out_highest)
  {
   out_lowest = 0.0;
   out_highest = 0.0;
   if(lookback_bars <= 0)
      return false;

   bool have_bar = false;
   for(int shift = 1; shift <= lookback_bars; shift++)
     {
      double bar_low = iLow(symbol, PERIOD_CURRENT, shift);
      double bar_high = iHigh(symbol, PERIOD_CURRENT, shift);
      if(bar_low <= 0.0 || bar_high <= 0.0)
         continue;

      if(!have_bar)
        {
         out_lowest = bar_low;
         out_highest = bar_high;
         have_bar = true;
        }
      else
        {
         if(bar_low < out_lowest)
            out_lowest = bar_low;
         if(bar_high > out_highest)
            out_highest = bar_high;
        }
     }

   return have_bar;
  }

bool QM_StopRulesReadADRValue(const string symbol,
                              const int adr_days,
                              double &out_adr)
  {
   out_adr = 0.0;
   if(adr_days <= 0)
      return false;

   double range_sum = 0.0;
   int samples = 0;
   for(int shift = 1; shift <= adr_days; shift++)
     {
      double day_high = iHigh(symbol, PERIOD_D1, shift);
      double day_low = iLow(symbol, PERIOD_D1, shift);
      if(day_high <= 0.0 || day_low <= 0.0 || day_high <= day_low)
         continue;

      range_sum += (day_high - day_low);
      samples++;
     }

   if(samples <= 0 || range_sum <= 0.0)
      return false;

   out_adr = range_sum / samples;
   return true;
  }

double QM_StopFixedPips(const string sym,
                        const QM_OrderType side,
                        const double entry,
                        const int sl_pips)
  {
   double distance = QM_StopRulesPipsToPriceDistance(sym, sl_pips);
   return QM_StopRulesStopFromDistance(sym, side, entry, distance);
  }

double QM_StopATRFromValue(const string sym,
                           const QM_OrderType side,
                           const double entry,
                           const double atr_value,
                           const double atr_mult)
  {
   if(atr_value <= 0.0 || atr_mult <= 0.0)
      return 0.0;
   return QM_StopRulesStopFromDistance(sym, side, entry, atr_value * atr_mult);
  }

double QM_StopATR(const string sym,
                  const QM_OrderType side,
                  const double entry,
                  const int atr_period,
                  const double atr_mult)
  {
   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(sym, atr_period, 1, atr_value))
      return 0.0;
   return QM_StopATRFromValue(sym, side, entry, atr_value, atr_mult);
  }

double QM_StopStructureFromExtremes(const string sym,
                                    const QM_OrderType side,
                                    const double lowest_price,
                                    const double highest_price)
  {
   if(lowest_price <= 0.0 || highest_price <= 0.0)
      return 0.0;

   double stop = QM_OrderTypeIsBuy(side) ? lowest_price : highest_price;
   return QM_StopRulesNormalizePrice(sym, stop);
  }

double QM_StopStructure(const string sym,
                        const QM_OrderType side,
                        const double entry,
                        const int lookback_bars)
  {
   if(entry <= 0.0)
      return 0.0;

   double lowest = 0.0;
   double highest = 0.0;
   if(!QM_StopRulesReadStructureExtremes(sym, lookback_bars, lowest, highest))
      return 0.0;
   return QM_StopStructureFromExtremes(sym, side, lowest, highest);
  }

double QM_StopVolatilityFromADR(const string sym,
                                const QM_OrderType side,
                                const double entry,
                                const double adr_value,
                                const double adr_mult)
  {
   if(adr_value <= 0.0 || adr_mult <= 0.0)
      return 0.0;
   return QM_StopRulesStopFromDistance(sym, side, entry, adr_value * adr_mult);
  }

double QM_StopVolatility(const string sym,
                         const QM_OrderType side,
                         const double entry,
                         const int adr_days,
                         const double adr_mult)
  {
   double adr_value = 0.0;
   if(!QM_StopRulesReadADRValue(sym, adr_days, adr_value))
      return 0.0;
   return QM_StopVolatilityFromADR(sym, side, entry, adr_value, adr_mult);
  }

double QM_TakeFixedPips(const string sym,
                        const QM_OrderType side,
                        const double entry,
                        const int tp_pips)
  {
   double distance = QM_StopRulesPipsToPriceDistance(sym, tp_pips);
   return QM_StopRulesTakeFromDistance(sym, side, entry, distance);
  }

double QM_TakeRR(const string sym,
                 const QM_OrderType side,
                 const double entry,
                 const double sl_price,
                 const double rr)
  {
   if(entry <= 0.0 || sl_price <= 0.0 || rr <= 0.0)
      return 0.0;

   double risk_distance = MathAbs(entry - sl_price);
   if(risk_distance <= 0.0)
      return 0.0;

   return QM_StopRulesTakeFromDistance(sym, side, entry, risk_distance * rr);
  }

double QM_TakeATRFromValue(const string sym,
                           const QM_OrderType side,
                           const double entry,
                           const double atr_value,
                           const double atr_mult)
  {
   if(atr_value <= 0.0 || atr_mult <= 0.0)
      return 0.0;
   return QM_StopRulesTakeFromDistance(sym, side, entry, atr_value * atr_mult);
  }

double QM_TakeATR(const string sym,
                  const QM_OrderType side,
                  const double entry,
                  const int atr_period,
                  const double atr_mult)
  {
   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(sym, atr_period, 1, atr_value))
      return 0.0;
   return QM_TakeATRFromValue(sym, side, entry, atr_value, atr_mult);
  }

#endif // QM_STOPRULES_MQH
