"""Q08.5 — Neighborhood Stability.

±10% perturbation of each Q03-chosen parameter must keep PF > 1.0 and
DD < 1.5× baseline. Confirms the EA sits on a robust parameter plateau
(not a sharp peak that real-world execution will slip off).

Implementation: this gate is a runner concern — it triggers ~7 supplementary
MT5 backtests (each Q03-chosen param ±10%, one at a time) and compares
their PF/DD to baseline. The sub-gate here reads the results from
`D:/QM/reports/pipeline/QM5_<id>/Q08/neighborhood/<symbol>/perturbations.json`
written by the neighborhood runner (separate script — TODO).

For now: graceful degradation. If perturbations.json is absent, return
INVALID (not FAIL) so the aggregator knows the gate didn't run, rather
than incorrectly failing the EA.
"""

from __future__ import annotations

import json
from pathlib import Path

from .common import make_result

GATE_NAME = "8.5_neighborhood"
PF_FLOOR = 1.0
DD_RATIO_MAX = 1.5


def run(ea_id: int | None = None, symbol: str | None = None,
        perturbations_path: Path | str | None = None, **_) -> dict:
    if perturbations_path is None and ea_id is not None and symbol is not None:
        sym_clean = symbol.replace(".", "_")
        perturbations_path = Path(
            f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/neighborhood/{sym_clean}/perturbations.json"
        )
    elif perturbations_path is not None:
        perturbations_path = Path(perturbations_path)
    else:
        return make_result(GATE_NAME, "INVALID",
                           value=None, threshold=None,
                           detail="missing_ea_id_or_perturbations_path")

    if not perturbations_path.exists():
        return make_result(GATE_NAME, "INVALID",
                           value=None, threshold=None,
                           detail=f"perturbations_runner_output_missing:{perturbations_path}",
                           evidence={"expected_path": str(perturbations_path)})

    try:
        data = json.loads(perturbations_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return make_result(GATE_NAME, "INVALID",
                           value=None, threshold=None,
                           detail=f"perturbations_parse_error:{exc}")

    baseline = data.get("baseline") or {}
    perturbs = data.get("perturbations") or []
    baseline_dd = float(baseline.get("dd", 0) or 0)
    breaches: list[dict] = []

    for p in perturbs:
        pf = float(p.get("pf", 0) or 0)
        dd = float(p.get("dd", 0) or 0)
        param = p.get("param", "?")
        delta = p.get("delta", "?")
        if pf < PF_FLOOR:
            breaches.append({"param": param, "delta": delta, "reason": "pf_below_floor",
                             "pf": pf, "dd": dd})
            continue
        if baseline_dd > 0 and dd > baseline_dd * DD_RATIO_MAX:
            ratio = dd / baseline_dd
            breaches.append({"param": param, "delta": delta, "reason": "dd_ratio_exceeded",
                             "pf": pf, "dd": dd, "ratio": round(ratio, 3)})

    if breaches:
        return make_result(
            GATE_NAME, "FAIL",
            value=len(breaches), threshold=0,
            detail=f"{len(breaches)}_perturbation_breaches",
            evidence={"breaches": breaches[:8], "n_perturbations_tested": len(perturbs)})

    return make_result(
        GATE_NAME, "PASS",
        value=len(perturbs), threshold=len(perturbs),
        detail=f"all_{len(perturbs)}_perturbations_within_plateau",
        evidence={"baseline_pf": baseline.get("pf"), "baseline_dd": baseline_dd,
                  "n_perturbations_tested": len(perturbs)})
