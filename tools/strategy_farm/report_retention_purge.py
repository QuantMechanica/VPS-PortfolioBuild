"""DL-090 implementing job: classify and age out D:\\QM\\reports\\work_items\\**.

Decision: decisions/DL-090_backtest_report_retention_policy.md (OWNER-ratified
2026-08-23). This script is the "implementing job" that decision commissions
as router task b24d7875.

Rule (DL-090 S2):
  KEEP indefinitely  - every run whose verdict_taxonomy == 'strategy' and
                       verdict startswith PASS/PASS_SOFT/PASS_LOWFREQ/
                       PASS_PORTFOLIO (the PASS family, including superseded
                       attempts); and the newest run per (ea_id, symbol, phase)
                       whose verdict_taxonomy == 'strategy' and verdict is NOT
                       a PASS (the standing rejection).
  AGE OUT (>=30d)    - every other 'strategy' row (superseded non-PASS
                       attempts) and every row whose taxonomy is 'infra' or
                       'invalid'.
  KEEP (unclassified)- everything else (review/governance/draft_defect/
                       measurement/open/unknown) is kept: DL-090 S4.1 requires
                       "never delete without a live classification" and these
                       taxonomies are not named by the rule.
  COMPRESS (>=30d)   - the kept set, in place, once old enough.

Fail-closed per DL-090 S4:
  1. Unclassifiable / DB-unreachable -> keep, report it, never delete.
  2. Quarantine before deletion (move, don't unlink), with a --dry-run that
     prints the full delta and a separate reap step for the actual removal.
  3. Never traverses C:\\QM\\mt5\\T_Live, live-book evidence, decisions/, or
     D:\\QM\\reports\\state (this script only ever reads
     D:\\QM\\reports\\work_items\\** paths taken from evidence_path in the DB).
  4. Reports what it removed, per class and in bytes, to a log next to the
     other purge logs.
  5. Standing rejection is recomputed every run from the live DB - never
     cached.
  6. A row still pending/active/claimed is never touched (clean view 'open'
     taxonomy is always kept, and additionally reports must be file-locked to
     the OPEN_STATUSES check, not just the phase name).

Actions are dry-run by default. Pass --execute to actually quarantine/reap/
compress; --classify-only never touches the filesystem regardless of --execute.
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import json
import shutil
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from work_item_clean_view import (  # noqa: E402
    CLEAN_VIEW_NAME,
    OPEN_STATUSES,
    open_clean_view_connection,
)

DB_PATH_DEFAULT = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
REPORTS_ROOT = Path("D:/QM/reports/work_items")
QUARANTINE_ROOT = Path("D:/QM/reports/_purge_quarantine/report_retention")
LOG_PATH = Path("D:/QM/reports/state/report_retention_purge.log")

# DL-090 S2.1: the PASS family, matched by prefix so PASS_SOFT/PASS_LOWFREQ/
# PASS_PORTFOLIO (and any future PASS_* variant) are included without a
# maintained enum.
PASS_PREFIX = "PASS"

# DL-090 S2, "artifact set per kept run".
KEPT_ARTIFACT_SUFFIXES = (".htm", ".html", ".json", ".ini", ".set")

# Never touched regardless of what a DB row claims (DL-090 S4.3).
FORBIDDEN_PREFIXES = (
    Path("C:/QM/mt5/T_Live"),
    Path("D:/QM/reports/state"),
    REPO_ROOT / "decisions",
)

MIN_AGE_DAYS_DEFAULT = 30
QUARANTINE_REAP_DAYS_DEFAULT = 30


def _log(msg: str) -> None:
    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    line = f"{stamp} {msg}"
    print(line)
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def _run_dir_for_evidence(evidence_path: str) -> Path | None:
    if not evidence_path:
        return None
    p = Path(evidence_path)
    try:
        resolved = p.resolve()
    except OSError:
        return None
    for forbidden in FORBIDDEN_PREFIXES:
        try:
            resolved.relative_to(forbidden.resolve())
            return None
        except ValueError:
            continue
    try:
        resolved.relative_to(REPORTS_ROOT.resolve())
    except ValueError:
        return None
    return resolved.parent


def _dir_bytes(d: Path) -> int:
    total = 0
    for f in d.rglob("*"):
        if f.is_file():
            try:
                total += f.stat().st_size
            except OSError:
                pass
    return total


def _age_days(updated_at: str, now: dt.datetime) -> float:
    try:
        stamp = dt.datetime.fromisoformat(str(updated_at).replace("Z", "+00:00"))
        if stamp.tzinfo is None:
            stamp = stamp.replace(tzinfo=dt.UTC)
    except (TypeError, ValueError):
        return -1.0
    return (now - stamp).total_seconds() / 86400.0


def classify(db_path: Path) -> dict[str, Any]:
    """Read-only pass. Returns per-class row lists (dicts with dir/bytes/age)."""

    now = dt.datetime.now(dt.UTC)
    connection = open_clean_view_connection(db_path)
    try:
        connection.row_factory = None
        rows = connection.execute(
            f"SELECT id, ea_id, symbol, phase, status, verdict, verdict_taxonomy, "
            f"evidence_path, updated_at FROM {CLEAN_VIEW_NAME} "
            f"WHERE evidence_path IS NOT NULL"
        ).fetchall()
    finally:
        connection.close()

    cols = ["id", "ea_id", "symbol", "phase", "status", "verdict", "verdict_taxonomy",
            "evidence_path", "updated_at"]
    items: list[dict[str, Any]] = []
    for row in rows:
        rec = dict(zip(cols, row))
        run_dir = _run_dir_for_evidence(rec["evidence_path"])
        if run_dir is None or not run_dir.is_dir():
            continue
        # The native MT5 report lives under <run_dir>/raw/run_NN/report.htm for
        # backtest phases; some phases (e.g. Q04 aggregate rollups) have only
        # aggregate.json with no native report and are correctly excluded here.
        has_report = any(run_dir.rglob("report.htm")) or any(run_dir.rglob("report.html"))
        if not has_report:
            continue
        rec["run_dir"] = run_dir
        rec["age_days"] = _age_days(rec["updated_at"], now)
        items.append(rec)

    # DL-090 S2.2 "standing rejection" = newest 'strategy' non-PASS row per
    # (ea_id, symbol, phase). Recomputed every run (S4.5), never cached.
    strategy_nonpass_groups: dict[tuple[str, str, str], list[dict[str, Any]]] = defaultdict(list)

    classes: dict[str, list[dict[str, Any]]] = {
        "keep_pass_family": [],
        "keep_standing_rejection": [],
        "keep_unclassified_taxonomy": [],
        "skip_open_status": [],
        "age_out_superseded_strategy": [],
        "age_out_infra_invalid": [],
    }

    for rec in items:
        status = str(rec["status"] or "")
        taxonomy = str(rec["verdict_taxonomy"] or "")
        verdict = str(rec["verdict"] or "")

        if status in OPEN_STATUSES:
            classes["skip_open_status"].append(rec)
            continue
        if taxonomy == "strategy":
            if verdict.upper().startswith(PASS_PREFIX):
                classes["keep_pass_family"].append(rec)
            else:
                key = (str(rec["ea_id"]), str(rec["symbol"]), str(rec["phase"]))
                strategy_nonpass_groups[key].append(rec)
            continue
        if taxonomy in ("infra", "invalid"):
            classes["age_out_infra_invalid"].append(rec)
            continue
        classes["keep_unclassified_taxonomy"].append(rec)

    for _key, group in strategy_nonpass_groups.items():
        group.sort(key=lambda r: str(r["updated_at"]))
        standing = group[-1]
        classes["keep_standing_rejection"].append(standing)
        for superseded in group[:-1]:
            classes["age_out_superseded_strategy"].append(superseded)

    return {"classes": classes, "generated_at_utc": now.isoformat(), "total_rows_seen": len(items)}


def summarize(result: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for cls, recs in result["classes"].items():
        total_bytes = sum(_dir_bytes(r["run_dir"]) for r in recs)
        out[cls] = {"count": len(recs), "bytes": total_bytes}
    return out


def quarantine(result: dict[str, Any], min_age_days: float, execute: bool) -> dict[str, Any]:
    """Move eligible age_out dirs (age >= min_age_days) into QUARANTINE_ROOT."""

    eligible: list[dict[str, Any]] = []
    for cls in ("age_out_infra_invalid", "age_out_superseded_strategy"):
        for rec in result["classes"][cls]:
            if rec["age_days"] < 0 or rec["age_days"] < min_age_days:
                continue
            eligible.append(rec)

    moved = 0
    moved_bytes = 0
    skipped_missing = 0
    today = dt.datetime.now(dt.UTC).strftime("%Y%m%d")
    for rec in eligible:
        src = rec["run_dir"]
        if not src.is_dir():
            skipped_missing += 1
            continue
        size = _dir_bytes(src)
        dest = QUARANTINE_ROOT / today / rec["id"]
        if execute:
            dest.parent.mkdir(parents=True, exist_ok=True)
            try:
                shutil.move(str(src), str(dest))
            except OSError as exc:
                _log(f"QUARANTINE_FAIL id={rec['id']} src={src} err={exc}")
                continue
        moved += 1
        moved_bytes += size

    verb = "QUARANTINED" if execute else "DRYRUN would quarantine"
    _log(
        f"{verb} {moved} run dir(s) (~{round(moved_bytes / 1e9, 3)}GB), "
        f"{skipped_missing} already missing, min_age_days={min_age_days}"
    )
    return {"moved": moved, "moved_bytes": moved_bytes, "skipped_missing": skipped_missing}


def reap_quarantine(reap_days: float, execute: bool) -> dict[str, Any]:
    """Delete quarantined run dirs older than reap_days (by dated parent folder)."""

    if not QUARANTINE_ROOT.is_dir():
        _log("REAP skip: quarantine root absent, nothing to reap")
        return {"deleted": 0, "deleted_bytes": 0}

    now = dt.datetime.now(dt.UTC)
    deleted = 0
    deleted_bytes = 0
    for date_dir in QUARANTINE_ROOT.iterdir():
        if not date_dir.is_dir():
            continue
        try:
            stamped = dt.datetime.strptime(date_dir.name, "%Y%m%d").replace(tzinfo=dt.UTC)
        except ValueError:
            continue
        age = (now - stamped).total_seconds() / 86400.0
        if age < reap_days:
            continue
        for run_dir in date_dir.iterdir():
            size = _dir_bytes(run_dir) if run_dir.is_dir() else 0
            if execute:
                try:
                    shutil.rmtree(run_dir)
                except OSError as exc:
                    _log(f"REAP_FAIL {run_dir} err={exc}")
                    continue
            deleted += 1
            deleted_bytes += size
        if execute:
            try:
                date_dir.rmdir()
            except OSError:
                pass

    verb = "REAPED" if execute else "DRYRUN would reap"
    _log(f"{verb} {deleted} quarantined run dir(s) (~{round(deleted_bytes / 1e9, 3)}GB), reap_days={reap_days}")
    return {"deleted": deleted, "deleted_bytes": deleted_bytes}


def compress_kept(result: dict[str, Any], min_age_days: float, execute: bool) -> dict[str, Any]:
    """Gzip the kept-set artifact files in place once old enough."""

    kept_classes = ("keep_pass_family", "keep_standing_rejection")
    compressed = 0
    compressed_bytes_before = 0
    compressed_bytes_after = 0
    already_done = 0
    for cls in kept_classes:
        for rec in result["classes"][cls]:
            if rec["age_days"] < 0 or rec["age_days"] < min_age_days:
                continue
            run_dir = rec["run_dir"]
            if not run_dir.is_dir():
                continue
            for f in list(run_dir.rglob("*")):
                if not f.is_file() or f.suffix == ".gz":
                    continue
                if f.suffix not in KEPT_ARTIFACT_SUFFIXES:
                    continue
                gz_path = f.with_suffix(f.suffix + ".gz")
                if gz_path.exists():
                    already_done += 1
                    continue
                size_before = f.stat().st_size
                if execute:
                    try:
                        with f.open("rb") as src, gzip.open(gz_path, "wb") as dst:
                            shutil.copyfileobj(src, dst)
                        size_after = gz_path.stat().st_size
                        f.unlink()
                    except OSError as exc:
                        _log(f"COMPRESS_FAIL {f} err={exc}")
                        continue
                else:
                    size_after = size_before  # unknown until actually gzipped
                compressed += 1
                compressed_bytes_before += size_before
                compressed_bytes_after += size_after

    verb = "COMPRESSED" if execute else "DRYRUN would compress"
    _log(
        f"{verb} {compressed} file(s) in kept set "
        f"(~{round(compressed_bytes_before / 1e9, 3)}GB -> ~{round(compressed_bytes_after / 1e9, 3)}GB), "
        f"{already_done} already compressed, min_age_days={min_age_days}"
    )
    return {"compressed": compressed, "before_bytes": compressed_bytes_before, "after_bytes": compressed_bytes_after}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DB_PATH_DEFAULT)
    parser.add_argument("--min-age-days", type=float, default=MIN_AGE_DAYS_DEFAULT)
    parser.add_argument("--quarantine-reap-days", type=float, default=QUARANTINE_REAP_DAYS_DEFAULT)
    parser.add_argument("--classify-only", action="store_true", help="Report only, never touch the filesystem.")
    parser.add_argument("--execute", action="store_true", help="Actually quarantine/reap/compress; default is dry-run.")
    parser.add_argument("--output", type=Path, help="Write the classification summary JSON here.")
    args = parser.parse_args()

    try:
        result = classify(args.db)
    except Exception as exc:  # fail closed: unreachable DB -> do nothing, report it
        _log(f"CLASSIFY_FAIL db={args.db} err={exc} -- no filesystem action taken")
        print(json.dumps({"error": str(exc), "action": "none_taken_fail_closed"}, indent=2))
        return 2

    summary = summarize(result)
    summary["generated_at_utc"] = result["generated_at_utc"]
    summary["total_rows_seen"] = result["total_rows_seen"]
    rendered = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    print(rendered, end="")

    if args.classify_only:
        return 0

    quarantine(result, args.min_age_days, execute=args.execute)
    reap_quarantine(args.quarantine_reap_days, execute=args.execute)
    compress_kept(result, args.min_age_days, execute=args.execute)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
