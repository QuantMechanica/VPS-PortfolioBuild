"""Select a DXZ sleeve cohort in one window and diagnose it in a later window.

This is a research-only, close-to-close holdout screen.  Selection uses only
conservative commission-adjusted closing P&L in the declared training window;
the selected cohort is then aggregated in a strictly later evaluation window.
It does not repair data gaps or simulate DARWIN mark-to-market / Risk Engine.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import dxz_darwinia_book_proxy as book


SCHEMA_VERSION = 2
TOOL_VERSION = "1.1.0"


class WalkForwardError(RuntimeError):
    """Raised when the declared holdout contract is invalid."""


def parse_universe(raw: str) -> tuple[str, ...]:
    keys = tuple(item.strip() for item in raw.split(",") if item.strip())
    if not keys or len(keys) != len(set(keys)):
        raise WalkForwardError("universe must contain unique comma-separated keys")
    return keys


def _profit_factor(values: Sequence[float]) -> float | None:
    gross_profit = sum(value for value in values if value > 0.0)
    gross_loss = -sum(value for value in values if value < 0.0)
    if gross_loss <= 0.0:
        return None
    return gross_profit / gross_loss


def build_report(
    cost_report_path: Path,
    *,
    expected_cost_report_sha256: str,
    expected_sleeve_count: int,
    universe: Sequence[str],
    train_from: str,
    train_to: str,
    evaluate_from: str,
    evaluate_to: str,
    minimum_training_trades: int,
    minimum_training_pf: float,
    starting_equity: float,
    as_of_utc: str,
    implementation_path: Path | None = None,
    dependency_path: Path | None = None,
) -> dict[str, Any]:
    try:
        train_start = dt.date.fromisoformat(train_from)
        train_end = dt.date.fromisoformat(train_to)
        test_start = dt.date.fromisoformat(evaluate_from)
        test_end = dt.date.fromisoformat(evaluate_to)
    except ValueError as exc:
        raise WalkForwardError("all window dates must be strict YYYY-MM-DD") from exc
    if any(
        value.isoformat() != raw
        for value, raw in (
            (train_start, train_from),
            (train_end, train_to),
            (test_start, evaluate_from),
            (test_end, evaluate_to),
        )
    ):
        raise WalkForwardError("all window dates must be strict YYYY-MM-DD")
    if train_start > train_end or test_start > test_end:
        raise WalkForwardError("window start must be <= end")
    if test_start <= train_end:
        raise WalkForwardError("evaluation window must be strictly after training")
    if minimum_training_trades <= 0:
        raise WalkForwardError("minimum training trades must be > 0")
    if minimum_training_pf <= 0 or not math.isfinite(minimum_training_pf):
        raise WalkForwardError("minimum training PF must be finite and > 0")
    if starting_equity <= 0 or not math.isfinite(starting_equity):
        raise WalkForwardError("starting equity must be finite and > 0")
    if not universe or len(universe) != len(set(universe)):
        raise WalkForwardError("universe must be non-empty and unique")

    try:
        cost_report, observed_sha = book._load_cost_report(
            cost_report_path,
            expected_cost_report_sha256,
            expected_sleeve_count,
        )
        indexed = book._index_sleeves(cost_report)
    except book.DarwiniaProxyError as exc:
        raise WalkForwardError(str(exc)) from exc
    unknown = sorted(set(universe) - set(indexed))
    if unknown:
        raise WalkForwardError(f"universe contains unknown keys: {unknown}")

    training_rows: list[dict[str, Any]] = []
    selected: list[str] = []
    for key in universe:
        try:
            events = book._cohort_events(
                indexed, (key,), train_start, train_end
            )
        except book.DarwiniaProxyError as exc:
            raise WalkForwardError(str(exc)) from exc
        values = [float(item.pnl) for item in events]
        pf = _profit_factor(values)
        passes = (
            len(values) >= minimum_training_trades
            and pf is not None
            and pf >= minimum_training_pf
        )
        if passes:
            selected.append(key)
        training_rows.append(
            {
                "key": key,
                "closed_trades": len(values),
                "gross_profit": round(sum(v for v in values if v > 0.0), 10),
                "gross_loss": round(sum(v for v in values if v < 0.0), 10),
                "net": round(sum(values), 10),
                "profit_factor": None if pf is None else round(pf, 10),
                "selected": passes,
                "event_stream_sha256": book.canonical_sha256(
                    [
                        [
                            event.entry_time.isoformat(),
                            event.exit_time.isoformat(),
                            event.sleeve_key,
                            event.source_row_index,
                            round(event.pnl, 10),
                        ]
                        for event in events
                    ]
                ),
            }
        )
    if not selected:
        raise WalkForwardError("training rule selected no sleeves")

    try:
        selected_evaluation = book.evaluate_cohort(
            indexed,
            selected,
            start=test_start,
            end=test_end,
            starting_equity=starting_equity,
            note=(
                "Selected mechanically using only the declared earlier training "
                "window; evaluation window was not used by the selector."
            ),
        )
        universe_evaluation = book.evaluate_cohort(
            indexed,
            tuple(universe),
            start=test_start,
            end=test_end,
            starting_equity=starting_equity,
            note="All explicitly declared universe sleeves; diagnostic benchmark.",
        )
    except book.DarwiniaProxyError as exc:
        raise WalkForwardError(str(exc)) from exc

    try:
        parsed_as_of = dt.datetime.fromisoformat(as_of_utc.replace("Z", "+00:00"))
    except ValueError as exc:
        raise WalkForwardError("as-of-utc must be ISO-8601 with offset") from exc
    if parsed_as_of.tzinfo is None:
        raise WalkForwardError("as-of-utc must be ISO-8601 with offset")
    implementation = (implementation_path or Path(__file__)).resolve(strict=True)
    dependency = (dependency_path or Path(book.__file__)).resolve(strict=True)
    result: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "tool": "dxz_darwinia_walkforward_proxy",
        "tool_version": TOOL_VERSION,
        "as_of_utc": parsed_as_of.astimezone(dt.UTC).replace(microsecond=0).isoformat(),
        "status": "RESEARCH_HOLDOUT_DIAGNOSTIC_NON_QUALIFYING",
        "deployment_eligible": False,
        "implementation": {
            "path": str(implementation),
            "sha256": book.sha256_file(implementation),
            "book_proxy_dependency_path": str(dependency),
            "book_proxy_dependency_sha256": book.sha256_file(dependency),
        },
        "input": {
            "cost_report_path": str(cost_report_path.resolve()),
            "cost_report_sha256": observed_sha,
            "expected_sleeve_count": expected_sleeve_count,
            "universe": list(universe),
            "universe_count": len(universe),
        },
        "selection_contract": {
            "training_window": {
                "from": train_start.isoformat(),
                "to": train_end.isoformat(),
                "inclusive": True,
            },
            "minimum_training_closed_trades": minimum_training_trades,
            "minimum_training_profit_factor": minimum_training_pf,
            "profit_factor_basis": (
                "conservative commission-adjusted exit-event P&L in the training window; "
                "recorded tester swap included"
            ),
            "finite_loss_denominator_required": True,
            "selected_keys": selected,
            "selected_count": len(selected),
        },
        "training_sleeves": training_rows,
        "evaluation_window": {
            "from": test_start.isoformat(),
            "to": test_end.isoformat(),
            "inclusive": True,
            "strictly_after_training": True,
        },
        "selected_cohort_evaluation": selected_evaluation,
        "full_universe_evaluation": universe_evaluation,
        "limitations": [
            "This is one historical split selected after the research programme began, not untouched prospective evidence.",
            "Training selection is based on exit-event P&L; no evaluation-window exit P&L is read by the mechanical selector, but strategy-development and universe-selection leakage remain possible.",
            "Exit-event P&L is not a DARWIN quote or mark-to-market equity curve.",
            "Same-second cross-sleeve execution order is unavailable; the deterministic tie-break is sleeve key then source row index.",
            "Darwinex Risk Engine, dynamic VaR, interventions and D-Leverage are not simulated.",
            "B/C/D raw-history discontinuities occur within the evaluation window and remain disqualifying until segmented.",
            "A 100% real-ticks label means historical spread is embedded in tester prices; it does not certify current or broker-parity spread. Current swap parity and slippage remain open.",
            "Sleeve P&Ls come from independent tester paths and are summed without synchronized shared-equity sizing, capital, margin, exposure or risk-budget matching.",
            "The SILVER activity proxy uses entry timestamps from completed round trips and cannot observe an entry that never appears in a completed round trip.",
            "Card/EA/preset/binary/news/Friday/routing governance remains independent and can reject a selected sleeve.",
            "No portfolio resize, DarwinIA rating, allocation probability, deployment, or sustainability claim follows from this report.",
        ],
    }
    result["integrity"] = {
        "payload_sha256": book.canonical_sha256(result),
        "payload_hash_scope": "canonical JSON with integrity field omitted",
        "final_file_sha256": "SEE_EXCLUSIVE_SIDECAR",
    }
    return result


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cost-report", type=Path, required=True)
    parser.add_argument("--expected-cost-report-sha256", required=True)
    parser.add_argument("--expected-sleeve-count", type=int, required=True)
    parser.add_argument("--universe", required=True)
    parser.add_argument("--train-from", required=True)
    parser.add_argument("--train-to", required=True)
    parser.add_argument("--evaluate-from", required=True)
    parser.add_argument("--evaluate-to", required=True)
    parser.add_argument("--minimum-training-trades", type=int, required=True)
    parser.add_argument("--minimum-training-pf", type=float, required=True)
    parser.add_argument("--starting-equity", type=float, default=100000.0)
    parser.add_argument("--as-of-utc", required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    report = build_report(
        args.cost_report,
        expected_cost_report_sha256=args.expected_cost_report_sha256,
        expected_sleeve_count=args.expected_sleeve_count,
        universe=parse_universe(args.universe),
        train_from=args.train_from,
        train_to=args.train_to,
        evaluate_from=args.evaluate_from,
        evaluate_to=args.evaluate_to,
        minimum_training_trades=args.minimum_training_trades,
        minimum_training_pf=args.minimum_training_pf,
        starting_equity=args.starting_equity,
        as_of_utc=args.as_of_utc,
    )
    try:
        digest = book.write_immutable_report(report, args.output)
    except book.DarwiniaProxyError as exc:
        raise WalkForwardError(str(exc)) from exc
    print(
        json.dumps(
            {
                "output": str(args.output.resolve()),
                "sha256": digest,
                "selected_count": report["selection_contract"]["selected_count"],
                "deployment_eligible": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except WalkForwardError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
