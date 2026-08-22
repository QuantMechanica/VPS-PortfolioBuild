from __future__ import annotations

import csv
import json
from pathlib import Path

from tools.strategy_farm import compile_work_items, farmctl, terminal_worker


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _fixture(tmp_path: Path, labels: list[str]) -> tuple[Path, Path]:
    repo = tmp_path / "repo"
    root = tmp_path / "farm"
    registry_rows = []
    magic_rows = []
    for offset, label in enumerate(labels):
        ea_id = str(1001 + offset)
        registry_rows.append({
            "ea_id": ea_id,
            "slug": label.split("_", 2)[2],
            "strategy_id": f"SRC_{ea_id}",
            "status": "active",
            "owner": "Research",
            "created_at": "2026-08-01",
        })
        magic_rows.append({
            "ea_id": ea_id,
            "ea_slug": label.split("_", 2)[2],
            "symbol_slot": "0",
            "symbol": "EURUSD.DWX",
            "magic": str(int(ea_id) * 10000),
            "reserved_at": "2026-08-01",
            "reserved_by": "test",
            "status": "active",
        })
        ea_dir = repo / "framework" / "EAs" / label
        ea_dir.mkdir(parents=True)
        (ea_dir / f"{label}.mq5").write_text(
            "#property strict\ninput double RISK_FIXED=1000.0;\n",
            encoding="utf-8",
        )
    _write_csv(
        repo / "framework" / "registry" / "ea_id_registry.csv",
        ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"],
        registry_rows,
    )
    _write_csv(
        repo / "framework" / "registry" / "magic_numbers.csv",
        [
            "ea_id", "ea_slug", "symbol_slot", "symbol", "magic",
            "reserved_at", "reserved_by", "status",
        ],
        magic_rows,
    )
    farmctl.init_db(root)
    return repo, root


def test_enqueue_compile_is_idempotent_for_existing_open_row(tmp_path: Path) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])

    first = compile_work_items.enqueue_compile_eas(root, repo, [label])
    second = compile_work_items.enqueue_compile_eas(root, repo, [label])

    assert first["mode"] == "apply"
    assert first["enqueued_count"] == 1
    assert second["ok"] is True
    assert second["enqueued_count"] == 0
    assert second["idempotent_open_count"] == 1
    with farmctl.connect(root) as conn:
        rows = conn.execute(
            "SELECT kind,phase,status FROM work_items WHERE ea_id='QM5_1001'"
        ).fetchall()
        hold = conn.execute(
            "SELECT hold_code,active,release_on_restart FROM work_item_holds"
        ).fetchone()
    assert [tuple(row) for row in rows] == [("compile", "COMPILE_EA", "pending")]
    assert tuple(hold) == (
        compile_work_items.COMPILE_ACTIVATION_HOLD_CODE,
        1,
        1,
    )


def test_batch_from_file_is_dry_run_until_apply(tmp_path: Path) -> None:
    labels = [
        "QM5_1001_compile-fixture-h1",
        "QM5_1002_second-fixture-d1",
    ]
    repo, root = _fixture(tmp_path, labels)
    batch = repo / "compile_labels.txt"
    batch.write_text("\n".join(labels) + "\n", encoding="utf-8")

    dry_run = compile_work_items.enqueue_compile_eas(
        root, repo, [], from_file=str(batch)
    )
    with farmctl.connect(root) as conn:
        before_apply = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE phase='COMPILE_EA'"
        ).fetchone()[0]
    applied = compile_work_items.enqueue_compile_eas(
        root, repo, [], from_file=str(batch), apply=True
    )

    assert dry_run["mode"] == "dry_run"
    assert dry_run["eligible_count"] == 2
    assert before_apply == 0
    assert applied["enqueued_count"] == 2


def test_compile_batch_status_reports_pending_hold_and_failure_classes(
    tmp_path: Path,
) -> None:
    labels = [
        "QM5_1001_compile-fixture-h1",
        "QM5_1002_second-fixture-d1",
    ]
    repo, root = _fixture(tmp_path, labels)
    applied = compile_work_items.enqueue_compile_eas(root, repo, labels)
    failed_id = applied["enqueued"][1]["work_item_id"]
    with farmctl.connect(root) as conn:
        payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (failed_id,)
            ).fetchone()[0]
        )
        payload["compile_result"] = {
            "failure_classes": ["COMPILE_ERRORS"],
            "build_check_result": "FAIL",
            "setfile_count": 1,
        }
        conn.execute(
            "UPDATE work_items SET status='failed',verdict='COMPILE_FAIL',payload_json=? "
            "WHERE id=?",
            (json.dumps(payload), failed_id),
        )
        conn.commit()

    status = compile_work_items.compile_batch_status(root, repo, labels)

    assert status["counts"] == {
        "compiled": 0,
        "failed": 1,
        "pending": 1,
        "active": 0,
        "not_enqueued": 0,
        "activation_held": 2,
    }
    assert status["results"][0]["activation_hold"] == (
        compile_work_items.COMPILE_ACTIVATION_HOLD_CODE
    )
    assert status["results"][1]["failure_classes"] == ["COMPILE_ERRORS"]


def test_candidate_refuses_work_history_and_bound_hash(tmp_path: Path) -> None:
    labels = [
        "QM5_1001_compile-fixture-h1",
        "QM5_1002_second-fixture-d1",
    ]
    repo, root = _fixture(tmp_path, labels)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,created_at,updated_at) "
            "VALUES ('old-row','backtest','Q02','QM5_1001','EURUSD.DWX','x.set','pending',0,'{}',?,?)",
            (now, now),
        )
        conn.commit()
    setfile = (
        repo / "framework" / "EAs" / labels[1] / "sets"
        / f"{labels[1]}_EURUSD.DWX_D1_backtest.set"
    )
    setfile.parent.mkdir()
    setfile.write_text("; build_hash: " + "a" * 64 + "\n", encoding="utf-8")

    inventory = compile_work_items._inventory(root, repo)
    one = compile_work_items.classify_candidate(root, repo, labels[0], inventory)
    two = compile_work_items.classify_candidate(root, repo, labels[1], inventory)

    assert one["eligible"] is False
    assert "WORK_ITEMS_EXIST" in one["reasons"]
    assert two["eligible"] is False
    assert "BOUND_SETFILE_HASH_EXISTS" in two["reasons"]


def test_candidate_recheck_allows_only_exact_r11_revival_predecessor(
    tmp_path: Path,
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])
    source_sha = compile_work_items.sha256_file(
        repo / "framework" / "EAs" / label / f"{label}.mq5"
    )
    now = farmctl.utc_now()
    old_payload = {
        "ea_label": label,
        "mq5_sha256": source_sha,
        "repair_handler": compile_work_items.R11_INCIDENT_HANDLER,
        "verdict_reason": compile_work_items.R11_INCIDENT_REASON,
    }
    revival_payload = {
        "ea_label": label,
        "mq5_sha256": source_sha,
        "revival_contract_version": compile_work_items.R11_REVIVAL_CONTRACT_VERSION,
        "revival_authority_task_id": compile_work_items.R11_REVIVAL_AUTHORITY_TASK_ID,
        "revival_reason": compile_work_items.R11_REVIVAL_REASON,
        "revival_source_mq5_sha256": source_sha,
        "revived_from_work_item_id": "r11-old",
        "append_only_revival": True,
    }
    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,"
            "payload_json,created_at,updated_at) "
            "VALUES ('r11-old','compile','COMPILE_EA','QM5_1001','','','failed',"
            "'INVALID',0,?,?,?)",
            (json.dumps(old_payload), now, now),
        )
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,claimed_by,"
            "payload_json,created_at,updated_at) "
            "VALUES ('revived','compile','COMPILE_EA','QM5_1001','','','active',0,"
            "'T8',?,?,?)",
            (json.dumps(revival_payload), now, now),
        )
        conn.commit()

    inventory = compile_work_items._inventory(root, repo)
    sanctioned = compile_work_items._sanctioned_compile_predecessor_ids(
        revival_payload, inventory, "1001"
    )
    candidate = compile_work_items.classify_candidate(
        root,
        repo,
        label,
        inventory,
        current_work_item_id="revived",
        sanctioned_predecessor_ids=sanctioned,
    )

    assert sanctioned == {"r11-old"}
    assert candidate["eligible"] is True
    assert candidate["sanctioned_predecessor_ids"] == ["r11-old"]

    old_payload["repair_handler"] = "not-the-r11-incident"
    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id='r11-old'",
            (json.dumps(old_payload),),
        )
        conn.commit()
    inventory = compile_work_items._inventory(root, repo)
    refused_ids = compile_work_items._sanctioned_compile_predecessor_ids(
        revival_payload, inventory, "1001"
    )
    refused = compile_work_items.classify_candidate(
        root,
        repo,
        label,
        inventory,
        current_work_item_id="revived",
        sanctioned_predecessor_ids=refused_ids,
    )
    assert refused_ids == set()
    assert refused["eligible"] is False
    assert "WORK_ITEMS_EXIST" in refused["reasons"]


def test_candidate_refuses_unresolved_timeframe_before_enqueue(tmp_path: Path) -> None:
    label = "QM5_1001_compile-fixture"
    repo, root = _fixture(tmp_path, [label])

    inventory = compile_work_items._inventory(root, repo)
    candidate = compile_work_items.classify_candidate(root, repo, label, inventory)

    assert candidate["eligible"] is False
    assert "TIMEFRAME_UNRESOLVED" in candidate["reasons"]


def test_terminal_worker_routes_compile_before_generic_ex5_preflight(
    tmp_path: Path, monkeypatch
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])
    now = farmctl.utc_now()
    payload = {
        "ea_label": label,
        "mq5_sha256": compile_work_items.sha256_file(
            repo / "framework" / "EAs" / label / f"{label}.mq5"
        ),
    }
    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,claimed_by,payload_json,created_at,updated_at) "
            "VALUES ('compile-row','compile','COMPILE_EA','QM5_1001','','','active',0,'T3',?,?,?)",
            (json.dumps(payload), now, now),
        )
        conn.commit()

    called = {}

    def fake_run(run_root, run_repo, row, terminal):
        called.update({"root": run_root, "repo": run_repo, "id": row["id"], "terminal": terminal})
        return {"action": "compile_ea_finished", "success": True}

    monkeypatch.setattr(compile_work_items, "run_compile_work_item", fake_run)
    monkeypatch.setattr(terminal_worker.farmctl, "REPO_ROOT", repo)
    result = terminal_worker._run_claimed_item(
        root,
        {"id": "compile-row"},
        "T3",
        timeout_seconds=60,
    )

    assert result == {"action": "compile_ea_finished", "success": True}
    assert called == {"root": root, "repo": repo, "id": "compile-row", "terminal": "T3"}
