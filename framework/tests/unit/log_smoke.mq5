#property strict

#include <QM/QM_Logger.mqh>

input int    ea_id   = 1000;
input string ea_slug = "log-smoke";
input long   magic   = 10000000;

bool g_logged_tick = false;

int OnInit()
  {
   QM_LoggerInit(ea_id, ea_slug, _Symbol, (ENUM_TIMEFRAMES)_Period, magic);
   if(!QM_LogEvent(QM_INFO, "LOG_SMOKE_INIT", "{\"stage\":\"on_init\"}"))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(g_logged_tick)
      return;

   g_logged_tick = true;
   QM_LogEvent(QM_INFO, "LOG_SMOKE_TICK", StringFormat("{\"bid\":%.5f,\"ask\":%.5f}", SymbolInfoDouble(_Symbol, SYMBOL_BID), SymbolInfoDouble(_Symbol, SYMBOL_ASK)));
   ExpertRemove();
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "LOG_SMOKE_DEINIT", StringFormat("{\"reason\":%d}", reason));
  }
