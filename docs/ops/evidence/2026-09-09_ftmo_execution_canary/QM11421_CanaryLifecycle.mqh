// Isolated review source. Not included by any registered or deployed EA.
// Parent QM_Common and input declarations must precede this include.
bool g_qm11421_cleanup_pending=false;
ulong g_qm11421_cleanup_started=0;
ulong g_qm11421_last_attempt=0;

bool QM11421_SessionSafe(const datetime broker_now)
  {
   MqlDateTime d;
   if(broker_now<=0 || !TimeToStruct(broker_now,d)) return false;
   if(d.day_of_week==0 || d.day_of_week==6) return false;
   const int seconds=d.hour*3600+d.min*60+d.sec;
   // Conservative canary: flat five minutes before EVERY scheduled pause.
   // Holiday overrides and live session freshness require native qualification.
   for(uint index=0;index<24;index++)
     {
      datetime begin,end;
      if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)d.day_of_week,index,begin,end)) break;
      const long a=(long)begin,b=(long)end;
      if(b>a && seconds>=a && seconds<b-300) return true;
     }
   return false;
  }

int QM11421_ExposureCount()
  {
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      const ulong t=OrderGetTicket(i);
      if(t>0 && OrderGetInteger(ORDER_MAGIC)==QM_FrameworkMagic() &&
         OrderGetString(ORDER_SYMBOL)==_Symbol) count++;
     }
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      const ulong t=PositionGetTicket(i);
      if(t>0 && PositionGetInteger(POSITION_MAGIC)==QM_FrameworkMagic() &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) count++;
     }
   return count;
  }

void QM11421_Cleanup(const string reason)
  {
   const ulong now=GetTickCount64();
   if(g_qm11421_last_attempt>0 && now-g_qm11421_last_attempt<1000) return;
   g_qm11421_last_attempt=now;
   // Exposure reduction never depends on entry permission or the shared budget.
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      const ulong t=OrderGetTicket(i);
      if(t==0 || OrderGetInteger(ORDER_MAGIC)!=QM_FrameworkMagic() ||
         OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      MqlTradeRequest request;MqlTradeResult result;string error;
      ZeroMemory(request);ZeroMemory(result);
      request.action=TRADE_ACTION_REMOVE;request.order=t;
      request.magic=QM_FrameworkMagic();request.symbol=_Symbol;
      const bool sent=QM_TradeContextSend(request,result,error,QM_TRADE_SEND_ONCE);
      const bool absent=!OrderSelect(t);
      QM_LogEvent(absent ? QM_INFO : QM_ERROR,"CANARY_DELETE",
         StringFormat("{\"ticket\":%I64u,\"sent\":%s,\"retcode\":%u,\"absent\":%s}",
                      t,sent?"true":"false",result.retcode,absent?"true":"false"));
     }
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      const ulong t=PositionGetTicket(i);
      if(t==0 || PositionGetInteger(POSITION_MAGIC)!=QM_FrameworkMagic() ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      const bool sent=QM_TM_ClosePosition(t,QM_EXIT_STRATEGY);
      const bool absent=!PositionSelectByTicket(t);
      QM_LogEvent(absent ? QM_INFO : QM_ERROR,"CANARY_CLOSE",
         StringFormat("{\"ticket\":%I64u,\"sent\":%s,\"absent\":%s}",
                      t,sent?"true":"false",absent?"true":"false"));
     }
   const int remaining=QM11421_ExposureCount();
   if(remaining==0) g_qm11421_cleanup_pending=false;
   else if(now-g_qm11421_cleanup_started>=30000)
      QM_LogEvent(QM_ERROR,"CANARY_CLEANUP_TIMEOUT",
         StringFormat("{\"reason\":\"%s\",\"remaining\":%d}",
                      QM_LoggerEscapeJson(reason),remaining));
  }

bool QM11421_CanaryBoundary()
  {
   double scale=0;string reason="CONTRACT_NOT_READY";
   bool allow=QM_RuntimeExecutionEntryAllowed() && QM_RuntimeExecutionGovernorRequired();
   if(allow) allow=QM_FTMO_ReadGovernorScale(
      g_qm_runtime_execution_contract.governor_policy_id,
      g_qm_runtime_execution_contract.challenge_instance_id,
      g_qm_runtime_execution_contract.governor_heartbeat_max_age_seconds,scale,reason);
   const datetime broker_now=TimeTradeServer();
   MqlTick tick;
   const bool quote_ok=SymbolInfoTick(_Symbol,tick) && tick.time>0 &&
      broker_now>=tick.time && broker_now-tick.time<=5;
   const bool news_ok=QM_NewsAllowsTrade2(_Symbol,broker_now,qm_news_temporal,qm_news_compliance);
   const bool session_ok=QM11421_SessionSafe(broker_now);
   const bool local_ok=QM_KillSwitchCheck();
   if(!quote_ok) {allow=false;reason="QUOTE_STALE";}
   if(!news_ok) {allow=false;reason="INTERNAL_NEWS_FLAT";}
   if(!session_ok) {allow=false;reason="SESSION_FLAT";}
   if(!local_ok) {allow=false;reason="LOCAL_HALT";}
   if(!allow && QM11421_ExposureCount()>0 && !g_qm11421_cleanup_pending)
     {g_qm11421_cleanup_pending=true;g_qm11421_cleanup_started=GetTickCount64();}
   if(g_qm11421_cleanup_pending)
     {QM11421_Cleanup(reason);return false;}
   return allow;
  }
