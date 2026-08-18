#!/usr/bin/env python3
"""Mechanical pre-screen for `build_ea` tasks sitting in REVIEW.

The review gate (v6 E3 / point 1.11) exists to keep defective EAs out of the pipeline, and the
defect classes that have actually produced false pipeline verdicts here are mechanical and
checkable: a stale `.ex5`, a magic row that disagrees with the setfile's slot, a strategy input
that is declared and never read, a missing setfile. Reading 58 EAs by hand to find those is the
wrong use of the reading; this screens all of them so the reading goes where it is needed.

What this is NOT: it does not judge whether the code implements its Strategy Card. That still
requires a human read, and a clean screen here is a necessary condition for closing a review, never
a sufficient one.

Checks, each with its own reason token:

  artifacts_present   .mq5 and .ex5 both exist
  ex5_fresh           .ex5 is not older than its .mq5 (the stale-binary class, 2026-08-17)
  magic_rows          active rows exist in magic_numbers.csv for the ea_id
  slot_conflation     every setfile's qm_magic_slot_offset equals that symbol's registry
                      symbol_slot -- the check that caught 7 EAs on 2026-08-16
  setfiles_present    one setfile per active registry symbol
  risk_mode           backtest setfiles carry RISK_FIXED > 0 (Hard Rule: RISK_FIXED for backtest)
  unwired_inputs      an input declared in the .mq5, referenced nowhere else in it, and unknown to
                      the framework includes -- i.e. a knob that does nothing (QM5_1355 class)
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import sqlite3
from collections import defaultdict
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
MAGIC_CSV = REPO / "framework" / "registry" / "magic_numbers.csv"
INCLUDES = REPO / "framework" / "include" / "QM"
SCHEMA = "qm.build-review-prescreen/v1"

INPUT_RE = re.compile(r"^\s*(?:input|sinput)\s+\w+\s+(\w+)", re.MULTILINE)
SETVAL_RE = re.compile(r"^\s*(\w+)\s*=\s*(.*?)\s*$", re.MULTILINE)


def registry_rows() -> dict[str, list[dict[str, str]]]:
    rows: dict[str, list[dict[str, str]]] = defaultdict(list)
    with MAGIC_CSV.open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            if (row.get("status") or "").strip().lower() == "active":
                rows[(row.get("ea_id") or "").strip()].append(row)
    return rows


def framework_input_names() -> set[str]:
    """Every identifier the framework includes reference, so EA-local inputs they consume
    are not mistaken for dead knobs."""
    names: set[str] = set()
    for path in INCLUDES.glob("*.mqh"):
        try:
            names.update(re.findall(r"\b(\w+)\b", path.read_text(encoding="utf-8", errors="replace")))
        except OSError:
            continue
    return names


def parse_setfile(path: Path) -> dict[str, str]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    return {m.group(1): m.group(2) for m in SETVAL_RE.finditer(text)
            if not m.group(1).startswith(";")}


def screen(ea_id: str, slug: str, reg: list[dict[str, str]], fw_names: set[str]) -> dict[str, Any]:
    problems: list[str] = []
    notes: list[str] = []
    ea_dir = REPO / "framework" / "EAs" / f"QM5_{ea_id}_{slug}"
    if not ea_dir.is_dir():
        return {"ea_id": ea_id, "slug": slug, "ok": False, "problems": ["ea_dir_missing"], "notes": []}

    mq5 = ea_dir / f"QM5_{ea_id}_{slug}.mq5"
    ex5 = ea_dir / f"QM5_{ea_id}_{slug}.ex5"
    if not mq5.exists():
        problems.append("mq5_missing")
    if not ex5.exists():
        problems.append("ex5_missing")
    if mq5.exists() and ex5.exists() and ex5.stat().st_mtime < mq5.stat().st_mtime:
        problems.append("ex5_older_than_mq5")

    if not reg:
        problems.append("no_active_magic_rows")
    else:
        notes.append(f"magic_rows={len(reg)}")

    slot_by_symbol = {(r.get("symbol") or "").strip(): (r.get("symbol_slot") or "").strip()
                      for r in reg}
    sets_dir = ea_dir / "sets"
    setfiles = sorted(sets_dir.glob("*_backtest.set")) if sets_dir.is_dir() else []
    if reg and len(setfiles) < len(reg):
        problems.append(f"setfiles_{len(setfiles)}_vs_registry_{len(reg)}")

    for sf in setfiles:
        values = parse_setfile(sf)
        symbol = next((s for s in slot_by_symbol if s and s in sf.name), None)
        declared = values.get("qm_magic_slot_offset")
        if symbol and declared is not None and slot_by_symbol[symbol] != declared.strip():
            problems.append(
                f"slot_conflation:{symbol}:set={declared.strip()}!=registry={slot_by_symbol[symbol]}")
        risk_fixed = values.get("RISK_FIXED")
        try:
            if risk_fixed is not None and float(risk_fixed) <= 0:
                problems.append(f"risk_fixed_zero:{sf.name}")
        except ValueError:
            problems.append(f"risk_fixed_unparsable:{sf.name}")

    if mq5.exists():
        text = mq5.read_text(encoding="utf-8", errors="replace")
        declared_inputs = INPUT_RE.findall(text)
        for name in declared_inputs:
            # one occurrence == the declaration itself
            if len(re.findall(rf"\b{re.escape(name)}\b", text)) <= 1 and name not in fw_names:
                problems.append(f"unwired_input:{name}")
        notes.append(f"inputs={len(declared_inputs)}")

    return {"ea_id": ea_id, "slug": slug, "ok": not problems,
            "problems": problems, "notes": notes, "dir": str(ea_dir)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=DB)
    ap.add_argument("--state", default="REVIEW")
    ap.add_argument("--output", type=Path)
    args = ap.parse_args()

    conn = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    tasks = []
    for row in conn.execute(
            "SELECT id,payload_json,verdict,updated_at FROM agent_tasks "
            "WHERE state=? AND task_type='build_ea' ORDER BY updated_at", (args.state,)):
        payload = json.loads(row["payload_json"] or "{}")
        # Payloads carry the id both bare ("41011") and prefixed ("QM5_1673"). Normalising is not
        # cosmetic: an un-normalised id builds the path QM5_QM5_1673_<slug>, which does not exist,
        # so the task reports ea_dir_missing and is never actually screened -- a false positive
        # that hides every real check behind it.
        ea_id = str(payload.get("ea_id") or "").strip()
        if ea_id.upper().startswith("QM5_"):
            ea_id = ea_id[4:]
        tasks.append({"task": row["id"], "ea_id": ea_id,
                      "slug": str(payload.get("slug") or ""), "verdict": row["verdict"],
                      "updated_at": row["updated_at"]})
    conn.close()

    reg = registry_rows()
    fw_names = framework_input_names()
    results = []
    for t in tasks:
        res = screen(t["ea_id"], t["slug"], reg.get(t["ea_id"], []), fw_names)
        res.update({"task": t["task"], "verdict": t["verdict"], "updated_at": t["updated_at"]})
        results.append(res)

    clean = [r for r in results if r["ok"]]
    census: dict[str, int] = defaultdict(int)
    for r in results:
        for p in r["problems"]:
            census[p.split(":")[0]] += 1

    doc = {"schema": SCHEMA,
           "at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
           "state": args.state, "tasks": len(results),
           "clean": len(clean), "flagged": len(results) - len(clean),
           "problem_census": dict(sorted(census.items(), key=lambda kv: -kv[1])),
           "results": results}

    print(json.dumps({k: v for k, v in doc.items() if k != "results"}, indent=1))
    print("\n=== flagged ===")
    for r in results:
        if not r["ok"]:
            print("  %-8s QM5_%-7s %s" % (r["task"][:8], r["ea_id"], "; ".join(r["problems"])[:110]))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
