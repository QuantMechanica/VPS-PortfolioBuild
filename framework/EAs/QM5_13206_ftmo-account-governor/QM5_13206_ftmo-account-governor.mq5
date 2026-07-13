#property strict
#property version "1.1"
#property description "FTMO Phase-1 account governor with challenge-bound persistent state"

#include <Trade/Trade.mqh>
#include <QM/QM_FTMOGovernorPolicy.mqh>

input group "Deployment Identity"
input long     expected_account_login              = 0;
input string   challenge_id                        = "";
input datetime challenge_start_utc                 = 0;
input string   allowed_magics_csv                  = "";
input bool     governor_dry_run                    = true;

input group "One-shot Explicit State Bootstrap"
input bool   challenge_state_bootstrap             = false;
input bool   bootstrap_no_prior_breach_confirmed   = false;
input int    bootstrap_prague_day_key              = 0;
input double bootstrap_midnight_balance            = 0.0;
input int    bootstrap_trading_days                = 0;
input int    bootstrap_last_trade_day_key          = 0;

input group "Execution"
input int governor_timer_ms                        = 200;
input int close_deviation_points                   = 50;

const int QM_FTMO_LEASE_TIMEOUT_SECONDS=5;
const int QM_FTMO_DAY_TRANSITION_MAX_GAP_SECONDS=5;

CTrade g_trade;
QM_FTMO_GovernorPolicy g_policy;
long g_login=0;
long g_allowed_magics[];
double g_instance_token=0.0;
bool g_has_lease=false;
bool g_state_loaded=false;
datetime g_last_evaluation_utc=0;
int g_day_key=0;
double g_midnight_balance=0.0;
int g_trading_days=0;
int g_last_trade_day_key=0;
bool g_day_lock=true;
bool g_total_lock=true;
bool g_target_lock=true;
bool g_target_complete=false;
bool g_flatten_pending=false;

string StateKey(const string suffix)
  {
   return QM_FTMO_StateKey(g_login,challenge_id,suffix);
  }

bool StateExists(const string suffix)
  {
   return GlobalVariableCheck(StateKey(suffix));
  }

bool StateWrite(const string suffix,const double value)
  {
   ResetLastError();
   const datetime updated=GlobalVariableSet(StateKey(suffix),value);
   if(updated == 0)
     {
      PrintFormat("FTMO_GOVERNOR_STATE_WRITE_FAILED key=%s error=%d",suffix,GetLastError());
      return false;
     }
   return true;
  }

bool StateReadRequired(const string suffix,double &value)
  {
   if(!StateExists(suffix))
      return false;
   ResetLastError();
   value=GlobalVariableGet(StateKey(suffix));
   return (GetLastError() == 0 && MathIsValidNumber(value));
  }

bool StateReadBool(const string suffix,bool &value)
  {
   double raw=0.0;
   if(!StateReadRequired(suffix,raw) || (raw != 0.0 && raw != 1.0))
      return false;
   value=(raw >= 0.5);
   return true;
  }

bool MagicAllowed(const long magic)
  {
   for(int i=0;i<ArraySize(g_allowed_magics);++i)
      if(g_allowed_magics[i] == magic)
         return true;
   return false;
  }

bool DecimalDigitsOnly(const string value)
  {
   if(StringLen(value) <= 0)
      return false;
   for(int i=0;i<StringLen(value);++i)
     {
      const ushort code=(ushort)StringGetCharacter(value,i);
      if(code < '0' || code > '9')
         return false;
     }
   return true;
  }

bool ParseAllowedMagics()
  {
   ArrayResize(g_allowed_magics,0);
   string values[];
   const ushort comma=(ushort)StringGetCharacter(",",0);
   const int count=StringSplit(allowed_magics_csv,comma,values);
   for(int i=0;i<count;++i)
     {
      string value=values[i];
      StringTrimLeft(value);
      StringTrimRight(value);
      if(!DecimalDigitsOnly(value))
         return false;
      const long magic=(long)StringToInteger(value);
      if(magic <= 0 || MagicAllowed(magic))
         return false;
      const int size=ArraySize(g_allowed_magics);
      if(ArrayResize(g_allowed_magics,size+1) != size+1)
         return false;
      g_allowed_magics[size]=magic;
     }
   return (ArraySize(g_allowed_magics) > 0);
  }

double MakeInstanceToken()
  {
   const string identity=StringFormat("%I64d_%I64d",(long)TimeLocal(),ChartID());
   const ulong exact_double_mask=4503599627370495;
   const ulong token=QM_FTMO_IdentifierHash(identity) & exact_double_mask;
   return (double)token;
  }

bool LeaseOwned()
  {
   double owner=0.0;
   return (g_has_lease && StateReadRequired("lease_owner",owner) &&
           owner == g_instance_token);
  }

bool AcquireLease(const datetime now_utc)
  {
   if(!StateExists("lease_owner") && !StateWrite("lease_owner",0.0))
      return false;
   if(!StateExists("lease_utc") && !StateWrite("lease_utc",0.0))
      return false;

   double owner=0.0,lease_utc=0.0;
   if(!StateReadRequired("lease_owner",owner) ||
      !StateReadRequired("lease_utc",lease_utc))
      return false;
   const long age=(long)(now_utc-(datetime)lease_utc);
   if(owner != 0.0 && owner != g_instance_token)
     {
      if(age < 0 || age <= QM_FTMO_LEASE_TIMEOUT_SECONDS)
         return false;
     }

   ResetLastError();
   if(!GlobalVariableSetOnCondition(StateKey("lease_owner"),g_instance_token,owner))
      return false;
   g_has_lease=true;
   if(!StateWrite("lease_utc",(double)now_utc))
      return false;
   GlobalVariablesFlush();
   return LeaseOwned();
  }

bool RefreshLease(const datetime now_utc)
  {
   if(!LeaseOwned())
      return false;
   if(!StateWrite("lease_utc",(double)now_utc))
      return false;
   return LeaseOwned();
  }

void ReleaseLease()
  {
   if(!LeaseOwned())
      return;
   GlobalVariableSetOnCondition(StateKey("lease_owner"),0.0,g_instance_token);
   GlobalVariablesFlush();
   g_has_lease=false;
  }

bool WritePersistentState()
  {
   bool ok=true;
   ok=StateWrite("initialized",1.0) && ok;
   ok=StateWrite("challenge_start",(double)challenge_start_utc) && ok;
   ok=StateWrite("day_key",(double)g_day_key) && ok;
   ok=StateWrite("midnight_balance",g_midnight_balance) && ok;
   ok=StateWrite("trading_days",(double)g_trading_days) && ok;
   ok=StateWrite("last_trade_day",(double)g_last_trade_day_key) && ok;
   ok=StateWrite("day_lock",g_day_lock ? 1.0 : 0.0) && ok;
   ok=StateWrite("total_lock",g_total_lock ? 1.0 : 0.0) && ok;
   ok=StateWrite("target_lock",g_target_lock ? 1.0 : 0.0) && ok;
   ok=StateWrite("target_complete",g_target_complete ? 1.0 : 0.0) && ok;
   ok=StateWrite("flatten_pending",g_flatten_pending ? 1.0 : 0.0) && ok;
   return ok;
  }

bool PublishSnapshot(const datetime now_utc,
                     const double scale,
                     const int reason,
                     const bool entry_locked,
                     const bool ready,
                     const bool include_persistent_state)
  {
   if(!LeaseOwned())
      return false;
   double raw_generation=0.0;
   if(StateExists("generation") &&
      (!StateReadRequired("generation",raw_generation) || raw_generation < 0.0))
      return false;
   long generation=(long)MathFloor(raw_generation);
   if((generation % 2) != 0)
      ++generation;
   const long odd_generation=generation+1;
   const long even_generation=generation+2;

   // Odd generation makes every concurrent client read fail closed.
   bool ok=StateWrite("generation",(double)odd_generation);
   ok=StateWrite("ready",0.0) && ok;
   ok=StateWrite("entry_lock",1.0) && ok;
   ok=StateWrite("version",QM_FTMO_V1_POLICY_VERSION) && ok;
   ok=StateWrite("fingerprint",QM_FTMO_V1_FINGERPRINT_NUMBER) && ok;
   ok=StateWrite("risk_scale",MathMin(1.0,MathMax(0.0,scale))) && ok;
   ok=StateWrite("reason",(double)reason) && ok;
   if(include_persistent_state)
      ok=WritePersistentState() && ok;
   ok=StateWrite("heartbeat_utc",(double)now_utc) && ok;
   if(!ok || !LeaseOwned())
     {
      GlobalVariablesFlush();
      return false;
     }

   if(!entry_locked)
      ok=StateWrite("entry_lock",0.0) && ok;
   ok=StateWrite("generation",(double)even_generation) && ok;
   if(ready && !entry_locked)
      ok=StateWrite("ready",1.0) && ok;
   GlobalVariablesFlush();
   return (ok && LeaseOwned());
  }

bool PublishFailClosed(const datetime now_utc,const int reason)
  {
   return PublishSnapshot(now_utc,0.0,reason,true,false,g_state_loaded);
  }

bool PoisonInvalidState(const datetime now_utc,const int reason)
  {
   if(!LeaseOwned())
      return false;
   double raw_generation=0.0;
   if(StateExists("generation") && !StateReadRequired("generation",raw_generation))
      raw_generation=0.0;
   long generation=(long)MathMax(0.0,MathFloor(raw_generation));
   if((generation % 2) == 0)
      ++generation;
   bool ok=StateWrite("generation",(double)generation);
   ok=StateWrite("ready",0.0) && ok;
   ok=StateWrite("entry_lock",1.0) && ok;
   ok=StateWrite("risk_scale",0.0) && ok;
   ok=StateWrite("reason",(double)reason) && ok;
   ok=StateWrite("heartbeat_utc",(double)now_utc) && ok;
   GlobalVariablesFlush();
   return ok;
  }

bool BootstrapInputsValid(const datetime now_utc)
  {
   const int current_day=QM_FTMO_PragueDayKey(now_utc);
   const int challenge_day=QM_FTMO_PragueDayKey(challenge_start_utc);
   if(!bootstrap_no_prior_breach_confirmed || challenge_start_utc <= 0 ||
      challenge_start_utc > now_utc || current_day <= 0 || challenge_day <= 0 ||
      bootstrap_prague_day_key != current_day ||
      !MathIsValidNumber(bootstrap_midnight_balance) ||
      bootstrap_midnight_balance <= 0.0 || bootstrap_trading_days < 0 ||
      bootstrap_trading_days > g_policy.minimum_trading_days)
      return false;
   if(bootstrap_trading_days == 0 && bootstrap_last_trade_day_key != 0)
      return false;
   if(bootstrap_trading_days > 0 &&
      (bootstrap_last_trade_day_key < challenge_day ||
       bootstrap_last_trade_day_key > current_day))
      return false;
   if(current_day == challenge_day &&
      !QM_FTMO_Near(bootstrap_midnight_balance,g_policy.start_balance))
      return false;
   return true;
  }

bool SeedBootstrapState(const datetime now_utc)
  {
   if(!BootstrapInputsValid(now_utc))
      return false;
   g_day_key=bootstrap_prague_day_key;
   g_midnight_balance=bootstrap_midnight_balance;
   g_trading_days=bootstrap_trading_days;
   g_last_trade_day_key=bootstrap_last_trade_day_key;
   g_day_lock=false;
   g_total_lock=false;
   g_target_lock=false;
   g_target_complete=false;
   g_flatten_pending=false;
   const bool seeded=PublishSnapshot(now_utc,0.0,QM_FTMO_GOVERNOR_STATE_INVALID,
                                     true,false,true);
   g_state_loaded=seeded;
   return seeded;
  }

bool LoadPersistentState(const datetime now_utc)
  {
   double initialized=0.0,start_utc=0.0,day_key=0.0,midnight=0.0;
   double trading_days=0.0,last_trade_day=0.0,generation=0.0;
   double version=0.0,fingerprint=0.0;
   bool day_lock=false,total_lock=false,target_lock=false,target_complete=false;
   bool flatten_pending=false;
   if(!StateReadRequired("initialized",initialized) || initialized != 1.0 ||
      !StateReadRequired("challenge_start",start_utc) ||
      !StateReadRequired("day_key",day_key) ||
      !StateReadRequired("midnight_balance",midnight) ||
      !StateReadRequired("trading_days",trading_days) ||
      !StateReadRequired("last_trade_day",last_trade_day) ||
      !StateReadRequired("generation",generation) ||
      !StateReadRequired("version",version) ||
      !StateReadRequired("fingerprint",fingerprint) ||
      !StateReadBool("day_lock",day_lock) ||
      !StateReadBool("total_lock",total_lock) ||
      !StateReadBool("target_lock",target_lock) ||
      !StateReadBool("target_complete",target_complete) ||
      !StateReadBool("flatten_pending",flatten_pending))
      return false;
   const int current_day=QM_FTMO_PragueDayKey(now_utc);
   if((datetime)start_utc != challenge_start_utc || challenge_start_utc <= 0 ||
      challenge_start_utc > now_utc || day_key != MathFloor(day_key) ||
      (int)day_key != current_day ||
      current_day <= 0 || midnight <= 0.0 || trading_days < 0.0 ||
      trading_days > (double)g_policy.minimum_trading_days ||
      trading_days != MathFloor(trading_days) ||
      last_trade_day != MathFloor(last_trade_day) ||
      generation < 2.0 || generation != MathFloor(generation) ||
      ((long)generation % 2) != 0 ||
      !QM_FTMO_Near(version,QM_FTMO_V1_POLICY_VERSION) ||
      fingerprint != QM_FTMO_V1_FINGERPRINT_NUMBER ||
      (target_complete && !target_lock))
      return false;
   if((int)trading_days == 0 && (int)last_trade_day != 0)
      return false;
   if((int)trading_days > 0 &&
      ((int)last_trade_day < QM_FTMO_PragueDayKey(challenge_start_utc) ||
       (int)last_trade_day > current_day))
      return false;

   g_day_key=(int)day_key;
   g_midnight_balance=midnight;
   g_trading_days=(int)trading_days;
   g_last_trade_day_key=(int)last_trade_day;
   g_day_lock=day_lock;
   g_total_lock=total_lock;
   g_target_lock=target_lock;
   g_target_complete=target_complete;
   g_flatten_pending=flatten_pending;
   g_state_loaded=true;
   g_last_evaluation_utc=now_utc;
   return true;
  }

bool RefreshMonotonicLocks()
  {
   double persisted_day_key=0.0;
   bool day_lock=false,total_lock=false,target_lock=false,target_complete=false;
   if(!StateReadRequired("day_key",persisted_day_key) ||
      !StateReadBool("day_lock",day_lock) ||
      !StateReadBool("total_lock",total_lock) ||
      !StateReadBool("target_lock",target_lock) ||
      !StateReadBool("target_complete",target_complete) ||
      (int)persisted_day_key != g_day_key)
      return false;
   g_day_lock=(g_day_lock || day_lock);
   g_total_lock=(g_total_lock || total_lock);
   g_target_lock=(g_target_lock || target_lock);
   g_target_complete=(g_target_complete || target_complete);
   if(g_target_complete)
      g_target_lock=true;
   return true;
  }

bool FindUnknownExposure(long &magic,ulong &ticket,string &kind)
  {
   for(int index=OrdersTotal()-1;index>=0;--index)
     {
      const ulong current=OrderGetTicket(index);
      if(current == 0 || !OrderSelect(current))
         continue;
      const long current_magic=OrderGetInteger(ORDER_MAGIC);
      if(!MagicAllowed(current_magic))
        {
         magic=current_magic;
         ticket=current;
         kind="ORDER";
         return true;
        }
     }
   for(int index=PositionsTotal()-1;index>=0;--index)
     {
      const ulong current=PositionGetTicket(index);
      if(current == 0 || !PositionSelectByTicket(current))
         continue;
      const long current_magic=PositionGetInteger(POSITION_MAGIC);
      if(!MagicAllowed(current_magic))
        {
         magic=current_magic;
         ticket=current;
         kind="POSITION";
         return true;
        }
     }
   return false;
  }

bool DeleteGovernedPendingOrders()
  {
   bool all_ok=true;
   for(int index=OrdersTotal()-1;index>=0;--index)
     {
      const ulong ticket=OrderGetTicket(index);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(!MagicAllowed(OrderGetInteger(ORDER_MAGIC)))
         continue;
      const bool requested=g_trade.OrderDelete(ticket);
      const uint retcode=g_trade.ResultRetcode();
      if(!requested || retcode != TRADE_RETCODE_DONE)
        {
         all_ok=false;
         PrintFormat("FTMO_GOVERNOR_DELETE_RETRY ticket=%I64u retcode=%u",ticket,retcode);
        }
     }
   return all_ok;
  }

bool CloseGovernedPositions()
  {
   bool all_ok=true;
   for(int index=PositionsTotal()-1;index>=0;--index)
     {
      const ulong ticket=PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!MagicAllowed(PositionGetInteger(POSITION_MAGIC)))
         continue;
      const bool requested=g_trade.PositionClose(ticket,(ulong)MathMax(0,close_deviation_points));
      const uint retcode=g_trade.ResultRetcode();
      if(!requested || retcode != TRADE_RETCODE_DONE)
        {
         all_ok=false;
         PrintFormat("FTMO_GOVERNOR_CLOSE_RETRY ticket=%I64u retcode=%u",ticket,retcode);
        }
     }
   return all_ok;
  }

bool GovernedExposureFlat()
  {
   for(int i=OrdersTotal()-1;i>=0;--i)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket) && MagicAllowed(OrderGetInteger(ORDER_MAGIC)))
         return false;
     }
   for(int i=PositionsTotal()-1;i>=0;--i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket) &&
         MagicAllowed(PositionGetInteger(POSITION_MAGIC)))
         return false;
     }
   return true;
  }

void EvaluateAndPublish()
  {
   const datetime now_utc=TimeGMT();
   if(now_utc <= 0 || !RefreshLease(now_utc))
     {
      Print("FTMO_GOVERNOR_LEASE_LOST");
      return;
     }
   const double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const int current_day=QM_FTMO_PragueDayKey(now_utc);
   if(current_day <= 0 || !MathIsValidNumber(balance) || !MathIsValidNumber(equity))
     {
      PublishFailClosed(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
      return;
     }

   if(current_day < g_day_key)
     {
      PublishFailClosed(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
      return;
     }
   if(current_day > g_day_key)
     {
      const long gap=(long)(now_utc-g_last_evaluation_utc);
      if(g_last_evaluation_utc <= 0 || gap < 0 ||
         gap > QM_FTMO_DAY_TRANSITION_MAX_GAP_SECONDS)
        {
         PublishFailClosed(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
         return;
        }
      g_day_key=current_day;
      g_midnight_balance=balance;
      g_day_lock=false;
     }
   else if(!RefreshMonotonicLocks())
     {
      PublishFailClosed(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
      return;
     }

   long unknown_magic=0;
   ulong unknown_ticket=0;
   string unknown_kind="";
   const bool unknown_exposure=FindUnknownExposure(unknown_magic,unknown_ticket,unknown_kind);
   if(unknown_exposure)
      PrintFormat("FTMO_GOVERNOR_UNKNOWN_EXPOSURE kind=%s ticket=%I64u magic=%I64d",
                  unknown_kind,unknown_ticket,unknown_magic);

   QM_FTMO_GovernorDecision decision;
   if(!QM_FTMO_EvaluateSnapshot(now_utc,balance,equity,g_midnight_balance,
                                g_trading_days,PositionsTotal(),OrdersTotal(),
                                g_day_lock,g_total_lock,g_policy,decision))
     {
      PublishFailClosed(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
      return;
     }

   if(decision.reason == QM_FTMO_GOVERNOR_TOTAL_FLOOR)
      g_total_lock=true;
   if(decision.reason == QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR)
      g_day_lock=true;
   if(decision.target_reached || decision.target_complete)
      g_target_lock=true;

   const bool account_flat=(!unknown_exposure && OrdersTotal() == 0 && PositionsTotal() == 0);
   if(g_target_lock && !g_target_complete && account_flat)
     {
      if(balance >= g_policy.target_balance &&
         g_trading_days >= g_policy.minimum_trading_days)
         g_target_complete=true;
      else if(balance < g_policy.target_balance && equity < g_policy.target_balance)
         g_target_lock=false;
     }
   if(g_target_complete)
      g_target_lock=true;

   int publish_reason=(int)decision.reason;
   if(g_target_complete && !g_day_lock && !g_total_lock)
      publish_reason=QM_FTMO_GOVERNOR_TARGET_COMPLETE;
   else if(g_target_lock && !g_day_lock && !g_total_lock)
      publish_reason=QM_FTMO_GOVERNOR_TARGET_CAPTURE;
   else if(unknown_exposure && !g_day_lock && !g_total_lock && !g_target_lock)
      publish_reason=QM_FTMO_GOVERNOR_UNKNOWN_EXPOSURE;

   const bool must_lock=(g_day_lock || g_total_lock || g_target_lock ||
                         unknown_exposure || !decision.entry_allowed ||
                         governor_dry_run);
   g_flatten_pending=((g_day_lock || g_total_lock || g_target_lock) &&
                      !GovernedExposureFlat());
   const bool published=PublishSnapshot(now_utc,decision.risk_scale,publish_reason,
                                        must_lock,
                                        (!governor_dry_run && !must_lock),true);
   g_last_evaluation_utc=now_utc;
   if(!published)
      return;

   if((g_day_lock || g_total_lock || g_target_lock) && !governor_dry_run)
     {
      const bool orders_ok=DeleteGovernedPendingOrders();
      const bool positions_ok=CloseGovernedPositions();
      g_flatten_pending=!(orders_ok && positions_ok && GovernedExposureFlat());
      PublishSnapshot(now_utc,decision.risk_scale,publish_reason,true,false,true);
     }
  }

void MarkTradingDay(const datetime now_utc)
  {
   const int key=QM_FTMO_PragueDayKey(now_utc);
   if(key <= 0 || key == g_last_trade_day_key)
      return;
   if(key < g_last_trade_day_key || key < QM_FTMO_PragueDayKey(challenge_start_utc))
     {
      PublishFailClosed(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
      return;
     }
   if(g_trading_days < g_policy.minimum_trading_days)
      ++g_trading_days;
   g_last_trade_day_key=key;
   EvaluateAndPublish();
  }

int OnInit()
  {
   g_login=AccountInfoInteger(ACCOUNT_LOGIN);
   QM_FTMO_DefaultPolicy(g_policy);
   if(expected_account_login <= 0 || g_login != expected_account_login ||
      !QM_FTMO_IdentifierValid(challenge_id) || challenge_start_utc <= 0 ||
      !QM_FTMO_IsExactV1Policy(g_policy) || governor_timer_ms < 100 ||
      governor_timer_ms > 1000 || !ParseAllowedMagics())
      return INIT_PARAMETERS_INCORRECT;

   g_instance_token=MakeInstanceToken();
   const datetime now_utc=TimeGMT();
   if(g_instance_token <= 0.0 || now_utc <= 0 || !AcquireLease(now_utc))
     {
      Print("FTMO_GOVERNOR_SINGLETON_LEASE_UNAVAILABLE");
      return INIT_FAILED;
     }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING ||
      AccountInfoString(ACCOUNT_CURRENCY) != "USD")
     {
      PoisonInvalidState(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
      return INIT_PARAMETERS_INCORRECT;
     }

   if(challenge_state_bootstrap)
     {
      if(!SeedBootstrapState(now_utc))
        {
         PoisonInvalidState(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
         return INIT_PARAMETERS_INCORRECT;
        }
      Print("FTMO_GOVERNOR_BOOTSTRAP_COMPLETE_RESTART_WITH_BOOTSTRAP_FALSE");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!LoadPersistentState(now_utc))
     {
      PoisonInvalidState(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
      Print("FTMO_GOVERNOR_STATE_MISSING_OR_INVALID_EXPLICIT_BOOTSTRAP_REQUIRED");
      return INIT_PARAMETERS_INCORRECT;
     }

   g_trade.SetAsyncMode(false);
   if(!EventSetMillisecondTimer(governor_timer_ms))
     {
      PublishFailClosed(now_utc,QM_FTMO_GOVERNOR_STATE_INVALID);
      return INIT_FAILED;
     }
   EvaluateAndPublish();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(LeaseOwned())
     {
      if(g_state_loaded)
         PublishFailClosed(TimeGMT(),QM_FTMO_GOVERNOR_STATE_INVALID);
      else
         PoisonInvalidState(TimeGMT(),QM_FTMO_GOVERNOR_STATE_INVALID);
     }
   ReleaseLease();
  }

void OnTimer()
  {
   EvaluateAndPublish();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0 ||
      !HistoryDealSelect(trans.deal))
      return;
   const long magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
   const long entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(MagicAllowed(magic) && (entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT))
      MarkTradingDay(TimeGMT());
  }
