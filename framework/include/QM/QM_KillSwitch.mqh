#ifndef QM_KILL_SWITCH_MQH
#define QM_KILL_SWITCH_MQH

#include <Trade/Trade.mqh>

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"

// V5 Framework Step 07:
// Three independent kill paths:
// - KS_DAILY_LOSS: day PnL breach versus broker-day starting equity
// - KS_PORTFOLIO_DD: external signal file from monitor
// - KS_MANUAL: manual halt file D:\QM\data\halt\<ea_id>.halt

int    g_qm_ks_ea_id                     = 0;
long   g_qm_ks_magic                     = 0;
double g_qm_ks_daily_loss_halt_pct       = 0.0;
double g_qm_ks_portfolio_dd_halt_pct     = 0.0;
double g_qm_ks_per_trade_risk_cap_pct    = 1.0;
string g_qm_ks_manual_halt_file          = "";
string g_qm_ks_portfolio_dd_signal_file  = "";

bool   g_qm_ks_initialized               = false;
bool   g_qm_ks_halted                    = false;
bool   g_qm_ks_unconfigured_logged       = false;
string g_qm_ks_halt_reason               = "";
int    g_qm_ks_halt_day_key              = -1;
int    g_qm_ks_day_key                   = -1;
double g_qm_ks_day_start_equity          = 0.0;

CTrade g_qm_ks_trade;

int QM_KillSwitchDayKey(const datetime broker_time)
{
   MqlDateTime t;
   TimeToStruct(broker_time, t);
   return t.year * 1000 + t.day_of_year;
}

string QM_KillSwitchTrim(const string value)
{
   string out = value;
   StringTrimLeft(out);
   StringTrimRight(out);
   return out;
}

bool QM_KillSwitchFileExists(const string path)
{
   if(StringLen(path) == 0)
      return false;

   if(FileIsExist(path))
      return true;

   if(FileIsExist(path, FILE_COMMON))
      return true;

   return false;
}

bool QM_KillSwitchReadFirstLine(const string path, string &line)
{
   line = "";
   if(StringLen(path) == 0)
      return false;

   int flags = FILE_READ | FILE_TXT | FILE_ANSI;
   int handle = FileOpen(path, flags);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(path, flags | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;

   if(!FileIsEnding(handle))
      line = QM_KillSwitchTrim(FileReadString(handle));
   FileClose(handle);
   return true;
}

bool QM_KillSwitchTryParseDouble(string text, double &value)
{
   text = QM_KillSwitchTrim(text);
   if(StringLen(text) == 0)
      return false;

   const int eq = StringFind(text, "=");
   if(eq >= 0)
      text = QM_KillSwitchTrim(StringSubstr(text, eq + 1));

   if(StringLen(text) == 0)
      return false;

   value = StringToDouble(text);
   if(!MathIsValidNumber(value))
      return false;

   if(value == 0.0 && text != "0" && text != "0.0" && text != "0.00")
      return false;

   return true;
}

void QM_KillSwitchRefreshBrokerDay()
{
   const datetime now_broker = TimeCurrent();
   const int current_day_key = QM_KillSwitchDayKey(now_broker);
   if(g_qm_ks_day_key == current_day_key)
      return;

   g_qm_ks_day_key = current_day_key;
   g_qm_ks_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_qm_ks_halted && g_qm_ks_halt_day_key != current_day_key)
   {
      g_qm_ks_halted = false;
      g_qm_ks_halt_reason = "";
      QM_LogEvent(QM_INFO,
                  "KILL_SWITCH_RESET_NEXT_BROKER_DAY",
                  StringFormat("{\"day_key\":%d,\"equity_start\":%.2f}", current_day_key, g_qm_ks_day_start_equity));
   }
}

int QM_KillSwitchClosePositionsByMagic(const long magic)
{
   int closed = 0;
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(magic > 0 && pos_magic != magic)
         continue;

      if(g_qm_ks_trade.PositionClose(ticket))
      {
         ++closed;
         continue;
      }

      QM_LogEvent(QM_ERROR,
                  "KILL_SWITCH_CLOSE_FAILED",
                  StringFormat("{\"ticket\":%I64u,\"retcode\":%u,\"reason\":\"%s\"}",
                               ticket,
                               g_qm_ks_trade.ResultRetcode(),
                               QM_LoggerEscapeJson(g_qm_ks_trade.ResultRetcodeDescription())));
   }

   return closed;
}

bool QM_KillSwitchPortfolioSignalTriggered(double &signal_value, bool &value_present)
{
   signal_value = 0.0;
   value_present = false;

   if(StringLen(g_qm_ks_portfolio_dd_signal_file) == 0)
      return false;
   if(!QM_KillSwitchFileExists(g_qm_ks_portfolio_dd_signal_file))
      return false;

   string first_line = "";
   if(QM_KillSwitchReadFirstLine(g_qm_ks_portfolio_dd_signal_file, first_line))
      value_present = QM_KillSwitchTryParseDouble(first_line, signal_value);

   if(g_qm_ks_portfolio_dd_halt_pct <= 0.0)
      return true;

   if(value_present)
      return (signal_value >= g_qm_ks_portfolio_dd_halt_pct);

   // If a signal file exists but value cannot be parsed, fail-safe to halt.
   return true;
}

void QM_KillSwitchTrip(const string reason, const string details_json)
{
   if(g_qm_ks_halted)
      return;

   g_qm_ks_halted = true;
   g_qm_ks_halt_reason = reason;
   g_qm_ks_halt_day_key = g_qm_ks_day_key;

   const int closed = QM_KillSwitchClosePositionsByMagic(g_qm_ks_magic);
   QM_LogFatal("KILL_SWITCH_TRIGGERED",
               StringFormat("{\"reason\":\"%s\",\"ea_id\":%d,\"magic\":%I64d,\"closed_positions\":%d,\"details\":%s}",
                            QM_LoggerEscapeJson(reason),
                            g_qm_ks_ea_id,
                            g_qm_ks_magic,
                            closed,
                            details_json));
}

bool QM_KillSwitchInit(const int ea_id,
                       const long magic,
                       const double daily_loss_halt_pct,
                       const double portfolio_dd_halt_pct = 0.0,
                       const double per_trade_risk_cap_pct = 1.0,
                       const string portfolio_dd_signal_file = "",
                       const string manual_halt_file = "")
{
   g_qm_ks_ea_id = ea_id;
   g_qm_ks_magic = magic;
   g_qm_ks_daily_loss_halt_pct = MathMax(0.0, daily_loss_halt_pct);
   g_qm_ks_portfolio_dd_halt_pct = MathMax(0.0, portfolio_dd_halt_pct);
   g_qm_ks_per_trade_risk_cap_pct = MathMax(0.0, per_trade_risk_cap_pct);
   g_qm_ks_portfolio_dd_signal_file = QM_KillSwitchTrim(portfolio_dd_signal_file);
   g_qm_ks_manual_halt_file = QM_KillSwitchTrim(manual_halt_file);
   if(StringLen(g_qm_ks_manual_halt_file) == 0 && ea_id > 0)
      g_qm_ks_manual_halt_file = StringFormat("D:\\QM\\data\\halt\\%d.halt", ea_id);
   if(StringLen(g_qm_ks_portfolio_dd_signal_file) == 0 && ea_id > 0)
      g_qm_ks_portfolio_dd_signal_file = "D:\\QM\\data\\halt\\portfolio_dd.signal";

   g_qm_ks_halted = false;
   g_qm_ks_halt_reason = "";
   g_qm_ks_halt_day_key = -1;
   g_qm_ks_day_key = -1;
   g_qm_ks_day_start_equity = 0.0;
   g_qm_ks_unconfigured_logged = false;
   g_qm_ks_initialized = true;
   QM_KillSwitchRefreshBrokerDay();

   QM_LogEvent(QM_INFO,
               "KILL_SWITCH_INIT",
               StringFormat("{\"ea_id\":%d,\"magic\":%I64d,\"daily_loss_halt_pct\":%.4f,\"portfolio_dd_halt_pct\":%.4f,\"per_trade_risk_cap_pct\":%.4f,\"manual_halt_file\":\"%s\",\"portfolio_dd_signal_file\":\"%s\"}",
                            g_qm_ks_ea_id,
                            g_qm_ks_magic,
                            g_qm_ks_daily_loss_halt_pct,
                            g_qm_ks_portfolio_dd_halt_pct,
                            g_qm_ks_per_trade_risk_cap_pct,
                            QM_LoggerEscapeJson(g_qm_ks_manual_halt_file),
                            QM_LoggerEscapeJson(g_qm_ks_portfolio_dd_signal_file)));
   return true;
}

bool QM_KillSwitchIsHalted()
{
   return g_qm_ks_halted;
}

string QM_KillSwitchHaltReason()
{
   return g_qm_ks_halt_reason;
}

double QM_KillSwitchPerTradeRiskCapPct()
{
   return g_qm_ks_per_trade_risk_cap_pct;
}

bool QM_KillSwitchCheck()
{
   if(!g_qm_ks_initialized)
   {
      if(!g_qm_ks_unconfigured_logged)
      {
         QM_LogEvent(QM_WARN, "KILL_SWITCH_UNCONFIGURED", "{}");
         g_qm_ks_unconfigured_logged = true;
      }
      return true;
   }

   QM_KillSwitchRefreshBrokerDay();
   if(g_qm_ks_halted)
      return false;

   if(QM_KillSwitchFileExists(g_qm_ks_manual_halt_file))
   {
      QM_KillSwitchTrip(KS_MANUAL,
                        StringFormat("{\"file\":\"%s\"}", QM_LoggerEscapeJson(g_qm_ks_manual_halt_file)));
      return false;
   }

   double portfolio_signal_value = 0.0;
   bool portfolio_value_present = false;
   if(QM_KillSwitchPortfolioSignalTriggered(portfolio_signal_value, portfolio_value_present))
   {
      if(portfolio_value_present)
      {
         QM_KillSwitchTrip(KS_PORTFOLIO_DD,
                           StringFormat("{\"file\":\"%s\",\"signal_value\":%.6f,\"halt_pct\":%.6f}",
                                        QM_LoggerEscapeJson(g_qm_ks_portfolio_dd_signal_file),
                                        portfolio_signal_value,
                                        g_qm_ks_portfolio_dd_halt_pct));
      }
      else
      {
         QM_KillSwitchTrip(KS_PORTFOLIO_DD,
                           StringFormat("{\"file\":\"%s\",\"signal_value\":null,\"halt_pct\":%.6f}",
                                        QM_LoggerEscapeJson(g_qm_ks_portfolio_dd_signal_file),
                                        g_qm_ks_portfolio_dd_halt_pct));
      }
      return false;
   }

   if(g_qm_ks_daily_loss_halt_pct > 0.0 && g_qm_ks_day_start_equity > 0.0)
   {
      const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
      const double pnl_pct = ((equity_now - g_qm_ks_day_start_equity) / g_qm_ks_day_start_equity) * 100.0;
      if(pnl_pct <= -g_qm_ks_daily_loss_halt_pct)
      {
         QM_KillSwitchTrip(KS_DAILY_LOSS,
                           StringFormat("{\"equity_start\":%.2f,\"equity_now\":%.2f,\"pnl_pct\":%.6f,\"halt_pct\":%.6f}",
                                        g_qm_ks_day_start_equity,
                                        equity_now,
                                        pnl_pct,
                                        g_qm_ks_daily_loss_halt_pct));
         return false;
      }
   }

   return true;
}

#endif // QM_KILL_SWITCH_MQH
