#!/usr/bin/env python3
"""Account-level FTMO_BOOK simulator and marginal-contribution engine.

The engine consumes a declared sleeve roster and SHA-bound real chronological
Q08 trade streams.  It re-costs each round trip with the canonical commission
registry, retains stream swap unless the optional financing library can provide
a primary-table value, applies configurable spread/slippage stress, builds a
Prague-midnight account path, and delegates block-bootstrap target/breach/payout
probabilities to :mod:`first_passage` (it does not fork that engine).

Base and candidate comparisons use one fixed calendar: the base book's common
window.  This deliberately replaces the older roster-intersection rule.  Under
that rule a short candidate changed the evidence window as well as the roster;
for example, adding QM5_11910 ended the D2g comparison on 2025-06-05 and
discarded later incumbent observations.  A candidate may now be inactive
outside its own stream span, but it cannot move the comparison endpoints.

Financing is explicit and fail-closed at the CLI.  Governed book evidence must
use --financed-streams whose every trade carries qm_financing metadata, or the
caller must opt into a visibly UNFINANCED research run with
--allow-unfinanced. Missing financing can never silently receive a book-
evidence label.

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
import statistics
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
FINANCED = "FINANCED"
UNFINANCED = "UNFINANCED"
DEFAULT_MARGINAL_PATHS = 40000
DEFAULT_MARGINAL_GRID_PATHS = 5000
DEFAULT_MARGINAL_REPLICATES = 5
DEFAULT_RESOLUTION_TARGET = 0.01
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
    financed_stream_root: Path | None = None,
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
        stream_path = (
            financed_stream_root / _stream_filename(ea_id, symbol)
            if financed_stream_root is not None
            else Path(row.get("stream_path") or (stream_root / _stream_filename(ea_id, symbol)))
        )
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
    financing_label: str,
) -> tuple[float, str]:
    embedded = float(row.get("swap") or 0.0)
    if financing_module is None:
        if financing_label == FINANCED:
            proof = row.get("qm_financing")
            if not isinstance(proof, Mapping):
                raise ValueError(
                    f"{symbol}: FINANCED stream row lacks qm_financing metadata"
                )
            required = {"status", "financing_usd", "units", "nights"}
            missing = sorted(required - set(proof))
            if missing:
                raise ValueError(
                    f"{symbol}: FINANCED stream row lacks fields {missing}"
                )
            exact = float(proof["financing_usd"])
            # The governed stream serializes swap to account cents while
            # retaining the unrounded table result in qm_financing.
            if abs(embedded - round(exact, 2)) > 0.011:
                raise ValueError(
                    f"{symbol}: embedded swap {embedded} does not match "
                    f"qm_financing.financing_usd {exact}"
                )
            return embedded, f"FINANCED_STREAM_QM_FINANCING:{proof['status']}"
        return embedded, "UNFINANCED_STREAM_EMBEDDED_SWAP"
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
    financing_module: Any | None, financing_status: str, financing_label: str,
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
        swap, swap_source = _trade_swap(
            row, spec.symbol, financing_module, financing_label
        )
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
        "financing_label": financing_label,
    }


def prepare_book(
    specs: Sequence[SleeveSpec], *, commission_registry_path: Path = DEFAULT_COMMISSION_REGISTRY,
    financing_lib_path: Path = DEFAULT_FINANCING_LIB, cost: CostConfig = CostConfig(),
    financing_label: str = UNFINANCED,
    financed_stream_root: Path | None = None,
    financing_manifest_path: Path | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if financing_label not in {FINANCED, UNFINANCED}:
        raise ValueError(f"unsupported financing label: {financing_label!r}")
    commission_registry = _load_commission_registry(commission_registry_path)
    if financing_label == FINANCED:
        if financed_stream_root is None:
            raise ValueError("FINANCED evaluation requires financed_stream_root")
        financing_module = None
        financing_status = "FINANCED_STREAMS_QM_FINANCING_EMBEDDED"
    else:
        financing_module, financing_status = _load_financing_module(financing_lib_path)
    sleeves = [
        prepare_sleeve(spec, commission_registry=commission_registry, cost=cost,
                       financing_module=financing_module, financing_status=financing_status,
                       financing_label=financing_label)
        for spec in specs
    ]
    financing_manifest = None
    financing_manifest_sha256 = None
    if financing_manifest_path is not None:
        if not financing_manifest_path.is_file():
            raise FileNotFoundError(
                f"financing manifest missing: {financing_manifest_path}"
            )
        financing_manifest = str(financing_manifest_path.resolve())
        financing_manifest_sha256 = sha256_file(financing_manifest_path)
    provenance = {
        "commission_registry": str(commission_registry_path.resolve()),
        "commission_registry_sha256": sha256_file(commission_registry_path),
        "commission_model": commission_registry["model"],
        "financing_library": str(financing_lib_path.resolve()),
        "financing_library_status": financing_status,
        "financing_label": financing_label,
        "financed_stream_root": (
            str(financed_stream_root.resolve())
            if financed_stream_root is not None else None
        ),
        "financing_manifest": financing_manifest,
        "financing_manifest_sha256": financing_manifest_sha256,
        "financing_row_contract": (
            "every TRADE_CLOSED row has qm_financing.status, financing_usd, "
            "units and nights; cent-rounded financing_usd equals swap"
            if financing_label == FINANCED else
            "not asserted; output is research-only UNFINANCED"
        ),
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
    lightweight: bool = False,
) -> dict[str, Any]:
    rules = fp.load_rules()
    economics = fp.load_economics()
    roster = _to_first_passage_roster(
        sleeves, start=start, end=end, timezone=str(rules["timezone"])
    )
    return fp.build(
        roster=roster, rules=rules, economics=economics, seed=seed,
        n_paths=n_paths, block_len=block_len, horizon=horizon,
        sensitivity=(
            ((1.0, 0.0),) if lightweight
            else ((1.0, 0.0), (1.5, 2.0))
        ),
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
                "financing_library_status", "financing_label",
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
    financing_label: str = UNFINANCED,
    financed_stream_root: Path | None = None,
    financing_manifest_path: Path | None = None,
    fixed_window: tuple[dt.date, dt.date] | None = None,
    n_paths: int = 2000, seed: int = 20260921, block_len: int = 20,
    horizon: int = 756, as_of: dt.datetime | None = None,
    lightweight: bool = False,
) -> tuple[dict[str, Any], list[dict[str, Any]], dict[str, Any]]:
    as_of = as_of or dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    sleeves, provenance = prepare_book(
        specs, commission_registry_path=commission_registry_path,
        financing_lib_path=financing_lib_path, cost=cost,
        financing_label=financing_label,
        financed_stream_root=financed_stream_root,
        financing_manifest_path=financing_manifest_path,
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
        lightweight=lightweight,
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
        "financing_label": financing_label,
    }
    result = {
        "schema": SCHEMA,
        "generated_at_utc": as_of.isoformat(),
        "status": "OK",
        "label": (
            f"{financing_label}; real chronological trades; registry commission; "
            + (
                "qm_financing-bound embedded financing; "
                if financing_label == FINANCED
                else "unfinanced research input; "
            )
            + "floating equity is a conservative simultaneous-active-MAE proxy"
        ),
        "financing": {
            "label": financing_label,
            "source": provenance["financing_library_status"],
            "financed_stream_root": provenance["financed_stream_root"],
            "manifest": provenance["financing_manifest"],
            "manifest_sha256": provenance["financing_manifest_sha256"],
            "book_evidence_eligible": financing_label == FINANCED,
        },
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
    row: Mapping[str, Any], *, stream_root: Path, manifest_hashes: Mapping[str, str],
    financed_stream_root: Path | None = None,
) -> SleeveSpec:
    sleeve = row.get("sleeve") or row
    ea_id = int(sleeve["ea_id"])
    symbol = _normalize_symbol(
        sleeve.get("dwx_symbol") or sleeve.get("dxz_symbol") or sleeve.get("symbol")
    )
    key = f"{ea_id}:{symbol}"
    path = (
        financed_stream_root / _stream_filename(ea_id, symbol)
        if financed_stream_root is not None
        else Path(sleeve.get("stream_path") or stream_root / _stream_filename(ea_id, symbol))
    )
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


def _lcb_resolution(
    deltas: Sequence[float], *, n_paths: int, target_delta: float
) -> dict[str, Any]:
    """Summarize seed-replicate uncertainty for one marginal LCB delta."""
    if len(deltas) < 2:
        raise ValueError("at least two seed replicates are required")
    values = [float(value) for value in deltas]
    mean = statistics.fmean(values)
    sample_sd = statistics.stdev(values)
    standard_error = sample_sd / math.sqrt(len(values))
    minimum_resolvable = 2.0 * standard_error
    return {
        "replicates": len(values),
        "paths_per_replicate": n_paths,
        "lcb_delta_samples": [round(value, 6) for value in values],
        "lcb_delta_mean": round(mean, 6),
        "lcb_delta_sample_sd": round(sample_sd, 6),
        "lcb_standard_error": round(standard_error, 6),
        "minimum_resolvable_delta_2se": round(minimum_resolvable, 6),
        "resolution_status": (
            "RESOLVED" if abs(mean) >= minimum_resolvable else "UNRESOLVED"
        ),
        "resolution_target_delta": target_delta,
        "target_delta_resolution_status": (
            "RESOLVED" if target_delta >= minimum_resolvable else "UNRESOLVED"
        ),
    }


def marginal_contributions(
    base_specs: Sequence[SleeveSpec], candidate_plan: Mapping[str, Any], *,
    stream_root: Path = DEFAULT_STREAM_ROOT,
    stream_manifest: Path | None = DEFAULT_STREAM_MANIFEST,
    financing_label: str = UNFINANCED,
    financed_stream_root: Path | None = None,
    financing_manifest_path: Path | None = None,
    cost: CostConfig = CostConfig(), weight_grid: Sequence[float] = DEFAULT_WEIGHT_GRID,
    n_paths: int = DEFAULT_MARGINAL_PATHS, seed: int = 20260921,
    grid_n_paths: int = DEFAULT_MARGINAL_GRID_PATHS,
    replicate_count: int = DEFAULT_MARGINAL_REPLICATES,
    resolution_target_delta: float = DEFAULT_RESOLUTION_TARGET,
    block_len: int = 20,
    horizon: int = 504, as_of: dt.datetime | None = None,
) -> dict[str, Any]:
    if replicate_count < 5:
        raise ValueError("marginal resolution requires at least 5 seed replicates")
    if n_paths <= 0 or grid_n_paths <= 0 or resolution_target_delta <= 0.0:
        raise ValueError("marginal path count and resolution target must be positive")
    as_of = as_of or dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    manifest_hashes = _manifest_stream_hashes(stream_manifest)
    rows: list[dict[str, Any]] = []
    base_prepared, _ = prepare_book(
        base_specs, cost=cost, financing_label=financing_label,
        financed_stream_root=financed_stream_root,
        financing_manifest_path=financing_manifest_path,
    )
    base_window = common_window(base_prepared)
    base_cache: dict[tuple[str, str, int, int, bool], dict[str, Any]] = {}

    def evaluate(
        specs: Sequence[SleeveSpec], window: tuple[dt.date, dt.date], run_seed: int,
        path_count: int, *, lightweight: bool,
    ) -> dict[str, Any]:
        result, _, _ = evaluate_book(
            specs, cost=cost, financing_label=financing_label,
            financed_stream_root=financed_stream_root,
            financing_manifest_path=financing_manifest_path,
            fixed_window=window, n_paths=path_count, seed=run_seed,
            block_len=block_len, horizon=horizon, as_of=as_of,
            lightweight=lightweight,
        )
        return result

    def cached_base(
        window: tuple[dt.date, dt.date], run_seed: int, path_count: int, *,
        lightweight: bool,
    ) -> dict[str, Any]:
        key = (
            window[0].isoformat(), window[1].isoformat(), run_seed,
            path_count, lightweight,
        )
        if key not in base_cache:
            base_cache[key] = evaluate(
                base_specs, window, run_seed, path_count, lightweight=lightweight
            )
        return base_cache[key]

    replicate_seeds = [seed + offset for offset in range(replicate_count)]

    def resolution(
        reference_specs: Sequence[SleeveSpec],
        variant_specs: Sequence[SleeveSpec],
        window: tuple[dt.date, dt.date],
        *,
        reference_is_base: bool,
    ) -> dict[str, Any]:
        deltas: list[float] = []
        for run_seed in replicate_seeds:
            reference = (
                cached_base(
                    window, run_seed, n_paths, lightweight=True
                )
                if reference_is_base
                else evaluate(
                    reference_specs, window, run_seed, n_paths, lightweight=True
                )
            )
            variant = (
                cached_base(
                    window, run_seed, n_paths, lightweight=True
                )
                if list(variant_specs) == list(base_specs)
                else evaluate(
                    variant_specs, window, run_seed, n_paths, lightweight=True
                )
            )
            delta = _difference(
                _metric_projection(variant)["P_FIRST_NET_FTMO_PAYOUT_LCB"],
                _metric_projection(reference)["P_FIRST_NET_FTMO_PAYOUT_LCB"],
            )
            if delta is None:
                raise ValueError("LCB delta unavailable during resolution run")
            deltas.append(delta)
        report = _lcb_resolution(
            deltas, n_paths=n_paths, target_delta=resolution_target_delta
        )
        report["seeds"] = replicate_seeds
        return report

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
            reference = evaluate(
                without, base_window, seed, grid_n_paths, lightweight=False
            )
            variant = cached_base(
                base_window, seed, grid_n_paths, lightweight=False
            )
            contribution = _delta_row(reference, variant)
            contribution["resolution"] = resolution(
                without, base_specs, base_window, reference_is_base=False
            )
            rows.append({
                "id": candidate_id, "mode": mode, "status": "OK",
                "proposed_risk_percent": matches[0].risk_percent,
                "comparison_window": [base_window[0].isoformat(), base_window[1].isoformat()],
                "contribution_when_present": contribution,
            })
            continue
        if mode != "add":
            raise ValueError(f"unsupported candidate mode: {mode}")
        candidate = _candidate_spec(
            plan_row, stream_root=stream_root, manifest_hashes=manifest_hashes,
            financed_stream_root=financed_stream_root,
        )
        # The candidate's shorter stream must not truncate incumbent history.
        # Both sides use the fixed base calendar; out-of-span candidate days
        # are correctly represented as candidate inactivity.
        comparison_window = base_window
        reference = cached_base(
            comparison_window, seed, grid_n_paths, lightweight=False
        )
        grid_rows: list[dict[str, Any]] = []
        proposed_row: dict[str, Any] | None = None
        proposed = float(plan_row.get("proposed_risk_percent") or candidate.risk_percent)
        weights = sorted(set(float(value) for value in (*weight_grid, proposed)))
        for weight in weights:
            variant_spec = replace(candidate, risk_percent=weight)
            variant = evaluate(
                [*base_specs, variant_spec], comparison_window, seed,
                grid_n_paths, lightweight=False,
            )
            item = {"risk_percent": weight, **_delta_row(reference, variant)}
            grid_rows.append(item)
            if abs(weight - proposed) <= 1e-12:
                proposed_row = item
        if proposed_row is None:
            raise AssertionError(f"{candidate_id}: proposed weight was not evaluated")
        proposed_spec = replace(candidate, risk_percent=proposed)
        proposed_row["resolution"] = resolution(
            base_specs, [*base_specs, proposed_spec], comparison_window,
            reference_is_base=True,
        )
        rows.append({
            "id": candidate_id, "mode": mode, "status": "OK",
            "role": candidate.role, "symbol": candidate.symbol,
            "stream_sha256": candidate.stream_sha256,
            "proposed_risk_percent": proposed,
            "comparison_window": [comparison_window[0].isoformat(), comparison_window[1].isoformat()],
            "proposed": proposed_row,
            "weight_grid": grid_rows,
        })
    return {
        "schema": MARGINAL_SCHEMA,
        "generated_at_utc": as_of.isoformat(),
        "method": (
            "all candidates and paired base references use the fixed base-book common "
            "window, identical seeds, block bootstrap, financing/cost model and "
            "first_passage engine; a short candidate cannot truncate incumbent history; "
            "deltas are variant-reference"
        ),
        "params": {"seed": seed, "n_paths": n_paths,
                   "weight_grid_n_paths": grid_n_paths, "block_len": block_len,
                   "horizon": horizon, "weight_grid": list(weight_grid),
                   "replicate_count": replicate_count,
                   "replicate_seeds": replicate_seeds,
                   "resolution_target_delta": resolution_target_delta,
                   "fixed_comparison_window": [
                       base_window[0].isoformat(), base_window[1].isoformat()
                   ],
                   "financing_label": financing_label},
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
        resolution = delta.get("resolution") or {}
        lcb = resolution.get(
            "lcb_delta_mean", delta.get("DELTA_P_FIRST_NET_FTMO_PAYOUT_LCB")
        )
        resolved = resolution.get("resolution_status") == "RESOLVED"
        daily = delta.get("DELTA_P_DAILY_LOSS_BREACH")
        maximum = delta.get("DELTA_P_MAX_LOSS_BREACH")
        if row.get("mode") == "leave_one_out":
            action = "KEEP" if lcb is not None and lcb >= 0.0 else "REVIEW_REMOVAL"
        else:
            if (
                lcb is not None and lcb > 0.0 and resolved
                and (daily is None or daily <= 0.0) and (maximum is None or maximum <= 0.0)
            ):
                action = "CONSIDER_ADD"
            elif lcb is not None and lcb > 0.0:
                action = "SHADOW_BOOK"
            else:
                action = "HOLD"
        out.append({
            "id": row.get("id"), "symbol": row.get("symbol"), "role": row.get("role"),
            "mode": row.get("mode"), "book_action": action,
            "proposed_risk_percent": row.get("proposed_risk_percent"),
            "marginal": {key: value for key, value in delta.items() if key.startswith("DELTA_")},
            "resolution": copy.deepcopy(resolution),
        })
    return out


def build_state(
    base: Mapping[str, Any], marginal: Mapping[str, Any], dependence: Mapping[str, Any], *,
    book_id: str, human_mirror: Path = DEFAULT_HUMAN_MIRROR,
    existing_state: Mapping[str, Any] | None = None,
    evidence_path: str | None = None,
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
    measured_candidates = _candidate_state_rows(marginal)
    existing_candidates = {
        str(row.get("id")): copy.deepcopy(row)
        for row in (existing_state or {}).get("candidates") or []
        if row.get("id") is not None
    }
    candidates = []
    for row in measured_candidates:
        merged = existing_candidates.get(str(row.get("id")), {})
        merged.update(row)
        candidates.append(merged)
    demo_cycle = copy.deepcopy((existing_state or {}).get("demo_cycle") or {})
    demo_cycle["state"] = demo_cycle.get("state", "UNMEASURED")
    demo_cycle["rule_headroom"] = {
        "daily_loss_headroom": f"{daily_headroom:.2f} USD (MAE proxy)",
        "max_loss_headroom": f"{max_headroom:.2f} USD (drawdown proxy)",
    }
    financing = copy.deepcopy((existing_state or {}).get("financing") or {})
    financing.update({
        "label": (base.get("financing") or {}).get("label", UNFINANCED),
        "source": (base.get("financing") or {}).get("source"),
        "stream_root": (base.get("financing") or {}).get("financed_stream_root"),
        "manifest": (base.get("financing") or {}).get("manifest"),
        "manifest_sha256": (base.get("financing") or {}).get("manifest_sha256"),
        "book_evidence_eligible": (base.get("financing") or {}).get(
            "book_evidence_eligible", False
        ),
        "swap_usd_window": metrics.get("BOOK_COST_DRAG", {}).get("swap_usd"),
        "commission_usd_window": metrics.get("BOOK_COST_DRAG", {}).get(
            "commission_usd"
        ),
    })
    if evidence_path:
        financing["evidence"] = evidence_path
    state = copy.deepcopy(existing_state or {})
    state.update({
        "schema": STATE_SCHEMA,
        "generated_at_utc": base.get("generated_at_utc"),
        "author": "Codex account-level simulator v2 financed-confidence run",
        "decision": "OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921",
        "book_id": book_id,
        "book_risk_percent": round(sum(float(s["risk_percent"]) for s in sleeves), 6),
        "account": {"product": "FTMO Challenge 2-Step", "size_usd": 100000},
        "sleeves": sleeves,
        "candidates": candidates,
        "financing": financing,
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
        "demo_cycle": demo_cycle,
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
    })
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
    parser.add_argument(
        "--financed-streams", type=Path,
        help="root containing qm_financing-bound q08 trade JSONL files",
    )
    parser.add_argument(
        "--financing-manifest", type=Path,
        help="optional manifest/provenance document for --financed-streams",
    )
    parser.add_argument(
        "--allow-unfinanced", action="store_true",
        help="explicit research-only opt-in; output is labelled UNFINANCED",
    )
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
    parser.add_argument(
        "--marginal-n-paths", type=int, default=DEFAULT_MARGINAL_PATHS
    )
    parser.add_argument(
        "--marginal-grid-n-paths", type=int,
        default=DEFAULT_MARGINAL_GRID_PATHS,
        help="paths for exploratory weight-grid rows; resolution uses --marginal-n-paths",
    )
    parser.add_argument(
        "--marginal-replicates", type=int, default=DEFAULT_MARGINAL_REPLICATES
    )
    parser.add_argument(
        "--resolution-target-delta", type=float,
        default=DEFAULT_RESOLUTION_TARGET,
    )
    parser.add_argument("--seed", type=int, default=20260921)
    parser.add_argument("--block-len", type=int, default=20)
    parser.add_argument("--horizon", type=int, default=756)
    parser.add_argument("--marginal-horizon", type=int, default=504)
    parser.add_argument("--as-of")
    parser.add_argument("--book-id")
    args = parser.parse_args(argv)
    if args.financed_streams is not None and args.allow_unfinanced:
        parser.error("--financed-streams and --allow-unfinanced are mutually exclusive")
    if args.financed_streams is None and not args.allow_unfinanced:
        parser.error(
            "book evidence is financing-fail-closed: provide --financed-streams "
            "or explicitly select research-only --allow-unfinanced"
        )
    financing_label = FINANCED if args.financed_streams is not None else UNFINANCED

    as_of = _parse_as_of(args.as_of)
    cost = CostConfig(args.spread_bps_rt, args.slippage_usd_per_lot_rt, args.margin_rate)
    roster_payload, specs = load_roster_specs(
        args.roster, stream_root=args.stream_root, stream_manifest=args.stream_manifest,
        require_sha=True, financed_stream_root=args.financed_streams,
    )
    base, sleeves, dependence = evaluate_book(
        specs, cost=cost, financing_label=financing_label,
        financed_stream_root=args.financed_streams,
        financing_manifest_path=args.financing_manifest,
        n_paths=args.n_paths, seed=args.seed,
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
            financing_label=financing_label,
            financed_stream_root=args.financed_streams,
            financing_manifest_path=args.financing_manifest,
            n_paths=args.marginal_n_paths, seed=args.seed,
            grid_n_paths=args.marginal_grid_n_paths,
            replicate_count=args.marginal_replicates,
            resolution_target_delta=args.resolution_target_delta,
            block_len=args.block_len, horizon=args.marginal_horizon, as_of=as_of,
        )
    else:
        marginal = {"schema": MARGINAL_SCHEMA, "generated_at_utc": as_of.isoformat(),
                    "status": "NOT_REQUESTED", "candidates": []}
    if args.marginal_out:
        _write_json(args.marginal_out, marginal)

    if args.state_out:
        existing = _load_existing_state(args.state_out)
        try:
            evidence_path = args.out.parent.resolve().relative_to(REPO_ROOT)
            evidence_path_text = evidence_path.as_posix()
        except ValueError:
            evidence_path_text = str(args.out.parent.resolve())
        state = build_state(
            base, marginal, dependence,
            book_id=str(args.book_id or roster_payload.get("cycle_id") or roster_payload.get("label") or "FTMO_BOOK"),
            human_mirror=args.human_mirror, existing_state=existing,
            evidence_path=evidence_path_text,
        )
        _write_json(args.state_out, state)

    metrics = base["book_metrics"]
    probs = base["first_passage"].get("probabilities") or {}
    top = (dependence.get("summary") or {}).get("top_fail_together_pair") or {}
    print(json.dumps({
        "status": "OK", "out": str(args.out),
        "financing": financing_label,
        "BOOK_R_PER_DAY": metrics.get("BOOK_R_PER_DAY"),
        "BOOK_TRADES_PER_DAY": metrics.get("BOOK_TRADES_PER_DAY"),
        "P_FIRST_NET_FTMO_PAYOUT_LCB": probs.get("P_FIRST_NET_FTMO_PAYOUT_LCB"),
        "top_fail_together_pair": top.get("pair"),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
