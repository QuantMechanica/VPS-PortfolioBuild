from __future__ import annotations

import json
from pathlib import Path
import sqlite3
import threading
from unittest.mock import patch

from tools.strategy_farm import farmctl
from tools.strategy_farm import next_cell_prestage
from tools.strategy_farm import terminal_worker


FIXTURE = Path(__file__).parent / "fixtures" / "next_cell_prestage_replay.json"


def _install_fixture(root: Path, fixture: dict) -> None:
    farmctl.init_db(root)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        for item in fixture["items"]:
            ea_dir = root / "fixture_eas" / f"{item['ea_id']}_replay"
            setfile = ea_dir / "sets" / f"{item['id']}.set"
            setfile.parent.mkdir(parents=True, exist_ok=True)
            setfile.write_text(
                "ENV=backtest\nRISK_FIXED=1000\nRISK_PERCENT=0\n",
                encoding="utf-8",
            )
            (ea_dir / f"{ea_dir.name}.ex5").write_bytes(
                f"binary:{item['id']}".encode("ascii")
            )
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES (?, 'backtest', ?, ?, ?, ?, 'pending', NULL,
                        0, NULL, NULL, NULL, ?, ?, ?)
                """,
                (
                    item["id"],
                    item["phase"],
                    item["ea_id"],
                    item["symbol"],
                    str(setfile.resolve()),
                    json.dumps(item["payload"], sort_keys=True),
                    item["created_at"],
                    item["created_at"],
                ),
            )
        conn.commit()


def _authoritative_snapshot(root: Path) -> dict:
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.row_factory = sqlite3.Row
        work_items = [
            dict(row)
            for row in conn.execute(
                """
                SELECT id,status,verdict,claimed_by,payload_json,updated_at
                FROM work_items ORDER BY id
                """
            )
        ]
        ledger = [
            dict(row)
            for row in conn.execute(
                """
                SELECT terminal,work_item_id,claim_class,claimed_at_utc
                FROM claim_class_ledger ORDER BY seq
                """
            )
        ]
    return {"work_items": work_items, "claim_class_ledger": ledger}


def _controller(
    root: Path,
    terminal: str,
    *,
    enabled: bool,
    telemetry: list[dict],
) -> next_cell_prestage.PrestageController:
    config = next_cell_prestage.PrestageConfig(
        root=root,
        terminal=terminal,
        enabled=enabled,
        terminal_allowlist=[terminal] if enabled else [],
        ttl_seconds=300,
        max_bytes=1024**2,
        io_mib_per_second=1024.0,
        min_free_disk_gb=0.0,
        min_free_ram_gb=0.0,
        min_free_commit_gb=0.0,
        max_cpu_percent=100.0,
        cancel_join_seconds=2.0,
    )
    return next_cell_prestage.PrestageController(
        config,
        snapshot_loader=lambda generation, cancel: terminal_worker._load_next_cell_prestage_snapshot(
            root, terminal, config, generation, cancel
        ),
        candidate_is_current=lambda token: terminal_worker._next_cell_prestage_candidate_is_current(
            root, token
        ),
        resource_probe=lambda: {"allowed": True, "reason": "replay_fixture"},
        policy_generation=terminal_worker._next_cell_prestage_policy_generation,
        dependency_validator=lambda plan: terminal_worker._next_cell_prestage_dependency_validator(
            root, terminal, plan
        ),
        telemetry=lambda value: telemetry.append(dict(value)),
    )


def _replay(root: Path, fixture: dict, *, prestage_enabled: bool) -> dict:
    _install_fixture(root, fixture)
    terminal = fixture["terminal"]
    telemetry: list[dict] = []
    controller = _controller(
        root,
        terminal,
        enabled=prestage_enabled,
        telemetry=telemetry,
    )
    claims: list[str] = []
    adoptions: list[str] = []
    for index, expected_item_id in enumerate(fixture["expected_claim_order"]):
        if prestage_enabled:
            prepared = threading.Event()
            original_sink = controller.telemetry

            def sink(value: dict) -> None:
                original_sink(value)
                if value.get("stage_event") == "prepared":
                    prepared.set()

            controller.telemetry = sink
            controller.child_spawned(item_id=f"current-{index}", pid=1000 + index)
            assert prepared.wait(5), telemetry
            controller.child_finished(item_id=f"current-{index}")
            controller.telemetry = original_sink

        controller.claim_attempt()
        claim = terminal_worker.claim_atomic(root, terminal)
        adoption = controller.claim_result(claim)
        assert claim.get("claimed"), claim
        claims.append(str(claim["item"]["id"]))
        assert claims[-1] == expected_item_id
        if adoption is not None:
            adoptions.append(str(adoption["item"]["id"]))
        with sqlite3.connect(root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                UPDATE work_items
                SET status='done', verdict='PASS', claimed_by=NULL, updated_at=?
                WHERE id=? AND status='active' AND claimed_by=?
                """,
                (fixture["fixed_now"], expected_item_id, terminal),
            )
            conn.commit()
    controller.shutdown()
    return {
        "claims": claims,
        "adoptions": adoptions,
        "authority": _authoritative_snapshot(root),
        "telemetry": telemetry,
    }


def test_replay_authority_is_identical_with_and_without_prestaging(
    tmp_path: Path,
) -> None:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    fixed_now = fixture["fixed_now"]
    worker_farmctl = terminal_worker.farmctl
    patches = (
        patch.object(worker_farmctl, "utc_now", return_value=fixed_now),
        patch.object(
            worker_farmctl,
            "_news_calendar_preflight",
            return_value={"ok": True, "status": "VALID"},
        ),
        patch.object(worker_farmctl, "_dwx_symbol_history_registry", return_value={}),
        patch.object(terminal_worker, "_process_private_snapshot", return_value={}),
        patch.object(terminal_worker, "_commit_headroom_gb", return_value=10_000.0),
        patch.object(terminal_worker, "_free_ram_gb", return_value=10_000.0),
        patch.object(terminal_worker, "_multisymbol_ea_ids", return_value=set()),
        patch.object(
            terminal_worker,
            "_p2_history_claimable",
            return_value=(True, None),
        ),
        patch.object(terminal_worker, "CLAIM_SPACING_SECONDS", 0.0),
        patch.object(
            terminal_worker.longrun_scheduling_policy,
            "policy_enabled",
            return_value=False,
        ),
    )
    for active_patch in patches:
        active_patch.start()
    try:
        disabled = _replay(tmp_path / "disabled", fixture, prestage_enabled=False)
        enabled = _replay(tmp_path / "enabled", fixture, prestage_enabled=True)
    finally:
        for active_patch in reversed(patches):
            active_patch.stop()

    assert disabled["claims"] == fixture["expected_claim_order"]
    assert enabled["claims"] == fixture["expected_claim_order"]
    assert disabled["authority"] == enabled["authority"]
    assert disabled["adoptions"] == []
    assert enabled["adoptions"] == fixture["expected_claim_order"]
    assert not (tmp_path / "disabled" / "cache" / "next_cell_prestage").exists()
    assert {
        event["stage_event"]
        for event in enabled["telemetry"]
    } >= {"prepared", "adoption_complete", "next_claim_attempt"}
