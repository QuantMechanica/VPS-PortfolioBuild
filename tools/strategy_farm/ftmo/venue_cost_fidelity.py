#!/usr/bin/env python3
"""Measure FTMO/Darwinex M1 spreads without inventing missing venue costs.

FTMO history is read from an already-running, exact-path demo terminal.  The
guard refuses to launch a terminal and refuses T_Live/T1-T10 executables.
Darwinex inputs are immutable MQL5 CopyRates JSONL snapshots.  An additive
simulator delta is emitted only for exact timestamp overlap; independent-period
quantiles remain descriptive and can never become a charge.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np


SCHEMA = "qm.ftmo-venue-cost-fidelity/v1"
DEFAULT_EXE = Path(r"C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe")
TARGETS = ("USDJPY", "GBPUSD", "XAUUSD", "USDCAD", "EURUSD")


class VenueCostError(ValueError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _running_processes(executable: Path) -> set[int]:
    try:
        import psutil
    except ImportError as exc:  # pragma: no cover - environment dependency
        raise VenueCostError("psutil_required_for_no_start_guard") from exc
    expected = os.path.normcase(str(executable.resolve()))
    result: set[int] = set()
    for process in psutil.process_iter(["pid", "exe"]):
        try:
            actual = process.info.get("exe")
            if actual and os.path.normcase(str(Path(actual).resolve())) == expected:
                result.add(int(process.info["pid"]))
        except (OSError, psutil.Error):
            continue
    return result


def _assert_allowed_terminal(executable: Path) -> Path:
    resolved = executable.resolve()
    forbidden = [Path(r"C:\QM\mt5\T_Live")] + [Path(f"D:/QM/mt5/T{i}") for i in range(1, 11)]
    if any(root.resolve() == resolved or root.resolve() in resolved.parents for root in forbidden):
        raise VenueCostError(f"forbidden_terminal:{resolved}")
    if not _running_processes(resolved):
        raise VenueCostError(f"terminal_not_already_running_refusing_initialize:{resolved}")
    return resolved


def _percentiles(values: Sequence[float]) -> dict[str, float | None]:
    if not values:
        return {"p50": None, "p75": None, "p90": None}
    array = np.asarray(values, dtype=float)
    return {
        "p50": round(float(np.percentile(array, 50)), 8),
        "p75": round(float(np.percentile(array, 75)), 8),
        "p90": round(float(np.percentile(array, 90)), 8),
    }


def _summarize(rows: Mapping[int, float]) -> dict[str, Any]:
    if not rows:
        return {"status": "UNMEASURED", "row_count": 0, "by_utc_hour": {}}
    ordered = sorted(rows)
    hourly: dict[str, Any] = {}
    for hour in range(24):
        values = [rows[stamp] for stamp in ordered if dt.datetime.fromtimestamp(stamp, dt.timezone.utc).hour == hour]
        hourly[f"{hour:02d}"] = {"row_count": len(values), **_percentiles(values)}
    return {
        "status": "MEASURED",
        "row_count": len(rows),
        "first_minute_utc": dt.datetime.fromtimestamp(ordered[0], dt.timezone.utc).isoformat(),
        "last_minute_utc": dt.datetime.fromtimestamp(ordered[-1], dt.timezone.utc).isoformat(),
        "spread_bps": _percentiles(list(rows.values())),
        "by_utc_hour": hourly,
        "rollover_21_23z": {
            hour: hourly[hour] for hour in ("21", "22", "23")
        },
    }


def _parse_time(value: Any) -> int:
    if isinstance(value, (int, float)):
        return int(value) // 60 * 60
    parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise VenueCostError("source timestamp must carry timezone")
    return int(parsed.timestamp()) // 60 * 60


def _normalize_server_minutes(
    rows_by_symbol: Mapping[str, Mapping[int, float]], observed_utc_epoch: int
) -> tuple[dict[str, dict[int, float]], dict[str, Any]]:
    """Infer a whole-hour live broker offset and convert its wall clock to UTC."""
    latest = [max(rows) for rows in rows_by_symbol.values() if rows]
    if len(latest) != len(rows_by_symbol):
        raise VenueCostError("cannot infer server offset from an empty symbol history")
    offsets = [round((stamp - observed_utc_epoch) / 3600.0) for stamp in latest]
    offset = int(round(float(np.median(np.asarray(offsets, dtype=float)))))
    if offset < -12 or offset > 14 or any(abs(item - offset) > 1 for item in offsets):
        raise VenueCostError(f"inconsistent_ftmo_server_offset_candidates:{offsets}")
    normalized = {
        symbol: {stamp - offset * 3600: value for stamp, value in rows.items()}
        for symbol, rows in rows_by_symbol.items()
    }
    lags = [observed_utc_epoch - (stamp - offset * 3600) for stamp in latest]
    # This live inference is deliberately unavailable on a stale/closed market.
    # A large lag could make a whole-hour guess ambiguous.
    if min(lags) < -300 or max(lags) > 900:
        raise VenueCostError(
            f"ftmo_server_offset_inference_not_live:offset={offset}:lags={lags}"
        )
    return normalized, {
        "method": "nearest whole-hour offset from each symbol's latest M1 bar to query wall-clock UTC",
        "server_minus_utc_hours": offset,
        "latest_bar_lag_seconds_after_normalization": dict(zip(rows_by_symbol, lags)),
        "status": "PASS_LIVE_OFFSET_INFERENCE",
    }


def load_dwx_raw(path: Path, point_size: float) -> tuple[dict[int, float], dict[str, Any]]:
    rows: dict[int, float] = {}
    with path.open("r", encoding="utf-8", errors="strict") as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            row = json.loads(line)
            stamp = _parse_time(row.get("ts", row.get("time")))
            close = float(row["close"])
            spread = float(row.get("spread", row.get("spread_points")))
            if not math.isfinite(close) or close <= 0 or not math.isfinite(spread) or spread < 0:
                raise VenueCostError(f"{path}:{number}: invalid close/spread")
            if stamp in rows:
                raise VenueCostError(f"{path}:{number}: duplicate minute")
            rows[stamp] = spread * point_size / close * 10000.0
    if not rows:
        raise VenueCostError(f"empty Darwinex source: {path}")
    return rows, {
        "mode": "MQL5_COPYRATES_PERIOD_M1_SPREAD_SNAPSHOT",
        "path": str(path.resolve()),
        "sha256": sha256_file(path),
        "size_bytes": path.stat().st_size,
        "point_size": point_size,
    }


def query_running_ftmo(
    executable: Path,
    *,
    symbols: Sequence[str],
    bars: int,
    expected_server: str,
    expected_login_last3: str,
) -> tuple[dict[str, dict[int, float]], dict[str, Any]]:
    resolved = _assert_allowed_terminal(executable)
    before = _running_processes(resolved)
    try:
        import MetaTrader5 as mt5
    except ImportError as exc:  # pragma: no cover - environment dependency
        raise VenueCostError("MetaTrader5_package_missing") from exc
    if not mt5.initialize(path=str(resolved), timeout=10_000, portable=False):
        raise VenueCostError(f"mt5_readonly_initialize_failed:{mt5.last_error()}")
    try:
        after = _running_processes(resolved)
        if not before.intersection(after):
            raise VenueCostError("terminal_process_identity_changed_during_attach")
        account = mt5.account_info()
        if account is None:
            raise VenueCostError(f"mt5_account_info_failed:{mt5.last_error()}")
        login = str(account.login)
        if account.server != expected_server or not login.endswith(expected_login_last3):
            raise VenueCostError(
                f"mt5_account_identity_mismatch:server={account.server}:login_last3={login[-3:]}"
            )
        result: dict[str, dict[int, float]] = {}
        symbol_meta: dict[str, Any] = {}
        hash_rows: list[tuple[Any, ...]] = []
        for symbol in symbols:
            info = mt5.symbol_info(symbol)
            if info is None or float(info.point) <= 0:
                raise VenueCostError(f"symbol_info_failed:{symbol}:{mt5.last_error()}")
            rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, bars)
            if rates is None or len(rates) == 0:
                raise VenueCostError(f"copy_rates_failed:{symbol}:{mt5.last_error()}")
            measured: dict[int, float] = {}
            for row in rates:
                stamp = int(row["time"]) // 60 * 60
                close = float(row["close"])
                spread = float(row["spread"])
                if close <= 0 or spread < 0:
                    raise VenueCostError(f"invalid_ftmo_rate:{symbol}:{stamp}")
                measured[stamp] = spread * float(info.point) / close * 10000.0
                hash_rows.append((symbol, stamp, close, spread, float(info.point)))
            result[symbol] = measured
            symbol_meta[symbol] = {
                "point_size": float(info.point),
                "digits": int(info.digits),
                "rows": len(measured),
            }
        observed = dt.datetime.now().astimezone(dt.timezone.utc).replace(microsecond=0)
        normalized, clock = _normalize_server_minutes(result, int(observed.timestamp()))
        canonical = json.dumps(hash_rows, separators=(",", ":"), ensure_ascii=True).encode()
        return normalized, {
            "mode": "RUNNING_MT5_READ_ONLY_COPYRATES_M1",
            "queried_at_utc": observed.isoformat().replace("+00:00", "Z"),
            "terminal_executable": str(resolved),
            "preexisting_process_ids": sorted(before),
            "account_login_masked": "*" * max(0, len(login) - 3) + login[-3:],
            "server": account.server,
            "requested_bars_per_symbol": bars,
            "query_sha256": hashlib.sha256(canonical).hexdigest(),
            "clock_normalization": clock,
            "symbols": symbol_meta,
            "autotrading_touched": False,
            "orders_sent": 0,
        }
    finally:
        mt5.shutdown()


def build(
    *,
    ftmo_rows: Mapping[str, Mapping[int, float]],
    ftmo_source: Mapping[str, Any],
    dxz_sources: Mapping[str, tuple[Mapping[int, float], Mapping[str, Any]]],
    generated_at: dt.datetime,
) -> tuple[dict[str, Any], dict[str, float]]:
    symbols: list[dict[str, Any]] = []
    eligible: dict[str, float] = {}
    for symbol in TARGETS:
        ftmo = dict(ftmo_rows.get(symbol) or {})
        dxz_pair = dxz_sources.get(symbol)
        dxz = dict(dxz_pair[0]) if dxz_pair else {}
        common = sorted(set(ftmo).intersection(dxz))
        comparison: dict[str, Any] = {
            "matched_minute_count": len(common),
            "minimum_required": 60,
            "charge_rule": "max(0, p90(FTMO_bps - DXZ_bps)) on exact matched minutes",
        }
        if len(common) >= 60:
            deltas = [ftmo[stamp] - dxz[stamp] for stamp in common]
            charge = max(0.0, float(np.percentile(np.asarray(deltas), 90)))
            comparison.update({
                "status": "PASS_MATCHED_MINUTES",
                "matched_delta_bps": _percentiles(deltas),
                "additional_spread_bps_rt": round(charge, 8),
            })
            eligible[f"{symbol}.DWX"] = round(charge, 8)
        else:
            ftmo_p90 = (_summarize(ftmo).get("spread_bps") or {}).get("p90")
            dxz_p90 = (_summarize(dxz).get("spread_bps") or {}).get("p90")
            comparison.update({
                "status": "ABSTAIN_NO_MATCHED_DXZ_MINUTES" if dxz else "ABSTAIN_DXZ_SPREAD_UNMEASURED",
                "additional_spread_bps_rt": None,
                "descriptive_independent_period_p90_difference_bps": (
                    round(float(ftmo_p90) - float(dxz_p90), 8)
                    if ftmo_p90 is not None and dxz_p90 is not None else None
                ),
                "descriptive_difference_is_not_charge_eligible": True,
            })
        symbols.append({
            "symbol": symbol,
            "ftmo": {"source": ftmo_source, "measurement": _summarize(ftmo)},
            "darwinex": {
                "source": dict(dxz_pair[1]) if dxz_pair else None,
                "measurement": _summarize(dxz),
            },
            "comparison": comparison,
            "slippage": {
                "status": "UNMEASURED",
                "usd_per_lot_rt": None,
                "reason": "No request-price-to-fill-price evidence exists in the collector or frozen Q08 rows.",
            },
        })
    result = {
        "schema": SCHEMA,
        "generated_at_utc": generated_at.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "status": "PASS" if len(eligible) == len(TARGETS) else "PARTIAL_ABSTAIN",
        "method": {
            "unit": "round-trip additive bps; one quoted spread is the full open-to-close spread burden",
            "anti_double_charge": "Only an exact-minute FTMO-minus-Darwinex delta is eligible; Q08 profit already embeds Darwinex execution.",
            "quantiles": ["p50", "p75", "p90"],
            "session_bucket": "UTC hour; 21Z, 22Z and 23Z are repeated under rollover_21_23z",
        },
        "symbols": symbols,
        "eligible_spread_bps_rt_by_symbol": eligible,
        "slippage_usd_per_lot_rt_by_symbol": {},
        "slippage_coverage": "UNMEASURED_ALL_SYMBOLS",
    }
    return result, eligible


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--spread-table-out", required=True, type=Path)
    parser.add_argument("--terminal-executable", type=Path, default=DEFAULT_EXE)
    parser.add_argument("--expected-server", default="FTMO-Demo")
    parser.add_argument("--expected-login-last3", default="732")
    parser.add_argument("--bars", type=int, default=100000)
    parser.add_argument("--as-of")
    args = parser.parse_args(argv)
    if args.bars < 60:
        parser.error("--bars must be >= 60")
    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    configured = spec.get("symbols") or {}
    if set(configured) != set(TARGETS):
        parser.error(f"spec symbols must be exactly {list(TARGETS)}")
    ftmo_rows, ftmo_source = query_running_ftmo(
        args.terminal_executable,
        symbols=TARGETS,
        bars=args.bars,
        expected_server=args.expected_server,
        expected_login_last3=args.expected_login_last3,
    )
    dxz_sources: dict[str, tuple[Mapping[int, float], Mapping[str, Any]]] = {}
    for symbol, row in configured.items():
        path_value = row.get("dxz_raw_path")
        if not path_value:
            continue
        path = Path(path_value)
        dxz_sources[symbol] = load_dwx_raw(path, float(row["dxz_point_size"]))
    generated = (
        dt.datetime.fromisoformat(args.as_of.replace("Z", "+00:00"))
        if args.as_of else dt.datetime.now(dt.timezone.utc)
    )
    result, table = build(
        ftmo_rows=ftmo_rows,
        ftmo_source=ftmo_source,
        dxz_sources=dxz_sources,
        generated_at=generated,
    )
    result["spec"] = {
        "path": str(args.spec.resolve()),
        "sha256": sha256_file(args.spec),
    }
    _write_json(args.out, result)
    _write_json(args.spread_table_out, table)
    print(json.dumps({
        "status": result["status"],
        "eligible_symbols": sorted(table),
        "out": str(args.out),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
