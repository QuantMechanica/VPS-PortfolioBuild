#property strict

#define QM_RUNTIME_EXECUTION_TESTING
#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

void BuildBasketContract(QM_RuntimeExecutionContract &contract)
  {
   contract.schema_version = 1;
   contract.contract_id = "BASKET_CONTRACT_V1";
   contract.generation = 3;
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

int OnInit()
  {
   QM_RuntimeExecutionTestReset();
   if(!QM_RuntimeExecutionBeginRequiredInitialization())
      return INIT_FAILED;

   QM_BasketOrderRequest req;
   req.symbol = _Symbol;
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.lots = 100.0;
   req.reason = "BLOCKED_CONTRACT_SMOKE";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   // REQUIRED_BLOCKED must reject before any price, lot, governor or broker
   // operation. The deliberately huge explicit volume must never matter.
   if(QM_BasketOpenPosition(1001, QM_NEWS_OFF, 20, req, ticket) || ticket != 0)
      return INIT_FAILED;

   QM_RuntimeExecutionTestReset();
   QM_RuntimeExecutionContract contract;
   BuildBasketContract(contract);
   if(!QM_RuntimeExecutionBeginRequiredInitialization() ||
      !QM_RuntimeExecutionBindRequired(contract,
                                       3,
                                       1002,
                                       10020000,
                                       _Symbol,
                                       (ENUM_TIMEFRAMES)_Period,
                                       AccountInfoInteger(ACCOUNT_LOGIN),
                                       AccountInfoString(ACCOUNT_SERVER),
                                       QM_MagicRegistryHash()))
      return INIT_FAILED;

   // The current V3 schema binds exactly one EA/symbol/magic identity. Each
   // attempted implicit basket expansion must reject before order submission.
   req.symbol = _Symbol + ".UNBOUND";
   ticket = 0;
   if(QM_BasketOpenPosition(1002, QM_NEWS_OFF, 20, req, ticket) || ticket != 0)
      return INIT_FAILED;

   req.symbol = _Symbol;
   ticket = 0;
   if(QM_BasketOpenPosition(1003, QM_NEWS_OFF, 20, req, ticket) || ticket != 0)
      return INIT_FAILED;

   req.symbol_slot = 1;
   ticket = 0;
   if(QM_BasketOpenPosition(1002, QM_NEWS_OFF, 20, req, ticket) || ticket != 0)
      return INIT_FAILED;

   Print("BASKET_ORDER_EXECUTION_POLICY_SMOKE_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
