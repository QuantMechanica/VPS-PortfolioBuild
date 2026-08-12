#property strict

#define QM_RUNTIME_EXECUTION_TESTING
#include <QM/QM_RuntimeExecutionContract.mqh>

const long TEST_SOURCE_GENERATION = 7;
const string TEST_REGISTRY_SHA256 = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";

void BuildContract(QM_RuntimeExecutionContract &contract)
  {
   contract.schema_version = 1;
   contract.contract_id = "TEST_CONTRACT_V1";
   contract.generation = TEST_SOURCE_GENERATION;
   contract.ea_id = 1001;
   contract.magic = 10010000;
   contract.symbol = _Symbol;
   contract.chart_timeframe = (ENUM_TIMEFRAMES)_Period;
   contract.account_login = AccountInfoInteger(ACCOUNT_LOGIN);
   contract.account_server = AccountInfoString(ACCOUNT_SERVER);
   contract.target = "DARWINEX_ZERO";
   contract.card_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   contract.execution_bundle_sha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   contract.target_rulepack_sha256 = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
   contract.magic_registry_sha256 = TEST_REGISTRY_SHA256;
  }

bool ContractMatches(const QM_RuntimeExecutionContract &contract,
                     const long expected_source_generation,
                     const string actual_registry_sha256)
  {
   return QM_RuntimeExecutionContractMatchesRuntime(contract,
                                                     expected_source_generation,
                                                     1001,
                                                     10010000,
                                                     _Symbol,
                                                     (ENUM_TIMEFRAMES)_Period,
                                                     AccountInfoInteger(ACCOUNT_LOGIN),
                                                     AccountInfoString(ACCOUNT_SERVER),
                                                     actual_registry_sha256);
  }

bool BindContract(const QM_RuntimeExecutionContract &contract,
                  const long expected_source_generation,
                  const string actual_registry_sha256)
  {
   return QM_RuntimeExecutionBindRequired(contract,
                                           expected_source_generation,
                                           1001,
                                           10010000,
                                           _Symbol,
                                           (ENUM_TIMEFRAMES)_Period,
                                           AccountInfoInteger(ACCOUNT_LOGIN),
                                           AccountInfoString(ACCOUNT_SERVER),
                                           actual_registry_sha256);
  }

int OnInit()
  {
   QM_RuntimeExecutionTestReset();
   if(!QM_RuntimeExecutionEntryAllowed())
      return INIT_FAILED;

   QM_RuntimeExecutionContract contract;
   BuildContract(contract);

   // Pure identity validation must reject both independent source-generation
   // drift and a syntactically valid but different registry hash.
   if(!ContractMatches(contract, TEST_SOURCE_GENERATION, TEST_REGISTRY_SHA256) ||
      ContractMatches(contract, TEST_SOURCE_GENERATION + 1, TEST_REGISTRY_SHA256) ||
      ContractMatches(contract,
                      TEST_SOURCE_GENERATION,
                      "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"))
      return INIT_FAILED;

   // Binding without the one-shot V3 arm is fail-closed.
   if(BindContract(contract, TEST_SOURCE_GENERATION, TEST_REGISTRY_SHA256) ||
      QM_RuntimeExecutionEntryAllowed())
      return INIT_FAILED;

   // A wrong independently supplied source generation consumes the one-shot
   // bind attempt and stays blocked.
   QM_RuntimeExecutionTestReset();
   if(!QM_RuntimeExecutionBeginRequiredInitialization() ||
      BindContract(contract, TEST_SOURCE_GENERATION + 1, TEST_REGISTRY_SHA256) ||
      QM_RuntimeExecutionEntryAllowed())
      return INIT_FAILED;

   QM_RuntimeExecutionTestReset();
   if(!QM_RuntimeExecutionBeginRequiredInitialization() ||
      !BindContract(contract, TEST_SOURCE_GENERATION, TEST_REGISTRY_SHA256))
      return INIT_FAILED;
   if(!QM_RuntimeExecutionEntryAllowed())
      return INIT_FAILED;

   // A READY contract is immutable. A second bind blocks entries instead of
   // downgrading to permissive legacy behavior.
   if(BindContract(contract, TEST_SOURCE_GENERATION, TEST_REGISTRY_SHA256) ||
      QM_RuntimeExecutionEntryAllowed())
      return INIT_FAILED;

   // Legacy initialization after READY is also a hard block.
   QM_RuntimeExecutionTestReset();
   if(!QM_RuntimeExecutionBeginRequiredInitialization() ||
      !BindContract(contract, TEST_SOURCE_GENERATION, TEST_REGISTRY_SHA256) ||
      QM_RuntimeExecutionBeginLegacyInitialization() ||
      QM_RuntimeExecutionEntryAllowed())
      return INIT_FAILED;

   // Conversely, a process already initialized as legacy cannot be promoted
   // into V3 without a fresh program instance.
   QM_RuntimeExecutionTestReset();
   if(!QM_RuntimeExecutionBeginLegacyInitialization() ||
      !QM_RuntimeExecutionEntryAllowed() ||
      QM_RuntimeExecutionBeginRequiredInitialization() ||
      QM_RuntimeExecutionEntryAllowed())
      return INIT_FAILED;

   Print("RUNTIME_EXECUTION_CONTRACT_SMOKE_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
