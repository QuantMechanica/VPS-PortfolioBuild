"""WP-2 hardening tests for ingest_phase_aggregates.

Covers the four Codex-review defects:
  1. atomic idempotency — a concurrent second apply / prior-committed row cannot
     double-insert (durable ledger PK + revalidation inside BEGIN IMMEDIATE);
     plus same-generated_at_utc content-change detection;
  2. safe supersede — a strictly-newer re-run with the same terminal verdict is
     suppressed and recorded as an observation, not inserted;
  3. setfile provenance — resolved from the immutable per-run tester.ini, never
     the mutable shared summary.json; unresolvable => row refused, not empty; and
     (round-3) a setfile no surviving hash can cover is REFUSED by default
     (setfile_hash_unavailable), ingested flagged only under --allow-unverified;
  4. guarded revert — refuses the whole triple when ANY of the three inserted rows
     (work_items, ea_metrics, ledger) was modified since ingestion (round-3) or
     when a downstream portfolio_candidates row references the work item.
"""

from __future__ import annotations

import json
import sqlite3
import sys
import threading
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import ingest_phase_aggregates as ing  # noqa: E402


# --------------------------------------------------------------------------- #
# Fixtures                                                                     #
# --------------------------------------------------------------------------- #

_WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL, ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL, setfile_path TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status in ('pending','active','done','failed')),
    verdict TEXT, attempt_count INTEGER NOT NULL DEFAULT 0, parent_task_id TEXT,
    evidence_path TEXT, claimed_by TEXT, payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE portfolio_candidates (
    ea_id TEXT, symbol TEXT, q11_work_item_id TEXT, state TEXT, evidence_path TEXT,
    first_seen_at TEXT, updated_at TEXT
);
"""


def _make_db(tmp_path: Path) -> Path:
    db = tmp_path / "farm.sqlite"
    con = sqlite3.connect(db)
    con.executescript(_WORK_ITEMS_DDL)
    con.commit()
    con.close()
    return db


def _write_run(root: Path, ea: int, slug: str, symbol: str, run_tag: str, run: str,
               setfile_name: str) -> Path:
    """Create a per-run report dir with an immutable tester.ini and return the
    report.htm path the aggregate should point at."""
    run_dir = root / f"QM5_{ea}" / run_tag / "raw" / run
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "report.htm").write_text("<html></html>", encoding="utf-8")
    (run_dir / "tester.ini").write_text(
        "[Tester]\n"
        f"Expert=QM\\{slug}\n"
        f"Symbol={symbol}\n"
        "Period=D1\nModel=4\n"
        f"ExpertParameters={setfile_name}\n",
        encoding="utf-8",
    )
    return run_dir / "report.htm"


def _write_aggregate(pipeline_root: Path, ea: int, symbol: str, phase: str,
                     verdict: str, gen_utc: str, report_htm: Path,
                     summary_path: Path | None = None, reason: str = "ok") -> Path:
    agg_dir = pipeline_root / f"QM5_{ea}" / phase / symbol.replace(".", "_")
    agg_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "ea_id": ea, "symbol": symbol, "phase": phase, "verdict": verdict,
        "generated_at_utc": gen_utc, "reason": reason,
        "report_htm": str(report_htm),
    }
    if summary_path is not None:
        payload["summary_path"] = str(summary_path)
    p = agg_dir / "aggregate.json"
    p.write_text(json.dumps(payload), encoding="utf-8")
    return p


def _make_setfile(eas_root: Path, slug: str, name: str) -> Path:
    d = eas_root / slug / "sets"
    d.mkdir(parents=True, exist_ok=True)
    p = d / name
    p.write_text("input x=1;\n", encoding="utf-8")
    return p


def _write_summary(pipeline_root: Path, ea: int, run_tag: str,
                   setfile_source: Path, sha256: str | None) -> Path:
    """Write a run_tag-level summary.json carrying the setfile source identity
    the ingester authenticates against (execution_identity.setfile.source)."""
    summary = pipeline_root / f"QM5_{ea}" / run_tag / "summary.json"
    summary.parent.mkdir(parents=True, exist_ok=True)
    source: dict = {"path": str(setfile_source)}
    if sha256 is not None:
        source["sha256"] = sha256
    summary.write_text(
        json.dumps({"execution_identity": {"setfile": {"source": source}}}),
        encoding="utf-8",
    )
    return summary


def _write_verified_run(env, ea: int, slug: str, symbol: str, run_tag: str,
                        run: str, setname: str) -> tuple[Path, Path]:
    """Create a run whose summary.json records the setfile's REAL sha256, so the
    setfile authenticates as verified under the default (hash-required) policy.
    Returns (report_htm, summary_path)."""
    setpath = env["eas"] / slug / "sets" / setname
    htm = _write_run(env["pipeline"], ea, slug, symbol, run_tag, run, setname)
    summary = _write_summary(env["pipeline"], ea, run_tag, setpath, ing._sha256_file(setpath))
    return htm, summary


def _seed_evidence_row(db: Path, wid: str, ea: str, symbol: str, phase: str,
                       verdict: str, evidence_path: Path, updated_at: str) -> None:
    """Seed a terminal work_items row whose evidence_path is an arbitrary file
    (e.g. a UTF-16 report.htm), with no generated_at_utc in its payload."""
    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,"
        "attempt_count,evidence_path,payload_json,created_at,updated_at) "
        "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (wid, "backtest", phase, ea, symbol, "C:\\seed.set", "done", verdict, 0,
         str(evidence_path), "{}", updated_at, updated_at),
    )
    con.commit(); con.close()


@pytest.fixture()
def env(tmp_path, monkeypatch):
    """A sandbox with patched aggregate roots + repo EA tree."""
    pipeline = tmp_path / "pipeline"
    work_items_root = tmp_path / "work_items"
    eas = tmp_path / "EAs"
    pipeline.mkdir(); work_items_root.mkdir(); eas.mkdir()
    monkeypatch.setattr(ing, "AGGREGATE_ROOTS", (
        (pipeline, "QM5_*/{phase}/*/aggregate.json"),
        (work_items_root, "**/{phase}/*/aggregate.json"),
    ))
    monkeypatch.setattr(ing, "REPO_EAS_DIR", eas)
    db = _make_db(tmp_path)
    snap = tmp_path / "snap"
    return {
        "tmp": tmp_path, "pipeline": pipeline, "eas": eas, "db": db, "snap": snap,
    }


# --------------------------------------------------------------------------- #
# Defect 3 — setfile provenance                                               #
# --------------------------------------------------------------------------- #

def test_setfile_resolves_from_own_tester_ini_not_shared_summary(env):
    """The XNGUSD/XAUUSD shape: both aggregates share one summary.json (last
    writer wins = XAUUSD) but each has its own tester.ini. The XNGUSD row must
    resolve to the XNGUSD setfile, proving we ignore the mutable summary."""
    ea, slug = 12567, "QM5_12567_cum-rsi2-commodity"
    xau_set = f"{slug}_XAUUSD.DWX_D1_q10_confirmation.set"
    xng_set = f"{slug}_XNGUSD.DWX_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, xau_set)
    _make_setfile(env["eas"], slug, xng_set)

    run_tag = "20260724_215508"
    xau_htm = _write_run(env["pipeline"], ea, slug, "XAUUSD.DWX", run_tag, "run_01", xau_set)
    xng_htm = _write_run(env["pipeline"], ea, slug, "XNGUSD.DWX", run_tag, "run_02", xng_set)

    # Shared, mutable summary.json — the XAUUSD run overwrote it last.
    shared_summary = env["pipeline"] / f"QM5_{ea}" / run_tag / "summary.json"
    shared_summary.write_text(json.dumps({
        "execution_identity": {"setfile": {"source": {"path": str(env["eas"] / slug / "sets" / xau_set)}}}
    }), encoding="utf-8")

    _write_aggregate(env["pipeline"], ea, "XAUUSD.DWX", "Q10", "PASS",
                     "2026-07-24T22:09:26+00:00", xau_htm, shared_summary)
    _write_aggregate(env["pipeline"], ea, "XNGUSD.DWX", "Q10", "PASS",
                     "2026-07-24T22:01:30+00:00", xng_htm, shared_summary)

    # This test's concern is setfile RESOLUTION (own tester.ini, not shared
    # summary), not the hash gate: the shared summary carries no sha256, so both
    # rows are unverified. Run under the OWNER exception so actions are produced
    # and the resolved paths can be checked. (Default-refuse of the unverified
    # sibling shape is covered by test_sibling_shared_summary_refused_by_default_*.)
    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now(), allow_unverified=True); con.close()
    by_sym = {a["symbol"]: a["setfile_path"] for a in result["actions"]}
    assert by_sym["XNGUSD.DWX"].endswith(xng_set)
    assert by_sym["XAUUSD.DWX"].endswith(xau_set)
    assert "XAUUSD" not in Path(by_sym["XNGUSD.DWX"]).name.replace("XAUUSD", "")  # sanity


def test_row_refused_when_setfile_cannot_be_resolved(env):
    """Missing setfile on disk => refuse the row (never write empty setfile)."""
    ea, slug = 99001, "QM5_99001_ghost"
    setname = f"{slug}_EURUSD.DWX_D1_q10_confirmation.set"  # deliberately NOT created
    htm = _write_run(env["pipeline"], ea, slug, "EURUSD.DWX", "20260101_000000", "run_01", setname)
    _write_aggregate(env["pipeline"], ea, "EURUSD.DWX", "Q10", "PASS",
                     "2026-01-01T00:00:00+00:00", htm)
    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert result["actions"] == []
    assert len(result["refused"]) == 1
    assert result["refused"][0]["reason"] == "setfile_unresolved"


def test_setfile_symbol_identity_mismatch_is_refused(env):
    """A tester.ini whose Symbol disagrees with the aggregate must not resolve."""
    ea, slug = 99002, "QM5_99002_x"
    setname = f"{slug}_EURUSD.DWX_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, setname)
    # tester.ini says GBPUSD while the aggregate claims EURUSD.
    htm = _write_run(env["pipeline"], ea, slug, "GBPUSD.DWX", "20260101_000000", "run_01", setname)
    _write_aggregate(env["pipeline"], ea, "EURUSD.DWX", "Q10", "PASS",
                     "2026-01-01T00:00:00+00:00", htm)
    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert result["actions"] == []
    assert result["refused"][0]["reason"] == "setfile_unresolved"


# --------------------------------------------------------------------------- #
# Defect 2 — safe supersede                                                    #
# --------------------------------------------------------------------------- #

def _seed_done_row(db: Path, ea: str, symbol: str, phase: str, verdict: str,
                   gen_utc: str, updated_at: str) -> str:
    con = sqlite3.connect(db)
    wid = f"seed-{ea}-{symbol}"
    con.execute(
        "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,"
        "attempt_count,payload_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
        (wid, "backtest", phase, ea, symbol, "C:\\seed.set", "done", verdict, 0,
         json.dumps({"generated_at_utc": gen_utc}), updated_at, updated_at),
    )
    con.commit(); con.close()
    return wid


def test_supersede_suppressed_when_verdict_unchanged(env):
    ea, slug = 20048, "QM5_20048_wti-preholiday"
    setname = f"{slug}_XTIUSD.DWX_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, setname)
    _seed_done_row(env["db"], "QM5_20048", "XTIUSD.DWX", "Q10", "PASS",
                   "2026-07-22T19:26:51+00:00", "2026-07-22T19:26:53+00:00")
    htm = _write_run(env["pipeline"], ea, slug, "XTIUSD.DWX", "20260724_214554", "run_01", setname)
    _write_aggregate(env["pipeline"], ea, "XTIUSD.DWX", "Q10", "PASS",
                     "2026-07-24T21:45:54+00:00", htm)  # strictly newer, same PASS

    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert result["actions"] == []
    obs = [o for o in result["observations"] if o["type"] == "supersede_suppressed_same_verdict"]
    assert len(obs) == 1 and obs[0]["ea_id"] == "QM5_20048"


def test_supersede_kept_when_verdict_changes(env):
    """A newer run that flips FAIL->PASS is a real supersede and must ingest."""
    ea, slug = 20049, "QM5_20049_y"
    setname = f"{slug}_EURUSD.DWX_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, setname)
    _seed_done_row(env["db"], "QM5_20049", "EURUSD.DWX", "Q10", "FAIL",
                   "2026-07-22T00:00:00+00:00", "2026-07-22T00:00:00+00:00")
    htm, summary = _write_verified_run(env, ea, slug, "EURUSD.DWX",
                                       "20260724_000000", "run_01", setname)
    _write_aggregate(env["pipeline"], ea, "EURUSD.DWX", "Q10", "PASS",
                     "2026-07-24T00:00:00+00:00", htm, summary)
    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert len(result["actions"]) == 1
    assert result["actions"][0]["action"] == "supersede"


# --------------------------------------------------------------------------- #
# Defect 1 — atomic idempotency / no double-insert                            #
# --------------------------------------------------------------------------- #

def _single_pass_env(env, ea=30001, symbol="EURUSD.DWX", gen="2026-07-01T00:00:00+00:00"):
    """A single verified Q10 PASS candidate. The summary records the setfile's real
    sha256 so it authenticates under the default (hash-required) policy — the
    idempotency / supersede / revert tests exercise their own concern, not the
    hash gate."""
    slug = f"QM5_{ea}_z"
    setname = f"{slug}_{symbol}_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, setname)
    htm, summary = _write_verified_run(env, ea, slug, symbol, "20260701_000000", "run_01", setname)
    _write_aggregate(env["pipeline"], ea, symbol, "Q10", "PASS", gen, htm, summary)
    return ea, symbol


def test_second_apply_is_noop(env):
    _single_pass_env(env)
    r1 = ing.apply(env["db"], env["snap"], "Q10")
    r2 = ing.apply(env["db"], env["snap"], "Q10")
    assert len(r1["inserted_work_item_ids"]) == 1
    assert r2["inserted_work_item_ids"] == []
    con = sqlite3.connect(env["db"])
    assert con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 1
    assert con.execute("SELECT COUNT(*) FROM ingest_phase_aggregate_ledger").fetchone()[0] == 1
    con.close()


def test_prior_committed_row_blocks_reinsert_via_revalidation(env):
    """Simulate a terminal worker committing the same evidence between plan and
    insert: pre-seed the ledger, then apply must revalidate and insert 0."""
    ea, symbol = _single_pass_env(env)
    # First apply establishes schema + ledger.
    ing.apply(env["db"], env["snap"], "Q10")
    # Wipe the work_items/ea_metrics rows but KEEP the ledger (models a durable
    # record of prior ingestion surviving a partial cleanup).
    con = sqlite3.connect(env["db"])
    con.execute("DELETE FROM work_items"); con.execute("DELETE FROM ea_metrics")
    con.commit(); con.close()
    r = ing.apply(env["db"], env["snap"], "Q10")
    assert r["inserted_work_item_ids"] == []  # ledger revalidation blocked it


def test_ledger_primary_key_rejects_duplicate(env):
    """The durable uniqueness backstop: a duplicate ledger key raises."""
    _single_pass_env(env)
    ing.apply(env["db"], env["snap"], "Q10")
    con = sqlite3.connect(env["db"])
    row = con.execute(
        f"SELECT ea_id,symbol,phase,generated_at_utc,evidence_sha256 FROM {ing.LEDGER_TABLE}"
    ).fetchone()
    with pytest.raises(sqlite3.IntegrityError):
        con.execute(
            f"INSERT INTO {ing.LEDGER_TABLE}(ea_id,symbol,phase,generated_at_utc,evidence_sha256,"
            "work_item_id,setfile_path,ingest_source_aggregate,ingested_at_utc) VALUES(?,?,?,?,?,?,?,?,?)",
            (*row, "dup", "s", "a", "t"),
        )
    con.close()


def test_concurrent_applies_cannot_double_insert(env):
    """Two threads race into apply(); under every interleaving the invariant
    holds: exactly one work_items row and one ledger row for the pair, and the
    two runs' inserted-id sets are disjoint with total size 1."""
    _single_pass_env(env)
    barrier = threading.Barrier(2)
    results: list[dict] = []
    lock = threading.Lock()

    def worker():
        barrier.wait()
        r = ing.apply(env["db"], env["snap"], "Q10")
        with lock:
            results.append(r)

    t1 = threading.Thread(target=worker); t2 = threading.Thread(target=worker)
    t1.start(); t2.start(); t1.join(); t2.join()

    con = sqlite3.connect(env["db"])
    assert con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 1
    assert con.execute("SELECT COUNT(*) FROM ingest_phase_aggregate_ledger").fetchone()[0] == 1
    con.close()
    total_inserted = sum(len(r["inserted_work_item_ids"]) for r in results)
    assert total_inserted == 1


def test_same_timestamp_content_change_is_surfaced_not_skipped(env):
    """An aggregate rewritten under an unchanged generated_at_utc (different
    content hash) is reported as an observation, not silently skipped."""
    ea, symbol = _single_pass_env(env, ea=30009)
    ing.apply(env["db"], env["snap"], "Q10")
    # Rewrite the aggregate: same generated_at_utc, different reason (=> new hash).
    agg = env["pipeline"] / f"QM5_{ea}" / "Q10" / symbol.replace(".", "_") / "aggregate.json"
    data = json.loads(agg.read_text(encoding="utf-8"))
    data["reason"] = "rewritten-different-content"
    agg.write_text(json.dumps(data), encoding="utf-8")
    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert result["actions"] == []
    types = {o["type"] for o in result["observations"]}
    assert "same_timestamp_content_changed" in types


# --------------------------------------------------------------------------- #
# Defect 4 — guarded revert                                                    #
# --------------------------------------------------------------------------- #

def test_revert_deletes_unmodified_rows(env):
    _single_pass_env(env)
    r = ing.apply(env["db"], env["snap"], "Q10")
    snap_path = Path(r["snapshot_path"])
    rev = ing.revert(env["db"], snap_path)
    assert len(rev["deleted"]) == 1 and rev["refused"] == []
    con = sqlite3.connect(env["db"])
    assert con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0
    assert con.execute("SELECT COUNT(*) FROM ingest_phase_aggregate_ledger").fetchone()[0] == 0
    con.close()


def test_revert_refuses_row_modified_since_ingestion(env):
    _single_pass_env(env)
    r = ing.apply(env["db"], env["snap"], "Q10")
    wid = r["inserted_work_item_ids"][0]
    con = sqlite3.connect(env["db"])
    con.execute("UPDATE work_items SET verdict='FAIL' WHERE id=?", (wid,))
    con.commit(); con.close()
    rev = ing.revert(env["db"], Path(r["snapshot_path"]))
    assert rev["deleted"] == []
    assert rev["refused"][0]["reason"] == "modified_since_ingestion"
    con = sqlite3.connect(env["db"])
    assert con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 1  # kept
    con.close()


def test_revert_refuses_row_with_downstream_candidate(env):
    _single_pass_env(env)
    r = ing.apply(env["db"], env["snap"], "Q10")
    wid = r["inserted_work_item_ids"][0]
    con = sqlite3.connect(env["db"])
    con.execute(
        "INSERT INTO portfolio_candidates(ea_id,symbol,q11_work_item_id,state,evidence_path,"
        "first_seen_at,updated_at) VALUES(?,?,?,?,?,?,?)",
        ("QM5_30001", "EURUSD.DWX", wid, "Q12_REVIEW_READY", "x", "t", "t"),
    )
    con.commit(); con.close()
    rev = ing.revert(env["db"], Path(r["snapshot_path"]))
    assert rev["deleted"] == []
    assert rev["refused"][0]["reason"].startswith("downstream_portfolio_candidates")


def test_snapshot_fingerprints_all_three_rows(env):
    """The pre-apply snapshot must carry a distinct fingerprint for each of the
    three rows a single insert creates (work_items, ea_metrics, ledger)."""
    _single_pass_env(env)
    r = ing.apply(env["db"], env["snap"], "Q10")
    snap = json.loads(Path(r["snapshot_path"]).read_text(encoding="utf-8"))
    item = snap["revert"]["items"][0]
    assert item["fingerprint"]
    assert item["ea_metrics_fingerprint"]
    assert item["ledger_fingerprint"]
    # Three distinct rows => three distinct hashes.
    assert len({item["fingerprint"], item["ea_metrics_fingerprint"],
                item["ledger_fingerprint"]}) == 3


def test_revert_refuses_when_ea_metrics_modified(env):
    """WP-2 round-3: the ea_metrics row is now independently fingerprinted. A
    post-hoc edit to it blocks the whole triple's deletion (per-row reason), so a
    modified sibling row is never destroyed by revert."""
    _single_pass_env(env)
    r = ing.apply(env["db"], env["snap"], "Q10")
    wid = r["inserted_work_item_ids"][0]
    con = sqlite3.connect(env["db"])
    con.execute("UPDATE ea_metrics SET verdict='FAIL' WHERE work_item_id=?", (wid,))
    con.commit(); con.close()
    rev = ing.revert(env["db"], Path(r["snapshot_path"]))
    assert rev["deleted"] == []
    assert rev["refused"][0]["reason"] == "ea_metrics_modified_since_ingestion"
    assert "ea_metrics_modified_since_ingestion" in rev["refused"][0]["rows_modified"]
    # The whole triple is preserved — no orphaned half-triple.
    con = sqlite3.connect(env["db"])
    assert con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 1
    assert con.execute("SELECT COUNT(*) FROM ea_metrics").fetchone()[0] == 1
    assert con.execute("SELECT COUNT(*) FROM ingest_phase_aggregate_ledger").fetchone()[0] == 1
    con.close()


def test_revert_refuses_when_ledger_modified(env):
    """WP-2 round-3: the ledger row is now independently fingerprinted. A post-hoc
    edit to it blocks the whole triple's deletion (per-row reason)."""
    _single_pass_env(env)
    r = ing.apply(env["db"], env["snap"], "Q10")
    wid = r["inserted_work_item_ids"][0]
    con = sqlite3.connect(env["db"])
    con.execute(
        f"UPDATE {ing.LEDGER_TABLE} SET setfile_path='C:\\tampered.set' WHERE work_item_id=?",
        (wid,),
    )
    con.commit(); con.close()
    rev = ing.revert(env["db"], Path(r["snapshot_path"]))
    assert rev["deleted"] == []
    assert rev["refused"][0]["reason"] == "ledger_modified_since_ingestion"
    con = sqlite3.connect(env["db"])
    assert con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 1  # nothing deleted
    con.close()


# --------------------------------------------------------------------------- #
# Defect 3 (round 2) — setfile BYTES authenticated against the run's hash      #
# --------------------------------------------------------------------------- #

def test_setfile_sha256_verified_true_when_summary_hash_matches(env):
    """When the run summary records execution_identity.setfile.source.sha256 and
    the current bytes match, the action is verified and the flag persists in the
    ingested work_items payload."""
    ea, slug, symbol = 40010, "QM5_40010_hashok", "EURUSD.DWX"
    setname = f"{slug}_{symbol}_D1_q10_confirmation.set"
    setpath = _make_setfile(env["eas"], slug, setname)
    real_sha = ing._sha256_file(setpath)
    run_tag = "20260724_090000"
    htm = _write_run(env["pipeline"], ea, slug, symbol, run_tag, "run_01", setname)
    summary = _write_summary(env["pipeline"], ea, run_tag, setpath, real_sha)
    _write_aggregate(env["pipeline"], ea, symbol, "Q10", "PASS",
                     "2026-07-24T09:00:00+00:00", htm, summary)

    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert len(result["actions"]) == 1
    assert result["actions"][0]["setfile_sha256_verified"] is True

    # The flag must survive into the persisted payload.
    r = ing.apply(env["db"], env["snap"], "Q10")
    assert len(r["inserted_work_item_ids"]) == 1
    con = sqlite3.connect(env["db"])
    payload = json.loads(con.execute("SELECT payload_json FROM work_items").fetchone()[0])
    con.close()
    assert payload["setfile_sha256_verified"] is True


def test_setfile_hash_mismatch_is_hard_refusal(env):
    """Bytes exist but MISMATCH a surviving recorded hash (setfile edited after
    the run) => hard refusal, never ingested."""
    ea, slug, symbol = 40011, "QM5_40011_hashbad", "EURUSD.DWX"
    setname = f"{slug}_{symbol}_D1_q10_confirmation.set"
    setpath = _make_setfile(env["eas"], slug, setname)
    run_tag = "20260724_091000"
    htm = _write_run(env["pipeline"], ea, slug, symbol, run_tag, "run_01", setname)
    # Recorded hash is a valid-length hex string that is NOT the current bytes'.
    summary = _write_summary(env["pipeline"], ea, run_tag, setpath, "de" * 32)
    _write_aggregate(env["pipeline"], ea, symbol, "Q10", "PASS",
                     "2026-07-24T09:10:00+00:00", htm, summary)

    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert result["actions"] == []
    assert result["refused"][0]["reason"] == "setfile_hash_mismatch"


def test_no_surviving_hash_is_refused_by_default(env):
    """No surviving hash (no summary) => REFUSE by default with
    setfile_hash_unavailable. Destruction of proof by a sibling is a reason to
    refuse, not evidence the run may be authenticated (Codex WP-2 round-3)."""
    ea, slug, symbol = 40012, "QM5_40012_nohash", "EURUSD.DWX"
    setname = f"{slug}_{symbol}_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, setname)
    run_tag = "20260724_092000"
    htm = _write_run(env["pipeline"], ea, slug, symbol, run_tag, "run_01", setname)
    # No summary.json is written for this run_tag.
    _write_aggregate(env["pipeline"], ea, symbol, "Q10", "PASS",
                     "2026-07-24T09:20:00+00:00", htm)

    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert result["actions"] == []
    assert result["refused"][0]["reason"] == "setfile_hash_unavailable"


def test_allow_unverified_ingests_flagged(env):
    """--allow-unverified is the OWNER-exception escape hatch: the same no-hash row
    is ingested with setfile_sha256_verified=false recorded (never falsely true),
    the human report shouts a loud per-row OWNER-EXCEPTION line, and the flag
    survives into the persisted work_items payload on apply(..., allow_unverified)."""
    ea, slug, symbol = 40012, "QM5_40012_nohash", "EURUSD.DWX"
    setname = f"{slug}_{symbol}_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, setname)
    run_tag = "20260724_092000"
    htm = _write_run(env["pipeline"], ea, slug, symbol, run_tag, "run_01", setname)
    _write_aggregate(env["pipeline"], ea, symbol, "Q10", "PASS",
                     "2026-07-24T09:20:00+00:00", htm)

    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now(), allow_unverified=True); con.close()
    assert len(result["actions"]) == 1
    assert result["actions"][0]["setfile_sha256_verified"] is False
    assert result["refused"] == []
    report = ing._render_human(result, dry_run=True)
    assert "OWNER-EXCEPTION" in report

    r = ing.apply(env["db"], env["snap"], "Q10", allow_unverified=True)
    assert len(r["inserted_work_item_ids"]) == 1
    con = sqlite3.connect(env["db"])
    payload = json.loads(con.execute("SELECT payload_json FROM work_items").fetchone()[0])
    con.close()
    assert payload["setfile_sha256_verified"] is False


def test_sibling_shared_summary_refused_by_default_flagged_under_allow(env):
    """The QM5_12567/XNGUSD shape: the shared/mutable summary belongs to a sibling
    run (its recorded setfile basename differs), so its hash cannot authenticate
    our setfile. By default the row is REFUSED (setfile_hash_unavailable); under
    the --allow-unverified OWNER exception it is ingested flagged, never falsely
    verified and never a spurious mismatch refusal."""
    ea, slug = 40014, "QM5_40014_sibling"
    xau_set = f"{slug}_XAUUSD.DWX_D1_q10_confirmation.set"
    xng_set = f"{slug}_XNGUSD.DWX_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, xau_set)
    xng_path = _make_setfile(env["eas"], slug, xng_set)
    run_tag = "20260724_215508"
    xng_htm = _write_run(env["pipeline"], ea, slug, "XNGUSD.DWX", run_tag, "run_02", xng_set)
    # Shared summary records the XAUUSD sibling's setfile + a real hash of the XNG
    # bytes (adversarial: right hash, wrong-identity source path).
    summary = _write_summary(
        env["pipeline"], ea, run_tag,
        env["eas"] / slug / "sets" / xau_set, ing._sha256_file(xng_path),
    )
    _write_aggregate(env["pipeline"], ea, "XNGUSD.DWX", "Q10", "PASS",
                     "2026-07-24T22:01:30+00:00", xng_htm, summary)

    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    default = ing.plan(con, "Q10", ing._utc_now())
    allowed = ing.plan(con, "Q10", ing._utc_now(), allow_unverified=True)
    con.close()
    # Default: refused, no action (recorded basename != our setfile => no hash).
    assert default["actions"] == []
    assert default["refused"][0]["reason"] == "setfile_hash_unavailable"
    # OWNER exception: ingested flagged, never falsely verified, never a mismatch.
    assert len(allowed["actions"]) == 1
    assert allowed["actions"][0]["setfile_sha256_verified"] is False
    assert allowed["refused"] == []


# --------------------------------------------------------------------------- #
# Defect 3 (round 2) — missing tester.ini Symbol must refuse                   #
# --------------------------------------------------------------------------- #

def test_tester_ini_missing_symbol_is_refused(env):
    """A run whose symbol cannot be proven from its own tester.ini (no Symbol
    line) must be refused, not ingested with a vacuous identity guard."""
    ea, slug, symbol = 40013, "QM5_40013_nosym", "EURUSD.DWX"
    setname = f"{slug}_{symbol}_D1_q10_confirmation.set"
    _make_setfile(env["eas"], slug, setname)
    run_dir = env["pipeline"] / f"QM5_{ea}" / "20260724_093000" / "raw" / "run_01"
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "report.htm").write_text("<html></html>", encoding="utf-8")
    (run_dir / "tester.ini").write_text(  # deliberately no Symbol=
        "[Tester]\n"
        f"Expert=QM\\{slug}\n"
        "Period=D1\nModel=4\n"
        f"ExpertParameters={setname}\n",
        encoding="utf-8",
    )
    _write_aggregate(env["pipeline"], ea, symbol, "Q10", "PASS",
                     "2026-07-24T09:30:00+00:00", run_dir / "report.htm")

    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q10", ing._utc_now()); con.close()
    assert result["actions"] == []
    assert result["refused"][0]["reason"] == "tester_ini_symbol_missing"


# --------------------------------------------------------------------------- #
# Defect 3 (round 2) — UTF-16 HTML evidence path must not crash                #
# --------------------------------------------------------------------------- #

def test_existing_generated_at_utf16_html_evidence_does_not_crash(env):
    """Regression for the live QM5_20002/EURUSD Q04 row 137b7aac-...: its
    evidence_path is a UTF-16 report.htm. _existing_generated_at must treat the
    non-UTF-8/non-JSON bytes as unparseable (fall back to updated_at), never raise
    UnicodeDecodeError."""
    utf16 = env["tmp"] / "report.htm"
    # UTF-16 BOM (ff fe) + UTF-16 body is invalid UTF-8 -> would raise on read.
    utf16.write_bytes("<!DOCTYPE html><html>x</html>".encode("utf-16"))
    _seed_evidence_row(env["db"], "row-utf16", "QM5_20002", "EURUSD.DWX", "Q04",
                       "PASS", utf16, "2026-07-16T17:09:25+00:00")
    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    row = con.execute("SELECT * FROM work_items WHERE id='row-utf16'").fetchone()
    con.close()
    gen = ing._existing_generated_at(row)  # must not raise
    assert gen == ing._parse_ts("2026-07-16T17:09:25+00:00")


# --------------------------------------------------------------------------- #
# Defect 4 remainder — current-shape Q04 aggregate is REFUSED, not crashed on  #
# --------------------------------------------------------------------------- #

def test_q04_current_shape_aggregate_is_refused_not_crashed(env):
    """A current-shape Q04 aggregate (symbol/verdict/generated_at_utc but NO
    report_htm — the work_items-root shape) must be REFUSED (setfile_unresolved),
    and planning must complete even when the pair's existing DB row points its
    evidence at a UTF-16 report.htm. This is the claim the re-review found false:
    the live Q04 dry-run crashed instead of refusing."""
    ea, symbol = 10076, "GDAXI.DWX"
    # The UTF-16 evidence landmine on the SAME (ea, symbol) pair the candidate
    # supersedes (planning visits it via _existing_generated_at).
    utf16 = env["tmp"] / "q04_report.htm"
    utf16.write_bytes("<!DOCTYPE html><html></html>".encode("utf-16"))
    _seed_evidence_row(env["db"], "q04-existing", f"QM5_{ea}", symbol, "Q04",
                       "PASS", utf16, "2026-07-16T00:00:00+00:00")

    # A discoverable current-shape Q04 aggregate under the work_items root
    # (**/Q04/*/aggregate.json), newer + a different verdict than the DB row.
    q04_dir = (env["tmp"] / "work_items" / "task-uuid" / f"QM5_{ea}" / "Q04" / symbol.replace(".", "_"))
    q04_dir.mkdir(parents=True, exist_ok=True)
    (q04_dir / "aggregate.json").write_text(json.dumps({
        "ea": f"QM5_{ea}", "ea_id": ea, "phase": "Q04",
        "symbol": symbol, "runner_symbol": symbol,
        "verdict": "INVALID", "generated_at_utc": "2026-07-17T00:00:00+00:00",
        "reason": "current-shape Q04, no report_htm", "folds": [],
    }), encoding="utf-8")

    con = sqlite3.connect(env["db"]); con.row_factory = sqlite3.Row
    result = ing.plan(con, "Q04", ing._utc_now())  # must not raise
    con.close()
    assert result["actions"] == []
    reasons = {(r["ea_id"], r["symbol"]): r["reason"] for r in result["refused"]}
    assert reasons.get((f"QM5_{ea}", symbol)) == "setfile_unresolved"
