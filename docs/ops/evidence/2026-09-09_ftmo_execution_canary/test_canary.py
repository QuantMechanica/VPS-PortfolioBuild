import importlib.util
from pathlib import Path
P=Path(__file__).parent
spec=importlib.util.spec_from_file_location('canary_prepare',P/'prepare.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

def test_strategy_mechanics_are_byte_equal_after_text_decoding():
    source=module.PARENT.read_text(encoding='utf-8-sig')
    copy=module.generate(source)
    assert source[:source.index('int OnInit()')]==copy[:copy.index('#include "execution_binding.mqh"')]
    assert 'QM_FrameworkInitV3(contract,generation,qm_ea_id,' in copy
    assert 'QM_FrameworkInit(qm_ea_id,' not in copy
    assert 'QM_FrameworkDeclareExecutionContract(' not in copy
    assert 'if(EventSetTimer(5))' not in copy
    assert copy.count('QM11421_CanaryBoundary();')==2

def test_unissued_binding_cannot_activate_account_or_invent_ratification():
    binding=(P/'execution_binding.mqh').read_text()
    assert 'return false;' in binding and 'return true;' not in binding
    assert 'owner_ratified=true' not in binding.replace(' ','')

def test_review_sources_do_not_change_registered_parent():
    source=module.PARENT.read_text(encoding='utf-8-sig')
    assert 'QM11421_Canary' not in source
    assert module.generate(source)==(P/'QM5_11421_execution_canary_review.mq5').read_text(encoding='utf-8')

def test_cleanup_uses_existing_send_once_contract_and_server_reconciliation():
    code=(P/'QM11421_CanaryLifecycle.mqh').read_text()
    context=(module.ROOT/'framework/include/QM/QM_TradeContext.mqh').read_text()
    assert 'QM_TRADE_SEND_ONCE' in code and 'QM_TRADE_SEND_ONCE' in context
    assert '!OrderSelect(t)' in code and '!PositionSelectByTicket(t)' in code
    assert 'if(remaining==0) g_qm11421_cleanup_pending=false;' in code
