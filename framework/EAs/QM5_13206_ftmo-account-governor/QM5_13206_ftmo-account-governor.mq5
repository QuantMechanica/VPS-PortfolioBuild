#property strict
#property version "1.0"
#property description "FTMO account-wide entry lock, risk scale, and governed-magic liquidator"

#include <Trade/Trade.mqh>
#include <QM/QM_FTMOGovernorPolicy.mqh>

input group "Deployment Identity"
input long   expected_account_login        = 0;
input string governor_policy_id            = "FTMO_P1_GOVERNOR_V1";
input double governor_policy_version       = 1.0;
input string allowed_magics_csv            = "";
input bool   governor_dry_run               = true;

input group "Policy"
input double policy_start_balance           = 100000.0;
input double policy_target_balance          = 110000.0;
input double policy_total_loss_floor        = 90000.0;
input double policy_execution_daily_stop    = 4500.0;
input double policy_profit_room_retention   = 0.20;
input double policy_full_risk_room          = 4000.0;
input int    policy_minimum_trading_days    = 4;

input group "Execution"
input int    governor_timer_ms              = 200;
input int    close_deviation_points         = 50;

CTrade g_trade;
QM_FTMO_GovernorPolicy g_policy;
long g_login=0;
long g_allowed_magics[];
int g_day_key=0;
double g_midnight_balance=0.0;
int g_trading_days=0;
int g_last_trade_day_key=0;
bool g_day_lock=true;
bool g_total_lock=true;
bool g_target_lock=false;

string StateKey(const string suffix)
  {
   return StringFormat("QM.FTMO.%I64d.%s.%s",g_login,governor_policy_id,suffix);
  }

bool StateExists(const string suffix)
  {
   return GlobalVariableCheck(StateKey(suffix));
  }

double StateRead(const string suffix,const double fallback)
  {
   return StateExists(suffix) ? GlobalVariableGet(StateKey(suffix)) : fallback;
  }

void StateWrite(const string suffix,const double value)
  {
   GlobalVariableSet(StateKey(suffix),value);
  }

void PublishFailClosed(const datetime now_utc,const double scale,const int reason)
  {
   StateWrite("version",governor_policy_version);
   StateWrite("heartbeat_utc",(double)now_utc);
   StateWrite("risk_scale",MathMin(1.0,MathMax(0.0,scale)));
   StateWrite("reason",(double)reason);
   StateWrite("entry_lock",1.0);
   StateWrite("ready",0.0);
   GlobalVariablesFlush();
  }

bool MagicAllowed(const long magic)
  {
   for(int i=0;i<ArraySize(g_allowed_magics);++i)
      if(g_allowed_magics[i] == magic)
         return true;
   return false;
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
      if(StringLen(value) <= 0)
         continue;
      const long magic=(long)StringToInteger(value);
      if(magic <= 0 || MagicAllowed(magic))
         return false;
      const int size=ArraySize(g_allowed_magics);
      ArrayResize(g_allowed_magics,size+1);
      g_allowed_magics[size]=magic;
     }
   return (ArraySize(g_allowed_magics) > 0);
  }

void LoadPolicy()
  {
   g_policy.policy_id=governor_policy_id;
   g_policy.start_balance=policy_start_balance;
   g_policy.target_balance=policy_target_balance;
   g_policy.total_loss_floor=policy_total_loss_floor;
   g_policy.execution_daily_stop=policy_execution_daily_stop;
   g_policy.profit_room_retention=policy_profit_room_retention;
   g_policy.full_risk_room=policy_full_risk_room;
   g_policy.minimum_trading_days=policy_minimum_trading_days;
  }

void PersistState()
  {
   StateWrite("day_key",(double)g_day_key);
   StateWrite("midnight_balance",g_midnight_balance);
   StateWrite("trading_days",(double)g_trading_days);
   StateWrite("last_trade_day_key",(double)g_last_trade_day_key);
   StateWrite("day_lock",g_day_lock ? 1.0 : 0.0);
   StateWrite("total_lock",g_total_lock ? 1.0 : 0.0);
   StateWrite("target_lock",g_target_lock ? 1.0 : 0.0);
  }

void MarkTradingDay(const datetime now_utc)
  {
   const int key=QM_FTMO_PragueDayKey(now_utc);
   if(key <= 0 || key == g_last_trade_day_key)
      return;
   ++g_trading_days;
   g_last_trade_day_key=key;
   PersistState();
   GlobalVariablesFlush();
  }

bool DeleteGovernedPendingOrders()
  {
   bool all_ok=true;
   for(int index=OrdersTotal()-1;index>=0;--index)
     {
      const ulong ticket=OrderGetTicket(index);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      const long magic=OrderGetInteger(ORDER_MAGIC);
      if(!MagicAllowed(magic))
         continue;
      if(!g_trade.OrderDelete(ticket))
        {
         all_ok=false;
         PrintFormat("FTMO_GOVERNOR_DELETE_RETRY ticket=%I64u retcode=%u",ticket,g_trade.ResultRetcode());
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
      const long magic=PositionGetInteger(POSITION_MAGIC);
      if(!MagicAllowed(magic))
         continue;
      if(!g_trade.PositionClose(ticket,(ulong)MathMax(0,close_deviation_points)))
        {
         all_ok=false;
         PrintFormat("FTMO_GOVERNOR_CLOSE_RETRY ticket=%I64u retcode=%u",ticket,g_trade.ResultRetcode());
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
      if(ticket > 0 && PositionSelectByTicket(ticket) && MagicAllowed(PositionGetInteger(POSITION_MAGIC)))
         return false;
     }
   return true;
  }

void EvaluateAndPublish()
  {
   const datetime now_utc=TimeGMT();
   const double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const int current_day=QM_FTMO_PragueDayKey(now_utc);
   if(current_day <= 0)
     {
      PublishFailClosed(now_utc,0.0,QM_FTMO_GOVERNOR_INVALID_INPUT);
      return;
     }
   if(current_day != g_day_key)
     {
      g_day_key=current_day;
      g_midnight_balance=balance;
      g_day_lock=false;
      PersistState();
      GlobalVariablesFlush();
     }

   QM_FTMO_GovernorDecision decision;
   if(!QM_FTMO_EvaluateSnapshot(now_utc,balance,equity,g_midnight_balance,
                                g_trading_days,PositionsTotal(),g_day_lock,
                                g_total_lock,g_policy,decision))
     {
      PublishFailClosed(now_utc,0.0,QM_FTMO_GOVERNOR_INVALID_INPUT);
      return;
     }

   if(decision.reason == QM_FTMO_GOVERNOR_TOTAL_FLOOR)
      g_total_lock=true;
   if(decision.reason == QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR)
      g_day_lock=true;
   if(decision.target_complete)
      g_target_lock=true;

   const bool must_lock=(g_day_lock || g_total_lock || g_target_lock ||
                         !decision.entry_allowed || governor_dry_run);
   StateWrite("version",governor_policy_version);
   StateWrite("heartbeat_utc",(double)now_utc);
   StateWrite("risk_scale",decision.risk_scale);
   StateWrite("reason",(double)decision.reason);
   StateWrite("entry_lock",must_lock ? 1.0 : 0.0);
   StateWrite("ready",(!governor_dry_run && !must_lock) ? 1.0 : 0.0);
   PersistState();

   // The entry lock is durable before any cancellation or close request.
   GlobalVariablesFlush();
   if((g_day_lock || g_total_lock) && !governor_dry_run)
     {
      const bool orders_ok=DeleteGovernedPendingOrders();
      const bool positions_ok=CloseGovernedPositions();
      StateWrite("flatten_pending",(orders_ok && positions_ok && GovernedExposureFlat()) ? 0.0 : 1.0);
      GlobalVariablesFlush();
     }
  }

int OnInit()
  {
   g_login=AccountInfoInteger(ACCOUNT_LOGIN);
   LoadPolicy();
   PublishFailClosed(TimeGMT(),0.0,QM_FTMO_GOVERNOR_INVALID_INPUT);
   if(expected_account_login <= 0 || g_login != expected_account_login)
     {
      PrintFormat("FTMO_GOVERNOR_ACCOUNT_MISMATCH expected=%I64d actual=%I64d",expected_account_login,g_login);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!QM_FTMO_PolicyValid(g_policy) || governor_policy_version <= 0.0 ||
      governor_timer_ms < 100 || governor_timer_ms > 1000 || !ParseAllowedMagics())
      return INIT_PARAMETERS_INCORRECT;

   g_trade.SetAsyncMode(false);
   g_day_key=(int)StateRead("day_key",0.0);
   g_midnight_balance=StateRead("midnight_balance",AccountInfoDouble(ACCOUNT_BALANCE));
   g_trading_days=(int)StateRead("trading_days",0.0);
   g_last_trade_day_key=(int)StateRead("last_trade_day_key",0.0);
   g_day_lock=(StateRead("day_lock",0.0) >= 0.5);
   g_total_lock=(StateRead("total_lock",0.0) >= 0.5);
   g_target_lock=(StateRead("target_lock",0.0) >= 0.5);
   if(!EventSetMillisecondTimer(governor_timer_ms))
      return INIT_FAILED;
   EvaluateAndPublish();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   PublishFailClosed(TimeGMT(),0.0,QM_FTMO_GOVERNOR_PERSISTED_TOTAL_LOCK);
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
