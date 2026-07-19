"""Build a non-qualifying DarwinIA book diagnostic from sealed DXZ cost evidence.

The diagnostic aggregates conservative, commission-adjusted closing P&L.  It is
deliberately not a DARWIN quote reconstruction: intratrade mark-to-market,
Darwinex's Risk Engine, current broker swap parity, and slippage are unavailable.
Every cohort must be named and enumerated explicitly so an ex-post selection
cannot masquerade as an out-of-sample rule.
"""

from __future__ import annotations

import argparse
import calendar
import datetime as dt
import hashlib
import json
import math
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable, Mapping, NamedTuple, Sequence


SCHEMA_VERSION = 2
TOOL_VERSION = "1.3.0"
COHORT_NAME_RE = re.compile(r"[A-Za-z][A-Za-z0-9_-]{0,63}")
EXIT_TIME_FORMAT = "%Y.%m.%d %H:%M:%S"

DARWINIA_RULES_SOURCE = "https://help.darwinex.com/what-is-darwinia"
DARWINIA_RATING_SOURCE = "https://www.darwinexzero.com/docs/rating"
RISK_ENGINE_SOURCE = "https://www.darwinexzero.com/docs/en/risk-engine"


class DarwiniaProxyError(RuntimeError):
    """Raised when an input or requested diagnostic is not fail-closed."""


class RoundTripEvent(NamedTuple):
    """One cost-adjusted round trip with its full MT5-server timestamps."""

    entry_time: dt.datetime
    exit_time: dt.datetime
    sleeve_key: str
    source_row_index: int
    pnl: float


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_sha256(value: Any) -> str:
    payload = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _strict_date(raw: str, label: str) -> dt.date:
    try:
        value = dt.date.fromisoformat(raw)
    except ValueError as exc:
        raise DarwiniaProxyError(f"{label} must be strict YYYY-MM-DD: {raw!r}") from exc
    if value.isoformat() != raw:
        raise DarwiniaProxyError(f"{label} must be strict YYYY-MM-DD: {raw!r}")
    return value


def _finite(value: Any, label: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise DarwiniaProxyError(f"{label} is not numeric: {value!r}") from exc
    if not math.isfinite(number):
        raise DarwiniaProxyError(f"{label} is not finite: {value!r}")
    return number


def _month_iter(start: dt.date, end: dt.date) -> Iterable[tuple[int, int]]:
    year, month = start.year, start.month
    while (year, month) <= (end.year, end.month):
        yield year, month
        month += 1
        if month == 13:
            year += 1
            month = 1


def _month_bounds(month: tuple[int, int]) -> tuple[dt.date, dt.date]:
    year, number = month
    return (
        dt.date(year, number, 1),
        dt.date(year, number, calendar.monthrange(year, number)[1]),
    )


def _drawdown(values: Iterable[float]) -> float:
    equity = 0.0
    peak = 0.0
    maximum = 0.0
    for value in values:
        equity += value
        peak = max(peak, equity)
        maximum = max(maximum, peak - equity)
    return maximum


def parse_cohort(raw: str) -> tuple[str, tuple[str, ...]]:
    if "=" not in raw:
        raise DarwiniaProxyError("cohort must be NAME=KEY,KEY,...")
    name, keys_raw = raw.split("=", 1)
    name = name.strip()
    if COHORT_NAME_RE.fullmatch(name) is None:
        raise DarwiniaProxyError(f"invalid cohort name: {name!r}")
    keys = tuple(item.strip() for item in keys_raw.split(",") if item.strip())
    if not keys:
        raise DarwiniaProxyError(f"cohort {name!r} is empty")
    if len(keys) != len(set(keys)):
        raise DarwiniaProxyError(f"cohort {name!r} contains duplicate keys")
    return name, keys


def parse_cohort_note(raw: str) -> tuple[str, str]:
    if "=" not in raw:
        raise DarwiniaProxyError("cohort note must be NAME=TEXT")
    name, note = raw.split("=", 1)
    name = name.strip()
    note = note.strip()
    if COHORT_NAME_RE.fullmatch(name) is None or not note:
        raise DarwiniaProxyError(f"invalid cohort note: {raw!r}")
    return name, note


def _load_cost_report(
    path: Path, expected_sha256: str, expected_sleeve_count: int
) -> tuple[dict[str, Any], str]:
    resolved = path.expanduser().resolve(strict=True)
    observed_sha = sha256_file(resolved)
    if observed_sha.casefold() != expected_sha256.casefold():
        raise DarwiniaProxyError(
            f"cost report SHA mismatch: expected {expected_sha256}, observed {observed_sha}"
        )
    try:
        report = json.loads(resolved.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise DarwiniaProxyError(f"cannot read cost report: {exc}") from exc
    if not isinstance(report, dict):
        raise DarwiniaProxyError("cost report must be a JSON object")
    if report.get("artifact_type") != "DXZ_STANDALONE_COST_EVIDENCE":
        raise DarwiniaProxyError("unexpected cost report artifact_type")
    if report.get("schema_version") != 3:
        raise DarwiniaProxyError("cost report must use schema_version=3")
    if report.get("deployment_eligible") is not False:
        raise DarwiniaProxyError("cost report must remain deployment_eligible=false")
    summary = report.get("summary")
    if not isinstance(summary, Mapping):
        raise DarwiniaProxyError("cost report lacks schema-v3 summary")
    policy = report.get("policy")
    if (
        not isinstance(policy, Mapping)
        or policy.get("round_trip_notional_rate") != 0.00005
        or policy.get("round_trip_notional_percent") != 0.005
        or policy.get("round_trip_notional_basis_points") != 0.5
    ):
        raise DarwiniaProxyError("cost report rate-unit contract is invalid")
    if "spread_certified_100_percent_real_ticks" in summary:
        raise DarwiniaProxyError("cost report uses superseded spread-certification field")
    if summary.get("current_broker_spread_parity_certified") != 0:
        raise DarwiniaProxyError(
            "commission-only proxy requires current broker spread parity to remain uncertified"
        )
    if not isinstance(
        summary.get("reports_with_100_percent_real_ticks_spread_embedded"), int
    ):
        raise DarwiniaProxyError("cost report lacks historical spread-embedding count")
    sleeves = report.get("sleeves")
    if not isinstance(sleeves, list) or len(sleeves) != expected_sleeve_count:
        raise DarwiniaProxyError(
            f"cost report sleeves != expected {expected_sleeve_count}"
        )
    return report, observed_sha


def _index_sleeves(report: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    indexed: dict[str, Mapping[str, Any]] = {}
    for index, sleeve in enumerate(report.get("sleeves") or []):
        if not isinstance(sleeve, Mapping):
            raise DarwiniaProxyError(f"sleeve {index} is not an object")
        meta = sleeve.get("sleeve")
        if not isinstance(meta, Mapping):
            raise DarwiniaProxyError(f"sleeve {index} lacks metadata")
        key = str(meta.get("key") or "").strip()
        if not key or key in indexed:
            raise DarwiniaProxyError(f"invalid or duplicate sleeve key: {key!r}")
        if sleeve.get("unbounded_trade_count") not in (0, 0.0):
            raise DarwiniaProxyError(f"sleeve {key} has unbounded cost ambiguity")
        indexed[key] = sleeve
    return indexed


def _cohort_round_trips(
    indexed: Mapping[str, Mapping[str, Any]],
    keys: Sequence[str],
) -> list[RoundTripEvent]:
    unknown = sorted(set(keys) - set(indexed))
    if unknown:
        raise DarwiniaProxyError(f"cohort contains unknown keys: {unknown}")
    events: list[RoundTripEvent] = []
    for key in keys:
        rows = indexed[key].get("round_trips")
        if not isinstance(rows, list):
            raise DarwiniaProxyError(f"sleeve {key} lacks round_trips")
        for row_index, row in enumerate(rows):
            if not isinstance(row, Mapping):
                raise DarwiniaProxyError(f"{key} round trip {row_index} is not an object")
            raw_entry_time = str(row.get("entry_time_mt5_server") or "")
            raw_exit_time = str(row.get("exit_time_mt5_server") or "")
            try:
                entry_time = dt.datetime.strptime(raw_entry_time, EXIT_TIME_FORMAT)
                exit_time = dt.datetime.strptime(raw_exit_time, EXIT_TIME_FORMAT)
            except ValueError as exc:
                raise DarwiniaProxyError(
                    f"{key} round trip {row_index} has invalid entry/exit time "
                    f"{raw_entry_time!r}/{raw_exit_time!r}"
                ) from exc
            if entry_time > exit_time:
                raise DarwiniaProxyError(
                    f"{key} round trip {row_index} enters after it exits"
                )
            pnl = _finite(
                row.get("conservative_cost_adjusted_pnl"),
                f"{key} round trip {row_index} conservative P&L",
            )
            events.append(
                RoundTripEvent(entry_time, exit_time, key, row_index, pnl)
            )
    events.sort(
        key=lambda item: (
            item.exit_time,
            item.sleeve_key,
            item.source_row_index,
        )
    )
    return events


def _cohort_events(
    indexed: Mapping[str, Mapping[str, Any]],
    keys: Sequence[str],
    start: dt.date,
    end: dt.date,
) -> list[RoundTripEvent]:
    """Return round trips whose exits fall in the inclusive evaluation window."""

    return [
        event
        for event in _cohort_round_trips(indexed, keys)
        if start <= event.exit_time.date() <= end
    ]


def evaluate_cohort(
    indexed: Mapping[str, Mapping[str, Any]],
    keys: Sequence[str],
    *,
    start: dt.date,
    end: dt.date,
    starting_equity: float,
    note: str,
) -> dict[str, Any]:
    if starting_equity <= 0 or not math.isfinite(starting_equity):
        raise DarwiniaProxyError("starting equity must be finite and > 0")
    all_events = _cohort_round_trips(indexed, keys)
    events = [
        event
        for event in all_events
        if start <= event.exit_time.date() <= end
    ]
    entry_events = [
        event
        for event in all_events
        if start <= event.entry_time.date() <= end
    ]
    daily: dict[dt.date, float] = defaultdict(float)
    monthly_net: dict[tuple[int, int], float] = defaultdict(float)
    monthly_closes: dict[tuple[int, int], int] = defaultdict(int)
    monthly_entries: dict[tuple[int, int], int] = defaultdict(int)
    per_key: dict[str, dict[str, float | int]] = {
        key: {"closed_trades": 0, "net": 0.0} for key in keys
    }
    for event in events:
        day = event.exit_time.date()
        key = event.sleeve_key
        pnl = event.pnl
        daily[day] += pnl
        month = (day.year, day.month)
        monthly_net[month] += pnl
        monthly_closes[month] += 1
        per_key[key]["closed_trades"] = int(per_key[key]["closed_trades"]) + 1
        per_key[key]["net"] = float(per_key[key]["net"]) + pnl
    for event in entry_events:
        month = (event.entry_time.year, event.entry_time.month)
        monthly_entries[month] += 1

    months = list(_month_iter(start, end))
    monthly: list[dict[str, Any]] = []
    for index, month in enumerate(months):
        prior = months[index - 1] if index else None
        net = monthly_net[month]
        closed_trades = monthly_closes[month]
        opened_trades = monthly_entries[month]
        active_current_or_prior = opened_trades > 0 or (
            prior is not None and monthly_entries[prior] > 0
        )
        monthly.append(
            {
                "month": f"{month[0]:04d}-{month[1]:02d}",
                "closed_trades": closed_trades,
                "opened_completed_round_trips": opened_trades,
                "net": round(net, 10),
                "simple_return_pct_on_starting_equity": round(
                    net / starting_equity * 100.0, 10
                ),
                "silver_entry_activity_proxy": active_current_or_prior,
            }
        )

    rolling: list[dict[str, Any]] = []
    sorted_days = sorted(daily)
    for index in range(5, len(months)):
        window_months = months[index - 5 : index + 1]
        window_start, _ = _month_bounds(window_months[0])
        _, window_end = _month_bounds(window_months[-1])
        window_events = [
            event
            for event in events
            if window_start <= event.exit_time.date() <= window_end
        ]
        net = sum(monthly_net[month] for month in window_months)
        exit_event_drawdown = _drawdown(event.pnl for event in window_events)
        daily_netted_drawdown = _drawdown(
            daily[day]
            for day in sorted_days
            if window_start <= day <= window_end
        )
        rolling.append(
            {
                "through_month": f"{window_months[-1][0]:04d}-{window_months[-1][1]:02d}",
                "from_month": f"{window_months[0][0]:04d}-{window_months[0][1]:02d}",
                "net": round(net, 10),
                "simple_return_pct_on_starting_equity": round(
                    net / starting_equity * 100.0, 10
                ),
                "exit_event_max_drawdown": round(exit_event_drawdown, 10),
                "exit_event_max_drawdown_pct_on_starting_equity": round(
                    exit_event_drawdown / starting_equity * 100.0, 10
                ),
                "daily_netted_close_pnl_max_drawdown": round(
                    daily_netted_drawdown, 10
                ),
                "daily_netted_close_pnl_max_drawdown_pct_on_starting_equity": round(
                    daily_netted_drawdown / starting_equity * 100.0, 10
                ),
                "closed_trades": sum(
                    monthly_closes[month] for month in window_months
                ),
                "opened_completed_round_trips": sum(
                    monthly_entries[month] for month in window_months
                ),
                "positive": net > 0.0,
            }
        )

    net_total = sum(event.pnl for event in events)
    exit_event_drawdown_total = _drawdown(event.pnl for event in events)
    daily_netted_drawdown_total = _drawdown(daily[day] for day in sorted_days)
    rolling_nets = [float(row["net"]) for row in rolling]
    rolling_exit_event_drawdowns = [
        float(row["exit_event_max_drawdown"]) for row in rolling
    ]
    rolling_daily_netted_drawdowns = [
        float(row["daily_netted_close_pnl_max_drawdown"]) for row in rolling
    ]
    return {
        "selection_note": note,
        "keys": list(keys),
        "key_count": len(keys),
        "event_stream_sha256": canonical_sha256(
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
        "drawdown_contract": {
            "exit_event_order": (
                "full MT5-server exit timestamp, sleeve key, source row index"
            ),
            "same_second_cross_sleeve_execution_order_known": False,
            "daily_metric": "all close P&L netted by MT5-server calendar date",
        },
        "activity_contract": {
            "basis": "entry_time_mt5_server from completed round trips",
            "open_positions_without_a_completed_round_trip_observable": False,
            "official_live_rule_reconstructed": False,
        },
        "window": {
            "from": start.isoformat(),
            "to": end.isoformat(),
            "inclusive": True,
            "starting_equity": starting_equity,
        },
        "summary": {
            "closed_trades": len(events),
            "opened_completed_round_trips": len(entry_events),
            "net": round(net_total, 10),
            "simple_return_pct_on_starting_equity": round(
                net_total / starting_equity * 100.0, 10
            ),
            "exit_event_max_drawdown": round(exit_event_drawdown_total, 10),
            "exit_event_max_drawdown_pct_on_starting_equity": round(
                exit_event_drawdown_total / starting_equity * 100.0, 10
            ),
            "daily_netted_close_pnl_max_drawdown": round(
                daily_netted_drawdown_total, 10
            ),
            "daily_netted_close_pnl_max_drawdown_pct_on_starting_equity": round(
                daily_netted_drawdown_total / starting_equity * 100.0, 10
            ),
            "calendar_months": len(months),
            "months_with_closes": sum(
                row["closed_trades"] > 0 for row in monthly
            ),
            "positive_months_with_closes": sum(
                row["closed_trades"] > 0 and row["net"] > 0 for row in monthly
            ),
            "months_with_entries": sum(
                row["opened_completed_round_trips"] > 0 for row in monthly
            ),
            "silver_entry_activity_proxy_months": sum(
                bool(row["silver_entry_activity_proxy"]) for row in monthly
            ),
            "rolling_six_month_windows": len(rolling),
            "positive_rolling_six_month_windows": sum(
                bool(row["positive"]) for row in rolling
            ),
            "minimum_rolling_six_month_net": (
                round(min(rolling_nets), 10) if rolling_nets else None
            ),
            "maximum_rolling_six_month_net": (
                round(max(rolling_nets), 10) if rolling_nets else None
            ),
            "maximum_rolling_six_month_exit_event_drawdown": (
                round(max(rolling_exit_event_drawdowns), 10)
                if rolling_exit_event_drawdowns
                else None
            ),
            "maximum_rolling_six_month_daily_netted_close_pnl_drawdown": (
                round(max(rolling_daily_netted_drawdowns), 10)
                if rolling_daily_netted_drawdowns
                else None
            ),
        },
        "per_sleeve_close_pnl": {
            key: {
                "closed_trades": int(per_key[key]["closed_trades"]),
                "net": round(float(per_key[key]["net"]), 10),
            }
            for key in keys
        },
        "monthly": monthly,
        "rolling_six_month": rolling,
        "status": "RESEARCH_DIAGNOSTIC_NON_QUALIFYING",
        "deployment_eligible": False,
    }


def build_report(
    cost_report_path: Path,
    *,
    expected_cost_report_sha256: str,
    expected_sleeve_count: int,
    cohorts: Sequence[tuple[str, Sequence[str]]],
    cohort_notes: Mapping[str, str],
    from_date: str,
    to_date: str,
    starting_equity: float,
    as_of_utc: str,
    implementation_path: Path | None = None,
) -> dict[str, Any]:
    start = _strict_date(from_date, "from-date")
    end = _strict_date(to_date, "to-date")
    if start > end:
        raise DarwiniaProxyError("from-date must be <= to-date")
    try:
        as_of = dt.datetime.fromisoformat(as_of_utc.replace("Z", "+00:00"))
    except ValueError as exc:
        raise DarwiniaProxyError("as-of-utc must be ISO-8601") from exc
    if as_of.tzinfo is None:
        raise DarwiniaProxyError("as-of-utc must include an offset")
    normalized_as_of = as_of.astimezone(dt.UTC).replace(microsecond=0).isoformat()
    if starting_equity <= 0 or not math.isfinite(starting_equity):
        raise DarwiniaProxyError("starting-equity must be finite and > 0")

    report, observed_sha = _load_cost_report(
        cost_report_path, expected_cost_report_sha256, expected_sleeve_count
    )
    indexed = _index_sleeves(report)
    names = [name for name, _ in cohorts]
    if not cohorts or len(names) != len(set(names)):
        raise DarwiniaProxyError("at least one uniquely named cohort is required")
    if set(cohort_notes) != set(names):
        raise DarwiniaProxyError("every cohort requires exactly one explicit note")

    implementation = (implementation_path or Path(__file__)).resolve(strict=True)
    evaluated = {
        name: evaluate_cohort(
            indexed,
            tuple(keys),
            start=start,
            end=end,
            starting_equity=starting_equity,
            note=cohort_notes[name],
        )
        for name, keys in cohorts
    }
    result: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "tool": "dxz_darwinia_book_proxy",
        "tool_version": TOOL_VERSION,
        "as_of_utc": normalized_as_of,
        "status": "RESEARCH_DIAGNOSTIC_NON_QUALIFYING",
        "deployment_eligible": False,
        "implementation": {
            "path": str(implementation),
            "sha256": sha256_file(implementation),
        },
        "input": {
            "cost_report_path": str(cost_report_path.resolve()),
            "cost_report_sha256": observed_sha,
            "expected_sleeve_count": expected_sleeve_count,
        },
        "darwinia_policy_snapshot": {
            "as_of": "2026-07-16",
            "sources": [
                DARWINIA_RULES_SOURCE,
                DARWINIA_RATING_SOURCE,
                RISK_ENGINE_SOURCE,
            ],
            "silver_rating_inputs": {
                "current_calendar_month_return_weight_pct": 22,
                "current_plus_prior_five_calendar_month_return_weight_pct": 67,
                "six_calendar_month_max_drawdown_weight_pct": 11,
                "minimum_rating_for_guaranteed_allocation": 75,
                "rating_formula": "PROPRIETARY_NOT_RECONSTRUCTED",
            },
            "trade_activity_rule": (
                "at least one trade in current or immediately preceding month"
            ),
            "trade_activity_proxy_basis": (
                "entry_time_mt5_server on completed historical round trips; "
                "not proof of activity on a live DARWIN"
            ),
            "risk_engine": {
                "maximum_monthly_target_var_pct": 6.5,
                "dynamic_target_var_range_pct": [3.25, 6.5],
                "strategy_var_reference": "last 45 exposed days",
                "simulated_here": False,
            },
        },
        "cohorts": evaluated,
        "limitations": [
            "Exit-event P&L is not a DARWIN quote or mark-to-market equity curve.",
            "Same-second cross-sleeve execution order is unavailable; the deterministic tie-break is sleeve key then source row index.",
            "Darwinex Risk Engine sizing, interventions, D-Leverage and dynamic VaR are not simulated.",
            "The proprietary DarwinIA rating cannot be reconstructed from public weights.",
            "A 100% real-ticks label means historical spread is embedded in tester prices; it does not certify current or broker-parity spread.",
            "Current broker swap-rate parity and slippage remain unevaluated.",
            "Sleeve P&Ls come from independent tester paths and are summed without synchronized shared-equity sizing, capital, margin, exposure or risk-budget matching.",
            "The SILVER activity proxy uses entry timestamps from completed round trips and cannot observe an entry that never appears in a completed round trip.",
            "B/C/D raw-history gaps are not repaired by aggregation.",
            "A cohort selected using these same full-sample PFs is explicitly in-sample and cannot establish sustainability.",
            "Card, EA, preset, binary, news, Friday, routing and portfolio governance remain independent gates.",
        ],
    }
    result["integrity"] = {
        "payload_sha256": canonical_sha256(result),
        "payload_hash_scope": "canonical JSON with integrity field omitted",
        "final_file_sha256": "SEE_EXCLUSIVE_SIDECAR",
    }
    return result


def write_immutable_report(report: Mapping[str, Any], output: Path) -> str:
    resolved = output.expanduser().resolve()
    sidecar = resolved.with_name(resolved.name + ".sha256")
    if resolved.exists() or sidecar.exists():
        raise DarwiniaProxyError(f"refusing overwrite: {resolved} or {sidecar}")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    payload = (
        json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False)
        + "\n"
    ).encode("utf-8")
    try:
        with resolved.open("xb") as handle:
            handle.write(payload)
        digest = hashlib.sha256(payload).hexdigest()
        with sidecar.open("x", encoding="ascii", newline="\n") as handle:
            handle.write(f"{digest}  {resolved.name}\n")
    except Exception:
        raise
    try:
        os.chmod(resolved, 0o444)
        os.chmod(sidecar, 0o444)
    except OSError:
        pass
    return digest


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cost-report", type=Path, required=True)
    parser.add_argument("--expected-cost-report-sha256", required=True)
    parser.add_argument("--expected-sleeve-count", type=int, required=True)
    parser.add_argument(
        "--cohort", action="append", required=True, help="NAME=KEY,KEY,..."
    )
    parser.add_argument(
        "--cohort-note", action="append", required=True, help="NAME=TEXT"
    )
    parser.add_argument("--from-date", required=True)
    parser.add_argument("--to-date", required=True)
    parser.add_argument("--starting-equity", type=float, default=100000.0)
    parser.add_argument("--as-of-utc", required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    cohorts = [parse_cohort(raw) for raw in args.cohort]
    notes = dict(parse_cohort_note(raw) for raw in args.cohort_note)
    report = build_report(
        args.cost_report,
        expected_cost_report_sha256=args.expected_cost_report_sha256,
        expected_sleeve_count=args.expected_sleeve_count,
        cohorts=cohorts,
        cohort_notes=notes,
        from_date=args.from_date,
        to_date=args.to_date,
        starting_equity=args.starting_equity,
        as_of_utc=args.as_of_utc,
    )
    digest = write_immutable_report(report, args.output)
    print(
        json.dumps(
            {
                "output": str(args.output.resolve()),
                "sha256": digest,
                "cohorts": sorted(report["cohorts"]),
                "deployment_eligible": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except DarwiniaProxyError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
