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
#include "QM_Signals.mqh"
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
// Accumulate TRADE_CLOSED JSON lines and flush to Common\Files INCREMENTALLY (bounded
// buffer) so the Q08 aggregator can read real per-trade P&L without OOMing the tester on
// high-trade EAs. 2026-07-10 fix: the line-631 unbounded `+=` string grew until MT5 logged
// "out of memory in 'QM_Common.mqh' (631,23)" (QM5_11476, 1968 trades) and emitted 0 rows.
string g_qm_q08_trade_log = "";
bool   g_qm_q08_stream_started = false;  // false => truncate file on the first flush this run

CTrade g_qm_fw_trade;

struct QM_PositionMaeState
  {
   ulong    position_id;
   datetime entry_time;
   double   min_floating_pnl;
  };

QM_PositionMaeState g_qm_q08_mae_states[];

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
   g_qm_q08_trade_log = "";
   g_qm_q08_stream_started = false;
   ArrayResize(g_qm_q08_mae_states, 0);

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
   // Loads baseline at `QM\baselines\QM5_<ea>_<sym>.json` (sandbox: terminal
   // MQL5\Files, then Common\Files) if present; otherwise stays dormant
   // (pre-Q13 EAs have no baseline file). Live trade window starts empty and
   // fills as OnTradeTransaction delivers closed deals.
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

// 2026-07-05 — per-trade risk-cap override for prop-account books (Round25 FTMO
// Two-Speed, OWNER-ratified). QM_FrameworkInit hard-caps per-trade risk money at
// 1% of account equity (risk_cap_money above); prop legs sized above 1% of the
// account need a wider cap. Call AFTER QM_FrameworkInit. cap_pct=1.0 keeps the
// framework default; bounds (0, 5.0] are a hard safety ceiling (FTMO daily limit).
bool QM_FrameworkSetRiskCapPct(const double cap_pct)
  {
   if(!g_qm_fw_initialized)
      return false;
   if(cap_pct <= 0.0 || cap_pct > 5.0)
      return false;
   const double cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * (cap_pct / 100.0);
   g_qm_risk_per_trade_cap_money = cap_money;
   if(MathAbs(cap_pct - 1.0) > 1e-9)
      QM_LogEvent(QM_INFO, "RISK_CAP_OVERRIDE",
                  StringFormat("{\"cap_pct\":%.4f,\"cap_money\":%.2f}", cap_pct, cap_money));
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

bool QM_FrameworkOwnsMagicSymbol(const long magic, const string symbol)
  {
   if(magic == (long)g_qm_fw_magic)
      return true;

   if(!QM_SymbolGuardIsBasket())
      return false;

   if(g_qm_fw_ea_id <= 0)
      return false;

   const long base_magic = (long)g_qm_fw_ea_id * 10000L;
   if(magic < base_magic || magic > base_magic + QM_MAGIC_SLOT_MAX)
      return false;

   const int slot = (int)(magic - base_magic);
   if(!QM_MagicRegistered(g_qm_fw_ea_id, slot))
      return false;

   if(symbol != "" && !QM_SymbolAllowed(symbol))
      return false;

   return true;
  }

int QM_FrameworkMaeFind(const ulong position_id)
  {
   const int count = ArraySize(g_qm_q08_mae_states);
   for(int i = 0; i < count; ++i)
     {
      if(g_qm_q08_mae_states[i].position_id == position_id)
         return i;
     }
   return -1;
  }

void QM_FrameworkMaeRemoveIndex(const int index)
  {
   const int count = ArraySize(g_qm_q08_mae_states);
   if(index < 0 || index >= count)
      return;
   for(int i = index; i < count - 1; ++i)
      g_qm_q08_mae_states[i] = g_qm_q08_mae_states[i + 1];
   ArrayResize(g_qm_q08_mae_states, count - 1);
  }

void QM_FrameworkMaeUpsert(const ulong position_id,
                           const datetime entry_time,
                           const double floating_pnl)
  {
   if(position_id == 0)
      return;

   const double mae = MathMin(0.0, floating_pnl);
   int index = QM_FrameworkMaeFind(position_id);
   if(index < 0)
     {
      const int count = ArraySize(g_qm_q08_mae_states);
      ArrayResize(g_qm_q08_mae_states, count + 1);
      index = count;
      g_qm_q08_mae_states[index].position_id = position_id;
      g_qm_q08_mae_states[index].entry_time = entry_time;
      g_qm_q08_mae_states[index].min_floating_pnl = mae;
      return;
     }

   if(entry_time > 0 && g_qm_q08_mae_states[index].entry_time <= 0)
      g_qm_q08_mae_states[index].entry_time = entry_time;
   if(mae < g_qm_q08_mae_states[index].min_floating_pnl)
      g_qm_q08_mae_states[index].min_floating_pnl = mae;
  }

bool QM_FrameworkMaePositionStillOpen(const ulong position_id)
  {
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) != position_id)
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(QM_FrameworkOwnsMagicSymbol(magic, symbol))
         return true;
     }
   return false;
  }

void QM_FrameworkTrackOpenPositionMae()
  {
   if(!g_qm_fw_initialized)
      return;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;

      const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const double floating_pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      QM_FrameworkMaeUpsert(position_id, entry_time, floating_pnl);
     }

   for(int index = ArraySize(g_qm_q08_mae_states) - 1; index >= 0; --index)
     {
      if(!QM_FrameworkMaePositionStillOpen(g_qm_q08_mae_states[index].position_id))
         QM_FrameworkMaeRemoveIndex(index);
     }
  }

void QM_FrameworkMaeRecordEntryDeal(const ulong position_id,
                                    const datetime entry_time)
  {
   QM_FrameworkMaeUpsert(position_id, entry_time, 0.0);
  }

datetime QM_FrameworkMaeFindEntryTimeInHistory(const ulong position_id,
                                               const datetime fallback_time)
  {
   if(position_id == 0)
      return fallback_time;

   const datetime to_time = (fallback_time > 0 ? fallback_time : TimeCurrent()) + 60;
   if(!HistorySelect(0, to_time))
      return fallback_time;

   datetime found = 0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID) != position_id)
         continue;
      const long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;

      const datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(deal_time > 0 && (found == 0 || deal_time < found))
         found = deal_time;
     }

   return (found > 0 ? found : fallback_time);
  }

bool QM_FrameworkMaeLookup(const ulong position_id,
                           datetime &entry_time,
                           double &mae_acct)
  {
   entry_time = 0;
   mae_acct = 0.0;
   const int index = QM_FrameworkMaeFind(position_id);
   if(index < 0)
      return false;

   entry_time = g_qm_q08_mae_states[index].entry_time;
   mae_acct = MathMin(0.0, g_qm_q08_mae_states[index].min_floating_pnl);
   return true;
  }

QM_ExitReason QM_FrameworkExitReasonFromText(const string reason)
  {
   if(reason == "friday_close")
      return QM_EXIT_FRIDAY_CLOSE;
   if(reason == "ks_distribution_divergence")
      return QM_EXIT_KILLSWITCH;
   return QM_EXIT_STRATEGY;
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

      if(QM_TM_ClosePosition(ticket, QM_FrameworkExitReasonFromText(reason)))
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

int QM_FrameworkCloseAllOwnedPositions(const string reason)
  {
   if(!QM_SymbolGuardIsBasket())
      return QM_FrameworkCloseAllByMagic((long)g_qm_fw_magic, reason);

   int closed = 0;
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;

      if(QM_TM_ClosePosition(ticket, QM_FrameworkExitReasonFromText(reason)))
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

   const int closed = QM_FrameworkCloseAllOwnedPositions("friday_close");
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

bool QM_FrameworkSymbolPrice(const string symbol, double &price)
  {
   price = 0.0;
   if(SymbolInfoDouble(symbol, SYMBOL_BID, price) && price > 0.0)
      return true;
   if(SymbolInfoDouble(symbol, SYMBOL_LAST, price) && price > 0.0)
      return true;
   if(SymbolInfoDouble(symbol, SYMBOL_ASK, price) && price > 0.0)
      return true;
   return false;
  }

bool QM_FrameworkCurrencyRateToAccount(const string from_currency, const string account_currency, double &rate)
  {
   rate = 1.0;
   if(from_currency == "" || account_currency == "" || from_currency == account_currency)
      return true;

   double px = 0.0;
   const string direct = from_currency + account_currency;
   if(QM_FrameworkSymbolPrice(direct, px) || QM_FrameworkSymbolPrice(direct + ".DWX", px))
     {
      rate = px;
      return true;
     }

   const string inverse = account_currency + from_currency;
   if((QM_FrameworkSymbolPrice(inverse, px) || QM_FrameworkSymbolPrice(inverse + ".DWX", px)) && px > 0.0)
     {
      rate = 1.0 / px;
      return true;
     }

   return false;
  }

double QM_FrameworkDealNotionalAccount(const ulong deal_ticket, const string symbol, const double volume, const double close_price)
  {
   double contract_size = 0.0;
   if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE, contract_size) || contract_size <= 0.0)
      contract_size = 1.0;

   const double raw_notional = volume * contract_size * close_price;
   const string profit_currency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   const string account_currency = AccountInfoString(ACCOUNT_CURRENCY);

   double rate = 1.0;
   if(QM_FrameworkCurrencyRateToAccount(profit_currency, account_currency, rate))
      return raw_notional * rate;

   QM_LogEvent(QM_WARN, "Q08_NOTIONAL_CONVERSION_FALLBACK",
               StringFormat("{\"deal\":%I64u,\"symbol\":\"%s\",\"profit_currency\":\"%s\",\"account_currency\":\"%s\"}",
                            deal_ticket,
                            QM_LoggerEscapeJson(symbol),
                            QM_LoggerEscapeJson(profit_currency),
                            QM_LoggerEscapeJson(account_currency)));
   return raw_notional;
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
   const string q08_symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   if(!QM_FrameworkOwnsMagicSymbol(deal_magic, q08_symbol))
      return;

   const long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   const ulong q08_position_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(entry == DEAL_ENTRY_IN)
     {
      const datetime deal_time = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
      QM_FrameworkMaeRecordEntryDeal(q08_position_id, deal_time);
      return;
     }
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
      return;  // only closing deals contribute to the live distribution

   const double profit     = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   const double swap       = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   const double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   const double net        = profit + swap + commission;

   // Q08 per-trade stream: one TRADE_CLOSED line per closing deal (real net P&L).
   const double q08_vol = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   const double q08_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   const double q08_notional = QM_FrameworkDealNotionalAccount(trans.deal, q08_symbol, q08_vol, q08_price);
   const long   q08_t   = (long)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   datetime q08_entry_time = 0;
   double q08_mae_acct = 0.0;
   QM_FrameworkMaeLookup(q08_position_id, q08_entry_time, q08_mae_acct);
   q08_entry_time = QM_FrameworkMaeFindEntryTimeInHistory(q08_position_id, q08_entry_time > 0 ? q08_entry_time : (datetime)q08_t);
   q08_mae_acct = MathMin(q08_mae_acct, net);
   g_qm_q08_trade_log += StringFormat(
      "{\"event\":\"TRADE_CLOSED\",\"time\":%I64d,\"entry_time\":%I64d,\"mae_acct\":%.2f,\"net\":%.2f,\"profit\":%.2f,\"swap\":%.2f,\"commission\":%.2f,\"volume\":%.2f,\"notional\":%.2f,\"symbol\":\"%s\"}\r\n",
      q08_t, (long)q08_entry_time, q08_mae_acct, net, profit, swap, commission, q08_vol, q08_notional, QM_LoggerEscapeJson(q08_symbol));
   QM_FrameworkMaeRemoveIndex(QM_FrameworkMaeFind(q08_position_id));
   // Bounded emission: flush to file once the buffer grows past ~32 KB so the in-memory
   // string never accumulates a whole high-trade backtest (2026-07-10 OOM fix).
   if(StringLen(g_qm_q08_trade_log) >= 32768)
      QM_FrameworkQ08Flush();

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
      QM_FrameworkCloseAllOwnedPositions("ks_distribution_divergence");
      // The fatal log inside QM_KillSwitchKSCheck already carries the d / d_crit / n.
      // Manual halt-flag is the most reliable cross-restart suppression.
      // H2 fix (2026-07-05): sandbox-relative path (the old D:\QM\... literal was
      // invalid inside the MQL5 file sandbox — the write silently failed forever).
      const string halt_path = StringFormat("QM\\halt\\%d.halt", g_qm_fw_ea_id);
      int handle = FileOpen(halt_path, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(handle != INVALID_HANDLE)
        {
         FileWrite(handle, "ks_distribution_divergence");
         FileClose(handle);
        }
     }
  }

// Flush the buffered Q08 TRADE_CLOSED lines to the deterministic Common\Files path.
// First flush of a run truncates (fresh file); later flushes append. Called both mid-run
// (bounded buffer) and at shutdown for the remainder. Emits the identical per-trade JSONL
// as before; only the write cadence changed (2026-07-10 OOM fix).
void QM_FrameworkQ08Flush()
  {
   if(!g_qm_fw_initialized || StringLen(g_qm_q08_trade_log) == 0)
      return;
   string q08_sym = _Symbol;
   StringReplace(q08_sym, ".", "_");
   const string q08_path = StringFormat("QM\\q08_trades\\%d_%s.jsonl", g_qm_fw_ea_id, q08_sym);
   const int base_flags = FILE_TXT | FILE_ANSI | FILE_COMMON;
   int q08_fh;
   if(g_qm_q08_stream_started)
     {
      q08_fh = FileOpen(q08_path, FILE_READ | FILE_WRITE | base_flags);
      if(q08_fh != INVALID_HANDLE)
         FileSeek(q08_fh, 0, SEEK_END);
     }
   else
      q08_fh = FileOpen(q08_path, FILE_WRITE | base_flags);  // truncate fresh on first flush
   if(q08_fh != INVALID_HANDLE)
     {
      FileWriteString(q08_fh, g_qm_q08_trade_log);
      FileClose(q08_fh);
      g_qm_q08_stream_started = true;
      g_qm_q08_trade_log = "";
     }
   else
      QM_LogEvent(QM_WARN, "Q08_STREAM_WRITE_FAILED",
                  StringFormat("{\"path\":\"%s\",\"error\":%d}",
                               QM_LoggerEscapeJson(q08_path), GetLastError()));
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
      else
         QM_LogEvent(QM_WARN, "Q04_RESULT_WRITE_FAILED",
                     StringFormat("{\"path\":\"%s\",\"error\":%d}",
                                  QM_LoggerEscapeJson(q04_path), GetLastError()));
     }
   // Q08 per-trade stream: flush the remaining buffered TRADE_CLOSED lines to the
   // deterministic Common\Files path so the Davey aggregator can read real per-trade P&L.
   // Bounded/incremental emission (see QM_FrameworkQ08Flush) — the old single unbounded
   // write OOMed the tester on high-trade EAs (2026-07-10 fix). If no mid-run flush
   // happened this run, this call truncates+writes exactly as before.
   QM_FrameworkQ08Flush();
   ArrayResize(g_qm_q08_mae_states, 0);
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
