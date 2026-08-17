"""Forward observation of evidence survival — the cohort watcher.

WHY THIS EXISTS
---------------
Roughly 35,900 verdicts in this farm carry a PASS/FAIL-family result whose backing
`summary.json` provably existed at grading time (the verdict was derived from it) and is now
gone. The deleting mechanism was searched for and NOT found: both PowerShell purges are
file-scoped to `*.log`, `prune_workitem_logs.py` keeps every summary/report, `rollback_batch.py`
touches `framework/EAs`, the requeue-archive rename accounts for 6 rows, the path convention is
identical across months, and 83% of the absent rows carry a productive verdict so
"never written" does not explain them.

Measured once, a one-off deletion and a rolling retention are INDISTINGUISHABLE: an
age-triggered rule always leaves the newest cohort looking clean. So a snapshot cannot answer
"is it still happening" — only forward observation can. This tool records a named cohort of
report roots that exist TODAY and re-checks them on every later run. If deletion is ongoing,
these rows are where it shows up first, and it shows up BEFORE the evidence is needed.

It is deliberately dumb: it records paths, it re-checks paths, it never deletes anything and
never writes to the farm database. The baseline lives in the repo (git-tracked, so a loss is
itself visible in a diff) and can be mirrored off-host.

USAGE
    python tools/strategy_farm/evidence_cohort_watch.py --init      # create/extend baseline
    python tools/strategy_farm/evidence_cohort_watch.py             # check (default)
    python tools/strategy_farm/evidence_cohort_watch.py --json      # machine-readable

EXIT CODES
    0  no loss observed
    3  LOSS OBSERVED — at least one baselined root disappeared
    1  usage/IO error
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sqlite3
import sys
from pathlib import Path

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
BASELINE = Path(r"C:\QM\repo\artifacts\evidence_cohort_baseline.json")
LOG = Path(r"D:\QM\strategy_farm\logs\evidence_cohort_watch.log")

# Rows worth watching: a productive verdict proves the evidence existed, and these phases are
# the ones a delivery decision would later have to cite.
PRODUCTIVE = (
    "PASS", "FAIL", "PASS_SOFT", "FAIL_SOFT", "PASS_LOWFREQ",
    "FAIL_HARD", "PASS_PORTFOLIO", "FAIL_PORTFOLIO", "ZERO_TRADES",
)
SAMPLE_PER_DAY = 40


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def log(msg: str) -> None:
    line = f"{utc_now()} {msg}"
    print(line)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def load_baseline() -> dict:
    if not BASELINE.exists():
        return {
            "schema": "qm.evidence-cohort-baseline/v1",
            "purpose": ("forward observation of evidence survival; a snapshot cannot "
                        "distinguish a one-off deletion from a rolling retention"),
            "created_at_utc": utc_now(),
            "entries": {},
            "observations": [],
        }
    return json.loads(BASELINE.read_text(encoding="utf-8"))


def save_baseline(data: dict) -> None:
    BASELINE.parent.mkdir(parents=True, exist_ok=True)
    tmp = BASELINE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=1), encoding="utf-8")
    tmp.replace(BASELINE)


def collect_candidates() -> list[dict]:
    """Rows whose evidence exists RIGHT NOW, sampled across recent days."""
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=20)
    con.row_factory = sqlite3.Row
    placeholders = ",".join("?" * len(PRODUCTIVE))
    rows = con.execute(
        "SELECT id, ea_id, symbol, phase, verdict, updated_at, evidence_path "
        "FROM work_items WHERE status IN ('done','failed') "
        f"AND verdict IN ({placeholders}) "
        "AND evidence_path IS NOT NULL AND evidence_path<>'' "
        "AND updated_at>=? ORDER BY updated_at DESC",
        (*PRODUCTIVE,
         (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=30)).strftime("%Y-%m-%d")),
    ).fetchall()
    con.close()

    per_day: dict[str, int] = {}
    out: list[dict] = []
    for r in rows:
        day = r["updated_at"][:10]
        if per_day.get(day, 0) >= SAMPLE_PER_DAY:
            continue
        p = r["evidence_path"]
        if not os.path.exists(p):
            continue
        # The report ROOT is what vanishes, so watch the root as well as the file.
        root = None
        parts = Path(p).parts
        if "work_items" in parts:
            i = parts.index("work_items")
            if len(parts) > i + 1:
                root = str(Path(*parts[: i + 2]))
        per_day[day] = per_day.get(day, 0) + 1
        out.append({
            "work_item_id": r["id"], "ea_id": r["ea_id"], "symbol": r["symbol"],
            "phase": r["phase"], "verdict": r["verdict"],
            "row_updated_at": r["updated_at"], "evidence_path": p, "report_root": root,
        })
    return out


def cmd_init() -> int:
    data = load_baseline()
    entries: dict = data["entries"]
    added = 0
    for c in collect_candidates():
        if c["work_item_id"] in entries:
            continue
        c["baselined_at_utc"] = utc_now()
        c["evidence_present_at_baseline"] = True
        entries[c["work_item_id"]] = c
        added += 1
    data["entries"] = entries
    data["last_init_utc"] = utc_now()
    save_baseline(data)
    log(f"COHORT_INIT added={added} total_watched={len(entries)} baseline={BASELINE}")
    return 0


def cmd_check(as_json: bool) -> int:
    data = load_baseline()
    entries: dict = data.get("entries", {})
    if not entries:
        log("COHORT_CHECK baseline is EMPTY — run --init first (nothing is being watched)")
        return 1

    lost_file, lost_root, intact = [], [], 0
    for wid, e in entries.items():
        f_ok = os.path.exists(e["evidence_path"])
        r_ok = os.path.exists(e["report_root"]) if e.get("report_root") else None
        if not f_ok:
            rec = dict(e)
            rec["observed_missing_at_utc"] = utc_now()
            rec["report_root_still_present"] = bool(r_ok)
            (lost_root if r_ok is False else lost_file).append(rec)
        else:
            intact += 1

    lost = lost_file + lost_root
    obs = {
        "checked_at_utc": utc_now(),
        "watched": len(entries),
        "intact": intact,
        "evidence_file_missing": len(lost_file),
        "whole_report_root_missing": len(lost_root),
    }
    data.setdefault("observations", []).append(obs)
    if lost:
        data.setdefault("losses", []).extend(lost)
    save_baseline(data)

    if as_json:
        print(json.dumps({**obs, "losses": lost[:50]}, indent=1))
    else:
        log("COHORT_CHECK watched=%d intact=%d file_missing=%d root_missing=%d"
            % (len(entries), intact, len(lost_file), len(lost_root)))
        for rec in lost[:20]:
            log("  LOST %s %s %s %s verdict=%s row_at=%s root_present=%s"
                % (rec["work_item_id"][:8], rec["ea_id"], rec["symbol"], rec["phase"],
                   rec["verdict"], rec["row_updated_at"][:10], rec["report_root_still_present"]))

    if lost:
        log("COHORT_CHECK RESULT=LOSS_OBSERVED — evidence deletion is ONGOING, not historical. "
            "The oldest baselined row that vanished dates the retention window.")
        return 3
    log("COHORT_CHECK RESULT=NO_LOSS — no baselined evidence has disappeared yet. This is not "
        "proof that nothing deletes; it means nothing has crossed the threshold during the "
        "observed span.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--init", action="store_true", help="create or extend the watched cohort")
    ap.add_argument("--json", action="store_true", help="machine-readable check output")
    a = ap.parse_args()
    try:
        return cmd_init() if a.init else cmd_check(a.json)
    except sqlite3.Error as exc:
        log(f"COHORT_ERROR sqlite: {exc}")
        return 1
    except OSError as exc:
        log(f"COHORT_ERROR io: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
