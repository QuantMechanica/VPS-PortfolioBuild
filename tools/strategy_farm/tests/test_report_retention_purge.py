"""Tests for the DL-090 backtest-report retention job.

Everything runs against a synthetic SQLite database and tmp_path directory
trees. The real ``D:/QM/reports`` and ``D:/QM/strategy_farm`` paths are never
touched: module-level path constants (REPORTS_ROOT, QUARANTINE_ROOT, LOG_PATH,
FORBIDDEN_PREFIXES) are monkeypatched onto tmp_path for the duration of each
test.
"""
from __future__ import annotations

import datetime as dt
import sqlite3
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import report_retention_purge as mod  # noqa: E402


NOW = dt.datetime.now(dt.UTC)
OLD = (NOW - dt.timedelta(days=40)).isoformat()
OLDER = (NOW - dt.timedelta(days=50)).isoformat()
NEWEST_NONPASS = (NOW - dt.timedelta(days=35)).isoformat()
RECENT = (NOW - dt.timedelta(days=5)).isoformat()


_COLUMNS = (
    "id",
    "ea_id",
    "symbol",
    "phase",
    "status",
    "verdict",
    "evidence_path",
    "updated_at",
    "payload_json",
)


def _make_db(db_path: Path, rows: list[dict]) -> None:
    conn = sqlite3.connect(db_path)
    conn.execute(
        "CREATE TABLE work_items ("
        "id TEXT, ea_id TEXT, symbol TEXT, phase TEXT, status TEXT, "
        "verdict TEXT, evidence_path TEXT, updated_at TEXT, payload_json TEXT)"
    )
    for r in rows:
        conn.execute(
            "INSERT INTO work_items (id, ea_id, symbol, phase, status, verdict, "
            "evidence_path, updated_at, payload_json) VALUES (?,?,?,?,?,?,?,?,?)",
            (
                r["id"],
                r.get("ea_id", "QM5_1"),
                r.get("symbol", "EURUSD"),
                r.get("phase", "Q02"),
                r.get("status", "done"),
                r.get("verdict", ""),
                r.get("evidence_path"),
                r.get("updated_at", OLD),
                r.get("payload_json", "{}"),
            ),
        )
    conn.commit()
    conn.close()


def _make_run(reports_root: Path, run_id: str, *, with_report: bool = True,
              extra_files: tuple[str, ...] = ()) -> str:
    """Create <reports_root>/<run_id>/ and return an evidence_path in it."""
    d = reports_root / run_id
    d.mkdir(parents=True, exist_ok=True)
    if with_report:
        (d / "report.htm").write_text("<html>report</html>" * 50, encoding="utf-8")
    for name in extra_files:
        (d / name).write_text("payload", encoding="utf-8")
    # Evidence file itself need not exist on disk; only its parent dir must.
    return str(d / "summary.json")


@pytest.fixture
def env(tmp_path, monkeypatch):
    reports = tmp_path / "reports" / "work_items"
    reports.mkdir(parents=True)
    quarantine = tmp_path / "quarantine"
    log = tmp_path / "logs" / "purge.log"
    monkeypatch.setattr(mod, "REPORTS_ROOT", reports)
    monkeypatch.setattr(mod, "QUARANTINE_ROOT", quarantine)
    monkeypatch.setattr(mod, "LOG_PATH", log)
    return SimpleNamespace(
        tmp=tmp_path,
        reports=reports,
        quarantine=quarantine,
        log=log,
        db=tmp_path / "farm.sqlite",
    )


def _ids(result: dict, cls: str) -> set[str]:
    return {r["id"] for r in result["classes"][cls]}


# --------------------------------------------------------------------------- #
# classify()
# --------------------------------------------------------------------------- #


def test_classify_buckets_every_class(env):
    rows = [
        # PASS family (all four variants) -> keep_pass_family.
        {"id": "pass1", "verdict": "PASS", "symbol": "EURUSD",
         "evidence_path": _make_run(env.reports, "pass1")},
        {"id": "pass2", "verdict": "PASS_SOFT", "symbol": "GBPUSD",
         "evidence_path": _make_run(env.reports, "pass2")},
        {"id": "pass3", "verdict": "PASS_LOWFREQ", "symbol": "USDJPY",
         "evidence_path": _make_run(env.reports, "pass3")},
        {"id": "pass4", "verdict": "PASS_PORTFOLIO", "symbol": "AUDUSD",
         "evidence_path": _make_run(env.reports, "pass4")},
        # Sole non-PASS strategy row in its group -> keep_standing_rejection.
        {"id": "rej_sole", "ea_id": "QM5_2", "symbol": "NZDUSD", "phase": "Q03",
         "verdict": "FAIL", "evidence_path": _make_run(env.reports, "rej_sole")},
        # Three non-PASS strategy rows in one group -> newest kept, rest superseded.
        {"id": "sup_old", "ea_id": "QM5_3", "symbol": "USDCAD", "phase": "Q02",
         "verdict": "FAIL", "updated_at": OLDER,
         "evidence_path": _make_run(env.reports, "sup_old")},
        {"id": "sup_mid", "ea_id": "QM5_3", "symbol": "USDCAD", "phase": "Q02",
         "verdict": "RETIRE", "updated_at": OLD,
         "evidence_path": _make_run(env.reports, "sup_mid")},
        {"id": "sup_new", "ea_id": "QM5_3", "symbol": "USDCAD", "phase": "Q02",
         "verdict": "ZERO_TRADES", "updated_at": NEWEST_NONPASS,
         "evidence_path": _make_run(env.reports, "sup_new")},
        # infra / invalid -> age_out_infra_invalid.
        {"id": "infra1", "verdict": "INFRA_FAIL",
         "evidence_path": _make_run(env.reports, "infra1")},
        {"id": "invalid1", "verdict": "INVALID_SETFILE",
         "evidence_path": _make_run(env.reports, "invalid1")},
        # Unrecognized taxonomies -> keep_unclassified_taxonomy (never age out).
        {"id": "review1", "verdict": "REVIEW_REQUIRED",
         "evidence_path": _make_run(env.reports, "review1")},
        {"id": "gov1", "verdict": "SUPERSEDED",
         "evidence_path": _make_run(env.reports, "gov1")},
        {"id": "unknown1", "verdict": "WEIRD_TOKEN",
         "evidence_path": _make_run(env.reports, "unknown1")},
        # Open row (no verdict, claimed) -> skip_open_status.
        {"id": "open1", "status": "claimed", "verdict": "",
         "evidence_path": _make_run(env.reports, "open1")},
        # Claimed row carrying a stale verdict -> STILL skip_open_status
        # (raw-status guard; clean view would restamp it to 'failed'/infra).
        {"id": "open_verdict", "status": "claimed", "verdict": "INFRA_FAIL",
         "evidence_path": _make_run(env.reports, "open_verdict")},
        # Run dir with no report.htm -> excluded from every class.
        {"id": "noreport", "verdict": "FAIL",
         "evidence_path": _make_run(env.reports, "noreport", with_report=False)},
    ]
    _make_db(env.db, rows)

    result = mod.classify(env.db)

    assert _ids(result, "keep_pass_family") == {"pass1", "pass2", "pass3", "pass4"}
    assert _ids(result, "keep_standing_rejection") == {"rej_sole", "sup_new"}
    assert _ids(result, "age_out_superseded_strategy") == {"sup_old", "sup_mid"}
    assert _ids(result, "age_out_infra_invalid") == {"infra1", "invalid1"}
    assert _ids(result, "keep_unclassified_taxonomy") == {"review1", "gov1", "unknown1"}
    assert _ids(result, "skip_open_status") == {"open1", "open_verdict"}

    # The report-less row must not appear anywhere.
    all_ids: set[str] = set()
    for cls in result["classes"]:
        all_ids |= _ids(result, cls)
    assert "noreport" not in all_ids
    assert result["total_rows_seen"] == len(rows) - 1  # noreport excluded


def test_claimed_row_with_verdict_never_ages_out(env):
    """DL-090 S4.6 fail-closed: raw 'claimed' status wins over a stale verdict."""
    rows = [
        {"id": "claimed_infra", "status": "claimed", "verdict": "INFRA_FAIL",
         "evidence_path": _make_run(env.reports, "claimed_infra")},
    ]
    _make_db(env.db, rows)
    result = mod.classify(env.db)
    assert _ids(result, "skip_open_status") == {"claimed_infra"}
    assert _ids(result, "age_out_infra_invalid") == set()


def test_classify_excludes_dir_without_report(env):
    rows = [
        {"id": "with", "verdict": "INFRA_FAIL",
         "evidence_path": _make_run(env.reports, "with")},
        {"id": "without", "verdict": "INFRA_FAIL",
         "evidence_path": _make_run(env.reports, "without", with_report=False)},
    ]
    _make_db(env.db, rows)
    result = mod.classify(env.db)
    assert _ids(result, "age_out_infra_invalid") == {"with"}


def test_classify_accepts_report_html_variant(env):
    d = env.reports / "htmlrow"
    d.mkdir(parents=True)
    (d / "report.html").write_text("<html/>", encoding="utf-8")
    rows = [{"id": "htmlrow", "verdict": "INFRA_FAIL",
             "evidence_path": str(d / "summary.json")}]
    _make_db(env.db, rows)
    result = mod.classify(env.db)
    assert _ids(result, "age_out_infra_invalid") == {"htmlrow"}


# --------------------------------------------------------------------------- #
# _run_dir_for_evidence()
# --------------------------------------------------------------------------- #


def test_run_dir_for_evidence_forbidden_prefix(tmp_path, monkeypatch):
    reports = tmp_path / "reports" / "work_items"
    protected = reports / "protected"   # forbidden AND inside reports root
    protected.mkdir(parents=True)
    (reports / "ok").mkdir()
    monkeypatch.setattr(mod, "REPORTS_ROOT", reports)
    monkeypatch.setattr(mod, "FORBIDDEN_PREFIXES", (protected,))

    # Under a forbidden prefix -> None even though it is under the reports root.
    assert mod._run_dir_for_evidence(str(protected / "run" / "summary.json")) is None
    # Under reports root, not forbidden -> the run dir (evidence parent).
    assert mod._run_dir_for_evidence(str(reports / "ok" / "summary.json")) == (
        reports / "ok"
    ).resolve()
    # Outside the reports root entirely -> None.
    assert mod._run_dir_for_evidence(str(tmp_path / "elsewhere" / "s.json")) is None
    # Empty evidence -> None.
    assert mod._run_dir_for_evidence("") is None


# --------------------------------------------------------------------------- #
# quarantine()
# --------------------------------------------------------------------------- #


def test_quarantine_respects_min_age_and_dry_run(env):
    rows = [
        {"id": "infra_old", "verdict": "INFRA_FAIL", "updated_at": OLD,
         "evidence_path": _make_run(env.reports, "infra_old")},
        {"id": "infra_new", "verdict": "INFRA_FAIL", "updated_at": RECENT,
         "evidence_path": _make_run(env.reports, "infra_new")},
    ]
    _make_db(env.db, rows)
    result = mod.classify(env.db)

    # Dry run: reports one eligible move, touches nothing.
    dry = mod.quarantine(result, min_age_days=30, execute=False)
    assert dry["moved"] == 1
    assert (env.reports / "infra_old").is_dir()
    assert (env.reports / "infra_new").is_dir()
    assert not env.quarantine.exists()

    # Execute: only the aged dir moves into QUARANTINE_ROOT/<date>/<id>.
    live = mod.quarantine(result, min_age_days=30, execute=True)
    assert live["moved"] == 1
    today = dt.datetime.now(dt.UTC).strftime("%Y%m%d")
    dest = env.quarantine / today / "infra_old"
    assert dest.is_dir()
    assert (dest / "report.htm").exists()
    assert not (env.reports / "infra_old").exists()
    assert (env.reports / "infra_new").is_dir()  # too young, untouched


# --------------------------------------------------------------------------- #
# reap_quarantine()
# --------------------------------------------------------------------------- #


def test_reap_quarantine_deletes_only_aged_folders(env):
    old_date = (NOW - dt.timedelta(days=40)).strftime("%Y%m%d")
    new_date = (NOW - dt.timedelta(days=5)).strftime("%Y%m%d")
    for date, rid in ((old_date, "r_old"), (new_date, "r_new")):
        d = env.quarantine / date / rid
        d.mkdir(parents=True)
        (d / "report.htm").write_text("x", encoding="utf-8")

    # Dry run: counts the aged folder, deletes nothing.
    dry = mod.reap_quarantine(reap_days=30, execute=False)
    assert dry["deleted"] == 1
    assert (env.quarantine / old_date / "r_old").exists()

    # Execute: aged dated folder gone, recent one preserved.
    live = mod.reap_quarantine(reap_days=30, execute=True)
    assert live["deleted"] == 1
    assert not (env.quarantine / old_date).exists()
    assert (env.quarantine / new_date / "r_new").exists()


def test_reap_quarantine_absent_root_is_noop(env):
    res = mod.reap_quarantine(reap_days=30, execute=True)
    assert res == {"deleted": 0, "deleted_bytes": 0}


# --------------------------------------------------------------------------- #
# compress_kept()
# --------------------------------------------------------------------------- #


def test_compress_kept_gzips_aged_kept_set(env):
    d = env.reports / "pass_old"
    d.mkdir(parents=True)
    (d / "report.htm").write_text("<html>" * 500, encoding="utf-8")
    (d / "tester.ini").write_text("[Tester]", encoding="utf-8")
    # An already-compressed artifact must be skipped, not re-gzipped.
    (d / "summary.json").write_text("{}", encoding="utf-8")
    (d / "summary.json.gz").write_text("already", encoding="utf-8")

    rows = [{"id": "pass_old", "verdict": "PASS", "updated_at": OLD,
             "evidence_path": str(d / "summary.json")}]
    _make_db(env.db, rows)
    result = mod.classify(env.db)

    # Dry run touches nothing.
    dry = mod.compress_kept(result, min_age_days=30, execute=False)
    assert dry["compressed"] == 2  # report.htm + tester.ini
    assert (d / "report.htm").exists()
    assert not (d / "report.htm.gz").exists()

    # Execute: gzips the two eligible files, unlinks originals, skips the pair.
    live = mod.compress_kept(result, min_age_days=30, execute=True)
    assert live["compressed"] == 2
    assert (d / "report.htm.gz").exists() and not (d / "report.htm").exists()
    assert (d / "tester.ini.gz").exists() and not (d / "tester.ini").exists()
    assert (d / "summary.json").exists()  # already-compressed sibling: untouched


def test_compress_kept_skips_too_young(env):
    d = env.reports / "pass_young"
    d.mkdir(parents=True)
    (d / "report.htm").write_text("<html>", encoding="utf-8")
    rows = [{"id": "pass_young", "verdict": "PASS", "updated_at": RECENT,
             "evidence_path": str(d / "summary.json")}]
    _make_db(env.db, rows)
    result = mod.classify(env.db)
    res = mod.compress_kept(result, min_age_days=30, execute=True)
    assert res["compressed"] == 0
    assert (d / "report.htm").exists()


# --------------------------------------------------------------------------- #
# Fail-closed: DB unreachable
# --------------------------------------------------------------------------- #


def test_classify_raises_on_missing_db(env):
    with pytest.raises(Exception):
        mod.classify(env.tmp / "does_not_exist.sqlite")


def test_main_fail_closed_on_missing_db(env, monkeypatch):
    missing = env.tmp / "does_not_exist.sqlite"
    monkeypatch.setattr(sys, "argv", ["report_retention_purge.py", "--db", str(missing)])
    rc = mod.main()
    assert rc == 2
    # No filesystem action taken (no quarantine tree created).
    assert not env.quarantine.exists()
    # Fail-closed reason was logged to the (tmp) log.
    assert env.log.exists()
    assert "CLASSIFY_FAIL" in env.log.read_text(encoding="utf-8")
