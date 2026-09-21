#!/usr/bin/env python3
"""Deterministic extract of the family-F1 sweep cells cited by QM-RESEARCH-2026-0012 (H-V4).

Reads docs/ops/evidence/2026-09-20_velocity_book/velocity_family_f1_sweep_0921.json (the sealed
sweep output of velocity_family_f1_sweep_0921.py) and copies, verbatim, the USDJPY.DWX and
EURUSD.DWX cells (all anchors A/B/C x N 2/3/4), the control-cell reconciliation against the Q02
tester report 652e0768, the pre-registered null/observed summary and the sweep's model fields
into strategy-seeds/sources/QM-RESEARCH-2026-0012/sweep_extract.json. No figure is computed
here beyond copying; sorted keys, no timestamps, so the file is byte-reproducible.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SWEEP = ROOT / "docs/ops/evidence/2026-09-20_velocity_book/velocity_family_f1_sweep_0921.json"
OUT = ROOT / "strategy-seeds/sources/QM-RESEARCH-2026-0012/sweep_extract.json"
SYMBOLS = ("USDJPY.DWX", "EURUSD.DWX")
CELL_FIELDS = (
    "anchor", "cell", "n_hours", "symbol", "day_states", "passes_SEL_rule",
    "passes_VAL_confirmation", "chance_pass_prob_SEL", "chance_pass_prob_VAL",
    "chance_pass_prob_joint", "selection", "validation",
)


def main() -> int:
    raw = SWEEP.read_bytes()
    sweep = json.loads(raw.decode("utf-8"))
    cells = {}
    for key, cell in sweep["cells"].items():
        if cell.get("symbol") in SYMBOLS:
            cells[key] = {k: cell[k] for k in CELL_FIELDS if k in cell}
    family = {}
    for sym in SYMBOLS:
        for anchor in ("A", "B", "C"):
            fam = [cells[f"{sym}|{anchor}{n}"]["selection"]["E_R"] for n in (2, 3, 4) if f"{sym}|{anchor}{n}" in cells]
            family[f"{sym}|{anchor}"] = {"SEL_E_R_by_N": fam, "all_positive_SEL": bool(fam) and all(v > 0 for v in fam)}
    payload = {
        "schema": "qm.velocity-hv4-sweep-extract/v1",
        "hypothesis": "H-V4",
        "research_id": "QM-RESEARCH-2026-0012",
        "source_file": str(SWEEP.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "registration": sweep["registration"],
        "mechanism": sweep["mechanism"],
        "fill_model": sweep["fill_model"],
        "news_model": sweep["news_model"],
        "commission_model": sweep["commission_model"],
        "commission_classes": {"forex": sweep["commission_classes"]["forex"]},
        "risk_fixed": sweep["risk_fixed"],
        "anchors": sweep["anchors"],
        "n_hours": sweep["n_hours"],
        "control_cell": sweep["control_cell"],
        "null": sweep["null"],
        "observed": sweep["observed"],
        "cells": cells,
        "family_consistency": family,
    }
    OUT.write_text(json.dumps(payload, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(OUT, hashlib.sha256(OUT.read_bytes()).hexdigest(), len(cells), "cells")
    return 0


if __name__ == "__main__":
    sys.exit(main())
