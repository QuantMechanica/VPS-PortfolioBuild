"""Q08.7 — Probability of Backtest Overfitting (PBO via CSCV).

Wraps the existing `framework/scripts/pbo_calculator.py` which implements
CSCV (López de Prado & Bailey 2014). PASS requires PBO < 0.40.

Input: per-(config, slice) score CSV at
    D:/QM/reports/pipeline/QM5_<id>/Q08/pbo/<symbol>/scores.csv
written by the PBO runner (which slices the Q03 sweep results into
combinatorial subsets). When the file is absent → INVALID (runner hasn't
been triggered for this EA yet).
"""

from __future__ import annotations

import sys
from pathlib import Path

from .common import make_result

# Path setup so we can import the existing pbo_calculator without packaging it
_FRAMEWORK_SCRIPTS = Path(__file__).resolve().parents[1]
if str(_FRAMEWORK_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_FRAMEWORK_SCRIPTS))

GATE_NAME = "8.7_pbo"
PBO_MAX = 0.40
PBO_MAX_PCT = PBO_MAX * 100.0


def run(ea_id: int | None = None, symbol: str | None = None,
        scores_path: Path | str | None = None, **_) -> dict:
    if scores_path is None and ea_id is not None and symbol is not None:
        sym_clean = symbol.replace(".", "_")
        scores_path = Path(
            f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/pbo/{sym_clean}/scores.csv"
        )
    elif scores_path is not None:
        scores_path = Path(scores_path)
    else:
        return make_result(GATE_NAME, "INVALID",
                           value=None, threshold=PBO_MAX_PCT,
                           detail="missing_ea_id_or_scores_path")

    if not scores_path.exists():
        return make_result(GATE_NAME, "INVALID",
                           value=None, threshold=PBO_MAX_PCT,
                           detail=f"pbo_runner_scores_missing:{scores_path}",
                           evidence={"expected_path": str(scores_path)})

    try:
        from pbo_calculator import _load_scores, compute_pbo  # type: ignore
        scores = _load_scores(scores_path, "config_id", "slice_id", "score")
        result = compute_pbo(scores)
    except Exception as exc:
        return make_result(GATE_NAME, "INVALID",
                           value=None, threshold=PBO_MAX_PCT,
                           detail=f"pbo_compute_error:{exc}")

    pbo_pct = float(result.get("pbo_pct", 100.0))
    splits = int(result.get("splits_evaluated", 0))
    overfit = int(result.get("overfit_splits", 0))
    status = "PASS" if pbo_pct < PBO_MAX_PCT else "FAIL"

    return make_result(
        GATE_NAME, status,
        value=round(pbo_pct, 3), threshold=PBO_MAX_PCT,
        detail=f"PBO={pbo_pct:.2f}%:max={PBO_MAX_PCT:.0f}%:splits={splits}:overfit={overfit}",
        evidence={"splits_evaluated": splits, "overfit_splits": overfit,
                  "scores_path": str(scores_path)})
