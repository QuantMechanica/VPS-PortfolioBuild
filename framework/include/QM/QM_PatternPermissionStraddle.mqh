//+------------------------------------------------------------------+
//| QM_PatternPermissionStraddle.mqh                                  |
//| A1/A2 integration for dual-pending (straddle) sleeves.            |
//|                                                                    |
//| WHY THIS EXISTS                                                    |
//| The generic veto point — between Strategy_EntrySignal() and        |
//| QM_TM_OpenPosition() in the skeleton — is structurally blind for   |
//| the Balke range-breakout family. Those EAs place the BUY_STOP      |
//| *inside* Strategy_EntrySignal and return only the SELL_STOP to the |
//| caller (QM5_13213:309-313 / :517-521, QM5_13301:334-341/:543-547). |
//| A veto after the return can therefore only ever suppress the sell; |
//| allow_buy=false would be a silent no-op, and the fail-closed       |
//| guarantee would not hold for exactly the sleeves we target.        |
//|                                                                    |
//| CONTRACT                                                           |
//|  1. Signal construction is SIDE-EFFECT FREE: it fills both order   |
//|     requests and places nothing.                                   |
//|  2. Permission is evaluated ONCE per reference bar, BEFORE either  |
//|     placement.                                                     |
//|  3. valid=false blocks BOTH legs and leaves the day unmarked, so   |
//|     there is nothing to roll back.                                 |
//|  4. Day/order state is advanced only from an actual placement      |
//|     outcome, never from the intent to place.                       |
//|  5. Permission is NOT latched: when a later reference bar forbids  |
//|     a direction whose stop order is still resting, that order is   |
//|     withdrawn. A veto at trigger time would be useless — broker-   |
//|     side activation of a pending order never calls the EA hook.    |
//|  6. Open positions, management and exits are NEVER suppressed.     |
//+------------------------------------------------------------------+
#property strict

#ifndef __QM_PATTERN_PERMISSION_STRADDLE_MQH__
#define __QM_PATTERN_PERMISSION_STRADDLE_MQH__

#include <QM/QM_PatternPermission.mqh>

//--- What a side-effect-free straddle signal produces.
struct QM_StraddlePlan
  {
   bool              want_buy;
   bool              want_sell;
   QM_EntryRequest   buy_req;
   QM_EntryRequest   sell_req;
  };

//--- Outcome of applying permission to a plan (pure; places nothing).
struct QM_StraddleDecision
  {
   bool              place_buy;
   bool              place_sell;
   bool              permission_valid;
   bool              mark_day_complete;   // only when at least one leg may go
   datetime          reference_bar_time;
   string            reason;
  };

void QM_PPS_InitPlan(QM_StraddlePlan &plan)
  {
   plan.want_buy = false;
   plan.want_sell = false;
  }

//+------------------------------------------------------------------+
//| Pure decision: plan x permission -> what may be placed.           |
//| Deliberately separated from execution so it is unit-testable and  |
//| so no order can be created before the decision exists.            |
//+------------------------------------------------------------------+
QM_StraddleDecision QM_PPS_Decide(const QM_StraddlePlan &plan,
                                  const QM_PermissionResult &perm)
  {
   QM_StraddleDecision d;
   d.reference_bar_time = perm.reference_bar_time;
   d.permission_valid = perm.valid;

   if(!perm.valid)
     {
      // Fail closed: neither leg, and the day stays OPEN so a later bar with
      // valid history can still act. Marking it complete here would silently
      // convert a data gap into a no-trade day.
      d.place_buy = false;
      d.place_sell = false;
      d.mark_day_complete = false;
      d.reason = "permission_invalid:" + perm.reason;
      return d;
     }

   d.place_buy = (plan.want_buy && perm.allow_buy);
   d.place_sell = (plan.want_sell && perm.allow_sell);
   d.mark_day_complete = (d.place_buy || d.place_sell);
   d.reason = perm.reason;
   return d;
  }

//+------------------------------------------------------------------+
//| Withdraw a resting stop order whose direction is no longer        |
//| permitted. Returns the number of orders removed.                  |
//|                                                                    |
//| Only this EA's own pending orders (matched by magic) are touched,  |
//| and only pending ones — an open position is never closed here.     |
//+------------------------------------------------------------------+
int QM_PPS_WithdrawForbiddenPendings(const long magic,
                                     const QM_PermissionResult &perm,
                                     CTrade &trade)
  {
   int removed = 0;
   const int total = OrdersTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      const bool is_buy_side = (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT);
      const bool is_sell_side = (type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_LIMIT);
      if(!is_buy_side && !is_sell_side)
         continue;   // not a pending order

      // Invalid permission withdraws both sides; valid permission withdraws
      // only the side that has become forbidden.
      const bool forbidden = (!perm.valid)
                             || (is_buy_side && !perm.allow_buy)
                             || (is_sell_side && !perm.allow_sell);
      if(!forbidden)
         continue;

      if(trade.OrderDelete(ticket))
         removed++;
     }
   return removed;
  }

#endif // __QM_PATTERN_PERMISSION_STRADDLE_MQH__
//+------------------------------------------------------------------+
