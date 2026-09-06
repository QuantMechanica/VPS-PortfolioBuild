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
