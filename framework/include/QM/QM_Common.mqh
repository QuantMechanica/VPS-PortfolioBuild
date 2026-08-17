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
#include "QM_RuntimeExecutionContract.mqh"
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

// Fail-closed input contracts must also be diagnosable.  A bare
// INIT_PARAMETERS_INCORRECT leaves the tester journal unable to distinguish a
// deliberate input rejection from missing history.  These helpers preserve the
// exact guard while emitting the predicate and observed/required values before
// the caller returns INIT_PARAMETERS_INCORRECT.
bool QM_InputRequireLong(const string predicate,
                         const long observed,
                         const long required)
  {
   if(observed == required)
      return true;
   PrintFormat("QM_INPUT_REJECT predicate=%s observed=%I64d required=%I64d",
               predicate, observed, required);
   return false;
  }

bool QM_InputRequireDouble(const string predicate,
                           const double observed,
                           const double required,
                           const double tolerance)
  {
   if(MathAbs(observed - required) <= tolerance)
      return true;
   PrintFormat("QM_INPUT_REJECT predicate=%s observed=%s required=%s tolerance=%s",
               predicate,
               DoubleToString(observed, 16),
               DoubleToString(required, 16),
               DoubleToString(tolerance, 16));
   return false;
  }

bool QM_InputRequireString(const string predicate,
                           const string observed,
                           const string required)
  {
   if(observed == required)
      return true;
   PrintFormat("QM_INPUT_REJECT predicate=%s observed='%s' required='%s'",
               predicate, observed, required);
   return false;
  }

// Card-v2 execution contract. Friday close used to be an implicit framework
// default, which made source-defined exits and the executable strategy diverge
// silently. Every migrated EA must now state whether Friday close is disabled,
// comes from the approved Card, or is an explicit framework override that
// requires its own qualification evidence.
enum QM_FridayCloseContractMode
  {
   QM_FRIDAY_CLOSE_UNDECLARED        = 0,
   QM_FRIDAY_CLOSE_DISABLED          = 1,
   QM_FRIDAY_CLOSE_CARD_RULE         = 2,
   QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE = 3
  };

// Opt-in sub-strategy identities for one symbol-master instance. The host
// magic above remains the default for every legacy EA; this array is populated
// only by explicit QM_MagicFor calls after framework initialization.
struct QM_FrameworkMagicContext
  {
   int    ea_id;
   int    slot;
   int    magic;
   string symbol;
  };

QM_FrameworkMagicContext g_qm_fw_magic_contexts[];

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
int    g_qm_q08_fh = INVALID_HANDLE;      // persistent Q08 stream handle: open once (truncate) per run, append, close at shutdown

CTrade g_qm_fw_trade;

struct QM_PositionMaeState
  {
   ulong    position_id;
   datetime entry_time;
   double   min_floating_pnl;
  };

QM_PositionMaeState g_qm_q08_mae_states[];       // MAE of currently-open positions (swept on close)
QM_PositionMaeState g_qm_q08_mae_closed[];       // archived MAE of closed positions, kept for the OnDeinit history walk

// Authoritative money ownership for the legacy Q08 stream. A position can have
// multiple IN deals (scale-ins) and multiple OUT / OUT_BY deals (partial exits),
// so entry-side commission cannot be recovered from a closing deal in isolation.
struct QM_FrameworkQ08Lifecycle
  {
   ulong    position_id;
   long     magic;
   string   symbol;
   string   side;
   datetime entry_time;
   double   entry_volume;
   double   entry_price_volume_sum;
   double   entry_commission;
   double   exit_volume;
   double   validated_entry_volume;
   double   validated_exit_volume;
   double   allocated_exit_volume;
   double   allocated_entry_commission;
   int      entry_count;
   int      exit_count;
  };

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

// Internal common initializer. Callers must use QM_FrameworkInit or
// QM_FrameworkInitV3; the runtime state must already be armed by one of them.
bool QM_FrameworkInitCoreAfterRuntimeStateArmed(const int ea_id,
                                                const int magic_slot_offset,
                                                const double risk_percent,
                                                const double risk_fixed,
                                                const double portfolio_weight,
                                                const QM_NewsMode news_mode,
                                                const bool friday_close_enabled,
                                                const int friday_close_hour_broker,
                                                const int news_pause_before_minutes,
                                                const int news_pause_after_minutes,
                                                const int news_stale_max_hours,
                                                const string news_min_impact,
                                                const uint rng_seed,
                                                const double stress_reject_probability,
                                                const QM_NewsTemporalMode news_temporal,
                                                const QM_NewsComplianceProfile news_compliance)
  {
   const bool legacy_armed = (g_qm_runtime_execution_initialization_started &&
                              g_qm_runtime_execution_state == QM_RUNTIME_EXECUTION_LEGACY_UNDECLARED);
   const bool v3_armed = (g_qm_runtime_execution_initialization_started &&
                          g_qm_runtime_execution_state == QM_RUNTIME_EXECUTION_REQUIRED_BLOCKED &&
                          g_qm_runtime_execution_block_reason == "CONTRACT_BIND_PENDING");
   if(!legacy_armed && !v3_armed)
     {
      QM_RuntimeExecutionBlock("FRAMEWORK_CORE_WITHOUT_ARM_REFUSED");
      return false;
     }
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
   ArrayResize(g_qm_fw_magic_contexts, 0);
   g_qm_q08_trade_log = "";
   if(g_qm_q08_fh != INVALID_HANDLE)
     {
      FileClose(g_qm_q08_fh);
      g_qm_q08_fh = INVALID_HANDLE;
     }
   ArrayResize(g_qm_q08_mae_states, 0);
   ArrayResize(g_qm_q08_mae_closed, 0);

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
   // 2026-07-20 framework audit P0.2 — the PERCENT-mode per-trade cap follows
   // live equity (cap_pct) instead of a money amount frozen at init-time
   // equity: a frozen cap silently de-compounds percent sizing and shifts on
   // every re-init. The money value stays as the FIXED-mode rail so RISK_FIXED
   // backtests remain bit-identical to the historical gate evidence.
   const double risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
   if(!QM_RiskSizerConfigure(mode, risk_percent, risk_fixed, portfolio_weight, risk_cap_money))
      return false;
   QM_RiskSizerSetCapPct(1.0);

   // FW7 2026-05-23 — News lazy-init (OWNER call after Q02 hang triage).
   // Originally QM_NewsInit ran for every EA, opening the calendar files and
   // loading thousands of CSV rows into g_qm_news_events even when no news
   // filter was active. That bricked Q02: every per-tick QM_NewsAllowsTrade2
   // call hit a linear scan over the loaded array. Now we skip the entire
   // calendar load when news is off across all three axes; the per-tick hook
   // takes its early-return path (g_qm_news_active=false) instantly.
   // A sealed Q09 bundle is an effective tester input even for CONTROL_OFF
   // cells.  Authenticate it during init while preserving the legacy lazy-load
   // fast path for empty inputs and every live attach.
   const bool tester_bundle_requested =
      (MQLInfoInteger(MQL_TESTER) != 0 && QM_NewsTesterBundleInputsRequested());
   const bool any_news_active = (news_mode != QM_NEWS_OFF) ||
                                 (news_temporal != QM_NEWS_TEMPORAL_OFF) ||
                                 (news_compliance != QM_NEWS_COMPLIANCE_NONE) ||
                                 tester_bundle_requested;
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
                      news_temporal, news_compliance, g_qm_fw_magic);
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

// Legacy initializer. It is intentionally unable to downgrade an armed or
// READY V3 execution contract back to the permissive legacy state.
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
   if(!QM_RuntimeExecutionBeginLegacyInitialization())
      return false;
   return QM_FrameworkInitCoreAfterRuntimeStateArmed(ea_id,
                                                      magic_slot_offset,
                                                      risk_percent,
                                                      risk_fixed,
                                                      portfolio_weight,
                                                      news_mode,
                                                      friday_close_enabled,
                                                      friday_close_hour_broker,
                                                      news_pause_before_minutes,
                                                      news_pause_after_minutes,
                                                      news_stale_max_hours,
                                                      news_min_impact,
                                                      rng_seed,
                                                      stress_reject_probability,
                                                      news_temporal,
                                                      news_compliance);
  }

// Card-v3 cohort initializer. Unlike the legacy initializer, this function
// cannot return success unless one immutable execution bundle matches the
// actual account/server/symbol/timeframe/magic identity. FTMO contracts also
// require the account-wide governor; standard and basket entry paths check its
// fresh snapshot on every attempted entry and apply only a reducing scale.
bool QM_FrameworkInitV3(const QM_RuntimeExecutionContract &execution_contract,
                        const long expected_source_generation,
                        const int ea_id,
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
   if(!QM_RuntimeExecutionBeginRequiredInitialization())
      return false;

   if(!QM_FrameworkInitCoreAfterRuntimeStateArmed(ea_id,
                                                  magic_slot_offset,
                                                  risk_percent,
                                                  risk_fixed,
                                                  portfolio_weight,
                                                  news_mode,
                                                  friday_close_enabled,
                                                  friday_close_hour_broker,
                                                  news_pause_before_minutes,
                                                  news_pause_after_minutes,
                                                  news_stale_max_hours,
                                                  news_min_impact,
                                                  rng_seed,
                                                  stress_reject_probability,
                                                  news_temporal,
                                                  news_compliance))
     {
      QM_RuntimeExecutionBlock("FRAMEWORK_INITIALIZATION_FAILED");
      return false;
     }

   if(!QM_RuntimeExecutionBindRequired(execution_contract,
                                       expected_source_generation,
                                       g_qm_fw_ea_id,
                                       g_qm_fw_magic,
                                       _Symbol,
                                       (ENUM_TIMEFRAMES)_Period,
                                       AccountInfoInteger(ACCOUNT_LOGIN),
                                       AccountInfoString(ACCOUNT_SERVER),
                                       QM_MagicRegistryHash()))
     {
      QM_LogEvent(QM_ERROR,
                  "RUNTIME_EXECUTION_CONTRACT_BLOCKED",
                  StringFormat("{\"contract_id\":\"%s\",\"reason\":\"%s\"}",
                               QM_LoggerEscapeJson(execution_contract.contract_id),
                               QM_LoggerEscapeJson(g_qm_runtime_execution_block_reason)));
      return false;
     }

   QM_LogEvent(QM_INFO,
               "RUNTIME_EXECUTION_CONTRACT_READY",
               StringFormat("{\"contract_id\":\"%s\",\"generation\":%I64d,\"bundle_sha256\":\"%s\",\"rulepack_sha256\":\"%s\",\"target\":\"%s\"}",
                            QM_LoggerEscapeJson(execution_contract.contract_id),
                            execution_contract.generation,
                            execution_contract.execution_bundle_sha256,
                            execution_contract.target_rulepack_sha256,
                            execution_contract.target));
   return true;
  }

// Fail-closed runtime binding for the Card-v2 execution contract. Call this in
// OnInit immediately after QM_FrameworkInit. `declaration` is deliberately
// required for framework overrides so a global safety policy can never mutate
// a strategy without leaving a machine-searchable reason in source and logs.
bool QM_FrameworkDeclareExecutionContract(
   const ENUM_TIMEFRAMES expected_chart_tf,
   const QM_FridayCloseContractMode friday_mode,
   const string declaration)
  {
   if(!g_qm_fw_initialized)
     {
      Print(EA_EXECUTION_CONTRACT_UNDECLARED);
      return false;
     }

   if((ENUM_TIMEFRAMES)_Period != expected_chart_tf)
     {
      QM_LogEvent(QM_ERROR,
                  EA_INPUT_TIMEFRAME_MISMATCH,
                  StringFormat("{\"expected_tf\":%d,\"actual_tf\":%d}",
                               (int)expected_chart_tf,
                               (int)_Period));
      return false;
     }

   if(friday_mode == QM_FRIDAY_CLOSE_UNDECLARED)
     {
      QM_LogEvent(QM_ERROR,
                  EA_EXECUTION_CONTRACT_UNDECLARED,
                  "{\"field\":\"friday_close\"}");
      return false;
     }

   const bool contract_enables_friday =
      (friday_mode == QM_FRIDAY_CLOSE_CARD_RULE ||
       friday_mode == QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE);
   if(contract_enables_friday != g_qm_fw_friday_close_enabled)
     {
      QM_LogEvent(QM_ERROR,
                  EA_EXECUTION_CONTRACT_MISMATCH,
                  StringFormat("{\"field\":\"friday_close\",\"mode\":%d,\"enabled\":%s}",
                               (int)friday_mode,
                               g_qm_fw_friday_close_enabled ? "true" : "false"));
      return false;
     }

   if(friday_mode == QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE && StringLen(declaration) == 0)
     {
      QM_LogEvent(QM_ERROR,
                  EA_EXECUTION_CONTRACT_UNDECLARED,
                  "{\"field\":\"friday_close_override_reason\"}");
      return false;
     }

   const QM_LogLevel level =
      (friday_mode == QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE) ? QM_WARN : QM_INFO;
   QM_LogEvent(level,
               "EXECUTION_CONTRACT",
               StringFormat("{\"chart_tf\":%d,\"friday_mode\":%d,\"friday_enabled\":%s,\"friday_hour\":%d,\"declaration\":\"%s\"}",
                            (int)expected_chart_tf,
                            (int)friday_mode,
                            g_qm_fw_friday_close_enabled ? "true" : "false",
                            g_qm_fw_friday_close_hour_broker,
                            QM_LoggerEscapeJson(declaration)));
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
   // audit P0.2: the pct is authoritative for PERCENT sizing (live-following);
   // cap_money remains the FIXED-mode rail and a reference value in the log.
   const double cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * (cap_pct / 100.0);
   g_qm_risk_per_trade_cap_money = cap_money;
   QM_RiskSizerSetCapPct(cap_pct);
   if(MathAbs(cap_pct - 1.0) > 1e-9)
      QM_LogEvent(QM_INFO, "RISK_CAP_OVERRIDE",
                  StringFormat("{\"cap_pct\":%.4f,\"cap_money\":%.2f}", cap_pct, cap_money));
   return true;
  }

int QM_FrameworkMagic()
  {
   return g_qm_fw_magic;
  }

// Resolve and remember an original strategy identity for this single-symbol
// framework instance. Binding both resolution and ownership to _Symbol keeps
// the context identical to the symbol used by QM_Entry.
int QM_MagicFor(const int ea_id, const int slot)
  {
   // Context ownership is part of this API's contract. Pure pre-init
   // resolution remains available through QM_MagicChecked; fail here rather
   // than return a magic that q08/Friday-close/kill-switch do not own.
   if(!g_qm_fw_initialized)
      return -1;

   const string context_symbol = _Symbol;
   const int magic = QM_MagicChecked(ea_id, slot, context_symbol);
   if(magic <= 0)
      return -1;

   // Re-resolving the host identity needs no additional framework context.
   if(magic == g_qm_fw_magic)
      return QM_KillSwitchRegisterMagic((long)magic) ? magic : -1;

   const int count = ArraySize(g_qm_fw_magic_contexts);
   for(int i = 0; i < count; ++i)
     {
      if(g_qm_fw_magic_contexts[i].magic == magic &&
         g_qm_fw_magic_contexts[i].symbol == context_symbol)
         return QM_KillSwitchRegisterMagic((long)magic) ? magic : -1;
     }

   if(ArrayResize(g_qm_fw_magic_contexts, count + 1) != count + 1)
      return -1;
   g_qm_fw_magic_contexts[count].ea_id = ea_id;
   g_qm_fw_magic_contexts[count].slot = slot;
   g_qm_fw_magic_contexts[count].magic = magic;
   g_qm_fw_magic_contexts[count].symbol = context_symbol;
   if(!QM_KillSwitchRegisterMagic((long)magic))
     {
      ArrayResize(g_qm_fw_magic_contexts, count);
      return -1;
     }
   return magic;
  }

int QM_FrameworkRegisterMagicSymbol(const int ea_id,
                                    const int slot,
                                    const string context_symbol)
  {
   if(!g_qm_fw_initialized)
      return -1;

   if(context_symbol == "")
      return -1;
   const int magic = QM_MagicChecked(ea_id, slot, context_symbol);
   if(magic <= 0)
      return -1;

   if(magic == g_qm_fw_magic)
      return QM_KillSwitchRegisterMagic((long)magic) ? magic : -1;

   const int count = ArraySize(g_qm_fw_magic_contexts);
   for(int i = 0; i < count; ++i)
     {
      if(g_qm_fw_magic_contexts[i].magic == magic &&
         g_qm_fw_magic_contexts[i].symbol == context_symbol)
         return QM_KillSwitchRegisterMagic((long)magic) ? magic : -1;
     }

   if(ArrayResize(g_qm_fw_magic_contexts, count + 1) != count + 1)
      return -1;
   g_qm_fw_magic_contexts[count].ea_id = ea_id;
   g_qm_fw_magic_contexts[count].slot = slot;
   g_qm_fw_magic_contexts[count].magic = magic;
   g_qm_fw_magic_contexts[count].symbol = context_symbol;
   if(!QM_KillSwitchRegisterMagic((long)magic))
     {
      ArrayResize(g_qm_fw_magic_contexts, count);
      return -1;
     }
   return magic;
  }

int QM_FrameworkMagicContextCount()
  {
   return ArraySize(g_qm_fw_magic_contexts);
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

   const int context_count = ArraySize(g_qm_fw_magic_contexts);
   for(int i = 0; i < context_count; ++i)
     {
      if(magic != (long)g_qm_fw_magic_contexts[i].magic)
         continue;
      if(symbol == "" || symbol == g_qm_fw_magic_contexts[i].symbol)
         return true;
     }

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
        {
         // Archive the closed position's MAE (worst floating loss is not in deal history,
         // so the OnDeinit Q08 history walk needs it kept). Then drop from the active array
         // so the per-tick find stays fast.
         const int ci = ArraySize(g_qm_q08_mae_closed);
         ArrayResize(g_qm_q08_mae_closed, ci + 1);
         g_qm_q08_mae_closed[ci] = g_qm_q08_mae_states[index];
         QM_FrameworkMaeRemoveIndex(index);
        }
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
   // Preserve the exact legacy single-magic fast path unless the EA has
   // explicitly registered sub-strategy contexts.
   if(!QM_SymbolGuardIsBasket() && QM_FrameworkMagicContextCount() == 0)
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
   const bool prefer_dwx = (StringFind(_Symbol, ".DWX") >= 0);
   const string direct = from_currency + account_currency;
   bool found = false;
   if(prefer_dwx)
      found = QM_FrameworkSymbolPrice(direct + ".DWX", px) || QM_FrameworkSymbolPrice(direct, px);
   else
      found = QM_FrameworkSymbolPrice(direct, px) || QM_FrameworkSymbolPrice(direct + ".DWX", px);
   if(found)
     {
      rate = px;
      return true;
     }

   const string inverse = account_currency + from_currency;
   if(prefer_dwx)
      found = QM_FrameworkSymbolPrice(inverse + ".DWX", px) || QM_FrameworkSymbolPrice(inverse, px);
   else
      found = QM_FrameworkSymbolPrice(inverse, px) || QM_FrameworkSymbolPrice(inverse + ".DWX", px);
   if(found && px > 0.0)
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

   // Q08 per-trade stream is NOT emitted here anymore. The MT5 strategy tester does not
   // reliably deliver a DEAL_ADD OnTradeTransaction for every closing deal (observed 54/1762
   // closes missing on a high-trade run), so an event-driven stream silently undercounts vs
   // the tester report. The stream is instead rebuilt deterministically from HistorySelect at
   // shutdown (QM_FrameworkQ08EmitFromHistory). The closing-deal MAE is preserved for that walk
   // by the OnTick sweep, which archives into g_qm_q08_mae_closed instead of discarding. This
   // handler keeps only the live kill-switch feed below (OnTradeTransaction is reliable LIVE).

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
      QM_KillSwitchDeleteOwnedPendings();
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

// Worst floating loss (MAE) for a position, from the active or archived MAE state. Not present
// in deal history, so it must come from the live-tracked arrays. Returns 0 if never tracked.
double QM_FrameworkQ08LookupMae(const ulong position_id, datetime &entry_time_out)
  {
   for(int i = ArraySize(g_qm_q08_mae_states) - 1; i >= 0; --i)
      if(g_qm_q08_mae_states[i].position_id == position_id)
        {
         entry_time_out = g_qm_q08_mae_states[i].entry_time;
         return MathMin(0.0, g_qm_q08_mae_states[i].min_floating_pnl);
        }
   for(int i = ArraySize(g_qm_q08_mae_closed) - 1; i >= 0; --i)
      if(g_qm_q08_mae_closed[i].position_id == position_id)
        {
         entry_time_out = g_qm_q08_mae_closed[i].entry_time;
         return MathMin(0.0, g_qm_q08_mae_closed[i].min_floating_pnl);
        }
   entry_time_out = 0;
   return 0.0;
  }

int QM_FrameworkQ08LifecycleIndex(const QM_FrameworkQ08Lifecycle &rows[],
                                  const ulong position_id)
  {
   const int count = ArraySize(rows);
   for(int i = 0; i < count; ++i)
      if(rows[i].position_id == position_id)
         return i;
   return -1;
  }

double QM_FrameworkQ08MoneyRound(const double value)
  {
   return MathRound(value * 100.0) / 100.0;
  }

string QM_FrameworkQ08CanonicalSide(const long deal_type)
  {
   if(deal_type == DEAL_TYPE_BUY)
      return "BUY";
   if(deal_type == DEAL_TYPE_SELL)
      return "SELL";
   return "";
  }

string QM_FrameworkQ08StablePriceJson(const double value)
  {
   // Both standalone and joint producers call this helper. Sixteen fixed
   // decimals retain all meaningful MT5 symbol precision while producing one
   // locale-independent, deterministic JSON number representation.
   return DoubleToString(value, 16);
  }

bool QM_FrameworkQ08MoneyCentExact(const double value)
  {
   return MathIsValidNumber(value) &&
          MathAbs(value - QM_FrameworkQ08MoneyRound(value)) <= 0.0000001;
  }

double QM_FrameworkQ08VolumeTolerance(const string symbol)
  {
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(!MathIsValidNumber(step) || step <= 0.0)
      return 0.0000001;
   return MathMax(0.0000001, step * 0.000001);
  }

void QM_FrameworkQ08RejectLifecycle(const string reason,
                                    const ulong position_id,
                                    const ulong deal_id)
  {
   // No valid row from this history walk may survive a lifecycle failure. The
   // final target is replaced only after a complete validated temp stream, so
   // clearing this in-memory buffer cannot expose a partial current-run file.
   g_qm_q08_trade_log = "";
   QM_LogEvent(
      QM_ERROR,
      "Q08_LIFECYCLE_INVALID",
      StringFormat("{\"reason\":\"%s\",\"position_id\":%I64u,\"deal_id\":%I64u}",
                   QM_LoggerEscapeJson(reason), position_id, deal_id));
  }

bool QM_FrameworkQ08WriteTempChunk(const int handle,
                                   long &bytes_written)
  {
   const int length = StringLen(g_qm_q08_trade_log);
   if(length == 0)
      return true;
   ResetLastError();
   const uint written = FileWriteString(handle, g_qm_q08_trade_log);
   if((int)written != length)
      return false;
   bytes_written += (long)written;
   g_qm_q08_trade_log = "";
   return true;
  }

bool QM_FrameworkQ08AllocateEntryCommission(QM_FrameworkQ08Lifecycle &row,
                                            const double exit_volume,
                                            double &entry_commission_out)
  {
   entry_commission_out = 0.0;
   if(!MathIsValidNumber(exit_volume) || exit_volume <= 0.0 ||
      !MathIsValidNumber(row.entry_volume) || row.entry_volume <= 0.0 ||
      !MathIsValidNumber(row.entry_commission))
      return false;

   const double tolerance = QM_FrameworkQ08VolumeTolerance(row.symbol);
   const double next_exit_volume = row.allocated_exit_volume + exit_volume;
   if(!MathIsValidNumber(next_exit_volume) ||
      next_exit_volume > row.entry_volume + tolerance)
      return false;

   const double total_entry_commission =
      QM_FrameworkQ08MoneyRound(row.entry_commission);
   const bool final_exit =
      MathAbs(next_exit_volume - row.entry_volume) <= tolerance;
   // Cumulative proportional targets avoid cent-rounding drift across many
   // partial exits. The final exit receives the exact unallocated remainder.
   const double target_allocated = final_exit
      ? total_entry_commission
      : QM_FrameworkQ08MoneyRound(
           total_entry_commission * next_exit_volume / row.entry_volume);
   entry_commission_out = QM_FrameworkQ08MoneyRound(
      target_allocated - row.allocated_entry_commission);
   if(!MathIsValidNumber(target_allocated) ||
      !MathIsValidNumber(entry_commission_out))
      return false;

   row.allocated_exit_volume = next_exit_volume;
   row.allocated_entry_commission = target_allocated;
   return true;
  }

// Rebuild the entire Q08 per-trade stream deterministically from the deal HISTORY at shutdown.
// This is the authoritative source (matches the tester report by construction) — the previous
// OnTradeTransaction event stream silently dropped closes the tester never delivered an event
// for. One TRADE_CLOSED line per OUT / OUT_BY deal owned by this EA is retained for legacy
// consumers. Before any line is published, the full position lifecycle is validated and actual
// IN commissions are allocated across partial exits. A bounded ~32 KB buffer is written to a
// temp stream only after validation; the final Common\Files target is replaced in one move.
void QM_FrameworkQ08EmitFromHistory()
  {
   if(!g_qm_fw_initialized)
      return;
   if(!HistorySelect(0, TimeCurrent()))
     {
      QM_FrameworkQ08RejectLifecycle("HISTORY_SELECT_FAILED", 0, 0);
      return;
     }
   const int total = HistoryDealsTotal();
   QM_FrameworkQ08Lifecycle lifecycles[];
   bool lifecycle_invalid = false;
   string lifecycle_reason = "";
   ulong lifecycle_position = 0;
   ulong lifecycle_deal = 0;

   // Pass 1: collect every owned IN deal. The opening deal reliably carries
   // the EA magic; SL/TP exits often carry DEAL_MAGIC 0. Grouping by
   // DEAL_POSITION_ID makes scale-ins one lifecycle and preserves the earliest
   // entry time plus the actual sum of all entry commissions.
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
        {
         lifecycle_invalid = true;
         lifecycle_reason = "HISTORY_DEAL_TICKET_ZERO";
         break;
        }
      const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      const ulong position_id =
         (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      const string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
      const long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
      int row_index = QM_FrameworkQ08LifecycleIndex(lifecycles, position_id);

      if(entry == DEAL_ENTRY_INOUT)
        {
         if(row_index >= 0 || QM_FrameworkOwnsMagicSymbol(magic, symbol))
           {
            lifecycle_invalid = true;
            lifecycle_reason = "INOUT_REVERSAL_UNSUPPORTED";
            lifecycle_position = position_id;
            lifecycle_deal = deal;
            break;
           }
         continue;
        }
      if(entry != DEAL_ENTRY_IN)
         continue;

      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
        {
         // A later foreign scale-in on an already-owned netting position makes
         // its money attribution ambiguous; never publish a partial truth.
         if(row_index >= 0)
           {
            lifecycle_invalid = true;
            lifecycle_reason = "OWNED_POSITION_FOREIGN_SCALE_IN";
            lifecycle_position = position_id;
            lifecycle_deal = deal;
            break;
           }
         continue;
        }

      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const long deal_type = HistoryDealGetInteger(deal, DEAL_TYPE);
      const string side = QM_FrameworkQ08CanonicalSide(deal_type);
      const double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      const double price = HistoryDealGetDouble(deal, DEAL_PRICE);
      const double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      const double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      const double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
      const double fee = HistoryDealGetDouble(deal, DEAL_FEE);
      if(position_id == 0 || symbol == "" || magic <= 0 || deal_time <= 0 ||
         side == "" || !MathIsValidNumber(price) || price <= 0.0 ||
         !MathIsValidNumber(volume) || volume <= 0.0 ||
         !QM_FrameworkQ08MoneyCentExact(commission) ||
         !QM_FrameworkQ08MoneyCentExact(profit) ||
         !QM_FrameworkQ08MoneyCentExact(swap) ||
         !QM_FrameworkQ08MoneyCentExact(fee) ||
         MathAbs(profit) > 0.0000001 || MathAbs(swap) > 0.0000001 ||
         MathAbs(fee) > 0.0000001)
        {
         lifecycle_invalid = true;
         lifecycle_reason = "ENTRY_IDENTITY_VOLUME_OR_MONEY_INVALID";
         lifecycle_position = position_id;
         lifecycle_deal = deal;
         break;
        }

      if(row_index < 0)
        {
         const int count = ArraySize(lifecycles);
         ArrayResize(lifecycles, count + 1);
         row_index = count;
         lifecycles[row_index].position_id = position_id;
         lifecycles[row_index].magic = magic;
         lifecycles[row_index].symbol = symbol;
         lifecycles[row_index].side = side;
         lifecycles[row_index].entry_time = deal_time;
         lifecycles[row_index].entry_volume = 0.0;
         lifecycles[row_index].entry_price_volume_sum = 0.0;
         lifecycles[row_index].entry_commission = 0.0;
         lifecycles[row_index].exit_volume = 0.0;
         lifecycles[row_index].validated_entry_volume = 0.0;
         lifecycles[row_index].validated_exit_volume = 0.0;
         lifecycles[row_index].allocated_exit_volume = 0.0;
         lifecycles[row_index].allocated_entry_commission = 0.0;
         lifecycles[row_index].entry_count = 0;
         lifecycles[row_index].exit_count = 0;
        }
      else if(lifecycles[row_index].magic != magic ||
              lifecycles[row_index].symbol != symbol ||
              lifecycles[row_index].side != side)
        {
         lifecycle_invalid = true;
         lifecycle_reason = "POSITION_ENTRY_IDENTITY_CHANGED";
         lifecycle_position = position_id;
         lifecycle_deal = deal;
         break;
        }

      if(deal_time < lifecycles[row_index].entry_time)
         lifecycles[row_index].entry_time = deal_time;
      lifecycles[row_index].entry_volume += volume;
      lifecycles[row_index].entry_price_volume_sum += price * volume;
      lifecycles[row_index].entry_commission += commission;
      ++lifecycles[row_index].entry_count;
      if(!MathIsValidNumber(lifecycles[row_index].entry_volume) ||
         !MathIsValidNumber(lifecycles[row_index].entry_price_volume_sum) ||
         !MathIsValidNumber(lifecycles[row_index].entry_commission))
        {
         lifecycle_invalid = true;
         lifecycle_reason = "ENTRY_AGGREGATE_INVALID";
         lifecycle_position = position_id;
         lifecycle_deal = deal;
         break;
        }
     }

   if(lifecycle_invalid)
     {
      QM_FrameworkQ08RejectLifecycle(lifecycle_reason,
                                     lifecycle_position,
                                     lifecycle_deal);
      return;
     }
   const int lifecycle_count = ArraySize(lifecycles);
   if(lifecycle_count == 0)
      return;

   double notional_by_history[];
   ArrayResize(notional_by_history, total);
   ArrayInitialize(notional_by_history, 0.0);
   int lifecycle_index_by_history[];
   ArrayResize(lifecycle_index_by_history, total);
   ArrayInitialize(lifecycle_index_by_history, -1);
   long deal_time_by_history[];
   ArrayResize(deal_time_by_history, total);
   ArrayInitialize(deal_time_by_history, 0);
   double profit_by_history[];
   double swap_by_history[];
   double exit_commission_by_history[];
   double volume_by_history[];
   double exit_price_by_history[];
   ArrayResize(profit_by_history, total);
   ArrayResize(swap_by_history, total);
   ArrayResize(exit_commission_by_history, total);
   ArrayResize(volume_by_history, total);
   ArrayResize(exit_price_by_history, total);
   ArrayInitialize(profit_by_history, 0.0);
   ArrayInitialize(swap_by_history, 0.0);
   ArrayInitialize(exit_commission_by_history, 0.0);
   ArrayInitialize(volume_by_history, 0.0);
   ArrayInitialize(exit_price_by_history, 0.0);

   // Pass 2: validate every relevant exit and the final volume balance. No
   // stream output occurs here. OUT_BY is a normal closing leg; INOUT is an
   // ambiguous close+open reversal and blocks the entire stream.
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
        {
         lifecycle_invalid = true;
         lifecycle_reason = "HISTORY_DEAL_TICKET_ZERO";
         break;
        }
      const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      const ulong position_id =
         (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      const string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
      const long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
      const int row_index =
         QM_FrameworkQ08LifecycleIndex(lifecycles, position_id);

      if(entry == DEAL_ENTRY_INOUT)
        {
         if(row_index >= 0 || QM_FrameworkOwnsMagicSymbol(magic, symbol))
           {
            lifecycle_invalid = true;
            lifecycle_reason = "INOUT_REVERSAL_UNSUPPORTED";
            lifecycle_position = position_id;
            lifecycle_deal = deal;
            break;
           }
         continue;
        }
      if(entry == DEAL_ENTRY_IN)
        {
         if(row_index >= 0)
           {
            const long deal_type = HistoryDealGetInteger(deal, DEAL_TYPE);
            const string side = QM_FrameworkQ08CanonicalSide(deal_type);
            const double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
            const double price = HistoryDealGetDouble(deal, DEAL_PRICE);
            const double tolerance =
               QM_FrameworkQ08VolumeTolerance(lifecycles[row_index].symbol);
            if(magic != lifecycles[row_index].magic ||
               symbol != lifecycles[row_index].symbol ||
               side != lifecycles[row_index].side ||
               !MathIsValidNumber(price) || price <= 0.0 ||
               !MathIsValidNumber(volume) || volume <= 0.0)
              {
               lifecycle_invalid = true;
               lifecycle_reason = "POSITION_ENTRY_IDENTITY_CHANGED";
               lifecycle_position = position_id;
               lifecycle_deal = deal;
               break;
              }
            // A position identifier may scale in while volume remains open,
            // but it may not be reused after a complete close.
            if(lifecycles[row_index].exit_count > 0 &&
               MathAbs(lifecycles[row_index].validated_entry_volume -
                       lifecycles[row_index].validated_exit_volume) <= tolerance)
              {
               lifecycle_invalid = true;
               lifecycle_reason = "POSITION_IDENTIFIER_REOPENED";
               lifecycle_position = position_id;
               lifecycle_deal = deal;
               break;
              }
            lifecycles[row_index].validated_entry_volume += volume;
           }
         continue;
        }
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
        {
         if(row_index >= 0)
           {
            lifecycle_invalid = true;
            lifecycle_reason = "DEAL_ENTRY_KIND_UNSUPPORTED";
            lifecycle_position = position_id;
            lifecycle_deal = deal;
            break;
           }
         continue;
        }
      if(row_index < 0)
        {
         if(QM_FrameworkOwnsMagicSymbol(magic, symbol))
           {
            lifecycle_invalid = true;
            lifecycle_reason = "OWNED_EXIT_WITHOUT_ENTRY";
            lifecycle_position = position_id;
            lifecycle_deal = deal;
            break;
           }
         continue;
        }

      const long deal_type = HistoryDealGetInteger(deal, DEAL_TYPE);
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      const double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      const double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
      const double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      const double fee = HistoryDealGetDouble(deal, DEAL_FEE);
      const double price = HistoryDealGetDouble(deal, DEAL_PRICE);
      if(symbol != lifecycles[row_index].symbol ||
         (deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL) ||
         deal_time < lifecycles[row_index].entry_time ||
         !MathIsValidNumber(volume) || volume <= 0.0 ||
         !QM_FrameworkQ08MoneyCentExact(profit) ||
         !QM_FrameworkQ08MoneyCentExact(swap) ||
         !QM_FrameworkQ08MoneyCentExact(commission) ||
         !QM_FrameworkQ08MoneyCentExact(fee) ||
         MathAbs(fee) > 0.0000001 ||
         !MathIsValidNumber(price) || price <= 0.0)
        {
         lifecycle_invalid = true;
         lifecycle_reason = "EXIT_IDENTITY_VOLUME_OR_MONEY_INVALID";
         lifecycle_position = position_id;
         lifecycle_deal = deal;
         break;
        }

      lifecycles[row_index].exit_volume += volume;
      lifecycles[row_index].validated_exit_volume += volume;
      ++lifecycles[row_index].exit_count;
      const double tolerance =
         QM_FrameworkQ08VolumeTolerance(lifecycles[row_index].symbol);
      if(!MathIsValidNumber(lifecycles[row_index].exit_volume) ||
         !MathIsValidNumber(lifecycles[row_index].validated_exit_volume) ||
         lifecycles[row_index].validated_exit_volume >
            lifecycles[row_index].validated_entry_volume + tolerance ||
         lifecycles[row_index].exit_volume >
            lifecycles[row_index].entry_volume + tolerance)
        {
         lifecycle_invalid = true;
         lifecycle_reason = "EXIT_VOLUME_EXCEEDS_ENTRY_VOLUME";
         lifecycle_position = position_id;
         lifecycle_deal = deal;
         break;
        }
      const double notional = QM_FrameworkDealNotionalAccount(
         deal, symbol, volume, price);
      if(!MathIsValidNumber(notional) || notional <= 0.0)
        {
         lifecycle_invalid = true;
         lifecycle_reason = "EXIT_NOTIONAL_INVALID";
         lifecycle_position = position_id;
         lifecycle_deal = deal;
         break;
        }
      notional_by_history[i] = notional;
      lifecycle_index_by_history[i] = row_index;
      deal_time_by_history[i] = (long)deal_time;
      profit_by_history[i] = QM_FrameworkQ08MoneyRound(profit);
      swap_by_history[i] = QM_FrameworkQ08MoneyRound(swap);
      exit_commission_by_history[i] = QM_FrameworkQ08MoneyRound(commission);
      volume_by_history[i] = volume;
      exit_price_by_history[i] = price;
     }

   if(!lifecycle_invalid)
      for(int i = 0; i < lifecycle_count; ++i)
        {
         const double tolerance =
            QM_FrameworkQ08VolumeTolerance(lifecycles[i].symbol);
         if(lifecycles[i].entry_count <= 0 || lifecycles[i].exit_count <= 0 ||
            lifecycles[i].entry_time <= 0 ||
            !MathIsValidNumber(lifecycles[i].entry_volume) ||
            !MathIsValidNumber(lifecycles[i].entry_price_volume_sum) ||
            lifecycles[i].entry_price_volume_sum <= 0.0 ||
            !MathIsValidNumber(lifecycles[i].exit_volume) ||
            MathAbs(lifecycles[i].validated_entry_volume -
                    lifecycles[i].entry_volume) > tolerance ||
            MathAbs(lifecycles[i].validated_exit_volume -
                    lifecycles[i].exit_volume) > tolerance ||
            MathAbs(lifecycles[i].entry_volume - lifecycles[i].exit_volume) >
               tolerance ||
            QM_FrameworkMaePositionStillOpen(lifecycles[i].position_id))
           {
            lifecycle_invalid = true;
            lifecycle_reason = "POSITION_LIFECYCLE_NOT_FULLY_CLOSED";
            lifecycle_position = lifecycles[i].position_id;
            break;
           }
        }

   if(lifecycle_invalid)
     {
      QM_FrameworkQ08RejectLifecycle(lifecycle_reason,
                                     lifecycle_position,
                                     lifecycle_deal);
      return;
     }

   // Pass 3: pre-compute all proportional entry-commission allocations. A
   // cumulative rounded target assigns cents stably; the final exit receives
   // the exact remainder. This pass also completes before any output.
   double entry_commission_by_history[];
   ArrayResize(entry_commission_by_history, total);
   ArrayInitialize(entry_commission_by_history, 0.0);
   for(int i = 0; i < lifecycle_count; ++i)
     {
      lifecycles[i].allocated_exit_volume = 0.0;
      lifecycles[i].allocated_entry_commission = 0.0;
     }
   for(int i = 0; i < total; ++i)
     {
      const int row_index = lifecycle_index_by_history[i];
      if(row_index < 0)
         continue;
      const ulong position_id = lifecycles[row_index].position_id;
      const double volume = volume_by_history[i];
      double allocated_entry_commission = 0.0;
      if(!QM_FrameworkQ08AllocateEntryCommission(
            lifecycles[row_index], volume, allocated_entry_commission))
        {
         lifecycle_invalid = true;
         lifecycle_reason = "ENTRY_COMMISSION_ALLOCATION_INVALID";
         lifecycle_position = position_id;
         lifecycle_deal = 0;
         break;
        }
      entry_commission_by_history[i] = allocated_entry_commission;
     }
   if(!lifecycle_invalid)
      for(int i = 0; i < lifecycle_count; ++i)
        {
         const double tolerance =
            QM_FrameworkQ08VolumeTolerance(lifecycles[i].symbol);
         if(MathAbs(lifecycles[i].allocated_exit_volume -
                    lifecycles[i].entry_volume) > tolerance ||
            MathAbs(lifecycles[i].allocated_entry_commission -
                    QM_FrameworkQ08MoneyRound(
                       lifecycles[i].entry_commission)) > 0.0000001)
           {
            lifecycle_invalid = true;
            lifecycle_reason = "ENTRY_COMMISSION_ALLOCATION_INCOMPLETE";
            lifecycle_position = lifecycles[i].position_id;
            break;
           }
        }

   const bool lifecycle_validated = !lifecycle_invalid;
   if(!lifecycle_validated)
     {
      QM_FrameworkQ08RejectLifecycle(lifecycle_reason,
                                     lifecycle_position,
                                     lifecycle_deal);
      return;
     }

   // Pass 4: create a complete temp stream solely from the immutable values
   // captured by Pass 2/3. The final Common\Files target is replaced in one
   // FileMove only after the complete temp stream is flushed and size-checked.
   string q08_sym = _Symbol;
   StringReplace(q08_sym, ".", "_");
   const string q08_path = StringFormat(
      "QM\\q08_trades\\%d_%s.jsonl", g_qm_fw_ea_id, q08_sym);
   const string q08_temp_path = q08_path + ".full_lifecycle.tmp";
   if(g_qm_q08_fh != INVALID_HANDLE)
     {
      FileClose(g_qm_q08_fh);
      g_qm_q08_fh = INVALID_HANDLE;
     }
   g_qm_q08_trade_log = "";
   ResetLastError();
   const int q08_temp_fh = FileOpen(
      q08_temp_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(q08_temp_fh == INVALID_HANDLE)
     {
      QM_FrameworkQ08RejectLifecycle("TEMP_STREAM_OPEN_FAILED", 0, 0);
      return;
     }
   long q08_temp_bytes = 0;
   bool q08_temp_valid = true;
   for(int i = 0; i < total; ++i)
     {
      const int row_index = lifecycle_index_by_history[i];
      if(row_index < 0)
         continue;

      const ulong position_id = lifecycles[row_index].position_id;
      const string symbol = lifecycles[row_index].symbol;
      const double profit = profit_by_history[i];
      const double swap = swap_by_history[i];
      const double entry_commission = entry_commission_by_history[i];
      const double exit_commission = exit_commission_by_history[i];
      const double commission = QM_FrameworkQ08MoneyRound(
         entry_commission + exit_commission);
      const double net = QM_FrameworkQ08MoneyRound(
         profit + swap + commission);
      const double volume = volume_by_history[i];
      const double entry_price =
         lifecycles[row_index].entry_price_volume_sum /
         lifecycles[row_index].entry_volume;
      const double exit_price = exit_price_by_history[i];
      const string entry_price_json =
         QM_FrameworkQ08StablePriceJson(entry_price);
      const string exit_price_json =
         QM_FrameworkQ08StablePriceJson(exit_price);
      const long deal_time = deal_time_by_history[i];
      datetime mae_entry_time = 0;
      double mae_acct = QM_FrameworkQ08LookupMae(position_id,
                                                 mae_entry_time);
      mae_acct = MathMin(mae_acct, net);
      g_qm_q08_trade_log += StringFormat(
         "{\"event\":\"TRADE_CLOSED\",\"money_basis\":\"FULL_POSITION_LIFECYCLE_ACTUAL_V1\",\"magic\":%I64d,\"side\":\"%s\",\"entry_price\":%s,\"exit_price\":%s,\"time\":%I64d,\"entry_time\":%I64d,\"mae_acct\":%.2f,\"net\":%.2f,\"profit\":%.2f,\"swap\":%.2f,\"fee\":0.00,\"commission\":%.2f,\"entry_commission\":%.2f,\"exit_commission\":%.2f,\"volume\":%.2f,\"notional\":%.2f,\"symbol\":\"%s\"}\r\n",
         lifecycles[row_index].magic,
         lifecycles[row_index].side,
         entry_price_json,
         exit_price_json,
         deal_time,
         (long)lifecycles[row_index].entry_time,
         mae_acct,
         net,
         profit,
         swap,
         commission,
         entry_commission,
         exit_commission,
         volume,
         notional_by_history[i],
         QM_LoggerEscapeJson(symbol));
      if(StringLen(g_qm_q08_trade_log) >= 32768 &&
         !QM_FrameworkQ08WriteTempChunk(q08_temp_fh, q08_temp_bytes))
        {
         q08_temp_valid = false;
         lifecycle_position = position_id;
         break;
        }
     }
   if(q08_temp_valid)
      q08_temp_valid = QM_FrameworkQ08WriteTempChunk(
         q08_temp_fh, q08_temp_bytes);
   FileFlush(q08_temp_fh);
   if(q08_temp_valid &&
      (q08_temp_bytes <= 0 ||
       (long)FileSize(q08_temp_fh) != q08_temp_bytes))
      q08_temp_valid = false;
   FileClose(q08_temp_fh);
   if(!q08_temp_valid)
     {
      FileDelete(q08_temp_path, FILE_COMMON);
      QM_FrameworkQ08RejectLifecycle(
         "TEMP_STREAM_WRITE_OR_SIZE_FAILED", lifecycle_position, 0);
      return;
     }
   ResetLastError();
   if(!FileMove(q08_temp_path,
                FILE_COMMON,
                q08_path,
                FILE_COMMON | FILE_REWRITE))
     {
      FileDelete(q08_temp_path, FILE_COMMON);
      QM_FrameworkQ08RejectLifecycle("TEMP_STREAM_FINAL_MOVE_FAILED", 0, 0);
      return;
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
   // Persistent-handle append (2026-07-10 fix v2). The previous version re-opened the file on
   // EVERY flush with FILE_READ|FILE_WRITE and FileSeek(SEEK_END). In the tester's FILE_TXT mode
   // that seek did not reliably land on the true end of a just-closed file, so the next write
   // overwrote the tail of the prior chunk and silently dropped trades — the loss scaled with the
   // number of mid-run flushes (~3 trades on a short run, ~54 on a long one; stream undercounted
   // vs the MT5 report). Opening the file ONCE (truncate) and holding the handle open for the
   // whole run removes the re-open and the seek, so appends are strictly sequential and lossless.
   if(g_qm_q08_fh == INVALID_HANDLE)
     {
      string q08_sym = _Symbol;
      StringReplace(q08_sym, ".", "_");
      const string q08_path = StringFormat("QM\\q08_trades\\%d_%s.jsonl", g_qm_fw_ea_id, q08_sym);
      g_qm_q08_fh = FileOpen(q08_path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);  // truncate fresh, keep open
      if(g_qm_q08_fh == INVALID_HANDLE)
        {
         QM_LogEvent(QM_WARN, "Q08_STREAM_OPEN_FAILED",
                     StringFormat("{\"ea\":%d,\"error\":%d}", g_qm_fw_ea_id, GetLastError()));
         return;   // keep the buffer; retry on the next flush
        }
     }
   FileWriteString(g_qm_q08_fh, g_qm_q08_trade_log);
   FileFlush(g_qm_q08_fh);   // durable on disk in case the run is killed before shutdown
   g_qm_q08_trade_log = "";
  }

void QM_FrameworkShutdown()
  {
   // audit 2026-07-20: deinit wall-time telemetry — MT5 force-kills OnDeinit
   // after ~2.7s, so anything approaching 1s here is a live-restart hazard.
   const uint deinit_start_ms = GetTickCount();
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
   // Q08 per-trade stream: build the COMPLETE stream from the deal history now (the tester
   // does not fire an OnTradeTransaction for every close), then flush to the deterministic
   // Common\Files path so the Davey aggregator reads real per-trade P&L that matches the
   // tester report. Bounded/incremental flush inside (2026-07-10 OOM fix) keeps memory capped.
   // 2026-07-20 framework audit P0.1: TESTER-ONLY. Q08 is a backtest gate; on a
   // live account this walk is HistorySelect(0,now) over the whole account
   // history plus one nested HistorySelect per closing deal — synchronous,
   // roughly quadratic work inside OnDeinit's ~2.7s budget. That force-kill is
   // the observed live-restart "Abnormal termination" class, and the output is
   // unused in live anyway.
   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      QM_FrameworkQ08EmitFromHistory();
      QM_FrameworkQ08Flush();
     }
   if(g_qm_q08_fh != INVALID_HANDLE)
     {
      FileClose(g_qm_q08_fh);
      g_qm_q08_fh = INVALID_HANDLE;
     }
   ArrayResize(g_qm_q08_mae_states, 0);
   ArrayResize(g_qm_q08_mae_closed, 0);
   if(g_qm_fw_initialized)
     {
      // Adversarial review 2026-07-20: wall-clock duration is live-only
      // telemetry — in the tester it would make the event log
      // non-deterministic run-to-run, so the tester keeps the legacy "{}".
      if(MQLInfoInteger(MQL_TESTER) != 0)
         QM_LogEvent(QM_INFO, "DEINIT", "{}");
      else
        {
         const uint deinit_ms = GetTickCount() - deinit_start_ms;
         QM_LogEvent(deinit_ms > 1000 ? QM_WARN : QM_INFO, "DEINIT",
                     StringFormat("{\"duration_ms\":%u}", deinit_ms));
        }
     }
   ArrayResize(g_qm_fw_magic_contexts, 0);
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
