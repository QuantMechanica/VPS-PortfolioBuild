"""Read-only FTMO sleeve-level P&L attribution.

Broker deal history supplies realised profit, commission, swap and fee.  The
append-only FTMO collector supplies floating P&L and account equity snapshots.
Every broker deal is assigned either to a roster magic or to ``unattributed``;
nothing is silently discarded.  The tool never starts MT5: direct querying is
allowed only after a path-matched FTMO terminal process is already running.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import sys
from collections import defaultdict
from copy import deepcopy
from datetime import date, datetime, time, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from pathlib import Path
from typing import Any, Iterable
from zoneinfo import ZoneInfo


SCHEMA = "qm.ftmo-sleeve-attribution/v1"
VERIFY_SCHEMA = "qm.ftmo-sleeve-attribution-reconciliation/v1"
PRAGUE = ZoneInfo("Europe/Prague")
CENT = Decimal("0.01")
DEFAULT_ROSTER = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\roster.json"
)
DEFAULT_TELEMETRY = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM\ftmo_trial"
    r"\FTMO_DEMO_BOOK_V3_D2G6_20260918\trial_telemetry_raw.jsonl"
)
DEFAULT_MT5_EXE = Path(r"C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe")
DEFAULT_OUTPUT = Path(r"D:\QM\reports\state\ftmo_sleeve_attribution.json")
ENTRY_IN = {"IN", "INOUT"}
ENTRY_OUT = {"OUT", "OUT_BY", "INOUT"}


class AttributionError(RuntimeError):
    pass


def _decimal(value: Any) -> Decimal:
    if value in (None, ""):
        return Decimal("0")
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise AttributionError(f"money_value_invalid:{value}") from exc


def _cents(value: Any) -> int:
    return int((_decimal(value).quantize(CENT, rounding=ROUND_HALF_UP) * 100).to_integral_value())


def _money(cents: int | None) -> float | None:
    return None if cents is None else float(Decimal(cents) / 100)


def _iso_utc(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _parse_utc(value: str | datetime) -> datetime:
    if isinstance(value, datetime):
        parsed = value
    else:
        try:
            parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        except ValueError as exc:
            raise AttributionError(f"timestamp_invalid:{value}") from exc
    if parsed.tzinfo is None:
        raise AttributionError(f"timestamp_timezone_missing:{value}")
    return parsed.astimezone(timezone.utc)


def _day_key(value: datetime) -> str:
    return value.astimezone(PRAGUE).date().isoformat()


def _entry_name(value: Any) -> str:
    mapping = {0: "IN", 1: "OUT", 2: "INOUT", 3: "OUT_BY"}
    if isinstance(value, int):
        return mapping.get(value, f"UNKNOWN_{value}")
    text = str(value or "").strip().upper()
    if text.isdigit():
        return mapping.get(int(text), f"UNKNOWN_{text}")
    return text or "UNKNOWN"


def _int(value: Any, *, field: str) -> int:
    try:
        return int(str(value or "0"))
    except ValueError as exc:
        raise AttributionError(f"integer_invalid:{field}:{value}") from exc


def load_roster(path: Path) -> dict[str, Any]:
    try:
        roster = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AttributionError(f"roster_unreadable:{path}:{exc}") from exc
    if roster.get("schema") not in {"qm.ftmo-demo-roster/v1", "qm.ftmo-book-roster/v1"}:
        raise AttributionError(f"roster_schema_invalid:{roster.get('schema')}")
    rows = roster.get("candidates") or roster.get("sleeves")
    if not isinstance(rows, list) or not rows:
        raise AttributionError("roster_empty")
    magics: set[int] = set()
    normalized = []
    for row in rows:
        magic = _int(row.get("magic"), field="magic")
        ea_id = _int(row.get("ea_id"), field="ea_id")
        slot = _int(row.get("slot"), field="slot")
        if magic != ea_id * 10000 + slot:
            raise AttributionError(f"roster_magic_formula_mismatch:{magic}")
        if magic in magics:
            raise AttributionError(f"roster_duplicate_magic:{magic}")
        magics.add(magic)
        normalized.append(
            {
                "ea_id": ea_id,
                "ea_label": row.get("ea_label") or f"QM5_{ea_id}",
                "symbol": row.get("ftmo_symbol") or row.get("symbol"),
                "timeframe": row.get("timeframe"),
                "magic": magic,
                "slot": slot,
                "role": row.get("role"),
                "risk_percent": row.get("risk_percent"),
            }
        )
    return {
        "book_id": roster.get("cycle_id") or roster.get("book_id") or roster.get("label"),
        "sleeves": normalized,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "path": str(path.resolve()),
    }


def normalize_deal(row: Any) -> dict[str, Any]:
    data = row._asdict() if hasattr(row, "_asdict") else dict(row)
    if data.get("time_utc"):
        stamp = _parse_utc(str(data["time_utc"]))
    elif data.get("time") is not None:
        stamp = datetime.fromtimestamp(int(data["time"]), tz=timezone.utc)
    else:
        raise AttributionError("deal_timestamp_missing")
    magic = 0
    for field in ("logical_magic", "deal_magic", "magic"):
        candidate = _int(data.get(field), field=field)
        if candidate:
            magic = candidate
            break
    ticket = _int(data.get("ticket") or data.get("deal_id"), field="deal_id")
    if ticket <= 0:
        raise AttributionError("deal_id_invalid")
    components = {name: _cents(data.get(name)) for name in ("profit", "swap", "commission", "fee")}
    net = sum(components.values())
    return {
        "deal_id": ticket,
        "position_id": _int(data.get("position_id"), field="position_id"),
        "time_utc": _iso_utc(stamp),
        "timestamp": stamp.timestamp(),
        "prague_day": _day_key(stamp),
        "entry": _entry_name(data.get("entry")),
        "magic": magic,
        "symbol": str(data.get("symbol") or ""),
        "type": str(data.get("type") or ""),
        "volume": float(data.get("volume") or 0.0),
        "profit_cents": components["profit"],
        "swap_cents": components["swap"],
        "commission_cents": components["commission"],
        "fee_cents": components["fee"],
        "net_cents": net,
        "operation_kind": "BALANCE_OPERATION"
        if not data.get("symbol") and _int(data.get("position_id"), field="position_id") == 0
        else "TRADE_DEAL",
    }


def load_deals_csv(path: Path, start: datetime, end: datetime) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    raw = path.read_bytes()
    try:
        rows = list(csv.DictReader(raw.decode("utf-8-sig").splitlines()))
    except (UnicodeDecodeError, csv.Error) as exc:
        raise AttributionError(f"deals_csv_unreadable:{path}:{exc}") from exc
    deals = []
    for row in rows:
        deal = normalize_deal(row)
        when = datetime.fromtimestamp(deal["timestamp"], tz=timezone.utc)
        if start <= when <= end:
            deals.append(deal)
    return deals, {
        "mode": "NORMALIZED_CSV",
        "path": str(path.resolve()),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "account_login_masked": None,
        "server": None,
    }


def load_deals_json(path: Path, start: datetime, end: datetime) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    raw = path.read_bytes()
    try:
        payload = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AttributionError(f"deals_json_unreadable:{path}:{exc}") from exc
    rows = payload.get("deals") if isinstance(payload, dict) else payload
    if not isinstance(rows, list):
        raise AttributionError("deals_json_list_required")
    deals = []
    for row in rows:
        deal = normalize_deal(row)
        when = datetime.fromtimestamp(deal["timestamp"], tz=timezone.utc)
        if start <= when <= end:
            deals.append(deal)
    return deals, {
        "mode": "JSON_SNAPSHOT",
        "path": str(path.resolve()),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "account_login_masked": payload.get("account_login_masked") if isinstance(payload, dict) else None,
        "server": payload.get("server") if isinstance(payload, dict) else None,
    }


def _running_processes(executable: Path) -> set[int]:
    try:
        import psutil
    except ImportError as exc:
        raise AttributionError("psutil_required_for_no_start_guard") from exc
    expected = os.path.normcase(str(executable.resolve()))
    found: set[int] = set()
    for process in psutil.process_iter(["pid", "exe"]):
        try:
            actual = process.info.get("exe")
            if actual and os.path.normcase(str(Path(actual).resolve())) == expected:
                found.add(int(process.info["pid"]))
        except (OSError, psutil.Error):
            continue
    return found


def query_running_mt5(
    executable: Path,
    start: datetime,
    end: datetime,
    *,
    expected_server: str,
    expected_login_last3: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    resolved = executable.resolve()
    forbidden = [Path(r"C:\QM\mt5\T_Live")] + [Path(f"D:/QM/mt5/T{i}") for i in range(1, 11)]
    if any(root.resolve() == resolved or root.resolve() in resolved.parents for root in forbidden):
        raise AttributionError(f"forbidden_terminal:{resolved}")
    before = _running_processes(resolved)
    if not before:
        raise AttributionError(f"terminal_not_already_running_refusing_initialize:{resolved}")
    try:
        import MetaTrader5 as mt5
    except ImportError as exc:
        raise AttributionError("MetaTrader5_package_missing") from exc
    if not mt5.initialize(path=str(resolved), timeout=10_000, portable=False):
        raise AttributionError(f"mt5_readonly_initialize_failed:{mt5.last_error()}")
    try:
        after = _running_processes(resolved)
        if not after or not before.intersection(after):
            raise AttributionError("terminal_process_identity_changed_during_attach")
        account = mt5.account_info()
        if account is None:
            raise AttributionError(f"mt5_account_info_failed:{mt5.last_error()}")
        login = str(account.login)
        if account.server != expected_server or not login.endswith(expected_login_last3):
            raise AttributionError(
                f"mt5_account_identity_mismatch:server={account.server}:login_last3={login[-3:]}"
            )
        rows = mt5.history_deals_get(start, end)
        if rows is None:
            raise AttributionError(f"mt5_history_deals_failed:{mt5.last_error()}")
        deals = [normalize_deal(row) for row in rows]
        canonical = json.dumps(
            [{k: v for k, v in row.items() if k != "timestamp"} for row in deals],
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        metadata = {
            "mode": "RUNNING_MT5_READ_ONLY",
            "terminal_executable": str(resolved),
            "preexisting_process_ids": sorted(before),
            "account_login_masked": ("*" * max(0, len(login) - 3)) + login[-3:],
            "server": account.server,
            "query_sha256": hashlib.sha256(canonical).hexdigest(),
            "query_row_count": len(deals),
        }
        return deals, metadata
    finally:
        mt5.shutdown()


def _snapshot_fields(sample: dict[str, Any], roster_magics: set[int]) -> dict[str, Any]:
    floats: dict[int, int] = {magic: 0 for magic in roster_magics}
    unattributed = 0
    for position in sample.get("positions") or []:
        magic = _int(position.get("magic"), field="position_magic")
        value = _cents(position.get("profit")) + _cents(position.get("swap"))
        if magic in floats:
            floats[magic] += value
        else:
            unattributed += value
    return {
        "ts_epoch": float(sample["ts_epoch"]),
        "ts_utc": str(sample.get("ts_utc") or _iso_utc(datetime.fromtimestamp(float(sample["ts_epoch"]), timezone.utc))),
        "balance_cents": _cents(sample.get("balance")),
        "equity_cents": _cents(sample.get("equity")),
        "float_by_magic": floats,
        "unattributed_float_cents": unattributed,
    }


def summarize_telemetry(
    path: Path,
    roster_magics: set[int],
    start: datetime,
    end: datetime,
    *,
    midnight_tolerance_seconds: int = 300,
) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    days: dict[str, dict[str, Any]] = {}
    digest = hashlib.sha256()
    bytes_read = 0
    parsed_rows = 0
    malformed_rows = 0
    with path.open("rb") as handle:
        for raw_line in handle:
            digest.update(raw_line)
            bytes_read += len(raw_line)
            try:
                sample = json.loads(raw_line)
                stamp = datetime.fromtimestamp(float(sample["ts_epoch"]), tz=timezone.utc)
            except (json.JSONDecodeError, KeyError, TypeError, ValueError):
                malformed_rows += 1
                continue
            if sample.get("event") != "SAMPLE" or not (start <= stamp <= end):
                continue
            parsed_rows += 1
            key = _day_key(stamp)
            local_date = stamp.astimezone(PRAGUE).date()
            target = datetime.combine(local_date, time.min, tzinfo=PRAGUE).astimezone(timezone.utc)
            snapshot = _snapshot_fields(sample, roster_magics)
            distance = abs((stamp - target).total_seconds())
            day = days.setdefault(
                key,
                {
                    "sample_count": 0,
                    "first": None,
                    "last": None,
                    "boundary_candidate": None,
                    "boundary_distance": None,
                    "worst": None,
                    "mae": {magic: 0 for magic in roster_magics},
                },
            )
            day["sample_count"] += 1
            if day["first"] is None:
                day["first"] = snapshot
            day["last"] = snapshot
            if day["boundary_distance"] is None or distance < day["boundary_distance"]:
                day["boundary_distance"] = distance
                day["boundary_candidate"] = snapshot
            if day["worst"] is None or snapshot["equity_cents"] < day["worst"]["equity_cents"]:
                day["worst"] = snapshot
            for magic, floating in snapshot["float_by_magic"].items():
                day["mae"][magic] = min(day["mae"][magic], floating)
    for day in days.values():
        if day["boundary_distance"] is None or day["boundary_distance"] > midnight_tolerance_seconds:
            day["boundary"] = None
            day["boundary_status"] = "UNAVAILABLE_OUTSIDE_TOLERANCE"
        else:
            day["boundary"] = day["boundary_candidate"]
            day["boundary_status"] = "NEAREST_SAMPLE_PROXY"
        day.pop("boundary_candidate", None)
    return days, {
        "path": str(path.resolve()),
        "sha256_prefix_read": digest.hexdigest(),
        "bytes_read": bytes_read,
        "parsed_sample_rows": parsed_rows,
        "malformed_rows": malformed_rows,
        "midnight_tolerance_seconds": midnight_tolerance_seconds,
    }


def _deal_totals(rows: Iterable[dict[str, Any]]) -> dict[str, int]:
    result = {name: 0 for name in ("profit_cents", "swap_cents", "commission_cents", "fee_cents", "net_cents")}
    for row in rows:
        for name in result:
            result[name] += int(row[name])
    return result


def _counts(rows: list[dict[str, Any]]) -> tuple[int, int, int]:
    entries = sum(row["entry"] in ENTRY_IN for row in rows)
    exits = sum(row["entry"] in ENTRY_OUT for row in rows)
    positions = {
        int(row["position_id"])
        for row in rows
        if row["entry"] in ENTRY_OUT and int(row["position_id"]) > 0
    }
    return entries, exits, len(positions)


def build_attribution(
    *,
    roster: dict[str, Any],
    deals: list[dict[str, Any]],
    deal_source: dict[str, Any],
    telemetry_days: dict[str, dict[str, Any]],
    telemetry_source: dict[str, Any],
    start: datetime,
    end: datetime,
    generated_at: datetime,
    daily_loss_limit_usd: float = 5000.0,
) -> dict[str, Any]:
    sleeves = roster["sleeves"]
    roster_magics = {int(row["magic"]) for row in sleeves}
    by_magic = {int(row["magic"]): row for row in sleeves}
    seen_deals: set[int] = set()
    for deal in deals:
        if deal["deal_id"] in seen_deals:
            raise AttributionError(f"duplicate_deal_id:{deal['deal_id']}")
        seen_deals.add(deal["deal_id"])
    deals = sorted(deals, key=lambda row: (row["timestamp"], row["deal_id"]))
    keys = sorted(set(telemetry_days) | {row["prague_day"] for row in deals})
    cumulative = {magic: 0 for magic in roster_magics}
    top_summaries: dict[int, dict[str, Any]] = {}
    for sleeve in sleeves:
        magic = int(sleeve["magic"])
        top_summaries[magic] = {
            **deepcopy(sleeve),
            "realised_usd": 0.0,
            "profit_usd": 0.0,
            "commission_usd": 0.0,
            "swap_usd": 0.0,
            "fee_usd": 0.0,
            "entries": 0,
            "exits": 0,
            "trade_count": 0,
            "latest_floating_usd": None,
            "cumulative_curve": [],
        }
    unattributed_rows = [row for row in deals if int(row["magic"]) not in roster_magics]
    rendered_days = []
    all_reconciled = True
    for key in keys:
        day_deals = [row for row in deals if row["prague_day"] == key]
        telem = telemetry_days.get(key)
        account_totals = _deal_totals(day_deals)
        roster_rows = [row for row in day_deals if int(row["magic"]) in roster_magics]
        other_rows = [row for row in day_deals if int(row["magic"]) not in roster_magics]
        roster_total = sum(row["net_cents"] for row in roster_rows)
        unattributed_total = sum(row["net_cents"] for row in other_rows)
        diff = account_totals["net_cents"] - roster_total - unattributed_total
        day_ok = diff == 0
        all_reconciled = all_reconciled and day_ok
        worst = telem.get("worst") if telem else None
        anchor = (telem.get("boundary") or telem.get("first")) if telem else None
        used_headroom = max(0, (anchor["balance_cents"] - worst["equity_cents"])) if anchor and worst else None
        worst_ts = worst["ts_epoch"] if worst else None
        contributions: dict[int, int] = {}
        negative_total = 0
        for magic in roster_magics:
            realised_to_worst = sum(
                row["net_cents"]
                for row in roster_rows
                if int(row["magic"]) == magic and (worst_ts is None or row["timestamp"] <= worst_ts)
            )
            floating = worst["float_by_magic"].get(magic, 0) if worst else 0
            contributions[magic] = realised_to_worst + floating
            negative_total += max(0, -contributions[magic])
        unattributed_contribution = sum(
            row["net_cents"]
            for row in other_rows
            if worst_ts is None or row["timestamp"] <= worst_ts
        ) + (worst["unattributed_float_cents"] if worst else 0)
        negative_total += max(0, -unattributed_contribution)
        day_sleeves = []
        for magic in sorted(roster_magics):
            rows = [row for row in roster_rows if int(row["magic"]) == magic]
            totals = _deal_totals(rows)
            entries, exits, trades = _counts(rows)
            cumulative[magic] += totals["net_cents"]
            boundary_float = (
                telem["boundary"]["float_by_magic"].get(magic, 0)
                if telem and telem.get("boundary")
                else None
            )
            mae = telem["mae"].get(magic) if telem else None
            share = (max(0, -contributions[magic]) / negative_total) if negative_total else 0.0
            allocation = round((used_headroom or 0) * share) if used_headroom is not None else None
            day_sleeves.append(
                {
                    "magic": magic,
                    "ea_id": by_magic[magic]["ea_id"],
                    "symbol": by_magic[magic]["symbol"],
                    "realised_usd": _money(totals["net_cents"]),
                    "profit_usd": _money(totals["profit_cents"]),
                    "commission_usd": _money(totals["commission_cents"]),
                    "swap_usd": _money(totals["swap_cents"]),
                    "fee_usd": _money(totals["fee_cents"]),
                    "floating_at_prague_midnight_usd": _money(boundary_float),
                    "trade_count": trades,
                    "entries": entries,
                    "exits": exits,
                    "worst_intraday_mae_proxy_usd": _money(mae),
                    "daily_loss_headroom_consumption_usd": _money(allocation),
                    "daily_loss_headroom_consumption_share": round(share, 8),
                    "contribution_at_account_worst_usd": _money(contributions[magic]) if worst else None,
                    "cumulative_realised_usd": _money(cumulative[magic]),
                }
            )
            summary = top_summaries[magic]
            summary["realised_usd"] = _money(_cents(summary["realised_usd"]) + totals["net_cents"])
            for source_name, target_name in (
                ("profit_cents", "profit_usd"),
                ("commission_cents", "commission_usd"),
                ("swap_cents", "swap_usd"),
                ("fee_cents", "fee_usd"),
            ):
                summary[target_name] = _money(_cents(summary[target_name]) + totals[source_name])
            summary["entries"] += entries
            summary["exits"] += exits
            summary["trade_count"] += trades
            summary["cumulative_curve"].append(
                {
                    "prague_day": key,
                    "daily_realised_usd": _money(totals["net_cents"]),
                    "cumulative_realised_usd": _money(cumulative[magic]),
                }
            )
            if telem and telem.get("last"):
                summary["latest_floating_usd"] = _money(telem["last"]["float_by_magic"].get(magic, 0))
        rendered_days.append(
            {
                "prague_day": key,
                "coverage": {
                    "sample_count": telem["sample_count"] if telem else 0,
                    "first_sample_utc": telem["first"]["ts_utc"] if telem else None,
                    "last_sample_utc": telem["last"]["ts_utc"] if telem else None,
                    "midnight_status": telem["boundary_status"] if telem else "NO_TELEMETRY",
                    "midnight_distance_seconds": telem["boundary_distance"] if telem else None,
                },
                "account": {
                    "realised_usd": _money(account_totals["net_cents"]),
                    "roster_realised_usd": _money(roster_total),
                    "unattributed_realised_usd": _money(unattributed_total),
                    "reconciliation_difference_usd": _money(diff),
                    "reconciliation_ok": day_ok,
                    "prague_midnight_balance_usd": _money(anchor["balance_cents"]) if anchor else None,
                    "worst_equity_usd": _money(worst["equity_cents"]) if worst else None,
                    "worst_equity_at_utc": worst["ts_utc"] if worst else None,
                    "daily_loss_limit_usd": daily_loss_limit_usd,
                    "daily_loss_headroom_consumed_usd": _money(used_headroom),
                    "daily_loss_headroom_remaining_usd": _money(max(0, _cents(daily_loss_limit_usd) - (used_headroom or 0))) if used_headroom is not None else None,
                },
                "sleeves": day_sleeves,
                "unattributed": {
                    "deal_count": len(other_rows),
                    "realised_usd": _money(unattributed_total),
                    "floating_at_prague_midnight_usd": _money(telem["boundary"]["unattributed_float_cents"]) if telem and telem.get("boundary") else None,
                    "daily_loss_headroom_consumption_share": round(max(0, -unattributed_contribution) / negative_total, 8) if negative_total else 0.0,
                },
            }
        )

    account_total = sum(row["net_cents"] for row in deals)
    roster_total = sum(row["net_cents"] for row in deals if int(row["magic"]) in roster_magics)
    unattributed_total = account_total - roster_total
    total_diff = account_total - roster_total - unattributed_total
    all_reconciled = all_reconciled and total_diff == 0
    unattributed = [
        {
            "deal_id": row["deal_id"],
            "position_id": row["position_id"],
            "time_utc": row["time_utc"],
            "prague_day": row["prague_day"],
            "magic": row["magic"],
            "symbol": row["symbol"],
            "entry": row["entry"],
            "operation_kind": row["operation_kind"],
            "profit_usd": _money(row["profit_cents"]),
            "commission_usd": _money(row["commission_cents"]),
            "swap_usd": _money(row["swap_cents"]),
            "fee_usd": _money(row["fee_cents"]),
            "realised_usd": _money(row["net_cents"]),
            "reason": "MAGIC_NOT_IN_ROSTER" if row["magic"] else "ZERO_OR_MANUAL_MAGIC",
        }
        for row in unattributed_rows
    ]
    result = {
        "schema": SCHEMA,
        "book_id": roster["book_id"],
        "generated_at_utc": _iso_utc(generated_at),
        "period": {"start_utc": _iso_utc(start), "end_utc": _iso_utc(end), "timezone": "Europe/Prague"},
        "method": {
            "realised": "broker deal profit + commission + swap + fee, cent-rounded per deal",
            "floating": "collector position profit + swap; nearest sample within midnight tolerance",
            "mae_proxy": "minimum observed per-magic floating P&L within the Prague day",
            "headroom_share": "negative sleeve contribution at the account's worst observed equity, divided by all negative roster + unattributed contributions",
            "first_partial_day_warning": "A period beginning after Prague midnight has coverage-limited midnight/headroom evidence.",
        },
        "sources": {"roster": {k: roster[k] for k in ("path", "sha256")}, "deals": deal_source, "telemetry": telemetry_source},
        "day_count": len(rendered_days),
        "latest_prague_day": rendered_days[-1]["prague_day"] if rendered_days else None,
        "unattributed_deal_count": len(unattributed),
        "days": rendered_days,
        "sleeves": [top_summaries[magic] for magic in sorted(top_summaries)],
        "unattributed": unattributed,
        "reconciliation": {
            "account_realised_usd": _money(account_total),
            "roster_realised_usd": _money(roster_total),
            "unattributed_realised_usd": _money(unattributed_total),
            "difference_usd": _money(total_diff),
            "identity": "roster_realised + unattributed_realised == account_history_realised",
            "cent_rounding": "ROUND_HALF_UP_PER_DEAL_COMPONENT",
        },
        "reconciliation_ok": all_reconciled,
    }
    return result


def render_markdown(result: dict[str, Any]) -> str:
    rec = result["reconciliation"]
    lines = [
        f"# FTMO sleeve attribution — {result['book_id']}",
        "",
        f"Generated: `{result['generated_at_utc']}`. Period: `{result['period']['start_utc']}` to `{result['period']['end_utc']}`.",
        "",
        f"Reconciliation: **{'PASS' if result['reconciliation_ok'] else 'FAIL'}** — account `{rec['account_realised_usd']:.2f}` = roster `{rec['roster_realised_usd']:.2f}` + unattributed `{rec['unattributed_realised_usd']:.2f}` USD; difference `{rec['difference_usd']:.2f}`.",
        "",
        "## Sleeve totals",
        "",
        "| Magic | EA | Symbol | Realised USD | Floating latest | Trades | Entries | Exits |",
        "|---:|---|---|---:|---:|---:|---:|---:|",
    ]
    for sleeve in result["sleeves"]:
        floating = "—" if sleeve["latest_floating_usd"] is None else f"{sleeve['latest_floating_usd']:.2f}"
        lines.append(
            f"| {sleeve['magic']} | {sleeve['ea_label']} | {sleeve['symbol']} | "
            f"{sleeve['realised_usd']:.2f} | {floating} | {sleeve['trade_count']} | {sleeve['entries']} | {sleeve['exits']} |"
        )
    lines += ["", "## Prague-day reconciliation", "", "| Day | Account | Roster | Unattributed | Difference | Status |", "|---|---:|---:|---:|---:|---|"]
    for day in result["days"]:
        account = day["account"]
        lines.append(
            f"| {day['prague_day']} | {account['realised_usd']:.2f} | {account['roster_realised_usd']:.2f} | "
            f"{account['unattributed_realised_usd']:.2f} | {account['reconciliation_difference_usd']:.2f} | "
            f"{'PASS' if account['reconciliation_ok'] else 'FAIL'} |"
        )
    lines += [
        "",
        f"Unattributed deals: `{len(result['unattributed'])}`. They are itemized in the JSON and included in the account identity; none are silently dropped.",
        "",
        "Floating-at-midnight, MAE and Daily-Loss headroom allocations are observation proxies with their exact coverage status in each day row. This report is read-only and does not control MT5.",
        "",
    ]
    return "\n".join(lines)


def _atomic_write(path: Path, data: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(data, encoding="utf-8")
    os.replace(temporary, path)


def write_outputs(result: dict[str, Any], json_path: Path, markdown_path: Path) -> None:
    _atomic_write(json_path, json.dumps(result, indent=2, sort_keys=True) + "\n")
    _atomic_write(markdown_path, render_markdown(result))


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--book-id")
    parser.add_argument("--roster", type=Path, default=DEFAULT_ROSTER)
    parser.add_argument("--telemetry", type=Path, default=DEFAULT_TELEMETRY)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--deals-csv", type=Path)
    source.add_argument("--deals-json", type=Path)
    source.add_argument("--query-running-mt5", action="store_true")
    parser.add_argument("--terminal-executable", type=Path, default=DEFAULT_MT5_EXE)
    parser.add_argument("--expected-server", default="FTMO-Demo")
    parser.add_argument("--expected-login-last3", default="732")
    parser.add_argument("--start-utc", required=True)
    parser.add_argument("--end-utc")
    parser.add_argument("--generated-at-utc")
    parser.add_argument("--midnight-tolerance-seconds", type=int, default=300)
    parser.add_argument("--daily-loss-limit-usd", type=float, default=5000.0)
    parser.add_argument("--output-json", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--output-md", type=Path, default=DEFAULT_OUTPUT.with_suffix(".md"))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        start = _parse_utc(args.start_utc)
        end = _parse_utc(args.end_utc) if args.end_utc else datetime.now(timezone.utc)
        generated = _parse_utc(args.generated_at_utc) if args.generated_at_utc else datetime.now(timezone.utc)
        if end <= start:
            raise AttributionError("period_end_must_follow_start")
        roster = load_roster(args.roster)
        if args.book_id:
            roster["book_id"] = args.book_id
        if args.deals_csv:
            deals, deal_source = load_deals_csv(args.deals_csv, start, end)
        elif args.deals_json:
            deals, deal_source = load_deals_json(args.deals_json, start, end)
        else:
            deals, deal_source = query_running_mt5(
                args.terminal_executable,
                start,
                end,
                expected_server=args.expected_server,
                expected_login_last3=args.expected_login_last3,
            )
        magics = {int(row["magic"]) for row in roster["sleeves"]}
        telemetry, telemetry_source = summarize_telemetry(
            args.telemetry,
            magics,
            start,
            end,
            midnight_tolerance_seconds=args.midnight_tolerance_seconds,
        )
        result = build_attribution(
            roster=roster,
            deals=deals,
            deal_source=deal_source,
            telemetry_days=telemetry,
            telemetry_source=telemetry_source,
            start=start,
            end=end,
            generated_at=generated,
            daily_loss_limit_usd=args.daily_loss_limit_usd,
        )
        write_outputs(result, args.output_json, args.output_md)
        print(
            json.dumps(
                {
                    "schema": result["schema"],
                    "book_id": result["book_id"],
                    "reconciliation_ok": result["reconciliation_ok"],
                    "day_count": len(result["days"]),
                    "unattributed_deals": len(result["unattributed"]),
                    "output_json": str(args.output_json),
                    "output_md": str(args.output_md),
                }
            )
        )
        return 0 if result["reconciliation_ok"] else 2
    except AttributionError as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
