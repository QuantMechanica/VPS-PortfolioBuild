#!/usr/bin/env python3
"""Build the near-miss register: economic FAILs that came within a tolerance of a gate floor.

A near-miss ranks where targeted rework has the best odds. It is NOT a gate exception -- nothing
here overrides a verdict (OWNER DL territory).

Why this file exists at all: the previous register was produced by an uncommitted scratchpad
script that hardcoded a PF floor of 1.20. Q04, Q05, Q06, Q07 and Q10 all declare 1.0. Every PF
row was therefore measured against a floor 20% above the real one, which both dropped genuine
near-misses (pf 0.96 is 4% off 1.0, but 20% off 1.20) and would have flagged rows in [1.0, 1.20)
as near-missing a floor they already clear.

So the floors are not restated here. They are PARSED OUT OF THE GATE MODULES, and every emitted
row carries the file and line its floor came from. A floor changed in a gate changes this register
on the next run; a floor that cannot be located is a hard error, never a default.
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
SCRIPTS = REPO / "framework" / "scripts"
DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")

SCHEMA = "qm.near-miss-register/v2"

# phase -> (module stem that DEFINES the constant, constant name, comparison as written in the gate)
# The comparison is recorded because the gates disagree: Q05/Q06/Q10 FAIL on `pf <= floor`
# (pass needs pf strictly above), while Q07 breaches on `pf < floor` (pass allows pf == floor).
# Q06 does not define its own floor -- it imports PF_FLOOR from q05_stress_medium, so the spec
# points at the defining module rather than restating the value.
GATE_SPEC = {
    "Q04": ("q04_walkforward", "PF_NET_FLOOR_PER_FOLD", ">"),
    "Q05": ("q05_stress_medium", "PF_FLOOR", ">"),
    "Q06": ("q05_stress_medium", "PF_FLOOR", ">"),
    "Q07": ("q07_multiseed", "PER_SEED_PF_MIN", ">="),
    "Q10": ("q10_confirmation", "PF_FLOOR", ">"),
}

TERMINAL_NON_PASS = (
    "FAIL", "FAIL_SOFT", "FAIL_HARD", "FAIL_LOWFREQ", "ZERO_TRADES",
    "FAIL_PORTFOLIO", "NEED_MORE_DATA", "PASS_LOWFREQ",
)


class FloorError(RuntimeError):
    """A gate floor could not be located. Never defaulted -- a wrong floor is worse than none."""


def read_floor(stem: str, const: str) -> tuple[float, str]:
    """Parse `CONST = <float>` out of a gate module. Returns (value, 'path:line')."""
    path = SCRIPTS / f"{stem}.py"
    if not path.exists():
        raise FloorError(f"gate_module_missing:{path}")
    pattern = re.compile(rf"^{re.escape(const)}\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*(?:#.*)?$")
    for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
        m = pattern.match(line.strip())
        if m:
            return float(m.group(1)), f"framework/scripts/{stem}.py:{lineno}"
    raise FloorError(f"floor_not_found:{const}:in:{stem}.py")


def resolve_floors() -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for phase, (stem, const, cmp_op) in GATE_SPEC.items():
        value, provenance = read_floor(stem, const)
        out[phase] = {"floor": value, "constant": const, "source": provenance, "pass_requires": cmp_op}
    return out


def measured_pf(reason: str) -> list[float]:
    """Pull the measured PF(s) out of a gate's own reason string.

    The reason string is the gate's own account of why it failed, so it is preferred over
    re-deriving from the aggregate. Two shapes exist:
      Q04  F1:pf_net=0.970;F2:pf_net=0.940;F3:pf_net=0.890
      Q05+ pf_below_floor:pf=0.960:floor=1.0
    """
    folds = [float(x) for x in re.findall(r"pf_net=(\d+(?:\.\d+)?)", reason)]
    if folds:
        return folds
    m = re.search(r"\bpf=(\d+(?:\.\d+)?)", reason)
    return [float(m.group(1))] if m else []


def load_json(path: str | None) -> dict | None:
    if not path:
        return None
    try:
        return json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, ValueError):
        return None


def build(window_hours: int, tolerance_pct: float, db: Path) -> dict[str, Any]:
    floors = resolve_floors()
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=25)
    con.row_factory = sqlite3.Row
    cut = (datetime.now(timezone.utc) - timedelta(hours=window_hours)).isoformat(timespec="seconds")
    marks = ",".join("?" * len(TERMINAL_NON_PASS))
    rows = con.execute(
        f"""SELECT id, ea_id, symbol, phase, verdict, evidence_path, updated_at
            FROM work_items
            WHERE status IN ('done','failed') AND updated_at >= ?
              AND verdict IN ({marks})
            ORDER BY updated_at DESC""",
        (cut, *TERMINAL_NON_PASS),
    ).fetchall()
    con.close()

    entries: list[dict[str, Any]] = []
    screened = unreadable = no_pf = 0
    for r in rows:
        spec = floors.get(r["phase"])
        if spec is None:
            continue
        screened += 1
        doc = load_json(r["evidence_path"])
        if doc is None:
            unreadable += 1
            continue
        reason = str(doc.get("verdict_reason") or doc.get("reason") or doc.get("lowfreq_reason") or "")
        pfs = measured_pf(reason)
        if not pfs:
            no_pf += 1
            continue
        # The gate fails on its WEAKEST fold, so that is the number the rework has to move.
        weakest = min(pfs)
        floor = spec["floor"]
        gap_pct = (floor - weakest) / floor * 100.0
        if 0.0 <= gap_pct <= tolerance_pct:
            entries.append({
                "work_item": r["id"],
                "ea": r["ea_id"],
                "symbol": r["symbol"],
                "phase": r["phase"],
                "verdict": r["verdict"],
                "at": r["updated_at"],
                "evidence": r["evidence_path"],
                "metric": "pf_net_weakest_fold" if len(pfs) > 1 else "pf",
                "value": round(weakest, 4),
                "folds": [round(x, 4) for x in pfs] if len(pfs) > 1 else None,
                "floor": floor,
                "floor_source": spec["source"],
                "pass_requires": spec["pass_requires"],
                "gap_pct": round(gap_pct, 2),
            })
    entries.sort(key=lambda e: e["gap_pct"])
    return {
        "schema": SCHEMA,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "window_hours": window_hours,
        "tolerance_pct": tolerance_pct,
        "policy": "priority list for targeted rework; gates are NOT overridden (OWNER DL territory)",
        "floors": floors,
        "rows_screened": screened,
        "evidence_unreadable": unreadable,
        "rows_without_parsable_pf": no_pf,
        "count": len(entries),
        "entries": entries,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--window-hours", type=int, default=72)
    ap.add_argument("--tolerance-pct", type=float, default=5.0)
    ap.add_argument("--db", type=Path, default=DB)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    doc = build(args.window_hours, args.tolerance_pct, args.db)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(doc, indent=1, sort_keys=False) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in doc.items() if k != "entries"}, indent=1))
    for e in doc["entries"]:
        print("  %-11s %-14s %-4s %-14s value=%.3f floor=%.2f gap=%.2f%%"
              % (e["ea"], e["symbol"], e["phase"], e["verdict"], e["value"], e["floor"], e["gap_pct"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
