#!/usr/bin/env python3
"""Account-level FTMO_BOOK simulator and marginal-contribution engine.

The engine consumes a declared sleeve roster and SHA-bound real chronological
Q08 trade streams.  It re-costs each round trip with the canonical commission
registry, retains stream swap unless the optional financing library can provide
a primary-table value, applies configurable spread/slippage stress, builds a
Prague-midnight account path, and delegates block-bootstrap target/breach/payout
probabilities to :mod:`first_passage` (it does not fork that engine).

Floating equity is necessarily a proxy because the frozen streams contain
closed trades rather than tick paths.  The account path therefore uses the sum
of every active trade's scaled MAE as a conservative simultaneous-open-P/L
envelope.  Every output labels this approximation explicitly.

Read-only safety: this module never starts MT5, touches terminals, writes the
farm DB, enables trading, or sends orders.  Its only optional external write is
the requested machine read-model JSON.
"""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import importlib.util
import json
import math
import re
import sys
from dataclasses import asdict, dataclass, replace
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo

import numpy as np

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from tools.strategy_farm.ftmo import first_passage as fp
from tools.strategy_farm.ftmo.dependence_matrix import compute_dependence_matrix, render_markdown


SCHEMA = "qm.ftmo-book-sim/v1"
MARGINAL_SCHEMA = "qm.ftmo-book-marginal/v1"
STATE_SCHEMA = "qm.ftmo-book-current/v1"
REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_COMMISSION_REGISTRY = REPO_ROOT / "framework" / "registry" / "live_commission.json"
DEFAULT_FINANCING_LIB = REPO_ROOT / "tools" / "strategy_farm" / "swap" / "financing_lib.py"
DEFAULT_STATE_OUT = Path(r"D:\QM\reports\state\ftmo_book_current.json")
DEFAULT_HUMAN_MIRROR = REPO_ROOT / "docs" / "ftmo" / "FTMO_BOOK_CURRENT.md"
DEFAULT_STREAM_ROOT = Path(r"D:\QM\reports\book_evolution\2026-W38\ftmo\snapshot_r2\streams\QM\q08_trades")
DEFAULT_STREAM_MANIFEST = Path(r"D:\QM\reports\book_evolution\2026-W38\ftmo\snapshot_r2\manifest.json")
DEFAULT_WEIGHT_GRID = (0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5)
SOURCE_RISK_PERCENT = 1.0
PROXY_LABEL = "CONSERVATIVE_SIMULTANEOUS_ACTIVE_MAE_ENVELOPE_NOT_TICK_EXACT"


@dataclass(frozen=True)
class CostConfig:
    spread_bps_rt: float = 0.0
    slippage_usd_per_lot_rt: float = 0.0
    margin_rate: float = 0.01


@dataclass(frozen=True)
class SleeveSpec:
    id: str
    ea_id: int
    symbol: str
    timeframe: str
    stream_path: str
    stream_sha256: str
    risk_percent: float
    role: str = "UNSPECIFIED"
    family: str = "UNSPECIFIED"
    session: str = "UNSPECIFIED"
    news_profile: str = "UNSPECIFIED"
    label: str = ""
    magic: int | None = None
    slot: int | None = None


def sha256_file(path: Path | str) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_sha256(value: Any) -> str:
    blob = json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _load_json(path: Path | str) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _iso_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _parse_as_of(value: str | None) -> dt.datetime:
    if not value:
        return dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc).replace(microsecond=0)


def _parse_epoch(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.timestamp()


def _normalize_symbol(value: Any) -> str:
    symbol = str(value or "").upper().strip()
    if not symbol:
        raise ValueError("sleeve symbol is required")
    return symbol if symbol.endswith(".DWX") else f"{symbol}.DWX"


def _stream_filename(ea_id: int, symbol: str) -> str:
    return f"{ea_id}_{symbol.replace('.DWX', '_DWX')}.jsonl"


def _manifest_stream_hashes(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    payload = _load_json(path)
    if payload.get("schema") != "qm.recompose-frozen-inputs/v1":
        raise ValueError(f"unsupported stream manifest schema: {payload.get('schema')!r}")
    return {
        str(row["key"]): str(row["sha256"]).lower()
        for row in payload.get("streams", {}).get("records") or []
        if row.get("status") == "PRESENT" and row.get("key") and row.get("sha256")
    }


def load_roster_specs(
    roster_path: Path | str, *, stream_root: Path = DEFAULT_STREAM_ROOT,
    stream_manifest: Path | None = DEFAULT_STREAM_MANIFEST, require_sha: bool = True,
) -> tuple[dict[str, Any], list[SleeveSpec]]:
    payload = _load_json(roster_path)
    rows = payload.get("sleeves") or payload.get("candidates") or []
    if not isinstance(rows, list) or not rows:
        raise ValueError("roster must contain a non-empty sleeves or candidates list")
    manifest_hashes = _manifest_stream_hashes(stream_manifest)
    specs: list[SleeveSpec] = []
    seen: set[str] = set()
    for index, row in enumerate(rows):
        ea_id = int(row["ea_id"])
        symbol = _normalize_symbol(
            row.get("dwx_symbol") or row.get("dxz_symbol") or row.get("symbol")
        )
        stream_path = Path(row.get("stream_path") or (stream_root / _stream_filename(ea_id, symbol)))
        key = f"{ea_id}:{symbol}"
        expected = str(row.get("stream_sha256") or manifest_hashes.get(key) or "").lower()
        if require_sha and not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise ValueError(f"{key}: a manifest-bound stream_sha256 is required")
        if not stream_path.is_file():
            raise FileNotFoundError(f"{key}: stream missing: {stream_path}")
        actual = sha256_file(stream_path)
        if expected and actual != expected:
            raise ValueError(f"{key}: stream sha256 mismatch ({actual} != {expected})")
        slot = row.get("slot")
        sleeve_id = str(row.get("id") or f"{ea_id}:{symbol}:{slot if slot is not None else index}")
        if sleeve_id in seen:
            raise ValueError(f"duplicate sleeve id: {sleeve_id}")
        seen.add(sleeve_id)
        risk = float(row.get("risk_percent") or 0.0)
        if risk <= 0.0:
            raise ValueError(f"{sleeve_id}: risk_percent must be > 0")
        specs.append(SleeveSpec(
            id=sleeve_id,
            ea_id=ea_id,
            symbol=symbol,
            timeframe=str(row.get("timeframe") or "UNSPECIFIED"),
            stream_path=str(stream_path.resolve()),
            stream_sha256=actual,
            risk_percent=risk,
            role=str(row.get("role") or "UNSPECIFIED"),
            family=str(row.get("family") or "UNSPECIFIED"),
            session=str(row.get("session") or "UNSPECIFIED"),
            news_profile=str(row.get("news_profile") or "UNSPECIFIED"),
            label=str(row.get("ea_label") or row.get("label") or ""),
            magic=int(row["magic"]) if row.get("magic") is not None else None,
            slot=int(slot) if slot is not None else None,
        ))
    return payload, specs


def _load_commission_registry(path: Path | str) -> dict[str, Any]:
    payload = _load_json(path)
    if payload.get("model") != "max(pct_rate_rt*notional_acct, flat_per_lot_rt*volume)":
        raise ValueError("unsupported live_commission registry model")
    return payload


def _commission_for_trade(
    row: Mapping[str, Any], symbol: str, registry: Mapping[str, Any]
) -> tuple[float, str]:
    symbol_class = registry.get("symbol_class", {}).get(symbol, registry.get("default_class"))
    model = registry.get("classes", {}).get(symbol_class)
    if not isinstance(model, dict):
        raise ValueError(f"commission class missing for {symbol}: {symbol_class!r}")
    volume = abs(float(row.get("volume") or 0.0))
    notional = abs(float(row.get("notional") or 0.0))
    pct_cost = float(model.get("pct_rate_rt") or 0.0) * notional
    flat_cost = float(model.get("flat_per_lot_rt") or 0.0) * volume
    source = "REGISTRY_MAX_PCT_NOTIONAL_FLAT"
    if notional <= 0.0:
        source = "REGISTRY_FLAT_FALLBACK_NOTIONAL_MISSING"
    return max(pct_cost, flat_cost), source


def _load_financing_module(path: Path) -> tuple[Any | None, str]:
    if not path.is_file():
        return None, "PRIMARY_FINANCING_TABLE_MISSING_STREAM_EMBEDDED_SWAP_FALLBACK"
    spec = importlib.util.spec_from_file_location("qm_financing_lib", path)
    if spec is None or spec.loader is None:
        return None, "PRIMARY_FINANCING_TABLE_UNLOADABLE_STREAM_EMBEDDED_SWAP_FALLBACK"
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if not callable(getattr(module, "trade_financing_usd", None)):
        return None, "PRIMARY_FINANCING_API_MISSING_STREAM_EMBEDDED_SWAP_FALLBACK"
    return module, f"PRIMARY_FINANCING_TABLE:{path}"


def _trade_swap(
    row: Mapping[str, Any], symbol: str, financing_module: Any | None,
) -> tuple[float, str]:
    embedded = float(row.get("swap") or 0.0)
    if financing_module is None:
        return embedded, "STREAM_EMBEDDED_ACTUAL"
    result = financing_module.trade_financing_usd(dict(row), symbol=symbol)
    if isinstance(result, Mapping):
        return float(result["usd"]), str(result.get("source") or "PRIMARY_FINANCING_TABLE")
    return float(result), "PRIMARY_FINANCING_TABLE"


def _iter_jsonl(path: Path) -> Iterable[dict[str, Any]]:
    with path.open("r", encoding="utf-8", errors="strict") as handle:
        for line_number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{line_number}: invalid JSON: {exc}") from exc
            if value.get("event", "TRADE_CLOSED") == "TRADE_CLOSED":
                yield value


def prepare_sleeve(
    spec: SleeveSpec, *, commission_registry: Mapping[str, Any], cost: CostConfig,
    financing_module: Any | None, financing_status: str,
) -> dict[str, Any]:
    trades: list[dict[str, Any]] = []
    commission_sources: set[str] = set()
    swap_sources: set[str] = set()
    factor = spec.risk_percent / SOURCE_RISK_PERCENT
    for row in _iter_jsonl(Path(spec.stream_path)):
        entry = _parse_epoch(row.get("entry_time"))
        close = _parse_epoch(row.get("time"))
        if close < entry:
            raise ValueError(f"{spec.id}: trade closes before entry")
        gross = float(row.get("profit", row.get("net") or 0.0))
        commission, commission_source = _commission_for_trade(row, spec.symbol, commission_registry)
        swap, swap_source = _trade_swap(row, spec.symbol, financing_module)
        volume = abs(float(row.get("volume") or 0.0))
        notional = abs(float(row.get("notional") or 0.0))
        spread = max(0.0, float(cost.spread_bps_rt)) / 10000.0 * notional
        slippage = max(0.0, float(cost.slippage_usd_per_lot_rt)) * volume
        net = gross + swap - commission - spread - slippage
        raw_mae = min(float(row.get("mae_acct") or 0.0), 0.0)
        mae = min(net, raw_mae - commission - spread - slippage)
        raw_mfe = row.get("mfe_acct")
        mfe = float(raw_mfe) if raw_mfe is not None else None
        commission_sources.add(commission_source)
        swap_sources.add(swap_source)
        trades.append({
            "entry_time": entry,
            "close_time": close,
            "side": str(row.get("side") or "UNKNOWN").upper(),
            "gross_source": gross,
            "swap_source_usd": swap,
            "commission_source_usd": commission,
            "spread_stress_source_usd": spread,
            "slippage_stress_source_usd": slippage,
            "net_source": net,
            "mae_source": mae,
            "mfe_source": mfe,
            "volume_source": volume,
            "notional_source": notional,
            "net_scaled": net * factor,
            "mae_scaled": mae * factor,
            "mfe_scaled": (mfe * factor if mfe is not None else None),
            "commission_scaled": commission * factor,
            "swap_scaled": swap * factor,
            "spread_stress_scaled": spread * factor,
            "slippage_stress_scaled": slippage * factor,
            "volume_scaled": volume * factor,
            "notional_scaled": notional * factor,
            "margin_proxy_scaled": notional * factor * max(0.0, cost.margin_rate),
        })
    trades.sort(key=lambda trade: (trade["close_time"], trade["entry_time"]))
    if not trades:
        raise ValueError(f"{spec.id}: no TRADE_CLOSED rows")
    return {
        "id": spec.id,
        "ea_id": spec.ea_id,
        "label": spec.label,
        "symbol": spec.symbol,
        "timeframe": spec.timeframe,
        "risk_percent": spec.risk_percent,
        "role": spec.role,
        "family": spec.family,
        "session": spec.session,
        "news_profile": spec.news_profile,
        "magic": spec.magic,
        "slot": spec.slot,
        "stream_path": spec.stream_path,
        "stream_sha256": spec.stream_sha256,
        "trades": trades,
        "commission_sources": sorted(commission_sources),
        "swap_sources": sorted(swap_sources),
        "financing_library_status": financing_status,
    }


def prepare_book(
    specs: Sequence[SleeveSpec], *, commission_registry_path: Path = DEFAULT_COMMISSION_REGISTRY,
    financing_lib_path: Path = DEFAULT_FINANCING_LIB, cost: CostConfig = CostConfig(),
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    commission_registry = _load_commission_registry(commission_registry_path)
    financing_module, financing_status = _load_financing_module(financing_lib_path)
    sleeves = [
        prepare_sleeve(spec, commission_registry=commission_registry, cost=cost,
                       financing_module=financing_module, financing_status=financing_status)
        for spec in specs
    ]
    provenance = {
        "commission_registry": str(commission_registry_path.resolve()),
        "commission_registry_sha256": sha256_file(commission_registry_path),
        "commission_model": commission_registry["model"],
        "financing_library": str(financing_lib_path.resolve()),
        "financing_library_status": financing_status,
        "spread_slippage_stress": asdict(cost),
    }
    return sleeves, provenance


def _prague_date(epoch: float, timezone: str = "Europe/Prague") -> dt.date:
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).astimezone(ZoneInfo(timezone)).date()


def _business_days(start: dt.date, end: dt.date) -> list[dt.date]:
    out: list[dt.date] = []
    cur = start
    while cur <= end:
        if cur.weekday() < 5:
            out.append(cur)
        cur += dt.timedelta(days=1)
    return out


def common_window(sleeves: Sequence[Mapping[str, Any]]) -> tuple[dt.date, dt.date]:
    starts = [min(_prague_date(t["entry_time"]) for t in sleeve["trades"]) for sleeve in sleeves]
    ends = [max(_prague_date(t["close_time"]) for t in sleeve["trades"]) for sleeve in sleeves]
    start, end = max(starts), min(ends)
    if start > end:
        raise ValueError(f"empty all-active window: {start} > {end}")
    return start, end


def _clip_sleeves(
    sleeves: Sequence[Mapping[str, Any]], start: dt.date, end: dt.date
) -> list[dict[str, Any]]:
    clipped: list[dict[str, Any]] = []
    for sleeve in sleeves:
        row = {key: value for key, value in sleeve.items() if key != "trades"}
        row["trades"] = [
            dict(trade) for trade in sleeve["trades"]
            if start <= _prague_date(trade["close_time"]) <= end
        ]
        if not row["trades"]:
            raise ValueError(f"{sleeve['id']}: no trades inside fixed comparison window")
        clipped.append(row)
    return clipped


def _daily_sleeve(sleeve: Mapping[str, Any]) -> dict[dt.date, dict[str, float]]:
    by_day: dict[dt.date, list[Mapping[str, Any]]] = {}
    opened: set[dt.date] = set()
    for trade in sleeve["trades"]:
        by_day.setdefault(_prague_date(trade["close_time"]), []).append(trade)
        opened.add(_prague_date(trade["entry_time"]))
    out: dict[dt.date, dict[str, float]] = {}
    for day, trades in by_day.items():
        running = net = 0.0
        low = 0.0
        for trade in sorted(trades, key=lambda item: item["close_time"]):
            low = min(low, running + float(trade["mae_scaled"]))
            running += float(trade["net_scaled"])
            net += float(trade["net_scaled"])
        low = min(low, net)
        out[day] = {"net": net, "low": low, "opened": 1.0 if day in opened else 0.0}
    for day in opened:
        out.setdefault(day, {"net": 0.0, "low": 0.0, "opened": 1.0})
        out[day]["opened"] = 1.0
    return out


def _max_drawdown(values: Sequence[float]) -> tuple[float, int, int, int | None]:
    peak = values[0]
    peak_index = trough_index = 0
    max_dd = 0.0
    for index, value in enumerate(values):
        if value > peak:
            peak, peak_index = value, index
        drawdown = peak - value
        if drawdown > max_dd:
            max_dd, trough_index = drawdown, index
            dd_peak_index = peak_index
    if max_dd <= 0.0:
        return 0.0, 0, 0, 0
    recovery = next(
        (index for index in range(trough_index + 1, len(values))
         if values[index] >= values[dd_peak_index]),
        None,
    )
    return max_dd, dd_peak_index, trough_index, recovery


def _exposure_metrics(sleeves: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    events: list[tuple[float, int, float]] = []
    for sleeve in sleeves:
        for trade in sleeve["trades"]:
            events.append((float(trade["entry_time"]), 1, float(trade["margin_proxy_scaled"])))
            events.append((float(trade["close_time"]), 0, -float(trade["margin_proxy_scaled"])))
    active = 0
    margin = 0.0
    max_active = 0
    max_margin = 0.0
    for _, order, delta in sorted(events, key=lambda row: (row[0], row[1])):
        if delta >= 0.0:
            active += 1
        else:
            active = max(0, active - 1)
        margin = max(0.0, margin + delta)
        max_active = max(max_active, active)
        max_margin = max(max_margin, margin)
    return {
        "max_simultaneous_positions": max_active,
        "max_margin_proxy_usd": round(max_margin, 2),
        "margin_proxy_note": "sum(abs(notional) * configured margin_rate) while positions overlap",
    }


def account_path_metrics(
    sleeves: Sequence[Mapping[str, Any]], *, start: dt.date, end: dt.date,
    initial_balance: float = 100000.0, daily_loss_fraction: float = 0.05,
    max_loss_fraction: float = 0.10,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    days = _business_days(start, end)
    daily_by_sleeve = [_daily_sleeve(sleeve) for sleeve in sleeves]
    balance = initial_balance
    balances = [balance]
    path: list[dict[str, Any]] = []
    active_days = 0
    daily_breach_days = max_breach_days = 0
    worst_daily_loss = 0.0
    lowest_equity = initial_balance
    target_day: str | None = None
    daily_cap = initial_balance * daily_loss_fraction
    max_floor = initial_balance * (1.0 - max_loss_fraction)
    for day in days:
        start_balance = balance
        day_net = sum(records.get(day, {}).get("net", 0.0) for records in daily_by_sleeve)
        day_low = sum(records.get(day, {}).get("low", 0.0) for records in daily_by_sleeve)
        opened = any(records.get(day, {}).get("opened", 0.0) > 0.0 for records in daily_by_sleeve)
        equity_low = start_balance + day_low
        balance += day_net
        balances.append(balance)
        if opened:
            active_days += 1
        worst_daily_loss = min(worst_daily_loss, day_low)
        lowest_equity = min(lowest_equity, equity_low)
        daily_breach = equity_low < start_balance - daily_cap
        max_breach = equity_low < max_floor
        daily_breach_days += int(daily_breach)
        max_breach_days += int(max_breach)
        if target_day is None and balance > initial_balance * 1.10:
            target_day = day.isoformat()
        path.append({
            "date": day.isoformat(), "balance_start": round(start_balance, 6),
            "realized_net": round(day_net, 6), "balance_end": round(balance, 6),
            "equity_low_mae_proxy": round(equity_low, 6), "opened": opened,
            "daily_loss_breach": daily_breach, "max_loss_breach": max_breach,
        })
    max_dd, peak_idx, trough_idx, recovery_idx = _max_drawdown(balances)
    total_trades = sum(len(sleeve["trades"]) for sleeve in sleeves)
    total_net = balance - initial_balance
    total_source_risk_usd = sum(
        1000.0 * sleeve["risk_percent"] / SOURCE_RISK_PERCENT * len(sleeve["trades"])
        for sleeve in sleeves
    )
    raw_r_per_day = sum(
        sum(float(t["net_source"]) for t in sleeve["trades"]) / 1000.0
        for sleeve in sleeves
    ) / max(1, len(days))
    costs = {
        "commission_usd": sum(float(t["commission_scaled"]) for s in sleeves for t in s["trades"]),
        "swap_usd": sum(float(t["swap_scaled"]) for s in sleeves for t in s["trades"]),
        "spread_stress_usd": sum(float(t["spread_stress_scaled"]) for s in sleeves for t in s["trades"]),
        "slippage_stress_usd": sum(float(t["slippage_stress_scaled"]) for s in sleeves for t in s["trades"]),
    }
    metrics = {
        "window": {"start": start.isoformat(), "end": end.isoformat(), "business_days": len(days)},
        "BOOK_EXPECTANCY": round(total_net / total_source_risk_usd, 6) if total_source_risk_usd else None,
        "BOOK_R_PER_DAY": round(raw_r_per_day, 6),
        "BOOK_EXPECTED_PROGRESS_USD_PER_DAY": round(total_net / max(1, len(days)), 6),
        "BOOK_TRADES_PER_DAY": round(total_trades / max(1, len(days)), 6),
        "BOOK_ACTIVE_DAYS": round(active_days / max(1, len(days)), 6),
        "TIME_WITH_NO_OPPORTUNITY": round(1.0 - active_days / max(1, len(days)), 6),
        "BOOK_MAX_DD": round(-max_dd, 6),
        "BOOK_MAX_DD_ABS_USD": round(max_dd, 6),
        "BOOK_RECOVERY_TIME_BD": (
            recovery_idx - trough_idx if recovery_idx is not None else None
        ),
        "BOOK_RECOVERY_CENSORED": recovery_idx is None,
        "BOOK_FINAL_BALANCE": round(balance, 6),
        "BOOK_REALIZED_NET": round(total_net, 6),
        "BOOK_LOWEST_EQUITY_MAE_PROXY": round(lowest_equity, 6),
        "BOOK_WORST_DAILY_LOSS_MAE_PROXY": round(worst_daily_loss, 6),
        "HISTORICAL_DAILY_LOSS_BREACH_DAYS": daily_breach_days,
        "HISTORICAL_MAX_LOSS_BREACH_DAYS": max_breach_days,
        "HISTORICAL_CHALLENGE_TARGET_FIRST_DAY": target_day,
        "BOOK_COST_DRAG": {key: round(value, 6) for key, value in costs.items()},
        "BOOK_COST_DRAG_USD_PER_DAY": round(
            (costs["commission_usd"] - costs["swap_usd"] + costs["spread_stress_usd"]
             + costs["slippage_stress_usd"]) / max(1, len(days)), 6
        ),
        "equity_proxy": PROXY_LABEL,
        **_exposure_metrics(sleeves),
    }
    return metrics, path


def _to_first_passage_roster(
    sleeves: Sequence[Mapping[str, Any]], *, start: dt.date, end: dt.date,
    timezone: str,
) -> dict[str, Any]:
    tz = ZoneInfo(timezone)
    fp_sleeves: list[fp.SleeveInput] = []
    for sleeve in sleeves:
        trades = [
            {
                "close": dt.datetime.fromtimestamp(t["close_time"], dt.timezone.utc),
                "entry": dt.datetime.fromtimestamp(t["entry_time"], dt.timezone.utc),
                "net": float(t["net_source"]), "mae": float(t["mae_source"]),
                "lots": float(t["volume_source"]),
                "commission": float(t["commission_source_usd"]),
            }
            for t in sleeve["trades"]
        ]
        daily = {
            day: values for day, values in fp.sleeve_daily(trades, tz).items()
            if start <= day <= end
        }
        fp_sleeves.append(fp.SleeveInput(
            ea_id=sleeve["ea_id"], ftmo_symbol=sleeve["symbol"].replace(".DWX", ""),
            dwx_symbol=sleeve["symbol"], magic=sleeve.get("magic"),
            risk_pct=float(sleeve["risk_percent"]), stream_path=sleeve["stream_path"],
            stream_sha256=sleeve["stream_sha256"], trades=trades, daily=daily,
        ))
    return {
        "ok": True, "sleeves": fp_sleeves, "dropped": [],
        "roster_label": "FTMO_BOOK", "roster_source": "book_sim_sha_bound_streams",
    }


def first_passage_for_book(
    sleeves: Sequence[Mapping[str, Any]], *, start: dt.date, end: dt.date,
    n_paths: int, seed: int, block_len: int, horizon: int, as_of: dt.datetime,
) -> dict[str, Any]:
    rules = fp.load_rules()
    economics = fp.load_economics()
    roster = _to_first_passage_roster(
        sleeves, start=start, end=end, timezone=str(rules["timezone"])
    )
    return fp.build(
        roster=roster, rules=rules, economics=economics, seed=seed,
        n_paths=n_paths, block_len=block_len, horizon=horizon,
        sensitivity=((1.0, 0.0), (1.5, 2.0)), chain=True,
        n_batches=min(20, max(2, n_paths // 100)), now=as_of,
    )


def _public_sleeves(sleeves: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    rows = []
    for sleeve in sleeves:
        trades = sleeve["trades"]
        rows.append({
            key: sleeve.get(key) for key in (
                "id", "ea_id", "label", "symbol", "timeframe", "risk_percent", "role",
                "family", "session", "news_profile", "magic", "slot", "stream_path",
                "stream_sha256", "commission_sources", "swap_sources",
                "financing_library_status",
            )
        } | {
            "trades": len(trades),
            "entry_span_utc": [
                dt.datetime.fromtimestamp(min(t["entry_time"] for t in trades), dt.timezone.utc).isoformat(),
                dt.datetime.fromtimestamp(max(t["entry_time"] for t in trades), dt.timezone.utc).isoformat(),
            ],
        })
    return rows


def evaluate_book(
    specs: Sequence[SleeveSpec], *, cost: CostConfig = CostConfig(),
    commission_registry_path: Path = DEFAULT_COMMISSION_REGISTRY,
    financing_lib_path: Path = DEFAULT_FINANCING_LIB,
    fixed_window: tuple[dt.date, dt.date] | None = None,
    n_paths: int = 2000, seed: int = 20260921, block_len: int = 20,
    horizon: int = 756, as_of: dt.datetime | None = None,
) -> tuple[dict[str, Any], list[dict[str, Any]], dict[str, Any]]:
    as_of = as_of or dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    sleeves, provenance = prepare_book(
        specs, commission_registry_path=commission_registry_path,
        financing_lib_path=financing_lib_path, cost=cost,
    )
    start, end = fixed_window or common_window(sleeves)
    sleeves = _clip_sleeves(sleeves, start, end)
    metrics, path = account_path_metrics(sleeves, start=start, end=end)
    dependence = compute_dependence_matrix(
        sleeves, generated_at_utc=as_of.isoformat()
    )
    passage = first_passage_for_book(
        sleeves, start=start, end=end, n_paths=n_paths, seed=seed,
        block_len=block_len, horizon=horizon, as_of=as_of,
    )
    headline = passage.get("headline") or {}
    chain = passage.get("chain") or {}
    probabilities = chain.get("probabilities") or {}
    stages = chain.get("stages") or {}
    metrics.update({
        "BOOK_DAILY_LOSS_BREACH_PROB": headline.get("p_daily_loss_breach"),
        "BOOK_MAX_LOSS_BREACH_PROB": headline.get("p_max_loss_breach"),
        "BOOK_EXPECTED_TIME_TO_CHALLENGE_TARGET": (
            chain.get("time_business_days", {}).get("phase1_target")
        ),
        "BOOK_EXPECTED_TIME_TO_VERIFICATION_TARGET": (
            chain.get("time_business_days", {}).get("verification_target")
        ),
        "BOOK_TAIL_DEPENDENCE": dependence.get("summary"),
        "BOOK_CONCENTRATION": _concentration(sleeves),
    })
    manifest = {
        "schema": "qm.ftmo-book-sim-input/v1",
        "sleeves": [asdict(spec) for spec in specs],
        "fixed_window": [start.isoformat(), end.isoformat()],
        "cost": asdict(cost), "seed": seed, "n_paths": n_paths,
        "block_len": block_len, "horizon": horizon,
        "provenance": provenance,
    }
    result = {
        "schema": SCHEMA,
        "generated_at_utc": as_of.isoformat(),
        "status": "OK",
        "label": (
            "real chronological trades; registry commission; stream swap fallback when "
            "primary financing table is unavailable; floating equity is a conservative "
            "simultaneous-active-MAE proxy"
        ),
        "input_manifest": manifest,
        "input_manifest_sha256": canonical_sha256(manifest),
        "sleeves": _public_sleeves(sleeves),
        "book_metrics": metrics,
        "first_passage": {
            "engine_schema": passage.get("schema"),
            "engine_version": passage.get("engine_version"),
            "input_manifest_sha256": passage.get("input_manifest_sha256"),
            "probabilities": probabilities,
            "stages": {
                name: {
                    key: value for key, value in report.items()
                    if key in {"p_pass", "p_daily_loss_breach", "p_max_loss_breach", "p_censored",
                               "conditional_on_reaching_stage"}
                }
                for name, report in stages.items()
            },
            "time_business_days": chain.get("time_business_days"),
            "sensitivity": chain.get("sensitivity"),
            "method": chain.get("method") or passage.get("method"),
        },
        "dependence_summary": dependence.get("summary"),
        "account_path_summary": {
            "rows": len(path), "equity_proxy": PROXY_LABEL,
            "daily_loss_anchor": "Europe/Prague midnight balance; fixed 5% initial-equity cap",
            "maximum_loss_floor": "static 90% of initial equity",
        },
    }
    return result, sleeves, dependence


def _concentration(sleeves: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    by_symbol: dict[str, float] = {}
    by_family: dict[str, float] = {}
    total = sum(float(s["risk_percent"]) for s in sleeves)
    for sleeve in sleeves:
        by_symbol[sleeve["symbol"]] = by_symbol.get(sleeve["symbol"], 0.0) + float(sleeve["risk_percent"])
        family = str(sleeve.get("family") or "UNSPECIFIED")
        by_family[family] = by_family.get(family, 0.0) + float(sleeve["risk_percent"])
    hhi = sum((value / total) ** 2 for value in by_symbol.values()) if total else None
    return {
        "book_risk_percent": round(total, 6),
        "risk_by_symbol_percent": {key: round(value, 6) for key, value in sorted(by_symbol.items())},
        "risk_by_family_percent": {key: round(value, 6) for key, value in sorted(by_family.items())},
        "symbol_risk_hhi": round(hhi, 6) if hhi is not None else None,
    }


def _metric_projection(result: Mapping[str, Any]) -> dict[str, Any]:
    metrics = result["book_metrics"]
    passage = result["first_passage"]
    probabilities = passage.get("probabilities") or {}
    times = passage.get("time_business_days") or {}
    dependence = result.get("dependence_summary") or {}
    return {
        "P_FIRST_NET_FTMO_PAYOUT_LCB": probabilities.get("P_FIRST_NET_FTMO_PAYOUT_LCB"),
        "P_CHALLENGE_PASS": probabilities.get("P_CHALLENGE_PASS"),
        "P_VERIFICATION_PASS": probabilities.get("P_VERIFICATION_PASS_GIVEN_CHALLENGE"),
        "P_DAILY_LOSS_BREACH": metrics.get("BOOK_DAILY_LOSS_BREACH_PROB"),
        "P_MAX_LOSS_BREACH": metrics.get("BOOK_MAX_LOSS_BREACH_PROB"),
        "EXPECTED_TIME_TO_TARGET": (times.get("phase1_target") or {}).get("mean"),
        "MAX_DRAWDOWN": metrics.get("BOOK_MAX_DD_ABS_USD"),
        "RECOVERY_TIME": metrics.get("BOOK_RECOVERY_TIME_BD"),
        "TRADE_DENSITY": metrics.get("BOOK_TRADES_PER_DAY"),
        "TAIL_DEPENDENCE": dependence.get("max_lower_tail_ratio"),
        "COST_DRAG": metrics.get("BOOK_COST_DRAG_USD_PER_DAY"),
    }


def _difference(value: Any, reference: Any) -> float | None:
    if value is None or reference is None:
        return None
    return round(float(value) - float(reference), 6)


def _delta_row(reference: Mapping[str, Any], variant: Mapping[str, Any]) -> dict[str, Any]:
    before = _metric_projection(reference)
    after = _metric_projection(variant)
    return {
        "reference": before,
        "variant": after,
        **{f"DELTA_{key}": _difference(after.get(key), before.get(key)) for key in before},
    }


def _candidate_spec(
    row: Mapping[str, Any], *, stream_root: Path, manifest_hashes: Mapping[str, str]
) -> SleeveSpec:
    sleeve = row.get("sleeve") or row
    ea_id = int(sleeve["ea_id"])
    symbol = _normalize_symbol(
        sleeve.get("dwx_symbol") or sleeve.get("dxz_symbol") or sleeve.get("symbol")
    )
    key = f"{ea_id}:{symbol}"
    path = Path(sleeve.get("stream_path") or stream_root / _stream_filename(ea_id, symbol))
    expected = str(sleeve.get("stream_sha256") or manifest_hashes.get(key) or "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise ValueError(f"candidate {key}: manifest-bound stream sha256 required")
    actual = sha256_file(path)
    if actual != expected:
        raise ValueError(f"candidate {key}: stream sha256 mismatch")
    proposed = float(row.get("proposed_risk_percent") or sleeve.get("risk_percent") or 0.0)
    return SleeveSpec(
        id=str(row.get("id") or sleeve.get("id") or key), ea_id=ea_id,
        symbol=symbol, timeframe=str(sleeve.get("timeframe") or "UNSPECIFIED"),
        stream_path=str(path.resolve()), stream_sha256=actual, risk_percent=proposed,
        role=str(sleeve.get("role") or "UNSPECIFIED"),
        family=str(sleeve.get("family") or "UNSPECIFIED"),
        session=str(sleeve.get("session") or "UNSPECIFIED"),
        news_profile=str(sleeve.get("news_profile") or "UNSPECIFIED"),
        label=str(sleeve.get("ea_label") or sleeve.get("label") or ""),
        magic=int(sleeve["magic"]) if sleeve.get("magic") is not None else None,
        slot=int(sleeve["slot"]) if sleeve.get("slot") is not None else None,
    )


def marginal_contributions(
    base_specs: Sequence[SleeveSpec], candidate_plan: Mapping[str, Any], *,
    stream_root: Path = DEFAULT_STREAM_ROOT,
    stream_manifest: Path | None = DEFAULT_STREAM_MANIFEST,
    cost: CostConfig = CostConfig(), weight_grid: Sequence[float] = DEFAULT_WEIGHT_GRID,
    n_paths: int = 1000, seed: int = 20260921, block_len: int = 20,
    horizon: int = 504, as_of: dt.datetime | None = None,
) -> dict[str, Any]:
    as_of = as_of or dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    manifest_hashes = _manifest_stream_hashes(stream_manifest)
    rows: list[dict[str, Any]] = []
    base_prepared, _ = prepare_book(base_specs, cost=cost)
    base_window = common_window(base_prepared)
    base_cache: dict[tuple[str, str], dict[str, Any]] = {}

    def evaluate(specs: Sequence[SleeveSpec], window: tuple[dt.date, dt.date]) -> dict[str, Any]:
        result, _, _ = evaluate_book(
            specs, cost=cost, fixed_window=window, n_paths=n_paths, seed=seed,
            block_len=block_len, horizon=horizon, as_of=as_of,
        )
        return result

    for plan_row in candidate_plan.get("candidates") or []:
        mode = str(plan_row.get("mode") or "add")
        candidate_id = str(plan_row.get("id") or plan_row.get("ea_id") or "candidate")
        if mode == "placeholder":
            rows.append({
                "id": candidate_id, "mode": mode, "status": "NOT_YET_MEASURABLE",
                "reason": str(plan_row.get("reason") or "stream pending"),
                "book_action": str(plan_row.get("book_action") or "TEST"),
                "role": plan_row.get("role"), "symbol": plan_row.get("symbol"),
            })
            continue
        if mode == "leave_one_out":
            ea_id = int(plan_row["ea_id"])
            matches = [spec for spec in base_specs if spec.ea_id == ea_id]
            if len(matches) != 1:
                raise ValueError(f"leave-one-out {ea_id}: expected one base sleeve, got {len(matches)}")
            without = [spec for spec in base_specs if spec.ea_id != ea_id]
            reference = evaluate(without, base_window)
            variant = evaluate(base_specs, base_window)
            rows.append({
                "id": candidate_id, "mode": mode, "status": "OK",
                "proposed_risk_percent": matches[0].risk_percent,
                "comparison_window": [base_window[0].isoformat(), base_window[1].isoformat()],
                "contribution_when_present": _delta_row(reference, variant),
            })
            continue
        if mode != "add":
            raise ValueError(f"unsupported candidate mode: {mode}")
        candidate = _candidate_spec(plan_row, stream_root=stream_root,
                                    manifest_hashes=manifest_hashes)
        candidate_prepared, _ = prepare_book([candidate], cost=cost)
        combined_window = common_window([*base_prepared, *candidate_prepared])
        cache_key = (combined_window[0].isoformat(), combined_window[1].isoformat())
        if cache_key not in base_cache:
            base_cache[cache_key] = evaluate(base_specs, combined_window)
        reference = base_cache[cache_key]
        grid_rows: list[dict[str, Any]] = []
        proposed_row: dict[str, Any] | None = None
        proposed = float(plan_row.get("proposed_risk_percent") or candidate.risk_percent)
        weights = sorted(set(float(value) for value in (*weight_grid, proposed)))
        for weight in weights:
            variant_spec = replace(candidate, risk_percent=weight)
            variant = evaluate([*base_specs, variant_spec], combined_window)
            item = {"risk_percent": weight, **_delta_row(reference, variant)}
            grid_rows.append(item)
            if abs(weight - proposed) <= 1e-12:
                proposed_row = item
        rows.append({
            "id": candidate_id, "mode": mode, "status": "OK",
            "role": candidate.role, "symbol": candidate.symbol,
            "stream_sha256": candidate.stream_sha256,
            "proposed_risk_percent": proposed,
            "comparison_window": [combined_window[0].isoformat(), combined_window[1].isoformat()],
            "proposed": proposed_row,
            "weight_grid": grid_rows,
        })
    return {
        "schema": MARGINAL_SCHEMA,
        "generated_at_utc": as_of.isoformat(),
        "method": (
            "candidate and its paired base reference use the same all-active window, "
            "seed, block bootstrap, cost model and first_passage engine; deltas are variant-reference"
        ),
        "params": {"seed": seed, "n_paths": n_paths, "block_len": block_len,
                   "horizon": horizon, "weight_grid": list(weight_grid)},
        "candidates": rows,
    }


def _parse_missing_behavior(human_mirror: Path, existing_state: Mapping[str, Any] | None) -> str:
    if human_mirror.is_file():
        text = human_mirror.read_text(encoding="utf-8")
        match = re.search(
            r"(?im)^-\s*\*\*Strongest missing behaviou?r:\*\*\s*(.+)$", text
        )
        if match:
            return match.group(1).strip()
    if existing_state and existing_state.get("strongest_missing_behavior"):
        return str(existing_state["strongest_missing_behavior"])
    return "NOT_YET_MEASURABLE"


def _candidate_state_rows(marginal: Mapping[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in marginal.get("candidates") or []:
        if row.get("status") != "OK":
            out.append({
                "id": row.get("id"), "symbol": row.get("symbol"),
                "role": row.get("role"), "book_action": row.get("book_action", "TEST"),
                "marginal_payout_probability": "NOT_YET_MEASURABLE",
                "reason": row.get("reason"),
            })
            continue
        delta = row.get("proposed") or row.get("contribution_when_present") or {}
        lcb = delta.get("DELTA_P_FIRST_NET_FTMO_PAYOUT_LCB")
        daily = delta.get("DELTA_P_DAILY_LOSS_BREACH")
        maximum = delta.get("DELTA_P_MAX_LOSS_BREACH")
        if row.get("mode") == "leave_one_out":
            action = "KEEP" if lcb is not None and lcb >= 0.0 else "REVIEW_REMOVAL"
        else:
            action = (
                "CONSIDER_ADD" if lcb is not None and lcb > 0.0
                and (daily is None or daily <= 0.0) and (maximum is None or maximum <= 0.0)
                else "HOLD"
            )
        out.append({
            "id": row.get("id"), "symbol": row.get("symbol"), "role": row.get("role"),
            "mode": row.get("mode"), "book_action": action,
            "proposed_risk_percent": row.get("proposed_risk_percent"),
            "marginal": {key: value for key, value in delta.items() if key.startswith("DELTA_")},
        })
    return out


def build_state(
    base: Mapping[str, Any], marginal: Mapping[str, Any], dependence: Mapping[str, Any], *,
    book_id: str, human_mirror: Path = DEFAULT_HUMAN_MIRROR,
    existing_state: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    metrics = copy.deepcopy(base["book_metrics"])
    first = base.get("first_passage") or {}
    probabilities = first.get("probabilities") or {}
    times = first.get("time_business_days") or {}
    role_by_ea = {
        int(row["ea_id"]): row.get("role")
        for row in (existing_state or {}).get("sleeves") or [] if row.get("ea_id") is not None
    }
    sleeves = []
    for row in base.get("sleeves") or []:
        role = row.get("role")
        if role in {None, "", "UNSPECIFIED"}:
            role = role_by_ea.get(int(row["ea_id"]), "UNSPECIFIED")
        sleeves.append({
            "id": row.get("id"), "ea_id": row.get("ea_id"),
            "symbol": str(row.get("symbol") or "").replace(".DWX", ""),
            "timeframe": row.get("timeframe"), "risk_percent": row.get("risk_percent"),
            "role": role, "sha256": row.get("stream_sha256"),
            "stream_path": row.get("stream_path"),
        })
    daily_headroom = 5000.0 - abs(min(0.0, float(metrics["BOOK_WORST_DAILY_LOSS_MAE_PROXY"])))
    max_headroom = 10000.0 - float(metrics["BOOK_MAX_DD_ABS_USD"])
    top = dependence.get("summary", {}).get("top_fail_together_pair")
    state = {
        "schema": STATE_SCHEMA,
        "generated_at_utc": base.get("generated_at_utc"),
        "author": "Codex account-level simulator e5c49db2",
        "decision": "OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921",
        "book_id": book_id,
        "book_risk_percent": round(sum(float(s["risk_percent"]) for s in sleeves), 6),
        "account": {"product": "FTMO Challenge 2-Step", "size_usd": 100000},
        "sleeves": sleeves,
        "candidates": _candidate_state_rows(marginal),
        "book_metrics": metrics,
        "first_passage": {
            "P_CHALLENGE_PASS": probabilities.get("P_CHALLENGE_PASS"),
            "P_VERIFICATION_PASS_GIVEN_CHALLENGE": probabilities.get(
                "P_VERIFICATION_PASS_GIVEN_CHALLENGE"
            ),
            "P_END_TO_END_FIRST_PAYOUT": probabilities.get("P_END_TO_END_FIRST_PAYOUT"),
            "P_FIRST_NET_FTMO_PAYOUT_LCB": probabilities.get("P_FIRST_NET_FTMO_PAYOUT_LCB"),
            "median_phase1_bd": (times.get("phase1_target") or {}).get("p50"),
            "median_verification_bd": (times.get("verification_target") or {}).get("p50"),
            "median_end_to_end_bd": (times.get("end_to_end") or {}).get("p50"),
            "engine": "tools/strategy_farm/ftmo/first_passage.py",
        },
        "demo_cycle": {
            "state": (existing_state or {}).get("demo_cycle", {}).get("state", "UNMEASURED"),
            "rule_headroom": {
                "daily_loss_headroom": f"{daily_headroom:.2f} USD (MAE proxy)",
                "max_loss_headroom": f"{max_headroom:.2f} USD (drawdown proxy)",
            },
        },
        "dependence_summary": {
            "top_fail_together_pair": top,
            "fail_together_clusters": dependence.get("summary", {}).get("fail_together_clusters") or [],
            "matrix_schema": dependence.get("schema"),
        },
        "strongest_missing_behavior": _parse_missing_behavior(human_mirror, existing_state),
        "machine_fields_note": (
            "human mirror is input-only and was not overwritten; floating equity/open risk use labelled MAE proxies"
        ),
        "input_hashes": {
            "book_sim": base.get("input_manifest_sha256"),
            "first_passage": first.get("input_manifest_sha256"),
        },
    }
    return state


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
                    encoding="utf-8")


def _load_existing_state(path: Path) -> Mapping[str, Any] | None:
    if not path.is_file():
        return None
    try:
        value = _load_json(path)
    except (OSError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--roster", required=True, type=Path)
    parser.add_argument("--stream-root", type=Path, default=DEFAULT_STREAM_ROOT)
    parser.add_argument("--stream-manifest", type=Path, default=DEFAULT_STREAM_MANIFEST)
    parser.add_argument("--candidate-plan", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--marginal-out", type=Path)
    parser.add_argument("--dependence-out", type=Path)
    parser.add_argument("--dependence-md", type=Path)
    parser.add_argument("--state-out", type=Path)
    parser.add_argument("--human-mirror", type=Path, default=DEFAULT_HUMAN_MIRROR)
    parser.add_argument("--spread-bps-rt", type=float, default=0.0)
    parser.add_argument("--slippage-usd-per-lot-rt", type=float, default=0.0)
    parser.add_argument("--margin-rate", type=float, default=0.01)
    parser.add_argument("--n-paths", type=int, default=2000)
    parser.add_argument("--marginal-n-paths", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=20260921)
    parser.add_argument("--block-len", type=int, default=20)
    parser.add_argument("--horizon", type=int, default=756)
    parser.add_argument("--marginal-horizon", type=int, default=504)
    parser.add_argument("--as-of")
    parser.add_argument("--book-id")
    args = parser.parse_args(argv)

    as_of = _parse_as_of(args.as_of)
    cost = CostConfig(args.spread_bps_rt, args.slippage_usd_per_lot_rt, args.margin_rate)
    roster_payload, specs = load_roster_specs(
        args.roster, stream_root=args.stream_root, stream_manifest=args.stream_manifest,
        require_sha=True,
    )
    base, sleeves, dependence = evaluate_book(
        specs, cost=cost, n_paths=args.n_paths, seed=args.seed,
        block_len=args.block_len, horizon=args.horizon, as_of=as_of,
    )
    _write_json(args.out, base)
    if args.dependence_out:
        _write_json(args.dependence_out, dependence)
    if args.dependence_md:
        args.dependence_md.parent.mkdir(parents=True, exist_ok=True)
        args.dependence_md.write_text(render_markdown(dependence), encoding="utf-8")

    if args.candidate_plan:
        candidate_plan = _load_json(args.candidate_plan)
        marginal = marginal_contributions(
            specs, candidate_plan, stream_root=args.stream_root,
            stream_manifest=args.stream_manifest, cost=cost,
            n_paths=args.marginal_n_paths, seed=args.seed,
            block_len=args.block_len, horizon=args.marginal_horizon, as_of=as_of,
        )
    else:
        marginal = {"schema": MARGINAL_SCHEMA, "generated_at_utc": as_of.isoformat(),
                    "status": "NOT_REQUESTED", "candidates": []}
    if args.marginal_out:
        _write_json(args.marginal_out, marginal)

    if args.state_out:
        existing = _load_existing_state(args.state_out)
        state = build_state(
            base, marginal, dependence,
            book_id=str(args.book_id or roster_payload.get("cycle_id") or roster_payload.get("label") or "FTMO_BOOK"),
            human_mirror=args.human_mirror, existing_state=existing,
        )
        _write_json(args.state_out, state)

    metrics = base["book_metrics"]
    probs = base["first_passage"].get("probabilities") or {}
    top = (dependence.get("summary") or {}).get("top_fail_together_pair") or {}
    print(json.dumps({
        "status": "OK", "out": str(args.out),
        "BOOK_R_PER_DAY": metrics.get("BOOK_R_PER_DAY"),
        "BOOK_TRADES_PER_DAY": metrics.get("BOOK_TRADES_PER_DAY"),
        "P_FIRST_NET_FTMO_PAYOUT_LCB": probs.get("P_FIRST_NET_FTMO_PAYOUT_LCB"),
        "top_fail_together_pair": top.get("pair"),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
