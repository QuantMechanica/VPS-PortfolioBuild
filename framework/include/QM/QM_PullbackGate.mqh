#ifndef QM_PULLBACK_GATE_MQH
#define QM_PULLBACK_GATE_MQH

#include "QM_OrderTypes.mqh"
#include "QM_Indicators.mqh"

struct QM_PullbackGateResult
  {
   bool valid;
   bool accepted;
   bool extended;
   double price;
   double fair_price;
   double atr;
   double distance_atr;
  };

void QM_PullbackGate_Reset(QM_PullbackGateResult &result)
  {
   result.valid = false;
   result.accepted = false;
   result.extended = false;
   result.price = 0.0;
   result.fair_price = 0.0;
   result.atr = 0.0;
   result.distance_atr = 0.0;
  }

bool QM_PullbackGate_Evaluate(const double price,
                              const double fair_price,
                              const double atr,
                              const QM_OrderType type,
                              const double boundary_atr,
                              const double max_chase_atr,
                              QM_PullbackGateResult &result)
  {
   QM_PullbackGate_Reset(result);
   result.price = price;
   result.fair_price = fair_price;
   result.atr = atr;

   if(price <= 0.0 || fair_price <= 0.0 || atr <= 0.0)
      return false;

   const int direction = QM_OrderTypeIsBuy(type) ? 1 : -1;
   result.distance_atr = ((price - fair_price) / atr) * (double)direction;
   result.valid = true;

   if(max_chase_atr > 0.0 && result.distance_atr > max_chase_atr)
     {
      result.extended = true;
      result.accepted = false;
      return true;
     }

   result.accepted = (result.distance_atr <= boundary_atr);
   return true;
  }

bool QM_PullbackGate_CheckSymbol(const string symbol,
                                 const QM_OrderType type,
                                 const int ema_period,
                                 const int atr_period,
                                 const double boundary_atr,
                                 const double max_chase_atr,
                                 QM_PullbackGateResult &result,
                                 const int shift = 1)
  {
   QM_PullbackGate_Reset(result);
   if(StringLen(symbol) <= 0)
      return false;
   if(!SymbolSelect(symbol, true))
      return false;

   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M30, shift, 1, rates) != 1)
      return false;

   const double fair_price = QM_EMA(symbol, PERIOD_M30, ema_period, shift, PRICE_CLOSE);
   const double atr = QM_ATR(symbol, PERIOD_M30, atr_period, shift);
   return QM_PullbackGate_Evaluate(rates[0].close,
                                   fair_price,
                                   atr,
                                   type,
                                   boundary_atr,
                                   max_chase_atr,
                                   result);
  }

#endif // QM_PULLBACK_GATE_MQH
