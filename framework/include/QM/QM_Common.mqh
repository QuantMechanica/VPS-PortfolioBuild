#ifndef QM_COMMON_MQH
#define QM_COMMON_MQH

#include <Trade/Trade.mqh>

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"
#include "QM_SeedRNG.mqh"
#include "QM_MagicResolver.mqh"
#include "QM_RiskSizer.mqh"
#include "QM_DSTAware.mqh"
#include "QM_NewsFilter.mqh"
#include "QM_SymbolGuard.mqh"
#include "QM_KillSwitch.mqh"
#include "QM_KillSwitchKS.mqh"
#include "QM_Entry.mqh"
#include "QM_Exit.mqh"
#include "QM_StopRules.mqh"
#include "QM_TradeManagement.mqh"
#include "QM_TM_Grid.mqh"
#include "QM_TradeContext.mqh"
#include "QM_ChartUI.mqh"
#include "QM_Indicators.mqh"
#include "QM_EquityStream.mqh"

int  g_qm_fw_ea_id            = 0;
int  g_qm_fw_magic_slot       = 0;
int  g_qm_fw_magic            = 0;
bool g_qm_fw_timer_active     = false;
bool g_qm_fw_initialized      = false;
bool g_qm_fw_friday_close_enabled = true;
int  g_qm_fw_friday_close_hour_broker = 21;

// Q04 simulated commission (USD per lot, round-trip), applied EA-side.
// The MT5 tester applies NO commission to custom .DWX symbols (they are MT5 Custom
// symbols; the broker groups file does not govern them), so PF from the tester report
// is always gross. For the Q04 commission gate the EA self-accounts a worst-case
// commission per closing deal and emits a structured PF-net so the gate has a realistic
// figure without depending on tester-side commission. Default 0 = no effect (every other
// phase / EA is unchanged until a Q04 setfile sets this input).
input double InpQMSimCommissionPerLot = 0.0;   // Q04: worst-case USD/lot round-trip (0=off)

double g_qm_sim_gross_profit_net = 0.0;
double g_qm_sim_gross_loss_net   = 0.0;
double g_qm_sim_commission_total = 0.0;
long   g_qm_sim_closed_deals     = 0;

// Q08 (Davey) per-trade stream. The framework previously emitted closing-deal data
// only on kill-switch divergence, so Q08's load_trades_from_log() found ZERO trades.
// Accumulate one TRADE_CLOSED JSON line per closing deal and dump to Common\Files at
// shutdown so the Q08 aggregator (and any robustness gate) can read real per-trade P&L.
string g_qm_q08_trade_log = "";

CTrade g_qm_fw_trade;

string QM_FrameworkSlug(const int ea_id)
  {
   return StringFormat("ea-%04d", ea_id);
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

bool QM_FrameworkInit(const int ea_id,
                      const int magic_slot_offset,
                      const double risk_percent,
                      const double risk_fixed,
                      const double portfolio_weight,
                      const QM_NewsMode news_mode,
                      const bool friday_close_enabled = true,
                      const int friday_close_hour_broker = 21,
                      const int news_pause_before_minutes = 30,
                      const int news_pause_after_minutes = 30,
                      const int news_stale_max_hours = 24 * 14,
                      const string news_min_impact = "high",
                      const uint rng_seed = 42,
                      const double stress_reject_probability = 0.0,
                      const QM_NewsTemporalMode news_temporal = QM_NEWS_TEMPORAL_OFF,
                      const QM_NewsComplianceProfile news_compliance = QM_NEWS_COMPLIANCE_NONE)
  {
   if(ea_id <= 0)
      return false;
   // FW3 2026-05-23: central seeded RNG must initialize before any module
   // that consumes randomness (trade-rejection hook, jitter, tie-breaks).
   QM_SeedReset(rng_seed);
   if(portfolio_weight <= 0.0 || portfolio_weight > 1.0)
     {
      Print(EA_INPUT_PORTFOLIO_WEIGHT_OUT_OF_RANGE);
      return false;
     }
   if(!QM_FrameworkValidateRiskInputs(risk_percent, risk_fixed))
      return false;

   g_qm_fw_ea_id = ea_id;
   g_qm_fw_magic_slot = magic_slot_offset;
   g_qm_fw_magic = QM_MagicChecked(ea_id, magic_slot_offset, _Symbol);
   if(g_qm_fw_magic <= 0)
      return false;

   const string slug = QM_FrameworkSlug(ea_id);
   QM_LoggerInit(ea_id, slug, _Symbol, (ENUM_TIMEFRAMES)_Period, g_qm_fw_magic);

   // FW7 2026-05-23 — default to single-symbol guard. Basket / portfolio EAs
   // must call QM_SymbolGuardInit({...}) AFTER QM_FrameworkInit to override
   // with their explicit symbol list. Without an override, any iClose/iTime/
   // Bars/CopyXxx call for a non-_Symbol symbol logs SYMBOL_GUARD_VIOLATION
   // when routed through QM_SymbolAssertOrLog.
   QM_SymbolGuardInitSingle();

   QM_RiskMode mode = QM_RISK_MODE_PERCENT;
   if(risk_fixed > 0.0)
      mode = QM_RISK_MODE_FIXED;
   const double risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
   if(!QM_RiskSizerConfigure(mode, risk_percent, risk_fixed, portfolio_weight, risk_cap_money))
      return false;

   // FW7 2026-05-23 — News lazy-init (OWNER call after Q02 hang triage).
   // Originally QM_NewsInit ran for every EA, opening the calendar files and
   // loading thousands of CSV rows into g_qm_news_events even when no news
   // filter was active. That bricked Q02: every per-tick QM_NewsAllowsTrade2
   // call hit a linear scan over the loaded array. Now we skip the entire
   // calendar load when news is off across all three axes; the per-tick hook
   // takes its early-return path (g_qm_news_active=false) instantly.
   const bool any_news_active = (news_mode != QM_NEWS_OFF) ||
                                 (news_temporal != QM_NEWS_TEMPORAL_OFF) ||
                                 (news_compliance != QM_NEWS_COMPLIANCE_NONE);
   g_qm_news_active = any_news_active;
   if(any_news_active)
     {
      if(!QM_NewsInit("D:\\QM\\data\\news_calendar",
                      news_stale_max_hours,
                      news_pause_before_minutes,
                      news_pause_after_minutes,
                      news_min_impact))
        {
         QM_LogEvent(QM_WARN, SETUP_DATA_MISSING, "{\"component\":\"news_calendar\"}");
         return false;
        }
     }
   else
     {
      QM_LogEvent(QM_INFO, "NEWS_CALENDAR_SKIPPED",
                  "{\"reason\":\"all_news_axes_off\",\"news_mode\":\"OFF\",\"news_temporal\":\"OFF\",\"news_compliance\":\"NONE\"}");
     }

   QM_EntryConfigure(ea_id, news_mode, 20, stress_reject_probability,
                     news_temporal, news_compliance);
   QM_KillSwitchInit(ea_id, g_qm_fw_magic, 3.0, 0.0, 1.0);

   // FW4 2026-05-23 — KS-test kill-switch (Q13 burn-in safety).
   // Loads baseline at `D:/QM/data/baselines/QM5_<ea>_<sym>.json` if present;
   // otherwise stays dormant (pre-Q13 EAs have no baseline file). Live trade
   // window starts empty and fills as OnTradeTransaction delivers closed deals.
   QM_KillSwitchKSInit(ea_id, _Symbol);
   g_qm_fw_friday_close_enabled = friday_close_enabled;
   g_qm_fw_friday_close_hour_broker = MathMin(23, MathMax(0, friday_close_hour_broker));

   if(!QM_ChartUI_Init(ea_id, slug))
      return false;

   // FW6 2026-05-23 — initialise equity snapshot stream (Q08 sub-gate input).
   QM_EquityStreamInit();

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

// FW8 2026-05-23 — once-per-Friday guard. Pre-FW8 every tick from Friday
// hour H to 23:59 hit QM_LogEvent which synchronously FileOpen/Write/Flush/
// Close → 99.95% of all Q02 backtest log volume was redundant FRIDAY_CLOSE
// entries (e.g. QM5_10026 EURUSD Q02: 83 087 of 83 126 lines). Track the
// last broker-day we acted on; subsequent same-day calls return false fast.
int g_qm_fw_friday_close_last_day_key = -1;

bool QM_FrameworkHandleFridayClose()
  {
   if(!QM_FrameworkFridayCloseNow())
      return false;

   // Idempotent per broker-day: only the FIRST tick past the close hour
   // closes positions and logs. Day key = year*1000 + day_of_year.
   const datetime broker_now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(broker_now, tm);
   const int day_key = tm.year * 1000 + tm.day_of_year;
   if(day_key == g_qm_fw_friday_close_last_day_key)
      return true; // already handled this Friday — silent fast return.
   g_qm_fw_friday_close_last_day_key = day_key;

   const int closed = QM_FrameworkCloseAllByMagic((long)g_qm_fw_magic, "friday_close");
   QM_LogEvent(QM_INFO, "FRIDAY_CLOSE", StringFormat("{\"closed\":%d,\"hour\":%d,\"day_key\":%d}",
               closed, g_qm_fw_friday_close_hour_broker, day_key));
   return true;
  }

void QM_FrameworkOnTimer()
  {
   if(!g_qm_fw_initialized)
      return;
   QM_ChartUI_Refresh();
  }

// FW4 2026-05-23 — OnTradeTransaction wrapper.
// MT5 fires OnTradeTransaction on every trade-server event. We care about
// DEAL_ADD transactions for closing deals (entry=OUT, OUT_BY) that belong to
// this EA's magic. When detected, extract the deal's net profit (including
// swap and commission), feed it to the KS kill-switch live window, and run
// the KS-check. If divergence is significant, close all positions and halt.
void QM_FrameworkOnTradeTransaction(const MqlTradeTransaction &trans,
                                    const MqlTradeRequest &request,
                                    const MqlTradeResult &result)
  {
   if(!g_qm_fw_initialized)
      return;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;

   const long deal_magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(deal_magic != g_qm_fw_magic)
      return;

   const long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
      return;  // only closing deals contribute to the live distribution

   const double profit     = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   const double swap       = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   const double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   const double net        = profit + swap + commission;

   // Q08 per-trade stream: one TRADE_CLOSED line per closing deal (real net P&L).
   const double q08_vol = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   const long   q08_t   = (long)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   g_qm_q08_trade_log += StringFormat(
      "{\"event\":\"TRADE_CLOSED\",\"time\":%I64d,\"net\":%.2f,\"profit\":%.2f,\"swap\":%.2f,\"commission\":%.2f,\"volume\":%.2f}\r\n",
      q08_t, net, profit, swap, commission, q08_vol);

   // Q04 EA-side simulated commission: accumulate a PF-net that reflects a worst-case
   // USD/lot round-trip charge the tester does not apply to custom symbols. Charged once
   // per closing deal on its volume (round-trip per lot). Pure accounting — does not
   // alter live trading or the tester books; reported in QM_FrameworkShutdown.
   if(InpQMSimCommissionPerLot > 0.0)
     {
      const double sim_vol  = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
      const double sim_cost = InpQMSimCommissionPerLot * sim_vol;
      const double net_after = net - sim_cost;
      g_qm_sim_commission_total += sim_cost;
      g_qm_sim_closed_deals++;
      if(net_after >= 0.0)
         g_qm_sim_gross_profit_net += net_after;
      else
         g_qm_sim_gross_loss_net   += -net_after;
     }

   QM_KillSwitchKSOnTradeClosed(net);

   if(QM_KillSwitchKSCheck())
     {
      QM_FrameworkCloseAllByMagic((long)g_qm_fw_magic, "ks_distribution_divergence");
      // The fatal log inside QM_KillSwitchKSCheck already carries the d / d_crit / n.
      // Manual halt-flag is the most reliable cross-restart suppression.
      const string halt_path = StringFormat("D:\\QM\\data\\halt\\%d.halt", g_qm_fw_ea_id);
      int handle = FileOpen(halt_path, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(handle != INVALID_HANDLE)
        {
         FileWrite(handle, "ks_distribution_divergence");
         FileClose(handle);
        }
     }
  }

void QM_FrameworkShutdown()
  {
   if(g_qm_fw_timer_active)
     {
      EventKillTimer();
      g_qm_fw_timer_active = false;
     }

   QM_ChartUI_Shutdown();
   QM_IndicatorsShutdown();
   QM_EquityStreamShutdown();
   if(g_qm_fw_initialized && InpQMSimCommissionPerLot > 0.0 && g_qm_sim_closed_deals > 0)
     {
      const double pf_net = (g_qm_sim_gross_loss_net > 0.0)
                            ? g_qm_sim_gross_profit_net / g_qm_sim_gross_loss_net : 0.0;
      const double net_profit = g_qm_sim_gross_profit_net - g_qm_sim_gross_loss_net;
      const string payload = StringFormat(
         "{\"sim_commission_per_lot\":%.2f,\"pf_net\":%.4f,\"net_profit\":%.2f,\"gross_profit_net\":%.2f,\"gross_loss_net\":%.2f,\"closed_deals\":%I64d,\"sim_commission_total\":%.2f}",
         InpQMSimCommissionPerLot, pf_net, net_profit,
         g_qm_sim_gross_profit_net, g_qm_sim_gross_loss_net,
         g_qm_sim_closed_deals, g_qm_sim_commission_total);
      QM_LogEvent(QM_INFO, "Q04_SIM_COMMISSION", payload);
      // Also write a deterministic per-(ea,symbol) result file in Common\Files so the
      // Q04 runner can read PF-net back without parsing the rotating tester journal
      // or hunting the tester-agent sandbox log. q04_walkforward.py deletes this before
      // each fold and reads it after (folds run sequentially per ea/symbol).
      string q04_sym = _Symbol;
      StringReplace(q04_sym, ".", "_");
      const string q04_path = StringFormat("QM\\q04_sim\\%d_%s.json", g_qm_fw_ea_id, q04_sym);
      int q04_fh = FileOpen(q04_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(q04_fh != INVALID_HANDLE)
        {
         FileWriteString(q04_fh, payload);
         FileClose(q04_fh);
        }
     }
   // Q08 per-trade stream: dump the accumulated TRADE_CLOSED lines to a deterministic
   // Common\Files path so the Davey aggregator can read real per-trade P&L (the tester
   // writes the EA's own log to the agent sandbox, which Q08 can't find). Always written
   // when trades occurred — Q08 runs its own backtest, reads this, then clears/re-runs.
   if(g_qm_fw_initialized && StringLen(g_qm_q08_trade_log) > 0)
     {
      string q08_sym = _Symbol;
      StringReplace(q08_sym, ".", "_");
      const string q08_path = StringFormat("QM\\q08_trades\\%d_%s.jsonl", g_qm_fw_ea_id, q08_sym);
      int q08_fh = FileOpen(q08_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(q08_fh != INVALID_HANDLE)
        {
         FileWriteString(q08_fh, g_qm_q08_trade_log);
         FileClose(q08_fh);
        }
     }
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
