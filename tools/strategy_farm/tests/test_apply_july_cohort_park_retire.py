import importlib.util
import json
import sqlite3
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "apply_july_cohort_park_retire.py"
SPEC = importlib.util.spec_from_file_location("july_cohort_park_retire", MODULE_PATH)
assert SPEC and SPEC.loader
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)


SCHEMA_SQL = """
CREATE TABLE work_items(
  id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
  setfile_path TEXT, status TEXT, verdict TEXT, claimed_by TEXT,
  payload_json TEXT, created_at TEXT
);
CREATE TABLE work_item_supersedes(
  work_item_id TEXT, superseded_by_work_item_id TEXT, reason TEXT,
  source_encoding TEXT, evidence_path TEXT, recorded_by TEXT, recorded_at TEXT,
  PRIMARY KEY(work_item_id, source_encoding)
);
CREATE TABLE events(
  ts TEXT, entity_type TEXT, entity_id TEXT, event TEXT, detail_json TEXT
);
"""


def _insert_work_item(conn, *, id_, phase, ea_id, symbol, status, verdict, claimed_by,
                       created_at):
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?)",
        (id_, "backtest", phase, ea_id, symbol, "set.set", status, verdict, claimed_by,
         "{}", created_at),
    )


def make_db(path: Path, *, park_count: int, retire_count: int) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA_SQL)

    park_verdicts = list(mod.PARK_VERDICTS)
    retire_verdicts = list(mod.RETIRE_VERDICTS)

    for i in range(park_count):
        ea_id, symbol, phase = f"QM5_PARK{i}", "EURUSD.DWX", "Q02"
        prior_id = f"prior-park-{i}"
        _insert_work_item(
            conn, id_=prior_id, phase=phase, ea_id=ea_id, symbol=symbol, status="done",
            verdict=park_verdicts[i % len(park_verdicts)], claimed_by=None,
            created_at="2026-08-01T00:00:00+00:00",
        )
        _insert_work_item(
            conn, id_=f"pending-park-{i}", phase=phase, ea_id=ea_id, symbol=symbol,
            status="pending", verdict=None, claimed_by=None,
            created_at="2026-08-10T00:00:00+00:00",
        )

    for i in range(retire_count):
        ea_id, symbol, phase = f"QM5_RETIRE{i}", "GBPUSD.DWX", "Q04"
        prior_id = f"prior-retire-{i}"
        _insert_work_item(
            conn, id_=prior_id, phase=phase, ea_id=ea_id, symbol=symbol, status="failed",
            verdict=retire_verdicts[i % len(retire_verdicts)], claimed_by=None,
            created_at="2026-08-02T00:00:00+00:00",
        )
        _insert_work_item(
            conn, id_=f"pending-retire-{i}", phase=phase, ea_id=ea_id, symbol=symbol,
            status="pending", verdict=None, claimed_by=None,
            created_at="2026-08-11T00:00:00+00:00",
        )

    # Out-of-scope distractors: INFRA_FAIL (treasure) and NO_PRIOR_RUN (assess).
    _insert_work_item(
        conn, id_="prior-infra-0", phase="Q02", ea_id="QM5_INFRA0", symbol="XAUUSD.DWX",
        status="failed", verdict="INFRA_FAIL", claimed_by=None,
        created_at="2026-08-01T00:00:00+00:00",
    )
    _insert_work_item(
        conn, id_="pending-infra-0", phase="Q02", ea_id="QM5_INFRA0", symbol="XAUUSD.DWX",
        status="pending", verdict=None, claimed_by=None,
        created_at="2026-08-10T00:00:00+00:00",
    )
    _insert_work_item(
        conn, id_="pending-noprior-0", phase="Q04", ea_id="QM5_NOPRIOR0", symbol="NDX.DWX",
        status="pending", verdict=None, claimed_by=None,
        created_at="2026-08-10T00:00:00+00:00",
    )

    conn.commit()
    conn.close()


def _build_and_write_plan(db: Path, tmp_path: Path) -> tuple[Path, str]:
    plan = mod.build_plan(db)
    plan_path = tmp_path / "plan.json"
    plan_path.write_bytes(mod.canonical_bytes(plan))
    return plan_path, mod.sha256_file(plan_path)


def test_build_plan_matches_expected_counts_and_excludes_out_of_scope(tmp_path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    evidence = tmp_path / "evidence.md"
    evidence.write_text("classification\n", encoding="utf-8")
    monkeypatch.setattr(mod, "CLASSIFICATION_EVIDENCE_PATH", evidence)
    monkeypatch.setattr(mod, "EXPECTED_PARK_COUNT", 6)
    monkeypatch.setattr(mod, "EXPECTED_RETIRE_COUNT", 8)
    make_db(db, park_count=6, retire_count=8)

    plan = mod.build_plan(db)
    assert plan["park_count"] == 6
    assert plan["retire_count"] == 8
    park_ids = {t["id"] for t in plan["park_targets"]}
    retire_ids = {t["id"] for t in plan["retire_targets"]}
    assert "pending-infra-0" not in park_ids | retire_ids
    assert "pending-noprior-0" not in park_ids | retire_ids
    for t in plan["park_targets"]:
        assert t["prior_verdict"] in mod.PARK_VERDICTS
    for t in plan["retire_targets"]:
        assert t["prior_verdict"] in mod.RETIRE_VERDICTS


def test_build_plan_stops_on_count_mismatch(tmp_path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    evidence = tmp_path / "evidence.md"
    evidence.write_text("classification\n", encoding="utf-8")
    monkeypatch.setattr(mod, "CLASSIFICATION_EVIDENCE_PATH", evidence)
    monkeypatch.setattr(mod, "EXPECTED_PARK_COUNT", 79)
    monkeypatch.setattr(mod, "EXPECTED_RETIRE_COUNT", 223)
    make_db(db, park_count=6, retire_count=8)

    try:
        mod.build_plan(db)
    except mod.ParkRetireBatchError as exc:
        assert "count_mismatch" in str(exc)
    else:
        raise AssertionError("count mismatch did not stop the dry-run")


def test_apply_is_append_only_single_backup_two_batches(tmp_path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    evidence = tmp_path / "evidence.md"
    evidence.write_text("classification\n", encoding="utf-8")
    monkeypatch.setattr(mod, "CLASSIFICATION_EVIDENCE_PATH", evidence)
    monkeypatch.setattr(mod, "EXPECTED_PARK_COUNT", 5)
    monkeypatch.setattr(mod, "EXPECTED_RETIRE_COUNT", 7)
    make_db(db, park_count=5, retire_count=7)

    plan_path, plan_sha = _build_and_write_plan(db, tmp_path)
    receipt_path = tmp_path / "receipt.json"
    backup_dir = tmp_path / "backups"
    receipt = mod.apply_plan(
        db=db, plan_path=plan_path, expected_plan_sha256=plan_sha, receipt_out=receipt_path,
        backup_dir=backup_dir, mutation_lock=tmp_path / "mutation.lock",
    )

    assert receipt["total_inserted"] == 12
    assert receipt["park"]["inserted"] == 5
    assert receipt["retire"]["inserted"] == 7
    assert receipt["total_skipped"] == 0
    assert len(list(backup_dir.glob("*.sqlite"))) == 1

    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    assert conn.execute("SELECT COUNT(*) FROM work_item_supersedes").fetchone()[0] == 12
    park_rows = conn.execute(
        "SELECT * FROM work_item_supersedes WHERE source_encoding=?",
        (mod.PARK_SOURCE_ENCODING,),
    ).fetchall()
    assert len(park_rows) == 5
    for row in park_rows:
        assert row["superseded_by_work_item_id"] is not None
        assert row["superseded_by_work_item_id"].startswith("prior-park-")
    retire_rows = conn.execute(
        "SELECT * FROM work_item_supersedes WHERE source_encoding=?",
        (mod.RETIRE_SOURCE_ENCODING,),
    ).fetchall()
    assert len(retire_rows) == 7
    for row in retire_rows:
        assert row["superseded_by_work_item_id"] is not None
        assert row["superseded_by_work_item_id"].startswith("prior-retire-")

    # Never edited/deleted: every touched pending row keeps its original
    # status/verdict/claimed_by/payload; only new supersede + event rows exist.
    still_pending = conn.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending' AND verdict IS NULL"
    ).fetchone()[0]
    assert still_pending == 5 + 7 + 2  # + the two out-of-scope distractor rows
    assert conn.execute(
        "SELECT COUNT(*) FROM events WHERE event='work_item_superseded'"
    ).fetchone()[0] == 12
    # Out-of-scope rows (INFRA_FAIL / NO_PRIOR_RUN) never got an edge.
    assert conn.execute(
        "SELECT COUNT(*) FROM work_item_supersedes WHERE work_item_id IN "
        "('pending-infra-0','pending-noprior-0')"
    ).fetchone()[0] == 0
    conn.close()


def test_apply_skips_drifted_row_without_touching_or_aborting_others(tmp_path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    evidence = tmp_path / "evidence.md"
    evidence.write_text("classification\n", encoding="utf-8")
    monkeypatch.setattr(mod, "CLASSIFICATION_EVIDENCE_PATH", evidence)
    monkeypatch.setattr(mod, "EXPECTED_PARK_COUNT", 4)
    monkeypatch.setattr(mod, "EXPECTED_RETIRE_COUNT", 3)
    make_db(db, park_count=4, retire_count=3)

    plan_path, plan_sha = _build_and_write_plan(db, tmp_path)

    # Simulate a factory worker claiming one park row between plan and apply.
    conn = sqlite3.connect(db)
    conn.execute(
        "UPDATE work_items SET status='active', claimed_by='T3' WHERE id='pending-park-0'"
    )
    conn.commit()
    conn.close()

    receipt = mod.apply_plan(
        db=db, plan_path=plan_path, expected_plan_sha256=plan_sha,
        receipt_out=tmp_path / "receipt.json", backup_dir=tmp_path / "backups",
        mutation_lock=tmp_path / "mutation.lock",
    )

    assert receipt["park"]["inserted"] == 3
    assert receipt["park"]["skipped"] == [{"id": "pending-park-0", "reason": "status_drifted:active"}]
    assert receipt["retire"]["inserted"] == 3
    assert receipt["total_inserted"] == 6

    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    drifted = conn.execute("SELECT * FROM work_items WHERE id='pending-park-0'").fetchone()
    assert drifted["status"] == "active" and drifted["claimed_by"] == "T3"
    assert conn.execute(
        "SELECT 1 FROM work_item_supersedes WHERE work_item_id='pending-park-0'"
    ).fetchone() is None
    assert conn.execute("SELECT COUNT(*) FROM work_item_supersedes").fetchone()[0] == 6
    conn.close()


def test_apply_refuses_plan_hash_mismatch(tmp_path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    evidence = tmp_path / "evidence.md"
    evidence.write_text("classification\n", encoding="utf-8")
    monkeypatch.setattr(mod, "CLASSIFICATION_EVIDENCE_PATH", evidence)
    monkeypatch.setattr(mod, "EXPECTED_PARK_COUNT", 2)
    monkeypatch.setattr(mod, "EXPECTED_RETIRE_COUNT", 2)
    make_db(db, park_count=2, retire_count=2)
    plan_path, _ = _build_and_write_plan(db, tmp_path)

    try:
        mod.apply_plan(
            db=db, plan_path=plan_path, expected_plan_sha256="0" * 64,
            receipt_out=tmp_path / "receipt.json", backup_dir=tmp_path / "backups",
            mutation_lock=tmp_path / "mutation.lock",
        )
    except mod.ParkRetireBatchError as exc:
        assert "plan_sha256_mismatch" in str(exc)
    else:
        raise AssertionError("plan hash mismatch was not refused")
    conn = sqlite3.connect(db)
    assert conn.execute("SELECT COUNT(*) FROM work_item_supersedes").fetchone()[0] == 0
    conn.close()
