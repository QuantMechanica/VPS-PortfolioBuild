import json
import sqlite3

import pytest

from tools.strategy_farm import release_status as rs


def cohort():
    rows = []
    for n in range(1, 9):
        for gate in rs.rc.GATE_CHAIN:
            rows.append(dict(id=f"{n}:{gate}", ea_id=f"QM5_{n}", symbol="EURUSD.DWX", phase=gate,
                             gate_contract_version="v4", status="done",
                             verdict="FAIL_SOFT" if n == 8 and gate == "Q08" else
                             "KEEP_INCUMBENT" if gate == "Q14" else "PASS"))
    rows.append({**rows[12], "id": "duplicate-terminal"})
    return rows


def reference(rows):
    c = sqlite3.connect(":memory:")
    c.row_factory = sqlite3.Row
    c.execute("CREATE TABLE work_items (id,ea_id,symbol,phase,gate_contract_version,status,verdict)")
    for r in rows:
        c.execute("INSERT INTO work_items VALUES (?,?,?,?,?,?,?)", tuple(r[k] for k in
                  ("id", "ea_id", "symbol", "phase", "gate_contract_version", "status", "verdict")))
    result = {k for k, v in rs.rc.build_pairs(c, limit=None).items() if rs.rc.summarise_pair(v)["highest_contiguous_valid_gate"] == "Q14"}
    c.close()
    return result


def test_7_8_9_reconciliation_preserves_owner_rule():
    rows = cohort()
    normal = {k for k, v in rs.project_records(rows).items() if v["missing_link"] is None}
    diagnostic = {k for k, v in rs.project_records(rows, diagnostic_without_soft=True).items() if v["missing_link"] is None}
    assert len(normal) == 8
    assert normal == reference(rows)
    assert len(diagnostic) == 7
    assert sum(rs.gate(r) == "Q14" and rs.passing(r) for r in rows) == 9
    assert normal - diagnostic == {("QM5_8", "EURUSD.DWX")}


@pytest.mark.parametrize("replacement", ["FAIL_SOFT", "INFRA_FAIL", "INVALID", "SUPERSEDED"])
def test_non_q08_soft_and_invalid_do_not_bridge_a_gap(replacement):
    rows = cohort()
    next(r for r in rows if r["id"] == "1:Q06")["verdict"] = replacement
    result = rs.project_records(rows)
    assert result[("QM5_1", "EURUSD.DWX")]["missing_link"] == "Q06"
    assert {k for k, v in result.items() if v["missing_link"] is None} == reference(rows)


def test_informational_news_lane_and_contract_translation():
    rows = cohort()
    news = next(r for r in rows if r["id"] == "1:Q10")
    news["phase"] = "Q10_PORTFOLIO"
    assert rs.project_records(rows)[("QM5_1", "EURUSD.DWX")]["missing_link"] == "Q10"
    news.update(phase="Q09_NEWS", gate_contract_version="v3", verdict="CONFIG_LOCKED")
    assert rs.project_records(rows)[("QM5_1", "EURUSD.DWX")]["missing_link"] is None
    assert len(reference(rows)) == 8


def test_typed_identity_precedence_and_missing_not_inferred():
    r = {"ex5_sha256": "typed", "payload_json": json.dumps({"expected_ex5_sha256": "payload", "expected_setfile_sha256": "set"})}
    assert rs.identity(r) == {"ex5_sha256": "typed", "setfile_sha256": "set", "mq5_sha256": None}


def test_missing_evidence_does_not_become_hash(tmp_path):
    assert rs.sha(tmp_path / "absent") is None
    assert rs.read_json(tmp_path / "absent") == {}


def test_full_projection_keeps_database_bytes_and_missing_bindings(tmp_path):
    db = tmp_path / "fixture.sqlite"
    c = sqlite3.connect(db)
    c.execute("CREATE TABLE work_items (id,ea_id,symbol,phase,gate_contract_version,status,verdict)")
    for r in cohort():
        c.execute("INSERT INTO work_items VALUES (?,?,?,?,?,?,?)", tuple(r[k] for k in
                  ("id", "ea_id", "symbol", "phase", "gate_contract_version", "status", "verdict")))
    c.commit(); c.close()
    before = db.read_bytes()
    result = rs.build_report(db, tmp_path / "absent.json", tmp_path)
    assert db.read_bytes() == before
    assert result["counts"]["reference_qualified_pairs"] == 8
    assert result["counts"]["bundle_bound_pairs"] == 0
    assert result["book_guard"]["allowed"] is False
    assert all(p["economic_result"]["status"] == "UNAVAILABLE_OR_STALE" for p in result["pairs"])
    assert all(p["execution_readiness"] == "NOT_AUTHORIZED_BY_THIS_PROJECTION" for p in result["pairs"])
