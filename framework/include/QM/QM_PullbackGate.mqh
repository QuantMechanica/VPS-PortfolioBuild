#ifndef QM_PULLBACK_GATE_MQH
#define QM_PULLBACK_GATE_MQH

#include "QM_OrderTypes.mqh"
#include "QM_Indicators.mqh"

struct QM_PullbackGateResult
  {
   bool valid;
   bool accepted;
   bool extended;
   bool boundary_touched;
   bool volume_confirmed;
   double price;
   double fair_price;
   double boundary_price;
   double atr;
   double distance_atr;
   long tick_volume;
   double avg_tick_volume;
  };

void QM_PullbackGate_Reset(QM_PullbackGateResult &result)
  {
   result.valid = false;
   result.accepted = false;
   result.extended = false;
   result.boundary_touched = false;
   result.volume_confirmed = false;
   result.price = 0.0;
   result.fair_price = 0.0;
   result.boundary_price = 0.0;
   result.atr = 0.0;
   result.distance_atr = 0.0;
   result.tick_volume = 0;
   result.avg_tick_volume = 0.0;
  }

double QM_PullbackGate_BoundaryPrice(const double fair_price,
                                     const double atr,
                                     const QM_OrderType type,
                                     const double boundary_atr)
  {
   if(fair_price <= 0.0 || atr <= 0.0)
      return 0.0;
   const double dist = MathMax(0.0, boundary_atr) * atr;
   return QM_OrderTypeIsBuy(type) ? (fair_price - dist) : (fair_price + dist);
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
   result.boundary_price = QM_PullbackGate_BoundaryPrice(fair_price, atr, type, boundary_atr);
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

bool QM_PullbackGate_EvaluateBar(const double high_price,
                                 const double low_price,
                                 const double close_price,
                                 const long tick_volume,
                                 const double avg_tick_volume,
                                 const double fair_price,
                                 const double atr,
                                 const QM_OrderType type,
                                 const double boundary_atr,
                                 const double max_chase_atr,
                                 const double max_tick_volume_ratio,
                                 QM_PullbackGateResult &result)
  {
   QM_PullbackGate_Reset(result);
   result.price = close_price;
   result.fair_price = fair_price;
   result.atr = atr;
   result.tick_volume = tick_volume;
   result.avg_tick_volume = avg_tick_volume;

   if(high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0 ||
      fair_price <= 0.0 || atr <= 0.0)
      return false;

   const bool is_buy = QM_OrderTypeIsBuy(type);
   result.boundary_price = QM_PullbackGate_BoundaryPrice(fair_price, atr, type, boundary_atr);
   if(result.boundary_price <= 0.0)
      return false;

   result.distance_atr = ((close_price - fair_price) / atr) * (is_buy ? 1.0 : -1.0);
   result.valid = true;
   result.boundary_touched = is_buy ? (low_price <= result.boundary_price)
                                    : (high_price >= result.boundary_price);

   if(max_chase_atr > 0.0 && result.distance_atr > max_chase_atr)
     {
      result.extended = true;
      result.accepted = false;
      return true;
     }

   result.volume_confirmed = true;
   if(max_tick_volume_ratio > 0.0 && avg_tick_volume > 0.0)
      result.volume_confirmed = ((double)tick_volume <= avg_tick_volume * max_tick_volume_ratio);

   const bool rejection = is_buy ? (close_price >= result.boundary_price)
                                 : (close_price <= result.boundary_price);
   result.accepted = (result.boundary_touched && rejection && result.volume_confirmed);
   return true;
  }

bool QM_PullbackGate_CheckSymbol(const string symbol,
                                 const QM_OrderType type,
                                 const int ema_period,
                                 const int atr_period,
                                 const double boundary_atr,
                                 const double max_chase_atr,
                                 const int volume_lookback,
                                 const double max_tick_volume_ratio,
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

   double avg_tick_volume = 0.0;
   if(volume_lookback > 0)
     {
      MqlRates history[];
      const int got = CopyRates(symbol, PERIOD_M30, shift + 1, volume_lookback, history);
      if(got > 0)
        {
         double total = 0.0;
         for(int i = 0; i < got; ++i)
            total += (double)history[i].tick_volume;
         avg_tick_volume = total / (double)got;
        }
     }

   const double fair_price = QM_EMA(symbol, PERIOD_M30, ema_period, shift, PRICE_CLOSE);
   const double atr = QM_ATR(symbol, PERIOD_M30, atr_period, shift);
   return QM_PullbackGate_EvaluateBar(rates[0].high,
                                      rates[0].low,
                                      rates[0].close,
                                      rates[0].tick_volume,
                                      avg_tick_volume,
                                      fair_price,
                                      atr,
                                      type,
                                      boundary_atr,
                                      max_chase_atr,
                                      max_tick_volume_ratio,
                                      result);
  }

#endif // QM_PULLBACK_GATE_MQH
