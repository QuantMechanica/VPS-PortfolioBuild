#ifndef QM_FTMO_GOVERNOR_CLIENT_MQH
#define QM_FTMO_GOVERNOR_CLIENT_MQH

string QM_FTMO_ClientKey(const long account_login,
                         const string policy_id,
                         const string suffix)
  {
   return StringFormat("QM.FTMO.%I64d.%s.%s",account_login,policy_id,suffix);
  }

bool QM_FTMO_ReadGovernorScale(const string policy_id,
                               const double required_policy_version,
                               const int heartbeat_max_age_seconds,
                               double &risk_scale,
                               string &block_reason)
  {
   risk_scale = 0.0;
   block_reason = "GOVERNOR_UNKNOWN";
   if(StringLen(policy_id) <= 0 || heartbeat_max_age_seconds <= 0)
     {
      block_reason = "GOVERNOR_CLIENT_CONFIG_INVALID";
      return false;
     }

   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   const string ready_key = QM_FTMO_ClientKey(login,policy_id,"ready");
   const string version_key = QM_FTMO_ClientKey(login,policy_id,"version");
   const string heartbeat_key = QM_FTMO_ClientKey(login,policy_id,"heartbeat_utc");
   const string lock_key = QM_FTMO_ClientKey(login,policy_id,"entry_lock");
   const string scale_key = QM_FTMO_ClientKey(login,policy_id,"risk_scale");
   if(!GlobalVariableCheck(ready_key) || !GlobalVariableCheck(version_key) ||
      !GlobalVariableCheck(heartbeat_key) || !GlobalVariableCheck(lock_key) ||
      !GlobalVariableCheck(scale_key))
     {
      block_reason = "GOVERNOR_STATE_MISSING";
      return false;
     }
   if(GlobalVariableGet(ready_key) < 0.5)
     {
      block_reason = "GOVERNOR_NOT_READY";
      return false;
     }
   if(MathAbs(GlobalVariableGet(version_key)-required_policy_version) > 0.000001)
     {
      block_reason = "GOVERNOR_POLICY_MISMATCH";
      return false;
     }

   const datetime now_utc = TimeGMT();
   const datetime heartbeat_utc = (datetime)GlobalVariableGet(heartbeat_key);
   const long age = (long)(now_utc-heartbeat_utc);
   if(heartbeat_utc <= 0 || age < 0 || age > heartbeat_max_age_seconds)
     {
      block_reason = "GOVERNOR_HEARTBEAT_STALE";
      return false;
     }
   if(GlobalVariableGet(lock_key) >= 0.5)
     {
      block_reason = "GOVERNOR_ENTRY_LOCKED";
      return false;
     }

   const double published_scale = GlobalVariableGet(scale_key);
   if(!MathIsValidNumber(published_scale) || published_scale <= 0.0 || published_scale > 1.0)
     {
      block_reason = "GOVERNOR_SCALE_INVALID";
      return false;
     }
   risk_scale = published_scale;
   block_reason = "ALLOW";
   return true;
  }

#endif // QM_FTMO_GOVERNOR_CLIENT_MQH
