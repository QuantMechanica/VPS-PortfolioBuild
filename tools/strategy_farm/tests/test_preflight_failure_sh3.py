from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

import pytest

from tools.strategy_farm import farmctl, schema_hardening, terminal_worker


def _migrate_empty_farm_to_sh3(root: Path, tmp_path: Path) -> None:
    farmctl.init_db(root)
    with farmctl.connect(root) as connection:
        schema_hardening.migrate_sh3(
            connection,
            tmp_path / "farm_before_sh3.sqlite",
        )


def _insert_active_row(
    root: Path,
    *,
    item_id: str,
    setfile: Path,
    payload: dict[str, object],
) -> None:
    now = farmctl.utc_now()
    with farmctl.connect(root) as connection:
        connection.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,"
            "attempt_count,payload_json,claimed_by,created_at,updated_at,"
            "gate_contract_version,sh3_enforced) "
            "VALUES (?,?,?,?,?,?,'active',NULL,0,?,'T4',?,?,?,1)",
            (
                item_id,
                "backtest",
                "Q02",
                "QM5_41165",
                "XTIUSD.DWX",
                str(setfile),
                json.dumps(payload, sort_keys=True),
                now,
                now,
                farmctl.ACTIVE_GATE_CONTRACT_VERSION,
            ),
        )
        connection.commit()


def test_stale_ex5_preflight_failure_is_sh3_compliant_and_returns_to_loop(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    repo = tmp_path / "repo"
    reports = tmp_path / "reports" / "work_items"
    ea_dir = repo / "framework" / "EAs" / "QM5_41165_fixture"
    setfile = ea_dir / "sets" / "QM5_41165_fixture_XTIUSD.DWX_M15_backtest.set"
    setfile.parent.mkdir(parents=True)
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    ex5 = ea_dir / "QM5_41165_fixture.ex5"
    ex5.write_bytes(b"current post-intake rebuild")
    actual_sha256 = hashlib.sha256(ex5.read_bytes()).hexdigest()
    stale_sha256 = "0" * 64
    assert actual_sha256 != stale_sha256

    _migrate_empty_farm_to_sh3(root, tmp_path)
    item_id = "de8e719f-4075-41a4-b4e6-8f0f1077dbe2"
    _insert_active_row(
        root,
        item_id=item_id,
        setfile=setfile,
        payload={"expected_ex5_sha256": stale_sha256},
    )
    monkeypatch.setattr(farmctl, "REPO_ROOT", repo)
    monkeypatch.setattr(terminal_worker.farmctl, "REPO_ROOT", repo)
    monkeypatch.setattr(terminal_worker, "WORK_ITEM_REPORTS_ROOT", reports)
    monkeypatch.setattr(
        terminal_worker.farmctl,
        "_news_calendar_preflight",
        lambda *, use_cache: {"ok": True},
    )

    # This is the exact handler called inside the resident loop. Before the fix,
    # its failure writer raised the SH3 IntegrityError instead of returning.
    result = terminal_worker._run_claimed_item(root, {"id": item_id}, "T4", 60)
    assert result["action"] == "staged_ex5_preflight_failed"
    assert result["status"] == "failed"
    assert result["verdict"] == "INFRA_FAIL"

    with farmctl.connect(root) as connection:
        stored = connection.execute(
            "SELECT status,verdict,verdict_taxonomy,payload_json,sh3_enforced "
            "FROM work_items WHERE id=?",
            (item_id,),
        ).fetchone()
    payload = json.loads(stored["payload_json"])
    assert stored["sh3_enforced"] == 1
    assert stored["status"] == "failed"
    assert stored["verdict"] == "INFRA_FAIL"
    assert stored["verdict_taxonomy"] == "infra"
    assert payload["verdict_taxonomy"] == "infra"
    assert payload["preflight_failure"]["reason"] == "staged_ex5_preflight_failed"
    assert "dispatch_ex5_source_sha256_mismatch" in payload["preflight_failure"]["detail"]
    assert "worker_crash_traceback_tail" not in payload
    evidence = json.loads(Path(result["evidence_path"]).read_text(encoding="utf-8"))
    assert evidence["verdict_taxonomy"] == "infra"

    # A legacy string failure is normalized before .get() and the same worker
    # can handle the next claimed row instead of dying/restarting.
    next_id = "fc8770b5-12fc-4ef4-a8e6-90b645fd9b46"
    _insert_active_row(root, item_id=next_id, setfile=setfile, payload={})
    with farmctl.connect(root) as connection:
        next_row = connection.execute(
            "SELECT * FROM work_items WHERE id=?", (next_id,)
        ).fetchone()
    next_result = terminal_worker._fail_work_item_preflight(
        root, next_row, "legacy_string_failure"
    )
    assert next_result["reason"] == "legacy_string_failure"
    with farmctl.connect(root) as connection:
        next_stored = connection.execute(
            "SELECT status,verdict_taxonomy,payload_json FROM work_items WHERE id=?",
            (next_id,),
        ).fetchone()
    next_payload = json.loads(next_stored["payload_json"])
    assert next_stored["status"] == "failed"
    assert next_stored["verdict_taxonomy"] == "infra"
    assert next_payload["preflight_failure"] == {
        "detail": "legacy_string_failure",
        "reason": "legacy_string_failure",
    }


@pytest.mark.parametrize(
    "source_path",
    [
        Path(terminal_worker.__file__),
        Path(farmctl.__file__),
    ],
)
def test_literal_failed_writers_name_the_taxonomy_column(source_path: Path) -> None:
    source = source_path.read_text(encoding="utf-8-sig")
    update_bodies = re.findall(
        r"UPDATE\s+work_items\s+SET(.*?)\bWHERE\b",
        source,
        flags=re.IGNORECASE | re.DOTALL,
    )
    failed_writes = [
        body
        for body in update_bodies
        if re.search(r"status\s*=\s*['\"]failed['\"]", body, re.IGNORECASE)
    ]
    assert failed_writes
    assert [body for body in failed_writes if "verdict_taxonomy" not in body] == []
