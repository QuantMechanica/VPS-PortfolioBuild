from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import revive_r11_compile_ea as revival


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
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
        CREATE TABLE work_item_holds (
            work_item_id TEXT PRIMARY KEY,
            hold_code TEXT NOT NULL,
            reason TEXT NOT NULL,
            active INTEGER NOT NULL,
            release_on_restart INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            released_at TEXT,
            release_note TEXT
        );
        CREATE TABLE work_item_transition_ledger (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            idempotency_key TEXT NOT NULL UNIQUE,
            ts TEXT NOT NULL,
            work_item_id TEXT NOT NULL,
            action TEXT NOT NULL,
            from_status TEXT,
            to_status TEXT,
            from_verdict TEXT,
            to_verdict TEXT,
            from_claimed_by TEXT,
            to_claimed_by TEXT,
            reason TEXT NOT NULL,
            run_id TEXT,
            detail_json TEXT NOT NULL
        );
        CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            event TEXT NOT NULL,
            detail_json TEXT NOT NULL
        );
        """
    )


def _source(repo: Path, label: str, data: bytes) -> Path:
    path = repo / "framework" / "EAs" / label / f"{label}.mq5"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def _payload(path: Path, source_sha: str, *, incident: bool = True) -> dict:
    label = path.stem
    payload = {
        "compile_contract_version": revival.COMPILE_CONTRACT_VERSION,
        "compile_activation_state": "AWAITING_REVIEWED_WORKER_ROLLOUT",
        "compile_activation_hold_code": revival.ACTIVATION_HOLD_CODE,
        "ea_label": label,
        "ea_dir": str(path.parent),
        "mq5_path": str(path),
        "mq5_sha256": source_sha,
        "symbols": ["EURUSD.DWX"],
        "timeframe": {"timeframe": "H1", "source": "test"},
        "risk_contract": {"RISK_FIXED": 1000.0, "RISK_PERCENT": 0.0},
        "utility_phase": True,
        "no_gate_verdict": True,
    }
    if incident:
        payload.update({
            "repair_handler": revival.INCIDENT_HANDLER,
            "verdict_reason": revival.INCIDENT_REASON,
            "preflight_failure": {"reason": revival.INCIDENT_REASON},
        })
    return payload


def _insert(
    conn: sqlite3.Connection,
    *,
    item_id: str,
    ea_id: str,
    payload: dict,
    phase: str = "COMPILE_EA",
    status: str = "failed",
    verdict: str | None = "INVALID",
) -> None:
    now = "2026-08-22T04:28:44Z"
    conn.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
            attempt_count,parent_task_id,evidence_path,claimed_by,
            payload_json,created_at,updated_at
        ) VALUES (?,'compile',?,?,?,'',?,?,0,NULL,'old.json',NULL,?,?,?)
        """,
        (item_id, phase, ea_id, "", status, verdict, json.dumps(payload), now, now),
    )
    conn.execute(
        """
        INSERT INTO work_item_holds(
            work_item_id,hold_code,reason,active,release_on_restart,
            created_at,updated_at,released_at,release_note
        ) VALUES (?,?,?,1,1,?,?,NULL,NULL)
        """,
        (item_id, revival.ACTIVATION_HOLD_CODE, "original", now, now),
    )


def _fixture(tmp_path: Path) -> tuple[Path, Path, dict[str, Path]]:
    repo = tmp_path / "repo"
    db = tmp_path / "farm_state.sqlite"
    paths = {
        "one": _source(repo, "QM5_1001_fresh-one-h1", b"fresh-one\n"),
        "two": _source(repo, "QM5_1002_fresh-two-h1", b"fresh-two\n"),
        "12946": _source(repo, "QM5_12946_mql5-macd-obv-div-card", b"new-12946\n"),
        "41097": _source(repo, "QM5_41097_balke-gmt3-range-breakout-opt", b"new-41097\n"),
        "lookalike": _source(repo, "QM5_9000_lookalike-h1", b"lookalike\n"),
    }
    with sqlite3.connect(db) as conn:
        _schema(conn)
        _insert(
            conn,
            item_id="old-one",
            ea_id="QM5_1001",
            payload=_payload(paths["one"], _sha(paths["one"].read_bytes())),
        )
        _insert(
            conn,
            item_id="old-two",
            ea_id="QM5_1002",
            payload=_payload(paths["two"], _sha(paths["two"].read_bytes())),
        )
        _insert(
            conn,
            item_id=revival.KNOWN_SHA_STALE_WORK_ITEMS["QM5_12946"],
            ea_id="QM5_12946",
            payload=_payload(paths["12946"], _sha(b"old-12946\n")),
        )
        _insert(
            conn,
            item_id=revival.KNOWN_SHA_STALE_WORK_ITEMS["QM5_41097"],
            ea_id="QM5_41097",
            payload=_payload(paths["41097"], _sha(b"old-41097\n"), incident=False),
            status="pending",
            verdict=None,
        )
        _insert(
            conn,
            item_id="q02-lookalike",
            ea_id="QM5_9000",
            payload=_payload(paths["lookalike"], _sha(paths["lookalike"].read_bytes())),
            phase="Q02",
        )
        _insert(
            conn,
            item_id="wrong-verdict-lookalike",
            ea_id="QM5_9000",
            payload=_payload(paths["lookalike"], _sha(paths["lookalike"].read_bytes())),
            verdict="INFRA_FAIL",
        )
        conn.commit()
    return repo, db, paths


def test_exact_selector_and_sha_classification(tmp_path: Path) -> None:
    repo, db, _paths = _fixture(tmp_path)
    result = revival.inspect(db, repo)

    assert result["mode"] == "dry_run"
    assert result["before_counts"]["incident_selector_count"] == 3
    assert result["eligible_count"] == 2
    assert result["held_count"] == 1
    assert result["already_revived_count"] == 0
    assert result["held"][0]["ea_id"] == "QM5_12946"
    assert result["held"][0]["hold_reasons"] == ["MQ5_SHA_STALE"]
    stale = {row["ea_id"]: row for row in result["known_sha_stale_audit"]}
    assert stale["QM5_12946"]["in_incident_selector"] is True
    assert stale["QM5_41097"]["in_incident_selector"] is False
    assert stale["QM5_41097"]["status"] == "pending"
    assert stale["QM5_41097"]["hold"]["active"] == 1

    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 6


def test_apply_appends_held_successors_and_preserves_incident_rows(tmp_path: Path) -> None:
    repo, db, _paths = _fixture(tmp_path)
    backup_dir = tmp_path / "backups"
    result = revival.apply_revival(
        db,
        repo,
        backup_dir,
        tmp_path / "FACTORY_MUTATION.lock",
    )

    assert result["verification_ok"] is True
    assert result["applied_count"] == 2
    assert result["actual_back_into_queue"] == 2
    assert result["before_counts"]["incident_selector_count"] == 3
    assert result["after_counts"]["incident_selector_count"] == 3
    assert result["after_counts"]["pending_successor_count"] == 2
    assert Path(result["backup"]["path"]).is_file()
    assert revival.sha256_file(Path(result["backup"]["path"])) == result["backup"]["sha256"]
    assert result["factory_mutation_lock"]["release_status"] == "released"

    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        old = list(conn.execute(
            "SELECT id,status,verdict,evidence_path FROM work_items WHERE id IN ('old-one','old-two')"
        ))
        assert {(row["status"], row["verdict"], row["evidence_path"]) for row in old} == {
            ("failed", "INVALID", "old.json")
        }
        successors = list(conn.execute(
            "SELECT * FROM work_items WHERE json_extract(payload_json, '$.revival_contract_version')=?",
            (revival.REVIVAL_CONTRACT_VERSION,),
        ))
        assert len(successors) == 2
        for row in successors:
            payload = json.loads(row["payload_json"])
            assert row["status"] == "pending"
            assert row["verdict"] is None
            assert payload["risk_contract"] == {"RISK_FIXED": 1000.0, "RISK_PERCENT": 0.0}
            assert payload["no_gate_verdict"] is True
            assert "repair_handler" not in payload
            assert "verdict_reason" not in payload
            hold = conn.execute(
                "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=?",
                (row["id"],),
            ).fetchone()
            assert tuple(hold) == (revival.ACTIVATION_HOLD_CODE, 1)
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger WHERE action='append_only_revival'"
        ).fetchone()[0] == 2
        assert conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='compile_ea_append_only_revival'"
        ).fetchone()[0] == 2
        assert conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='compile_ea_successor_appended'"
        ).fetchone()[0] == 2


def test_second_apply_is_idempotent(tmp_path: Path) -> None:
    repo, db, _paths = _fixture(tmp_path)
    backup_dir = tmp_path / "backups"
    first = revival.apply_revival(db, repo, backup_dir, tmp_path / "one.lock")
    second = revival.apply_revival(db, repo, backup_dir, tmp_path / "two.lock")

    assert first["applied_count"] == 2
    assert second["applied_count"] == 0
    assert second["idempotent_noop"] is True
    assert second["already_revived_count"] == 2
    assert second["backup"] is None
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE json_extract(payload_json, '$.revival_contract_version')=?",
            (revival.REVIVAL_CONTRACT_VERSION,),
        ).fetchone()[0] == 2
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger WHERE action='append_only_revival'"
        ).fetchone()[0] == 2


def test_source_sha_is_revalidated_inside_apply_boundary(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repo, db, paths = _fixture(tmp_path)
    original_backup = revival._backup_database

    def drift_after_backup(database: Path, backup_dir: Path):
        result = original_backup(database, backup_dir)
        paths["one"].write_bytes(b"changed-after-preflight\n")
        return result

    monkeypatch.setattr(revival, "_backup_database", drift_after_backup)
    with pytest.raises(revival.RevivalError, match="eligible incident ID set drifted"):
        revival.apply_revival(
            db,
            repo,
            tmp_path / "backups",
            tmp_path / "FACTORY_MUTATION.lock",
        )
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE json_extract(payload_json, '$.revival_contract_version')=?",
            (revival.REVIVAL_CONTRACT_VERSION,),
        ).fetchone()[0] == 0


def test_selector_text_is_the_exact_five_clause_contract() -> None:
    sql = " ".join(revival.INCIDENT_SELECTOR_SQL.split())
    assert "phase='COMPILE_EA'" in sql
    assert "status='failed'" in sql
    assert "verdict='INVALID'" in sql
    assert "$.repair_handler" in sql and revival.INCIDENT_HANDLER in sql
    assert "$.verdict_reason" in sql and revival.INCIDENT_REASON in sql
