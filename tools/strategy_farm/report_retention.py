"""DL-090 backtest report retention.

Authority: ``decisions/DL-090_backtest_report_retention_policy.md`` (OWNER-ratified
2026-08-23, "B' + C").

**Keep indefinitely**
  1. every run of the PASS family (``PASS``, ``PASS_SOFT``, ``PASS_LOWFREQ``,
     ``PASS_PORTFOLIO``), superseded attempts included — after a rebuild the earlier PASS
     is exactly the comparison evidence;
  2. every *standing rejection*: the latest run per ``(ea_id, symbol, gate)`` whose
     clean-view taxonomy is ``strategy`` and whose verdict is not a PASS. While that run
     makes an archive cell red, it must stay auditable at trade level.

**Age out** everything else — superseded attempts of an already-rejected cell and every
run whose taxonomy is ``infra`` or ``invalid``. A burnt run carries no judgement and is
never evidence for anything.

**Compress** the kept set once it is older than the same window.

This job never deletes a database row. Ageing out an artifact does not delete the run:
``work_items`` and the extracted numbers in ``ea_metrics`` remain permanently.

``*.log`` journals are OUT OF SCOPE — ``reports_log_purge.ps1`` and
``prune_workitem_logs.py`` keep their 12 h window, and this policy must never be used as
a disk-pressure control.

Usage::

    python tools/strategy_farm/report_retention.py --dry-run
    python tools/strategy_farm/report_retention.py --quarantine-only
    python tools/strategy_farm/report_retention.py --apply
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import json
import os
import re
import shutil
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from work_item_clean_view import open_clean_view_connection  # noqa: E402

FARM_ROOT = Path(r"D:\QM\strategy_farm")
DB = FARM_ROOT / "state" / "farm_state.sqlite"
REPORTS = Path(r"D:\QM\reports")
REPORT_ROOTS = (REPORTS / "work_items", REPORTS / "pipeline")
QUARANTINE = REPORTS / "_retention_quarantine"
LOG = REPORTS / "state" / "report_retention.log"

# Paths this job must never walk, whatever a future config says.
FORBIDDEN = (Path(r"C:\QM\mt5\T_Live"), REPORTS / "state", REPO_ROOT / "decisions")

MIN_AGE_DAYS = 30
COMPRESS_AFTER_DAYS = 30
ARTIFACT_SUFFIXES = (".htm", ".html", ".json", ".ini", ".set", ".gz")
KEEP_UNCOMPRESSED = (".ini", ".set")          # tiny, and read by tooling
OPEN_STATES = ("pending", "active", "claimed")


def now_iso() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def log(msg: str) -> None:
    line = f"{now_iso()} {msg}"
    print(line)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def classify(db: Path = DB) -> dict:
    """Return the kept / aged-out work-item id sets, recomputed from scratch.

    The standing rejection is recomputed on every run — a cell that flips to PASS, or
    whose rejection is superseded by a newer attempt, changes which artifact is
    protected.
    """
    conn = open_clean_view_connection(db)
    rows = list(conn.execute(
        "SELECT id, ea_id, symbol, phase, verdict, verdict_taxonomy, status, updated_at "
        "FROM work_items_clean WHERE ea_id IS NOT NULL"))
    conn.close()

    keep: set[str] = set()
    open_runs: set[str] = set()
    latest: dict[tuple[str, str, str], tuple[str, str, str, str]] = {}
    seen: set[str] = set()

    for wid, ea, sym, phase, verdict, tax, status, upd in rows:
        seen.add(wid)
        v = (verdict or "").upper()
        if (status or "").lower() in OPEN_STATES:
            open_runs.add(wid)
        if v.startswith("PASS"):
            keep.add(wid)                                    # rule 1
        gate = "Q09" if (phase or "").startswith("Q09") else (phase or "")
        key = (ea, (sym or "").strip() or "BASKET", gate)
        cur = latest.get(key)
        if cur is None or (upd or "") > cur[0]:
            latest[key] = ((upd or ""), wid, v, tax or "")

    for _upd, wid, v, tax in latest.values():                # rule 2
        if tax == "strategy" and not v.startswith("PASS"):
            keep.add(wid)

    keep |= open_runs        # a run still in flight is never touched
    return {"keep": keep, "known": seen, "open": open_runs,
            "aged_out": seen - keep, "cells": len(latest)}


_UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)


def _work_item_of(path: Path) -> str | None:
    """Work-item id from the artifact path.

    Segments carry suffixes in practice (``<uuid>.requeued_2026...``, ``<symbol>__<uuid>``),
    so match the uuid anywhere in the segment rather than requiring an exact length.
    Artifacts under ``reports/pipeline/<EA>/<timestamp>/`` carry no id at all — those are
    reported as unattributable and always KEPT.
    """
    for seg in str(path).replace("\\", "/").split("/"):
        m = _UUID.search(seg)
        if m:
            return m.group(0)
    return None


def _forbidden(path: Path) -> bool:
    rp = str(path).lower()
    return any(str(f).lower() in rp for f in FORBIDDEN)


def scan(cutoff: dt.datetime) -> dict:
    """Walk the report roots once and bucket artifacts by work item."""
    by_item: dict[str, list[tuple[Path, float, int]]] = defaultdict(list)
    unattributed = 0
    for base in REPORT_ROOTS:
        if not base.is_dir():
            continue
        for root, _dirs, files in os.walk(base):
            rootp = Path(root)
            if _forbidden(rootp):
                continue
            for f in files:
                if not f.lower().endswith(ARTIFACT_SUFFIXES):
                    continue
                p = rootp / f
                try:
                    st = p.stat()
                except OSError:
                    continue
                wid = _work_item_of(p)
                if wid is None:
                    unattributed += 1
                    continue
                by_item[wid].append((p, st.st_mtime, st.st_size))
    return {"by_item": by_item, "unattributed": unattributed, "cutoff": cutoff}


def run(mode: str) -> int:
    started = dt.datetime.now(dt.UTC)
    cutoff = started - dt.timedelta(days=MIN_AGE_DAYS)
    cutoff_ts = cutoff.timestamp()

    cls = classify()
    if not cls["known"]:
        log("ABORT: classification empty — refusing to touch any artifact (fail-closed)")
        return 2
    sc = scan(cutoff)
    by_item = sc["by_item"]

    stats = Counter()
    bytes_ = Counter()
    to_remove: list[Path] = []
    to_compress: list[Path] = []

    for wid, entries in by_item.items():
        if wid not in cls["known"]:
            # Fail-closed: an artifact we cannot classify is KEPT and reported.
            stats["unclassifiable_items"] += 1
            for p, _m, s in entries:
                stats["unclassifiable_files"] += 1
                bytes_["unclassifiable"] += s
            continue
        kept = wid in cls["keep"]
        for p, mtime, size in entries:
            if mtime > cutoff_ts:
                stats["too_young"] += 1
                bytes_["too_young"] += size
                continue
            if kept:
                if p.suffix.lower() in KEEP_UNCOMPRESSED or p.suffix.lower() == ".gz":
                    stats["kept_asis"] += 1
                    bytes_["kept_asis"] += size
                else:
                    to_compress.append(p)
                    stats["kept_compress"] += 1
                    bytes_["kept_compress"] += size
            else:
                to_remove.append(p)
                stats["age_out"] += 1
                bytes_["age_out"] += size

    def gb(n: int) -> str:
        return f"{n / 1073741824:.2f} GB"

    log(f"CLASSIFY runs={len(cls['known']):,} keep={len(cls['keep']):,} "
        f"age_out={len(cls['aged_out']):,} open={len(cls['open']):,} cells={cls['cells']:,}")
    log(f"SCAN items={len(by_item):,} unattributed_files={sc['unattributed']:,} "
        f"cutoff={cutoff.date().isoformat()} ({MIN_AGE_DAYS}d)")
    log(f"PLAN remove={stats['age_out']:,} ({gb(bytes_['age_out'])}) "
        f"compress={stats['kept_compress']:,} ({gb(bytes_['kept_compress'])}) "
        f"keep_asis={stats['kept_asis']:,} too_young={stats['too_young']:,} "
        f"unclassifiable_files={stats['unclassifiable_files']:,} "
        f"({gb(bytes_['unclassifiable'])})")

    if mode == "dry-run":
        log("DRY-RUN: nothing written")
        return 0

    # ── quarantine, then (optionally) delete ──────────────────────────
    stamp = started.strftime("%Y%m%dT%H%M%SZ")
    qdir = QUARANTINE / stamp
    moved = 0
    moved_bytes = 0
    for p in to_remove:
        try:
            rel = p.relative_to(REPORTS)
        except ValueError:
            continue
        dest = qdir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            size = p.stat().st_size
            shutil.move(str(p), str(dest))
            moved += 1
            moved_bytes += size
        except OSError as exc:
            log(f"WARN move failed {p}: {exc}")
    log(f"QUARANTINED {moved:,} files ({gb(moved_bytes)}) -> {qdir}")

    compressed = 0
    saved = 0
    if mode == "apply":
        for p in to_compress:
            gzp = p.with_suffix(p.suffix + ".gz")
            try:
                before = p.stat().st_size
                with p.open("rb") as src, gzip.open(gzp, "wb", compresslevel=6) as dst:
                    shutil.copyfileobj(src, dst)
                after = gzp.stat().st_size
                p.unlink()
                compressed += 1
                saved += before - after
            except OSError as exc:
                log(f"WARN compress failed {p}: {exc}")
                if gzp.exists():
                    try:
                        gzp.unlink()
                    except OSError:
                        pass
        log(f"COMPRESSED {compressed:,} files, saved {gb(saved)}")

    log(f"DONE mode={mode} elapsed={(dt.datetime.now(dt.UTC) - started).total_seconds():.0f}s")
    print(json.dumps({"mode": mode, "keep": len(cls["keep"]), "age_out": len(cls["aged_out"]),
                      "quarantined_files": moved, "quarantined_bytes": moved_bytes,
                      "compressed_files": compressed, "compress_saved_bytes": saved,
                      "unclassifiable_files": stats["unclassifiable_files"],
                      "quarantine_dir": str(qdir)}, indent=1))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="DL-090 backtest report retention")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", help="classify and report, write nothing")
    g.add_argument("--quarantine-only", action="store_true",
                   help="move aged-out artifacts to quarantine, do not compress")
    g.add_argument("--apply", action="store_true",
                   help="quarantine aged-out artifacts AND compress the kept set")
    args = ap.parse_args()
    mode = "apply" if args.apply else ("quarantine" if args.quarantine_only else "dry-run")
    return run(mode)


if __name__ == "__main__":
    raise SystemExit(main())
