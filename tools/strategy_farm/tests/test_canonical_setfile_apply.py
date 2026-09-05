from copy import deepcopy
import json
from pathlib import Path
import sqlite3

import pytest
from tools.strategy_farm import canonical_setfile_apply as repair
from tools.strategy_farm import canonical_setfile_paths as paths


def gates(*args):
    return {'failures':[]}


@pytest.fixture
def case(tmp_path):
    root=tmp_path/'farm';repo=tmp_path/'repo'
    repair.farmctl.init_db(root)
    db=root/'state/farm_state.sqlite'
    canonical=repo/'framework/EAs/QM5_9900_example/sets/EURUSD.set'
    old=tmp_path/'worktree/framework/EAs/QM5_9900_example/sets/EURUSD.set'
    for p in (canonical,old):
        p.parent.mkdir(parents=True);p.write_text('RISK_FIXED=1000\nRISK_PERCENT=0\nqm_magic_slot_offset=0\n')
    ex5=canonical.parent.parent/'QM5_9900_example.ex5';ex5.write_bytes(b'compiled fixture')
    with sqlite3.connect(db) as c:
        c.execute("INSERT INTO work_items (id,kind,phase,ea_id,symbol,setfile_path,status,payload_json,created_at,updated_at) VALUES ('old','backtest','Q02','QM5_9900','EURUSD.DWX',?,'pending','{}','fixture','fixture')",(str(old),))
        c.row_factory=sqlite3.Row
        row=dict(c.execute("SELECT * FROM work_items WHERE id='old'").fetchone())
    approved={'old':paths.pending_successor_proposal(row,repo)}
    return dict(database=db,repo_root=repo,authorities=approved,gate_check=gates,
                receipt_path=repo/'docs/ops/evidence/receipt.json'),row,canonical,old


def state(case):
    with sqlite3.connect(case[0]['database']) as c:
        return {t:c.execute('SELECT * FROM '+t).fetchall() for t in ('work_items','work_item_holds','work_item_supersedes','events')}


def test_dry_run_never_writes_or_takes_lock(case,monkeypatch):
    before=state(case)
    monkeypatch.setattr(repair,'FactoryMutationLock',lambda *a,**kw:pytest.fail('dry run took lock'))
    monkeypatch.setattr(repair.farmctl,'_governed_state_backup',lambda *a:pytest.fail('dry run backed up'))
    result=repair.run(['old'],**case[0])
    assert result['eligible'] and not result['applied'] and state(case)==before
    assert not case[0]['receipt_path'].exists()


def test_apply_appends_preserves_row_and_all_holds_and_blocks_old_claim(case,monkeypatch):
    kw,row,_,_=case
    with sqlite3.connect(kw['database']) as c:
        c.execute("INSERT INTO work_item_holds (work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at) VALUES ('old','OWNER_NEWS_HOLD','must remain held',1,0,'old-time','old-time')")
    before=state(case)
    real=repair.FactoryMutationLock;entered=[]
    class Tracking(real):
        def __enter__(self):
            entered.append(True);return super().__enter__()
    monkeypatch.setattr(repair,'FactoryMutationLock',Tracking)
    result=repair.run(['old'],apply=True,**kw)
    assert result['applied'] and len(entered)==1
    assert json.loads(kw['receipt_path'].read_text())['applied']
    assert Path(result['backup']['path']).is_file()
    with sqlite3.connect(kw['database']) as c:
        c.row_factory=sqlite3.Row
        assert dict(c.execute("SELECT * FROM work_items WHERE id='old'").fetchone())==row
        successor=kw['authorities']['old']['proposed_successor_id']
        new=dict(c.execute('SELECT * FROM work_items WHERE id=?',(successor,)).fetchone())
        assert new['sh3_enforced']==1 and new['gate_contract_version']=='v4'
        assert json.loads(new['payload_json'])['canonical_path_repair']['supersedes_work_item_id']=='old'
        hold=dict(c.execute('SELECT * FROM work_item_holds WHERE work_item_id=?',(successor,)).fetchone())
        old_hold=dict(c.execute("SELECT * FROM work_item_holds WHERE work_item_id='old'").fetchone())
        assert hold=={**old_hold,'work_item_id':successor}
        assert c.execute("UPDATE work_items SET status='active',claimed_by='T1' WHERE id='old'").rowcount==0
    repeated=repair.run(['old'],**{**kw,'receipt_path':kw['receipt_path'].with_name('second.json')})
    assert not repeated['eligible']


@pytest.mark.parametrize('fault', ['claimed','row_bytes','old_bytes','canonical_bytes','ex5_bytes','missing_file','competing','successor','superseded','gate','not_previewed'])
def test_refusals_never_append(case,fault):
    kw,row,canonical,old=case
    with sqlite3.connect(kw['database']) as c:
        if fault=='claimed':c.execute("UPDATE work_items SET claimed_by='T2' WHERE id='old'")
        if fault=='row_bytes':c.execute("UPDATE work_items SET payload_json='{\"changed\":true}' WHERE id='old'")
        if fault in ('competing','successor'):
            new_id='competitor' if fault=='competing' else kw['authorities']['old']['proposed_successor_id']
            c.execute("INSERT INTO work_items (id,kind,phase,ea_id,symbol,setfile_path,status,payload_json,created_at,updated_at) VALUES (?,'backtest','Q02','QM5_9900','EURUSD.DWX',?,'pending','{}','fixture','fixture')",(new_id,str(canonical)))
        if fault=='superseded':c.execute("INSERT INTO work_item_supersedes(work_item_id,reason,source_encoding,recorded_by,recorded_at) VALUES ('old','prior','test','owner','now')")
    if fault=='old_bytes':old.write_text('changed')
    if fault=='canonical_bytes':canonical.write_text('changed')
    if fault=='ex5_bytes':(canonical.parent.parent/'QM5_9900_example.ex5').write_bytes(b'changed')
    if fault=='missing_file':canonical.unlink()
    if fault=='gate':kw['gate_check']=lambda *a:{'failures':['BUILD_GUARDRAILS_FAILED']}
    if fault=='not_previewed':kw['authorities']={}
    before=state(case)
    result=repair.run(['old'],apply=True,**kw)
    assert not result['applied'] and not result['eligible']
    assert state(case)==before and not kw['receipt_path'].exists()


@pytest.mark.parametrize('off_check', [1,2,3])
def test_fresh_off_checks_roll_back(case,monkeypatch,off_check):
    calls=[]
    def off(root):
        calls.append(root);return len(calls)>=off_check
    monkeypatch.setattr(repair.farmctl,'factory_is_off',off)
    before=state(case)
    with pytest.raises(repair.RepairRefused,match='FACTORY_OFF'):
        repair.run(['old'],apply=True,**case[0])
    assert state(case)==before


def test_backup_failure_and_transaction_failure_are_atomic(case,monkeypatch):
    before=state(case)
    def fail(*a):raise OSError('backup failed')
    with monkeypatch.context() as m:
        m.setattr(repair.farmctl,'_governed_state_backup',fail)
        with pytest.raises(OSError):repair.run(['old'],apply=True,**case[0])
    assert state(case)==before
    with sqlite3.connect(case[0]['database']) as c:
        c.execute("CREATE TRIGGER test_reject_edge BEFORE INSERT ON work_item_supersedes BEGIN SELECT RAISE(ABORT,'fixture failure'); END")
    with pytest.raises(sqlite3.IntegrityError):repair.run(['old'],apply=True,**case[0])
    assert state(case)==before


def test_missing_supersession_guard_and_bad_receipt_path_refused(case):
    kw=case[0]
    with pytest.raises(repair.RepairRefused,match='RECEIPT_NOT_CANONICAL'):
        repair.run(['old'],apply=True,**{**kw,'receipt_path':kw['repo_root']/'outside.json'})
    with sqlite3.connect(kw['database']) as c:c.execute('DROP TRIGGER trg_work_items_superseded_no_activate')
    with pytest.raises(repair.RepairRefused,match='SUPERSESSION_CLAIM_GUARD_MISSING'):
        repair.run(['old'],apply=True,**kw)


def test_all_targets_refused_atomically_if_one_changed(case):
    before=state(case)
    result=repair.run(['old','unapproved'],apply=True,**case[0])
    assert not result['applied'] and state(case)==before


def test_authority_manifest_hashes_and_canonical_cli_guard(tmp_path,monkeypatch):
    # Current canonical evidence is read-only and already hash pinned.
    assert len(repair.load_authorities())==9
    monkeypatch.setattr(paths,'CANONICAL_REPO',tmp_path/'canonical')
    with pytest.raises(SystemExit):paths.main(['apply','--all-previewed','--apply'])


def test_artifact_changed_during_gates_rolls_back(case):
    before=state(case)
    def changing_gate(*args):
        case[2].write_text('changed after initial byte binding')
        return {'failures':[]}
    with pytest.raises(repair.RepairRefused,match='ARTIFACT_CHANGED_BEFORE_COMMIT'):
        repair.run(['old'],apply=True,**{**case[0],'gate_check':changing_gate})
    assert state(case)==before
