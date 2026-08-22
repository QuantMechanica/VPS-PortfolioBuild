#ifndef QM_RUNTIME_EXECUTION_CONTRACT_MQH
#define QM_RUNTIME_EXECUTION_CONTRACT_MQH

// Additive V3 execution identity. Legacy EAs remain explicitly classified as
// LEGACY_UNDECLARED while the Card-v3 fleet migrates in compile-tested cohorts.
// An EA that opts into V3 is fail-closed until one immutable contract matches
// its runtime identity; the contract cannot be rebound within the process.

enum QM_RuntimeExecutionState
  {
   QM_RUNTIME_EXECUTION_LEGACY_UNDECLARED = 0,
   QM_RUNTIME_EXECUTION_REQUIRED_BLOCKED  = 1,
   QM_RUNTIME_EXECUTION_READY             = 2
  };

struct QM_RuntimeExecutionContract
  {
   int             schema_version;
   string          contract_id;
   long            generation;
   int             ea_id;
   int             magic;
   string          symbol;
   ENUM_TIMEFRAMES chart_timeframe;
   long            account_login;
   string          account_server;
   string          target;
   string          card_sha256;
   string          execution_bundle_sha256;
   string          target_rulepack_sha256;
   string          magic_registry_sha256;
   bool            governor_required;
   string          governor_policy_id;
   string          challenge_instance_id;
   int             governor_heartbeat_max_age_seconds;
   bool            account_stop_risk_reservation_required;
   string          account_stop_risk_policy_id;
   string          account_stop_risk_policy_sha256;
   double          account_stop_risk_anchor_balance;
   double          account_stop_risk_cap_percent;
   bool            account_stop_risk_owner_ratified;

   QM_RuntimeExecutionContract()
     {
      schema_version = 0;
      contract_id = "";
      generation = 0;
      ea_id = 0;
      magic = 0;
      symbol = "";
      chart_timeframe = PERIOD_CURRENT;
      account_login = 0;
      account_server = "";
      target = "";
      card_sha256 = "";
      execution_bundle_sha256 = "";
      target_rulepack_sha256 = "";
      magic_registry_sha256 = "";
      governor_required = false;
      governor_policy_id = "";
      challenge_instance_id = "";
      governor_heartbeat_max_age_seconds = 0;
      account_stop_risk_reservation_required = false;
      account_stop_risk_policy_id = "";
      account_stop_risk_policy_sha256 = "";
      account_stop_risk_anchor_balance = 0.0;
      account_stop_risk_cap_percent = 0.0;
      account_stop_risk_owner_ratified = false;
     }
  };

QM_RuntimeExecutionState    g_qm_runtime_execution_state = QM_RUNTIME_EXECUTION_LEGACY_UNDECLARED;
QM_RuntimeExecutionContract g_qm_runtime_execution_contract;
string                      g_qm_runtime_execution_block_reason = "LEGACY_UNDECLARED";
bool                        g_qm_runtime_execution_initialization_started = false;

bool QM_RuntimeExecutionHashValid(const string value)
  {
   if(StringLen(value) != 64)
      return false;
   for(int i = 0; i < 64; ++i)
     {
      const ushort c = StringGetCharacter(value, i);
      const bool digit = (c >= '0' && c <= '9');
      const bool lower = (c >= 'a' && c <= 'f');
      const bool upper = (c >= 'A' && c <= 'F');
      if(!digit && !lower && !upper)
         return false;
     }
   return true;
  }

bool QM_RuntimeExecutionIdentifierValid(const string value)
  {
   if(StringLen(value) < 3 || StringLen(value) > 128)
      return false;
   for(int i = 0; i < StringLen(value); ++i)
     {
      const ushort c = StringGetCharacter(value, i);
      const bool alpha = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
      const bool digit = (c >= '0' && c <= '9');
      if(!alpha && !digit && c != '_' && c != '-' && c != '.')
         return false;
     }
   return true;
  }

void QM_RuntimeExecutionBlock(const string reason)
  {
   g_qm_runtime_execution_state = QM_RUNTIME_EXECUTION_REQUIRED_BLOCKED;
   g_qm_runtime_execution_block_reason = reason;
  }

// Initialization is a one-way state machine. A legacy initializer may only run
// while no V3 contract has been armed. It can never erase REQUIRED/READY state.
bool QM_RuntimeExecutionBeginLegacyInitialization()
  {
   if(g_qm_runtime_execution_state != QM_RUNTIME_EXECUTION_LEGACY_UNDECLARED)
     {
      QM_RuntimeExecutionBlock("LEGACY_INIT_AFTER_CONTRACT_REFUSED");
      return false;
     }
   g_qm_runtime_execution_initialization_started = true;
   return true;
  }

// Arm V3 before any framework side effect. Only the first initializer in the
// process may do this; a legacy->V3 or V3->V3 reinitialization attempt blocks
// entries and requires a fresh process/program instance to recover.
bool QM_RuntimeExecutionBeginRequiredInitialization()
  {
   if(g_qm_runtime_execution_initialization_started ||
      g_qm_runtime_execution_state != QM_RUNTIME_EXECUTION_LEGACY_UNDECLARED)
     {
      QM_RuntimeExecutionBlock("CONTRACT_REINITIALIZATION_REFUSED");
      return false;
     }

   g_qm_runtime_execution_initialization_started = true;
   QM_RuntimeExecutionBlock("CONTRACT_BIND_PENDING");
   return true;
  }

bool QM_RuntimeExecutionContractMatchesRuntime(const QM_RuntimeExecutionContract &contract,
                                                const long expected_source_generation,
                                                const int actual_ea_id,
                                                const int actual_magic,
                                                const string actual_symbol,
                                                const ENUM_TIMEFRAMES actual_timeframe,
                                                const long actual_account_login,
                                                const string actual_account_server,
                                                const string actual_magic_registry_sha256)
  {
   if(contract.schema_version != 1 ||
      !QM_RuntimeExecutionIdentifierValid(contract.contract_id) ||
      expected_source_generation <= 0 ||
      contract.generation != expected_source_generation ||
      contract.ea_id != actual_ea_id ||
      contract.magic != actual_magic ||
      contract.symbol != actual_symbol ||
      contract.chart_timeframe != actual_timeframe ||
      contract.account_login != actual_account_login ||
      contract.account_server != actual_account_server ||
      !QM_RuntimeExecutionHashValid(contract.card_sha256) ||
      !QM_RuntimeExecutionHashValid(contract.execution_bundle_sha256) ||
      !QM_RuntimeExecutionHashValid(contract.target_rulepack_sha256) ||
      !QM_RuntimeExecutionHashValid(contract.magic_registry_sha256) ||
      !QM_RuntimeExecutionHashValid(actual_magic_registry_sha256) ||
      contract.magic_registry_sha256 != actual_magic_registry_sha256)
      return false;

   if(contract.target != "DARWINEX_ZERO" && contract.target != "FTMO")
      return false;
   if(contract.target == "FTMO")
     {
      if(!contract.governor_required ||
         !QM_RuntimeExecutionIdentifierValid(contract.governor_policy_id) ||
         !QM_RuntimeExecutionIdentifierValid(contract.challenge_instance_id) ||
         contract.governor_heartbeat_max_age_seconds <= 0 ||
         contract.governor_heartbeat_max_age_seconds > 5)
         return false;
     }
   else if(contract.governor_required)
      return false;

   // SP-C2 is additive and dormant for existing contracts. Activation is
   // legal only on an exact FTMO 100k contract with a separately hash-bound,
   // OWNER-ratified policy. The 2.5% figure is a hard maximum, never a knob an
   // EA may raise to escape a blocked order.
   if(contract.account_stop_risk_reservation_required)
     {
      if(contract.target != "FTMO" || !contract.governor_required ||
         contract.account_stop_risk_policy_id !=
            "FTMO_2S_100K_OPEN_STOP_RISK_V1" ||
         !QM_RuntimeExecutionHashValid(
            contract.account_stop_risk_policy_sha256) ||
         contract.account_stop_risk_anchor_balance != 100000.0 ||
         !MathIsValidNumber(contract.account_stop_risk_cap_percent) ||
         contract.account_stop_risk_cap_percent <= 0.0 ||
         contract.account_stop_risk_cap_percent > 2.5 ||
         !contract.account_stop_risk_owner_ratified)
         return false;
     }
   else if(contract.account_stop_risk_policy_id != "" ||
           contract.account_stop_risk_policy_sha256 != "" ||
           contract.account_stop_risk_anchor_balance != 0.0 ||
           contract.account_stop_risk_cap_percent != 0.0 ||
           contract.account_stop_risk_owner_ratified)
      return false;

   return true;
  }

bool QM_RuntimeExecutionBindRequired(const QM_RuntimeExecutionContract &contract,
                                     const long expected_source_generation,
                                     const int actual_ea_id,
                                     const int actual_magic,
                                     const string actual_symbol,
                                     const ENUM_TIMEFRAMES actual_timeframe,
                                     const long actual_account_login,
                                     const string actual_account_server,
                                     const string actual_magic_registry_sha256)
  {
   if(g_qm_runtime_execution_state == QM_RUNTIME_EXECUTION_READY)
     {
      QM_RuntimeExecutionBlock("IMMUTABLE_REBIND_REFUSED");
      return false;
     }

   if(g_qm_runtime_execution_state != QM_RUNTIME_EXECUTION_REQUIRED_BLOCKED ||
      g_qm_runtime_execution_block_reason != "CONTRACT_BIND_PENDING")
     {
      QM_RuntimeExecutionBlock("CONTRACT_BIND_WITHOUT_BEGIN_REFUSED");
      return false;
     }

   g_qm_runtime_execution_block_reason = "CONTRACT_INVALID";
   if(!QM_RuntimeExecutionContractMatchesRuntime(contract,
                                                 expected_source_generation,
                                                 actual_ea_id,
                                                 actual_magic,
                                                 actual_symbol,
                                                 actual_timeframe,
                                                 actual_account_login,
                                                 actual_account_server,
                                                 actual_magic_registry_sha256))
      return false;

   g_qm_runtime_execution_contract = contract;
   g_qm_runtime_execution_state = QM_RUNTIME_EXECUTION_READY;
   g_qm_runtime_execution_block_reason = "READY";
   return true;
  }

#ifdef QM_RUNTIME_EXECUTION_TESTING
// Test-only escape hatch. Production includes never expose a reset symbol.
void QM_RuntimeExecutionTestReset()
  {
   g_qm_runtime_execution_state = QM_RUNTIME_EXECUTION_LEGACY_UNDECLARED;
   g_qm_runtime_execution_block_reason = "LEGACY_UNDECLARED";
   g_qm_runtime_execution_initialization_started = false;
   QM_RuntimeExecutionContract empty_contract;
   g_qm_runtime_execution_contract = empty_contract;
  }
#endif

bool QM_RuntimeExecutionEntryAllowed()
  {
   // Compatibility is explicit rather than inferred: only EAs initialized via
   // QM_FrameworkInitV3 enter REQUIRED_BLOCKED/READY. New Card-v3 builds must
   // use that initializer; fleet-wide enforcement follows cohort migration.
   if(g_qm_runtime_execution_state == QM_RUNTIME_EXECUTION_LEGACY_UNDECLARED)
      return true;
   return (g_qm_runtime_execution_state == QM_RUNTIME_EXECUTION_READY);
  }

bool QM_RuntimeExecutionGovernorRequired()
  {
   return (g_qm_runtime_execution_state == QM_RUNTIME_EXECUTION_READY &&
           g_qm_runtime_execution_contract.target == "FTMO" &&
           g_qm_runtime_execution_contract.governor_required);
  }

#endif // QM_RUNTIME_EXECUTION_CONTRACT_MQH
