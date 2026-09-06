import datetime as dt
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import pytest
from tools.strategy_farm import dsr_cohort as producer, dsr_single_configuration as single
sys.path.insert(0, str(Path(__file__).resolve().parents[3]/'framework/scripts'))
from q08_davey import dsr_v2 as v2


def bind(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    return {'path': str(path.resolve()), 'sha256': hashlib.sha256(raw).hexdigest()}


def fixture(tmp_path):
    candidate = {'ea_id': 'QM5_42', 'symbol': 'EURUSD.DWX', 'timeframe': 'D1'}
    provenance = {k: bind(tmp_path/(k+'.txt'), raw) for k,raw in {
        'spec': b'Locked fixture spec', 'mq5': b'input int strategy_period=9;',
        'ex5': b'fixture binary, not native compile evidence', 'setfile': b'strategy_period=9\nRISK_FIXED=1000\n'}.items()}
    declaration = {'schema': single.DECLARATION, **candidate, 'complete': True, 'no_optimization_search': True,
                   'research_trial_count': 0, 'spec_sha256': provenance['spec']['sha256'],
                   'locked_parameters': {'strategy_period': '9', 'RISK_FIXED': '1000'}}
    card = '---\ng0_status: APPROVED\n---\n```qm-dsr-single-configuration\n'+json.dumps(declaration)+'\n```\n'
    provenance['card'] = bind(tmp_path/'card.md', card.encode())
    context = {'schema': single.SCHEMA, 'sealed': True, 'complete': True, 'losers_included': True, 'losers': [],
       'candidate': candidate, 'window': {'from': '2025-01-01', 'to': '2025-12-31'}, 'timezone': 'UTC',
       'initial_balance': 100000, 'frequency': 'CALENDAR_DAY', 'costs_attested': True,
       'selection_mode': 'DECLARED_SINGLE_CONFIGURATION', 'declared_trial_count': 1,
       'selection_trial_count': 1, 'research_trial_count': 0, 'effective_trial_count': 1, 'cohort_std_daily': 0,
       'build_identity': {k+'_sha256': provenance[k]['sha256'] for k in ('mq5','ex5','setfile')}, 'provenance': provenance,
       'search_history': {'complete': True, 'unit': 'candidate_configuration',
          'annual_measurements_are_trials': False,
          'factory_search_ledger': {'schema': 'qm.factory-search-before-q08-claim/v1',
             'complete': True, 'q08_work_item_id': 'q08',
             'q08_claimed_at_utc': '2026-01-02T00:00:00+00:00',
             'work_items_examined': 0, 'optimization_rows': []}}}
    return context, declaration


def work_items_db():
    con = sqlite3.connect(':memory:')
    con.row_factory = sqlite3.Row
    con.execute('''CREATE TABLE work_items(
        id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT,
        created_at TEXT, payload_json TEXT)''')
    return con


def trades(values):
    return [{'ts_utc': (dt.datetime(2025,1,1,tzinfo=dt.UTC)+dt.timedelta(days=i)).isoformat(), 'net': x} for i,x in enumerate(values)]


@pytest.mark.parametrize('values,status', [([200,-100]*182,'PASS'),([-200,100]*182,'FAIL'),([0]*365,'INSUFFICIENT')])
def test_evaluate_single(tmp_path, values, status):
    context,_ = fixture(tmp_path)
    result = v2.evaluate(trades(values), binding=producer.seal(context,tmp_path/'sealed'), ea_id='QM5_42', symbol='EURUSD.DWX')
    assert result['status'] == status
    assert result['threshold'] == .05
    assert result['evidence']['selection_correction_applied'] is False
    if status != 'INSUFFICIENT': assert result['evidence']['expected_max_sharpe_daily'] == 0


@pytest.mark.parametrize('change', ['silent','approval','hash','set','source_input','spec','build','research','candidate','duplicate','history','count'])
def test_refusals(tmp_path, change):
    context,decl = fixture(tmp_path); prov=context['provenance']
    if change == 'silent': prov['card']=bind(tmp_path/'card.md', b'---\ng0_status: APPROVED\n---\nFixed defaults')
    if change == 'approval':
        p=Path(prov['card']['path']);prov['card']=bind(p,p.read_bytes().replace(b'APPROVED',b'PENDING'))
    if change == 'hash': Path(prov['ex5']['path']).write_bytes(b'changed')
    if change == 'set':
        prov['setfile']=bind(tmp_path/'setfile.txt',b'strategy_period=10\nRISK_FIXED=1000\n');context['build_identity']['setfile_sha256']=prov['setfile']['sha256']
    if change == 'source_input':
        prov['mq5']=bind(tmp_path/'mq5.txt',b'input int extra=2;');context['build_identity']['mq5_sha256']=prov['mq5']['sha256']
    if change == 'spec': prov['spec']=bind(tmp_path/'spec.txt', b'changed')
    if change == 'build': context['build_identity']['mq5_sha256']='0'*64
    if change == 'research':
        p=Path(prov['card']['path']);prov['card']=bind(p,p.read_bytes().replace(b'"research_trial_count": 0',b'"research_trial_count": 1'))
    if change == 'candidate': context['candidate']['symbol']='GBPUSD.DWX'
    if change == 'duplicate':
        p=Path(prov['card']['path']);prov['card']=bind(p,p.read_bytes().replace(b'"complete": true',b'"complete": true, "complete": false'))
    if change == 'history': context['search_history']['complete']=False
    if change == 'count': context['effective_trial_count']=2
    result=v2.evaluate(trades([200,-100]*182),binding=producer.seal(context,tmp_path/'out'),ea_id='QM5_42',symbol='EURUSD.DWX')
    assert result['status']=='INVALID'


def test_producer_and_deterministic_seal(tmp_path, monkeypatch):
    context, decl = fixture(tmp_path)
    # Redirect the approved-card root only; validate/IO/hash functions are real.
    original = producer.Path
    card_root=tmp_path/'cards';card_root.mkdir()
    ea=tmp_path/'QM5_42_fixture';(ea/'sets').mkdir(parents=True)
    for role,name in [('mq5','QM5_42_fixture.mq5'),('ex5','QM5_42_fixture.ex5'),('spec','SPEC.md'),('setfile','sets/baseline.set')]:
        (ea/name).write_bytes(Path(context['provenance'][role]['path']).read_bytes())
    (card_root/'QM5_42_fixture.md').write_bytes(Path(context['provenance']['card']['path']).read_bytes())
    monkeypatch.setattr(producer,'Path',lambda p: card_root if str(p)=='D:/QM/strategy_farm/artifacts/cards_approved' else original(p))
    con = work_items_db()
    row={'id':'q08','kind':'backtest','phase':'Q08','ea_id':'QM5_42','symbol':'EURUSD.DWX',
         'setfile_path':str(ea/'sets/baseline.set'),**context['build_identity']}
    payload={'claimed_at_iso':'2026-01-02T00:00:00+00:00'}
    doc=producer.assemble_single_configuration(con,row,payload,'D1',context['window'])
    assert doc['declared_trial_count']==1 and doc['losers']==[]
    assert doc['search_history']['factory_search_ledger']['optimization_rows'] == []
    assert producer.seal(doc,tmp_path/'out')==producer.seal(doc,tmp_path/'out')


def test_single_configuration_candidate_uses_replacement_set_binding(tmp_path, monkeypatch):
    context, _ = fixture(tmp_path)
    original = producer.Path
    card_root = tmp_path/'cards'; card_root.mkdir()
    ea = tmp_path/'QM5_42_fixture'; (ea/'sets').mkdir(parents=True)
    for role, name in [('mq5','QM5_42_fixture.mq5'),
                       ('ex5','QM5_42_fixture.ex5'), ('spec','SPEC.md')]:
        (ea/name).write_bytes(Path(context['provenance'][role]['path']).read_bytes())
    replacement = ea/'sets/QM5_42_fixture_EURUSD.DWX_D1_backtest_s20260906-001.set'
    replacement.write_bytes(Path(context['provenance']['setfile']['path']).read_bytes())
    replacement_sha = producer.sha256_file(replacement)
    (card_root/'QM5_42_fixture.md').write_bytes(
        Path(context['provenance']['card']['path']).read_bytes())
    monkeypatch.setattr(
        producer, 'Path',
        lambda p: card_root if str(p)=='D:/QM/strategy_farm/artifacts/cards_approved'
        else original(p))
    con = work_items_db()
    row = {'id':'q08', 'kind':'backtest', 'phase':'Q08', 'ea_id':'QM5_42',
           'symbol':'EURUSD.DWX', 'setfile_path':str(replacement),
           'mq5_sha256':context['build_identity']['mq5_sha256'],
           'ex5_sha256':context['build_identity']['ex5_sha256'],
           'setfile_sha256':replacement_sha}
    payload = {
        'claimed_at_iso':'2026-01-02T00:00:00+00:00',
        'replacement_setfile_sha256':replacement_sha,
        'expected_setfile_sha256':replacement_sha,
        'artifact_identity':{'setfile_sha256':replacement_sha},
    }
    doc = producer.assemble_single_configuration(
        con, row, payload, 'D1', context['window'])
    assert doc['build_identity']['setfile_sha256'] == replacement_sha
    assert doc['provenance']['setfile']['sha256'] == replacement_sha


@pytest.mark.parametrize('phase', ['OPT_CENSUS', 'OPT_OTHER', 'Q12', 'Q13', 'Q14', 'Q15', 'Q16'])
def test_producer_refuses_factory_search_before_q08_claim(tmp_path, monkeypatch, phase):
    context, _ = fixture(tmp_path)
    original = producer.Path
    card_root=tmp_path/'cards';card_root.mkdir()
    ea=tmp_path/'QM5_42_fixture';(ea/'sets').mkdir(parents=True)
    for role,name in [('mq5','QM5_42_fixture.mq5'),('ex5','QM5_42_fixture.ex5'),
                      ('spec','SPEC.md'),('setfile','sets/baseline.set')]:
        (ea/name).write_bytes(Path(context['provenance'][role]['path']).read_bytes())
    (card_root/'QM5_42_fixture.md').write_bytes(Path(context['provenance']['card']['path']).read_bytes())
    monkeypatch.setattr(producer,'Path',lambda p: card_root if str(p)=='D:/QM/strategy_farm/artifacts/cards_approved' else original(p))
    con = work_items_db()
    con.execute('INSERT INTO work_items VALUES(?,?,?,?,?,?)',
                ('prior','analytic',phase,'QM5_42','2026-01-01T00:00:00+00:00','{}'))
    row={'id':'q08','kind':'backtest','phase':'Q08','ea_id':'QM5_42','symbol':'EURUSD.DWX',
         'setfile_path':str(ea/'sets/baseline.set'),**context['build_identity']}
    with pytest.raises(producer.CohortUnavailable, match='FACTORY_SEARCH_LEDGER_PRECEDES_Q08'):
        producer.assemble_single_configuration(
            con, row, {'claimed_at_iso':'2026-01-02T00:00:00+00:00'},
            'D1', context['window'])


def test_effective_lock_includes_omitted_source_defaults():
    source = b'input int explicit_value=9;\ninput string omitted_value="fixed";\n'
    setfile = b'explicit_value=10\n'
    assert single.effective_parameters(source, setfile) == {
        'explicit_value': '10', 'omitted_value': 'fixed'}


def test_factory_search_marker_refuses_but_post_claim_row_does_not():
    con = work_items_db()
    con.execute('INSERT INTO work_items VALUES(?,?,?,?,?,?)',
                ('prior','backtest','Q07','QM5_42','2026-01-01T00:00:00Z',
                 '{"route":"optimization_fork"}'))
    con.execute('INSERT INTO work_items VALUES(?,?,?,?,?,?)',
                ('future','analytic','Q14','QM5_42','2026-01-03T00:00:00Z','{}'))
    row = {'id':'q08','phase':'Q08','ea_id':'QM5_42'}
    payload = {'claimed_at_iso':'2026-01-02T00:00:00+00:00'}
    with pytest.raises(producer.CohortUnavailable, match='FACTORY_SEARCH_LEDGER_PRECEDES_Q08'):
        producer._factory_search_before_q08_claim(con, row, payload)
    con.execute("DELETE FROM work_items WHERE id='prior'")
    proof = producer._factory_search_before_q08_claim(con, row, payload)
    assert proof['optimization_rows'] == []
    assert proof['work_items_examined'] == 0

def test_canonical_ea_id_matches_aggregator_int_and_work_item_label():
    # 2026-09-06: farmctl passes --ea-id 11167 to q08_davey/aggregate.py while the sealed candidate says QM5_11167;
    # the literal string compare produced DSR_V2_SINGLE_CONFIG_CANDIDATE_MISMATCH on every single-config rerun (19c9df13).
    from tools.strategy_farm.dsr_single_configuration import canonical_ea_id
    assert canonical_ea_id(11167) == canonical_ea_id('QM5_11167') == canonical_ea_id('11167') == canonical_ea_id('qm5_11167') == '11167'
    assert canonical_ea_id('QM5_11168') != canonical_ea_id(11167)
    assert canonical_ea_id('QM5_41372_XTI_XNG') == '41372'
