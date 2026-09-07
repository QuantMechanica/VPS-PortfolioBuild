from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

from tools.strategy_farm import farmctl


EA_ID = "QM5_9901"
EA_SLUG = "rebind-fixture"
COMPILE_ID = "compile-current"
SOURCE_ID = "source-stale"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_registry(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9901", "slug": EA_SLUG, "status": "active"})


def _fixture(tmp_path: Path, *, terminal: bool = False) -> dict[str, object]:
    root = tmp_path / "farm"
    repo = tmp_path / "repo"
    farmctl.init_db(root)
    ea_dir = repo / "framework" / "EAs" / f"{EA_ID}_{EA_SLUG}"
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir(parents=True)
    mq5_path = ea_dir / f"{ea_dir.name}.mq5"
    ex5_path = ea_dir / f"{ea_dir.name}.ex5"
    setfile_path = sets_dir / f"{ea_dir.name}_EURUSD.DWX_H1_backtest.set"
    mq5_path.write_bytes(b"current source\n")
    ex5_path.write_bytes(b"current binary\n")
    setfile_path.write_bytes(
        b"RISK_FIXED=1000\nRISK_PERCENT=0\nstrategy_period=20\n"
    )
    _write_registry(repo / "framework" / "registry" / "ea_id_registry.csv")
    mq5_sha = _sha(mq5_path)
    ex5_sha = _sha(ex5_path)
    setfile_sha = _sha(setfile_path)
    old_ex5_sha = hashlib.sha256(b"old binary\n").hexdigest()

    evidence_path = tmp_path / "compile_evidence.json"
    evidence_path.write_text(
        json.dumps({
            "schema_version": "qm.compile-ea-evidence/v1",
            "work_item_id": COMPILE_ID,
            "ea_id": EA_ID,
            "phase": "COMPILE_EA",
            "success": True,
            "compile_result": "PASS",
            "build_check_result": "PASS",
            "ex5_sha256": ex5_sha,
            "candidate_recheck": {
                "eligible": True,
                "mq5_sha256": mq5_sha,
                "symbols": ["EURUSD.DWX"],
            },
        }),
        encoding="utf-8",
    )
    now = "2026-09-07T00:00:00+00:00"
    compile_payload = {
        "mq5_sha256": mq5_sha,
        "compile_result": {
            "success": True,
            "compile_result": "PASS",
            "build_check_result": "PASS",
            "ex5_sha256": ex5_sha,
        },
    }
    source_payload = {
        "expected_current_ex5_sha256": old_ex5_sha,
        "expected_ex5_sha256": old_ex5_sha,
        "expected_mq5_sha256": mq5_sha,
        "expected_setfile_sha256": setfile_sha,
        "expected_symbol": "EURUSD.DWX",
        "expected_period": "H1",
        "host_symbol": "EURUSD.DWX",
        "host_timeframe": "H1",
        "from_date": "2018.01.01",
        "to_date": "2025.12.31",
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
        "artifact_identity": {
            "ex5_sha256": old_ex5_sha,
            "mq5_sha256": mq5_sha,
            "setfile_sha256": setfile_sha,
        },
    }
    status = "failed" if terminal else "pending"
    verdict = "INFRA_FAIL" if terminal else None
    taxonomy = "infrastructure" if terminal else "open"
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items
              (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
               attempt_count,evidence_path,payload_json,created_at,updated_at,
               gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256,
               verdict_taxonomy,sh3_enforced)
            VALUES (?,'compile','COMPILE_EA',?,'','', 'done','COMPILE_OK',1,?,?,?,?,'v5',?,?,?,'artifact',1)
            """,
            (
                COMPILE_ID, EA_ID, str(evidence_path),
                json.dumps(compile_payload), now, now, ex5_sha, setfile_sha, mq5_sha,
            ),
        )
        conn.execute(
            """
            INSERT INTO work_items
              (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
               attempt_count,evidence_path,payload_json,created_at,updated_at,
               gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256,
               data_window_start,data_window_end,verdict_taxonomy,sh3_enforced)
            VALUES (?,'backtest','Q02',?,?,?, ?,?,0,?,?,?,?,'v5',?,?,?,
                    '2018.01.01','2025.12.31',?,1)
            """,
            (
                SOURCE_ID, EA_ID, "EURUSD.DWX", str(setfile_path), status, verdict,
                "EVIDENCE_UNAVAILABLE" if terminal else None,
                json.dumps(source_payload), now, now, old_ex5_sha,
                setfile_sha, mq5_sha, taxonomy,
            ),
        )
        conn.commit()
    return {
        "root": root,
        "repo": repo,
        "ex5_sha": ex5_sha,
        "setfile": setfile_path,
    }


def _call(fixture: dict[str, object], *, apply: bool = False) -> dict[str, object]:
    return farmctl.rebind_q02_stale_ex5(
        fixture["root"],  # type: ignore[arg-type]
        SOURCE_ID,
        expected_current_ex5_sha256=str(fixture["ex5_sha"]),
        reason="fixture EX5-only rebuild",
        apply=apply,
        repo_root=fixture["repo"],  # type: ignore[arg-type]
    )


def test_pending_predecessor_dry_run_then_apply_is_append_only(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    dry_run = _call(fixture)
    assert dry_run["ok"] is True
    assert dry_run["eligible"] is True
    assert dry_run["would_enqueue"] is True
    with farmctl.connect(fixture["root"]) as conn:  # type: ignore[arg-type]
        assert conn.execute("SELECT COUNT(*) FROM work_item_supersedes").fetchone()[0] == 0

    result = _call(fixture, apply=True)
    assert result["applied"] is True
    successor_id = str(result["successor_work_item_id"])
    receipt_path = Path(str(result["receipt_path"]))
    assert receipt_path.is_file()
    with farmctl.connect(fixture["root"]) as conn:  # type: ignore[arg-type]
        predecessor = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id=?", (SOURCE_ID,)
        ).fetchone()
        successor = conn.execute(
            "SELECT status,verdict,ex5_sha256,payload_json FROM work_items WHERE id=?",
            (successor_id,),
        ).fetchone()
        supersession = conn.execute(
            "SELECT superseded_by_work_item_id,evidence_path FROM work_item_supersedes "
            "WHERE work_item_id=?",
            (SOURCE_ID,),
        ).fetchone()
        claimable = {
            row["id"] for row in conn.execute(farmctl.pending_claim_order_sql())
        }
    assert tuple(predecessor) == ("pending", None)
    assert successor["status"] == "pending"
    assert successor["verdict"] is None
    assert successor["ex5_sha256"] == fixture["ex5_sha"]
    assert json.loads(successor["payload_json"])["q02_stale_binding_rebind_of"] == SOURCE_ID
    assert supersession["superseded_by_work_item_id"] == successor_id
    assert Path(supersession["evidence_path"]) == receipt_path
    assert SOURCE_ID not in claimable
    assert successor_id in claimable


def test_terminal_infra_predecessor_is_preserved(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path, terminal=True)
    result = _call(fixture, apply=True)
    assert result["applied"] is True
    with farmctl.connect(fixture["root"]) as conn:  # type: ignore[arg-type]
        predecessor = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id=?", (SOURCE_ID,)
        ).fetchone()
        superseded = conn.execute(
            "SELECT superseded_by_work_item_id FROM work_item_supersedes "
            "WHERE work_item_id=?",
            (SOURCE_ID,),
        ).fetchone()
    assert tuple(predecessor) == ("failed", "INFRA_FAIL")
    assert superseded[0] == result["successor_work_item_id"]


def test_mismatching_operator_ex5_sha_is_refused(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    result = farmctl.rebind_q02_stale_ex5(
        fixture["root"],  # type: ignore[arg-type]
        SOURCE_ID,
        expected_current_ex5_sha256="0" * 64,
        reason="wrong hash",
        repo_root=fixture["repo"],  # type: ignore[arg-type]
    )
    assert result["ok"] is False
    assert result["reason"] == "canonical_ex5_sha256_mismatch"


def test_changed_setfile_is_refused_before_binary_rebind(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    Path(fixture["setfile"]).write_bytes(b"strategy_period=99\n")
    result = _call(fixture)
    assert result["ok"] is False
    assert result["reason"] == "source_setfile_changed"
