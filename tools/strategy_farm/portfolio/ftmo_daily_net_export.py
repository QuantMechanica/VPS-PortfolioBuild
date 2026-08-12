"""Export one fail-closed, FTMO-venue-attested daily sleeve stream.

The finite-horizon evaluator deliberately refuses ordinary Q08 streams because
their bid/ask prices came from Darwinex.  This exporter accepts a *native FTMO*
Strategy Tester report plus the exact Q08 trade/equity harvest from that same
run.  It verifies the venue, real-tick marker, immutable artifact identities,
full-lifecycle money reconciliation, set-file risk guardrails, and the pinned
FTMO instrument terms before writing ``FTMO_DAILY_NET_V1`` rows.

No terminal, queue, database, or live setting is touched by this program.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .ftmo_phase1_mae import (
        FULL_POSITION_LIFECYCLE_ACTUAL_V1,
        q08_round_trip_values,
        q08_stream_money_basis,
    )
    from .ftmo_report_cost_reconcile import (
        RoundTrip,
        extract_round_trips,
        ftmo_trade_commission_sides,
        ftmo_trade_net,
    )
    from .ftmo_stream_reconciliation import (
        load_q08_trade_rows,
        reconcile_case,
        strict_json_loads,
    )
    from .ftmo_timebox_eval import DAILY_STREAM_SCHEMA
    from .prop_challenge_optimizer import _normalize_cell, _report_rows
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_phase1_mae import (  # type: ignore
        FULL_POSITION_LIFECYCLE_ACTUAL_V1,
        q08_round_trip_values,
        q08_stream_money_basis,
    )
    from ftmo_report_cost_reconcile import (  # type: ignore
        RoundTrip,
        extract_round_trips,
        ftmo_trade_commission_sides,
        ftmo_trade_net,
    )
    from ftmo_stream_reconciliation import (  # type: ignore
        load_q08_trade_rows,
        reconcile_case,
        strict_json_loads,
    )
    from ftmo_timebox_eval import DAILY_STREAM_SCHEMA  # type: ignore
    from prop_challenge_optimizer import _normalize_cell, _report_rows  # type: ignore


EXPORT_RECEIPT_SCHEMA = "qm.ftmo-daily-net-export-receipt/v1"
PINNED_COST_SNAPSHOT_SHA256 = (
    "7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da"
)
FTMO_VENUE = "FTMO"
FTMO_TERMS = "FTMO_TERMS"
MAX_INPUT_BYTES = 512 * 1024 * 1024
MAX_JSONL_LINE_BYTES = 1024 * 1024
MAX_JSONL_LINES = 2_000_000
MONEY_TOLERANCE = 0.01
EQUITY_TOLERANCE = 0.02
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
REPORT_PERIOD_RE = re.compile(
    r"\((?P<from>\d{4}\.\d{2}\.\d{2})\s+-\s+"
    r"(?P<to>\d{4}\.\d{2}\.\d{2})\)"
)


class FtmoDailyExportError(ValueError):
    """The supplied run cannot support FTMO daily-stream attestation."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        if path.stat().st_size > MAX_INPUT_BYTES:
            raise FtmoDailyExportError(f"input exceeds size limit: {path}")
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise FtmoDailyExportError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def binding(path: Path) -> dict[str, Any]:
    resolved = path.expanduser().resolve()
    if not resolved.is_file():
        raise FtmoDailyExportError(f"required input is not a file: {resolved}")
    return {
        "path": str(resolved),
        "size_bytes": resolved.stat().st_size,
        "sha256": sha256_file(resolved),
    }


def _strict_json_file(path: Path, label: str) -> Any:
    try:
        value = strict_json_loads(path.read_text(encoding="utf-8-sig"), label=label)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        raise FtmoDailyExportError(f"{label}: invalid JSON: {exc}") from exc
    return value


def _finite(value: Any, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise FtmoDailyExportError(f"{label}: expected JSON number")
    number = float(value)
    if not math.isfinite(number):
        raise FtmoDailyExportError(f"{label}: expected finite number")
    return number


def _date_from_dot(value: str, label: str) -> dt.date:
    try:
        parsed = dt.datetime.strptime(value, "%Y.%m.%d").date()
    except ValueError as exc:
        raise FtmoDailyExportError(f"{label}: expected YYYY.MM.DD") from exc
    if parsed.strftime("%Y.%m.%d") != value:
        raise FtmoDailyExportError(f"{label}: non-canonical date")
    return parsed


def _continuous_days(start: dt.date, end: dt.date) -> list[dt.date]:
    if end < start:
        raise FtmoDailyExportError("report window ends before it starts")
    return [start + dt.timedelta(days=index) for index in range((end - start).days + 1)]


def _decode_setfile(path: Path) -> str:
    raw = path.read_bytes()
    if len(raw) > MAX_INPUT_BYTES:
        raise FtmoDailyExportError(f"setfile exceeds size limit: {path}")
    encodings = ["utf-16-le", "utf-8-sig"] if b"\x00" in raw[:80] else ["utf-8-sig", "utf-16-le"]
    for encoding in encodings:
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise FtmoDailyExportError(f"setfile is not valid UTF-8/UTF-16LE: {path}")


def _setfile_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line_number, raw_line in enumerate(_decode_setfile(path).splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key in values:
            raise FtmoDailyExportError(
                f"setfile:{line_number}: duplicate input {key!r}"
            )
        values[key] = value
    return values


def _numeric_text(value: str, label: str) -> float:
    try:
        number = float(value)
    except ValueError as exc:
        raise FtmoDailyExportError(f"{label}: expected numeric value") from exc
    if not math.isfinite(number):
        raise FtmoDailyExportError(f"{label}: expected finite value")
    return number


def validate_setfile_guardrails(path: Path) -> dict[str, float | None]:
    values = _setfile_values(path)
    if "RISK_FIXED" not in values or "RISK_PERCENT" not in values:
        raise FtmoDailyExportError("setfile must explicitly define RISK_FIXED and RISK_PERCENT")
    risk_fixed = _numeric_text(values["RISK_FIXED"], "setfile.RISK_FIXED")
    risk_percent = _numeric_text(values["RISK_PERCENT"], "setfile.RISK_PERCENT")
    if risk_fixed <= 0.0:
        raise FtmoDailyExportError("setfile.RISK_FIXED must be greater than zero")
    if risk_percent != 0.0:
        raise FtmoDailyExportError("setfile.RISK_PERCENT must equal zero")
    stale_raw = values.get("qm_news_stale_max_hours")
    stale = (
        _numeric_text(stale_raw, "setfile.qm_news_stale_max_hours")
        if stale_raw is not None
        else None
    )
    if stale is not None and stale > 336.0:
        raise FtmoDailyExportError("setfile.qm_news_stale_max_hours exceeds 336")
    return {
        "risk_fixed": risk_fixed,
        "risk_percent": risk_percent,
        "qm_news_stale_max_hours": stale,
    }


def _report_fields(rows: Sequence[Sequence[str]]) -> tuple[dict[str, str], dict[str, str]]:
    fields: dict[str, str] = {}
    inputs: dict[str, str] = {}
    for row in rows:
        normalized = [str(cell).strip() for cell in row]
        for index, cell in enumerate(normalized):
            if not cell:
                continue
            if "=" in cell and not cell.endswith(":"):
                key, value = (part.strip() for part in cell.split("=", 1))
                if key and key not in inputs:
                    inputs[key] = value
            key = _normalize_cell(cell.rstrip(":"))
            if key in {
                "expert",
                "symbol",
                "period",
                "company",
                "currency",
                "initial deposit",
                "history quality",
                "total net profit",
                "total trades",
            }:
                value = next((item for item in normalized[index + 1 :] if item), "")
                if value and key not in fields:
                    fields[key] = value
    return fields, inputs


def _report_money(raw: str, label: str) -> float:
    token = raw.replace("\xa0", " ").replace("\u202f", " ").strip().replace(" ", "")
    if "," in token and "." in token:
        token = token.replace(",", "")
    elif "," in token:
        token = token.replace(",", ".")
    try:
        value = float(token)
    except ValueError as exc:
        raise FtmoDailyExportError(f"report.{label}: invalid number {raw!r}") from exc
    if not math.isfinite(value):
        raise FtmoDailyExportError(f"report.{label}: non-finite number")
    return value


def parse_ftmo_report_identity(
    report_path: Path, *, native_symbol: str
) -> dict[str, Any]:
    try:
        rows = _report_rows(report_path)
    except (OSError, UnicodeError, ValueError) as exc:
        raise FtmoDailyExportError(f"cannot parse MT5 report: {exc}") from exc
    if not rows:
        raise FtmoDailyExportError("MT5 report contains no rows")
    fields, inputs = _report_fields(rows)
    server_candidates = [
        str(row[0]).strip()
        for row in rows[:12]
        if len(row) == 1 and str(row[0]).strip()
    ]
    server = next(
        (value for value in server_candidates if re.search(r"(?i)FTMO.*Demo", value)),
        "",
    )
    if not server or any("darwinex" in value.lower() for value in server_candidates):
        raise FtmoDailyExportError("report is not a native FTMO-Demo Strategy Tester report")
    company = fields.get("company", "")
    if "ftmo" not in company.lower():
        raise FtmoDailyExportError(f"report company is not FTMO: {company!r}")
    if fields.get("symbol") != native_symbol:
        raise FtmoDailyExportError(
            f"report symbol mismatch: {fields.get('symbol')!r} != {native_symbol!r}"
        )
    quality = fields.get("history quality", "")
    if "real ticks" not in quality.lower():
        raise FtmoDailyExportError("report lacks a real-ticks history-quality marker")
    period = fields.get("period", "")
    match = REPORT_PERIOD_RE.search(period)
    if match is None:
        raise FtmoDailyExportError(f"report period is not parseable: {period!r}")
    initial_deposit = _report_money(fields.get("initial deposit", ""), "initial_deposit")
    net_profit = _report_money(fields.get("total net profit", ""), "total_net_profit")
    try:
        total_trades = int(fields.get("total trades", ""))
    except ValueError as exc:
        raise FtmoDailyExportError("report.total_trades is not an integer") from exc
    if initial_deposit <= 0.0 or total_trades <= 0:
        raise FtmoDailyExportError("report must have positive initial deposit and trades")

    for key in ("RISK_FIXED", "RISK_PERCENT"):
        if key not in inputs:
            raise FtmoDailyExportError(f"report inputs omit {key}")
    report_risk_fixed = _numeric_text(inputs["RISK_FIXED"], "report.RISK_FIXED")
    report_risk_percent = _numeric_text(inputs["RISK_PERCENT"], "report.RISK_PERCENT")
    if report_risk_fixed <= 0.0 or report_risk_percent != 0.0:
        raise FtmoDailyExportError("report violates fixed-risk backtest guardrail")
    stale = None
    if "qm_news_stale_max_hours" in inputs:
        stale = _numeric_text(
            inputs["qm_news_stale_max_hours"], "report.qm_news_stale_max_hours"
        )
        if stale > 336.0:
            raise FtmoDailyExportError("report.qm_news_stale_max_hours exceeds 336")
    return {
        "server": server,
        "company": company,
        "expert": fields.get("expert"),
        "native_symbol": fields["symbol"],
        "period": period,
        "from_date": match.group("from"),
        "to_date": match.group("to"),
        "currency": fields.get("currency"),
        "initial_deposit": initial_deposit,
        "total_net_profit": net_profit,
        "total_trades": total_trades,
        "history_quality": quality,
        "risk_fixed": report_risk_fixed,
        "risk_percent": report_risk_percent,
        "qm_news_stale_max_hours": stale,
    }


def _validated_summary(
    summary_path: Path,
    *,
    report_path: Path,
    native_symbol: str,
    setfile_path: Path,
    expected_trades: int,
) -> tuple[dict[str, Any], Mapping[str, Any]]:
    summary = _strict_json_file(summary_path, "summary")
    if not isinstance(summary, Mapping):
        raise FtmoDailyExportError("summary must be a JSON object")
    if summary.get("evidence_schema") != "run_smoke/v2" or summary.get("result") != "PASS":
        raise FtmoDailyExportError("summary is not a PASS run_smoke/v2 artifact")
    if summary.get("symbol") != native_symbol or int(summary.get("model", -1)) != 4:
        raise FtmoDailyExportError("summary does not bind native symbol + model-4")
    if summary.get("execution_identity", {}).get("stable_during_run") is not True:
        raise FtmoDailyExportError("summary execution artifacts were not stable during run")
    ok_runs = [
        run
        for run in summary.get("runs", [])
        if isinstance(run, Mapping) and run.get("status") == "OK"
    ]
    if len(ok_runs) != 1:
        raise FtmoDailyExportError("summary must contain exactly one usable OK run")
    run = ok_runs[0]
    if run.get("real_ticks_marker") is not True:
        raise FtmoDailyExportError("summary OK run lacks the real-ticks marker")
    if int(run.get("total_trades", -1)) != expected_trades:
        raise FtmoDailyExportError("summary/report trade-count mismatch")
    report_sha = sha256_file(report_path)
    if str(run.get("report_sha256", "")).lower() != report_sha:
        raise FtmoDailyExportError("summary does not hash-bind the supplied MT5 report")
    identity = summary.get("execution_identity", {})
    set_source = identity.get("setfile", {}).get("source", {})
    if str(set_source.get("sha256", "")).lower() != sha256_file(setfile_path):
        raise FtmoDailyExportError("summary does not hash-bind the supplied setfile")
    return dict(summary), run


def _cost_term(
    path: Path, *, ftmo_code: str, expected_sha256: str
) -> tuple[dict[str, Any], str]:
    actual_sha = sha256_file(path)
    if actual_sha != expected_sha256:
        raise FtmoDailyExportError(
            f"FTMO cost snapshot is not the pinned artifact: {actual_sha}"
        )
    value = _strict_json_file(path, "ftmo_cost_snapshot")
    if not isinstance(value, list):
        raise FtmoDailyExportError("FTMO cost snapshot must be an instrument list")
    matches = [
        item
        for item in value
        if isinstance(item, Mapping)
        and ftmo_code.upper()
        in {
            str(item.get("code", "")).upper(),
            str(item.get("displayCode", "")).upper(),
        }
    ]
    if len(matches) != 1:
        raise FtmoDailyExportError(f"FTMO cost term is absent/ambiguous: {ftmo_code}")
    term = dict(matches[0])
    required = (
        "commission",
        "commissionType",
        "swapLong",
        "swapShort",
        "swapType",
        "contractSize",
        "digits",
        "profitCurrency",
    )
    if term.get("active") is not True or any(term.get(field) is None for field in required):
        raise FtmoDailyExportError(f"FTMO term is inactive or incomplete: {ftmo_code}")
    for field in ("commission", "swapLong", "swapShort", "contractSize", "digits"):
        _finite(term[field], f"ftmo_cost_snapshot.{field}")
    if term["commissionType"] != "percent" or term["swapType"] != "points":
        raise FtmoDailyExportError("unsupported FTMO commission/swap type")
    if float(term["contractSize"]) <= 0.0 or int(term["digits"]) < 0:
        raise FtmoDailyExportError("invalid FTMO contract size/digits")
    return term, actual_sha


def _cost_reconciliation(
    trades: Sequence[RoundTrip], term: Mapping[str, Any]
) -> dict[str, Any]:
    commission_rate = float(term["commission"]) / 100.0
    contract_size = float(term["contractSize"])
    digits = int(term["digits"])
    profit_currency = str(term["profitCurrency"]).upper()
    commission_deltas: list[float] = []
    swap_deltas: list[float] = []
    swap_checked = 0
    rollover_units = 0
    for index, trade in enumerate(trades, 1):
        derive_rate = profit_currency != "USD"
        try:
            entry_cost, exit_cost = ftmo_trade_commission_sides(
                trade,
                commission_rate_per_side=commission_rate,
                contract_size=contract_size,
                derive_profit_currency_rate_from_pnl=derive_rate,
            )
        except ValueError as exc:
            if commission_rate != 0.0:
                raise FtmoDailyExportError(
                    f"trade {index}: cannot validate FTMO commission: {exc}"
                ) from exc
            entry_cost = exit_cost = 0.0
        expected_commission = -(entry_cost + exit_cost)
        commission_delta = trade.native_commission - expected_commission
        commission_tolerance = max(0.03, abs(expected_commission) * 0.01)
        if abs(commission_delta) > commission_tolerance:
            raise FtmoDailyExportError(
                "native commission does not match pinned FTMO terms at trade "
                f"{index}: delta={commission_delta:.6f} tolerance={commission_tolerance:.6f}"
            )
        commission_deltas.append(commission_delta)

        try:
            _net, _commission, expected_swap, units = ftmo_trade_net(
                trade,
                commission_rate_per_side=commission_rate,
                swap_long_points=float(term["swapLong"]),
                swap_short_points=float(term["swapShort"]),
                contract_size=contract_size,
                digits=digits,
                derive_profit_currency_rate_from_pnl=derive_rate,
            )
        except ValueError:
            # A zero-move EUR-denominated trade cannot supply a conversion rate.
            # It still passed native report/Q08 money reconciliation; another
            # rollover-bearing trade must attest the swap schedule below.
            continue
        rollover_units += units
        if units <= 0:
            if abs(trade.native_swap) > MONEY_TOLERANCE:
                raise FtmoDailyExportError(
                    f"trade {index}: native swap booked with zero rollover units"
                )
            continue
        swap_checked += 1
        swap_delta = trade.native_swap - expected_swap
        swap_tolerance = max(0.10, abs(expected_swap) * 0.05)
        if abs(swap_delta) > swap_tolerance:
            raise FtmoDailyExportError(
                "native swap does not match pinned FTMO terms at trade "
                f"{index}: delta={swap_delta:.6f} tolerance={swap_tolerance:.6f}"
            )
        swap_deltas.append(swap_delta)
    if rollover_units > 0 and swap_checked == 0:
        raise FtmoDailyExportError("rollover trades exist but FTMO swap terms were not checkable")
    return {
        "commission_contract": "PINNED_PERCENT_PER_SIDE_VS_NATIVE_DEALS",
        "commission_checked_trades": len(trades),
        "commission_max_abs_delta": max((abs(value) for value in commission_deltas), default=0.0),
        "swap_contract": "PINNED_POINTS_PER_ROLLOVER_VS_NATIVE_DEALS",
        "swap_checked_trades": swap_checked,
        "swap_rollover_units": rollover_units,
        "swap_max_abs_delta": max((abs(value) for value in swap_deltas), default=0.0),
    }


def load_equity_snapshots(path: Path, *, native_symbol: str) -> dict[dt.date, float]:
    if path.stat().st_size > MAX_INPUT_BYTES:
        raise FtmoDailyExportError(f"equity log exceeds size limit: {path}")
    snapshots: dict[dt.date, float] = {}
    try:
        with path.open(encoding="utf-8", errors="strict") as handle:
            for line_number, line in enumerate(handle, 1):
                if line_number > MAX_JSONL_LINES:
                    raise FtmoDailyExportError("equity log exceeds line limit")
                if len(line.encode("utf-8")) > MAX_JSONL_LINE_BYTES:
                    raise FtmoDailyExportError(f"equity log line {line_number} exceeds size limit")
                if not line.strip():
                    continue
                try:
                    row = strict_json_loads(line, label=f"equity_log:{line_number}")
                except (json.JSONDecodeError, ValueError) as exc:
                    raise FtmoDailyExportError(f"equity_log:{line_number}: {exc}") from exc
                if not isinstance(row, Mapping) or row.get("event") != "EQUITY_SNAPSHOT":
                    continue
                payload: Any = row.get("payload", row)
                if isinstance(payload, str):
                    try:
                        payload = strict_json_loads(payload, label=f"equity_log:{line_number}.payload")
                    except (json.JSONDecodeError, ValueError) as exc:
                        raise FtmoDailyExportError(
                            f"equity_log:{line_number}.payload: {exc}"
                        ) from exc
                if not isinstance(payload, Mapping):
                    raise FtmoDailyExportError(f"equity_log:{line_number}: payload is not an object")
                if payload.get("scope", "account") != "account":
                    raise FtmoDailyExportError(f"equity_log:{line_number}: non-account scope")
                symbol = payload.get("symbol", row.get("symbol"))
                if symbol != native_symbol:
                    raise FtmoDailyExportError(
                        f"equity_log:{line_number}: symbol mismatch {symbol!r}"
                    )
                day_key = payload.get("day_key")
                if isinstance(day_key, bool) or not isinstance(day_key, int):
                    raise FtmoDailyExportError(f"equity_log:{line_number}: invalid day_key")
                try:
                    day = dt.datetime.strptime(str(day_key), "%Y%m%d").date()
                except ValueError as exc:
                    raise FtmoDailyExportError(
                        f"equity_log:{line_number}: invalid day_key"
                    ) from exc
                equity = _finite(payload.get("equity"), f"equity_log:{line_number}.equity")
                if equity <= 0.0:
                    raise FtmoDailyExportError(f"equity_log:{line_number}: non-positive equity")
                if day in snapshots:
                    raise FtmoDailyExportError(f"equity_log:{line_number}: duplicate day_key {day_key}")
                snapshots[day] = equity
    except (OSError, UnicodeError) as exc:
        raise FtmoDailyExportError(f"cannot read equity log: {exc}") from exc
    if len(snapshots) < 2:
        raise FtmoDailyExportError("equity log has fewer than two FTMO account snapshots")
    return snapshots


def _daily_rows(
    *,
    sleeve_id: str,
    symbol: str,
    cost_sha256: str,
    report_identity: Mapping[str, Any],
    report_trades: Sequence[RoundTrip],
    q08_rows: Sequence[Mapping[str, Any]],
    equity_snapshots: Mapping[dt.date, float],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    start = _date_from_dot(str(report_identity["from_date"]), "report.from_date")
    end = _date_from_dot(str(report_identity["to_date"]), "report.to_date")
    days = _continuous_days(start, end)
    if any(day < start or day > end for day in equity_snapshots):
        raise FtmoDailyExportError("equity snapshot falls outside the report window")
    if len(report_trades) != len(q08_rows):
        raise FtmoDailyExportError("report/Q08 lifecycle count mismatch")

    initial = float(report_identity["initial_deposit"])
    final_equity = initial + float(report_identity["total_net_profit"])
    if final_equity <= 0.0:
        raise FtmoDailyExportError("report final equity is non-positive")
    if end in equity_snapshots and abs(float(equity_snapshots[end]) - final_equity) > EQUITY_TOLERANCE:
        raise FtmoDailyExportError("final equity snapshot does not reconcile to MT5 report")

    close_equity: dict[dt.date, float] = {}
    observed_days = set(equity_snapshots)
    previous = initial
    for day in days:
        if day in equity_snapshots:
            previous = float(equity_snapshots[day])
        close_equity[day] = previous
    # QM_EquityStream emits on day rollover, so the final tester day has no
    # natural next-day tick.  The native report is flat-reconciled by
    # extract_round_trips; its final balance therefore supplies that one close.
    close_equity[end] = final_equity

    day_start_balance: dict[dt.date, float] = {}
    closed_net: dict[dt.date, float] = defaultdict(float)
    open_mae: dict[dt.date, float] = defaultdict(float)
    trade_opens: dict[dt.date, int] = defaultdict(int)
    flat_at_end: dict[dt.date, bool] = {day: True for day in days}
    for index, (trade, q08_row) in enumerate(zip(report_trades, q08_rows), 1):
        try:
            net, mae = q08_round_trip_values(q08_row)
        except (KeyError, TypeError, ValueError, OverflowError) as exc:
            raise FtmoDailyExportError(f"Q08 trade {index}: invalid money/MAE: {exc}") from exc
        entry_day = trade.entry_time.date()
        exit_day = trade.exit_time.date()
        if entry_day < start or exit_day > end or exit_day < entry_day:
            raise FtmoDailyExportError(f"Q08 trade {index}: lifecycle outside report window")
        closed_net[exit_day] += float(net)
        trade_opens[entry_day] += 1
        cursor = entry_day
        while cursor <= exit_day:
            open_mae[cursor] += float(mae)
            if cursor < exit_day:
                flat_at_end[cursor] = False
            cursor += dt.timedelta(days=1)

    running_balance = initial
    for day in days:
        day_start_balance[day] = running_balance
        running_balance += closed_net.get(day, 0.0)
    if abs(running_balance - final_equity) > max(EQUITY_TOLERANCE, len(q08_rows) * 0.005):
        raise FtmoDailyExportError(
            "Q08 closing net does not reconcile to report final balance: "
            f"{running_balance:.6f} != {final_equity:.6f}"
        )

    output: list[dict[str, Any]] = []
    prior_close = initial
    for day in days:
        close = close_equity[day]
        if prior_close <= 0.0:
            raise FtmoDailyExportError(f"{day}: non-positive broker-midnight equity")
        net_return = close / prior_close - 1.0
        conservative_low_equity = day_start_balance[day] + open_mae.get(day, 0.0)
        low_return = conservative_low_equity / prior_close - 1.0
        low_return = min(low_return, 0.0, net_return)
        if net_return <= -1.0 or low_return <= -1.0:
            raise FtmoDailyExportError(f"{day}: account-loss return is outside evaluator domain")
        eligible = day in observed_days or (
            day == end and day.weekday() < 5
        )
        output.append(
            {
                "schema": DAILY_STREAM_SCHEMA,
                "sleeve_id": sleeve_id,
                "symbol": symbol,
                "date": day.isoformat(),
                "net_return": round(net_return, 12),
                "intraday_low_return": round(low_return, 12),
                "trade_count": int(trade_opens.get(day, 0)),
                "eligible_start": bool(eligible),
                "flat_at_end": bool(flat_at_end[day]),
                "venue": FTMO_VENUE,
                "spread_basis": FTMO_TERMS,
                "commission_basis": FTMO_TERMS,
                "swap_basis": FTMO_TERMS,
                "cost_snapshot_sha256": cost_sha256,
            }
        )
        prior_close = close
    if sum(row["trade_count"] for row in output) != len(q08_rows):
        raise FtmoDailyExportError("daily trade counts do not reconcile to Q08 lifecycle rows")
    diagnostics = {
        "calendar_days": len(output),
        "eligible_start_days": sum(bool(row["eligible_start"]) for row in output),
        "first_date": output[0]["date"],
        "last_date": output[-1]["date"],
        "initial_equity": initial,
        "final_equity": final_equity,
        "observed_equity_snapshots": len(equity_snapshots),
        "final_close_source": (
            "EQUITY_SNAPSHOT_RECONCILED_TO_REPORT"
            if end in equity_snapshots
            else "MT5_REPORT_FINAL_BALANCE_FLAT_RECONCILED"
        ),
        "intraday_low_basis": "DAY_START_BALANCE_PLUS_SUM_OF_ALL_OVERLAPPING_TRADE_MAE",
        "intraday_low_conservatism": "ALL_OVERLAPPING_TRADE_MAE_ASSUMED_SIMULTANEOUS",
    }
    return output, diagnostics


def _atomic_write(path: Path, content: str, *, replace: bool) -> None:
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not replace:
        raise FtmoDailyExportError(f"refusing to replace existing artifact: {path}")
    descriptor, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def export_ftmo_daily_stream(
    *,
    sleeve_id: str,
    symbol: str,
    native_symbol: str,
    ftmo_code: str,
    summary_path: Path,
    report_path: Path,
    q08_trades_path: Path,
    equity_log_path: Path,
    cost_snapshot_path: Path,
    setfile_path: Path,
    output_path: Path,
    receipt_path: Path,
    replace: bool = False,
    expected_cost_sha256: str = PINNED_COST_SNAPSHOT_SHA256,
) -> dict[str, Any]:
    if not sleeve_id or not symbol or not native_symbol or not ftmo_code:
        raise FtmoDailyExportError("sleeve/symbol/native-symbol/ftmo-code must be non-empty")
    if not SHA_RE.fullmatch(expected_cost_sha256):
        raise FtmoDailyExportError("expected cost digest is not lowercase SHA-256")
    paths = {
        "summary": summary_path.expanduser().resolve(),
        "report": report_path.expanduser().resolve(),
        "q08_trades": q08_trades_path.expanduser().resolve(),
        "equity_log": equity_log_path.expanduser().resolve(),
        "cost_snapshot": cost_snapshot_path.expanduser().resolve(),
        "setfile": setfile_path.expanduser().resolve(),
    }
    output_path = output_path.expanduser().resolve()
    receipt_path = receipt_path.expanduser().resolve()
    if output_path == receipt_path:
        raise FtmoDailyExportError("stream and receipt paths must differ")
    if output_path in paths.values() or receipt_path in paths.values():
        raise FtmoDailyExportError("output paths must not alias an input artifact")
    input_bindings = {name: binding(path) for name, path in paths.items()}
    set_guardrails = validate_setfile_guardrails(paths["setfile"])
    report_identity = parse_ftmo_report_identity(paths["report"], native_symbol=native_symbol)
    if not math.isclose(
        float(set_guardrails["risk_fixed"]),
        float(report_identity["risk_fixed"]),
        rel_tol=0.0,
        abs_tol=1e-12,
    ) or float(set_guardrails["risk_percent"]) != float(report_identity["risk_percent"]):
        raise FtmoDailyExportError("setfile/report risk inputs differ")

    term, cost_sha = _cost_term(
        paths["cost_snapshot"], ftmo_code=ftmo_code, expected_sha256=expected_cost_sha256
    )
    q08_rows = load_q08_trade_rows(paths["q08_trades"])
    if not q08_rows:
        raise FtmoDailyExportError("Q08 trade stream is empty")
    try:
        money_basis = q08_stream_money_basis(q08_rows)
    except ValueError as exc:
        raise FtmoDailyExportError(f"Q08 money basis is invalid: {exc}") from exc
    if money_basis != FULL_POSITION_LIFECYCLE_ACTUAL_V1:
        raise FtmoDailyExportError(
            "Q08 stream is not FULL_POSITION_LIFECYCLE_ACTUAL_V1"
        )
    report_trades, _report_stats = extract_round_trips(paths["report"], native_symbol)
    if len(report_trades) != int(report_identity["total_trades"]):
        raise FtmoDailyExportError("parsed report lifecycle count mismatch")
    summary, selected_run = _validated_summary(
        paths["summary"],
        report_path=paths["report"],
        native_symbol=native_symbol,
        setfile_path=paths["setfile"],
        expected_trades=len(report_trades),
    )
    try:
        ea_id = int(summary["ea_id"])
    except (KeyError, TypeError, ValueError) as exc:
        raise FtmoDailyExportError("summary.ea_id is invalid") from exc
    stream_reconciliation = reconcile_case(
        ea_id,
        native_symbol,
        paths["summary"],
        stream_path=paths["q08_trades"],
        report_path=paths["report"],
    )
    if (
        stream_reconciliation.get("status") != "PASS"
        or stream_reconciliation.get("contract")
        != "full_position_lifecycle_actual_v1"
        or stream_reconciliation.get("lifecycle", {}).get("status") != "PASS"
    ):
        raise FtmoDailyExportError(
            "native report/Q08 full-lifecycle reconciliation failed: "
            + ";".join(stream_reconciliation.get("reasons", []))
        )
    cost_reconciliation = _cost_reconciliation(report_trades, term)
    equity_snapshots = load_equity_snapshots(paths["equity_log"], native_symbol=native_symbol)
    rows, construction = _daily_rows(
        sleeve_id=sleeve_id,
        symbol=symbol,
        cost_sha256=cost_sha,
        report_identity=report_identity,
        report_trades=report_trades,
        q08_rows=q08_rows,
        equity_snapshots=equity_snapshots,
    )

    output_text = "".join(
        json.dumps(row, ensure_ascii=False, allow_nan=False, sort_keys=True) + "\n"
        for row in rows
    )
    _atomic_write(output_path, output_text, replace=replace)
    output_binding = binding(output_path)
    receipt: dict[str, Any] = {
        "schema": EXPORT_RECEIPT_SCHEMA,
        "status": "PASS",
        "claim": "HISTORICAL_DIAGNOSTIC_NOT_SELECTION_SEALED",
        "sleeve_id": sleeve_id,
        "symbol": symbol,
        "native_symbol": native_symbol,
        "ftmo_code": ftmo_code,
        "attestation": {
            "venue": FTMO_VENUE,
            "spread_basis": FTMO_TERMS,
            "commission_basis": FTMO_TERMS,
            "swap_basis": FTMO_TERMS,
            "spread_evidence": "NATIVE_FTMO_DEMO_MODEL4_REAL_TICKS_REPORT_PROFIT",
            "commission_evidence": "NATIVE_DEALS_RECONCILED_TO_PINNED_FTMO_PERCENT_TERMS",
            "swap_evidence": "NATIVE_DEALS_RECONCILED_TO_PINNED_FTMO_POINT_TERMS",
            "cost_snapshot_sha256": cost_sha,
            "report_server": report_identity["server"],
            "report_company": report_identity["company"],
            "history_quality": report_identity["history_quality"],
        },
        "cost_term": term,
        "cost_reconciliation": cost_reconciliation,
        "report_identity": report_identity,
        "setfile_guardrails": set_guardrails,
        "selected_run": dict(selected_run),
        "stream_reconciliation": stream_reconciliation,
        "construction": construction,
        "inputs": input_bindings,
        "output": output_binding,
    }
    receipt_text = json.dumps(
        receipt, ensure_ascii=False, allow_nan=False, indent=2, sort_keys=True
    ) + "\n"
    try:
        _atomic_write(receipt_path, receipt_text, replace=replace)
    except Exception:
        # Do not leave an unattested stream behind if receipt publication fails.
        try:
            output_path.unlink()
        except OSError:
            pass
        raise
    return receipt


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sleeve-id", required=True)
    parser.add_argument("--symbol", required=True, help="evaluator symbol, e.g. XAUUSD")
    parser.add_argument("--native-symbol", required=True, help="native FTMO symbol, e.g. XAUUSD")
    parser.add_argument("--ftmo-code", required=True, help="pinned snapshot code, e.g. XAU/USD")
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--q08-trades", required=True, type=Path)
    parser.add_argument("--equity-log", required=True, type=Path)
    parser.add_argument("--cost-snapshot", required=True, type=Path)
    parser.add_argument("--setfile", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--receipt-out", type=Path)
    parser.add_argument("--replace", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    receipt_path = args.receipt_out or args.out.with_suffix(args.out.suffix + ".receipt.json")
    try:
        receipt = export_ftmo_daily_stream(
            sleeve_id=args.sleeve_id,
            symbol=args.symbol,
            native_symbol=args.native_symbol,
            ftmo_code=args.ftmo_code,
            summary_path=args.summary,
            report_path=args.report,
            q08_trades_path=args.q08_trades,
            equity_log_path=args.equity_log,
            cost_snapshot_path=args.cost_snapshot,
            setfile_path=args.setfile,
            output_path=args.out,
            receipt_path=receipt_path,
            replace=args.replace,
        )
    except (FtmoDailyExportError, OSError, UnicodeError, ValueError) as exc:
        print(f"REFUSED: {exc}")
        return 2
    print(
        "PASS "
        f"rows={receipt['construction']['calendar_days']} "
        f"stream={receipt['output']['path']} receipt={receipt_path.resolve()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
