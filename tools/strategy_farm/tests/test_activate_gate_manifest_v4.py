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
    for old, _new in act.FLIP_SUBSTITUTIONS:
        assert text.count(old) == 1, old


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
            "created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
            [
                ("wi-1", "backtest", "Q10", "QM5_1", "EURUSD.DWX", "s.set",
                 "pending", "{}", "2026-08-23T11:00:00Z", "2026-08-23T11:00:00Z"),
                ("wi-2", "backtest", "Q08", "QM5_2", "EURUSD.DWX", "s.set",
                 "pending", "{}", "2026-08-23T11:00:00Z", "2026-08-23T11:00:00Z"),
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
    before = db.read_bytes()
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
    # Live DB file bytes are unchanged; the migration ran on the copy.
    assert db.read_bytes() == before
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


# --------------------------------------------------------------------------- #
# Step 6 — rollback plan
# --------------------------------------------------------------------------- #
def test_rollback_plan_mentions_revert_and_backup() -> None:
    lines = act.rollback_plan_lines("D:/QM/backups/x.sqlite")
    joined = "\n".join(lines)
    assert "git revert" in joined
    assert "D:/QM/backups/x.sqlite" in joined
