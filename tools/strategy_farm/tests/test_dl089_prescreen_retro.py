import json
import sqlite3
from pathlib import Path
import pytest

from tools.strategy_farm import dl089_prescreen_retro as r, dl089_prescreen as p
from tools.strategy_farm import opt_census as census, opt_census_select as selector, dl089_scheduling as scheduling
from tools.strategy_farm import governed_work_item_hold as backend, rebaseline_census as rebaseline
from tools.strategy_farm.tests.test_opt_census import _plan, _db
from tools.strategy_farm.tests.test_dl089_prescreen import measure


@pytest.mark.parametrize('profits,fires,expected',[
    (['105','105'],[5,5],'ADMIT'),(['105','104.999'],[5,5],'SKIP'),(['200','200'],[4,5],'SKIP'),
    (['200',None],[4,5],'UNKNOWN'),(['200','200'],[None,5],'UNKNOWN')])
def test_classifier_needs_both_measured_years_and_exact_thresholds(profits,fires,expected):
    pairs=[({'net_profit':v} if v is not None else None,{'net_profit':'100'}) for v in profits]
    assert r.classify(pairs,fires)[0]==expected


@pytest.fixture
def program(tmp_path,monkeypatch):
    monkeypatch.setenv('QM_DL089_PRESCREEN','0')
    plan=_plan(tmp_path);db=_db(tmp_path/'db.sqlite');ledger=tmp_path/'ledger.json'
    census.enqueue(plan,db_path=db,ledger_path=ledger)
    for year in [2019,2020]:
        measure(db,plan,year,'baseline',100,tmp_path)
        measure(db,plan,year,'buy_003',100,tmp_path)
    con=sqlite3.connect(db);con.row_factory=sqlite3.Row
    con.executescript('''CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY,hold_code TEXT,reason TEXT,
        active INTEGER,release_on_restart INTEGER,created_at TEXT,updated_at TEXT,released_at TEXT,release_note TEXT);
        CREATE TABLE events(id INTEGER PRIMARY KEY,ts TEXT,entity_type TEXT,entity_id TEXT,event TEXT,detail_json TEXT);''')
    bars=tmp_path/'USDJPY.DWX_D1.csv';bars.write_text('fixture bars')
    auth=tmp_path/'authority.md';auth.write_text('| 13 | '+p.DECISION+' | released |')
    contract=p.create_contract(plan['symbol'],bars_root=tmp_path,manifest_root=tmp_path/'manifests',authority=auth)
    proof=[]
    for year in [2019,2020]:
        for arm in ['buy_003','baseline']:
            cell=next(c for c in plan['cells'] if (c['year'],c['arm'])==(year,arm))
            proof.append(p.measured(con.execute('SELECT * FROM work_items WHERE id=?',(cell['work_item_id'],)).fetchone()))
    targets=[{'id':c['work_item_id'],**{k:c[k] for k in ['cell_key','year','arm','direction','predicate_id','setfile_path']}}
             for c in plan['cells'] if c['arm']=='buy_003' and c['year']>2020]
    doc={'program_id':plan['program_id'],'ea_id':plan['ea_id'],'symbol':plan['symbol'],'ledger_path':str(ledger),
         'declaration_sha256':r.digest(r.declaration(json.loads(ledger.read_text()))),'declared_trial_count':154,
         'candidate_holds':5,'contract':contract,'targets':targets,
         'arm_decisions':{'buy_003':{'disposition':'SKIP','reason':'B2_NOT_QUALIFIED','proof':proof,'fire_counts':[5,5]}}}
    out=tmp_path/'receipts';out.mkdir()
    yield con,doc,out,ledger
    con.close()


def snapshot(con):return [tuple(v) for v in con.execute('SELECT * FROM work_items ORDER BY id')]


def test_idempotent_holds_resolve_unmeasured_without_promoting_contiguous_gates(program):
    con,doc,out,ledger=program;before=snapshot(con);decl=ledger.read_bytes()
    gates_before=rebaseline.compute(con,None)['summary']
    first=r.apply_program(con,doc,'a'*64,out,backend,{})
    assert first['inserted']==5 and snapshot(con)==before and ledger.read_bytes()==decl
    second=r.apply_program(con,doc,'a'*64,out,backend,{})
    assert second['inserted']==0 and second['already_held']==5
    assert con.execute('SELECT COUNT(*) FROM events').fetchone()[0]==1
    reader=selector._default_metric_reader(con)
    assert all(reader(t['id'])[0]=='SKIPPED_EXCLUDED' for t in doc['targets'])
    specs=[{'work_item_id':t['id'],'cell_key':t['cell_key']} for t in doc['targets']]
    counts=selector._all_measured(reader,{},specs)
    assert counts['skipped']==5 and counts['ok']==0 and counts['pending']==0
    rows=[dict(v) for v in con.execute("SELECT * FROM work_items WHERE phase='OPT_CENSUS'")]
    heads=scheduling.arm_frontier(rows,json.loads(ledger.read_text()),conn=con)
    assert (doc['program_id'],'buy_003') not in heads
    gates_after=rebaseline.compute(con,None)['summary']
    assert gates_after.pop('opt_census_prescreen')['valid_held_cells']==5
    gates_before.pop('opt_census_prescreen')
    assert gates_after==gates_before and snapshot(con)==before


def test_races_and_existing_inactive_holds_preserve_every_row(program):
    con,doc,out,ledger=program;ids=[t['id'] for t in doc['targets']]
    con.execute("UPDATE work_items SET status='active',claimed_by='T2' WHERE id=?",(ids[0],))
    con.execute("UPDATE work_items SET status='done',verdict='MEASURED' WHERE id=?",(ids[1],))
    con.execute("INSERT INTO work_item_holds VALUES(?,'OTHER','preserve',0,0,'old','old',NULL,NULL)",(ids[2],))
    con.commit();before=snapshot(con)
    result=r.apply_program(con,doc,'b'*64,out,backend,{})
    assert result['inserted']==2 and len(result['raced'])==3 and snapshot(con)==before
    assert tuple(con.execute('SELECT hold_code,active,reason FROM work_item_holds WHERE work_item_id=?',(ids[2],)).fetchone())==('OTHER',0,'preserve')


def test_missing_program_receipt_row_cannot_resolve_a_hold(program):
    con,doc,out,ledger=program;r.apply_program(con,doc,'c'*64,out,backend,{})
    con.execute('DELETE FROM events');con.commit()
    with pytest.raises(ValueError,match='receipt row missing'):
        selector._default_metric_reader(con)(doc['targets'][0]['id'])


def test_changed_native_proof_aborts_without_holds_or_work_item_changes(program):
    con,doc,out,ledger=program;before=snapshot(con)
    Path(doc['arm_decisions']['buy_003']['proof'][0]['report_path']).write_text('tampered')
    with pytest.raises(ValueError,match='native report hash mismatch'):
        r.apply_program(con,doc,'d'*64,out,backend,{})
    assert con.execute('SELECT COUNT(*) FROM work_item_holds').fetchone()[0]==0
    assert con.execute('SELECT COUNT(*) FROM events').fetchone()[0]==0
    assert snapshot(con)==before and list(out.iterdir())==[]
