#ifndef QM_COMMON_MQH
#define QM_COMMON_MQH

#include <Trade/Trade.mqh>

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"
#include "QM_MagicResolver.mqh"
#include "QM_RiskSizer.mqh"
#include "QM_DSTAware.mqh"
#include "QM_NewsFilter.mqh"
#include "QM_KillSwitch.mqh"
#include "QM_Entry.mqh"
#include "QM_Exit.mqh"
#include "QM_StopRules.mqh"
#include "QM_TradeContext.mqh"
#include "QM_ChartUI.mqh"

int  g_qm_fw_ea_id            = 0;
int  g_qm_fw_magic_slot       = 0;
int  g_qm_fw_magic            = 0;
bool g_qm_fw_timer_active     = false;
bool g_qm_fw_initialized      = false;
bool g_qm_fw_friday_close_enabled = true;
int  g_qm_fw_friday_close_hour_broker = 21;

CTrade g_qm_fw_trade;

string QM_FrameworkSlug(const int framework_ea_id)
  {
   return StringFormat("ea-%04d", framework_ea_id);
  }

bool QM_FrameworkValidateRiskInputs(const double risk_percent, const double risk_fixed)
  {
   if(risk_percent <= 0.0 && risk_fixed <= 0.0)
     {
      Print(EA_INPUT_RISK_BOTH_ZERO);
      return false;
     }
   if(risk_percent > 0.0 && risk_fixed > 0.0)
     {
      Print(EA_INPUT_RISK_BOTH_SET);
      return false;
     }
   return true;
  }

bool QM_FrameworkInit(const int framework_ea_id,
                      const int framework_magic_slot_offset,
                      const double risk_percent,
                      const double risk_fixed,
                      const double portfolio_weight,
                      const QM_NewsMode framework_news_mode,
                      const bool framework_friday_close_enabled = true,
                      const int framework_friday_close_hour_broker = 21)
  {
   if(framework_ea_id <= 0)
      return false;
   if(portfolio_weight <= 0.0 || portfolio_weight > 1.0)
     {
      Print(EA_INPUT_PORTFOLIO_WEIGHT_OUT_OF_RANGE);
      return false;
     }
   if(!QM_FrameworkValidateRiskInputs(risk_percent, risk_fixed))
      return false;

   g_qm_fw_ea_id = framework_ea_id;
   g_qm_fw_magic_slot = framework_magic_slot_offset;
   g_qm_fw_magic = QM_MagicChecked(framework_ea_id, framework_magic_slot_offset, _Symbol);
   if(g_qm_fw_magic <= 0)
      return false;

   const string slug = QM_FrameworkSlug(framework_ea_id);
   QM_LoggerInit(framework_ea_id, slug, _Symbol, (ENUM_TIMEFRAMES)_Period, g_qm_fw_magic);

   QM_RiskMode mode = QM_RISK_MODE_PERCENT;
   if(risk_fixed > 0.0)
      mode = QM_RISK_MODE_FIXED;
   const double risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
   if(!QM_RiskSizerConfigure(mode, risk_percent, risk_fixed, portfolio_weight, risk_cap_money))
      return false;

   if(!QM_NewsInit())
     {
      QM_LogEvent(QM_WARN, SETUP_DATA_MISSING, "{\"component\":\"news_calendar\"}");
      if(framework_news_mode != QM_NEWS_OFF)
         return false;
     }

   QM_EntryConfigure(framework_ea_id, framework_news_mode);
   QM_KillSwitchInit(framework_ea_id, g_qm_fw_magic, 3.0, 0.0, 1.0);
   g_qm_fw_friday_close_enabled = framework_friday_close_enabled;
   g_qm_fw_friday_close_hour_broker = MathMin(23, MathMax(0, framework_friday_close_hour_broker));

   if(!QM_ChartUI_Init(framework_ea_id, slug))
      return false;

   if(qm_chartui_enabled && MQLInfoInteger(MQL_TESTER) == 0)
     {
      EventSetTimer(1);
      g_qm_fw_timer_active = true;
     }

   g_qm_fw_initialized = true;
   QM_LogEvent(QM_INFO, "INIT", StringFormat("{\"magic\":%d,\"symbol\":\"%s\"}", g_qm_fw_magic, QM_LoggerEscapeJson(_Symbol)));
   return true;
  }

int QM_FrameworkMagic()
  {
   return g_qm_fw_magic;
  }

bool QM_FrameworkFridayCloseNow(const datetime broker_time = 0)
  {
   if(!g_qm_fw_friday_close_enabled)
      return false;

   datetime t = broker_time;
   if(t <= 0)
      t = TimeCurrent();

   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.day_of_week != 5)
      return false;
   return (dt.hour >= g_qm_fw_friday_close_hour_broker);
  }

int QM_FrameworkCloseAllByMagic(const long magic, const string reason)
  {
   int closed = 0;
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(g_qm_fw_trade.PositionClose(ticket))
        {
         ++closed;
         continue;
        }

      QM_LogEvent(QM_WARN,
                  "FRIDAY_CLOSE_FAILED",
                  StringFormat("{\"ticket\":%I64u,\"retcode\":%u,\"reason\":\"%s\"}",
                               ticket,
                               g_qm_fw_trade.ResultRetcode(),
                               QM_LoggerEscapeJson(reason)));
     }

   return closed;
  }

bool QM_FrameworkHandleFridayClose()
  {
   if(!QM_FrameworkFridayCloseNow())
      return false;

   const int closed = QM_FrameworkCloseAllByMagic((long)g_qm_fw_magic, "friday_close");
   QM_LogEvent(QM_INFO, "FRIDAY_CLOSE", StringFormat("{\"closed\":%d,\"hour\":%d}", closed, g_qm_fw_friday_close_hour_broker));
   return true;
  }

void QM_FrameworkOnTimer()
  {
   if(!g_qm_fw_initialized)
      return;
   QM_ChartUI_Refresh();
  }

void QM_FrameworkShutdown()
  {
   if(g_qm_fw_timer_active)
     {
      EventKillTimer();
      g_qm_fw_timer_active = false;
     }

   QM_ChartUI_Shutdown();
   if(g_qm_fw_initialized)
      QM_LogEvent(QM_INFO, "DEINIT", "{}");
   g_qm_fw_initialized = false;
  }

double QM_DefaultObjective()
  {
   const double gross_profit = TesterStatistics(STAT_GROSS_PROFIT);
   const double gross_loss = TesterStatistics(STAT_GROSS_LOSS);
   if(gross_profit <= 0.0 || gross_loss >= 0.0)
      return 0.0;
   return gross_profit / MathAbs(gross_loss);
  }

#endif // QM_COMMON_MQH
