#ifndef QM_FTMO_GOVERNOR_POLICY_MQH
#define QM_FTMO_GOVERNOR_POLICY_MQH

// Immutable FTMO 2-Step 100k policy contracts shared by the governor and
// every wired client. The exact policy id is selected by a signed manifest;
// arbitrary runtime limits are deliberately unsupported.

const double QM_FTMO_POLICY_VERSION = 2.0;
const int QM_FTMO_CONTRACT_REVISION = 2;

const double QM_FTMO_P1_FINGERPRINT_NUMBER = 1215771617389199.0;
const double QM_FTMO_P2_FINGERPRINT_NUMBER = 2586499533483248.0;
const double QM_FTMO_FUNDED_FINGERPRINT_NUMBER = 1248702263814813.0;

enum QM_FTMO_GovernorReason
  {
   QM_FTMO_GOVERNOR_ALLOW = 0,
   QM_FTMO_GOVERNOR_PERSISTED_TOTAL_LOCK = 1,
   QM_FTMO_GOVERNOR_PERSISTED_DAY_LOCK = 2,
   QM_FTMO_GOVERNOR_TOTAL_FLOOR = 3,
   QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR = 4,
   QM_FTMO_GOVERNOR_TARGET_CAPTURE = 5,
   QM_FTMO_GOVERNOR_TARGET_COMPLETE = 6,
   QM_FTMO_GOVERNOR_ENTRY_HALT = 7,
   QM_FTMO_GOVERNOR_UNKNOWN_EXPOSURE = 8,
   QM_FTMO_GOVERNOR_STATE_INVALID = 9,
   QM_FTMO_GOVERNOR_INVALID_INPUT = 10
  };

struct QM_FTMO_GovernorPolicy
  {
   string policy_id;
   double start_balance;
   bool   target_enabled;
   double target_balance;
   double official_total_floor;
   double official_daily_loss;
   double internal_total_floor;
   double entry_daily_stop;
   double liquidation_daily_stop;
   double profit_room_retention;
   double full_risk_room;
   int    minimum_trading_days;
   double taper_level_1;
   double taper_scale_1;
   double taper_level_2;
   double taper_scale_2;
  };

struct QM_FTMO_GovernorDecision
  {
   int                    prague_day_key;
   double                 official_daily_floor;
   double                 protected_profit_floor;
   double                 liquidation_floor;
   double                 entry_floor;
   double                 risk_scale;
   bool                   entry_allowed;
   bool                   persist_lock;
   bool                   flatten_required;
   bool                   minimum_days_complete;
   bool                   target_reached;
   bool                   target_complete;
   QM_FTMO_GovernorReason reason;
  };

bool QM_FTMO_SelectPolicy(const string policy_id,
                          QM_FTMO_GovernorPolicy &policy)
  {
   ZeroMemory(policy);
   if(policy_id == "FTMO_2S_P1_100K_V2")
     {
      policy.policy_id = policy_id;
      policy.start_balance = 100000.0;
      policy.target_enabled = true;
      policy.target_balance = 110000.0;
      policy.official_total_floor = 90000.0;
      policy.official_daily_loss = 5000.0;
      policy.internal_total_floor = 94000.0;
      policy.entry_daily_stop = 900.0;
      policy.liquidation_daily_stop = 1250.0;
      policy.profit_room_retention = 0.20;
      policy.full_risk_room = 900.0;
      policy.minimum_trading_days = 4;
      policy.taper_level_1 = 107500.0;
      policy.taper_scale_1 = 0.75;
      policy.taper_level_2 = 109000.0;
      policy.taper_scale_2 = 0.50;
      return true;
     }
   if(policy_id == "FTMO_2S_P2_100K_V2")
     {
      policy.policy_id = policy_id;
      policy.start_balance = 100000.0;
      policy.target_enabled = true;
      policy.target_balance = 105000.0;
      policy.official_total_floor = 90000.0;
      policy.official_daily_loss = 5000.0;
      policy.internal_total_floor = 96000.0;
      policy.entry_daily_stop = 650.0;
      policy.liquidation_daily_stop = 900.0;
      policy.profit_room_retention = 0.20;
      policy.full_risk_room = 650.0;
      policy.minimum_trading_days = 4;
      policy.taper_level_1 = 103500.0;
      policy.taper_scale_1 = 0.70;
      policy.taper_level_2 = 104500.0;
      policy.taper_scale_2 = 0.40;
      return true;
     }
   if(policy_id == "FTMO_2S_FUNDED_100K_V2")
     {
      policy.policy_id = policy_id;
      policy.start_balance = 100000.0;
      policy.target_enabled = false;
      policy.target_balance = 0.0;
      policy.official_total_floor = 90000.0;
      policy.official_daily_loss = 5000.0;
      policy.internal_total_floor = 97500.0;
      policy.entry_daily_stop = 350.0;
      policy.liquidation_daily_stop = 500.0;
      policy.profit_room_retention = 0.20;
      policy.full_risk_room = 350.0;
      policy.minimum_trading_days = 0;
      policy.taper_level_1 = 0.0;
      policy.taper_scale_1 = 1.0;
      policy.taper_level_2 = 0.0;
      policy.taper_scale_2 = 1.0;
      return true;
     }
   return false;
  }

void QM_FTMO_DefaultPolicy(QM_FTMO_GovernorPolicy &policy)
  {
   QM_FTMO_SelectPolicy("FTMO_2S_P1_100K_V2",policy);
  }

bool QM_FTMO_Near(const double left,const double right)
  {
   return (MathIsValidNumber(left) && MathIsValidNumber(right) &&
           MathAbs(left-right) <= 0.000000001);
  }

bool QM_FTMO_IsExactPolicy(const QM_FTMO_GovernorPolicy &policy)
  {
   QM_FTMO_GovernorPolicy expected;
   if(!QM_FTMO_SelectPolicy(policy.policy_id,expected))
      return false;
   return (QM_FTMO_Near(policy.start_balance,expected.start_balance) &&
           policy.target_enabled == expected.target_enabled &&
           QM_FTMO_Near(policy.target_balance,expected.target_balance) &&
           QM_FTMO_Near(policy.official_total_floor,expected.official_total_floor) &&
           QM_FTMO_Near(policy.official_daily_loss,expected.official_daily_loss) &&
           QM_FTMO_Near(policy.internal_total_floor,expected.internal_total_floor) &&
           QM_FTMO_Near(policy.entry_daily_stop,expected.entry_daily_stop) &&
           QM_FTMO_Near(policy.liquidation_daily_stop,expected.liquidation_daily_stop) &&
           QM_FTMO_Near(policy.profit_room_retention,expected.profit_room_retention) &&
           QM_FTMO_Near(policy.full_risk_room,expected.full_risk_room) &&
           policy.minimum_trading_days == expected.minimum_trading_days &&
           QM_FTMO_Near(policy.taper_level_1,expected.taper_level_1) &&
           QM_FTMO_Near(policy.taper_scale_1,expected.taper_scale_1) &&
           QM_FTMO_Near(policy.taper_level_2,expected.taper_level_2) &&
           QM_FTMO_Near(policy.taper_scale_2,expected.taper_scale_2));
  }

double QM_FTMO_PolicyFingerprintNumber(const QM_FTMO_GovernorPolicy &policy)
  {
   if(!QM_FTMO_IsExactPolicy(policy))
      return 0.0;
   if(policy.policy_id == "FTMO_2S_P1_100K_V2")
      return QM_FTMO_P1_FINGERPRINT_NUMBER;
   if(policy.policy_id == "FTMO_2S_P2_100K_V2")
      return QM_FTMO_P2_FINGERPRINT_NUMBER;
   if(policy.policy_id == "FTMO_2S_FUNDED_100K_V2")
      return QM_FTMO_FUNDED_FINGERPRINT_NUMBER;
   return 0.0;
  }

bool QM_FTMO_IdentifierValid(const string value)
  {
   const int length=StringLen(value);
   if(length <= 0 || length > 24)
      return false;
   for(int i=0;i<length;++i)
     {
      const ushort code=(ushort)StringGetCharacter(value,i);
      const bool valid=((code >= 'a' && code <= 'z') ||
                        (code >= 'A' && code <= 'Z') ||
                        (code >= '0' && code <= '9') || code == '-' || code == '_');
      if(!valid)
         return false;
     }
   return true;
  }

ulong QM_FTMO_IdentifierHash(const string value)
  {
   ulong hash=5381;
   for(int i=0;i<StringLen(value);++i)
      hash=((hash << 5)+hash) ^ (ulong)StringGetCharacter(value,i);
   return hash;
  }

string QM_FTMO_StateKey(const long account_login,
                        const string challenge_instance_id,
                        const string suffix)
  {
   return StringFormat("QM.F2.%I64d.%I64u.%s",account_login,
                       QM_FTMO_IdentifierHash(challenge_instance_id),suffix);
  }

int QM_FTMO_DaysInMonth(const int year,const int month)
  {
   if(month == 2)
     {
      const bool leap=((year % 4 == 0 && year % 100 != 0) || year % 400 == 0);
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
   parts.year=year;
   parts.mon=month;
   parts.day=QM_FTMO_DaysInMonth(year,month);
   parts.hour=1;
   const datetime last_day=StructToTime(parts);
   MqlDateTime resolved;
   ZeroMemory(resolved);
   if(!TimeToStruct(last_day,resolved))
      return 0;
   parts.day-=resolved.day_of_week;
   return StructToTime(parts);
  }

int QM_FTMO_PragueUTCOffsetSeconds(const datetime timestamp_utc)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(timestamp_utc,parts))
      return 0;
   const datetime spring=QM_FTMO_LastSundayAtOneUTC(parts.year,3);
   const datetime autumn=QM_FTMO_LastSundayAtOneUTC(parts.year,10);
   if(spring <= 0 || autumn <= 0)
      return 0;
   return (timestamp_utc >= spring && timestamp_utc < autumn) ? 7200 : 3600;
  }

int QM_FTMO_PragueDayKey(const datetime timestamp_utc)
  {
   const int offset=QM_FTMO_PragueUTCOffsetSeconds(timestamp_utc);
   if(offset <= 0)
      return 0;
   MqlDateTime local;
   ZeroMemory(local);
   if(!TimeToStruct(timestamp_utc+offset,local))
      return 0;
   return local.year*10000+local.mon*100+local.day;
  }

bool QM_FTMO_Floors(const double midnight_balance,
                     const QM_FTMO_GovernorPolicy &policy,
                     double &official_daily_floor,
                     double &protected_profit_floor,
                     double &liquidation_floor,
                     double &entry_floor)
  {
   if(!QM_FTMO_IsExactPolicy(policy) ||
      !MathIsValidNumber(midnight_balance) || midnight_balance <= 0.0)
      return false;
   official_daily_floor=midnight_balance-policy.official_daily_loss;
   protected_profit_floor=policy.internal_total_floor+
                          policy.profit_room_retention*
                          MathMax(0.0,midnight_balance-policy.internal_total_floor);
   const double internal_daily_floor=midnight_balance-policy.liquidation_daily_stop;
   liquidation_floor=MathMax(policy.official_total_floor,
                     MathMax(policy.internal_total_floor,
                     MathMax(official_daily_floor,
                     MathMax(internal_daily_floor,protected_profit_floor))));
   entry_floor=MathMax(liquidation_floor,
                       midnight_balance-policy.entry_daily_stop);
   return true;
  }

double QM_FTMO_EntryRiskScale(const double equity,
                              const double entry_floor,
                              const QM_FTMO_GovernorPolicy &policy)
  {
   if(!QM_FTMO_IsExactPolicy(policy) || !MathIsValidNumber(equity) ||
      !MathIsValidNumber(entry_floor))
      return 0.0;
   const double room_scale=MathMin(1.0,MathMax(0.0,
                                  (equity-entry_floor)/policy.full_risk_room));
   double target_cap=1.0;
   if(policy.target_enabled)
     {
      if(equity >= policy.target_balance)
         target_cap=0.0;
      else if(equity >= policy.taper_level_2)
         target_cap=policy.taper_scale_2;
      else if(equity >= policy.taper_level_1)
         target_cap=policy.taper_scale_1;
     }
   return MathMin(room_scale,target_cap);
  }

bool QM_FTMO_EvaluateSnapshot(const datetime timestamp_utc,
                              const double balance,
                              const double equity,
                              const double midnight_balance,
                              const int trading_days,
                              const int positions_open,
                              const int orders_pending,
                              const bool persisted_day_lock,
                              const bool persisted_total_lock,
                              const QM_FTMO_GovernorPolicy &policy,
                              QM_FTMO_GovernorDecision &decision)
  {
   ZeroMemory(decision);
   decision.reason=QM_FTMO_GOVERNOR_INVALID_INPUT;
   if(!QM_FTMO_IsExactPolicy(policy) ||
      !MathIsValidNumber(balance) || !MathIsValidNumber(equity) ||
      !MathIsValidNumber(midnight_balance) || balance <= 0.0 || equity <= 0.0 ||
      trading_days < 0 || positions_open < 0 || orders_pending < 0)
      return false;
   decision.prague_day_key=QM_FTMO_PragueDayKey(timestamp_utc);
   if(decision.prague_day_key <= 0 ||
      !QM_FTMO_Floors(midnight_balance,policy,decision.official_daily_floor,
                      decision.protected_profit_floor,decision.liquidation_floor,
                      decision.entry_floor))
      return false;

   decision.risk_scale=QM_FTMO_EntryRiskScale(equity,decision.entry_floor,policy);
   decision.minimum_days_complete=(trading_days >= policy.minimum_trading_days);
   decision.target_reached=(policy.target_enabled && equity >= policy.target_balance);
   decision.target_complete=(policy.target_enabled &&
                             balance >= policy.target_balance &&
                             positions_open == 0 && orders_pending == 0 &&
                             decision.minimum_days_complete);

   // A current total-floor event must escalate through an existing day lock.
   if(persisted_total_lock)
      decision.reason=QM_FTMO_GOVERNOR_PERSISTED_TOTAL_LOCK;
   else if(equity <= policy.internal_total_floor ||
           equity <= policy.official_total_floor)
      decision.reason=QM_FTMO_GOVERNOR_TOTAL_FLOOR;
   else if(persisted_day_lock)
      decision.reason=QM_FTMO_GOVERNOR_PERSISTED_DAY_LOCK;
   else if(equity <= decision.liquidation_floor)
      decision.reason=QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR;
   else if(decision.target_complete)
      decision.reason=QM_FTMO_GOVERNOR_TARGET_COMPLETE;
   else if(decision.target_reached)
      decision.reason=QM_FTMO_GOVERNOR_TARGET_CAPTURE;
   else if(equity <= decision.entry_floor || decision.risk_scale <= 0.0)
      decision.reason=QM_FTMO_GOVERNOR_ENTRY_HALT;
   else
      decision.reason=QM_FTMO_GOVERNOR_ALLOW;

   decision.entry_allowed=(decision.reason == QM_FTMO_GOVERNOR_ALLOW);
   decision.persist_lock=(decision.reason == QM_FTMO_GOVERNOR_TOTAL_FLOOR ||
                          decision.reason == QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR ||
                          decision.reason == QM_FTMO_GOVERNOR_TARGET_CAPTURE ||
                          decision.reason == QM_FTMO_GOVERNOR_TARGET_COMPLETE);
   decision.flatten_required=((decision.reason == QM_FTMO_GOVERNOR_TOTAL_FLOOR ||
                               decision.reason == QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR ||
                               decision.reason == QM_FTMO_GOVERNOR_TARGET_CAPTURE) &&
                              (positions_open > 0 || orders_pending > 0));
   return true;
  }

#endif // QM_FTMO_GOVERNOR_POLICY_MQH
