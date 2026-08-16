#property strict

#define QM_RUNTIME_EXECUTION_TESTING
#include <QM/QM_Common.mqh>

void BuildEntryContract(QM_RuntimeExecutionContract &contract)
  {
   contract.schema_version = 1;
   contract.contract_id = "ENTRY_CONTRACT_V1";
   contract.generation = 5;
   contract.ea_id = 1002;
   contract.magic = 10020000;
   contract.symbol = _Symbol;
   contract.chart_timeframe = (ENUM_TIMEFRAMES)_Period;
   contract.account_login = AccountInfoInteger(ACCOUNT_LOGIN);
   contract.account_server = AccountInfoString(ACCOUNT_SERVER);
   contract.target = "DARWINEX_ZERO";
   contract.card_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   contract.execution_bundle_sha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   contract.target_rulepack_sha256 = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
   contract.magic_registry_sha256 = QM_MagicRegistryHash();
  }

bool BindEntryContract(const QM_RuntimeExecutionContract &contract)
  {
   QM_RuntimeExecutionTestReset();
   return (QM_RuntimeExecutionBeginRequiredInitialization() &&
           QM_RuntimeExecutionBindRequired(contract,
                                            5,
                                            1002,
                                            10020000,
                                            _Symbol,
                                            (ENUM_TIMEFRAMES)_Period,
                                            AccountInfoInteger(ACCOUNT_LOGIN),
                                            AccountInfoString(ACCOUNT_SERVER),
                                            QM_MagicRegistryHash()));
  }

int OnInit()
  {
   QM_RuntimeExecutionContract contract;
   BuildEntryContract(contract);

   QM_EntryRequest req;
   req.type = QM_BUY;
   req.reason = "ENTRY_IDENTITY_SMOKE";
   ulong ticket = 0;

   // Slot zero is the relative framework host slot. Prove that it preserves
   // a non-zero absolute host assignment and that explicit magics still pass
   // through unchanged. No broker operation is reached by these checks.
   g_qm_entry_ea_id = 1002;
   g_qm_entry_host_magic = 10020001;
   g_qm_entry_host_magic_ea_id = 1002;
   g_qm_entry_host_magic_symbol = _Symbol;
   req.symbol_slot = 0;
   if(QM_EntryResolveRequestMagic(req, 0) != 10020001)
      return INIT_FAILED;
   if(QM_EntryResolveRequestMagic(req, 10020002) != 10020002)
      return INIT_FAILED;
   if(QM_EntryConfiguredHostMagic(1003, _Symbol) >= 0)
      return INIT_FAILED;

   if(!BindEntryContract(contract))
      return INIT_FAILED;
   g_qm_entry_ea_id = 1003;
   if(QM_Entry(req, ticket) != QM_ENTRY_REJECTED_CONTRACT || ticket != 0)
      return INIT_FAILED;

   if(!BindEntryContract(contract))
      return INIT_FAILED;
   g_qm_entry_ea_id = 1002;
   ticket = 0;
   if(QM_Entry(req, ticket, 10020001) != QM_ENTRY_REJECTED_CONTRACT || ticket != 0)
      return INIT_FAILED;

   Print("ENTRY_EXECUTION_IDENTITY_SMOKE_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
