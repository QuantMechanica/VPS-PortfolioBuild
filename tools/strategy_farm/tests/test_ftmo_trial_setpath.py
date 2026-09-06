from pathlib import Path
import hashlib
import json
import sqlite3
import pytest
from tools.strategy_farm.ftmo import trial_setpath as s

BASE=b'; environment: backtest\nRISK_FIXED=1000\nRISK_PERCENT=0\nLookback=17\nPORTFOLIO_WEIGHT=1\nqm_magic_slot_offset=3\n'

def test_derivation_freezes_every_other_parameter():
    data,proof=s.derive(BASE,0.1)
    output=s.values(s.decode(data))
    assert output['RISK_PERCENT']=='0.1'
    assert output['RISK_FIXED']=='0'
    assert output['qm_news_temporal']=='3'
    assert output['qm_news_compliance']=='2'
    assert output['qm_news_stale_max_hours']=='336'
    assert output['qm_friday_close_enabled']=='true'
    assert output['qm_friday_close_hour_broker']=='21'
    assert proof['strategy_parameter_count']==3
    assert s.verify_derivation(s.decode(BASE),s.decode(data))==proof['strategy_identity_sha256']
    with pytest.raises(s.Refusal,match='strategy_parameters_changed'):
        s.verify_derivation(s.decode(BASE),s.decode(data).replace('Lookback=17','Lookback=18'))

@pytest.mark.parametrize('risk',[0,-1,1.1,float('nan'),float('inf')])
def test_risk_refusals(risk):
    with pytest.raises(s.Refusal): s.derive(BASE,risk)

@pytest.mark.parametrize('extra',[b'Lookback=18\n',b'qm_news_stale_max_hours=337\n',b'qm_news_stale_max_hours=nan\n',b'Param=1||1||1||2||Y\n'])
def test_unsafe_source_refusals(extra):
    with pytest.raises(s.Refusal): s.derive(BASE+extra,0.1)

def test_seal_and_source_drift(tmp_path):
    conn=sqlite3.connect(':memory:')
    conn.execute('CREATE TABLE work_items (id,ea_id,symbol,phase,status,verdict,setfile_path,evidence_path,setfile_sha256,updated_at)')
    with pytest.raises(s.Refusal,match='unsealed_source'):s.sealed_source(conn,10706,'GBPUSD')
    source=tmp_path/'source_GBPUSD.DWX_H1_backtest.set';source.write_bytes(BASE)
    seal=tmp_path/'aggregate.json';seal.write_text(json.dumps({'verdict':'CONFIG_LOCKED','schema_version':'q09-news-adjudication/v3','identities':{'baseline_setfile_sha256':s.sha(BASE)}}))
    conn.execute('INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?)',('id','QM5_10706','GBPUSD.DWX','Q10_NEWS','done','CONFIG_LOCKED',str(source),str(seal),None,'2026-09-06'))
    raw,binding=s.sealed_source(conn,10706,'GBPUSD')
    assert raw==BASE
    assert binding['timeframe']=='H1'
    source.write_bytes(BASE+b'NewParam=1\n')
    with pytest.raises(s.Refusal,match='sealed_source_hash_drift'):s.sealed_source(conn,10706,'GBPUSD')

@pytest.mark.parametrize('name',['../T_Live','C:/QM/mt5/T_Live','x/y','..','a:b'])
def test_destination_traversal(name):
    with pytest.raises(s.Refusal):s.output_path(name)

def test_existing_destination_refused(tmp_path,monkeypatch):
    monkeypatch.setattr(s,'TRIAL_ROOT',tmp_path)
    (tmp_path/'existing').mkdir()
    with pytest.raises(s.Refusal):s.output_path('existing')


def test_m13_binding_is_standard_hash_bound_and_governor_coherent():
    binding, rule, rulepack, raw = s.load_binding()
    assert binding['binding_id'] == 'FTMO_M13_STANDARD_DEMO_V1'
    assert binding['account']['observed_leverage'] == '1:100'
    assert rule['rulepack_id'] == 'FTMO_2S_100K_STANDARD_V2'
    assert binding['rulepack']['file_sha256'] == s.sha(raw)
    assert rulepack == s.RULEPACK
    assert binding['qm_demo_overlay']['news_stale_max_hours'] == 336
    assert binding['authority_boundary']['attachment_authorized'] is False
    assert binding['authority_boundary']['autotrading_authorized'] is False


def test_m13_binding_refuses_account_or_hash_drift(tmp_path):
    binding = json.loads(s.BINDING.read_text(encoding='utf-8'))
    binding['account']['observed_leverage'] = '1:30'
    path = tmp_path / 'binding.json'
    path.write_text(json.dumps(binding), encoding='utf-8')
    with pytest.raises(s.Refusal, match='wrong_standard_demo_account'):
        s.load_binding(path)

    binding['account']['observed_leverage'] = '1:100'
    binding['rulepack']['file_sha256'] = '0' * 64
    path.write_text(json.dumps(binding), encoding='utf-8')
    with pytest.raises(s.Refusal, match='rulepack_file_hash_drift'):
        s.load_binding(path)


def test_generated_manifest_names_standard_profile_and_internal_overlay(tmp_path, monkeypatch):
    monkeypatch.setattr(s, 'TRIAL_ROOT', tmp_path / 'review')
    s.TRIAL_ROOT.mkdir()
    database = tmp_path / 'farm.sqlite'
    sqlite3.connect(database).close()
    source = tmp_path / 'source_EURUSD.DWX_H1_backtest.set'
    source.write_bytes(BASE)

    def fake_sealed_source(_conn, ea, symbol):
        return BASE, {
            'ea_id': ea,
            'symbol': symbol,
            'native_symbol': s.LANES[symbol],
            'timeframe': 'H1',
            'seal_work_item_id': f'seal-{ea}',
            'source_path': str(source),
            'source_sha256': s.sha(BASE),
            'seal_path': str(tmp_path / 'seal.json'),
            'seal_sha256': '1' * 64,
            'source_role': 'SEALED_BASELINE_STRATEGY_PARAMETERS',
            'original_selected_news_config': {},
            'ex5_sha256': '2' * 64,
        }

    monkeypatch.setattr(s, 'sealed_source', fake_sealed_source)
    manifest = s.generate('standard-binding-test', 0.1, database=database)
    assert manifest['schema'] == 'qm.ftmo-trial-setpath/v3'
    assert manifest['rulepack']['id'] == 'FTMO_2S_100K_STANDARD_V2'
    assert manifest['constraints']['observed_account_leverage'] == '1:100'
    assert manifest['constraints']['provider_evaluation_news_restricted'] is False
    assert manifest['constraints']['qm_news_blackout'] == 'PRE30_POST30_PLUS_FTMO_COMPLIANCE'
    assert manifest['constraints']['qm_weekend_flat'].startswith('FRIDAY_CLOSE')
    assert manifest['installed'] is False
    assert manifest['installable'] is False
