import copy
import json
import sqlite3
from pathlib import Path
import pytest
from tools.strategy_farm import window_sweep as w
from tools.strategy_farm import opt_census

def test_grid_and_unchanged_inputs():
    grid=w.stage_a()
    assert len(grid)==60 and (3,3,18) in grid
    cells=w.cells_for(grid,Path('fixture'))
    assert len(cells)==len({c['work_item_id'] for c in cells})==420
    base=w.text(w.BASE);original=w.inputs(base)
    for cell in cells:
        changed=w.inputs(w.render(base,cell))
        assert {k:v for k,v in changed.items() if k not in ('strategy_range_start_hour','strategy_range_end_hour','strategy_exit_hour')}=={k:v for k,v in original.items() if k not in ('strategy_range_start_hour','strategy_range_end_hour','strategy_exit_hour')}

@pytest.fixture
def queue(tmp_path,monkeypatch):
    db=tmp_path/'farm.sqlite';c=sqlite3.connect(db)
    c.execute('CREATE TABLE work_items(id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,setfile_path TEXT,status TEXT,verdict TEXT,attempt_count INT,payload_json TEXT,created_at TEXT,updated_at TEXT,evidence_path TEXT,claimed_by TEXT)')
    c.execute("INSERT INTO work_items(id,phase,ea_id,status,payload_json) VALUES('reference','OPT_CENSUS','QM5_41398','pending',?)",(json.dumps({'program_id':'DL089_QM5_13213_USDJPY_DWX_2019_2025','priority_track':True,'opt_census_frontier_priority':True}),));c.commit();c.close()
    monkeypatch.setattr(opt_census,'_q02_pass',lambda *a:{'id':'q02'})
    monkeypatch.setattr(opt_census,'_harness_pass',lambda *a:{'id':'fixture'})
    return db,tmp_path/'program'

def test_enqueue_dry_run_and_repeat_are_idempotent(queue):
    db,art=queue
    assert w.enqueue(w.build_plan(art=art),db,art)['new_rows']==420
    assert not (art/'declaration.json').exists()
    assert w.enqueue(w.build_plan(art=art),db,art,True)['inserted']==420
    assert w.enqueue(w.build_plan(art=art),db,art,True)['inserted']==0
    c=sqlite3.connect(db)
    assert c.execute('SELECT count(*) FROM work_items').fetchone()[0]==421
    original=c.execute("SELECT payload_json FROM work_items WHERE id='reference'").fetchone()[0]
    assert 'declaration_sha256' not in original
    payload=json.loads(c.execute("SELECT payload_json FROM work_items WHERE id!='reference' LIMIT 1").fetchone()[0])
    _,ledger=w.authenticate_ledger(payload)
    assert len(ledger['cells'])==420
    Path(ledger['cells'][0]['setfile_path']).write_text('tampered')
    with pytest.raises(w.SweepError,match='setfile binding'):w.authenticate_ledger(payload)

def test_identity_and_grid_tampering_fail(queue):
    db,art=queue;w.enqueue(w.build_plan(art=art),db,art,True)
    c=sqlite3.connect(db);payload=json.loads(c.execute("SELECT payload_json FROM work_items WHERE id!='reference' LIMIT 1").fetchone()[0])
    bad=dict(payload,expected_ex5_sha256='0'*64)
    with pytest.raises(w.SweepError,match='binary/source'):w.authenticate_ledger(bad)
    p=art/'ledger.json';ledger=json.loads(p.read_text());ledger['cells'].pop();w.write_json(p,ledger)
    with pytest.raises(w.SweepError,match='incomplete ledger'):w.authenticate_ledger(payload)

def test_declaration_tamper():
    d=w.declaration();d['parameter_count']=4
    with pytest.raises(w.SweepError,match='hash mismatch'):w.validate_declaration(d)

def synthetic(score=1):
    return [{'start':s,'length':n,'exit':x,'years':{y:{'trades':50,'entry_days':20,'score':score,'costed_trade_pnl':[2,-1]} for y in w.YEARS}} for s,n,x in w.stage_a()]

def test_no_selection_from_partial_or_missing_year():
    data=synthetic();del data[0]['years'][2025]
    assert w.select(data)['winner'] is None
    assert not w.select(data)['complete']

def test_tie_break_and_no_fictitious_improvement():
    result=w.select(synthetic())
    assert (result['winner']['length'],result['winner']['start'])==(2,0)
    assert result['refutation']=='REFUTED'

def test_admissibility_before_selection():
    data=synthetic();data[0]['years'][2019]['entry_days']=9
    result=w.select(data)
    assert (result['winner']['length'],result['winner']['start'])==(2,1)

def test_oos_failure_refutes_even_with_dev_improvement():
    data=synthetic()
    for item in data:
        if item['start']>=6:
            for year in (2019,2020,2021,2022):item['years'][year]['score']=5
            for year in (2023,2024,2025):item['years'][year].update(score=-1,costed_trade_pnl=[1,-2])
    result=w.select(data)
    assert result['dev_improvement'] and not result['oos_confirmation']
    assert result['refutation']=='REFUTED'

def test_inadmissible_grid_neighbor_does_not_change_declared_topology():
    data=synthetic();data[0]['years'][2019].update(entry_days=0,trades=0)
    for y in w.YEARS:data[0]['years'][y]['score']=-100
    w.select(data)
    assert data[0]['admissible'] is False
    assert data[0]['dev_score']==-100
    assert data[0]['plateau_score']==1

def test_empty_report_has_420_explicit_missing_cells(queue,tmp_path):
    db,art=queue;w.write_json(art/'declaration.json',w.declaration(art))
    result=w.report(art,db,tmp_path/'surface.csv')
    assert len(result['missing_or_unusable_cells'])==420
    assert result['winner'] is None
    assert len((tmp_path/'surface.csv').read_text().splitlines())==421

def test_stage_b_requires_complete_same_declaration(tmp_path):
    p=tmp_path/'report.json';w.write_json(p,{'complete':False})
    with pytest.raises(w.SweepError,match='incomplete'):w.build_plan('B',tmp_path,p)

def test_worker_malformed_window_payload_cannot_use_legacy_mode():
    from tools.strategy_farm import terminal_worker as worker
    assert worker._is_governed_dl089_census_payload({'schema':w.SCHEMA})
    assert not worker._is_governed_dl089_census_payload({'schema':'legacy'})
    with pytest.raises(w.SweepError):w.authenticate_ledger({'schema':w.SCHEMA,'program_id':'OTHER'})

def test_stale_worker_blocks_production_enqueue(monkeypatch):
    monkeypatch.setattr(w.subprocess,'check_output',lambda *a,**kw:json.dumps([{'pid':7,'started':1,'command':'python C:/QM/repo/tools/strategy_farm/terminal_worker.py'}]))
    with pytest.raises(w.SweepError,match='WORKER_ROLLOUT_REQUIRED'):w.require_current_workers()

def test_native_identity_missing_is_not_measured(tmp_path):
    p=tmp_path/'summary.json';w.write_json(p,{'runs':[{'status':'OK'}]})
    with pytest.raises(w.SweepError,match='identity/window'):w.measure(p,{'evidence_binding_required':True})

def test_payload_date_tampering_is_rejected(queue):
    db,art=queue;w.enqueue(w.build_plan(art=art),db,art,True)
    c=sqlite3.connect(db);payload=json.loads(c.execute("SELECT payload_json FROM work_items WHERE id!='reference' LIMIT 1").fetchone()[0]);c.close()
    payload['expected_to_date']='2026.12.31'
    with pytest.raises(w.SweepError,match='expected_to_date'):w.authenticate_ledger(payload)
