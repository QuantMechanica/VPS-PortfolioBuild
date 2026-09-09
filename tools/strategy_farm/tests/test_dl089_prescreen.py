from __future__ import annotations
import json
import sqlite3
from pathlib import Path

import pytest
from tools.strategy_farm import dl089_prescreen as p, opt_census as census, opt_census_select as selector, dl089_scheduling as scheduling
from tools.strategy_farm.tests.test_opt_census import _plan, _db


def setup(tmp_path, monkeypatch):
    # Historical v1 replay, never a production opt-in.
    monkeypatch.setattr(p, "RETIRED", False)
    monkeypatch.setenv("QM_DL089_PRESCREEN","1")
    plan = _plan(tmp_path); db = _db(tmp_path/"db.sqlite"); ledger = tmp_path/"ledger.json"
    bars = tmp_path/"USDJPY.DWX_D1.csv"; bars.write_text("fixture bars\n")
    auth = tmp_path/"authority.md";auth.write_text("| 13 | "+p.DECISION+" | released |")
    plan["prescreen_contract"] = p.create_contract(plan["symbol"],bars_root=tmp_path,manifest_root=tmp_path/"manifests",authority=auth)
    original = p.plan_admission
    counts = lambda year,baseline:{c["arm"]:(5 if c["arm"]=="buy_003" else 0) for c in plan["cells"] if c["arm"]!="baseline"}
    monkeypatch.setattr(p,"plan_admission",lambda *args,**kwargs:original(*args,counts_reader=counts,**kwargs))
    return plan,db,ledger


def measure(db,plan,year,arm,net,tmp_path):
    cell=next(c for c in plan["cells"] if c["year"]==year and c["arm"]==arm)
    report=tmp_path/(str(year)+arm+".htm");report.write_text("native fixture")
    summary=report.with_suffix(".json");summary.write_text(json.dumps({"runs":[{"status":"OK","report_canonical_path":str(report),"report_sha256":p.sha(report),"net_profit":net}]}))
    with sqlite3.connect(db) as c:c.execute("UPDATE work_items SET status='done',verdict='MEASURED',evidence_path=? WHERE id=?",(str(summary),cell["work_item_id"]))


def test_staged_enqueue_receipts_and_154_trial_reconciliation(tmp_path,monkeypatch):
    plan,db,ledger=setup(tmp_path,monkeypatch)
    assert census.enqueue(plan,db_path=db,ledger_path=ledger)["inserted"]==2
    for year in p.YEARS:measure(db,plan,year,"baseline",100,tmp_path)
    result=census.enqueue(plan,db_path=db,ledger_path=ledger)
    assert result["inserted"]==308 and result["skipped"]==306
    with sqlite3.connect(db) as c:
        ids=[r[0] for r in c.execute("SELECT id FROM work_items WHERE verdict=?",(p.VERDICT,))]
        read=selector._default_metric_reader(c)
        assert all(read(i)[0]=="SKIPPED_EXCLUDED" for i in ids)
    for year in p.YEARS:measure(db,plan,year,"buy_003",105,tmp_path)
    result=census.enqueue(plan,db_path=db,ledger_path=ledger)
    assert result["inserted"]==770 and result["skipped"]==765 # five baselines, one surviving arm still awaits each
    for year in range(2021,2026):measure(db,plan,year,"baseline",100,tmp_path)
    assert census.enqueue(plan,db_path=db,ledger_path=ledger)["inserted"]==5
    assert census.enqueue(plan,db_path=db,ledger_path=ledger)["inserted"]==0
    saved=json.loads(ledger.read_text());assert saved["declared_trial_count"]==154 and len(saved["cells"])==1085
    with sqlite3.connect(db) as c:
        assert c.execute("SELECT COUNT(*) FROM work_items WHERE phase='OPT_CENSUS'").fetchone()[0]==1085
        assert c.execute("SELECT COUNT(*) FROM work_items WHERE verdict=?",(p.VERDICT,)).fetchone()[0]==1071


def test_second_screening_year_must_also_beat_positive_baseline():
    assert p.qualifies({"net_profit":"105"},{"net_profit":"100"})
    assert not p.qualifies({"net_profit":"104.99"},{"net_profit":"100"})
    assert not p.qualifies({"net_profit":"0"},{"net_profit":"-100"})
    assert not p.qualifies({"net_profit":"1"},{"net_profit":"0"})
    assert not p.qualifies(None,{"net_profit":"100"})


def test_kill_switch_preserves_receipts_and_existing_running_rows(tmp_path,monkeypatch):
    plan,db,ledger=setup(tmp_path,monkeypatch);census.enqueue(plan,db_path=db,ledger_path=ledger)
    for year in p.YEARS:measure(db,plan,year,"baseline",100,tmp_path)
    census.enqueue(plan,db_path=db,ledger_path=ledger)
    with sqlite3.connect(db) as c:
        c.execute("UPDATE work_items SET status='active',claimed_by='T1' WHERE phase='OPT_CENSUS' AND verdict IS NULL")
        before=c.execute("SELECT * FROM work_items ORDER BY id").fetchall()
    monkeypatch.setenv("QM_DL089_PRESCREEN","0")
    (tmp_path/"USDJPY.DWX_D1.csv").unlink() # rollback does not need the old mutable export
    census.enqueue(plan,db_path=db,ledger_path=ledger)
    with sqlite3.connect(db) as c:
        after={r[0]:r for r in c.execute("SELECT * FROM work_items")}
    assert all(after[r[0]]==r for r in before)
    assert len(after)==1087 # 1085 annual + two prerequisite fixtures


def test_manifest_tamper_fails_before_any_enqueue(tmp_path,monkeypatch):
    plan,db,ledger=setup(tmp_path,monkeypatch)
    (tmp_path/"USDJPY.DWX_D1.csv").write_text("changed")
    with pytest.raises(ValueError,match="D1 export changed"):census.enqueue(plan,db_path=db,ledger_path=ledger)
    with sqlite3.connect(db) as c:assert c.execute("SELECT COUNT(*) FROM work_items WHERE phase='OPT_CENSUS'").fetchone()[0]==0


def test_staged_frontier_allows_only_explicit_admissions(tmp_path,monkeypatch):
    plan,db,ledger=setup(tmp_path,monkeypatch);census.enqueue(plan,db_path=db,ledger_path=ledger)
    with sqlite3.connect(db) as c:
        c.row_factory=sqlite3.Row;rows=[dict(r) for r in c.execute("SELECT * FROM work_items WHERE phase='OPT_CENSUS'")]
    saved=json.loads(ledger.read_text());heads=scheduling.arm_frontier(rows,saved)
    assert len(heads)==1 # baseline 2019 precedes baseline 2020
    saved["prescreen_admitted_cell_keys"].pop()
    with pytest.raises(scheduling.SchedulingError,match="coverage"):scheduling.arm_frontier(rows,saved)


def test_protected_year_keeps_all_legacy_arms(tmp_path,monkeypatch):
    plan,db,ledger=setup(tmp_path,monkeypatch)
    contract=plan["prescreen_contract"];contract["protected_years"]=[2019]
    contract["contract_sha256"]=p.digest({k:v for k,v in contract.items() if k!="contract_sha256"})
    assert census.enqueue(plan,db_path=db,ledger_path=ledger)["inserted"]==156 # 155 legacy + 2020 baseline


def test_stage2_rejects_arm_missing_second_year_uplift(tmp_path,monkeypatch):
    plan,db,ledger=setup(tmp_path,monkeypatch);census.enqueue(plan,db_path=db,ledger_path=ledger)
    for year in p.YEARS:measure(db,plan,year,"baseline",100,tmp_path)
    census.enqueue(plan,db_path=db,ledger_path=ledger)
    measure(db,plan,2019,"buy_003",150,tmp_path);measure(db,plan,2020,"buy_003",104.99,tmp_path)
    result=census.enqueue(plan,db_path=db,ledger_path=ledger)
    assert result["skipped"]==770 # every future arm; baselines still measured


def test_receipt_tamper_cannot_be_counted_as_resolved(tmp_path,monkeypatch):
    plan,db,ledger=setup(tmp_path,monkeypatch);census.enqueue(plan,db_path=db,ledger_path=ledger)
    for year in p.YEARS:measure(db,plan,year,"baseline",100,tmp_path)
    census.enqueue(plan,db_path=db,ledger_path=ledger)
    with sqlite3.connect(db) as c:
        wid,path=c.execute("SELECT id,evidence_path FROM work_items WHERE verdict=? LIMIT 1",(p.VERDICT,)).fetchone()
        Path(path).write_text('{}')
        with pytest.raises(census.CensusError,match="receipt hash"):selector._default_metric_reader(c)(wid)


def test_matrix_binding_allows_partial_only_with_matching_staged_owner(tmp_path,monkeypatch):
    from tools.strategy_farm.tests.test_dl089_matrix_service import _program_binding_fixture, _guard
    monkeypatch.setenv("QM_DL089_PRESCREEN","0")
    root,db,artifacts,template=_program_binding_fixture(tmp_path)
    path=next(artifacts.glob('*/ledger.json'));ledger=json.loads(path.read_text())
    contract={"schema":p.SCHEMA,"decision_id":p.DECISION,"stage1_years":[2019,2020],"threshold":5,
              "declared_trial_count":154,"net_profit_relative_uplift":"0.05","protected_years":[],
              "relative_base_rule":"STRICTLY_POSITIVE_BASELINE_AS_EXISTING_SELECTOR",
              "manifest_path":"fixture","manifest_sha256":"a"*64};contract['contract_sha256']=p.digest(contract)
    ledger['prescreen_contract']=contract
    kept=[c for c in ledger['cells'] if c['arm']=='baseline' and c['year'] in p.YEARS]
    ledger['prescreen_admitted_cell_keys']=[c['cell_key'] for c in kept];path.write_text(json.dumps(ledger))
    with sqlite3.connect(db) as c:
        c.execute("DELETE FROM work_items WHERE phase='OPT_CENSUS' AND id NOT IN (?,?)",tuple(c['work_item_id'] for c in kept))
    assert _guard(root,artifacts)['declared_cell_count']==2
    ledger['q12_work_item_id']='foreign';path.write_text(json.dumps(ledger))
    from tools.strategy_farm.dl089_matrix_service import MatrixServiceError
    with pytest.raises(MatrixServiceError,match="IDENTITY_MISMATCH"):_guard(root,artifacts)
