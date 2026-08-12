#ifndef QM_FTMO_GOVERNOR_CLIENT_MQH
#define QM_FTMO_GOVERNOR_CLIENT_MQH

#include <QM/QM_FTMOGovernorPolicy.mqh>

bool QM_FTMO_ClientGenerationValid(const double value)
  {
   if(!MathIsValidNumber(value) || value < 2.0 || value != MathFloor(value))
      return false;
   return (((long)value % 2) == 0);
  }

bool QM_FTMO_ReadGovernorScale(const string policy_id,
                               const string challenge_instance_id,
                               const int heartbeat_max_age_seconds,
                               double &risk_scale,
                               string &block_reason)
  {
   risk_scale=0.0;
   block_reason="GOVERNOR_UNKNOWN";
   QM_FTMO_GovernorPolicy expected_policy;
   if(!QM_FTMO_SelectPolicy(policy_id,expected_policy) ||
      !QM_FTMO_IsExactPolicy(expected_policy) ||
      !QM_FTMO_IdentifierValid(challenge_instance_id) ||
      heartbeat_max_age_seconds <= 0 || heartbeat_max_age_seconds > 5)
     {
      block_reason="GOVERNOR_CLIENT_CONFIG_INVALID";
      return false;
     }

   const long login=AccountInfoInteger(ACCOUNT_LOGIN);
   const string generation_key=QM_FTMO_StateKey(login,challenge_instance_id,"generation");
   const string ready_key=QM_FTMO_StateKey(login,challenge_instance_id,"ready");
   const string version_key=QM_FTMO_StateKey(login,challenge_instance_id,"version");
   const string fingerprint_key=QM_FTMO_StateKey(login,challenge_instance_id,"fingerprint");
   const string heartbeat_key=QM_FTMO_StateKey(login,challenge_instance_id,"heartbeat_utc");
   const string day_key=QM_FTMO_StateKey(login,challenge_instance_id,"day_key");
   const string lock_key=QM_FTMO_StateKey(login,challenge_instance_id,"entry_lock");
   const string scale_key=QM_FTMO_StateKey(login,challenge_instance_id,"risk_scale");
   if(!GlobalVariableCheck(generation_key) || !GlobalVariableCheck(ready_key) ||
      !GlobalVariableCheck(version_key) || !GlobalVariableCheck(fingerprint_key) ||
      !GlobalVariableCheck(heartbeat_key) || !GlobalVariableCheck(day_key) ||
      !GlobalVariableCheck(lock_key) ||
      !GlobalVariableCheck(scale_key))
     {
      block_reason="GOVERNOR_STATE_MISSING";
      return false;
     }

   const double generation_before=GlobalVariableGet(generation_key);
   if(!QM_FTMO_ClientGenerationValid(generation_before))
     {
      block_reason="GOVERNOR_SNAPSHOT_IN_PROGRESS";
      return false;
     }
   const double ready_before=GlobalVariableGet(ready_key);
   const double version=GlobalVariableGet(version_key);
   const double fingerprint=GlobalVariableGet(fingerprint_key);
   const datetime heartbeat_utc=(datetime)GlobalVariableGet(heartbeat_key);
   const double published_day_key=GlobalVariableGet(day_key);
   const double entry_lock=GlobalVariableGet(lock_key);
   const double published_scale=GlobalVariableGet(scale_key);
   // The generation read must be the final read. If a publisher starts or
   // completes after ready_after, the final generation observes odd/new state
   // and the stale payload cannot be accepted.
   const double ready_after=GlobalVariableGet(ready_key);
   const double generation_after=GlobalVariableGet(generation_key);

   if(generation_before != generation_after ||
      !QM_FTMO_ClientGenerationValid(generation_after) ||
      ready_before != ready_after)
     {
      block_reason="GOVERNOR_SNAPSHOT_CHANGED";
      return false;
     }
   if(!MathIsValidNumber(ready_before) || !MathIsValidNumber(ready_after) ||
      ready_before != 1.0 || ready_after != 1.0)
     {
      block_reason="GOVERNOR_NOT_READY";
      return false;
     }
   if(!QM_FTMO_Near(version,QM_FTMO_POLICY_VERSION) ||
      fingerprint != QM_FTMO_PolicyFingerprintNumber(expected_policy))
     {
      block_reason="GOVERNOR_POLICY_MISMATCH";
      return false;
     }

   const datetime now_utc=TimeGMT();
   const long age=(long)(now_utc-heartbeat_utc);
   if(heartbeat_utc <= 0 || age < 0 || age > heartbeat_max_age_seconds)
     {
      block_reason="GOVERNOR_HEARTBEAT_STALE";
      return false;
     }
   if(!MathIsValidNumber(published_day_key) ||
      published_day_key != (double)QM_FTMO_PragueDayKey(now_utc))
     {
      block_reason="GOVERNOR_DAY_MISMATCH";
      return false;
     }
   if(!MathIsValidNumber(entry_lock) || entry_lock != 0.0)
     {
      block_reason="GOVERNOR_ENTRY_LOCKED";
      return false;
     }
   if(!MathIsValidNumber(published_scale) || published_scale <= 0.0 ||
      published_scale > 1.0)
     {
      block_reason="GOVERNOR_SCALE_INVALID";
      return false;
     }

   risk_scale=published_scale;
   block_reason="ALLOW";
   return true;
  }

#endif // QM_FTMO_GOVERNOR_CLIENT_MQH
