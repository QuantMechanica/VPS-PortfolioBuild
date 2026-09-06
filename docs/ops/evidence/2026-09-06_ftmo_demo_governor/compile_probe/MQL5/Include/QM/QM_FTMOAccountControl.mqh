#ifndef QM_FTMO_ACCOUNT_CONTROL_MQH
#define QM_FTMO_ACCOUNT_CONTROL_MQH

#include <QM/QM_FTMOGovernorPolicy.mqh>

// Account-wide overlays shared by the deployed governor and its native tester
// acceptance harness.  Inputs are observations, not configurable loss limits.
struct QM_FTMO_AccountControlDecision
  {
   QM_FTMO_GovernorDecision risk;
   QM_FTMO_GovernorReason reason;
   bool entry_allowed;
   bool flatten_required;
   bool persist_halt;
  };

bool QM_FTMO_FridayFlatDue(const datetime broker_time,
                           const int friday_close_hour,
                           const int flatten_lead_minutes)
  {
   if(broker_time <= 0 || friday_close_hour < 1 || friday_close_hour > 23 ||
      flatten_lead_minutes < 1 || flatten_lead_minutes > 60)
      return true;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(broker_time,parts))
      return true;
   if(parts.day_of_week == 0 || parts.day_of_week == 6)
      return true;
   if(parts.day_of_week != 5)
      return false;
   const int minute_of_day=parts.hour*60+parts.min;
   return (minute_of_day >= friday_close_hour*60-flatten_lead_minutes);
  }

bool QM_FTMO_EvaluateAccountControl(
   const datetime timestamp_utc,
   const datetime broker_time,
   const double balance,
   const double equity,
   const double midnight_balance,
   const int trading_days,
   const int positions_open,
   const int orders_pending,
   const bool persisted_day_lock,
   const bool persisted_total_lock,
   const bool persisted_halt,
   const bool news_allowed,
   const int friday_close_hour,
   const int flatten_lead_minutes,
   const QM_FTMO_GovernorPolicy &policy,
   QM_FTMO_AccountControlDecision &out)
  {
   ZeroMemory(out);
   out.reason=QM_FTMO_GOVERNOR_INVALID_INPUT;
   if(!QM_FTMO_EvaluateSnapshot(timestamp_utc,balance,equity,midnight_balance,
                                trading_days,positions_open,orders_pending,
                                persisted_day_lock,persisted_total_lock,
                                policy,out.risk))
      return false;

   out.reason=out.risk.reason;
   out.entry_allowed=out.risk.entry_allowed;
   out.flatten_required=out.risk.flatten_required;
   out.persist_halt=(out.risk.reason == QM_FTMO_GOVERNOR_TOTAL_FLOOR ||
                     out.risk.reason == QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR ||
                     out.risk.reason == QM_FTMO_GOVERNOR_TARGET_CAPTURE ||
                     out.risk.reason == QM_FTMO_GOVERNOR_TARGET_COMPLETE);

   // A fresh hard risk event retains its precise reason.  Otherwise a durable
   // halt dominates temporary observations and can never clear itself.
   if(!out.persist_halt && persisted_halt)
      out.reason=QM_FTMO_GOVERNOR_HALT_LATCHED;
   else if(!out.persist_halt &&
           QM_FTMO_FridayFlatDue(broker_time,friday_close_hour,
                                 flatten_lead_minutes))
      out.reason=QM_FTMO_GOVERNOR_WEEKEND_FLAT;
   else if(!out.persist_halt && !news_allowed)
      out.reason=QM_FTMO_GOVERNOR_NEWS_BLACKOUT;

   // The halt-file latch is reserved for a durable account stop.  News is a
   // temporary entry blackout; Friday/weekend requires flattening but may
   // reopen on the next eligible weekday.  Neither creates an irreversible
   // halt file by itself.
   if(out.reason == QM_FTMO_GOVERNOR_HALT_LATCHED)
      out.persist_halt=true;
   if(out.persist_halt)
     {
      out.entry_allowed=false;
      out.flatten_required=(positions_open > 0 || orders_pending > 0);
     }
   else if(out.reason == QM_FTMO_GOVERNOR_WEEKEND_FLAT)
     {
      out.entry_allowed=false;
      out.flatten_required=(positions_open > 0 || orders_pending > 0);
     }
   else if(out.reason == QM_FTMO_GOVERNOR_NEWS_BLACKOUT)
     {
      out.entry_allowed=false;
      out.flatten_required=false;
     }
   return true;
  }

#endif // QM_FTMO_ACCOUNT_CONTROL_MQH
