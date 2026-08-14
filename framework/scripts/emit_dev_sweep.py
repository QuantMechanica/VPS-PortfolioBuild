#!/usr/bin/env python3
"""Deterministic emitter for Q15 DEV-sweep evidence (``qm.opt-dev-sweep/v1``).

At census scale (1386 predicate/direction cells across the pattern-permission
program) hand-assembling ``dev_sweep.json`` is untenable and error-prone. This
script assembles the artifact from already-completed DEV trial runs instead of
computing anything itself: it never launches MT5 and never selects a
promotion candidate (measurement is not selection -- Plan v2 E0-1). The chosen
predicate is a pre-registered input, not a decision this script makes.

Inputs, per DEV trial, are one JSON result file per planned trial id under
``--results-dir`` (named ``<trial_id>.json``), each carrying::

    {"trial_id": "...", "predicate_id": "...", "direction": "BUY"|"SELL",
     "metric_value": <number>, "fire_count": <non-negative int>,
     "time_thirds": [{"id": "...", "metric_value": <number>}, ...]}   # exactly 3

and one incumbent-control JSON under ``--incumbent-result``::

    {"metric_value": <number>,
     "time_thirds": [{"id": "...", "start": "YYYY-MM-DD", "end": "YYYY-MM-DD",
                       "metric_value": <number>}, ...]}                # exactly 3

Every planned trial in the opt-card's trial ledger must have a matching result
file whose ``predicate_id``/``direction``/``trial_id`` byte-exactly match the
ledger's ``planned_trials`` entry; a missing file or an identity mismatch is a
hard error. A missing ``fire_count`` is always a hard error -- it is never
defaulted. Only the categorical (``PREDICATE_ABLATION``) surface is supported;
numeric single-lever DEV sweeps are still small enough to hand-assemble and
are out of scope here.

Each result/incumbent file becomes the durable, SHA-256-bound evidence for its
own trial/incumbent entry -- nothing is copied. Output is byte-identical
across repeated runs against the same inputs (no wall-clock, no randomness).
Dry-run is the default; ``--apply`` writes the artifact to ``--out``.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

REPO_ROOT = Path(__file__).resolve().parents[2]
if __package__ in (None, ""):
    sys.path.insert(0, str(REPO_ROOT))

from framework.scripts import q15_freeze_check as q15

DEV_SWEEP_SCHEMA = q15.DEV_SWEEP_SCHEMA
RESULT_SCHEMA = "qm.emit-dev-sweep-result/v1"

_TRIAL_KEYS = {"trial_id", "predicate_id", "direction", "metric_value", "fire_count", "time_thirds", "evidence"}
_CANDIDATE_THIRD_KEYS = {"id", "metric_value"}
_INCUMBENT_THIRD_KEYS = {"id", "start", "end", "metric_value"}
_BINDING_KEYS = {"path", "sha256", "size_bytes"}


class EmitDevSweepError(RuntimeError):
    """A fail-closed input or assembly error."""


def _read_json(path: Path, label: str) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise EmitDevSweepError(f"{label} is missing or invalid: {path}: {exc}") from exc


def _binding(path: Path) -> dict[str, Any]:
    try:
        return q15._binding(path)
    except q15.Q15Error as exc:
        raise EmitDevSweepError(str(exc)) from exc


def _require_nonneg_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise EmitDevSweepError(f"{label} must be a non-negative integer, got {value!r}")
    return value


def _require_three_thirds(raw: Any, *, label: str, keys: set[str]) -> list[Mapping[str, Any]]:
    if not isinstance(raw, list) or len(raw) != 3:
        raise EmitDevSweepError(f"{label} must declare exactly three time_thirds")
    ids: set[str] = set()
    for index, third in enumerate(raw):
        if not isinstance(third, Mapping) or set(third) != keys:
            raise EmitDevSweepError(f"{label} time_thirds[{index}] has the wrong key set (expected {sorted(keys)})")
        third_id = str(third.get("id") or "")
        if not third_id or third_id in ids:
            raise EmitDevSweepError(f"{label} time_thirds need unique non-empty ids")
        ids.add(third_id)
    return list(raw)


def build_sweep(
    *,
    card_path: Path,
    ledger_path: Path,
    results_dir: Path,
    incumbent_result_path: Path,
    window_start: str,
    window_end: str,
    chosen_trial_id: str,
) -> dict[str, Any]:
    card_raw = _read_json(card_path, "opt-card")
    card_id = str(card_raw.get("card_id") or "")
    try:
        card_info = q15._validate_card(card_raw, card_id)
    except q15.Q15Error as exc:
        raise EmitDevSweepError(f"opt-card is invalid: {exc}") from exc
    if not card_info["categorical"]:
        raise EmitDevSweepError(
            "emit_dev_sweep.py only assembles categorical (PREDICATE_ABLATION) DEV sweeps; "
            "numeric single-lever sweeps remain hand-assembled"
        )

    ledger_raw = _read_json(ledger_path, "trial ledger")
    try:
        ledger_info = q15._validate_ledger(ledger_raw, card_id=card_id, expected_path=ledger_path)
    except q15.Q15Error as exc:
        raise EmitDevSweepError(f"trial ledger is invalid: {exc}") from exc

    try:
        start = q15._iso_date(window_start, "--dev-window-start")
        end = q15._iso_date(window_end, "--dev-window-end")
    except q15.Q15Error as exc:
        raise EmitDevSweepError(str(exc)) from exc
    if start > end or end >= card_info["first_oos_start"]:
        raise EmitDevSweepError(
            f"DEV window {start.isoformat()}..{end.isoformat()} must end strictly before the "
            f"first sealed OOS window ({card_info['first_oos_start'].isoformat()})"
        )

    incumbent_raw = _read_json(incumbent_result_path, "incumbent DEV result")
    incumbent_metric = incumbent_raw.get("metric_value")
    if not isinstance(incumbent_metric, (int, float)) or isinstance(incumbent_metric, bool):
        raise EmitDevSweepError("incumbent DEV result metric_value must be numeric")
    incumbent_thirds = _require_three_thirds(
        incumbent_raw.get("time_thirds"), label="incumbent DEV result", keys=_INCUMBENT_THIRD_KEYS
    )
    incumbent_block = {
        "metric_value": incumbent_metric,
        "time_thirds": [
            {"id": str(t["id"]), "start": str(t["start"]), "end": str(t["end"]), "metric_value": t["metric_value"]}
            for t in incumbent_thirds
        ],
        "evidence": _binding(incumbent_result_path),
    }

    planned = ledger_info["planned"]
    trials: list[dict[str, Any]] = []
    for row in planned:
        trial_id = str(row["trial_id"])
        planned_predicate = str(row["predicate_id"])
        planned_direction = str(row["direction"])
        result_path = results_dir / f"{trial_id}.json"
        if not result_path.is_file():
            raise EmitDevSweepError(f"DEV trial result is missing for planned trial {trial_id}: {result_path}")
        result = _read_json(result_path, f"DEV trial result {trial_id}")

        result_trial_id = str(result.get("trial_id") or "")
        predicate_id = str(result.get("predicate_id") or "").strip()
        direction = str(result.get("direction") or "").strip().upper()
        if (
            result_trial_id != trial_id
            or predicate_id != planned_predicate
            or direction != planned_direction
        ):
            raise EmitDevSweepError(
                f"DEV trial result {trial_id} identity ({result_trial_id}/{predicate_id}/{direction}) "
                f"does not byte-exactly match its planned_trials entry "
                f"({trial_id}/{planned_predicate}/{planned_direction})"
            )

        if "fire_count" not in result or result.get("fire_count") is None:
            raise EmitDevSweepError(f"DEV trial result {trial_id} is missing fire_count")
        fire_count = _require_nonneg_int(result["fire_count"], f"DEV trial result {trial_id} fire_count")

        metric_value = result.get("metric_value")
        if not isinstance(metric_value, (int, float)) or isinstance(metric_value, bool):
            raise EmitDevSweepError(f"DEV trial result {trial_id} metric_value must be numeric")

        thirds = _require_three_thirds(
            result.get("time_thirds"), label=f"DEV trial result {trial_id}", keys=_CANDIDATE_THIRD_KEYS
        )
        trials.append({
            "trial_id": trial_id,
            "predicate_id": predicate_id,
            "direction": direction,
            "metric_value": metric_value,
            "fire_count": fire_count,
            "time_thirds": [{"id": str(t["id"]), "metric_value": t["metric_value"]} for t in thirds],
            "evidence": _binding(result_path),
        })

    trial_ids = {t["trial_id"] for t in trials}
    if chosen_trial_id not in trial_ids:
        raise EmitDevSweepError(f"--chosen-trial-id {chosen_trial_id!r} is not one of the declared planned trials")

    return {
        "schema": DEV_SWEEP_SCHEMA,
        "card_id": card_id,
        "window": {"kind": "DEV_IS", "start": start.isoformat(), "end": end.isoformat()},
        "selection_metric": {"name": card_info["metric_name"], "direction": "MAXIMIZE"},
        "incumbent": incumbent_block,
        "trials": trials,
        "selection": {"chosen_trial_id": chosen_trial_id},
    }


def _assert_binding_shape(binding: Any, label: str) -> None:
    if not isinstance(binding, Mapping) or set(binding) != _BINDING_KEYS:
        raise EmitDevSweepError(f"{label} evidence binding has the wrong key set")
    if not re.fullmatch(r"[0-9a-f]{64}", str(binding["sha256"])):
        raise EmitDevSweepError(f"{label} evidence binding sha256 is malformed")


def assert_matches_schema(sweep: Mapping[str, Any]) -> None:
    """Dependency-free structural check against opt_dev_sweep.v1.schema.json."""
    required_top = {"schema", "card_id", "window", "selection_metric", "incumbent", "trials", "selection"}
    if set(sweep) != required_top:
        raise EmitDevSweepError(f"assembled sweep has the wrong top-level key set: {sorted(set(sweep) ^ required_top)}")
    if sweep["schema"] != DEV_SWEEP_SCHEMA:
        raise EmitDevSweepError("assembled sweep schema constant is wrong")
    if not re.fullmatch(r"OPT-[A-Za-z0-9-]+", str(sweep["card_id"])):
        raise EmitDevSweepError("assembled sweep card_id does not match the required pattern")

    window = sweep["window"]
    if set(window) != {"kind", "start", "end"} or window["kind"] != "DEV_IS":
        raise EmitDevSweepError("assembled sweep window block is malformed")

    metric = sweep["selection_metric"]
    if set(metric) != {"name", "direction"} or metric["direction"] != "MAXIMIZE" or not metric["name"]:
        raise EmitDevSweepError("assembled sweep selection_metric block is malformed")

    trials = sweep["trials"]
    if not isinstance(trials, list) or len(trials) < 2:
        raise EmitDevSweepError("assembled sweep must contain at least two trials")
    for trial in trials:
        if set(trial) != _TRIAL_KEYS:
            raise EmitDevSweepError(f"assembled trial has the wrong key set: {sorted(set(trial) ^ _TRIAL_KEYS)}")
        if trial["direction"] not in {"BUY", "SELL"}:
            raise EmitDevSweepError("assembled trial direction must be BUY or SELL")
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", str(trial["predicate_id"])):
            raise EmitDevSweepError("assembled trial predicate_id is malformed")
        _assert_binding_shape(trial["evidence"], f"trial {trial['trial_id']}")
        for third in trial["time_thirds"]:
            if set(third) != _CANDIDATE_THIRD_KEYS:
                raise EmitDevSweepError("assembled trial time_thirds entries have the wrong key set")

    incumbent = sweep["incumbent"]
    if set(incumbent) != {"metric_value", "time_thirds", "evidence"}:
        raise EmitDevSweepError("assembled incumbent block has the wrong key set")
    _assert_binding_shape(incumbent["evidence"], "incumbent")
    for third in incumbent["time_thirds"]:
        if set(third) != _INCUMBENT_THIRD_KEYS:
            raise EmitDevSweepError("assembled incumbent time_thirds entries have the wrong key set")

    selection = sweep["selection"]
    if set(selection) != {"chosen_trial_id"} or not selection["chosen_trial_id"]:
        raise EmitDevSweepError("assembled sweep selection block is malformed")


def _canonical_text(value: Any) -> str:
    return json.dumps(value, indent=2, sort_keys=True) + "\n"


def run_emit_dev_sweep(
    *,
    card_path: Path,
    ledger_path: Path,
    results_dir: Path,
    incumbent_result_path: Path,
    window_start: str,
    window_end: str,
    chosen_trial_id: str,
    out_path: Path,
    apply: bool = False,
) -> dict[str, Any]:
    sweep = build_sweep(
        card_path=card_path,
        ledger_path=ledger_path,
        results_dir=results_dir,
        incumbent_result_path=incumbent_result_path,
        window_start=window_start,
        window_end=window_end,
        chosen_trial_id=chosen_trial_id,
    )
    assert_matches_schema(sweep)
    body = _canonical_text(sweep)
    result: dict[str, Any] = {
        "schema": RESULT_SCHEMA,
        "card_id": sweep["card_id"],
        "trial_count": len(sweep["trials"]),
        "chosen_trial_id": sweep["selection"]["chosen_trial_id"],
        "applied": bool(apply),
        "body_sha256": q15._sha256_bytes(body.encode("utf-8")),
    }
    if apply:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(body, encoding="utf-8")
        result["out_path"] = str(out_path.resolve())
    else:
        result["sweep"] = sweep
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Emit a qm.opt-dev-sweep/v1 artifact from completed DEV trial runs (dry-run default)"
    )
    parser.add_argument("--card", required=True)
    parser.add_argument("--ledger", required=True)
    parser.add_argument("--results-dir", required=True)
    parser.add_argument("--incumbent-result", required=True)
    parser.add_argument("--dev-window-start", required=True)
    parser.add_argument("--dev-window-end", required=True)
    parser.add_argument("--chosen-trial-id", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--apply", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = run_emit_dev_sweep(
            card_path=Path(args.card),
            ledger_path=Path(args.ledger),
            results_dir=Path(args.results_dir),
            incumbent_result_path=Path(args.incumbent_result),
            window_start=args.dev_window_start,
            window_end=args.dev_window_end,
            chosen_trial_id=args.chosen_trial_id,
            out_path=Path(args.out),
            apply=bool(args.apply),
        )
    except EmitDevSweepError as exc:
        print(json.dumps({"schema": RESULT_SCHEMA, "verdict": "FAIL", "error": str(exc)}, indent=2, sort_keys=True))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
