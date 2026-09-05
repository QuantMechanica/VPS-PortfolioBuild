"""Behavioral fixtures for inactive option B; no production paths or writes."""
import copy
from datetime import timedelta
import importlib.resources
import json
from pathlib import Path
import sys

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / 'tools' / 'strategy_farm'))
import news_calendar_scoped_consumer as scope
import q09_news_calendar as legacy


def tzbytes(name='Europe/Prague'):
    return importlib.resources.files('tzdata.zoneinfo').joinpath(*name.split('/')).read_bytes()


def fixture(*, declarations=None, whole_days=False, before=0, after=0):
    env = {'from_utc': '2026-01-01T00:00:00Z', 'to_utc': '2027-01-01T00:00:00Z'}
    currencies = ['USD', 'EUR', 'AUD', 'JPY']
    classes = {'CPI': ['HIGH'], 'EMPLOYMENT': ['HIGH', 'MEDIUM']}
    coverage = [{'currency': c, 'event_class': k, **env, 'evidence_id': 'SOURCE-' + c + '-' + k}
                for c in currencies for k in classes]
    raw = b'datetime_utc,currency,event_class,impact\n2026-02-02T13:30:00Z,USD,CPI,HIGH\n'
    csvs = dict.fromkeys(scope.FILES, raw)
    s = {'schema': scope.SCHEMA, 'consumer_version': scope.CONSUMER,
         'csv_sha256': {n: scope.sha(r) for n, r in csvs.items()},
         'csv_columns': {n: {'time': 'datetime_utc', 'currency': 'currency', 'class': 'event_class', 'impact': 'impact'} for n in scope.FILES},
         'coverage_envelope': env, 'coverage_assertions': coverage,
         'mapping': {'schema': scope.MAPPING_SCHEMA, 'version': 'fixture-mapping-1',
                     'event_classes': classes,
                     'symbols': {'EURUSD': {'currencies': ['EUR', 'USD']}, 'AUDJPY': {'currencies': ['AUD', 'JPY']},
                                 'BASKET': {'constituents': ['EURUSD', 'AUDJPY']}}},
         'window_policy': {'schema': scope.POLICY_SCHEMA, 'look_back_seconds': before, 'look_ahead_seconds': after,
                           'whole_local_days': whole_days, 'timezone': 'Europe/Prague', 'tzif_sha256': scope.sha(tzbytes())},
         'declarations': [] if declarations is None else declarations}
    return s, csvs


def declaration(currency='USD', months=None, cls='CPI', id='D-1', gate='6.1', reason='UNMEASURED'):
    return {'id': id, 'currency': currency, 'months': months or ['2026-03'], 'event_class': cls,
            'gate': gate, 'reason': reason, 'required_evidence': 'official anchors and footprint',
            'usage': 'INADMISSIBLE', 'production_use_permitted': False}


def package(s, csvs):
    s = copy.deepcopy(s)
    proof = scope.canonical({'schema': scope.PROOF_SCHEMA, 'measured_full_scope_pass': False,
                             'coverage_envelope': s['coverage_envelope'], 'coverage_assertions': s['coverage_assertions'],
                             'declarations_sha256': scope.sha(scope.canonical(s['declarations']))})
    s['source_proof_sha256'] = scope.sha(proof)
    raw = scope.canonical(s)
    return {'sidecar': raw, 'csv_bytes': csvs, 'source_proof': proof,
            'timezone_bytes': tzbytes(), 'expected_sidecar_sha256': scope.sha(raw)}


def bound(**kwargs):
    return scope.load(**package(*fixture(**kwargs)))


def request(b, start='2026-02-03T00:00:00Z', end='2026-02-04T00:00:00Z', symbols=None):
    return {'consumer_version': scope.CONSUMER, 'bundle_sha256': b.bundle_sha256,
            'window_policy_sha256': scope.sha(scope.canonical(scope.strict(b.sidecar)['window_policy'])),
            'from_utc': start, 'to_utc': end, 'symbols': ['EURUSD'] if symbols is None else symbols}


def test_flag_off_preserves_bytes_identity_and_does_not_touch_scoped_path(monkeypatch):
    monkeypatch.delenv(scope.FLAG, raising=False)
    original = {'status': 'CONFIG_LOCKED', 'raw': 'literal\r\n', 'nested': {'risk': 1}}
    raw = scope.canonical(original)
    for value in [None, '0', 'false', '', 'TRUE', '01']:
        env = {} if value is None else {scope.FLAG: value}
        for consumer in ['ENTRY', 'BOUNDARY', 'POSITIONS', 'Q09', 'Q10', 'ADMISSION']:
            out = scope.project(consumer, original, None, env=env)
            assert out is original and scope.canonical(out) == raw
        assert scope.consume(legacy=lambda: original, scoped=lambda: pytest.fail('scope read while off'), env=env) is original
        assert scope.experiment(None, None, expected_cells=None, legacy_result=original, env=env) is original


@pytest.mark.parametrize('field', ['sidecar', 'source_proof', 'timezone_bytes'])
def test_raw_tampering_refused(field):
    p = package(*fixture()); p[field] += b' '
    with pytest.raises(scope.ScopeError): scope.load(**p)


@pytest.mark.parametrize('name', scope.FILES)
def test_each_csv_hash_bound(name):
    p = package(*fixture()); p['csv_bytes'] = dict(p['csv_bytes']); p['csv_bytes'][name] += b'\n'
    with pytest.raises(scope.ScopeError, match='CSV SHA-256 mismatch'): scope.load(**p)


@pytest.mark.parametrize('field', ['sidecar', 'source_proof', 'timezone_bytes'])
def test_missing_bytes_refused(field):
    p = package(*fixture()); p[field] = b''
    with pytest.raises(scope.ScopeError): scope.load(**p)


@pytest.mark.parametrize('mutation', [
    lambda s: s.update(schema='unknown/v4'),
    lambda s: s.update(consumer_version='legacy/v2'),
    lambda s: s['mapping'].update(schema='unknown/v2'),
    lambda s: s['mapping'].update(symbols={}),
    lambda s: s['mapping'].update(event_classes={}),
    lambda s: s['mapping']['symbols'].update(BASKET={'constituents': []}),
    lambda s: s['mapping']['symbols'].update(BASKET={'constituents': ['UNKNOWN']}),
    lambda s: s['mapping']['symbols'].update(BASKET={'constituents': ['BASKET']}),
    lambda s: s['mapping']['symbols'].update(EURUSD={'currencies': []}),
    lambda s: s.update(coverage_assertions=[]),
    lambda s: s['coverage_assertions'][0].update(event_class='UNKNOWN'),
    lambda s: s['window_policy'].update(look_back_seconds=-1),
    lambda s: s['window_policy'].update(whole_local_days=None),
    lambda s: s.update(declarations=[declaration(cls='UNKNOWN')]),
    lambda s: s.update(declarations=[declaration(currency='ZZZ')]),
    lambda s: s.update(declarations=[declaration(months=['2026-13'])]),
    lambda s: s.update(declarations=[declaration(), declaration()]),
])
def test_semantic_negatives_with_resealed_fixture(mutation):
    s, csvs = fixture(); mutation(s)
    with pytest.raises(scope.ScopeError): scope.load(**package(s, csvs))


def test_duplicate_json_key_refused_even_with_matching_raw_hash():
    p = package(*fixture()); p['sidecar'] = b'{"schema":"x","schema":"x"}'; p['expected_sidecar_sha256'] = scope.sha(p['sidecar'])
    with pytest.raises(scope.ScopeError, match='duplicate'): scope.load(**p)


@pytest.mark.parametrize('raw', [b'', b'datetime_utc,currency,event_class,impact\n',
    b'datetime_utc,currency,event_class,impact\n2026-02-02T13:30:00Z,USD,UNKNOWN,HIGH\n',
    b'datetime_utc,currency,event_class,impact\n2026-02-02T13:30:00Z,USD,CPI,EXTREME\n',
    b'datetime_utc,currency,event_class,impact\n2026-02-02 13:30:00,USD,CPI,HIGH\n'])
def test_empty_or_unknown_csv_cannot_be_resealed_into_healthy_scope(raw):
    s, csvs = fixture(); csvs[scope.FILES[0]] = raw; s['csv_sha256'][scope.FILES[0]] = scope.sha(raw)
    with pytest.raises(scope.ScopeError): scope.load(**package(s, csvs))


@pytest.mark.parametrize('symbols', [[], ['UNKNOWN'], ['EURUSD', 'UNKNOWN']])
def test_unknown_or_empty_requested_exposure_unconfirmed(symbols):
    b = bound(); result = scope.availability(b, request(b, symbols=symbols))
    assert result['availability'] == 'UNCONFIRMED' and not result['new_release_credit']


def test_utc_month_half_open_and_lookback_crossing():
    d = declaration(months=['2026-01'])
    b = bound(declarations=[d])
    assert scope.availability(b, request(b, '2026-02-01T00:00:00Z', '2026-02-01T00:01:00Z'))['availability'] == 'AVAILABLE'
    b = bound(declarations=[d], before=1)
    result = scope.availability(b, request(b, '2026-02-01T00:00:00Z', '2026-02-01T00:01:00Z'))
    assert result['availability'] == 'UNCONFIRMED' and result['declaration_ids'] == ['D-1']


def test_lookahead_crosses_next_month():
    b = bound(declarations=[declaration()], after=1)
    result = scope.availability(b, request(b, '2026-02-28T23:59:58Z', '2026-03-01T00:00:00Z'))
    assert result['availability'] == 'UNCONFIRMED'


@pytest.mark.parametrize('day,hours', [('2026-03-29', 23), ('2026-10-25', 25)])
def test_dst_whole_day_uses_sealed_rule_bytes(day, hours):
    b = bound(whole_days=True)
    a, z = scope.expanded_window(b, request(b, day+'T10:00:00Z', day+'T11:00:00Z'))
    assert z-a == timedelta(hours=hours)


def test_wildcard_union_all_gates_reasons_and_nonhost_basket_exposure():
    ds = [declaration(currency='ALL', id='ALL', reason='GLOBAL'),
          declaration(currency='JPY', id='J', gate='6.5', reason='JAPAN', cls='ALL_HIGH'),
          declaration(currency='AUD', id='A', gate='6.7', reason='AUSTRALIA', cls='EMPLOYMENT')]
    b = bound(declarations=ds)
    result = scope.availability(b, request(b, '2026-03-02T00:00:00Z', '2026-03-03T00:00:00Z', ['BASKET']))
    assert result['currencies'] == ['AUD', 'EUR', 'JPY', 'USD']
    assert result['declaration_ids'] == ['A', 'ALL', 'J']
    assert result['declaration_gates'] == ['6.1', '6.5', '6.7']
    assert result['reasons'] == ['AUSTRALIA', 'GLOBAL', 'JAPAN']


def test_coverage_gap_and_outside_envelope_are_unknown():
    s, csvs = fixture(); s['coverage_assertions'] = [r for r in s['coverage_assertions'] if (r['currency'],r['event_class']) != ('EUR','CPI')]
    b = scope.load(**package(s, csvs)); r = scope.availability(b, request(b))
    assert r['missing_coverage'] == ['EUR/CPI'] and r['availability'] == 'UNCONFIRMED'
    b = bound(); r = scope.availability(b, request(b, '2025-12-31T23:59:59Z', '2026-01-01T00:00:01Z'))
    assert 'OUTSIDE_COVERAGE_ENVELOPE' in r['reasons']


def test_adjacent_assertions_cover_but_one_second_gap_does_not():
    s, csvs = fixture(); row = s['coverage_assertions'][0]
    half = {**row, 'from_utc': '2026-02-03T12:00:00Z'}; row['to_utc'] = half['from_utc']; s['coverage_assertions'].append(half)
    b = scope.load(**package(s, csvs)); assert scope.availability(b, request(b))['availability'] == 'AVAILABLE'
    half['from_utc'] = '2026-02-03T12:00:01Z'
    b = scope.load(**package(s, csvs)); assert scope.availability(b, request(b))['availability'] == 'UNCONFIRMED'


@pytest.mark.parametrize('consumer,status', [('ENTRY','BLACKOUT_UNKNOWN'),('BOUNDARY','DATA_ERROR'),('Q09','UNCONFIRMED'),('Q10','UNCONFIRMED')])
def test_consumer_responses_never_healthy_none_or_selection(consumer, status):
    b = bound(declarations=[declaration()]); assessment = scope.availability(b, request(b, '2026-03-02T00:00:00Z','2026-03-03T00:00:00Z'))
    old = {'status': 'CONFIG_LOCKED', 'event_time': 'known', 'config_locked': True, 'fallback_off_credit': True}
    result = scope.project(consumer, old, assessment, env={scope.FLAG:'1'})
    assert result['status'] == status and result['new_release_credit'] is False
    assert old['status'] == 'CONFIG_LOCKED'
    if consumer in ['Q09','Q10']: assert not result['config_locked'] and not result['fallback_off_credit']
    if consumer == 'BOUNDARY': assert result['event_time'] is None and result['safe_close_time'] is None


def test_positions_and_admission_keep_protections_and_deny_credit():
    bad = {'availability':'UNCONFIRMED','declaration_ids':['D-1']}
    r = scope.project('POSITIONS', {'emergency_stop':'original'}, bad, env={scope.FLAG:'1'})
    assert r['emergency_stop']=='original' and r['preserve_emergency_protections'] and r['preserve_risk_reduction']
    assert r['scope_forced_close_time'] is None and not r['compliance_certified']
    assert not scope.project('ADMISSION',{},bad,env={scope.FLAG:'1'})['admission_credit']


def test_available_scope_still_defers_to_legacy_news_filter():
    b=bound(); old={'status':'NEWS_BLACKOUT','entry_authorized':False}
    assert scope.project('ENTRY',old,scope.availability(b,request(b)),env={scope.FLAG:'1'}) is old


def test_zero_trades_missing_cells_and_control_policy_same_denominator():
    b=bound(declarations=[declaration()]); req=request(b,'2026-03-02T00:00:00Z','2026-03-03T00:00:00Z')
    roster=[{'id':arm,'request':req} for arm in ['OFF','TEMPORAL','COMPLIANCE']]
    observed=[{**r,'trades':0,'result':{'status':'PASS'}} for r in roster[:2]]
    r=scope.experiment(b,observed,expected_cells=roster,legacy_result={'status':'CONFIG_LOCKED'},env={scope.FLAG:'1'})
    assert r['availability']=='UNCONFIRMED' and r['attempted_cells']==3 and r['missing_cells']==1 and r['unconfirmed_cells']==3
    assert not r['selection_credit'] and [x['trades'] for x in r['cells']]==[0,0,None]


def test_censoring_one_arm_cannot_gain_credit():
    b=bound(); req=request(b); roster=[{'id':'OFF','request':req},{'id':'ON','request':req}]
    obs=[{**r,'trades':1,'result':{'status':'PASS'}} for r in roster]
    obs[1]['request']={**req,'from_utc':'2026-02-03T12:00:00Z'}
    result=scope.experiment(b,obs,expected_cells=roster,legacy_result={},env={scope.FLAG:'1'})
    assert result['availability']=='UNCONFIRMED' and result['attempted_cells']==2
    roster[1]['request']=obs[1]['request']
    with pytest.raises(scope.ScopeError,match='mixed'): scope.experiment(b,obs,expected_cells=roster,legacy_result={},env={scope.FLAG:'1'})


def test_all_sidecar_bytes_and_window_changes_change_every_identity():
    b=bound(); r=request(b); p=scope.bind_run_plan(b,r,implementation_sha256='a'*64,legacy_input_bytes=b'fixed legacy')
    values=[b.bundle_sha256,p['run_plan_sha256'],p['effective_input_sha256']]
    s,csvs=fixture(); s['mapping']['version']='fixture-mapping-2'; other=scope.load(**package(s,csvs))
    q=scope.bind_run_plan(other,request(other),implementation_sha256='a'*64,legacy_input_bytes=b'fixed legacy')
    assert all(x!=y for x,y in zip(values,[other.bundle_sha256,q['run_plan_sha256'],q['effective_input_sha256']]))
    q=scope.bind_run_plan(b,{**r,'to_utc':'2026-02-05T00:00:00Z'},implementation_sha256='a'*64,legacy_input_bytes=b'fixed legacy')
    assert q['run_plan_sha256']!=p['run_plan_sha256'] and q['effective_input_sha256']!=p['effective_input_sha256']
    # Even whitespace in a valid sidecar is a different sealed input.
    pkg=package(*fixture()); pkg['sidecar']+=b' '; pkg['expected_sidecar_sha256']=scope.sha(pkg['sidecar'])
    assert scope.load(**pkg).bundle_sha256!=b.bundle_sha256


def test_legacy_python_and_ea_refuse_scoped_version_before_dispatch(tmp_path):
    b=bound(); (tmp_path/'manifest.json').write_bytes(scope.canonical({'schema_version':scope.SCHEMA,'bundle_id':b.bundle_id}))
    with pytest.raises(legacy.CalendarBundleError,match='unsupported'): legacy.verify_bundle(tmp_path)
    # The actual untouched EA function rejects this distinct prefix before CSV load.
    source=(REPO/'framework/include/QM/QM_NewsFilter.mqh').read_text(encoding='utf-8')
    a=source.index('bool QM_NewsBundleIdValid'); z=source.index('bool QM_NewsNormalizeCommonRelativePath',a)
    assert 'StringFind(bundle_id, "Q09CAL-") != 0' in source[a:z]
    assert not b.bundle_id.upper().startswith('Q09CAL-')


def test_receipt_and_new_include_are_bound_without_active_ea_changes():
    b=bound(declarations=[declaration()]); r=request(b,'2026-03-02T00:00:00Z','2026-03-03T00:00:00Z')
    include=REPO/'framework/include/QM/QM_NewsScopeV1.mqh'
    p=scope.bind_run_plan(b,r,implementation_sha256=scope.sha(include.read_bytes()),legacy_input_bytes=b'fixture only')
    receipt=scope.ea_receipt(b,p); lines=receipt.decode().splitlines()
    assert len(lines)==14 and lines[0]=='QM_SCOPE_V1' and lines[1]==b.bundle_id and lines[10]=='UNCONFIRMED' and lines[12]=='D-1'
    p['effective_input_sha256']='b'*64
    with pytest.raises(scope.ScopeError): scope.ea_receipt(b,p)
    code=include.read_text(encoding='utf-8')
    assert 'm_enabled=false' in code and 'if(!m_enabled) return true;' in code
    assert 'QM_SCOPE_BLACKOUT_UNKNOWN' in code and 'QM_SCOPE_DATA_ERROR' in code
    assert 'CopyCalendarBytes' in code and 'OrderSend(' not in code and 'PositionClose(' not in code
    assert not any('QM_NewsScopeV1.mqh' in f.read_text(encoding='utf-8',errors='ignore') for f in (REPO/'framework/EAs').glob('*/*.mq5'))


def test_fractional_utc_receipt_cannot_widen_start_by_truncation():
    b=bound(); r=request(b,'2026-02-03T00:00:00.999Z','2026-02-04T00:00:00Z')
    p=scope.bind_run_plan(b,r,implementation_sha256='a'*64,legacy_input_bytes=b'fixture')
    with pytest.raises(scope.ScopeError,match='whole UTC seconds'): scope.ea_receipt(b,p)
