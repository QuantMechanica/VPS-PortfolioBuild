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
MIN_VALID_PERTURBATIONS = 2


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

    # Defensive guard: if the BASELINE run itself produced no trades (or no PF), the
    # neighborhood backtests did not reproduce the strategy — the gate did not actually
    # test parameter stability. Return INVALID, never FAIL: failing an EA because the
    # runner is degenerate is a false negative (this masked a -Year 0 window bug that gave
    # every EA a 0-trade baseline and falsely FAILED them all). 2026-06-26.
    base_trades = int(baseline.get("trades", 0) or 0)
    if base_trades <= 0 or baseline.get("pf") is None:
        return make_result(GATE_NAME, "INVALID",
                           value=base_trades, threshold=None,
                           detail=f"degenerate_baseline:trades={base_trades}:pf={baseline.get('pf')}",
                           evidence={"baseline": baseline})

    # No perturbations recorded = the gate tested nothing -> a PASS here would be a VACUOUS
    # pass (claims a robust plateau that was never probed). 141 historical runs passed this
    # way. INVALID, not PASS — the gate must actually perturb the parameters to give a verdict.
    if not perturbs:
        return make_result(GATE_NAME, "INVALID",
                           value=0, threshold=None,
                           detail="no_perturbations_tested_vacuous_pass",
                           evidence={"baseline": baseline})

    if baseline.get("dd") is None:
        return make_result(
            GATE_NAME,
            "INVALID",
            value=None,
            threshold=None,
            detail="degenerate_baseline:dd_missing",
            evidence={"baseline": baseline},
        )
    baseline_dd = float(baseline.get("dd", 0) or 0)
    breaches: list[dict] = []
    invalid_perturbs: list[dict] = []
    valid_perturbs: list[dict] = []

    for p in perturbs:
        try:
            trades = int(p.get("trades") or 0)
        except (TypeError, ValueError):
            trades = 0
        explicit_status = str(p.get("status") or "").upper()
        if (
            explicit_status == "INVALID"
            or trades <= 0
            or p.get("pf") is None
            or p.get("dd") is None
        ):
            invalid_perturbs.append({
                "param": p.get("param", "?"),
                "delta": p.get("delta", "?"),
                "pf": p.get("pf"),
                "dd": p.get("dd"),
                "trades": trades,
                "reason": p.get("invalid_reason") or "zero_trades_or_missing_metrics",
            })
            continue
        pf = float(p.get("pf", 0) or 0)
        dd = float(p.get("dd", 0) or 0)
        param = p.get("param", "?")
        delta = p.get("delta", "?")
        valid_perturbs.append(p)
        if pf <= PF_FLOOR:
            breaches.append({"param": param, "delta": delta, "reason": "pf_not_above_floor",
                             "pf": pf, "dd": dd, "trades": trades})
            continue
        if baseline_dd > 0 and dd > baseline_dd * DD_RATIO_MAX:
            ratio = dd / baseline_dd
            breaches.append({"param": param, "delta": delta, "reason": "dd_ratio_exceeded",
                             "pf": pf, "dd": dd, "trades": trades,
                             "ratio": round(ratio, 3)})

    if breaches:
        return make_result(
            GATE_NAME, "FAIL",
            value=len(breaches), threshold=0,
            detail=f"{len(breaches)}_perturbation_breaches",
            evidence={
                "breaches": breaches[:8],
                "invalid_perturbations": invalid_perturbs[:8],
                "n_valid_perturbations": len(valid_perturbs),
                "n_invalid_perturbations": len(invalid_perturbs),
                "n_perturbations_tested": len(perturbs),
            })

    if len(valid_perturbs) < MIN_VALID_PERTURBATIONS:
        return make_result(
            GATE_NAME,
            "INVALID",
            value=len(valid_perturbs),
            threshold=MIN_VALID_PERTURBATIONS,
            detail=(
                "insufficient_valid_perturbations:"
                f"got={len(valid_perturbs)}:need>={MIN_VALID_PERTURBATIONS}:"
                f"invalid={len(invalid_perturbs)}"
            ),
            evidence={
                "invalid_perturbations": invalid_perturbs[:8],
                "n_valid_perturbations": len(valid_perturbs),
                "n_invalid_perturbations": len(invalid_perturbs),
                "n_perturbations_tested": len(perturbs),
            },
        )

    return make_result(
        GATE_NAME, "PASS",
        value=len(valid_perturbs), threshold=MIN_VALID_PERTURBATIONS,
        detail=(
            f"all_{len(valid_perturbs)}_valid_perturbations_within_plateau:"
            f"invalid_dropped={len(invalid_perturbs)}"
        ),
        evidence={"baseline_pf": baseline.get("pf"), "baseline_dd": baseline_dd,
                  "invalid_perturbations": invalid_perturbs[:8],
                  "n_valid_perturbations": len(valid_perturbs),
                  "n_invalid_perturbations": len(invalid_perturbs),
                  "n_perturbations_tested": len(perturbs)})
