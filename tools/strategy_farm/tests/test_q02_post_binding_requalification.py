from __future__ import annotations

import csv
import hashlib
import json
import subprocess
from pathlib import Path

from tools.strategy_farm import farmctl


EA_ID = "QM5_9902"
EA_SLUG = "post-binding-requal-fixture"
SOURCE_ID = "post-binding-source"
COMPILE_ID = "post-binding-compile"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_registry(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9902", "slug": EA_SLUG, "status": "active"})


def _git(repo: Path, *args: str) -> None:
    subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
    )


def _fixture(
    tmp_path: Path,
    *,
    terminal: bool = False,
    parameter_change: bool = False,
    with_authority: bool = False,
    compile_gate_unbound: bool = False,
) -> dict[str, object]:
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
    old_bytes = (
        b"; build_hash:   pending\r\n"
        b"RISK_FIXED=1000\r\n"
        b"RISK_PERCENT=0\r\n"
        b"strategy_period=20\r\n"
    )
    setfile_path.write_bytes(old_bytes)
    old_setfile_sha = _sha(setfile_path)
    _write_registry(repo / "framework" / "registry" / "ea_id_registry.csv")
    _git(repo, "init")
    _git(repo, "config", "user.email", "tests@quantmechanica.invalid")
    _git(repo, "config", "user.name", "QuantMechanica Tests")
    _git(repo, "add", "framework")
    _git(repo, "commit", "-m", "fixture historical preset")

    strategy_period = b"21" if parameter_change else b"20"
    setfile_path.write_bytes(
        b"; build_hash:   current\n"
        b"RISK_FIXED=1000\n"
        b"RISK_PERCENT=0\n"
        b"strategy_period=" + strategy_period + b"\n"
    )
    mq5_sha = _sha(mq5_path)
    ex5_sha = _sha(ex5_path)
    current_setfile_sha = _sha(setfile_path)
    old_ex5_sha = hashlib.sha256(b"old binary\n").hexdigest()

    candidate_recheck: dict[str, object] = {
        "eligible": True,
        "mq5_sha256": mq5_sha,
    }
    if with_authority:
        authority_path = repo / "docs" / "ops" / "evidence" / "authority.json"
        authority_path.parent.mkdir(parents=True)
        authority_path.write_text(
            json.dumps({
                "schema": "qm.compile-ea-source-repair-authority-evidence/v1",
                "registrations": [{
                    "ea_id": "9902",
                    "ea_label": ea_dir.name,
                    "source_sha256": mq5_sha,
                    "repair": "fixture input-pin repair",
                }],
            }),
            encoding="utf-8",
        )
        candidate_recheck.update({
            "source_repair_authorized": True,
            "source_repair_authority": "fixture:input-pin:QM5_9902",
            "source_repair_artifact_bindings": [{
                "path": "docs/ops/evidence/authority.json",
                "sha256": _sha(authority_path),
            }],
        })

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
            "candidate_recheck": candidate_recheck,
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
    if with_authority:
        compile_payload.update({
            "append_only_source_repair": True,
            "compile_source_repair_authority": "fixture:input-pin:QM5_9902",
        })
    source_payload = {
        "expected_current_ex5_sha256": old_ex5_sha,
        "expected_ex5_sha256": old_ex5_sha,
        "expected_mq5_sha256": hashlib.sha256(b"old source\n").hexdigest(),
        "expected_setfile_sha256": old_setfile_sha,
        "expected_symbol": "EURUSD.DWX",
        "expected_period": "H1",
        "expected_expert": f"QM\\{ea_dir.name}",
        "host_symbol": "EURUSD.DWX",
        "host_timeframe": "H1",
        "from_date": "2018.01.01",
        "to_date": "2025.12.31",
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
        "artifact_identity": {
            "ex5_sha256": old_ex5_sha,
            "setfile_sha256": old_setfile_sha,
        },
    }
    if compile_gate_unbound:
        source_payload.pop("expected_setfile_sha256")
        source_payload["artifact_identity"].pop("setfile_sha256")
        source_payload["spawn_refusal"] = {
            "phase": "Q02",
            "reason": "compile_gate:COMPILE_FAILED",
            "terminal": "T1",
        }
    status = "failed" if compile_gate_unbound else ("done" if terminal else "pending")
    verdict = "INFRA_FAIL" if compile_gate_unbound else ("PASS" if terminal else None)
    taxonomy = "infra" if compile_gate_unbound else ("economic" if terminal else "open")
    source_evidence = (
        "EVIDENCE_UNAVAILABLE:spawn_refusal:compile_gate:COMPILE_FAILED"
        if compile_gate_unbound
        else ("EVIDENCE_UNAVAILABLE" if terminal else None)
    )
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
                json.dumps(compile_payload), now, now, ex5_sha,
                current_setfile_sha, mq5_sha,
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
                source_evidence,
                json.dumps(source_payload), now, now, old_ex5_sha,
                None if compile_gate_unbound else old_setfile_sha,
                source_payload["expected_mq5_sha256"], taxonomy,
            ),
        )
        conn.commit()
    return {
        "root": root,
        "repo": repo,
        "ex5_sha": ex5_sha,
        "old_setfile_sha": old_setfile_sha,
        "current_setfile_sha": current_setfile_sha,
        "receipt_dir": tmp_path / "receipts",
    }


def _call(fixture: dict[str, object], *, apply: bool = False) -> dict[str, object]:
    return farmctl.requalify_q02_post_binding(
        fixture["root"],  # type: ignore[arg-type]
        SOURCE_ID,
        expected_current_ex5_sha256=str(fixture["ex5_sha"]),
        reason="fixture post-binding identity requalification",
        apply=apply,
        receipt_dir=fixture["receipt_dir"],  # type: ignore[arg-type]
        repo_root=fixture["repo"],  # type: ignore[arg-type]
    )


def test_physical_host_dependency_manifest_does_not_require_logical_symbol() -> None:
    row = {"symbol": "USDJPY.DWX"}
    payload = {
        "basket_manifest": "basket_manifest.json",
        "basket_symbol_count": 2,
        "basket_symbols": ["EURUSD.DWX", "USDJPY.DWX"],
        "host_symbol": "USDJPY.DWX",
        "expected_symbol": "USDJPY.DWX",
    }

    ok, binding = farmctl._q02_execution_symbol_binding(
        row, payload  # type: ignore[arg-type]
    )

    assert ok is True
    assert binding == {
        "expected_symbol": "USDJPY.DWX",
        "physical_host_dependency": True,
    }


def test_synthetic_basket_without_logical_symbol_remains_fail_closed() -> None:
    row = {"symbol": "EURUSD_GBPUSD_BASKET"}
    payload = {
        "basket_manifest": "basket_manifest.json",
        "basket_symbol_count": 2,
        "basket_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
        "host_symbol": "EURUSD.DWX",
        "expected_symbol": "EURUSD.DWX",
    }

    ok, binding = farmctl._q02_execution_symbol_binding(
        row, payload  # type: ignore[arg-type]
    )

    assert ok is False
    assert binding["reason"] == "historical_execution_identity_missing"
    assert binding["binding"] == "logical_symbol"


def test_pending_predecessor_is_superseded_append_only_with_receipt(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    dry_run = _call(fixture)
    assert dry_run["eligible"] is True
    assert dry_run["parameter_diff"] == []
    assert dry_run["setfile_recovery"]["exact_sha256"] == fixture["old_setfile_sha"]

    result = _call(fixture, apply=True)
    assert result["applied"] is True
    successor_id = str(result["successor_work_item_id"])
    receipt = json.loads(Path(str(result["receipt_path"])).read_text(encoding="utf-8"))
    assert receipt["parameter_diff"] == []
    with farmctl.connect(fixture["root"]) as conn:  # type: ignore[arg-type]
        predecessor = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id=?", (SOURCE_ID,)
        ).fetchone()
        successor = conn.execute(
            "SELECT status,verdict,ex5_sha256,setfile_sha256,payload_json "
            "FROM work_items WHERE id=?", (successor_id,),
        ).fetchone()
        sidecar = conn.execute(
            "SELECT superseded_by_work_item_id,source_encoding,evidence_path "
            "FROM work_item_supersedes WHERE work_item_id=?", (SOURCE_ID,),
        ).fetchone()
        claimable = {
            row["id"] for row in conn.execute(farmctl.pending_claim_order_sql())
        }
    assert tuple(predecessor) == ("pending", None)
    assert tuple(successor[:4]) == (
        "pending", None, fixture["ex5_sha"], fixture["current_setfile_sha"]
    )
    payload = json.loads(successor["payload_json"])
    assert payload["q02_post_binding_requalification_of"] == SOURCE_ID
    assert sidecar["superseded_by_work_item_id"] == successor_id
    assert sidecar["source_encoding"] == "farmctl:requalify-q02/v1"
    assert Path(sidecar["evidence_path"]) == Path(str(result["receipt_path"]))
    assert SOURCE_ID not in claimable
    assert successor_id in claimable


def test_terminal_predecessor_and_verdict_are_retained(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path, terminal=True)
    result = _call(fixture, apply=True)
    assert result["applied"] is True
    with farmctl.connect(fixture["root"]) as conn:  # type: ignore[arg-type]
        predecessor = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id=?", (SOURCE_ID,)
        ).fetchone()
        sidecar = conn.execute(
            "SELECT superseded_by_work_item_id FROM work_item_supersedes "
            "WHERE work_item_id=?", (SOURCE_ID,),
        ).fetchone()
    assert tuple(predecessor) == ("done", "PASS")
    assert sidecar[0] == result["successor_work_item_id"]


def test_compile_gate_unbound_setfile_requires_source_repair_compile(
    tmp_path: Path,
) -> None:
    fixture = _fixture(tmp_path, compile_gate_unbound=True)

    result = _call(fixture)

    assert result["ok"] is False
    assert result["reason"] == (
        "compile_gate_unbound_setfile_requires_source_repair_compile"
    )


def test_compile_gate_unbound_setfile_can_requalify_after_authorized_compile(
    tmp_path: Path,
) -> None:
    fixture = _fixture(
        tmp_path,
        compile_gate_unbound=True,
        with_authority=True,
    )

    dry_run = _call(fixture)
    assert dry_run["eligible"] is True
    assert dry_run["compile_gate_unbound_setfile"] is True
    assert dry_run["source_setfile_sha256"] is None
    assert dry_run["parameter_diff"] == []
    assert dry_run["setfile_recovery"] == {
        "method": "compile_gate_unbound_current_canonical_setfile",
        "historical_setfile_sha256": None,
        "current_setfile_sha256": fixture["current_setfile_sha"],
        "tester_launch_proven_absent": True,
    }

    result = _call(fixture, apply=True)
    assert result["applied"] is True
    with farmctl.connect(fixture["root"]) as conn:  # type: ignore[arg-type]
        successor = conn.execute(
            "SELECT payload_json,setfile_sha256 FROM work_items WHERE id=?",
            (result["successor_work_item_id"],),
        ).fetchone()
    payload = json.loads(successor["payload_json"])
    assert payload["requalification_compile_gate_unbound_setfile"] is True
    assert successor["setfile_sha256"] == fixture["current_setfile_sha"]


def test_parameter_change_is_refused_without_hash_bound_authority(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path, parameter_change=True)
    result = _call(fixture)
    assert result["ok"] is False
    assert result["reason"] == "parameter_change_provenance_missing"
    assert result["parameter_diff"] == [{
        "key": "strategy_period",
        "change": "changed",
        "before": "20",
        "after": "21",
    }]


def test_parameter_change_accepts_exact_compile_source_repair_authority(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path, parameter_change=True, with_authority=True)
    result = _call(fixture)
    assert result["eligible"] is True
    assert result["parameter_change_count"] == 1
    provenance = result["parameter_provenance"]
    assert provenance["source_repair_authority"] == "fixture:input-pin:QM5_9902"
    assert provenance["registration"]["ea_id"] == "9902"


def test_operator_current_ex5_sha_mismatch_is_refused(tmp_path: Path) -> None:
    fixture = _fixture(tmp_path)
    result = farmctl.requalify_q02_post_binding(
        fixture["root"],  # type: ignore[arg-type]
        SOURCE_ID,
        expected_current_ex5_sha256="0" * 64,
        reason="wrong operator hash",
        repo_root=fixture["repo"],  # type: ignore[arg-type]
    )
    assert result["ok"] is False
    assert result["reason"] == "canonical_ex5_sha256_mismatch"
