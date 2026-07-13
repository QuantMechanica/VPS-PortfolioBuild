#ifndef QM_FTMO_GOVERNOR_POLICY_MQH
#define QM_FTMO_GOVERNOR_POLICY_MQH

// Pure decision core. Persistence, heartbeat publication, order cancellation,
// and liquidation belong to the account-governor EA and its clients.

enum QM_FTMO_GovernorReason
  {
   QM_FTMO_GOVERNOR_ALLOW = 0,
   QM_FTMO_GOVERNOR_PERSISTED_TOTAL_LOCK = 1,
   QM_FTMO_GOVERNOR_PERSISTED_DAY_LOCK = 2,
   QM_FTMO_GOVERNOR_TOTAL_FLOOR = 3,
   QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR = 4,
   QM_FTMO_GOVERNOR_TARGET_COMPLETE = 5,
   QM_FTMO_GOVERNOR_NO_RISK_ROOM = 6,
   QM_FTMO_GOVERNOR_INVALID_INPUT = 7
  };

struct QM_FTMO_GovernorPolicy
  {
   string policy_id;
   double start_balance;
   double target_balance;
   double total_loss_floor;
   double execution_daily_stop;
   double profit_room_retention;
   double full_risk_room;
   int    minimum_trading_days;
  };

struct QM_FTMO_GovernorDecision
  {
   int                    prague_day_key;
   double                 effective_floor;
   double                 daily_floor;
   double                 protected_profit_floor;
   double                 risk_scale;
   bool                   entry_allowed;
   bool                   persist_lock;
   bool                   flatten_required;
   bool                   target_complete;
   QM_FTMO_GovernorReason reason;
  };

void QM_FTMO_DefaultPolicy(QM_FTMO_GovernorPolicy &policy)
  {
   policy.policy_id = "FTMO_P1_GOVERNOR_V1";
   policy.start_balance = 100000.0;
   policy.target_balance = 110000.0;
   policy.total_loss_floor = 90000.0;
   policy.execution_daily_stop = 4500.0;
   policy.profit_room_retention = 0.20;
   policy.full_risk_room = 4000.0;
   policy.minimum_trading_days = 4;
  }

bool QM_FTMO_PolicyValid(const QM_FTMO_GovernorPolicy &policy)
  {
   if(StringLen(policy.policy_id) <= 0)
      return false;
   if(!MathIsValidNumber(policy.start_balance) ||
      !MathIsValidNumber(policy.target_balance) ||
      !MathIsValidNumber(policy.total_loss_floor) ||
      !MathIsValidNumber(policy.execution_daily_stop) ||
      !MathIsValidNumber(policy.profit_room_retention) ||
      !MathIsValidNumber(policy.full_risk_room))
      return false;
   if(!(policy.total_loss_floor < policy.start_balance &&
        policy.start_balance < policy.target_balance))
      return false;
   if(policy.execution_daily_stop <= 0.0 ||
      policy.execution_daily_stop >= policy.start_balance - policy.total_loss_floor)
      return false;
   if(policy.profit_room_retention < 0.0 || policy.profit_room_retention > 1.0)
      return false;
   return (policy.full_risk_room > 0.0 && policy.minimum_trading_days > 0);
  }

int QM_FTMO_DaysInMonth(const int year,const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0);
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

datetime QM_FTMO_LastSundayAtOneUTC(const int year,const int month)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = year;
   parts.mon = month;
   parts.day = QM_FTMO_DaysInMonth(year,month);
   parts.hour = 1;
   const datetime last_day = StructToTime(parts);
   MqlDateTime resolved;
   ZeroMemory(resolved);
   if(!TimeToStruct(last_day,resolved))
      return 0;
   parts.day -= resolved.day_of_week;
   return StructToTime(parts);
  }

int QM_FTMO_PragueUTCOffsetSeconds(const datetime timestamp_utc)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(timestamp_utc,parts))
      return 0;
   const datetime spring = QM_FTMO_LastSundayAtOneUTC(parts.year,3);
   const datetime autumn = QM_FTMO_LastSundayAtOneUTC(parts.year,10);
   if(spring <= 0 || autumn <= 0)
      return 0;
   return (timestamp_utc >= spring && timestamp_utc < autumn) ? 7200 : 3600;
  }

int QM_FTMO_PragueDayKey(const datetime timestamp_utc)
  {
   const int offset = QM_FTMO_PragueUTCOffsetSeconds(timestamp_utc);
   if(offset <= 0)
      return 0;
   MqlDateTime local;
   ZeroMemory(local);
   if(!TimeToStruct(timestamp_utc + offset,local))
      return 0;
   return local.year * 10000 + local.mon * 100 + local.day;
  }

bool QM_FTMO_DailyFloors(const double midnight_balance,
                         const QM_FTMO_GovernorPolicy &policy,
                         double &daily_floor,
                         double &protected_profit_floor,
                         double &effective_floor)
  {
   if(!QM_FTMO_PolicyValid(policy) || !MathIsValidNumber(midnight_balance))
      return false;
   daily_floor = midnight_balance - policy.execution_daily_stop;
   protected_profit_floor = policy.total_loss_floor +
                            policy.profit_room_retention *
                            MathMax(0.0,midnight_balance - policy.total_loss_floor);
   effective_floor = MathMax(policy.total_loss_floor,
                             MathMax(daily_floor,protected_profit_floor));
   return true;
  }

double QM_FTMO_EntryRiskScale(const double equity,
                              const QM_FTMO_GovernorPolicy &policy)
  {
   if(!QM_FTMO_PolicyValid(policy) || !MathIsValidNumber(equity))
      return 0.0;
   const double raw = (equity - policy.total_loss_floor) / policy.full_risk_room;
   return MathMin(1.0,MathMax(0.0,raw));
  }

bool QM_FTMO_EvaluateSnapshot(const datetime timestamp_utc,
                              const double balance,
                              const double equity,
                              const double midnight_balance,
                              const int trading_days,
                              const int positions_open,
                              const bool persisted_day_lock,
                              const bool persisted_total_lock,
                              const QM_FTMO_GovernorPolicy &policy,
                              QM_FTMO_GovernorDecision &decision)
  {
   ZeroMemory(decision);
   decision.reason = QM_FTMO_GOVERNOR_INVALID_INPUT;
   if(!QM_FTMO_PolicyValid(policy) ||
      !MathIsValidNumber(balance) || !MathIsValidNumber(equity) ||
      !MathIsValidNumber(midnight_balance) || trading_days < 0 ||
      positions_open < 0)
      return false;
   decision.prague_day_key = QM_FTMO_PragueDayKey(timestamp_utc);
   if(decision.prague_day_key <= 0 ||
      !QM_FTMO_DailyFloors(midnight_balance,policy,decision.daily_floor,
                           decision.protected_profit_floor,decision.effective_floor))
      return false;

   decision.risk_scale = QM_FTMO_EntryRiskScale(equity,policy);
   decision.target_complete = (balance >= policy.target_balance &&
                               positions_open == 0 &&
                               trading_days >= policy.minimum_trading_days);

   if(persisted_total_lock)
      decision.reason = QM_FTMO_GOVERNOR_PERSISTED_TOTAL_LOCK;
   else if(persisted_day_lock)
      decision.reason = QM_FTMO_GOVERNOR_PERSISTED_DAY_LOCK;
   else if(equity <= policy.total_loss_floor)
      decision.reason = QM_FTMO_GOVERNOR_TOTAL_FLOOR;
   else if(equity <= decision.effective_floor)
      decision.reason = QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR;
   else if(decision.target_complete)
      decision.reason = QM_FTMO_GOVERNOR_TARGET_COMPLETE;
   else if(decision.risk_scale <= 0.0)
      decision.reason = QM_FTMO_GOVERNOR_NO_RISK_ROOM;
   else
      decision.reason = QM_FTMO_GOVERNOR_ALLOW;

   decision.entry_allowed = (decision.reason == QM_FTMO_GOVERNOR_ALLOW);
   decision.persist_lock = (decision.reason == QM_FTMO_GOVERNOR_TOTAL_FLOOR ||
                            decision.reason == QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR);
   decision.flatten_required = (decision.persist_lock && positions_open > 0);
   return true;
  }

#endif // QM_FTMO_GOVERNOR_POLICY_MQH
