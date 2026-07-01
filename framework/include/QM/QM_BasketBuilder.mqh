#ifndef QM_BASKET_BUILDER_MQH
#define QM_BASKET_BUILDER_MQH

#include "QM_CurrencyStrength.mqh"
#include "QM_OrderTypes.mqh"

#define QM_BASKET_BUILDER_MAX_LEGS 7
#define QM_BASKET_MODE_C_CLUSTER 2
#define QM_BASKET_MODE_B_SQUARE 1

struct QM_BasketLeg
  {
   string symbol;
   QM_OrderType type;
   int symbol_slot;
  };

struct QM_BasketPlan
  {
   int mode;
   int currency_idx;
   int direction;
   int leg_count;
   QM_BasketLeg legs[QM_BASKET_BUILDER_MAX_LEGS];
  };

void QM_BasketBuilder_Reset(QM_BasketPlan &plan)
  {
   plan.mode = 0;
   plan.currency_idx = -1;
   plan.direction = 0;
   plan.leg_count = 0;
   for(int i = 0; i < QM_BASKET_BUILDER_MAX_LEGS; ++i)
     {
      plan.legs[i].symbol = "";
      plan.legs[i].type = QM_BUY;
      plan.legs[i].symbol_slot = -1;
     }
  }

bool QM_BasketBuilder_AddLeg(QM_BasketPlan &plan,
                             const string symbol,
                             const QM_OrderType type)
  {
   if(plan.leg_count >= QM_BASKET_BUILDER_MAX_LEGS)
      return false;
   const int slot = QM_CSM_PairSlot(symbol);
   if(slot < 0)
      return false;

   plan.legs[plan.leg_count].symbol = symbol;
   plan.legs[plan.leg_count].type = type;
   plan.legs[plan.leg_count].symbol_slot = slot;
   plan.leg_count++;
   return true;
  }

bool QM_BasketBuilder_ModeC(const int currency_idx,
                            const int direction,
                            QM_BasketPlan &plan)
  {
   QM_BasketBuilder_Reset(plan);
   if(currency_idx < 0 || currency_idx >= QM_CSM_CURRENCY_COUNT)
      return false;
   if(direction != 1 && direction != -1)
      return false;

   plan.mode = QM_BASKET_MODE_C_CLUSTER;
   plan.currency_idx = currency_idx;
   plan.direction = direction;
   const string ccy = QM_CSM_CCY[currency_idx];

   for(int i = 0; i < QM_CSM_PAIR_COUNT; ++i)
     {
      const string symbol = QM_CSM_PAIRS[i];
      const string base = QM_CSM_PairBase(symbol);
      const string quote = QM_CSM_PairQuote(symbol);
      if(base == ccy)
        {
         const QM_OrderType type = (direction > 0) ? QM_BUY : QM_SELL;
         if(!QM_BasketBuilder_AddLeg(plan, symbol, type))
            return false;
        }
      else if(quote == ccy)
        {
         const QM_OrderType type = (direction > 0) ? QM_SELL : QM_BUY;
         if(!QM_BasketBuilder_AddLeg(plan, symbol, type))
            return false;
        }
     }

   return (plan.leg_count == QM_BASKET_BUILDER_MAX_LEGS);
  }

bool QM_BasketBuilder_ModeB_Square(const string base_ccy,
                                   const string quote_ccy,
                                   const int direction,
                                   QM_BasketPlan &plan)
  {
   QM_BasketBuilder_Reset(plan);
   if(direction != 1 && direction != -1)
      return false;

   string symbol = "";
   bool inverted = false;
   plan.mode = QM_BASKET_MODE_B_SQUARE;
   plan.direction = direction;

   string legs_base[4] = {"EUR", "EUR", base_ccy, "USD"};
   string legs_quote[4] = {base_ccy, quote_ccy, "USD", quote_ccy};
   int desired_side[4] = {1, -1, -1, -1};
   for(int i = 0; i < 4; ++i)
     {
      if(!QM_CSM_FindPair(legs_base[i], legs_quote[i], symbol, inverted))
         return false;
      int side = desired_side[i] * direction;
      if(inverted)
         side = -side;
      if(!QM_BasketBuilder_AddLeg(plan, symbol, side > 0 ? QM_BUY : QM_SELL))
         return false;
     }

   return (plan.leg_count == 4);
  }

bool QM_BasketBuilder_HasLeg(const QM_BasketPlan &plan,
                             const string symbol,
                             const QM_OrderType type)
  {
   for(int i = 0; i < plan.leg_count; ++i)
      if(plan.legs[i].symbol == symbol && plan.legs[i].type == type)
         return true;
   return false;
  }

#endif // QM_BASKET_BUILDER_MQH
