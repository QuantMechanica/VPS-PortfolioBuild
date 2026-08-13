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

import json
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
PBO_MIN_SPLITS = 10


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

    meta_path = scores_path.with_name("scores_meta.json")
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8-sig")) if meta_path.exists() else {}
    except (OSError, json.JSONDecodeError):
        meta = {}
    try:
        meta_schema = int(meta.get("schema_version") or 0)
    except (TypeError, ValueError):
        meta_schema = 0
    if meta_schema == 2:
        meta_status = str(meta.get("status") or "").upper()
        if meta_status in {"INVALID", "INVALID_NA"}:
            reason = str(meta.get("reason") or "pbo_config_family_invalid")
            common_evidence = {
                "scores_path": str(scores_path),
                "scores_meta_path": str(meta_path),
                "n_configs": int(meta.get("n_configs") or 0),
                "n_common_slices": int(meta.get("n_common_slices") or 0),
                "config_source": meta.get("config_source"),
            }
            # NOT-APPLICABLE (2026-07-27, census rank 7): status INVALID_NA is the PBO
            # runner's AUTHORITATIVE structural determination — the neighborhood runner
            # proved the strategy has no perturbable parameter, so a >=2-config PBO family
            # is UNDEFINED BY CONSTRUCTION for this fixed-parameter card. That is neither a
            # model-selection verdict nor a retry-owed infra condition (no retry can invent
            # a config family), so it must NOT read as a failure. Distinct from a plain
            # meta INVALID (insufficient_distinct_configs / non-even slices), which the
            # sub-gate cannot prove is structural and which stays a NARROW C2 tooling
            # INVALID -> INFRA_FAIL.
            if meta_status == "INVALID_NA":
                return make_result(
                    GATE_NAME,
                    "NOT_APPLICABLE",
                    value=None,
                    threshold=PBO_MAX_PCT,
                    detail=f"not_applicable:{reason}",
                    evidence=common_evidence,
                )
            return make_result(
                GATE_NAME,
                "INVALID",
                value=None,
                threshold=PBO_MAX_PCT,
                detail=reason,
                evidence=common_evidence,
            )

    try:
        from pbo_calculator import _load_scores, compute_pbo  # type: ignore
        scores = _load_scores(scores_path, "config_id", "slice_id", "score")
        n_configs = len(scores)
        if n_configs < 2:
            return make_result(
                GATE_NAME,
                "INVALID",
                value=None,
                threshold=PBO_MAX_PCT,
                detail=f"insufficient_distinct_configs:got={n_configs}:need>=2",
                evidence={"scores_path": str(scores_path), "n_configs": n_configs},
            )
        # Exact-family enforcement (plan v2 A3 / codex review finding 3). PBO is only
        # defined over a rectangular (config x slice) matrix drawn from ONE configuration
        # family. A ragged matrix means some configs were evaluated on fewer slices —
        # typically the losers, which crash, zero-trade or time out more often. Silently
        # intersecting or dropping them biases PBO downward (the set looks less overfit
        # than it is). Fail closed instead, and say exactly which configs are short.
        slice_sets = {cfg: set(v.keys()) for cfg, v in scores.items()}
        common_slices = set.intersection(*slice_sets.values())
        all_slices = set.union(*slice_sets.values())
        if common_slices != all_slices:
            ragged = sorted(
                (cfg, len(all_slices - s)) for cfg, s in slice_sets.items() if s != all_slices
            )
            return make_result(
                GATE_NAME, "INVALID",
                value=None, threshold=PBO_MAX_PCT,
                detail=("pbo_family_not_rectangular:"
                        f"configs={n_configs}:slices_union={len(all_slices)}:"
                        f"slices_common={len(common_slices)}:short_configs={len(ragged)}"),
                evidence={
                    "scores_path": str(scores_path),
                    "n_configs": n_configs,
                    "n_slices_union": len(all_slices),
                    "n_slices_common": len(common_slices),
                    "short_configs": [{"config_id": c, "missing_slices": m}
                                      for c, m in ragged[:20]],
                    "config_source": str(meta.get("config_source") or "UNKNOWN"),
                    "rule": "PBO requires one family on a complete config x slice grid",
                },
            )
        # A declared config count that exceeds what the scores file carries proves
        # configurations were lost between the runner and this gate.
        declared_configs = meta.get("n_configs")
        try:
            declared_configs = int(declared_configs) if declared_configs is not None else None
        except (TypeError, ValueError):
            declared_configs = None
        if declared_configs is not None and declared_configs > n_configs:
            return make_result(
                GATE_NAME, "INVALID",
                value=None, threshold=PBO_MAX_PCT,
                detail=(f"pbo_configs_lost:declared={declared_configs}:present={n_configs}"),
                evidence={"scores_path": str(scores_path),
                          "declared_n_configs": declared_configs,
                          "present_n_configs": n_configs,
                          "config_source": str(meta.get("config_source") or "UNKNOWN")},
            )
        result = compute_pbo(scores)
    except Exception as exc:
        return make_result(GATE_NAME, "INVALID",
                           value=None, threshold=PBO_MAX_PCT,
                           detail=f"pbo_compute_error:{exc}")

    pbo_pct = float(result.get("pbo_pct", 100.0))
    splits = int(result.get("splits_evaluated", 0))
    overfit = int(result.get("overfit_splits", 0))
    config_source = str(meta.get("config_source") or "UNKNOWN")
    if splits <= 0:
        return make_result(
            GATE_NAME,
            "INVALID",
            value=None,
            threshold=PBO_MAX_PCT,
            detail=(
                "insufficient_common_even_slices:"
                f"got={len(common_slices)}:need_even>=2"
            ),
            evidence={
                "scores_path": str(scores_path),
                "n_configs": n_configs,
                "n_common_slices": len(common_slices),
                "splits_evaluated": splits,
            },
        )
    if splits < PBO_MIN_SPLITS:
        return make_result(
            GATE_NAME,
            "INVALID",
            value=None,
            threshold=PBO_MAX_PCT,
            detail=f"insufficient_pbo_splits:got={splits}:need>={PBO_MIN_SPLITS}",
            evidence={
                "n_configs": n_configs,
                "n_common_slices": len(common_slices),
                "splits_evaluated": splits,
                "overfit_splits": overfit,
                "raw_pbo_pct": round(pbo_pct, 3),
                "scores_path": str(scores_path),
                "config_source": config_source,
                "q03_candidate_configs": meta.get("q03_candidate_configs"),
                "neighborhood_candidate_configs": meta.get(
                    "neighborhood_candidate_configs"
                ),
            },
        )
    status = "PASS" if pbo_pct < PBO_MAX_PCT else "FAIL"

    return make_result(
        GATE_NAME, status,
        value=round(pbo_pct, 3), threshold=PBO_MAX_PCT,
        detail=(
            f"PBO={pbo_pct:.2f}%:max={PBO_MAX_PCT:.0f}%:"
            f"splits={splits}:overfit={overfit}:source={config_source}"
        ),
        evidence={"n_configs": n_configs, "n_common_slices": len(common_slices),
                  "splits_evaluated": splits, "overfit_splits": overfit,
                  "scores_path": str(scores_path),
                  "config_source": config_source,
                  "q03_candidate_configs": meta.get("q03_candidate_configs"),
                  "neighborhood_candidate_configs": meta.get(
                      "neighborhood_candidate_configs"
                  )})
