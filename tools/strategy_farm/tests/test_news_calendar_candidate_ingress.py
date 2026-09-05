import hashlib
import json
from pathlib import Path
import sys
import pytest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import news_calendar_candidate_ingress as ingress
import news_calendar_gate as gate
from test_news_calendar_gate import _test_policy, _write_pair, _snapshot
from test_news_calendar_repin import _fixture, _write_calendar, _publication_proof
import news_calendar_repin as repin


def fixture(tmp_path, *, failed=None):
    source=tmp_path/"candidate";_write_pair(source)
    verification={"schema":ingress.SCHEMA,"decision_id":ingress.DECISION,"publishable":True,"status":"PASS","exit_code":0,
                  "gates":{k:{"pass":k!=failed} for k in ingress.GATES}}
    v=json.dumps(verification).encode();(source/"verification.json").write_bytes(v)
    manifest={"schema":ingress.SCHEMA,"decision_id":ingress.DECISION,"publishable":True,"production_write":False,
              "verification_sha256":hashlib.sha256(v).hexdigest(),"files":[
                  {"name":n,"sha256":hashlib.sha256((source/n).read_bytes()).hexdigest(),"row_count":2} for n in gate.CALENDAR_NAMES]}
    m=json.dumps(manifest).encode();(source/"manifest.json").write_bytes(m)
    return source,hashlib.sha256(m).hexdigest(),_test_policy(tmp_path)


def test_dry_run_is_read_only_and_staging_is_exact_create_only(tmp_path):
    source,sha,policy=fixture(tmp_path)
    before=_snapshot(tmp_path)
    assert ingress.prepare(gate,source,sha,policy=policy)["status"]=="VALIDATED"
    assert _snapshot(tmp_path)==before
    policy.evidence_dir.mkdir()
    target=policy.evidence_dir/("news-calendar-staging-"+"a"*32)
    r=ingress.prepare(gate,source,sha,staging_dir=target,apply=True,policy=policy)
    assert r["applied"] and not policy.source_dir.exists()
    for n in gate.CALENDAR_NAMES:assert (target/n).read_bytes()==(source/n).read_bytes()
    plan=gate.build_multi_principal_publication_plan(target/gate.PRIMARY_NAME,target/gate.SECONDARY_NAME,_policy=policy)
    assert [r["sha256"] for r in plan["candidates"]]==[r["sha256"] for r in r["files"]]
    with pytest.raises(ValueError,match="already exists"):
        ingress.prepare(gate,source,sha,staging_dir=target,apply=True,policy=policy)


@pytest.mark.parametrize("failure",["manifest","verification","file","gate","destination"])
def test_refusal_precedes_any_write(tmp_path,failure):
    source,sha,policy=fixture(tmp_path,failed=ingress.GATES[0] if failure=="gate" else None)
    if failure=="manifest":sha="0"*64
    elif failure=="verification":(source/"verification.json").write_text("{}")
    elif failure=="file":(source/gate.PRIMARY_NAME).write_bytes((source/gate.PRIMARY_NAME).read_bytes()+b"\n")
    target=tmp_path/"arbitrary" if failure=="destination" else policy.evidence_dir/("news-calendar-staging-"+"b"*32)
    before=_snapshot(tmp_path)
    with pytest.raises((ValueError,gate.NewsCalendarError)):
        ingress.prepare(gate,source,sha,staging_dir=target,apply=True,policy=policy)
    assert _snapshot(tmp_path)==before


def test_e1a_authority_preserves_receipt_chain_and_registered_only(tmp_path):
    p=_fixture(tmp_path,["2026-08-20","2026-08-21"])
    _write_calendar(p["calendar"],["2026-08-20","2026-08-21","2026-08-22"])
    p["proof_dir"].mkdir()
    receipt,journal=_publication_proof(p["proof_dir"],calendar=p["calendar"],refresh_script=p["refresh_script"],operation_id="c"*64)
    kwargs=dict(publication_receipt_path=receipt,publication_journal_path=journal,calendar_path=p["calendar"],
        registry_path=p["registry"],receipt_dir=p["receipt_dir"],bundle_root=p["bundle_root"],refresh_script_path=p["refresh_script"],
        lock_path=p["lock"],expected_operation_id="c"*64,reason="fixture")
    before=p["registry"].read_bytes()
    with pytest.raises(repin.RepinError,match="unregistered"):
        repin.record_repin(**kwargs,owner_decision_id="OWNER-MADE-UP")
    assert p["registry"].read_bytes()==before
    result=repin.record_repin(**kwargs,owner_decision_id=ingress.DECISION)
    assert result["chain_verification"]=="PASS"
    r=json.loads(next(p["receipt_dir"].glob("*.json")).read_text())
    assert r["authority"]["decision_id"]==ingress.DECISION


def test_cli_e1a_still_requires_refresh_parent(tmp_path,monkeypatch,capsys):
    monkeypatch.delenv("QM_NEWS_CALENDAR_REFRESH_PARENT_PID",raising=False)
    monkeypatch.delenv("QM_NEWS_CALENDAR_REFRESH_OPERATION_ID",raising=False)
    status=repin.main(["record","--publication-receipt",str(tmp_path/"absent"),"--publication-journal",str(tmp_path/"absent2"),
                      "--operation-id","d"*64,"--reason","fixture","--owner-decision-id",ingress.DECISION])
    assert status==2 and "refresh" in capsys.readouterr().out.lower()
