"""Unit tests for the Gate Manifest v4 activation tool.

The tool's steps are pure-ish functions so they can be exercised without a real
apply: manifest promotion is validated through the loader, the source flip is
run on sample text, the smoke evaluator is checked against expected/degraded
payloads, and the database migration runs against a tiny fixture DB built by
``farmctl.init_db`` in a temp dir.  ``--apply`` is never run.
"""

from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import activate_gate_manifest_v4 as act  # noqa: E402
import gate_manifest as gm  # noqa: E402
import farmctl  # noqa: E402

import pytest  # noqa: E402


# --------------------------------------------------------------------------- #
# Step 2 — promote
# --------------------------------------------------------------------------- #
def test_build_active_manifest_bytes_loads_as_active(tmp_path: Path) -> None:
    data = act.build_active_manifest_bytes()
    # LF-pinned, trailing newline.
    assert b"\r\n" not in data
    assert data.endswith(b"\n")

    probe = tmp_path / gm.V4_MANIFEST.name
    probe.write_bytes(data)
    manifest = gm.load_gate_manifest(probe)
    assert manifest.activation_state == "ACTIVE"
    assert manifest.schema_version == gm.SCHEMA_VERSION_V4


def test_built_manifest_carries_both_required_review_refs(tmp_path: Path) -> None:
    raw = json.loads(act.build_active_manifest_bytes().decode("utf-8"))
    guard = raw["extension_topology"]["activation_guard"]
    assert guard["state"] == "ACTIVE"
    assert guard["default_manifest_switch"] is True
    assert guard["activated_by"] == act.ACTIVATED_BY == "CLAUDE"
    assert guard["activated_at"] == act.ACTIVATION_DATE
    assert set(gm.V4_ACTIVATION_REVIEW_REFS).issubset(set(guard["review_refs"]))
    assert raw["status"] == "ACTIVE"


def test_built_manifest_only_changes_status_and_guard() -> None:
    draft = json.loads(act.V4_DRAFT_MANIFEST.read_text(encoding="utf-8"))
    built = json.loads(act.build_active_manifest_bytes().decode("utf-8"))
    for key in built:
        if key == "status":
            continue
        if key == "extension_topology":
            for sub in built[key]:
                if sub == "activation_guard":
                    continue
                assert built[key][sub] == draft[key][sub], sub
            continue
        assert built[key] == draft[key], key


# --------------------------------------------------------------------------- #
# Step 3 — flip
# --------------------------------------------------------------------------- #
SAMPLE_SOURCE = (
    "SCHEMA_VERSION = SCHEMA_VERSION_V3\n"
    "DEFAULT_MANIFEST = V3_MANIFEST\n"
    "OTHER = 1\n"
)


def test_flip_text_faithful_and_idempotent() -> None:
    flipped, changed = act._flip_text(SAMPLE_SOURCE)
    assert changed is True
    assert "DEFAULT_MANIFEST = V4_MANIFEST" in flipped
    assert "SCHEMA_VERSION = SCHEMA_VERSION_V4" in flipped
    assert "V3_MANIFEST" not in flipped.replace("SCHEMA_VERSION_V3", "")
    # Re-running is a no-op.
    again, changed_again = act._flip_text(flipped)
    assert changed_again is False
    assert again == flipped


def test_flip_text_rejects_ambiguous_anchor() -> None:
    doubled = SAMPLE_SOURCE + "DEFAULT_MANIFEST = V3_MANIFEST\n"
    with pytest.raises(RuntimeError, match="found 2 times"):
        act._flip_text(doubled)


def test_real_gate_manifest_has_exactly_one_flip_anchor() -> None:
    text = act.GATE_MANIFEST_PY.read_text(encoding="utf-8")
    for old, new in act.FLIP_SUBSTITUTIONS:
        assert text.count(old) + text.count(new) == 1, (old, new)


# --------------------------------------------------------------------------- #
# Step 3 — smoke evaluator
# --------------------------------------------------------------------------- #
def _good_smoke() -> dict:
    return {
        "schema": "qm.gate-manifest/v4",
        "active_version": "v4",
        "phase_order": [f"Q{n:02d}" for n in range(18)],
        "next_q14": None,
        "macro_q10": "2_OPTIMIERUNG",
        "macro_q15": "3_BUCHBEWERTUNG",
        "macro_q17": "3_BUCHBEWERTUNG",
        "label_q10_v3": "Q11 (v3:Q10)",
    }


def test_evaluate_smoke_accepts_expected_payload() -> None:
    assert act._evaluate_smoke(_good_smoke()) == []


@pytest.mark.parametrize(
    "mutate",
    [
        lambda d: d.update(schema="qm.gate-manifest/v3"),
        lambda d: d.update(active_version="v3"),
        lambda d: d.update(next_q14="Q15"),
        lambda d: d.update(label_q10_v3="Q10"),
        lambda d: d["phase_order"].append("Q18"),
        lambda d: d.update(macro_q15=None),
    ],
)
def test_evaluate_smoke_rejects_bad_payload(mutate) -> None:
    payload = _good_smoke()
    mutate(payload)
    assert act._evaluate_smoke(payload) != []


# --------------------------------------------------------------------------- #
# Step 4 — database migration
# --------------------------------------------------------------------------- #
def _fixture_db(root: Path) -> Path:
    farmctl.init_db(root)
    db = farmctl.db_path(root)
    conn = sqlite3.connect(str(db))
    try:
        conn.executemany(
            "INSERT INTO work_items"
            "(id,kind,phase,ea_id,symbol,setfile_path,status,payload_json,"
            "created_at,updated_at,gate_contract_version) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
            [
                ("wi-1", "backtest", "Q10", "QM5_1", "EURUSD.DWX", "s.set",
                 "pending", "{}", "2026-08-23T11:00:00Z", "2026-08-23T11:00:00Z", "v3"),
                ("wi-2", "backtest", "Q08", "QM5_2", "EURUSD.DWX", "s.set",
                 "pending", "{}", "2026-08-23T11:00:00Z", "2026-08-23T11:00:00Z", "v3"),
            ],
        )
        conn.commit()
    finally:
        conn.close()
    return db


def test_migrate_database_apply_backs_up_stamps_and_preserves_dependencies(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    db = _fixture_db(root)
    backup_dir = root / "backups"

    result = act.migrate_database(
        db,
        backup_dir=backup_dir,
        manifest_sha256="deadbeef",
        git_head="cafef00d",
        apply=True,
    )
    assert result.ok, result.lines
    # Backup exists and passed integrity.
    backups = list(backup_dir.glob("farm_state_pre_v4_*.sqlite"))
    assert len(backups) == 1
    assert result.data["dep_total_before"] == result.data["dep_total_after"]

    # Activation ledger row written.
    conn = sqlite3.connect(str(db))
    try:
        row = conn.execute(
            "SELECT contract_version, manifest_sha256, backup_path, git_head "
            "FROM gate_contract_activations"
        ).fetchone()
    finally:
        conn.close()
    assert row[0] == "v4"
    assert row[1] == "deadbeef"
    assert row[3] == "cafef00d"

    # Idempotent second run.
    second = act.migrate_database(
        db,
        backup_dir=backup_dir,
        manifest_sha256="deadbeef",
        git_head="cafef00d",
        apply=True,
    )
    assert second.ok
    assert second.data["counts_after"] == result.data["counts_after"]


def test_migrate_database_dry_run_uses_copy_and_leaves_live_db_untouched(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    db = _fixture_db(root)
    before_conn = act._open_ro(db)
    try:
        before = {
            "schema": before_conn.execute(
                "SELECT type,name,sql FROM sqlite_master ORDER BY type,name"
            ).fetchall(),
            "rows": before_conn.execute(
                "SELECT id,phase,status,verdict,gate_contract_version "
                "FROM work_items ORDER BY id"
            ).fetchall(),
        }
    finally:
        before_conn.close()
    scratch = tmp_path / "scratch"

    result = act.migrate_database(
        db,
        backup_dir=root / "backups",
        manifest_sha256="sha",
        git_head="head",
        apply=False,
        scratch_dir=scratch,
    )
    assert result.ok, result.lines
    # A WAL checkpoint may legitimately change physical bytes during a
    # read-only snapshot; the source's logical schema and rows must not change.
    after_conn = act._open_ro(db)
    try:
        after = {
            "schema": after_conn.execute(
                "SELECT type,name,sql FROM sqlite_master ORDER BY type,name"
            ).fetchall(),
            "rows": after_conn.execute(
                "SELECT id,phase,status,verdict,gate_contract_version "
                "FROM work_items ORDER BY id"
            ).fetchall(),
        }
    finally:
        after_conn.close()
    assert after == before
    assert (scratch / "farm_state_copy.sqlite").exists()
    # No live backup dir was populated in dry-run.
    assert not (root / "backups").exists()


def test_dependency_count_change_fails_closed(tmp_path: Path, monkeypatch) -> None:
    root = tmp_path / "farm"
    db = _fixture_db(root)

    # Simulate the (never-expected) case where the migration alters a dependency
    # row count: the tool must refuse rather than proceed.
    calls = {"n": 0}

    def _stats(conn: sqlite3.Connection):
        calls["n"] += 1
        return (0 if calls["n"] == 1 else 1), {}

    monkeypatch.setattr(act, "_dependency_stats", _stats)
    result = act.migrate_database(
        db,
        backup_dir=root / "backups",
        manifest_sha256="s",
        git_head="h",
        apply=True,
    )
    assert result.ok is False
    assert any("DEPENDENCY ROW COUNT CHANGED" in line for line in result.lines)


def test_cutover_plan_covers_all_open_meaning_changes_and_skips_terminal_rows() -> None:
    conn = sqlite3.connect(":memory:")
    try:
        conn.execute(
            "CREATE TABLE work_items ("
            "id TEXT PRIMARY KEY,phase TEXT,status TEXT,verdict TEXT,"
            "gate_contract_version TEXT)"
        )
        phase_map, _ = act._v4_cutover_maps()
        versions = ("legacy", "v2", "v3")
        for index, old_phase in enumerate(phase_map):
            conn.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?)",
                (
                    f"open-{index}", old_phase,
                    "active" if index % 2 else "pending", None,
                    versions[index % len(versions)],
                ),
            )
            conn.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?)",
                (f"done-{index}", old_phase, "done", "PASS", "v3"),
            )

        plan = act.pending_cutover_plan(conn)
        assert plan["blocked"] == []
        assert plan["dependencies"] == []
        assert {
            (row["old_phase"], row["new_phase"])
            for row in plan["work_items"]
        } == set(phase_map.items())
        assert all(row["work_item_id"].startswith("open-") for row in plan["work_items"])
    finally:
        conn.close()


def test_cutover_plan_refuses_to_relabel_bound_payload_provenance() -> None:
    conn = sqlite3.connect(":memory:")
    try:
        conn.execute(
            "CREATE TABLE work_items ("
            "id TEXT PRIMARY KEY,phase TEXT,status TEXT,verdict TEXT,"
            "gate_contract_version TEXT,payload_json TEXT)"
        )
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?)",
            (
                "historic-q14",
                "Q14",
                "pending",
                None,
                "v3",
                json.dumps({"phase": "Q14", "gate_contract_version": "v3"}),
            ),
        )

        plan = act.pending_cutover_plan(conn)

        assert plan["work_items"] == []
        assert plan["blocked"] == [
            {
                "work_item_id": "historic-q14",
                "old_phase": "Q14",
                "new_phase": "Q12",
                "old_version": "v3",
                "new_version": "v4",
                "status": "pending",
                "reason": (
                    "bound payload provenance requires append-only remint: "
                    "payload phase=Q14, payload version=v3"
                ),
            }
        ]
    finally:
        conn.close()


def test_pending_news_hold_and_dependency_rows_cut_over_append_only(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = farmctl.db_path(root)
    now = "2026-08-23T11:00:00Z"
    conn = sqlite3.connect(str(db))
    conn.row_factory = sqlite3.Row
    try:
        rows = (
            ("q08", "Q08", "done", "PASS", "v3"),
            ("pending-news", "Q09_NEWS", "pending", None, "v3"),
            ("done-news", "Q09_NEWS", "done", "CONFIG_LOCKED", "v3"),
            ("pending-incumbent", "Q10", "active", None, "v3"),
            ("done-incumbent", "Q10", "done", "PASS", "v3"),
        )
        for item_id, phase, status, verdict, version in rows:
            conn.execute(
                "INSERT INTO work_items"
                "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,"
                "payload_json,created_at,updated_at,gate_contract_version) "
                "VALUES(?,'backtest',?,'QM5_1','EURUSD.DWX','base.set',?,?,"
                "'{}',?,?,?)",
                (item_id, phase, status, verdict, now, now, version),
            )
        conn.execute(
            "INSERT INTO work_item_holds"
            "(work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at) "
            "VALUES('pending-news','Q09_AWAITING_SEALED_PLAN','fixture',1,0,?,?)",
            (now, now),
        )
        # Load a historical edge directly; its normal insert trigger is bound
        # to whichever manifest is active in this test process.
        conn.execute("DROP TRIGGER IF EXISTS trg_wid_validate_insert")
        conn.execute(
            "INSERT INTO work_item_dependencies VALUES(?,?,?,?,?,?)",
            (
                "pending-incumbent", "Q09_NEWS", "done-news", "a" * 64,
                '["CONFIG_LOCKED"]', now,
            ),
        )
        conn.commit()

        result = act.cutover_pending_rows(conn, apply=True)
        assert result.ok, result.lines
        rewritten = {
            row["id"]: (row["phase"], row["gate_contract_version"])
            for row in conn.execute(
                "SELECT id,phase,gate_contract_version FROM work_items"
            )
        }
        assert rewritten["pending-news"] == ("Q10_NEWS", "v4")
        assert rewritten["pending-incumbent"] == ("Q11", "v4")
        assert rewritten["done-news"] == ("Q09_NEWS", "v3")
        assert rewritten["done-incumbent"] == ("Q10", "v3")
        assert tuple(conn.execute(
            "SELECT hold_code,active FROM work_item_holds "
            "WHERE work_item_id='pending-news'"
        ).fetchone()) == ("Q09_AWAITING_SEALED_PLAN", 1)
        assert conn.execute(
            "SELECT dependency_role FROM work_item_dependencies "
            "WHERE child_work_item_id='pending-incumbent'"
        ).fetchone()[0] == "Q10_NEWS"
        logs = conn.execute(
            "SELECT work_item_id,old_phase,new_phase FROM gate_contract_cutover_log "
            "ORDER BY rowid"
        ).fetchall()
        assert [tuple(row) for row in logs] == [
            ("pending-incumbent", "Q10", "Q11"),
            ("pending-news", "Q09_NEWS", "Q10_NEWS"),
            ("pending-incumbent", "Q09_NEWS", "Q10_NEWS"),
        ]
        with pytest.raises(sqlite3.IntegrityError, match="append-only"):
            conn.execute("DELETE FROM gate_contract_cutover_log")

        # Under the v4 claimant contract the row remains held until the sealed
        # plan binding is present, then becomes selectable as Q10_NEWS.
        monkeypatch.setattr(farmctl, "_NEWS_PHASE", "Q10_NEWS")
        monkeypatch.setattr(farmctl, "_INSPECTION_ONLY_NEWS_ALIAS", "Q10")
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id='pending-news'",
            (json.dumps({
                "q09_binding_version": "q09-news-dispatch-binding/v1",
                "q09_run_plan_path": "plan.json",
                "q09_run_plan_file_sha256": "b" * 64,
                "q09_dispatch_binding_sha256": "c" * 64,
            }),),
        )
        conn.execute(
            "UPDATE work_item_holds SET active=0 WHERE work_item_id='pending-news'"
        )
        claimable = {
            row["id"]: row["phase"]
            for row in conn.execute(farmctl.pending_claim_order_sql()).fetchall()
        }
        assert claimable["pending-news"] == "Q10_NEWS"
    finally:
        conn.close()


# --------------------------------------------------------------------------- #
# Step 4 — hidden --_run-migration entrypoint re-asserts its own precondition
# --------------------------------------------------------------------------- #
def _has_activation_row(db: Path) -> bool:
    conn = sqlite3.connect(str(db))
    try:
        # The migration creates the table; if it never ran, the table is absent,
        # which is itself proof that no activation row exists.
        exists = conn.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name='gate_contract_activations'"
        ).fetchone()
        if not exists:
            return False
        return (
            conn.execute(
                "SELECT COUNT(*) FROM gate_contract_activations"
            ).fetchone()[0]
            > 0
        )
    finally:
        conn.close()


def test_run_migration_entrypoint_refuses_when_factory_on(tmp_path: Path) -> None:
    # The subprocess entrypoint mutates the live DB; with the factory ON and no
    # override it must fail closed and leave the DB untouched, even though the
    # in-process apply flow would normally have validated preconditions first.
    root = tmp_path / "farm"
    db = _fixture_db(root)
    assert not (root / "state" / "FACTORY_OFF.flag").exists()
    out = tmp_path / "result.json"

    rc = act.main(
        [
            "--_run-migration",
            "--db-root",
            str(root),
            "--manifest-sha",
            "sha",
            "--git-head",
            "head",
            "--json-out",
            str(out),
        ]
    )
    assert rc == 1
    assert not _has_activation_row(db)
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload["ok"] is False
    assert any("FACTORY_OFF" in line or "factory" in line.lower() for line in payload["lines"])


def test_run_migration_entrypoint_proceeds_when_factory_off(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _fixture_db(root)
    (root / "state" / "FACTORY_OFF.flag").write_text("off", encoding="utf-8")
    out = tmp_path / "result.json"

    rc = act.main(
        [
            "--_run-migration",
            "--db-root",
            str(root),
            "--manifest-sha",
            "sha",
            "--git-head",
            "head",
            "--json-out",
            str(out),
        ]
    )
    assert rc == 0
    assert _has_activation_row(db)


def test_run_migration_entrypoint_honors_factory_on_override(tmp_path: Path) -> None:
    # The apply flow forwards --allow-factory-on so a deliberately-allowed run is
    # not false-failed by the re-check.
    root = tmp_path / "farm"
    db = _fixture_db(root)
    assert not (root / "state" / "FACTORY_OFF.flag").exists()
    out = tmp_path / "result.json"

    rc = act.main(
        [
            "--_run-migration",
            "--allow-factory-on",
            "--db-root",
            str(root),
            "--manifest-sha",
            "sha",
            "--git-head",
            "head",
            "--json-out",
            str(out),
        ]
    )
    assert rc == 0
    assert _has_activation_row(db)


# --------------------------------------------------------------------------- #
# Step 6 — rollback plan
# --------------------------------------------------------------------------- #
def test_rollback_plan_mentions_revert_and_backup() -> None:
    lines = act.rollback_plan_lines("D:/QM/backups/x.sqlite")
    joined = "\n".join(lines)
    assert "git revert" in joined
    assert "D:/QM/backups/x.sqlite" in joined
