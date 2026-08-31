from __future__ import annotations

import csv
import json
from pathlib import Path

import pytest

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


def _insert_build_task(
    root: Path,
    repo: Path,
    label: str,
    task_id: str,
    *,
    status: str = "pending",
    payload_overrides: dict[str, str] | None = None,
) -> None:
    parts = compile_work_items._label_parts(label)
    assert parts is not None
    _canonical_label, numeric_id, slug = parts
    payload = {
        "ea_id": f"QM5_{numeric_id}",
        "slug": slug,
        "ea_dir": str(repo / "framework" / "EAs" / label),
    }
    payload.update(payload_overrides or {})
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO tasks "
            "(id,kind,status,source_id,card_id,payload_json,created_at,updated_at) "
            "VALUES (?,'build_ea',?,NULL,?,?,?,?)",
            (
                task_id,
                status,
                f"QM5_{numeric_id}",
                json.dumps(payload, sort_keys=True),
                now,
                now,
            ),
        )
        conn.commit()


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


def test_open_build_task_compile_requires_exact_identity_binding(
    tmp_path: Path,
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    task_id = "build-task-1001"
    repo, root = _fixture(tmp_path, [label])
    _insert_build_task(root, repo, label, task_id)

    unbound = compile_work_items.enqueue_compile_eas(root, repo, [label])
    bound = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [label],
        build_task_id=task_id,
    )

    assert unbound["ok"] is False
    assert unbound["enqueued_count"] == 0
    assert "BUILD_TASK_EXISTS" in unbound["refused"][0]["reasons"]
    assert bound["ok"] is True
    assert bound["enqueued_count"] == 1
    work_item_id = bound["enqueued"][0]["work_item_id"]
    with farmctl.connect(root) as conn:
        payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?",
                (work_item_id,),
            ).fetchone()[0]
        )
    assert payload["compile_build_task_binding_contract_version"] == (
        compile_work_items.BUILD_TASK_BINDING_CONTRACT_VERSION
    )
    assert payload["bound_build_task_id"] == task_id
    assert payload["bound_build_task_ea_id"] == "QM5_1001"

    inventory = compile_work_items._inventory(root, repo)
    worker_recheck = compile_work_items.classify_candidate(
        root,
        repo,
        label,
        inventory,
        current_work_item_id=work_item_id,
        bound_build_task_id=task_id,
    )
    assert worker_recheck["eligible"] is True
    assert worker_recheck["build_task_binding_authorized"] is True


def test_build_task_compile_binding_fails_closed_on_wrong_task_or_state(
    tmp_path: Path,
) -> None:
    labels = [
        "QM5_1001_compile-fixture-h1",
        "QM5_1002_second-fixture-d1",
    ]
    repo, root = _fixture(tmp_path, labels)
    _insert_build_task(root, repo, labels[0], "build-task-1001")
    _insert_build_task(root, repo, labels[1], "build-task-1002")

    wrong_task = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [labels[0]],
        build_task_id="build-task-1002",
    )
    assert wrong_task["ok"] is False
    assert "BUILD_TASK_BINDING_IDENTITY_MISMATCH" in (
        wrong_task["refused"][0]["reasons"]
    )

    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE tasks SET status='done' WHERE id='build-task-1001'"
        )
        conn.commit()
    closed_task = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [labels[0]],
        build_task_id="build-task-1001",
    )
    assert closed_task["ok"] is False
    assert "BUILD_TASK_BINDING_NOT_OPEN" in closed_task["refused"][0]["reasons"]

    broad_request = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        labels,
        build_task_id="build-task-1002",
    )
    assert broad_request == {
        "ok": False,
        "reason": "BUILD_TASK_BINDING_REQUIRES_ONE_EXPLICIT_EA_LABEL",
        "enqueued_count": 0,
    }


def test_source_repair_appends_fresh_row_without_mutating_stale_open(
    tmp_path: Path, monkeypatch,
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])
    monkeypatch.setattr(
        compile_work_items, "SOURCE_REPAIR_EA_LABELS", frozenset({label})
    )
    first = compile_work_items.enqueue_compile_eas(root, repo, [label])
    old_id = first["enqueued"][0]["work_item_id"]
    source = repo / "framework" / "EAs" / label / f"{label}.mq5"
    source.write_text(source.read_text(encoding="utf-8") + "// repaired\n", encoding="utf-8")
    current_sha = compile_work_items.sha256_file(source)

    repair = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [label],
        source_repair_authority=compile_work_items.SOURCE_REPAIR_AUTHORITY,
    )

    assert repair["ok"] is True
    assert repair["enqueued_count"] == 1
    new_id = repair["enqueued"][0]["work_item_id"]
    assert new_id != old_id
    with farmctl.connect(root) as conn:
        rows = conn.execute(
            "SELECT id,status,verdict,payload_json FROM work_items "
            "WHERE ea_id='QM5_1001' ORDER BY created_at,id"
        ).fetchall()
    assert {
        row["id"]: (row["status"], row["verdict"]) for row in rows
    } == {
        old_id: ("pending", None),
        new_id: ("pending", None),
    }
    payload = json.loads(next(row["payload_json"] for row in rows if row["id"] == new_id))
    assert payload["mq5_sha256"] == current_sha
    assert payload["append_only_source_repair"] is True
    assert payload["compile_source_repair_authority"] == (
        compile_work_items.SOURCE_REPAIR_AUTHORITY
    )
    assert payload["source_repair_stale_open_work_item_ids"] == [old_id]

    repeated = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [label],
        source_repair_authority=compile_work_items.SOURCE_REPAIR_AUTHORITY,
    )

    assert repeated["ok"] is True
    assert repeated["enqueued_count"] == 0
    assert repeated["idempotent_open_count"] == 1
    assert repeated["idempotent_open"][0]["work_item_ids"] == [new_id]
    with farmctl.connect(root) as conn:
        row_count = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE ea_id='QM5_1001'"
        ).fetchone()[0]
    assert row_count == 2

    worker_recheck = compile_work_items.classify_candidate(
        root,
        repo,
        label,
        compile_work_items._inventory(root, repo),
        current_work_item_id=new_id,
        source_repair_authority=compile_work_items.SOURCE_REPAIR_AUTHORITY,
    )
    assert worker_recheck["eligible"] is True
    assert worker_recheck["source_repair_authorized"] is True
    assert worker_recheck["source_repair_waived_reasons"] == ["WORK_ITEMS_EXIST"]


def test_source_repair_refuses_current_compile_ok(
    tmp_path: Path, monkeypatch,
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])
    monkeypatch.setattr(
        compile_work_items, "SOURCE_REPAIR_EA_LABELS", frozenset({label})
    )
    first = compile_work_items.enqueue_compile_eas(root, repo, [label])
    work_item_id = first["enqueued"][0]["work_item_id"]
    with farmctl.connect(root) as conn:
        source = repo / "framework" / "EAs" / label / f"{label}.mq5"
        binary = source.with_suffix(".ex5")
        binary.write_bytes(b"usable current binary")
        conn.execute(
            "UPDATE work_items SET status='done',verdict='COMPILE_OK',ex5_sha256=? WHERE id=?",
            (compile_work_items.sha256_file(binary), work_item_id),
        )
        conn.commit()

    repair = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [label],
        source_repair_authority=compile_work_items.SOURCE_REPAIR_AUTHORITY,
    )

    assert repair["ok"] is False
    assert repair["enqueued_count"] == 0
    assert repair["refused"][0]["reason"] == "USABLE_CURRENT_COMPILE_VERDICT_EXISTS"


def test_rollout_reconciliation_authority_requires_stale_hold_and_supersession(
    tmp_path: Path,
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])
    first = compile_work_items.enqueue_compile_eas(root, repo, [label])
    old_id = first["enqueued"][0]["work_item_id"]
    source = repo / "framework" / "EAs" / label / f"{label}.mq5"
    source.write_text(source.read_text(encoding="utf-8") + "// current\n", encoding="utf-8")

    repair = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [label],
        source_repair_authority=(
            compile_work_items.ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY
        ),
    )

    assert repair["ok"] is True
    assert repair["enqueued_count"] == 1
    new_id = repair["enqueued"][0]["work_item_id"]
    with farmctl.connect(root) as conn:
        conn.execute(
            """INSERT INTO work_item_supersedes
               (work_item_id,superseded_by_work_item_id,reason,source_encoding,
                evidence_path,recorded_by,recorded_at)
               VALUES (?,?,'test','operator:test',NULL,'test',?)""",
            (old_id, new_id, farmctl.utc_now()),
        )
        conn.execute(
            "UPDATE work_item_holds SET active=0 WHERE work_item_id=?",
            (old_id,),
        )
        conn.commit()

    worker_recheck = compile_work_items.classify_candidate(
        root,
        repo,
        label,
        compile_work_items._inventory(root, repo),
        current_work_item_id=new_id,
        source_repair_authority=(
            compile_work_items.ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY
        ),
    )
    unauthorized_new_enqueue = compile_work_items.classify_candidate(
        root,
        repo,
        label,
        compile_work_items._inventory(root, repo),
        source_repair_authority=(
            compile_work_items.ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY
        ),
    )

    assert worker_recheck["eligible"] is True
    assert worker_recheck["source_repair_authorized"] is True
    assert unauthorized_new_enqueue["eligible"] is False
    assert unauthorized_new_enqueue["reason"] == "OPEN_COMPILE_EA_EXISTS"


def test_q02_infra_source_repair_authority_is_exact_label_bound() -> None:
    label = "QM5_11900_kobasfx-4ema-macd-sentiment-h1"

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.Q02_INFRA_SOURCE_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_11901_unrelated-h1",
        compile_work_items.Q02_INFRA_SOURCE_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_q02_infra_repair:wrong-task",
    )


def test_qm5_1252_q02_infra_repair_authority_is_exact_label_bound() -> None:
    label = "QM5_1252_carver-handcraft-ens"

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_1252_Q02_INFRA_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_1253_unrelated-d1",
        compile_work_items.QM5_1252_Q02_INFRA_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_ops_issue:wrong-task",
    )


def test_qm5_41163_mae_repair_authority_is_exact_label_bound() -> None:
    label = "QM5_41163_williams-18ma-outside-bar-entry-d1-opt"

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41163_MAE_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41162_ohlc-daily-squeeze-reversal-d1-opt",
        compile_work_items.QM5_41163_MAE_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_ops_issue:wrong-task",
    )


def test_qm5_41163_setfile_repair_authority_is_exact_label_bound() -> None:
    label = "QM5_41163_williams-18ma-outside-bar-entry-d1-opt"

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41163_SETFILE_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41162_ohlc-daily-squeeze-reversal-d1-opt",
        compile_work_items.QM5_41163_SETFILE_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_ops_issue:wrong-task",
    )


def test_qm5_41194_dl089_build_repair_authority_is_exact_label_bound() -> None:
    label = "QM5_41194_brent-tom-mom-opt"

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41194_DL089_BUILD_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41195_aa-vol-sma10-opt",
        compile_work_items.QM5_41194_DL089_BUILD_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_ops_issue:wrong-task",
    )


def test_dl089_sibling_rebind_authority_is_exact_task_and_label_bound() -> None:
    allowed = compile_work_items.DL089_SIBLING_REBIND_EA_LABELS
    authorities = {
        compile_work_items.DL089_SIBLING_REBIND_AUTHORITY,
        compile_work_items.DL089_SIBLING_REPAIR_AUTHORITY,
    }

    assert allowed == frozenset({
        "QM5_41195_aa-vol-sma10-opt",
        "QM5_41196_qs-kama-trend-xau-opt",
    })
    for authority in authorities:
        for label in allowed:
            assert compile_work_items._sibling_rebind_authorized(label, authority)
            assert compile_work_items._source_repair_authorized(label, authority)
        assert not compile_work_items._sibling_rebind_authorized(
            "QM5_41194_brent-tom-mom-opt", authority
        )
        assert not compile_work_items._source_repair_authorized(
            "QM5_41194_brent-tom-mom-opt", authority
        )
    for label in allowed:
        assert not compile_work_items._sibling_rebind_authorized(
            label, "router_ops_issue:28d59a8e-71be-437b-ac8b-0246f37c9ef5"
        )
        assert not compile_work_items._sibling_rebind_authorized(
            label, "router_ops_issue:wrong-task"
        )
    assert compile_work_items._sibling_rebind_directory(
        compile_work_items.DL089_SIBLING_REBIND_AUTHORITY,
        "QM5_41196_qs-kama-trend-xau-opt",
    ) == compile_work_items.DL089_SIBLING_REBIND_DIRECTORY
    assert compile_work_items._sibling_rebind_directory(
        compile_work_items.DL089_SIBLING_REPAIR_AUTHORITY,
        "QM5_41195_aa-vol-sma10-opt",
    ) == compile_work_items.DL089_SIBLING_REPAIR_DIRECTORY
    assert compile_work_items._sibling_rebind_directory(
        compile_work_items.DL089_SIBLING_REPAIR_AUTHORITY,
        "QM5_41196_qs-kama-trend-xau-opt",
    ) == compile_work_items.DL089_SIBLING_REPAIR_41196_RETRY_DIRECTORY
    assert compile_work_items._sibling_rebind_authorized(
        "QM5_41195_aa-vol-sma10-opt",
        compile_work_items.DL089_SIBLING_Q02_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._sibling_rebind_authorized(
        "QM5_41196_qs-kama-trend-xau-opt",
        compile_work_items.DL089_SIBLING_Q02_REPAIR_AUTHORITY,
    )
    assert compile_work_items._sibling_rebind_directory(
        compile_work_items.DL089_SIBLING_Q02_REPAIR_AUTHORITY,
        "QM5_41195_aa-vol-sma10-opt",
    ) == compile_work_items.DL089_SIBLING_Q02_REPAIR_DIRECTORY
    assert compile_work_items._sibling_rebind_directory(
        "router_ops_issue:wrong-task", "QM5_41195_aa-vol-sma10-opt"
    ) is None


def test_dl089_sibling_rebind_setfile_requires_unbound_fixed_risk_neutral_inputs(
    tmp_path: Path,
) -> None:
    path = tmp_path / "current.set"
    path.write_text(
        "; build_hash: pending\n"
        "RISK_FIXED=1000\nRISK_PERCENT=0\n"
        "opt_pp_buy1=0\nopt_pp_buy2=0\nopt_pp_buy3=0\n"
        "opt_pp_sell1=0\nopt_pp_sell2=0\nopt_pp_sell3=0\n",
        encoding="utf-8",
    )

    assert compile_work_items._sibling_rebind_setfile_check(path) == (True, [])
    original = path.read_bytes()
    path.write_text(path.read_text(encoding="utf-8").replace(
        "opt_pp_sell3=0", "opt_pp_sell3=1"
    ), encoding="utf-8")
    valid, findings = compile_work_items._sibling_rebind_setfile_check(path)
    assert valid is False
    assert "SIBLING_REBIND_NEUTRAL_INPUT_INVALID:opt_pp_sell3" in findings
    assert original != path.read_bytes()


def test_q09_requal8_repair_authority_is_exact_and_does_not_require_pp_inputs(
    tmp_path: Path,
) -> None:
    label = "QM5_41215_pre-fomc-drift-ndx-requal8"
    authority = compile_work_items.Q09_REQUAL8_BUILD_REPAIR_AUTHORITY
    retry = compile_work_items.Q09_REQUAL8_41215_RETRY_AUTHORITY

    assert compile_work_items._sibling_rebind_authorized(label, authority)
    assert compile_work_items._source_repair_authorized(label, authority)
    assert compile_work_items._sibling_rebind_directory(authority, label) == (
        compile_work_items.Q09_REQUAL8_BUILD_REPAIR_DIRECTORY
    )
    assert compile_work_items._sibling_rebind_authorized(label, retry)
    assert compile_work_items._source_repair_authorized(label, retry)
    assert compile_work_items._sibling_rebind_directory(retry, label) == (
        compile_work_items.Q09_REQUAL8_41215_RETRY_DIRECTORY
    )
    assert not compile_work_items._sibling_rebind_authorized(
        "QM5_41214_wrong", authority
    )
    assert not compile_work_items._sibling_rebind_authorized(
        "QM5_41216_grimes-nested-pb-v2-requal8", retry
    )

    path = tmp_path / "current.set"
    path.write_text(
        "; build_hash: pending\nRISK_FIXED=1000\nRISK_PERCENT=0\n",
        encoding="utf-8",
    )
    assert compile_work_items._sibling_rebind_setfile_check(
        path, authority
    ) == (True, [])
    assert compile_work_items._sibling_rebind_setfile_check(
        path, retry
    ) == (True, [])


def test_qm5_1538_compile_fail_repair_authority_is_failure_and_hash_bound() -> None:
    label = compile_work_items.QM5_1538_COMPILE_FAIL_REPAIR_EA_LABEL
    predecessor_id = (
        compile_work_items.QM5_1538_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
    )
    expected_failures = list(
        compile_work_items.QM5_1538_COMPILE_FAIL_FAILURE_CLASSES
    )
    predecessor_payload = {
        "ea_label": label,
        "mq5_sha256": (
            compile_work_items.QM5_1538_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        ),
        "verdict_reason": ";".join(expected_failures),
        "compile_result": {
            "compile_result": "FAIL",
            "build_check_result": "FAIL",
            "failure_classes": expected_failures,
        },
    }
    inventory = {
        "work_rows": {
            "1538": [{
                "id": predecessor_id,
                "phase": compile_work_items.COMPILE_EA_PHASE,
                "status": "failed",
                "verdict": "COMPILE_FAIL",
                "payload_json": json.dumps(predecessor_payload),
            }],
        },
    }
    arguments = {
        "ea_id": "1538",
        "source_sha": (
            compile_work_items.QM5_1538_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        ),
        "inventory": inventory,
    }

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_1538_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_1539_unrelated",
        compile_work_items.QM5_1538_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "governed_compile_fail:wrong-row",
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_1538_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "source_sha": "0" * 64},
    )
    changed_inventory = json.loads(json.dumps(inventory))
    changed_inventory["work_rows"]["1538"][0]["status"] = "done"
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_1538_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "inventory": changed_inventory},
    )


def test_qm5_41201_compile_fail_repair_authority_is_failure_and_hash_bound() -> None:
    label = compile_work_items.QM5_41201_COMPILE_FAIL_REPAIR_EA_LABEL
    predecessor_id = (
        compile_work_items.QM5_41201_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
    )
    predecessor_payload = {
        "ea_label": label,
        "mq5_sha256": (
            compile_work_items.QM5_41201_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        ),
        "verdict_reason": "EA_INDICATOR_BUFFER_UNBOUNDED",
        "compile_result": {
            "compile_result": "PASS",
            "build_check_result": "FAIL",
            "failure_classes": ["EA_INDICATOR_BUFFER_UNBOUNDED"],
        },
    }
    inventory = {
        "work_rows": {
            "41201": [{
                "id": predecessor_id,
                "phase": compile_work_items.COMPILE_EA_PHASE,
                "status": "failed",
                "verdict": "COMPILE_FAIL",
                "payload_json": json.dumps(predecessor_payload),
            }],
        },
    }
    arguments = {
        "ea_id": "41201",
        "source_sha": (
            compile_work_items.QM5_41201_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        ),
        "inventory": inventory,
    }

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41201_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41202_unrelated",
        compile_work_items.QM5_41201_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "governed_compile_fail:wrong-row",
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41201_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "source_sha": "0" * 64},
    )
    changed_inventory = json.loads(json.dumps(inventory))
    changed_inventory["work_rows"]["41201"][0]["payload_json"] = json.dumps(
        {**predecessor_payload, "verdict_reason": "OTHER"}
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41201_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "inventory": changed_inventory},
    )


def test_qm5_41223_compile_fail_repair_authority_is_failure_and_hash_bound() -> None:
    label = compile_work_items.QM5_41223_COMPILE_FAIL_REPAIR_EA_LABEL
    predecessor_id = (
        compile_work_items.QM5_41223_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
    )
    predecessor_payload = {
        "ea_label": label,
        "mq5_sha256": (
            compile_work_items.QM5_41223_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        ),
        "verdict_reason": "EA_INDICATOR_BUFFER_UNBOUNDED",
        "compile_result": {
            "compile_result": "PASS",
            "build_check_result": "FAIL",
            "failure_classes": ["EA_INDICATOR_BUFFER_UNBOUNDED"],
        },
    }
    inventory = {
        "work_rows": {
            "41223": [{
                "id": predecessor_id,
                "phase": compile_work_items.COMPILE_EA_PHASE,
                "status": "failed",
                "verdict": "COMPILE_FAIL",
                "payload_json": json.dumps(predecessor_payload),
            }],
        },
    }
    arguments = {
        "ea_id": "41223",
        "source_sha": (
            compile_work_items.QM5_41223_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        ),
        "inventory": inventory,
    }

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41223_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41222_unrelated",
        compile_work_items.QM5_41223_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "governed_compile_fail:wrong-row",
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41223_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "source_sha": "0" * 64},
    )
    changed_inventory = json.loads(json.dumps(inventory))
    changed_inventory["work_rows"]["41223"][0]["payload_json"] = json.dumps(
        {**predecessor_payload, "verdict_reason": "OTHER"}
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41223_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "inventory": changed_inventory},
    )


def test_qm5_41228_compile_fail_repair_authority_is_failure_and_hash_bound() -> None:
    label = compile_work_items.QM5_41228_COMPILE_FAIL_REPAIR_EA_LABEL
    predecessor_id = (
        compile_work_items.QM5_41228_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
    )
    predecessor_payload = {
        "ea_label": label,
        "mq5_sha256": (
            compile_work_items.QM5_41228_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        ),
        "verdict_reason": "EA_INDICATOR_BUFFER_UNBOUNDED",
        "compile_result": {
            "compile_result": "PASS",
            "build_check_result": "FAIL",
            "failure_classes": ["EA_INDICATOR_BUFFER_UNBOUNDED"],
        },
    }
    inventory = {
        "work_rows": {
            "41228": [{
                "id": predecessor_id,
                "phase": compile_work_items.COMPILE_EA_PHASE,
                "status": "failed",
                "verdict": "COMPILE_FAIL",
                "payload_json": json.dumps(predecessor_payload),
            }],
        },
    }
    arguments = {
        "ea_id": "41228",
        "source_sha": (
            compile_work_items.QM5_41228_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        ),
        "inventory": inventory,
    }

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41228_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41227_unrelated",
        compile_work_items.QM5_41228_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "governed_compile_fail:wrong-row",
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41228_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "source_sha": "0" * 64},
    )
    changed_inventory = json.loads(json.dumps(inventory))
    changed_inventory["work_rows"]["41228"][0]["payload_json"] = json.dumps(
        {**predecessor_payload, "verdict_reason": "OTHER"}
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41228_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "inventory": changed_inventory},
    )


def test_qm5_41203_compile_fail_repair_authority_is_failure_and_hash_bound() -> None:
    label = compile_work_items.QM5_41203_COMPILE_FAIL_REPAIR_EA_LABEL
    predecessor_id = (
        compile_work_items.QM5_41203_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
    )
    failure_classes = [
        "EA_Q08_MAE_HOOK_MISSING",
        "EA_INDICATOR_BUFFER_UNBOUNDED",
    ]
    predecessor_payload = {
        "ea_label": label,
        "mq5_sha256": (
            compile_work_items.QM5_41203_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        ),
        "verdict_reason": ";".join(failure_classes),
        "compile_result": {
            "compile_result": "PASS",
            "build_check_result": "FAIL",
            "failure_classes": failure_classes,
        },
    }
    inventory = {
        "work_rows": {
            "41203": [{
                "id": predecessor_id,
                "phase": compile_work_items.COMPILE_EA_PHASE,
                "status": "failed",
                "verdict": "COMPILE_FAIL",
                "payload_json": json.dumps(predecessor_payload),
            }],
        },
    }
    arguments = {
        "ea_id": "41203",
        "source_sha": (
            compile_work_items.QM5_41203_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        ),
        "inventory": inventory,
    }

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41203_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41202_unrelated",
        compile_work_items.QM5_41203_COMPILE_FAIL_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "governed_compile_fail:wrong-row",
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41203_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "source_sha": "0" * 64},
    )
    changed_inventory = json.loads(json.dumps(inventory))
    changed_inventory["work_rows"]["41203"][0]["payload_json"] = json.dumps(
        {**predecessor_payload, "verdict_reason": "OTHER"}
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41203_COMPILE_FAIL_REPAIR_AUTHORITY,
        **{**arguments, "inventory": changed_inventory},
    )


def test_qm5_41207_compile_advisory_repair_is_receipt_and_hash_bound(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    label = compile_work_items.QM5_41207_COMPILE_ADVISORY_REPAIR_EA_LABEL
    predecessor_id = (
        compile_work_items.QM5_41207_COMPILE_ADVISORY_REPAIR_PREDECESSOR_ID
    )
    evidence_path = tmp_path / "compile_evidence.json"
    evidence_path.write_text(
        json.dumps({
            "build_check_result": "PASS",
            "compile_result": "PASS",
            "build_check_output_tail": (
                "WARNING: BUILD_CHECK_DWX_ADVISORY_DWX_SPREAD_FAILCLOSED\n"
                "build_check.warnings=1\n"
            ),
        }),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        compile_work_items,
        "sha256_file",
        lambda _path: (
            compile_work_items.QM5_41207_COMPILE_ADVISORY_EVIDENCE_SHA256
        ),
    )
    predecessor_payload = {
        "ea_label": label,
        "mq5_sha256": (
            compile_work_items.QM5_41207_COMPILE_ADVISORY_REJECTED_SOURCE_SHA256
        ),
        "verdict_reason": "COMPILE_ARTIFACT_READY",
        "compile_result": {
            "compile_result": "PASS",
            "build_check_result": "PASS",
            "failure_classes": [],
            "success": True,
            "ex5_sha256": (
                compile_work_items.QM5_41207_COMPILE_ADVISORY_PREDECESSOR_EX5_SHA256
            ),
        },
    }
    inventory = {
        "work_rows": {
            "41207": [{
                "id": predecessor_id,
                "phase": compile_work_items.COMPILE_EA_PHASE,
                "status": "done",
                "verdict": "COMPILE_OK",
                "evidence_path": str(evidence_path),
                "ex5_sha256": (
                    compile_work_items.QM5_41207_COMPILE_ADVISORY_PREDECESSOR_EX5_SHA256
                ),
                "payload_json": json.dumps(predecessor_payload),
            }],
        },
    }
    arguments = {
        "ea_id": "41207",
        "source_sha": (
            compile_work_items.QM5_41207_COMPILE_ADVISORY_REPAIRED_SOURCE_SHA256
        ),
        "inventory": inventory,
    }

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41207_COMPILE_ADVISORY_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41208_unrelated",
        compile_work_items.QM5_41207_COMPILE_ADVISORY_REPAIR_AUTHORITY,
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "governed_compile_advisory:wrong-row",
        **arguments,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41207_COMPILE_ADVISORY_REPAIR_AUTHORITY,
        **{**arguments, "source_sha": "0" * 64},
    )
    changed_inventory = json.loads(json.dumps(inventory))
    changed_inventory["work_rows"]["41207"][0]["payload_json"] = json.dumps(
        {**predecessor_payload, "verdict_reason": "OTHER"}
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_41207_COMPILE_ADVISORY_REPAIR_AUTHORITY,
        **{**arguments, "inventory": changed_inventory},
    )


def test_dl089_matrix_dispatch_repair_authority_is_exact_label_bound() -> None:
    allowed = compile_work_items.DL089_MATRIX_DISPATCH_REPAIR_EA_LABELS

    assert allowed == {
        "QM5_41161_tv-mon-ls-opt",
        "QM5_41162_ohlc-daily-squeeze-reversal-d1-opt",
    }
    for label in allowed:
        assert compile_work_items._source_repair_authorized(
            label,
            compile_work_items.DL089_MATRIX_DISPATCH_REPAIR_AUTHORITY,
        )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41163_williams-18ma-outside-bar-entry-d1-opt",
        compile_work_items.DL089_MATRIX_DISPATCH_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41161_tv-mon-ls-opt",
        "router_ops_issue:wrong-task",
    )


def test_dl089_pilot_binary_recovery_authority_is_exact_cohort_bound() -> None:
    allowed = compile_work_items.DL089_PILOT_BINARY_RECOVERY_EA_LABELS

    assert allowed == {
        "QM5_41161_tv-mon-ls-opt",
        "QM5_41162_ohlc-daily-squeeze-reversal-d1-opt",
        "QM5_41163_williams-18ma-outside-bar-entry-d1-opt",
    }
    for label in allowed:
        assert compile_work_items._source_repair_authorized(
            label,
            compile_work_items.DL089_PILOT_BINARY_RECOVERY_AUTHORITY,
        )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41164_unrelated",
        compile_work_items.DL089_PILOT_BINARY_RECOVERY_AUTHORITY,
    )


def test_dl089_pilot_missing_compile_ok_binary_can_append_recovery(
    tmp_path: Path, monkeypatch,
) -> None:
    label = "QM5_1001_williams-18ma-outside-bar-entry-d1-opt"
    repo, root = _fixture(tmp_path, [label])
    monkeypatch.setattr(
        compile_work_items,
        "DL089_PILOT_BINARY_RECOVERY_EA_LABELS",
        frozenset({label}),
    )
    first = compile_work_items.enqueue_compile_eas(root, repo, [label])
    first_id = first["enqueued"][0]["work_item_id"]
    binary = repo / "framework" / "EAs" / label / f"{label}.ex5"
    binary.write_bytes(b"quarantined binary fixture")
    binary_sha = compile_work_items.sha256_file(binary)
    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE work_items SET status='done',verdict='COMPILE_OK',ex5_sha256=? WHERE id=?",
            (binary_sha, first_id),
        )
        conn.commit()
    binary.unlink()

    recovery = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [label],
        source_repair_authority=(
            compile_work_items.DL089_PILOT_BINARY_RECOVERY_AUTHORITY
        ),
    )

    assert recovery["ok"] is True
    assert recovery["enqueued_count"] == 1
    assert recovery["enqueued"][0]["work_item_id"] != first_id
    assert recovery["refused"] == []


def test_qm5_11465_q02_binary_recovery_authority_is_exact_label_bound() -> None:
    label = "QM5_11465_suhr-bank-trading-stop-run-fade-h1"

    assert compile_work_items.QM5_11465_Q02_BINARY_RECOVERY_EA_LABELS == {label}
    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_11465_Q02_BINARY_RECOVERY_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_11466_unrelated-h1",
        compile_work_items.QM5_11465_Q02_BINARY_RECOVERY_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_ops_issue:wrong-task",
    )


def test_qm5_11465_missing_compile_ok_binary_can_append_recovery(
    tmp_path: Path,
    monkeypatch,
) -> None:
    label = "QM5_1001_suhr-bank-trading-stop-run-fade-h1"
    repo, root = _fixture(tmp_path, [label])
    monkeypatch.setattr(
        compile_work_items,
        "QM5_11465_Q02_BINARY_RECOVERY_EA_LABELS",
        frozenset({label}),
    )
    first = compile_work_items.enqueue_compile_eas(root, repo, [label])
    first_id = first["enqueued"][0]["work_item_id"]
    binary = repo / "framework" / "EAs" / label / f"{label}.ex5"
    binary.write_bytes(b"lost binary fixture")
    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE work_items SET status='done',verdict='COMPILE_OK',ex5_sha256=? WHERE id=?",
            (compile_work_items.sha256_file(binary), first_id),
        )
        conn.commit()
    binary.unlink()

    recovery = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [label],
        source_repair_authority=(
            compile_work_items.QM5_11465_Q02_BINARY_RECOVERY_AUTHORITY
        ),
    )

    assert recovery["ok"] is True
    assert recovery["enqueued_count"] == 1
    assert recovery["enqueued"][0]["work_item_id"] != first_id
    assert recovery["refused"] == []


def test_qm5_41164_41191_compile_fail_repair_authority_is_exact_label_bound() -> None:
    allowed = compile_work_items.QM5_41164_41191_COMPILE_FAIL_REPAIR_EA_LABELS

    assert allowed == {
        "QM5_41164_xauxag-mrepmedian-rv",
        "QM5_41165_wti-mrobust3-agree-tr",
        "QM5_41166_xauxag-mrobust3-agree-rv",
        "QM5_41168_xauxag-mcoxstuart-rv",
        "QM5_41172_wti-mpettitt-shift-tr",
        "QM5_41191_wti-samecal-srank",
    }
    for label in allowed:
        assert compile_work_items._source_repair_authorized(
            label,
            compile_work_items.QM5_41164_41191_COMPILE_FAIL_REPAIR_AUTHORITY,
        )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41163_williams-18ma-outside-bar-entry-d1-opt",
        compile_work_items.QM5_41164_41191_COMPILE_FAIL_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_41164_xauxag-mrepmedian-rv",
        "router_ops_issue:wrong-task",
    )


def test_qm5_35005_review_repair_authority_is_exact_label_bound() -> None:
    label = "QM5_35005_sma-crossover-pullback-system"

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_35005_REVIEW_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_35006_unrelated",
        compile_work_items.QM5_35005_REVIEW_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_review_ea:wrong-task",
    )


def test_qm5_36005_review_repair_authority_is_exact_label_bound() -> None:
    label = "QM5_36005_nnfx-coral-trendlord-woodies-harvester"

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_36005_REVIEW_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_36004_nnfx-ssl-hma-trend-system",
        compile_work_items.QM5_36005_REVIEW_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_review_ea:wrong-task",
    )


def test_review_rework_source_repair_authority_is_exact_label_bound() -> None:
    authorities = compile_work_items.REVIEW_REWORK_SOURCE_REPAIR_AUTHORITIES

    assert authorities == {
        "QM5_9468_connors-rsi4-3day-d1": (
            "router_review_ea:cd6442dd-4ad9-4845-862a-2ef6e3ec0172"
        ),
        "QM5_9909_bandy-lrchannel-breakout-trend": (
            "router_review_ea:d6ea3abe-d44b-4861-b466-475a28899eaa"
        ),
        "QM5_41011_tokyo-london-bank-flow-handover": (
            "router_review_ea:86e63523-90c7-47e7-bd41-b220e70042e7"
        ),
        "QM5_41229_wti-samecal-trimean5": (
            "router_review_ea:0c39bc3c-df80-41fd-9ec1-5b7be49129dd"
        ),
    }
    for label, authority in authorities.items():
        assert compile_work_items._source_repair_authorized(label, authority)
        assert not compile_work_items._source_repair_authorized(
            label, "router_review_ea:wrong-task"
        )
    assert not compile_work_items._source_repair_authorized(
        "QM5_9469_unrelated-d1",
        compile_work_items.REVIEW_REWORK_SOURCE_REPAIR_AUTHORITY,
    )


def test_qm5_38006_review_repair_authority_is_exact_label_bound() -> None:
    label = "QM5_38006_codetrading-doji-hammer-pivot-rejection"

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.QM5_38006_REVIEW_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_38005_codetrading-ascending-triangle-breakout",
        compile_work_items.QM5_38006_REVIEW_REPAIR_AUTHORITY,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_ops_issue:wrong-task",
    )


def test_hma_cata_requal_authority_is_exact_and_artifact_hash_bound(
    tmp_path: Path, monkeypatch,
) -> None:
    label = "QM5_10251_tv-nova-rev"
    repo = tmp_path / "repo"
    artifact_paths = [
        "decisions/owner.md",
        "docs/ops/evidence/census.csv",
        "framework/include/QM/QM_Indicators.mqh",
    ]
    expected: dict[str, str] = {}
    for index, relative_path in enumerate(artifact_paths):
        artifact = repo / relative_path
        artifact.parent.mkdir(parents=True, exist_ok=True)
        artifact.write_text(f"artifact-{index}\n", encoding="utf-8")
        expected[relative_path] = compile_work_items.sha256_file(artifact)
    monkeypatch.setattr(
        compile_work_items, "HMA_CATA_REQUAL_ARTIFACT_SHA256", expected
    )

    assert compile_work_items._source_repair_authorized(
        label,
        compile_work_items.HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY,
        repo_root=repo,
    )
    assert not compile_work_items._source_repair_authorized(
        "QM5_10252_unrelated",
        compile_work_items.HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY,
        repo_root=repo,
    )
    assert not compile_work_items._source_repair_authorized(
        label,
        "router_ops_issue:wrong-task",
        repo_root=repo,
    )

    (repo / artifact_paths[-1]).write_text("changed\n", encoding="utf-8")
    assert not compile_work_items._source_repair_authorized(
        label,
        compile_work_items.HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY,
        repo_root=repo,
    )


def test_hma_cata_requal_payload_binds_owner_artifacts_and_worker_recheck(
    tmp_path: Path, monkeypatch,
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])
    monkeypatch.setattr(
        compile_work_items, "HMA_CATA_REQUAL_EA_LABELS", frozenset({label})
    )
    artifact = repo / "framework" / "include" / "QM" / "QM_Indicators.mqh"
    artifact.parent.mkdir(parents=True, exist_ok=True)
    artifact.write_text("// fixed HMA\n", encoding="utf-8")
    expected = {
        "framework/include/QM/QM_Indicators.mqh": (
            compile_work_items.sha256_file(artifact)
        )
    }
    monkeypatch.setattr(
        compile_work_items, "HMA_CATA_REQUAL_ARTIFACT_SHA256", expected
    )
    # Make this a source repair rather than an ordinary first compile.
    source = repo / "framework" / "EAs" / label / f"{label}.mq5"
    (source.parent / f"{label}.ex5").write_bytes(b"historical binary")

    result = compile_work_items.enqueue_compile_eas(
        root,
        repo,
        [label],
        source_repair_authority=(
            compile_work_items.HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY
        ),
    )

    assert result["enqueued_count"] == 1
    work_item_id = result["enqueued"][0]["work_item_id"]
    with farmctl.connect(root) as conn:
        raw_payload = conn.execute(
            "SELECT payload_json FROM work_items WHERE id=?", (work_item_id,)
        ).fetchone()[0]
    payload = json.loads(raw_payload)
    assert payload["owner_decision_id"] == "OWNER-DEC-HMA-CATA"
    assert payload["requalification_new_identity_from_phase"] == "Q02"
    assert payload["source_repair_artifact_bindings"] == [
        {"path": next(iter(expected)), "sha256": next(iter(expected.values()))}
    ]

    worker_recheck = compile_work_items.classify_candidate(
        root,
        repo,
        label,
        compile_work_items._inventory(root, repo),
        current_work_item_id=work_item_id,
        source_repair_authority=(
            compile_work_items.HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY
        ),
    )
    assert worker_recheck["eligible"] is True
    assert worker_recheck["source_repair_authorized"] is True


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


def test_candidate_recheck_allows_exact_build_binding_retry_chain(
    tmp_path: Path,
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])
    source_sha = compile_work_items.sha256_file(
        repo / "framework" / "EAs" / label / f"{label}.mq5"
    )
    now = farmctl.utc_now()
    r11_payload = {
        "ea_label": label,
        "mq5_sha256": source_sha,
        "repair_handler": compile_work_items.R11_INCIDENT_HANDLER,
        "verdict_reason": compile_work_items.R11_INCIDENT_REASON,
    }
    candidate_failure_payload = {
        "ea_label": label,
        "mq5_sha256": source_sha,
        "revival_contract_version": compile_work_items.R11_REVIVAL_CONTRACT_VERSION,
        "revival_authority_task_id": compile_work_items.R11_REVIVAL_AUTHORITY_TASK_ID,
        "revival_reason": compile_work_items.R11_REVIVAL_REASON,
        "revival_source_mq5_sha256": source_sha,
        "revived_from_work_item_id": "r11-old",
        "append_only_revival": True,
        "verdict_reason": compile_work_items.COMPILE_RECHECK_FAILURE_CLASS,
        "compile_result": {
            "failure_classes": [compile_work_items.COMPILE_RECHECK_FAILURE_CLASS]
        },
    }
    binding_failure_payload = {
        **candidate_failure_payload,
        "compile_retry_contract_version": (
            compile_work_items.COMPILE_RECHECK_RETRY_CONTRACT_VERSION
        ),
        "compile_retry_authority_task_id": (
            compile_work_items.COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID
        ),
        "retry_of_work_item_id": "candidate-failed",
        "append_only_retry": True,
        "verdict_reason": compile_work_items.COMPILE_BINDING_FAILURE_CLASS,
        "compile_result": {
            "failure_classes": [compile_work_items.COMPILE_BINDING_FAILURE_CLASS]
        },
    }
    binding_retry_payload = {
        **candidate_failure_payload,
        "compile_retry_contract_version": (
            compile_work_items.COMPILE_BINDING_RETRY_CONTRACT_VERSION
        ),
        "compile_retry_authority_task_id": (
            compile_work_items.COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID
        ),
        "retry_of_work_item_id": "binding-failed",
        "append_only_retry": True,
    }
    with farmctl.connect(root) as conn:
        for item_id, verdict, status, payload in (
            ("r11-old", "INVALID", "failed", r11_payload),
            ("candidate-failed", "COMPILE_FAIL", "failed", candidate_failure_payload),
            ("binding-failed", "COMPILE_FAIL", "failed", binding_failure_payload),
            ("binding-retry", None, "active", binding_retry_payload),
        ):
            conn.execute(
                "INSERT INTO work_items "
                "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,"
                "claimed_by,payload_json,created_at,updated_at) "
                "VALUES (?,'compile','COMPILE_EA','QM5_1001','','',?,?,0,?,?,?,?)",
                (
                    item_id,
                    status,
                    verdict,
                    "T5" if status == "active" else None,
                    json.dumps(payload),
                    now,
                    now,
                ),
            )
        conn.commit()

    inventory = compile_work_items._inventory(root, repo)
    sanctioned = compile_work_items._sanctioned_compile_predecessor_ids(
        binding_retry_payload, inventory, "1001"
    )
    candidate = compile_work_items.classify_candidate(
        root,
        repo,
        label,
        inventory,
        current_work_item_id="binding-retry",
        sanctioned_predecessor_ids=sanctioned,
    )

    assert sanctioned == {"r11-old", "candidate-failed", "binding-failed"}
    assert candidate["eligible"] is True

    binding_failure_payload["verdict_reason"] = "DIFFERENT_FAILURE"
    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id='binding-failed'",
            (json.dumps(binding_failure_payload),),
        )
        conn.commit()
    refused_inventory = compile_work_items._inventory(root, repo)
    assert compile_work_items._sanctioned_compile_predecessor_ids(
        binding_retry_payload, refused_inventory, "1001"
    ) == set()


def _dl089_fixture(tmp_path: Path, ea_id: str, label: str) -> tuple[Path, Path]:
    """Build a fixture EA that already has an .ex5, historical work_items, and a
    bound setfile hash - the exact "already live" shape the DL-089 force-rebuild
    bypass exists for."""
    repo = tmp_path / "repo"
    root = tmp_path / "farm"
    slug = label.split("_", 2)[2]
    _write_csv(
        repo / "framework" / "registry" / "ea_id_registry.csv",
        ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"],
        [{
            "ea_id": ea_id, "slug": slug, "strategy_id": f"SRC_{ea_id}",
            "status": "active", "owner": "Research", "created_at": "2026-08-01",
        }],
    )
    _write_csv(
        repo / "framework" / "registry" / "magic_numbers.csv",
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic",
         "reserved_at", "reserved_by", "status"],
        [{
            "ea_id": ea_id, "ea_slug": slug, "symbol_slot": "0",
            "symbol": "EURUSD.DWX", "magic": str(int(ea_id) * 10000),
            "reserved_at": "2026-08-01", "reserved_by": "test", "status": "active",
        }],
    )
    ea_dir = repo / "framework" / "EAs" / label
    ea_dir.mkdir(parents=True)
    (ea_dir / f"{label}.mq5").write_text(
        "#property strict\ninput double RISK_FIXED=1000.0;\n", encoding="utf-8",
    )
    (ea_dir / f"{label}.ex5").write_bytes(b"stale-binary")
    setfile_dir = ea_dir / "sets"
    setfile_dir.mkdir()
    (setfile_dir / f"{label}_EURUSD.DWX_H1_backtest.set").write_text(
        "; build_hash: " + "b" * 64 + "\n", encoding="utf-8",
    )
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,"
            "payload_json,created_at,updated_at) "
            "VALUES ('old-q02-row','backtest','Q02',?,'EURUSD.DWX','x.set','done','PASS',0,'{}',?,?)",
            (f"QM5_{ea_id}", now, now),
        )
        conn.commit()
    return repo, root


def _write_owner_priority_tracks(
    repo: Path, ea_id: str, owner_reference: str
) -> None:
    document = {
        "schema_version": "qm.owner-priority-tracks/v1",
        "entries": [{"ea_id": f"QM5_{ea_id}", "owner_reference": owner_reference}],
    }
    path = repo / "framework" / "registry" / "owner_priority_tracks.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(document), encoding="utf-8")


def test_dl089_force_rebuild_bypasses_existing_artifacts_and_history(
    tmp_path: Path,
) -> None:
    ea_id = next(iter(compile_work_items.DL089_FORCE_REBUILD_EA_IDS))
    label = f"QM5_{ea_id}_dl089-fixture-h1"
    repo, root = _dl089_fixture(tmp_path, ea_id, label)
    _write_owner_priority_tracks(
        repo, ea_id, compile_work_items.DL089_FORCE_REBUILD_OWNER_REFERENCE
    )

    allowlist = compile_work_items.dl089_force_rebuild_allowlist(repo)
    assert ea_id in allowlist

    inventory = compile_work_items._inventory(root, repo)
    candidate = compile_work_items.classify_candidate(
        root, repo, label, inventory, force_rebuild_ea_ids=allowlist,
    )
    assert candidate["eligible"] is True
    assert candidate["force_rebuild_authorized"] is True
    assert set(candidate["force_rebuild_waived_reasons"]) == {
        "EX5_ALREADY_PRESENT", "WORK_ITEMS_EXIST", "BOUND_SETFILE_HASH_EXISTS",
    }

    applied = compile_work_items.enqueue_compile_eas(root, repo, [label])
    assert applied["enqueued_count"] == 1
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT payload_json FROM work_items WHERE ea_id=? AND phase='COMPILE_EA'",
            (f"QM5_{ea_id}",),
        ).fetchone()
    payload = json.loads(row[0])
    assert payload["force_rebuild"] is True
    assert payload["force_rebuild_owner_reference"] == (
        compile_work_items.DL089_FORCE_REBUILD_OWNER_REFERENCE
    )


def test_dl089_force_rebuild_fails_closed_without_owner_priority_tracks_entry(
    tmp_path: Path,
) -> None:
    ea_id = next(iter(compile_work_items.DL089_FORCE_REBUILD_EA_IDS))
    label = f"QM5_{ea_id}_dl089-fixture-h1"
    repo, root = _dl089_fixture(tmp_path, ea_id, label)
    # No owner_priority_tracks.json entry written: the hardcoded id alone must
    # not be enough to unlock the bypass.

    allowlist = compile_work_items.dl089_force_rebuild_allowlist(repo)
    assert ea_id not in allowlist

    inventory = compile_work_items._inventory(root, repo)
    candidate = compile_work_items.classify_candidate(
        root, repo, label, inventory, force_rebuild_ea_ids=allowlist,
    )
    assert candidate["eligible"] is False
    assert candidate["force_rebuild_authorized"] is False
    assert "EX5_ALREADY_PRESENT" in candidate["reasons"]


def test_dl089_force_rebuild_never_waives_structural_guards(tmp_path: Path) -> None:
    ea_id = next(iter(compile_work_items.DL089_FORCE_REBUILD_EA_IDS))
    label = f"QM5_{ea_id}_dl089-fixture-h1"
    repo, root = _dl089_fixture(tmp_path, ea_id, label)
    _write_owner_priority_tracks(
        repo, ea_id, compile_work_items.DL089_FORCE_REBUILD_OWNER_REFERENCE
    )
    # Retire the active magic row: a structural guard the bypass must never waive.
    magic_path = repo / "framework" / "registry" / "magic_numbers.csv"
    _write_csv(
        magic_path,
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic",
         "reserved_at", "reserved_by", "status"],
        [{
            "ea_id": ea_id, "ea_slug": label.split("_", 2)[2], "symbol_slot": "0",
            "symbol": "EURUSD.DWX", "magic": str(int(ea_id) * 10000),
            "reserved_at": "2026-08-01", "reserved_by": "test", "status": "retired",
        }],
    )

    allowlist = compile_work_items.dl089_force_rebuild_allowlist(repo)
    inventory = compile_work_items._inventory(root, repo)
    candidate = compile_work_items.classify_candidate(
        root, repo, label, inventory, force_rebuild_ea_ids=allowlist,
    )
    assert candidate["eligible"] is False
    assert candidate["force_rebuild_authorized"] is True
    assert "ACTIVE_MAGIC_ROWS_MISSING" in candidate["reasons"]
    assert "EX5_ALREADY_PRESENT" not in candidate["reasons"]


def test_mae_hook_force_rebuild_requires_exact_routed_owner_task(tmp_path: Path) -> None:
    repo, root = _fixture(tmp_path, ["QM5_1001_compile-fixture-h1"])
    del repo
    with farmctl.connect(root) as conn:
        conn.execute(
            "CREATE TABLE agent_tasks(id TEXT PRIMARY KEY, payload_json TEXT NOT NULL)"
        )
        conn.execute(
            """
            INSERT INTO agent_tasks(id,payload_json) VALUES (?,?)
            """,
            (
                compile_work_items.MAE_HOOK_FORCE_REBUILD_AUTHORITY_TASK_ID,
                json.dumps({
                    "title": "NOTFALL Template-Defekt: MAE-Hook reparieren",
                    "goal": "QM5_12947-12952 batch-reparieren",
                }),
            ),
        )
        conn.commit()

    assert compile_work_items.mae_hook_force_rebuild_allowlist(root) == (
        compile_work_items.MAE_HOOK_FORCE_REBUILD_EA_IDS
    )

    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE agent_tasks SET payload_json=? WHERE id=?",
            (
                json.dumps({"title": "unrelated", "goal": "QM5_12947-12952"}),
                compile_work_items.MAE_HOOK_FORCE_REBUILD_AUTHORITY_TASK_ID,
            ),
        )
        conn.commit()
    assert compile_work_items.mae_hook_force_rebuild_allowlist(root) == frozenset()


def test_candidate_refuses_unresolved_timeframe_before_enqueue(tmp_path: Path) -> None:
    label = "QM5_1001_compile-fixture"
    repo, root = _fixture(tmp_path, [label])

    inventory = compile_work_items._inventory(root, repo)
    candidate = compile_work_items.classify_candidate(root, repo, label, inventory)

    assert candidate["eligible"] is False
    assert "TIMEFRAME_UNRESOLVED" in candidate["reasons"]


def test_compile_output_boolean_receipt_is_strict() -> None:
    output = "\n".join(
        [
            "compile_one.include_mirror_atomic_replace=True",
            "compile_one.unrelated=truthy",
        ]
    )

    assert compile_work_items._output_bool(
        output, "compile_one.include_mirror_atomic_replace"
    ) is True
    assert compile_work_items._output_bool(output, "compile_one.unrelated") is None
    assert compile_work_items._output_bool(output, "compile_one.missing") is None


def test_compile_profile_stdlib_failure_is_persisted_as_infra_not_compile_fail(
    tmp_path: Path,
) -> None:
    label = "QM5_1001_compile-fixture-h1"
    repo, root = _fixture(tmp_path, [label])
    del repo
    now = farmctl.utc_now()
    evidence_path = tmp_path / "compile_evidence.json"
    evidence_path.write_text("{}", encoding="utf-8")
    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,claimed_by,payload_json,created_at,updated_at) "
            "VALUES ('compile-infra','compile','COMPILE_EA','QM5_1001','','','active',0,'T6','{}',?,?)",
            (now, now),
        )
        conn.commit()

    compile_work_items._complete_work_item(
        root,
        "compile-infra",
        "T6",
        evidence_path,
        {
            "success": False,
            "mq5_sha256": "3" * 64,
            "failure_classes": [
                "COMPILE_PROFILE_STDLIB_MISSING",
                "BUILD_CHECK_COMPILE_FAILED",
            ],
            "compile_result": "FAIL",
            "build_check_result": "FAIL",
            "setfile_count": 1,
        },
    )

    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status,verdict,payload_json,mq5_sha256 "
            "FROM work_items WHERE id='compile-infra'"
        ).fetchone()
    payload = json.loads(row["payload_json"])
    assert (row["status"], row["verdict"]) == ("failed", "INFRA_FAIL")
    assert row["mq5_sha256"] == "3" * 64
    assert payload["verdict_reason"] == "COMPILE_PROFILE_STDLIB_MISSING"
    assert payload["verdict_taxonomy"] == "infra"


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
