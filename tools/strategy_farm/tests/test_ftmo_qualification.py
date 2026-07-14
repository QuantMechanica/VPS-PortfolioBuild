import csv
import json
import os
import sqlite3
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

from portfolio import ftmo_qualification  # noqa: E402


def _fixture(tmp_path: Path, *, q08_verdict: str = "PASS", fresh_mae: bool = True):
    repo = tmp_path / "repo"
    common = tmp_path / "common"
    db = tmp_path / "farm.sqlite"
    ea_dir = repo / "framework" / "EAs" / "QM5_9001_demo"
    ea_dir.mkdir(parents=True)
    (ea_dir / "QM5_9001_demo.ex5").write_bytes(b"compiled")
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    registry.parent.mkdir(parents=True)
    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "symbol", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9001", "symbol": "NDX.DWX", "status": "active"})

    durable_stream = tmp_path / "durable" / "QM" / "q08_trades" / "9001_NDX_DWX.jsonl"
    durable_stream.parent.mkdir(parents=True)
    with durable_stream.open("w", encoding="utf-8") as handle:
        for index in range(50):
            row = {"event": "TRADE_CLOSED", "net": 10.0, "time": index + 10}
            if fresh_mae:
                row.update({"entry_time": index + 1, "mae_acct": -5.0})
            handle.write(json.dumps(row) + "\n")

    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            CREATE TABLE work_items (
                id TEXT, phase TEXT, ea_id TEXT, symbol TEXT, status TEXT,
                verdict TEXT, evidence_path TEXT, created_at TEXT, updated_at TEXT
            )
            """
        )
        for phase in ftmo_qualification.STRICT_PHASES:
            evidence = tmp_path / f"{phase}.json"
            payload = {}
            if phase == "Q08":
                payload["portfolio_stream"] = {
                    "persisted": True,
                    "path": str(durable_stream),
                }
            evidence.write_text(json.dumps(payload), encoding="utf-8")
            verdict = q08_verdict if phase == "Q08" else "PASS"
            conn.execute(
                "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?)",
                (
                    f"wi-{phase}", phase, "QM5_9001", "NDX.DWX", "done",
                    verdict, str(evidence), "2026-01-01", "2026-01-01",
                ),
            )
        conn.commit()

    # Deliberately invalid volatile output proves qualification uses the
    # evidence-linked baseline, not the last Q08.5 perturbation workspace.
    stream = common / "QM" / "q08_trades" / "9001_NDX_DWX.jsonl"
    stream.parent.mkdir(parents=True)
    stream.write_text('{"event":"TRADE_CLOSED"}\n', encoding="utf-8")
    return repo, common, db


def test_candidate_is_ready_only_with_complete_strict_evidence(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path)

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    assert artifact["challenge_ready_count"] == 1
    assert artifact["candidates"][0]["state"] == "CHALLENGE_READY"
    assert artifact["candidates"][0]["blockers"] == []


def test_q08_soft_fail_never_becomes_challenge_ready(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path, q08_verdict="FAIL_SOFT")

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    candidate = artifact["candidates"][0]
    assert candidate["challenge_ready"] is False
    assert candidate["state"] == "RESEARCH_LEAD"
    assert "q08_not_pass:FAIL_SOFT" in candidate["blockers"]


def test_missing_intraday_mae_blocks_candidate(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path, fresh_mae=False)

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    candidate = artifact["candidates"][0]
    assert candidate["challenge_ready"] is False
    assert "fresh_intraday_mae_stream_missing" in candidate["blockers"]


def test_evidence_and_stream_older_than_binary_block_candidate(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path)
    ex5 = repo / "framework" / "EAs" / "QM5_9001_demo" / "QM5_9001_demo.ex5"
    rebuilt_at = time.time() + 60
    os.utime(ex5, (rebuilt_at, rebuilt_at))

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    candidate = artifact["candidates"][0]
    assert candidate["challenge_ready"] is False
    assert "q02_evidence_predates_build" in candidate["blockers"]
    assert "q03_evidence_predates_build" in candidate["blockers"]
    assert "q04_evidence_predates_build" in candidate["blockers"]
    assert "q10_evidence_predates_build" in candidate["blockers"]
    assert "intraday_mae_stream_predates_build" in candidate["blockers"]
    assert candidate["phases"]["Q04"]["evidence_predates_build"] is True
    assert candidate["stream"]["predates_build"] is True


def test_unlinked_q08_stream_cannot_qualify_volatile_common_output(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path)
    q08_evidence = tmp_path / "Q08.json"
    q08_evidence.write_text("{}", encoding="utf-8")

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    candidate = artifact["candidates"][0]
    assert candidate["challenge_ready"] is False
    assert "q08_baseline_stream_unlinked:portfolio_stream_missing" in candidate["blockers"]
    assert candidate["stream"]["source"] == "common_volatile_fallback"


def test_parse_keys_accepts_qm5_and_numeric_labels() -> None:
    assert ftmo_qualification.parse_keys("QM5_12969:USDJPY.DWX,13036:NDX.DWX") == [
        ("QM5_12969", "USDJPY.DWX"),
        ("QM5_13036", "NDX.DWX"),
    ]
