import pytest
import os
from pathlib import Path
import shutil
import subprocess
from tools.strategy_farm.session_tools.audit_pattern_measurement_lineage_20260909 import assignments, equivalent, compare_defaults


def test_assignment_parser_preserves_duplicates_and_ignores_comments():
    assert assignments('; RISK_FIXED=1\nRISK_FIXED=1000\nRISK_FIXED=5000\nx=3||1||2||10||Y\n') == {'RISK_FIXED': ['1000', '5000'], 'x': ['3']}


@pytest.mark.parametrize('left,right,typ,want', [('1','1.0','double',True), ('true','1','bool',True), ('false','0','bool',True), ('01','1','string',False), ('1','2','int',False), ('ENUM_A','ENUM_B','enum',False)])
def test_typed_comparison(left,right,typ,want):
    assert equivalent(left,right,typ) is want


@pytest.mark.parametrize('actual,source,state', [({'x':['2']},'1','EXPLICIT_MATCH'), ({'x':['1']},'1','EXPLICIT_CURRENT_CARD_DIFFERENCE'), ({},'2','OMITTED_CURRENT_SOURCE_MATCH'), ({},'1','OMITTED_CURRENT_SOURCE_DIFFERS'), ({},None,'MISSING_UNKNOWN_DEFAULT'), ({'x':['2','2']},'2','DUPLICATE_ASSIGNMENT')])
def test_missing_is_not_automatically_wrong_and_duplicates_are_not_collapsed(actual,source,state):
    info={'card_defaults':{'x':'2'},'input_defaults':{'x':source} if source is not None else {},'input_types':{'x':'int'}}
    assert compare_defaults(info,actual)[0]['classification']==state


def test_document_current_generator_duplicate_core_and_symbolic_enum_exposure(tmp_path):
    """Diagnostic counterexample, not a claim that production is already repaired."""
    shell = shutil.which('pwsh')
    if not shell: pytest.skip('PowerShell required')
    root = tmp_path/'fixture_repo'
    scripts = root/'framework/scripts'; scripts.mkdir(parents=True)
    registry = root/'framework/registry'; registry.mkdir()
    cards = root/'artifacts/cards_approved'; cards.mkdir(parents=True)
    slug = 'QM5_99996_analysis-only'
    ea = root/'framework/EAs'/slug; ea.mkdir(parents=True)
    source = Path(__file__).resolve().parents[3]/'framework/scripts/gen_setfile.ps1'
    shutil.copy2(source, scripts/'gen_setfile.ps1')
    (registry/'magic_numbers.csv').write_text('ea_id,symbol,status,symbol_slot\n99996,EURUSD.DWX,active,0\n')
    (ea/(slug+'.mq5')).write_text('input double RISK_FIXED = 1000;\ninput QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;\ninput int strategy_period = 17;\n')
    (cards/(slug+'.md')).write_text('| param | default |\n| --- | --- |\n| RISK_FIXED | 5000 |\n| qm_news_compliance | QM_NEWS_COMPLIANCE_DXZ |\n| strategy_period | 17 |\n')
    env = os.environ.copy(); env['QM_STRATEGY_FARM_ROOT'] = str(tmp_path/'empty_farm')
    proc = subprocess.run([shell,'-NoProfile','-NonInteractive','-File',str(scripts/'gen_setfile.ps1'),'-EaSlug',slug,'-Symbol','EURUSD.DWX','-TF','H1','-Env','backtest'],cwd=root,env=env,capture_output=True,text=True,timeout=30)
    assert proc.returncode == 0, proc.stderr
    actual = assignments((ea/'sets'/(slug+'_EURUSD.DWX_H1_backtest.set')).read_text())
    assert actual['RISK_FIXED'] == ['1000','5000']
    assert actual['qm_news_compliance'] == ['QM_NEWS_COMPLIANCE_DXZ']
