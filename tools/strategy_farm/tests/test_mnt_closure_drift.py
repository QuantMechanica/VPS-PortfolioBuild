from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from pathlib import Path

import pytest


TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import mnt_closure_drift as subject  # noqa: E402


WORK_ITEMS_SCHEMA = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    phase TEXT NOT NULL,
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    setfile_path TEXT NOT NULL,
    status TEXT NOT NULL,
    verdict TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    parent_task_id TEXT,
    evidence_path TEXT,
    claimed_by TEXT,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE portfolio_candidates (
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    q11_work_item_id TEXT NOT NULL,
    state TEXT NOT NULL,
    evidence_path TEXT,
    first_seen_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (ea_id, symbol, q11_work_item_id)
);
"""


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def _insert_work_item(connection: sqlite3.Connection, **overrides: object) -> None:
    row = {
        "id": "q07-1",
        "kind": "backtest",
        "phase": "Q07",
        "ea_id": "QM5_1",
        "symbol": "EURUSD.DWX",
        "setfile_path": "",
        "status": "done",
        "verdict": "PASS",
        "attempt_count": 1,
        "parent_task_id": None,
        "evidence_path": None,
        "claimed_by": None,
        "payload_json": "{}",
        "created_at": "2026-01-01T00:00:00+00:00",
        "updated_at": "2026-01-01T01:00:00+00:00",
    }
    row.update(overrides)
    connection.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
            parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
        ) VALUES(
            :id,:kind,:phase,:ea_id,:symbol,:setfile_path,:status,:verdict,:attempt_count,
            :parent_task_id,:evidence_path,:claimed_by,:payload_json,:created_at,:updated_at
        )
        """,
        row,
    )


def _report_html(seed: int) -> str:
    return (
        "<html><body><table>"
        '<tr><td colspan="3">Inputs:</td><td colspan="10"><b>qm_rng_seed='
        f"{seed}</b></td></tr>"
        '<tr><td colspan="3">Company:</td><td colspan="10"><b>QM</b></td></tr>'
        "</table></body></html>"
    )


def _build_seed_summary(
    root: Path,
    *,
    seed: int,
    mq5: Path,
    ex5: Path,
    closure_sha: str,
) -> tuple[Path, str]:
    run_root = root / f"seed_{seed}"
    run_dir = run_root / "raw" / "run_01"
    run_dir.mkdir(parents=True)
    seeded_set = run_root / f"QM5_1_demo_EURUSD.DWX_H1_q06_stress_harsh_seed{seed}.set"
    seeded_set.write_text(f"qm_rng_seed={seed}\nRISK_FIXED=1000\n", encoding="utf-8")
    tester = run_dir / "tester.ini"
    tester.write_text(f"ExpertParameters={seeded_set.name}\n", encoding="utf-8")
    report = run_dir / "report.htm"
    report.write_text(_report_html(seed), encoding="utf-8")
    summary_path = run_root / "summary.json"
    summary = {
        "ea_id": 1,
        "symbol": "EURUSD.DWX",
        "execution_identity": {
            "stable_during_run": True,
            "source_closure_sha256": closure_sha,
            "mq5_source": {"path": str(mq5), "sha256": _sha(mq5)},
            "expert_binary": {
                "stable_during_run": True,
                "source": {"path": str(ex5), "sha256": _sha(ex5)},
                "deployed": {"path": str(ex5), "sha256": _sha(ex5)},
            },
            "setfile": {
                "stable_during_run": True,
                "source": {"path": str(seeded_set), "sha256": _sha(seeded_set)},
                "deployed": {"path": str(seeded_set), "sha256": _sha(seeded_set)},
            },
        },
        "runs": [
            {
                "report_canonical_path": str(report),
                "tester_ini_path": str(tester),
                "report_sha256": _sha(report),
                "tester_ini_sha256": _sha(tester),
            }
        ],
    }
    _write_json(summary_path, summary)
    return summary_path, _sha(summary_path)


@pytest.fixture()
def closed_fixture(tmp_path: Path) -> dict[str, Path]:
    repo = tmp_path / "repo"
    ea_dir = repo / "framework" / "EAs" / "QM5_1_demo"
    sets = ea_dir / "sets"
    sets.mkdir(parents=True)
    registry = repo / "framework" / "registry"
    registry.mkdir(parents=True)
    _write_json(registry / "multiseed_seeds.json", {"seeds": [42, 17]})

    mq5 = ea_dir / "QM5_1_demo.mq5"
    mq5.write_text("#property strict\ninput int qm_rng_seed=42;\n", encoding="utf-8")
    ex5 = ea_dir / "QM5_1_demo.ex5"
    ex5.write_bytes(b"compiled-demo-v1")
    baseline = sets / "QM5_1_demo_EURUSD.DWX_H1_backtest.set"
    baseline.write_text("qm_rng_seed=42\nRISK_FIXED=1000\n", encoding="utf-8")
    closure_sha = subject.source_closure(mq5, repo)["aggregate_sha256"]

    evidence_root = tmp_path / "evidence"
    details = []
    for seed, pf in ((42, 1.20), (17, 1.10)):
        summary_path, summary_sha = _build_seed_summary(
            evidence_root,
            seed=seed,
            mq5=mq5,
            ex5=ex5,
            closure_sha=closure_sha,
        )
        details.append(
            {
                "seed": seed,
                "pf": pf,
                "trades": 50,
                "invalid_reason": None,
                "summary_path": str(summary_path),
                "summary_sha256": summary_sha,
                "report_path": None,
            }
        )
    aggregate = evidence_root / "aggregate.json"
    _write_json(
        aggregate,
        {
            "phase": "Q07",
            "ea_id": 1,
            "symbol": "EURUSD.DWX",
            "runner_symbol": "EURUSD.DWX",
            "verdict": "PASS",
            "seeds": [42, 17],
            "metrics": {
                "variance_pct": 8.7,
                "spread": 0.1,
                "min_pf": 1.1,
                "max_pf": 1.2,
            },
            "per_seed_detail": details,
        },
    )

    q10_evidence = evidence_root / "q10.json"
    _write_json(q10_evidence, {"phase": "Q10", "verdict": "PASS"})
    db = tmp_path / "farm.sqlite"
    connection = sqlite3.connect(db)
    connection.executescript(WORK_ITEMS_SCHEMA)
    q07_payload = {
        "ea_dir_name": ea_dir.name,
        "expected_mq5_sha256": _sha(mq5),
        "expected_ex5_sha256": _sha(ex5),
        "expected_setfile_sha256": _sha(baseline),
        "evidence_sha256": _sha(aggregate),
        "source_closure_sha256": closure_sha,
    }
    _insert_work_item(
        connection,
        setfile_path=str(baseline),
        evidence_path=str(aggregate),
        payload_json=json.dumps(q07_payload, sort_keys=True),
    )
    q10_payload = {
        "ea_dir_name": ea_dir.name,
        "promoted_from_work_item": "q07-1",
        "expected_mq5_sha256": _sha(mq5),
        "expected_ex5_sha256": _sha(ex5),
        "expected_setfile_sha256": _sha(baseline),
        "evidence_sha256": _sha(q10_evidence),
        "source_closure_sha256": closure_sha,
    }
    _insert_work_item(
        connection,
        id="q10-1",
        phase="Q10",
        setfile_path=str(baseline),
        evidence_path=str(q10_evidence),
        payload_json=json.dumps(q10_payload, sort_keys=True),
    )
    connection.execute(
        "INSERT INTO portfolio_candidates VALUES(?,?,?,?,?,?,?)",
        (
            "QM5_1",
            "EURUSD.DWX",
            "q10-1",
            "Q12_REVIEW_READY",
            str(q10_evidence),
            "2026-01-01T00:00:00+00:00",
            "2026-01-01T00:00:00+00:00",
        ),
    )
    connection.commit()
    connection.close()

    live_manifest = tmp_path / "live.json"
    _write_json(
        live_manifest,
        {
            "status": "LIVE",
            "n_sleeves": 1,
            "sleeves": [
                {
                    "ea_id": 1,
                    "symbol": "EURUSD.DWX",
                    "mq5_path": str(mq5),
                    "mq5_sha256": _sha(mq5),
                    "ex5_path": str(ex5),
                    "ex5_sha256": _sha(ex5),
                    "setfile": str(baseline),
                    "setfile_sha256": _sha(baseline),
                }
            ],
        },
    )
    return {
        "repo": repo,
        "db": db,
        "mq5": mq5,
        "ex5": ex5,
        "aggregate": aggregate,
        "live": live_manifest,
    }


def _scan(paths: dict[str, Path], observed: str = "2026-07-29T08:00:00+00:00") -> dict:
    return subject.scan(
        db_path=paths["db"],
        repo_root=paths["repo"],
        live_manifests=[paths["live"]],
        include_default_live=False,
        phases=["Q07"],
        observed_at_utc=observed,
    )


def test_closed_q07_is_authenticated_and_scan_is_read_only_and_deterministic(
    closed_fixture: dict[str, Path],
) -> None:
    db_before = closed_fixture["db"].read_bytes()
    first = _scan(closed_fixture)
    second = _scan(closed_fixture, "2026-07-29T09:00:00+00:00")

    assert closed_fixture["db"].read_bytes() == db_before
    assert first["scan_fingerprint_sha256"] == second["scan_fingerprint_sha256"]
    assert first["observed_at_utc"] != second["observed_at_utc"]
    assert first["summary"]["effective_statuses"] == {"PASS": 1}
    adjudication = first["adjudications"][0]
    assert adjudication["reason_classes"] == []
    assert adjudication["bindings"]["input"]["status"] == "AUTHENTICATED"
    assert adjudication["priority"] == "P0_LIVE"
    assert adjudication["live_action"] == "HOLD_OWNER_REVIEW"
    assert first["subjects"][0]["status"] == "CLOSED"
    assert first["cohort_coverage"][0]["phases"][0]["status"] == "BOUND_PASS"


def test_binary_change_marks_evidence_vintage_stale_without_db_update(
    closed_fixture: dict[str, Path],
) -> None:
    db_before = closed_fixture["db"].read_bytes()
    closed_fixture["ex5"].write_bytes(b"compiled-demo-v2")

    report = _scan(closed_fixture)

    assert closed_fixture["db"].read_bytes() == db_before
    adjudication = report["adjudications"][0]
    assert adjudication["effective_admission_status"] == "EVIDENCE_VINTAGE_STALE"
    assert "BINARY_VINTAGE_MISMATCH" in adjudication["reason_classes"]
    assert adjudication["original_verdict"] == "PASS"
    assert report["subjects"][0]["status"] == "DRIFT"


def test_missing_parse_error_backfill_can_never_mint_effective_pass(
    closed_fixture: dict[str, Path],
) -> None:
    connection = sqlite3.connect(closed_fixture["db"])
    connection.execute(
        "UPDATE work_items SET evidence_path=?, attempt_count=0, payload_json=? WHERE id='q07-1'",
        (
            str(closed_fixture["aggregate"].parent / "missing"),
            json.dumps({"backfill": "parse_error_recovery", "verdict_reason": "parse_error"}),
        ),
    )
    connection.commit()
    connection.close()

    report = _scan(closed_fixture)

    adjudication = report["adjudications"][0]
    assert adjudication["effective_admission_status"] == "PROVENANCE_UNVERIFIED"
    assert {"MISSING_FILE", "PARSE_ERROR_BACKFILL"} <= set(
        adjudication["reason_classes"]
    )
    assert adjudication["original_status"] == "done"
    assert adjudication["original_verdict"] == "PASS"


def test_append_overlay_is_hash_chained_idempotent_and_never_rewrites_prefix(
    closed_fixture: dict[str, Path], tmp_path: Path
) -> None:
    report = _scan(closed_fixture)
    event = subject.overlay_event_from_adjudication(
        report["adjudications"][0],
        reviewer="codex-test",
        observed_at_utc=report["observed_at_utc"],
    )
    overlay = tmp_path / "overlay.jsonl"

    first = subject.append_overlay(overlay, [event])
    prefix = overlay.read_bytes()
    duplicate = subject.append_overlay(overlay, [event])
    changed = dict(event)
    changed["reason_classes"] = ["MANUAL_REVIEW"]
    changed["effective_admission_status"] = "PROVENANCE_UNVERIFIED"
    changed["event_id"] = subject.canonical_sha256(
        {key: value for key, value in changed.items() if key != "event_id"}
    )
    second = subject.append_overlay(overlay, [changed])

    assert first["appended"] == 1
    assert duplicate["appended"] == 0
    assert second["appended"] == 1
    assert overlay.read_bytes().startswith(prefix)
    events, tail = subject.validate_overlay_chain(overlay)
    assert len(events) == 2
    assert tail == events[-1]["event_sha256"]
    assert subject.effective_overlay(overlay)["q07-1"]["effective_admission_status"] == (
        "PROVENANCE_UNVERIFIED"
    )


def test_overlay_tamper_is_refused(closed_fixture: dict[str, Path], tmp_path: Path) -> None:
    report = _scan(closed_fixture)
    event = subject.overlay_event_from_adjudication(
        report["adjudications"][0],
        reviewer="codex-test",
        observed_at_utc=report["observed_at_utc"],
    )
    overlay = tmp_path / "overlay.jsonl"
    subject.append_overlay(overlay, [event])
    overlay.write_text(
        overlay.read_text(encoding="utf-8").replace('"priority":"P0_LIVE"', '"priority":"P1_HISTORY"'),
        encoding="utf-8",
    )

    with pytest.raises(subject.ScanError, match="hash mismatch"):
        subject.append_overlay(overlay, [event])


def test_report_write_is_create_only(closed_fixture: dict[str, Path], tmp_path: Path) -> None:
    report = _scan(closed_fixture)
    destination = tmp_path / "report.json"
    subject.write_report_create_only(destination, report)
    original = destination.read_bytes()

    with pytest.raises(FileExistsError):
        subject.write_report_create_only(destination, report)
    assert destination.read_bytes() == original


def test_schemas_are_versioned_json_objects() -> None:
    schema_dir = TOOLS / "schemas"
    report = json.loads(
        (schema_dir / "mnt_closure_drift_report_v1.schema.json").read_text(encoding="utf-8")
    )
    overlay = json.loads(
        (schema_dir / "mnt_adjudication_overlay_event_v1.schema.json").read_text(
            encoding="utf-8"
        )
    )
    assert report["$id"] == subject.REPORT_SCHEMA
    assert overlay["$id"] == subject.OVERLAY_SCHEMA


def test_database_connection_is_enforced_query_only(
    closed_fixture: dict[str, Path],
) -> None:
    connection = subject.open_db_read_only(closed_fixture["db"])
    try:
        assert connection.execute("PRAGMA query_only").fetchone()[0] == 1
        with pytest.raises(sqlite3.OperationalError, match="readonly|read-only"):
            connection.execute("DELETE FROM work_items")
    finally:
        connection.rollback()
        connection.close()
