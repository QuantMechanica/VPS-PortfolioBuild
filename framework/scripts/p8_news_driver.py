#!/usr/bin/env python3
"""P8 real news replay gate.

P8 is a post-report analysis gate. It does not synthesize news-mode metrics.
It parses real MT5 tester deal rows, maps entry/exit trade pairs to the actual
UTC news calendar, and recomputes metrics for each supported runtime news mode.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import re
import sqlite3
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    parse_float,
    write_phase_artifacts,
    write_json,
    update_result_with_evidence_path,
)


REQUIRED_CALENDAR_COLUMNS = [
    "timestamp_utc",
    "currency",
    "impact",
    "event",
    "actual",
    "forecast",
    "previous",
]
CALENDAR_ALIASES = {
    "timestamp_utc": ("timestamp_utc", "datetime", "DateTime_UTC", "Date"),
    "currency": ("currency", "Currency"),
    "impact": ("impact", "Impact"),
    "event": ("event", "event_name", "Event"),
    "actual": ("actual", "Actual"),
    "forecast": ("forecast", "Forecast"),
    "previous": ("previous", "Previous"),
}

MODE_ALIASES = {
    "OFF": "OFF",
    "PAUSE": "PAUSE",
    "SKIP_DAY": "SKIP_DAY",
    "FTMO_PAUSE": "FTMO_PAUSE",
    "FTMO": "FTMO_PAUSE",
    "5ERS_PAUSE": "5ers_PAUSE",
    "5ERS": "5ers_PAUSE",
    "NO_NEWS": "no_news",
    "NO-NEWS": "no_news",
    "NEWS_ONLY": "news_only",
    "NEWS-ONLY": "news_only",
}
MODE_PROFILES = {
    "full": ["OFF", "PAUSE", "SKIP_DAY", "FTMO_PAUSE", "5ers_PAUSE", "no_news", "news_only"],
    "dxz": ["PAUSE", "SKIP_DAY", "OFF"],
    "ftmo": ["FTMO_PAUSE", "PAUSE", "SKIP_DAY", "OFF"],
    "5ers": ["5ers_PAUSE", "PAUSE", "SKIP_DAY", "OFF"],
    "no-news": ["no_news", "OFF"],
    "news-only": ["news_only", "PAUSE", "OFF"],
}
MODE_ORDER = ["OFF", "PAUSE", "SKIP_DAY", "FTMO_PAUSE", "5ers_PAUSE", "no_news", "news_only"]
MODE_SETFILE_VALUE = {
    "OFF": "0",
    "PAUSE": "1",
    "SKIP_DAY": "2",
    "FTMO_PAUSE": "3",
    "5ers_PAUSE": "4",
    "no_news": "5",
    "news_only": "6",
}
DEFAULT_FARM_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")


@dataclass(frozen=True)
class NewsEvent:
    timestamp_utc: datetime
    currency: str
    impact: str
    event: str


@dataclass(frozen=True)
class Trade:
    symbol: str
    entry_time_utc: datetime
    exit_time_utc: datetime | None
    side: str
    profit: float
    volume: float
    source_report: str


def normalize_mode(raw_mode: str) -> str:
    text = (raw_mode or "").strip().upper()
    return MODE_ALIASES.get(text, "")


def parse_mode_profiles(mode_arg: str, custom_modes_arg: str) -> dict[str, list[str]]:
    raw = (mode_arg or "all").strip().lower()
    selected: dict[str, list[str]] = {}
    if raw == "all":
        selected.update(MODE_PROFILES)
    else:
        for name in [x.strip() for x in raw.split(",") if x.strip()]:
            if name not in MODE_PROFILES and name != "custom":
                raise ValueError(f"Unsupported mode profile: {name}")
            if name in MODE_PROFILES:
                selected[name] = list(MODE_PROFILES[name])
    if "custom" in raw or raw == "all":
        custom = []
        for chunk in (custom_modes_arg or "").split(","):
            mode = normalize_mode(chunk)
            if mode and mode not in custom:
                custom.append(mode)
        selected["custom"] = custom or ["OFF"]
    return selected


def parse_mt5_modes(raw_modes: str) -> list[str]:
    raw = (raw_modes or "all").strip()
    if raw.lower() == "all":
        return list(MODE_ORDER)
    modes: list[str] = []
    for chunk in raw.split(","):
        mode = normalize_mode(chunk)
        if not mode:
            raise ValueError(f"Unsupported MT5 news mode: {chunk}")
        if mode not in modes:
            modes.append(mode)
    return modes


def _first(row: dict[str, str], canonical: str) -> str:
    for alias in CALENDAR_ALIASES[canonical]:
        if alias in row and str(row.get(alias) or "").strip():
            return str(row.get(alias) or "").strip()
    return ""


def parse_utc_timestamp(raw: str) -> datetime:
    text = (raw or "").strip()
    if not text:
        raise ValueError("empty timestamp")
    text = text.replace("Z", "+00:00")
    dt = datetime.fromisoformat(text)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    if dt.utcoffset() != timedelta(0):
        raise ValueError(f"non-UTC timestamp: {raw}")
    return dt.astimezone(timezone.utc)


def validate_calendar(path: Path) -> tuple[list[NewsEvent], dict[str, object]]:
    rows = load_csv_rows(path)
    if not rows:
        raise ValueError(f"Calendar CSV has no rows: {path}")
    first = rows[0]
    missing_cols = [col for col in REQUIRED_CALENDAR_COLUMNS if not any(alias in first for alias in CALENDAR_ALIASES[col])]
    if missing_cols:
        raise ValueError(f"Calendar CSV missing required columns: {', '.join(missing_cols)}")

    events: list[NewsEvent] = []
    seen: set[tuple[str, str, str]] = set()
    duplicates = 0
    impact_bad = 0
    for row in rows:
        ts_raw = _first(row, "timestamp_utc")
        dt = parse_utc_timestamp(ts_raw)
        currency = _first(row, "currency").upper()
        impact = _first(row, "impact").lower()
        event_name = _first(row, "event")
        if impact not in {"low", "medium", "high"}:
            impact_bad += 1
            continue
        key = (dt.isoformat(), currency, event_name)
        if key in seen:
            duplicates += 1
        else:
            seen.add(key)
        events.append(NewsEvent(dt, currency, impact, event_name))
    if impact_bad:
        raise ValueError(f"Calendar CSV has {impact_bad} rows with invalid impact level")
    return events, {"rows": len(rows), "usable_events": len(events), "duplicate_event_rows": duplicates}


def normalize_symbol(symbol: str) -> str:
    out = (symbol or "").strip().upper()
    if "." in out:
        out = out.split(".", 1)[0]
    return out


def event_affects_symbol(event: NewsEvent, symbol: str) -> bool:
    currency = event.currency.upper().strip()
    if not currency or currency == "ALL":
        return True
    sym = normalize_symbol(symbol)
    if len(sym) < 6:
        return True
    base, quote = sym[:3], sym[3:6]
    padded = f" {currency} "
    return (
        f" {base} " in padded
        or f" {quote} " in padded
        or base in currency
        or quote in currency
    )


def mode_window_minutes(mode: str, impact: str, before_default: int, after_default: int) -> tuple[int, int]:
    impact = impact.lower()
    if mode == "FTMO_PAUSE":
        if impact == "high":
            return (5, 5)
        if impact == "medium":
            return (3, 3)
        if impact == "low":
            return (1, 1)
        return (0, 0)
    if mode == "5ers_PAUSE":
        if impact == "high":
            return (2, 2)
        if impact == "medium":
            return (1, 1)
        return (0, 0)
    return before_default, after_default


def matching_events(
    events: list[NewsEvent],
    symbol: str,
    ts_utc: datetime,
    mode: str,
    before_minutes: int,
    after_minutes: int,
    min_impact: str,
) -> list[NewsEvent]:
    impact_rank = {"low": 1, "medium": 2, "high": 3}
    required = impact_rank.get(min_impact.lower(), 3)
    matched = []
    for event in events:
        if impact_rank.get(event.impact, 0) < required:
            continue
        if not event_affects_symbol(event, symbol):
            continue
        before, after = mode_window_minutes(mode, event.impact, before_minutes, after_minutes)
        if before <= 0 and after <= 0:
            continue
        if event.timestamp_utc - timedelta(minutes=before) <= ts_utc <= event.timestamp_utc + timedelta(minutes=after):
            matched.append(event)
    return matched


def day_has_event(events: list[NewsEvent], symbol: str, ts_utc: datetime, min_impact: str) -> bool:
    impact_rank = {"low": 1, "medium": 2, "high": 3}
    required = impact_rank.get(min_impact.lower(), 3)
    day = ts_utc.date()
    for event in events:
        if event.timestamp_utc.date() != day:
            continue
        if impact_rank.get(event.impact, 0) < required:
            continue
        if event_affects_symbol(event, symbol):
            return True
    return False


def trade_allowed(
    trade: Trade,
    events: list[NewsEvent],
    mode: str,
    before_minutes: int,
    after_minutes: int,
    min_impact: str,
) -> tuple[bool, list[NewsEvent]]:
    if mode == "OFF":
        return True, []
    matches = matching_events(events, trade.symbol, trade.entry_time_utc, mode, before_minutes, after_minutes, min_impact)
    if mode in {"PAUSE", "FTMO_PAUSE", "5ers_PAUSE"}:
        return not matches, matches
    if mode == "SKIP_DAY":
        has = day_has_event(events, trade.symbol, trade.entry_time_utc, min_impact)
        return not has, matches
    if mode == "no_news":
        return not matches, matches
    if mode == "news_only":
        return bool(matches), matches
    raise ValueError(f"Unsupported mode: {mode}")


def parse_number(text: str) -> float:
    token = html.unescape(str(text or "")).strip().replace("\xa0", " ")
    match = re.search(r"[-+]?\d[\d\s,.]*", token)
    if not match:
        return 0.0
    raw = match.group(0).replace(" ", "")
    if "." in raw and "," in raw:
        raw = raw.replace(",", "")
    elif "," in raw and "." not in raw:
        raw = raw.replace(",", ".")
    return float(raw)


def summary_runs(summary: dict[str, Any]) -> list[dict[str, Any]]:
    runs = summary.get("runs")
    return runs if isinstance(runs, list) else []


def summary_metric(summary: dict[str, Any], keys: tuple[str, ...], default: float = 0.0) -> float:
    for run in summary_runs(summary):
        if not isinstance(run, dict):
            continue
        for key in keys:
            if key in run and run[key] not in (None, ""):
                try:
                    return float(run[key])
                except (TypeError, ValueError):
                    pass
    for key in keys:
        if key in summary and summary[key] not in (None, ""):
            try:
                return float(summary[key])
            except (TypeError, ValueError):
                pass
    return default


def summary_report_paths(summary: dict[str, Any]) -> list[Path]:
    paths: list[Path] = []
    for run in summary_runs(summary):
        if not isinstance(run, dict):
            continue
        for key in ("report_canonical_path", "report_source_path"):
            value = str(run.get(key) or "").strip()
            if value:
                path = Path(value)
                if path.exists():
                    paths.append(path)
    report_dir = str(summary.get("report_dir") or "").strip()
    if report_dir:
        paths.extend(Path(report_dir).glob("raw/run_*/report.htm"))
    return sorted(set(paths))


def metrics_from_summary(summary: dict[str, Any]) -> dict[str, Any]:
    trades = int(summary_metric(summary, ("total_trades", "trade_count", "trades"), 0))
    pf = summary_metric(summary, ("profit_factor", "pf"), 0.0)
    net = summary_metric(summary, ("net_profit", "total_net_profit"), 0.0)
    dd = summary_metric(summary, ("drawdown", "drawdown_pct", "max_drawdown_pct"), 0.0)
    return {
        "trades": trades,
        "profit_factor": round(pf, 4),
        "net_profit": round(net, 2),
        "drawdown": round(dd, 4),
        "result": str(summary.get("result") or ""),
        "reason_classes": summary.get("reason_classes", []),
        "summary_path": str(summary.get("_summary_path") or ""),
    }


def write_mode_setfile(base_setfile: Path, target: Path, mode: str, before: int, after: int, min_impact: str) -> None:
    text = base_setfile.read_text(encoding="utf-8-sig", errors="replace")
    replacements = {
        "qm_news_mode": MODE_SETFILE_VALUE[mode],
        "qm_news_pause_before_minutes": str(before),
        "qm_news_pause_after_minutes": str(after),
        "qm_news_min_impact": min_impact,
    }
    lines = text.splitlines()
    seen = set()
    out_lines = []
    for line in lines:
        if "=" not in line or line.lstrip().startswith(";"):
            out_lines.append(line)
            continue
        key = line.split("=", 1)[0].strip()
        if key in replacements:
            out_lines.append(f"{key}={replacements[key]}")
            seen.add(key)
        else:
            out_lines.append(line)
    for key, value in replacements.items():
        if key not in seen:
            out_lines.append(f"{key}={value}")
    target.write_text("\n".join(out_lines) + "\n", encoding="utf-8")


def infer_active_p8_work_item(ea: str, db_path: Path = DEFAULT_FARM_DB) -> dict[str, str]:
    if not db_path.exists():
        return {}
    try:
        with sqlite3.connect(db_path) as con:
            con.row_factory = sqlite3.Row
            row = con.execute(
                """
                SELECT symbol, setfile_path, claimed_by
                FROM work_items
                WHERE ea_id=? AND phase='P8' AND status='active'
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                (ea,),
            ).fetchone()
    except sqlite3.Error:
        return {}
    if not row:
        return {}
    setfile_path = str(row["setfile_path"] or "").strip()
    symbol = str(row["symbol"] or "").strip()
    terminal = str(row["claimed_by"] or "").strip()
    if not setfile_path or not Path(setfile_path).exists() or not symbol:
        return {}
    return {"base_setfile": setfile_path, "symbol": symbol, "terminal": terminal}


def run_mt5_mode(
    *,
    ea: str,
    symbol: str,
    period: str,
    mode: str,
    base_setfile: Path,
    terminal: str,
    from_date: str,
    to_date: str,
    report_root: Path,
    before_minutes: int,
    after_minutes: int,
    min_impact: str,
    timeout_seconds: int,
    smoke_script: Path,
) -> tuple[dict[str, Any], list[Path]]:
    with tempfile.TemporaryDirectory(prefix=f"qm_p8_{ea}_{mode}_") as tmp:
        mode_setfile = Path(tmp) / f"{ea}_{symbol}_{mode}.set"
        write_mode_setfile(base_setfile, mode_setfile, mode, before_minutes, after_minutes, min_impact)
        ea_id_num = int(re.search(r"QM5_(\d+)", ea).group(1)) if re.search(r"QM5_(\d+)", ea) else int(ea)
        cmd = [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(smoke_script),
            "-EAId",
            str(ea_id_num),
            "-Symbol",
            symbol,
            "-Year",
            from_date[:4],
            "-FromDate",
            from_date,
            "-ToDate",
            to_date,
            "-Terminal",
            terminal,
            "-Period",
            period,
            "-Runs",
            "1",
            "-MinTrades",
            "1",
            "-SetFile",
            str(mode_setfile),
            "-ReportRoot",
            str(report_root),
            "-DispatchPhase",
            "P8",
            "-DispatchVersion",
            f"news_{mode}",
            "-TimeoutSeconds",
            str(timeout_seconds),
            "-AllowMissingRealTicksLogMarker",
        ]
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        proc = subprocess.run(cmd, cwd=str(Path(__file__).resolve().parents[2]), capture_output=True, text=True, timeout=timeout_seconds + 120, creationflags=creationflags)
        summary_path = ""
        for line in (proc.stdout + "\n" + proc.stderr).splitlines():
            if line.startswith("run_smoke.summary="):
                summary_path = line.split("=", 1)[1].strip()
        if not summary_path or not Path(summary_path).exists():
            return {
                "trades": 0,
                "profit_factor": 0.0,
                "net_profit": 0.0,
                "drawdown": 0.0,
                "result": "FAIL",
                "reason_classes": ["NO_SUMMARY_JSON", f"rc={proc.returncode}"],
                "stdout_tail": proc.stdout[-2000:],
                "stderr_tail": proc.stderr[-2000:],
            }, []
        summary = json.loads(Path(summary_path).read_text(encoding="utf-8-sig"))
        summary["_summary_path"] = summary_path
        metrics = metrics_from_summary(summary)
        metrics["mode_setfile_template"] = str(base_setfile)
        return metrics, summary_report_paths(summary)


def broker_to_utc(dt: datetime) -> datetime:
    # DarwinexZero server convention: GMT+2 outside US DST, GMT+3 during US DST.
    year = dt.year
    march = datetime(year, 3, 8)
    dst_start = march + timedelta(days=(6 - march.weekday()) % 7)
    nov = datetime(year, 11, 1)
    dst_end = nov + timedelta(days=(6 - nov.weekday()) % 7)
    offset = 3 if dst_start.date() <= dt.date() < dst_end.date() else 2
    return (dt - timedelta(hours=offset)).replace(tzinfo=timezone.utc)


def parse_report_deals(report_path: Path) -> list[Trade]:
    raw = report_path.read_bytes()
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        text = raw.decode("utf-16", errors="replace")
    else:
        text = raw.decode("utf-8", errors="replace")
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", text, flags=re.IGNORECASE | re.DOTALL)
    in_deals = False
    pending: dict[tuple[str, str], dict[str, Any]] = {}
    trades: list[Trade] = []
    for row_html in rows:
        cells = [html.unescape(re.sub(r"<[^>]+>", "", c)).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row_html, flags=re.IGNORECASE | re.DOTALL)]
        if not cells:
            continue
        if any(c == "Deals" for c in cells):
            in_deals = True
            continue
        if not in_deals or cells[0] == "Time" or len(cells) < 13:
            continue
        direction = cells[4].lower()
        symbol = cells[2].strip()
        if direction not in {"in", "out"} or not symbol:
            continue
        try:
            broker_dt = datetime.strptime(cells[0], "%Y.%m.%d %H:%M:%S")
        except ValueError:
            continue
        side = cells[3].lower()
        volume = parse_number(cells[5])
        profit = parse_number(cells[10])
        key = (symbol, cells[7] or side)
        if direction == "in":
            pending[key] = {
                "symbol": symbol,
                "entry_time_utc": broker_to_utc(broker_dt),
                "side": side,
                "volume": volume,
                "source_report": str(report_path),
            }
        else:
            if key not in pending:
                # Some MT5 reports use different order IDs for in/out. Fall back
                # to first pending symbol-side pair.
                fallback = next((k for k, v in pending.items() if v["symbol"] == symbol), None)
                if fallback is None:
                    continue
                key = fallback
            entry = pending.pop(key)
            trades.append(
                Trade(
                    symbol=symbol,
                    entry_time_utc=entry["entry_time_utc"],
                    exit_time_utc=broker_to_utc(broker_dt),
                    side=str(entry["side"]),
                    volume=float(entry["volume"]),
                    profit=profit,
                    source_report=str(report_path),
                )
            )
    return trades


def discover_reports(out_prefix: Path, ea: str, explicit: list[str]) -> list[Path]:
    reports: list[Path] = []
    for item in explicit:
        path = Path(item)
        if path.exists():
            reports.append(path)
    if reports:
        return sorted(set(reports))
    ea_dir = out_prefix / ea
    candidates = list(ea_dir.glob("P4/fold_runs/**/raw/run_*/report.htm"))
    if not candidates:
        candidates = list(ea_dir.glob("**/raw/run_*/report.htm"))
    by_fold: dict[str, Path] = {}
    for path in candidates:
        parts = path.parts
        key = str(path.parent.parent.parent.parent)
        if "fold_runs" in parts:
            idx = parts.index("fold_runs")
            if idx + 1 < len(parts):
                key = str(Path(*parts[: idx + 2]))
        # Limits repeated retries within the same fold/run family.
        current = by_fold.get(key)
        if current is None or path.stat().st_mtime > current.stat().st_mtime:
            by_fold[key] = path
    return sorted(set(by_fold.values()))


def compute_metrics(trades: list[Trade]) -> dict[str, Any]:
    gross_profit = sum(t.profit for t in trades if t.profit > 0)
    gross_loss = sum(t.profit for t in trades if t.profit < 0)
    net_profit = gross_profit + gross_loss
    pf = gross_profit / abs(gross_loss) if gross_loss < 0 else (999.0 if gross_profit > 0 else 0.0)
    return {
        "trades": len(trades),
        "gross_profit": round(gross_profit, 2),
        "gross_loss": round(gross_loss, 2),
        "net_profit": round(net_profit, 2),
        "profit_factor": round(pf, 4),
    }


def top_trade_risk(trades: list[Trade], top_n: int = 5) -> dict[str, Any]:
    if not trades:
        return {"top_n": top_n, "top_profit": 0.0, "net_without_top": 0.0, "top_profit_share": 0.0}
    winners = sorted([t.profit for t in trades if t.profit > 0], reverse=True)
    top_profit = sum(winners[:top_n])
    net = sum(t.profit for t in trades)
    gross_profit = sum(winners)
    share = top_profit / gross_profit if gross_profit > 0 else 0.0
    return {
        "top_n": top_n,
        "top_profit": round(top_profit, 2),
        "net_without_top": round(net - top_profit, 2),
        "top_profit_share": round(share, 4),
    }


def write_replay_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    ensure_dir(path.parent)
    fieldnames = [
        "mode", "symbol", "entry_time_utc", "allowed", "profit",
        "blocked_event_count", "nearest_event_utc", "nearest_event_currency",
        "nearest_event_impact", "nearest_event_name", "source_report",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_summary_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    ensure_dir(path.parent)
    fieldnames = ["profile", "symbol", "recommended_mode", "verdict", "eligible_mode_count", "selected_modes", "trades", "net_profit", "profit_factor", "blocked_trades", "source"]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="P8 real news replay over MT5 deal rows")
    add_common_args(parser)
    parser.add_argument("--news-matrix", default="", help="Deprecated compatibility arg; ignored except as fallback evidence.")
    parser.add_argument("--calendar-csv", default="D:/QM/data/news_calendar/news_calendar_2015_2025.csv")
    parser.add_argument("--mode", default="all", help="Profile(s): all|full|ftmo|5ers|dxz|no-news|news-only|custom")
    parser.add_argument("--custom-modes", default="")
    parser.add_argument("--trade-report", action="append", default=[], help="MT5 report.htm path. Repeatable.")
    parser.add_argument("--base-setfile", default="", help="Base setfile used for real MT5 reruns with qm_news_mode patched.")
    parser.add_argument("--symbol", default="", help="Symbol for MT5 reruns.")
    parser.add_argument("--period", default="H1", help="Timeframe for MT5 reruns.")
    parser.add_argument("--terminal", default="T1", help="Factory terminal for MT5 reruns.")
    parser.add_argument("--from-date", default="2023.01.01")
    parser.add_argument("--to-date", default="2025.12.31")
    parser.add_argument("--run-mt5", action="store_true", help="Run real MT5 backtests per news mode before replay analysis.")
    parser.add_argument("--mt5-modes", default="all", help="MT5 modes to rerun when --run-mt5 is used, e.g. all|OFF,PAUSE")
    parser.add_argument("--no-auto-mt5", action="store_true", help="Disable active P8 work_item inference for legacy worker commands.")
    parser.add_argument("--smoke-script", default="framework/scripts/run_smoke.ps1")
    parser.add_argument("--smoke-timeout-seconds", type=int, default=3600)
    parser.add_argument("--before-minutes", type=int, default=30)
    parser.add_argument("--after-minutes", type=int, default=30)
    parser.add_argument("--min-impact", choices=["low", "medium", "high"], default="high")
    parser.add_argument("--min-trades", type=int, default=30)
    parser.add_argument("--min-profit-factor", type=float, default=1.0)
    parser.add_argument("--require-nonnegative-net", action="store_true", default=True)
    args = parser.parse_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P8")
    events, calendar_stats = validate_calendar(Path(args.calendar_csv))
    selected_profiles = parse_mode_profiles(args.mode, args.custom_modes)
    inferred_work_item = {}
    if not args.no_auto_mt5 and not args.run_mt5 and not args.base_setfile and not args.trade_report:
        inferred_work_item = infer_active_p8_work_item(args.ea)
        if inferred_work_item:
            args.base_setfile = inferred_work_item["base_setfile"]
            args.symbol = args.symbol or inferred_work_item["symbol"]
            args.terminal = inferred_work_item.get("terminal") or args.terminal
            args.run_mt5 = True
    if not args.run_mt5 and not args.base_setfile:
        result = build_result(
            phase="P8",
            ea_id=args.ea,
            verdict="WAITING_INPUT",
            criterion="P8 requires real MT5 news-mode reruns via --run-mt5 and --base-setfile.",
            evidence_path=str(Path(args.news_matrix)) if args.news_matrix else "",
            details={
                "calendar_csv": str(Path(args.calendar_csv)),
                "calendar_stats": calendar_stats,
                "deprecated_news_matrix": str(Path(args.news_matrix)) if args.news_matrix else "",
                "trade_reports_ignored_for_hard_gate": [str(p) for p in args.trade_report],
                "parameters": {
                    "run_mt5": False,
                    "inferred_work_item": inferred_work_item,
                    "from_date": args.from_date,
                    "to_date": args.to_date,
                },
            },
        )
        result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P8", ea_id=args.ea, result=result)
        update_result_with_evidence_path(result_path, result)
        print(result_path)
        return 0
    mt5_metrics: dict[str, dict[str, dict[str, Any]]] = {}
    mt5_report_paths: list[Path] = []
    if args.run_mt5 or args.base_setfile:
        if not args.base_setfile or not args.symbol:
            raise ValueError("--run-mt5 requires --base-setfile and --symbol")
        base_setfile = Path(args.base_setfile)
        if not base_setfile.exists():
            raise ValueError(f"Base setfile missing: {base_setfile}")
        mt5_root = out_dir / "mt5_mode_runs"
        for mode in parse_mt5_modes(args.mt5_modes):
            metrics, reports = run_mt5_mode(
                ea=args.ea,
                symbol=args.symbol,
                period=args.period,
                mode=mode,
                base_setfile=base_setfile,
                terminal=args.terminal,
                from_date=args.from_date,
                to_date=args.to_date,
                report_root=mt5_root,
                before_minutes=args.before_minutes,
                after_minutes=args.after_minutes,
                min_impact=args.min_impact,
                timeout_seconds=args.smoke_timeout_seconds,
                smoke_script=Path(args.smoke_script),
            )
            mt5_metrics.setdefault(mode, {})[args.symbol] = metrics
            mt5_report_paths.extend(reports)

    report_paths = discover_reports(Path(args.out_prefix), args.ea, args.trade_report + [str(p) for p in mt5_report_paths])
    if not report_paths:
        raise ValueError(f"No MT5 reports found for real news replay under {Path(args.out_prefix) / args.ea}")

    trades: list[Trade] = []
    for report in report_paths:
        trades.extend(parse_report_deals(report))
    if not trades:
        raise ValueError("No real MT5 entry/exit trade pairs parsed from reports")

    by_symbol = sorted({t.symbol for t in trades})
    replay_rows: list[dict[str, Any]] = []
    metrics_by_mode_symbol: dict[str, dict[str, dict[str, Any]]] = {}
    for mode in MODE_ORDER:
        metrics_by_mode_symbol[mode] = {}
        for symbol in by_symbol:
            symbol_trades = [t for t in trades if t.symbol == symbol]
            kept: list[Trade] = []
            blocked = 0
            for trade in symbol_trades:
                allowed, matched = trade_allowed(trade, events, mode, args.before_minutes, args.after_minutes, args.min_impact)
                if allowed:
                    kept.append(trade)
                else:
                    blocked += 1
                nearest = matched[0] if matched else None
                replay_rows.append({
                    "mode": mode,
                    "symbol": trade.symbol,
                    "entry_time_utc": trade.entry_time_utc.isoformat(),
                    "allowed": "1" if allowed else "0",
                    "profit": round(trade.profit, 2),
                    "blocked_event_count": len(matched),
                    "nearest_event_utc": nearest.timestamp_utc.isoformat() if nearest else "",
                    "nearest_event_currency": nearest.currency if nearest else "",
                    "nearest_event_impact": nearest.impact if nearest else "",
                    "nearest_event_name": nearest.event if nearest else "",
                    "source_report": trade.source_report,
                })
            metrics = mt5_metrics.get(mode, {}).get(symbol) or compute_metrics(kept)
            metrics["blocked_trades"] = blocked
            metrics["original_trades"] = len(symbol_trades)
            metrics["source"] = "mt5_rerun" if mode in mt5_metrics and symbol in mt5_metrics[mode] else "deal_replay"
            metrics["top_trade_risk"] = top_trade_risk(kept, top_n=5)
            metrics_by_mode_symbol[mode][symbol] = metrics

    summary_rows: list[dict[str, Any]] = []
    mode_results: dict[str, Any] = {}
    any_failure = False
    for profile, allowed_modes in selected_profiles.items():
        profile_failure = False
        symbol_results = []
        recommended_mode_by_symbol: dict[str, str] = {}
        for symbol in by_symbol:
            candidates = []
            for mode in allowed_modes:
                metrics = metrics_by_mode_symbol.get(mode, {}).get(symbol, {})
                if not metrics:
                    continue
                if int(metrics["trades"]) < args.min_trades:
                    continue
                if float(metrics["profit_factor"]) < args.min_profit_factor:
                    continue
                if args.require_nonnegative_net and float(metrics["net_profit"]) < 0:
                    continue
                candidates.append((mode, metrics))
            candidates.sort(key=lambda item: (float(item[1]["profit_factor"]), float(item[1]["net_profit"]), -int(item[1]["blocked_trades"])), reverse=True)
            if candidates:
                rec_mode, rec_metrics = candidates[0]
                verdict = "MODE_SELECTED"
            else:
                rec_mode = "REVIEW_REQUIRED"
                rec_metrics = compute_metrics([])
                verdict = "NO_ELIGIBLE_MODE"
                profile_failure = True
            recommended_mode_by_symbol[symbol] = rec_mode
            row = {
                "profile": profile,
                "symbol": symbol,
                "recommended_mode": rec_mode,
                "verdict": verdict,
                "eligible_mode_count": len(candidates),
                "selected_modes": ",".join(allowed_modes),
                "trades": rec_metrics["trades"],
                "net_profit": rec_metrics["net_profit"],
                "profit_factor": rec_metrics["profit_factor"],
                "blocked_trades": rec_metrics.get("blocked_trades", 0),
                "source": rec_metrics.get("source", "deal_replay"),
            }
            summary_rows.append(row)
            symbol_results.append(row)
        mode_results[profile] = {
            "selected_modes": allowed_modes,
            "recommended_mode_by_symbol": recommended_mode_by_symbol,
            "symbol_results": symbol_results,
            "verdict": "MODE_SELECTED" if not profile_failure else "NO_ELIGIBLE_MODE",
        }
        any_failure = any_failure or profile_failure

    replay_csv = out_dir / "P8_real_news_replay.csv"
    summary_csv = out_dir / "P8_summary.csv"
    write_replay_csv(replay_csv, replay_rows)
    write_summary_csv(summary_csv, summary_rows)
    trades_json = out_dir / "P8_trade_replay_inputs.json"
    write_json(trades_json, {
        "reports": [str(p) for p in report_paths],
        "trade_count": len(trades),
        "symbols": by_symbol,
        "calendar_csv": str(Path(args.calendar_csv)),
    })

    result = build_result(
        phase="P8",
        ea_id=args.ea,
        verdict="NO_ELIGIBLE_MODE" if any_failure else "MODE_SELECTED",
        criterion="P8 real news replay: MT5 deal timestamps mapped to actual UTC news calendar and runtime modes",
        evidence_path="",
        details={
            "calendar_csv": str(Path(args.calendar_csv)),
            "calendar_stats": calendar_stats,
            "reports": [str(p) for p in report_paths],
            "mt5_mode_metrics": mt5_metrics,
            "trade_count": len(trades),
            "top_trade_risk_all_modes_off": top_trade_risk(trades, top_n=5),
            "symbols": by_symbol,
            "mode_results": mode_results,
            "summary_csv": str(summary_csv),
            "replay_csv": str(replay_csv),
            "trade_inputs_json": str(trades_json),
            "parameters": {
                "before_minutes": args.before_minutes,
                "after_minutes": args.after_minutes,
                "min_impact": args.min_impact,
                "min_trades": args.min_trades,
                "min_profit_factor": args.min_profit_factor,
                "require_nonnegative_net": args.require_nonnegative_net,
                "run_mt5": bool(args.run_mt5 or args.base_setfile),
                "mt5_modes": parse_mt5_modes(args.mt5_modes) if (args.run_mt5 or args.base_setfile) else [],
                "inferred_work_item": inferred_work_item,
                "from_date": args.from_date,
                "to_date": args.to_date,
            },
        },
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P8", ea_id=args.ea, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
