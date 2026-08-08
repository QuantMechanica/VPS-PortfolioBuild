#!/usr/bin/env python3
"""Fail-closed FTMO/DXZ M1 spread-harvest orchestrator.

The module has two deliberately separate execution modes:

* ``ftmo`` launches exactly one registered FTMO research lane and harvests the
  native symbol assigned to that lane.  The other FTMO lane must be idle and
  the OWNER challenge terminal must remain the same observed process.
* ``dxz`` reserves one genuinely free T1-T10 slot, harvests both custom-symbol
  comparators, and releases only its own reservation.

Both modes compile and run the read-only ``QM_M1_SpreadHarvest`` script.  They
never change terminal trading settings, never signal T_Live or the Program
Files challenge terminal, and never emit a Q-pipeline verdict.  Raw OHLC rows
are validated and projected into the existing strict spread-calibration row
schema before publication to the paths named by the reviewed spec.
"""

from __future__ import annotations

import argparse
import base64
import contextlib
import datetime as dt
import hashlib
import json
import math
import ntpath
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any, Iterator, Mapping, Sequence


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_SOURCE = REPO_ROOT / "framework/scripts/mt5_diagnostics/QM_M1_SpreadHarvest.mq5"
SPEC_PATH = REPO_ROOT / "docs/ops/evidence/2026-08-02_ftmo_spread_calibration_spec.json"
FARM_ROOT = Path("D:/QM/strategy_farm")
FARM_DB = FARM_ROOT / "state/farm_state.sqlite"
REPORT_ROOT = Path("D:/QM/reports/ftmo_spread_calibration")
LOCK_PATH = FARM_ROOT / "state/ftmo_m1_bootstrap.lock"
MT5_ROOT = Path("D:/QM/mt5")
CHALLENGE_TERMINAL = Path(
    "C:/Program Files/FTMO Global Markets MT5 Terminal/terminal64.exe"
)

LANE_ROOTS: dict[str, Path] = {
    "FTMO_STREAM1": Path("D:/QM/mt5/FTMO_STREAM1"),
    "FTMO_STREAM2": Path("D:/QM/mt5/FTMO_STREAM2"),
}
LANE_SYMBOLS = {
    "FTMO_STREAM1": "XAUUSD",
    "FTMO_STREAM2": "GER40.cash",
}
# Shared demo account both lanes bind (provision receipts 2026-08-03); the
# password lives only in each lane's Config/accounts.dat.
FTMO_DEMO_LOGIN = "1514165262"
FTMO_DEMO_SERVER = "FTMO-Demo"
# The factory-terminal market-data login stays OUT of the repo: it is read
# from this VPS-local untracked file ({"login": "...", "server": "..."}).
# Without it the dxz chart cannot initialize (account-less /config start,
# proven live 2026-08-08) and the run refuses.
DXZ_FACTORY_LOGIN_FILE = Path("D:/QM/strategy_farm/state/dxz_factory_login.json")


def load_dxz_factory_login() -> tuple[str, str]:
    if not DXZ_FACTORY_LOGIN_FILE.is_file():
        raise BootstrapError(
            f"dxz factory login file is absent: {DXZ_FACTORY_LOGIN_FILE}"
        )
    value = load_json(DXZ_FACTORY_LOGIN_FILE, "dxz factory login")
    login = str(value.get("login") or "").strip()
    server = str(value.get("server") or "").strip()
    if not login.isdigit() or not server:
        raise BootstrapError("dxz factory login file must bind login and server")
    return login, server
SYMBOL_LANES = {symbol: lane for lane, symbol in LANE_SYMBOLS.items()}
DXZ_SYMBOLS = ("XAUUSD.DWX", "GDAXI.DWX")
FACTORY_TERMINALS = tuple(f"T{index}" for index in range(1, 11))

HISTORY_OBSERVATION_SCHEMA = "qm.ftmo-history-coverage/v1"
BOOTSTRAP_RECEIPT_SCHEMA = "qm.ftmo-m1-bootstrap-receipt/v1"
HARVEST_COVERAGE_SCHEMA = "qm.m1-spread-harvest-coverage/v1"
HARVEST_EVIDENCE_SCHEMA = "qm.m1-spread-harvest-evidence/v1"
CALIBRATION_SPEC_SCHEMA = "qm.ftmo-spread-calibration-spec/v1"
CALIBRATION_ROW_SCHEMA = "qm.m1-spread-row/v1"
EXTRACTION_METHOD = "MQL5_COPYRATES_PERIOD_M1_SPREAD"

RAW_ROW_FIELDS = {"ts", "open", "high", "low", "close", "tick_volume", "spread"}
COVERAGE_FIELDS = {
    "schema",
    "status",
    "extraction_method",
    "output_tag",
    "symbol",
    "first_bar",
    "last_bar",
    "bar_count",
    "depth_days",
    "tick_first",
    "tick_last",
}
FORBIDDEN_MQL_TOKENS = (
    r"\bOrderSend\s*\(",
    r"\bOrderSendAsync\s*\(",
    r"\bPositionOpen\s*\(",
    r"\bPositionClose\s*\(",
    r"\bBuy\s*\(",
    r"\bSell\s*\(",
    r"CTrade",
    r"Trade\\Trade\.mqh",
)
TAG_RE = re.compile(r"^[A-Za-z0-9_-]{1,96}$")


class BootstrapError(ValueError):
    """The requested bootstrap operation cannot be proved safe or complete."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        indent=2,
        sort_keys=True,
    ) + "\n"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise BootstrapError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def file_binding(path: Path) -> dict[str, Any]:
    resolved = path.expanduser().resolve()
    if not resolved.is_file():
        raise BootstrapError(f"required file is absent: {resolved}")
    return {
        "path": str(resolved),
        "size_bytes": resolved.stat().st_size,
        "sha256": sha256_file(resolved),
    }


def _strict_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise BootstrapError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def strict_json_loads(raw: str | bytes, label: str) -> Any:
    def reject_constant(value: str) -> None:
        raise BootstrapError(f"{label}: non-finite JSON constant {value}")

    try:
        return json.loads(
            raw,
            object_pairs_hook=_strict_pairs,
            parse_constant=reject_constant,
        )
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise BootstrapError(f"{label}: invalid JSON: {exc}") from exc


def load_json(path: Path, label: str) -> Any:
    try:
        return strict_json_loads(path.read_bytes(), label)
    except OSError as exc:
        raise BootstrapError(f"{label}: cannot read {path}: {exc}") from exc


def atomic_write_text(path: Path, text: str, *, replace: bool = False) -> None:
    target = path.expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and not replace:
        raise BootstrapError(f"refusing to replace existing artifact: {target}")
    descriptor, temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=str(target.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, target)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def atomic_write_json(path: Path, value: Any, *, replace: bool = False) -> None:
    atomic_write_text(path, canonical_json(value), replace=replace)


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.expanduser().resolve().relative_to(root.expanduser().resolve())
    except ValueError:
        return False
    return True


def _reject_sensitive_evidence_path(path: Path, label: str) -> Path:
    resolved = path.expanduser().resolve()
    lowered = _windows_path_key(resolved)
    if "\\t_live\\" in lowered or "\\appdata\\" in lowered:
        raise BootstrapError(f"{label}: T_Live/AppData evidence paths are forbidden")
    return resolved


def _windows_path_key(value: str | Path) -> str:
    return ntpath.normcase(ntpath.normpath(str(value).replace("/", "\\")))


def _safe_tag(value: str) -> str:
    tag = str(value).strip()
    if not TAG_RE.fullmatch(tag):
        raise BootstrapError("output tag must match [A-Za-z0-9_-]{1,96}")
    return tag


def _symbol_token(symbol: str) -> str:
    token = symbol.replace(".", "_").replace("-", "_")
    if not TAG_RE.fullmatch(token):
        raise BootstrapError(f"symbol cannot form a safe harvest filename: {symbol!r}")
    return token


def _parse_utc_minute(value: Any, label: str) -> dt.datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise BootstrapError(f"{label}: expected explicit UTC minute ending Z")
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise BootstrapError(f"{label}: invalid timestamp") from exc
    if parsed.second or parsed.microsecond or parsed.utcoffset() != dt.timedelta(0):
        raise BootstrapError(f"{label}: expected exact UTC minute")
    return parsed.astimezone(dt.UTC)


def _finite_number(value: Any, label: str) -> float:
    if isinstance(value, bool):
        raise BootstrapError(f"{label}: boolean is not numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise BootstrapError(f"{label}: expected finite number") from exc
    if not math.isfinite(number):
        raise BootstrapError(f"{label}: expected finite number")
    return number


def validate_mql_source(path: Path = SCRIPT_SOURCE) -> dict[str, Any]:
    binding = file_binding(path)
    try:
        source = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        raise BootstrapError(f"cannot read MQL5 script: {exc}") from exc
    required = (
        "input string InpSymbols",
        "input string InpOutputTag",
        "SymbolSelect(",
        "CopyRates(",
        "CopyTicksRange(",
        "QM\\\\m1_harvest",
        EXTRACTION_METHOD,
        "4401",
        "4403",
    )
    missing = [token for token in required if token not in source]
    if missing:
        raise BootstrapError(f"MQL5 harvest script is missing required tokens: {missing}")
    forbidden = [pattern for pattern in FORBIDDEN_MQL_TOKENS if re.search(pattern, source)]
    if forbidden:
        raise BootstrapError(f"MQL5 harvest script contains trading-capable tokens: {forbidden}")
    return {
        **binding,
        "read_only_static_check": "PASS",
        "forbidden_trading_tokens": [],
    }


def load_calibration_targets(spec_path: Path = SPEC_PATH) -> dict[tuple[str, str], dict[str, Any]]:
    spec = load_json(spec_path.expanduser().resolve(), "spread_calibration_spec")
    if not isinstance(spec, Mapping) or spec.get("schema") != CALIBRATION_SPEC_SCHEMA:
        raise BootstrapError("spread calibration spec has an unsupported schema")
    pairs = spec.get("pairs")
    if not isinstance(pairs, list) or not pairs:
        raise BootstrapError("spread calibration spec has no pairs")
    targets: dict[tuple[str, str], dict[str, Any]] = {}
    for index, pair in enumerate(pairs):
        if not isinstance(pair, Mapping):
            raise BootstrapError(f"spread calibration pair {index} is malformed")
        for side in ("ftmo", "dxz"):
            source = pair.get(side)
            venue = side.upper()
            if not isinstance(source, Mapping) or source.get("venue") != venue:
                raise BootstrapError(f"spread calibration pair {index}.{side} is malformed")
            symbol = source.get("symbol")
            if not isinstance(symbol, str) or not symbol:
                raise BootstrapError(f"spread calibration pair {index}.{side} has no symbol")
            if source.get("extraction_method") != EXTRACTION_METHOD:
                raise BootstrapError(f"spread calibration pair {index}.{side} changed extraction method")
            projection = Path(str(source.get("m1_spread_path", ""))).expanduser().resolve()
            if not _is_within(projection, REPORT_ROOT):
                raise BootstrapError(f"spread projection escaped the reviewed report root: {projection}")
            hcc_values = source.get("source_hcc_paths")
            if not isinstance(hcc_values, list) or not hcc_values:
                raise BootstrapError(f"spread calibration pair {index}.{side} has no HCC binding")
            hcc_paths = tuple(Path(str(value)).expanduser().resolve() for value in hcc_values)
            if any(path.suffix.lower() != ".hcc" for path in hcc_paths):
                raise BootstrapError(f"spread calibration pair {index}.{side} has a non-HCC source")
            key = (venue, symbol)
            if key in targets:
                raise BootstrapError(f"duplicate spread target: {venue}/{symbol}")
            targets[key] = {
                "venue": venue,
                "symbol": symbol,
                "projection_path": projection,
                "hcc_paths": hcc_paths,
                "evaluator_symbol": pair.get("evaluator_symbol"),
            }
    return targets


def local_harvest_paths(terminal_root: Path, output_tag: str, symbol: str) -> tuple[Path, Path]:
    tag = _safe_tag(output_tag)
    token = _symbol_token(symbol)
    base = terminal_root.expanduser().resolve() / "MQL5/Files/QM/m1_harvest"
    return base / f"{tag}_{token}_M1.jsonl", base / f"{tag}_{token}_coverage.json"


def _validate_coverage(
    value: Any,
    *,
    symbol: str,
    output_tag: str,
    row_count: int,
    first: dt.datetime,
    last: dt.datetime,
) -> dict[str, Any]:
    if not isinstance(value, Mapping) or set(value) != COVERAGE_FIELDS:
        raise BootstrapError("harvest coverage has unexpected fields")
    if value.get("schema") != HARVEST_COVERAGE_SCHEMA or value.get("status") != "COMPLETE":
        raise BootstrapError("harvest coverage is not a COMPLETE supported artifact")
    if value.get("extraction_method") != EXTRACTION_METHOD:
        raise BootstrapError("harvest coverage changed extraction method")
    if value.get("output_tag") != output_tag or value.get("symbol") != symbol:
        raise BootstrapError("harvest coverage tag/symbol mismatch")
    if isinstance(value.get("bar_count"), bool) or value.get("bar_count") != row_count:
        raise BootstrapError("harvest coverage bar_count does not match raw rows")
    coverage_first = _parse_utc_minute(value.get("first_bar"), "coverage.first_bar")
    coverage_last = _parse_utc_minute(value.get("last_bar"), "coverage.last_bar")
    if coverage_first != first or coverage_last != last:
        raise BootstrapError("harvest coverage first/last bar does not match raw rows")
    depth_days = _finite_number(value.get("depth_days"), "coverage.depth_days")
    expected_depth = (last - first).total_seconds() / 86400.0
    if depth_days < 0 or abs(depth_days - expected_depth) > 0.0000011:
        raise BootstrapError("harvest coverage depth_days does not match first/last bar")
    tick_first_raw = value.get("tick_first")
    tick_last_raw = value.get("tick_last")
    if (tick_first_raw is None) != (tick_last_raw is None):
        raise BootstrapError("harvest coverage must bind both tick endpoints or neither")
    tick_first = _parse_utc_minute(tick_first_raw, "coverage.tick_first") if tick_first_raw else None
    tick_last = _parse_utc_minute(tick_last_raw, "coverage.tick_last") if tick_last_raw else None
    if tick_first is not None and tick_last is not None and tick_last < tick_first:
        raise BootstrapError("harvest tick window is reversed")
    return {
        "first_bar": first.isoformat().replace("+00:00", "Z"),
        "last_bar": last.isoformat().replace("+00:00", "Z"),
        "bar_count": row_count,
        "depth_days": depth_days,
        "tick_first": tick_first.isoformat().replace("+00:00", "Z") if tick_first else None,
        "tick_last": tick_last.isoformat().replace("+00:00", "Z") if tick_last else None,
    }


def project_raw_harvest(
    raw_path: Path,
    coverage_path: Path,
    projection_path: Path,
    *,
    symbol: str,
    venue: str,
    output_tag: str,
    replace: bool = False,
) -> dict[str, Any]:
    raw_path = raw_path.expanduser().resolve()
    coverage_path = coverage_path.expanduser().resolve()
    projection_path = projection_path.expanduser().resolve()
    if venue not in {"FTMO", "DXZ"}:
        raise BootstrapError("venue must be FTMO or DXZ")
    if not raw_path.is_file() or not coverage_path.is_file():
        raise BootstrapError("harvest completion requires both raw and coverage artifacts")
    projection_path.parent.mkdir(parents=True, exist_ok=True)
    if projection_path.exists() and not replace:
        raise BootstrapError(f"refusing to replace spread projection: {projection_path}")
    descriptor, temporary = tempfile.mkstemp(
        prefix=f".{projection_path.name}.", dir=str(projection_path.parent)
    )
    row_count = 0
    first: dt.datetime | None = None
    last: dt.datetime | None = None
    try:
        with raw_path.open("rb") as source, os.fdopen(
            descriptor, "w", encoding="utf-8", newline="\n"
        ) as destination:
            for line_number, raw in enumerate(source, 1):
                if not raw.strip():
                    raise BootstrapError(f"raw harvest line {line_number}: blank row")
                row = strict_json_loads(raw, f"raw harvest line {line_number}")
                if not isinstance(row, Mapping) or set(row) != RAW_ROW_FIELDS:
                    raise BootstrapError(f"raw harvest line {line_number}: unexpected fields")
                minute = _parse_utc_minute(row.get("ts"), f"raw harvest line {line_number}.ts")
                if last is not None and minute <= last:
                    raise BootstrapError(f"raw harvest line {line_number}: timestamps are not increasing")
                prices = {
                    field: _finite_number(row.get(field), f"raw harvest line {line_number}.{field}")
                    for field in ("open", "high", "low", "close")
                }
                if prices["high"] < max(prices["open"], prices["low"], prices["close"]):
                    raise BootstrapError(f"raw harvest line {line_number}: high is inconsistent")
                if prices["low"] > min(prices["open"], prices["high"], prices["close"]):
                    raise BootstrapError(f"raw harvest line {line_number}: low is inconsistent")
                tick_volume = row.get("tick_volume")
                spread = row.get("spread")
                if isinstance(tick_volume, bool) or not isinstance(tick_volume, int) or tick_volume < 0:
                    raise BootstrapError(f"raw harvest line {line_number}.tick_volume is invalid")
                if isinstance(spread, bool) or not isinstance(spread, int) or spread < 0:
                    raise BootstrapError(f"raw harvest line {line_number}.spread is invalid")
                projection = {
                    "schema": CALIBRATION_ROW_SCHEMA,
                    "symbol": symbol,
                    "venue": venue,
                    "time": minute.isoformat().replace("+00:00", "Z"),
                    "spread_points": spread,
                }
                destination.write(json.dumps(projection, separators=(",", ":"), sort_keys=True) + "\n")
                if first is None:
                    first = minute
                last = minute
                row_count += 1
            destination.flush()
            os.fsync(destination.fileno())
        if row_count <= 0 or first is None or last is None:
            raise BootstrapError("raw harvest is empty")
        coverage = _validate_coverage(
            load_json(coverage_path, "harvest_coverage"),
            symbol=symbol,
            output_tag=output_tag,
            row_count=row_count,
            first=first,
            last=last,
        )
        os.replace(temporary, projection_path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    return {
        "raw": file_binding(raw_path),
        "terminal_coverage": file_binding(coverage_path),
        "projection": file_binding(projection_path),
        "coverage": coverage,
        "extraction_method": EXTRACTION_METHOD,
    }


def _coverage_evidence_path(projection_path: Path) -> Path:
    stem = projection_path.stem
    if stem.endswith("_M1"):
        stem = stem[:-3]
    return projection_path.with_name(stem + "_coverage.json")


def publish_harvest(
    *,
    terminal_root: Path,
    terminal_name: str,
    output_tag: str,
    target: Mapping[str, Any],
    run_binding: Mapping[str, Any],
    replace: bool,
) -> dict[str, Any]:
    symbol = str(target["symbol"])
    venue = str(target["venue"])
    raw_path, coverage_path = local_harvest_paths(terminal_root, output_tag, symbol)
    hcc_paths = tuple(Path(path).resolve() for path in target["hcc_paths"])
    hcc_bindings = [file_binding(path) for path in hcc_paths]
    projection = project_raw_harvest(
        raw_path,
        coverage_path,
        Path(target["projection_path"]),
        symbol=symbol,
        venue=venue,
        output_tag=output_tag,
        replace=replace,
    )
    evidence = {
        "schema": HARVEST_EVIDENCE_SCHEMA,
        "status": "PASS",
        "created_at": utc_now(),
        "venue": venue,
        "symbol": symbol,
        "evaluator_symbol": target.get("evaluator_symbol"),
        "terminal": terminal_name,
        "terminal_root": str(terminal_root.expanduser().resolve()),
        "output_tag": output_tag,
        "extraction_method": EXTRACTION_METHOD,
        "coverage": projection["coverage"],
        "bindings": {
            "raw": projection["raw"],
            "terminal_coverage": projection["terminal_coverage"],
            "projection": projection["projection"],
            "source_hcc": hcc_bindings,
            "run": dict(run_binding),
        },
        "claims": {
            "q_pipeline_verdict": "NONE",
            "live_authority": "NONE",
            "autotrading_touched": False,
        },
    }
    evidence_path = _coverage_evidence_path(Path(target["projection_path"]))
    atomic_write_json(evidence_path, evidence, replace=replace)
    return {**evidence, "evidence": file_binding(evidence_path)}


def _validated_published_ftmo_coverage(path: Path, symbol: str) -> dict[str, Any]:
    value = load_json(path, f"published_{symbol}_coverage")
    if not isinstance(value, Mapping) or value.get("schema") != HARVEST_EVIDENCE_SCHEMA:
        raise BootstrapError(f"published {symbol} coverage has an unsupported schema")
    if value.get("status") != "PASS" or value.get("venue") != "FTMO" or value.get("symbol") != symbol:
        raise BootstrapError(f"published {symbol} coverage identity/status mismatch")
    if value.get("terminal") != SYMBOL_LANES[symbol]:
        raise BootstrapError(f"published {symbol} coverage came from the wrong FTMO lane")
    expected_root = LANE_ROOTS[SYMBOL_LANES[symbol]].resolve()
    if Path(str(value.get("terminal_root", ""))).resolve() != expected_root:
        raise BootstrapError(f"published {symbol} coverage has the wrong FTMO lane root")
    bindings = value.get("bindings")
    if not isinstance(bindings, Mapping):
        raise BootstrapError(f"published {symbol} coverage lacks bindings")
    for name in ("raw", "terminal_coverage", "projection"):
        binding = bindings.get(name)
        if not isinstance(binding, Mapping):
            raise BootstrapError(f"published {symbol} coverage lacks {name} binding")
        bound_path = _reject_sensitive_evidence_path(
            Path(str(binding.get("path", ""))), f"published {symbol}.{name}"
        )
        if sha256_file(bound_path) != binding.get("sha256"):
            raise BootstrapError(f"published {symbol} {name} binding drift")
    hcc = bindings.get("source_hcc")
    if not isinstance(hcc, list) or not hcc:
        raise BootstrapError(f"published {symbol} coverage lacks HCC binding")
    for binding in hcc:
        if not isinstance(binding, Mapping):
            raise BootstrapError(f"published {symbol} HCC binding malformed")
        bound_path = _reject_sensitive_evidence_path(
            Path(str(binding.get("path", ""))), f"published {symbol}.source_hcc"
        )
        if bound_path.suffix.lower() != ".hcc" or sha256_file(bound_path) != binding.get("sha256"):
            raise BootstrapError(f"published {symbol} HCC binding drift")
    coverage = value.get("coverage")
    if not isinstance(coverage, Mapping):
        raise BootstrapError(f"published {symbol} coverage payload missing")
    _parse_utc_minute(coverage.get("first_bar"), f"published {symbol}.first_bar")
    _parse_utc_minute(coverage.get("last_bar"), f"published {symbol}.last_bar")
    if (coverage.get("tick_first") is None) != (coverage.get("tick_last") is None):
        raise BootstrapError(f"published {symbol} tick coverage is incomplete")
    return dict(value)


def build_history_handoff(
    *,
    lane: str,
    observation_path: Path,
    report_root: Path = REPORT_ROOT,
) -> dict[str, Any]:
    if lane not in LANE_ROOTS:
        raise BootstrapError(f"unsupported FTMO lane: {lane}")
    symbols: dict[str, Any] = {}
    hold_reasons: list[str] = []
    source_bindings: dict[str, Any] = {}
    for symbol in ("XAUUSD", "GER40.cash"):
        target_name = "XAUUSD_FTMO_coverage.json" if symbol == "XAUUSD" else "GER40_cash_FTMO_coverage.json"
        path = report_root.expanduser().resolve() / target_name
        if not path.is_file():
            hold_reasons.append(f"MISSING_{symbol.replace('.', '_')}_FTMO_COVERAGE")
            continue
        evidence = _validated_published_ftmo_coverage(path, symbol)
        coverage = evidence["coverage"]
        source = file_binding(path)
        source_bindings[symbol] = source
        m1 = {
            "coverage_from": str(coverage["first_bar"])[:10],
            "coverage_to": str(coverage["last_bar"])[:10],
            "source_artifact": source["path"],
            "source_sha256": source["sha256"],
        }
        if coverage.get("tick_first") is None or coverage.get("tick_last") is None:
            hold_reasons.append(f"MISSING_{symbol.replace('.', '_')}_REAL_TICK_WINDOW")
            continue
        real_ticks = {
            "coverage_from": str(coverage["tick_first"])[:10],
            "coverage_to": str(coverage["tick_last"])[:10],
            "source_artifact": source["path"],
            "source_sha256": source["sha256"],
        }
        symbols[symbol] = {"real_ticks": real_ticks, "m1_bars": m1}

    if hold_reasons or set(symbols) != {"XAUUSD", "GER40.cash"}:
        return {
            "status": "HOLD_PARTIAL",
            "history_observation": None,
            "hold_reasons": sorted(set(hold_reasons)),
            "available_source_bindings": source_bindings,
            "runner_contract": "PARTIAL_COVERAGE_IS_NOT_PASSED_TO_ftmo_lane_runner._apply_history_observation",
        }
    observation = {
        "schema": HISTORY_OBSERVATION_SCHEMA,
        "lane": lane,
        "lane_root": str(LANE_ROOTS[lane].resolve()),
        "symbols": symbols,
    }
    atomic_write_json(observation_path, observation)
    return {
        "status": "READY",
        "history_observation": file_binding(observation_path),
        "hold_reasons": [],
        "available_source_bindings": source_bindings,
        "runner_contract": "EXACT_ftmo_lane_runner._apply_history_observation_SCHEMA",
    }


def _powershell_json(script: str, *, timeout: int = 20) -> Any:
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=timeout,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception as exc:
        raise BootstrapError(f"PowerShell process observation failed: {exc}") from exc
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        raise BootstrapError(f"PowerShell process observation failed ({result.returncode}): {detail}")
    if not (result.stdout or "").strip():
        return []
    return strict_json_loads(result.stdout, "PowerShell process observation")


def scan_terminal_processes() -> list[dict[str, Any]]:
    value = _powershell_json(
        "Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | "
        "Select-Object ProcessId,CreationDate,ExecutablePath,CommandLine | "
        "ConvertTo-Json -Depth 4 -Compress"
    )
    rows = value if isinstance(value, list) else [value]
    if not all(isinstance(row, Mapping) for row in rows):
        raise BootstrapError("terminal process scan returned malformed rows")
    return [dict(row) for row in rows]


def scan_metaeditor_processes() -> list[dict[str, Any]]:
    value = _powershell_json(
        "Get-CimInstance Win32_Process -Filter \"Name='MetaEditor64.exe'\" | "
        "Select-Object ProcessId,CreationDate,ExecutablePath,CommandLine | "
        "ConvertTo-Json -Depth 4 -Compress"
    )
    rows = value if isinstance(value, list) else [value]
    if not all(isinstance(row, Mapping) for row in rows):
        raise BootstrapError("MetaEditor process scan returned malformed rows")
    return [dict(row) for row in rows]


_WMI_JSON_DATE = re.compile(r"^/Date\((-?\d+)\)/$")


def _parse_creation_date(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise BootstrapError(f"{label}: missing CreationDate")
    text = value.strip()
    # Windows PowerShell 5.1 ConvertTo-Json serializes CIM DateTime as
    # /Date(<epoch_ms>)/ - accept it alongside ISO-8601 (pwsh 7 / tests).
    wmi = _WMI_JSON_DATE.match(text)
    if wmi is not None:
        parsed = dt.datetime.fromtimestamp(int(wmi.group(1)) / 1000.0, tz=dt.UTC)
        return parsed.isoformat(timespec="seconds").replace("+00:00", "Z")
    try:
        parsed = dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise BootstrapError(f"{label}: invalid CreationDate") from exc
    if parsed.tzinfo is None:
        raise BootstrapError(f"{label}: CreationDate lacks timezone")
    return parsed.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def process_identity(row: Mapping[str, Any], label: str) -> dict[str, Any]:
    try:
        pid = int(row.get("ProcessId"))
    except (TypeError, ValueError) as exc:
        raise BootstrapError(f"{label}: invalid process ID") from exc
    executable = str(row.get("ExecutablePath") or "").strip()
    if pid <= 0 or not executable:
        raise BootstrapError(f"{label}: process identity is incomplete")
    return {
        "pid": pid,
        "executable_path": str(Path(executable).resolve()),
        "creation_date_utc": _parse_creation_date(row.get("CreationDate"), label),
    }


def _terminal_class(executable_path: str | Path) -> tuple[str, str | None]:
    key = _windows_path_key(executable_path)
    if key == _windows_path_key(CHALLENGE_TERMINAL):
        return "challenge", None
    for lane, root in LANE_ROOTS.items():
        if key == _windows_path_key(root / "terminal64.exe"):
            return "ftmo_lane", lane
    for terminal in FACTORY_TERMINALS:
        direct = MT5_ROOT / terminal / "terminal64.exe"
        nested = MT5_ROOT / terminal / "MT5_Base/terminal64.exe"
        if key in {_windows_path_key(direct), _windows_path_key(nested)}:
            return "factory", terminal
    live_paths = (
        Path("C:/QM/mt5/T_Live/terminal64.exe"),
        Path("C:/QM/mt5/T_Live/MT5_Base/terminal64.exe"),
        MT5_ROOT / "T_Live/terminal64.exe",
        MT5_ROOT / "T_Live/MT5_Base/terminal64.exe",
    )
    if key in {_windows_path_key(path) for path in live_paths}:
        return "t_live", None
    return "unknown", None


def classified_terminal_snapshot(rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "challenge": [],
        "ftmo_lanes": {lane: [] for lane in LANE_ROOTS},
        "factory": {terminal: [] for terminal in FACTORY_TERMINALS},
        "t_live": [],
    }
    unknown: list[dict[str, Any]] = []
    for index, row in enumerate(rows):
        identity = process_identity(row, f"terminal process row {index}")
        kind, name = _terminal_class(identity["executable_path"])
        if kind == "challenge":
            result["challenge"].append(identity)
        elif kind == "ftmo_lane" and name:
            result["ftmo_lanes"][name].append(identity)
        elif kind == "factory" and name:
            result["factory"][name].append(identity)
        elif kind == "t_live":
            result["t_live"].append(identity)
        else:
            unknown.append(identity)
    if unknown:
        raise BootstrapError(f"factory-side process preconditions are unclear: {unknown}")
    return result


def assert_ftmo_preconditions(lane: str, rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    if lane not in LANE_ROOTS:
        raise BootstrapError(f"unsupported FTMO lane: {lane}")
    snapshot = classified_terminal_snapshot(rows)
    if len(snapshot["challenge"]) != 1:
        raise BootstrapError("OWNER challenge terminal must be exactly one observed running process")
    active_lanes = {
        name: identities for name, identities in snapshot["ftmo_lanes"].items() if identities
    }
    if active_lanes:
        raise BootstrapError(f"FTMO bootstrap is serial and lane processes are already active: {active_lanes}")
    if any(len(identities) > 1 for identities in snapshot["factory"].values()):
        raise BootstrapError("factory-side process preconditions are unclear: duplicate T1-T10 process")
    return {
        "lane": lane,
        "other_lane": next(name for name in LANE_ROOTS if name != lane),
        "challenge": snapshot["challenge"][0],
        "t_live_observed": snapshot["t_live"],
        "factory_process_count": sum(len(value) for value in snapshot["factory"].values()),
        "autotrading_touched": False,
    }


def assert_process_identity_present(
    expected: Mapping[str, Any], rows: Sequence[Mapping[str, Any]], label: str
) -> None:
    matches = []
    for index, row in enumerate(rows):
        try:
            identity = process_identity(row, f"{label} row {index}")
        except BootstrapError:
            # An unrelated transient/access-denied row can never be the
            # expected process; refusing the whole scan over it aborted a
            # live run 2026-08-08 ('row 3: process identity is incomplete').
            continue
        if (
            identity["pid"] == expected.get("pid")
            and _windows_path_key(identity["executable_path"])
            == _windows_path_key(str(expected.get("executable_path", "")))
            and identity["creation_date_utc"] == expected.get("creation_date_utc")
        ):
            matches.append(identity)
    if len(matches) != 1:
        raise BootstrapError(f"{label} process identity did not remain stable")


def _read_text_auto(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")) or b"\x00" in raw[:80]:
        encodings = ("utf-16", "utf-8-sig", "cp1252")
    else:
        encodings = ("utf-8-sig", "cp1252")
    for encoding in encodings:
        try:
            return raw.decode(encoding)
        except UnicodeError:
            continue
    raise BootstrapError(f"cannot decode text artifact: {path}")


def compile_harvest_script(terminal_root: Path, run_root: Path) -> dict[str, Any]:
    source_binding = validate_mql_source()
    terminal_root = terminal_root.expanduser().resolve()
    metaeditor = terminal_root / "MetaEditor64.exe"
    file_binding(metaeditor)
    if any(
        _windows_path_key(str(row.get("ExecutablePath") or "")) == _windows_path_key(metaeditor)
        for row in scan_metaeditor_processes()
    ):
        raise BootstrapError(f"lane/factory MetaEditor is already active: {metaeditor}")
    staged_source = terminal_root / "MQL5/Scripts/QM/m1_harvest/QM_M1_SpreadHarvest.mq5"
    staged_source.parent.mkdir(parents=True, exist_ok=True)
    # Staging converges to the hash-validated repo source: a stale copy from
    # an earlier reviewed run is replaced, an unknown foreign file refuses.
    if staged_source.exists() and sha256_file(staged_source) != source_binding["sha256"]:
        stale_backup = staged_source.with_suffix(f".stale_{utc_now().replace(':', '')}.mq5")
        shutil.move(str(staged_source), str(stale_backup))
    if not staged_source.exists():
        shutil.copyfile(SCRIPT_SOURCE, staged_source)
    if sha256_file(staged_source) != source_binding["sha256"]:
        raise BootstrapError("staged MQL5 source hash mismatch")
    compile_log = run_root / "compile.log"
    if compile_log.exists():
        raise BootstrapError(f"refusing to replace compile log: {compile_log}")
    started_at = dt.datetime.now(dt.UTC)
    try:
        result = subprocess.run(
            [str(metaeditor), f"/compile:{staged_source}", f"/log:{compile_log}"],
            cwd=str(terminal_root),
            capture_output=True,
            text=True,
            timeout=180,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception as exc:
        raise BootstrapError(f"MetaEditor compile failed to run: {exc}") from exc
    if not compile_log.is_file():
        raise BootstrapError("MetaEditor did not produce the bound compile log")
    log_text = _read_text_auto(compile_log)
    counts = re.findall(r"(?i)(\d+)\s+errors?\s*,\s*(\d+)\s+warnings?", log_text)
    if not counts:
        raise BootstrapError("MetaEditor compile log has no error/warning summary")
    errors, warnings = (int(value) for value in counts[-1])
    if errors != 0 or warnings != 0 or result.returncode not in {0, 1}:
        raise BootstrapError(
            f"MQL5 compile did not PASS 0E/0W: exit={result.returncode} errors={errors} warnings={warnings}"
        )
    staged_ex5 = staged_source.with_suffix(".ex5")
    if not staged_ex5.is_file():
        raise BootstrapError("MetaEditor reported success but produced no EX5")
    if dt.datetime.fromtimestamp(staged_ex5.stat().st_mtime, dt.UTC) < started_at - dt.timedelta(seconds=2):
        raise BootstrapError("compiled EX5 predates this compile invocation")
    return {
        "source": source_binding,
        "staged_source": file_binding(staged_source),
        "ex5": file_binding(staged_ex5),
        "metaeditor": file_binding(metaeditor),
        "compile_log": file_binding(compile_log),
        "errors": errors,
        "warnings": warnings,
        "exit_code": result.returncode,
    }


def prepare_startup_files(
    *,
    terminal_root: Path,
    run_root: Path,
    symbols: Sequence[str],
    output_tag: str,
    login: str | None,
    server: str | None,
    chart_symbol: str | None = None,
) -> dict[str, Any]:
    terminal_root = terminal_root.expanduser().resolve()
    tag = _safe_tag(output_tag)
    if not symbols:
        raise BootstrapError("startup requires at least one symbol")
    for symbol in symbols:
        local_raw, local_coverage = local_harvest_paths(terminal_root, tag, symbol)
        if local_raw.exists() or local_coverage.exists():
            raise BootstrapError(f"refusing to reuse terminal-local harvest artifacts for {symbol}")
    preset = terminal_root / "MQL5/Presets" / f"QM_M1_SpreadHarvest_{tag}.set"
    preset_text = f"InpSymbols={','.join(symbols)}\nInpOutputTag={tag}\n"
    atomic_write_text(preset, preset_text)
    startup_ini = run_root / "startup.ini"
    ini_text = "\n".join(
        [
            "; Generated by ftmo_m1_bootstrap.py; read-only script launch",
            # Without an explicit [Common] Login/Server a /config start never
            # establishes an account context: no connection for native sync
            # (4401) and no chart initialization at all (300s 'failed with
            # code 0') - both proven live 2026-08-08. Passwords stay in the
            # terminal's Config/accounts.dat - never in this file.
            *(
                ["[Common]", f"Login={login}", f"Server={server}"]
                if login and server
                else []
            ),
            "[Experts]",
            "Enabled=0",
            "AllowLiveTrading=0",
            "AllowDllImport=0",
            "[StartUp]",
            "Script=QM\\m1_harvest\\QM_M1_SpreadHarvest",
            f"ScriptParameters={preset.name}",
            # The startup chart only hosts the script. A custom-symbol chart
            # never finishes initializing on a fresh offline start (live 300s
            # 'failed with code 0' 2026-08-08) - dxz passes a native symbol.
            f"Symbol={chart_symbol or symbols[0]}",
            "Period=M1",
            "ShutdownTerminal=0",
            "",
        ]
    )
    atomic_write_text(startup_ini, ini_text)
    return {
        "preset": file_binding(preset),
        "startup_ini": file_binding(startup_ini),
        "script_relative_path": "QM\\m1_harvest\\QM_M1_SpreadHarvest",
        "symbols": list(symbols),
        "output_tag": tag,
        "experts_enabled": False,
        "allow_live_trading": False,
    }


def _exact_process_for_path(
    rows: Sequence[Mapping[str, Any]], executable: Path
) -> list[dict[str, Any]]:
    key = _windows_path_key(executable)
    return [
        process_identity(row, "launched terminal")
        for row in rows
        if _windows_path_key(str(row.get("ExecutablePath") or "")) == key
    ]


def terminate_exact_owned_terminal(identity: Mapping[str, Any]) -> dict[str, Any]:
    executable = Path(str(identity.get("executable_path", ""))).resolve()
    kind, name = _terminal_class(executable)
    if kind not in {"ftmo_lane", "factory"} or not name:
        raise BootstrapError("refusing to terminate a process outside an owned FTMO/factory root")
    try:
        pid = int(identity.get("pid"))
    except (TypeError, ValueError) as exc:
        raise BootstrapError("owned terminal identity has an invalid PID") from exc
    expected_creation = str(identity.get("creation_date_utc", ""))
    path_base64 = base64.b64encode(str(executable).encode("utf-8")).decode("ascii")
    creation_base64 = base64.b64encode(expected_creation.encode("utf-8")).decode("ascii")
    script = rf"""
$expectedPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{path_base64}'))
$expectedCreation = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{creation_base64}'))
$row = Get-CimInstance Win32_Process -Filter "ProcessId={pid}" -ErrorAction Stop
if ($null -eq $row) {{ throw 'owned process no longer exists' }}
$actualPath = [IO.Path]::GetFullPath([string]$row.ExecutablePath)
$actualCreation = ([datetime]$row.CreationDate).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$expectedCreationNormalized = ([datetime]$expectedCreation).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
if (-not $actualPath.Equals([IO.Path]::GetFullPath($expectedPath), [StringComparison]::OrdinalIgnoreCase)) {{ throw 'owned process path drift' }}
if ($actualCreation -ne $expectedCreationNormalized) {{ throw 'owned process CreationDate drift' }}
$result = Invoke-CimMethod -InputObject $row -MethodName Terminate -Arguments @{{Reason=0}} -ErrorAction Stop
if ([int]$result.ReturnValue -ne 0) {{ throw "owned process terminate failed: $($result.ReturnValue)" }}
@{{status='TERMINATED';pid={pid};executable_path=$actualPath;creation_date_utc=$actualCreation}} | ConvertTo-Json -Compress
"""
    result = _powershell_json(script, timeout=20)
    if not isinstance(result, Mapping) or result.get("status") != "TERMINATED":
        raise BootstrapError("owned terminal termination returned an invalid receipt")
    return dict(result)


def launch_and_wait(
    *,
    terminal_root: Path,
    startup_ini: Path,
    expected_artifacts: Sequence[Path],
    timeout_seconds: int,
    challenge_identity: Mapping[str, Any] | None,
) -> dict[str, Any]:
    if timeout_seconds < 60:
        raise BootstrapError("harvest timeout must be at least 60 seconds")
    terminal_root = terminal_root.expanduser().resolve()
    terminal = terminal_root / "terminal64.exe"
    file_binding(terminal)
    if _terminal_class(terminal)[0] not in {"ftmo_lane", "factory"}:
        raise BootstrapError("terminal launch path is outside an authorized lane/factory root")
    if _exact_process_for_path(scan_terminal_processes(), terminal):
        raise BootstrapError(f"selected terminal is no longer idle: {terminal}")
    command = [str(terminal), "/portable", f"/config:{startup_ini.resolve()}"]
    try:
        process = subprocess.Popen(
            command,
            cwd=str(terminal_root),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception as exc:
        raise BootstrapError(f"could not launch the selected terminal: {exc}") from exc

    identity: dict[str, Any] | None = None
    termination: dict[str, Any] | None = None
    started = utc_now()
    deadline = time.monotonic() + timeout_seconds
    try:
        identity_deadline = min(deadline, time.monotonic() + 20)
        while time.monotonic() < identity_deadline:
            matches = _exact_process_for_path(scan_terminal_processes(), terminal)
            if len(matches) > 1:
                raise BootstrapError("more than one process appeared for the selected terminal root")
            if matches:
                if matches[0]["pid"] != int(process.pid):
                    raise BootstrapError("launched terminal PID differs from the path-anchored process")
                identity = matches[0]
                break
            if process.poll() is not None:
                raise BootstrapError("selected terminal exited before its process identity was bound")
            time.sleep(0.25)
        if identity is None:
            raise BootstrapError("could not bind launched terminal PID/path/CreationDate")

        while time.monotonic() < deadline:
            rows = scan_terminal_processes()
            assert_process_identity_present(identity, rows, "owned terminal")
            if challenge_identity is not None:
                assert_process_identity_present(challenge_identity, rows, "OWNER challenge terminal")
            if all(path.is_file() for path in expected_artifacts):
                break
            time.sleep(0.5)
        else:
            raise BootstrapError("M1 harvest timed out before all completion artifacts appeared")
    finally:
        if identity is not None:
            termination = terminate_exact_owned_terminal(identity)
    if termination is None:
        raise BootstrapError("owned terminal was not safely terminated")
    return {
        "started_at": started,
        "finished_at": utc_now(),
        "command_contract": ["terminal64.exe", "/portable", "/config:<absolute-startup-ini>"],
        "terminal": file_binding(terminal),
        "process_identity": identity,
        "termination": termination,
        "challenge_identity": dict(challenge_identity) if challenge_identity is not None else None,
        "autotrading_touched": False,
    }


def read_active_factory_claims(db_path: Path = FARM_DB) -> set[str]:
    resolved = db_path.expanduser().resolve()
    if not resolved.is_file():
        raise BootstrapError(f"factory database is absent: {resolved}")
    uri = resolved.as_uri() + "?mode=ro"
    try:
        with sqlite3.connect(uri, uri=True, timeout=5) as connection:
            rows = connection.execute(
                "SELECT DISTINCT UPPER(claimed_by) FROM work_items "
                "WHERE status='active' AND claimed_by IS NOT NULL"
            ).fetchall()
    except sqlite3.Error as exc:
        raise BootstrapError(f"factory active-claim observation failed: {exc}") from exc
    claims = {str(row[0]).upper() for row in rows if row and row[0]}
    invalid = sorted(value for value in claims if value not in FACTORY_TERMINALS)
    if invalid:
        raise BootstrapError(f"factory active claims have unclear terminal identities: {invalid}")
    return claims


def read_terminal_reservations(farm_root: Path = FARM_ROOT) -> dict[str, dict[str, Any]]:
    path = farm_root.expanduser().resolve() / "state/terminal_reservations.json"
    if not path.exists():
        return {}
    raw = load_json(path, "terminal_reservations")
    entries = raw.get("reservations") if isinstance(raw, Mapping) else None
    if not isinstance(entries, Mapping):
        raise BootstrapError("terminal reservations artifact is malformed")
    now = dt.datetime.now(dt.UTC)
    live: dict[str, dict[str, Any]] = {}
    for terminal, value in entries.items():
        name = str(terminal).upper()
        if name not in FACTORY_TERMINALS or not isinstance(value, Mapping):
            raise BootstrapError("terminal reservations artifact has an unclear entry")
        try:
            until = dt.datetime.fromisoformat(str(value.get("until_utc", "")).replace("Z", "+00:00"))
        except ValueError as exc:
            raise BootstrapError(f"terminal reservation {name} has invalid expiry") from exc
        if until.tzinfo is None:
            raise BootstrapError(f"terminal reservation {name} expiry lacks timezone")
        if until.astimezone(dt.UTC) > now:
            live[name] = dict(value)
    return live


def select_free_factory_terminal(
    rows: Sequence[Mapping[str, Any]],
    active_claims: set[str],
    reservations: Mapping[str, Any],
) -> str:
    snapshot = classified_terminal_snapshot(rows)
    if any(len(identities) > 1 for identities in snapshot["factory"].values()):
        raise BootstrapError("factory-side preconditions are unclear: duplicate terminal process")
    for terminal in FACTORY_TERMINALS:
        root = MT5_ROOT / terminal
        if not (root / "terminal64.exe").is_file() or not (root / "MetaEditor64.exe").is_file():
            continue
        if snapshot["factory"][terminal] or terminal in active_claims or terminal in reservations:
            continue
        return terminal
    raise BootstrapError("no free T1-T10 terminal is provably available")


def _run_farmctl(args: Sequence[str], *, farm_root: Path = FARM_ROOT) -> Any:
    command = [
        sys.executable,
        str(REPO_ROOT / "tools/strategy_farm/farmctl.py"),
        "--root",
        str(farm_root.expanduser().resolve()),
        *args,
    ]
    try:
        result = subprocess.run(
            command,
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=30,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception as exc:
        raise BootstrapError(f"farmctl terminal reservation call failed: {exc}") from exc
    if result.returncode != 0:
        raise BootstrapError(
            f"farmctl terminal reservation call failed ({result.returncode}): "
            f"{(result.stderr or result.stdout or '').strip()}"
        )
    return strict_json_loads(result.stdout, "farmctl terminal reservation")


def reserve_factory_terminal(terminal: str, owner: str, *, minutes: int) -> dict[str, Any]:
    value = _run_farmctl(
        [
            "reserve-terminal",
            terminal,
            "--by",
            owner,
            "--minutes",
            str(minutes),
            "--reason",
            "FTMO/DXZ M1 spread harvest; process-free slot only",
        ]
    )
    if not isinstance(value, Mapping) or value.get("terminal") != terminal:
        raise BootstrapError("farmctl returned an invalid terminal reservation")
    return dict(value)


def release_factory_terminal_if_owned(terminal: str, owner: str) -> dict[str, Any]:
    current = read_terminal_reservations().get(terminal)
    if current is None:
        return {"released": False, "reason": "already_absent", "terminal": terminal}
    if current.get("reserved_by") != owner:
        raise BootstrapError("refusing to release a factory reservation now owned by another actor")
    value = _run_farmctl(["release-terminal", terminal])
    if not isinstance(value, Mapping) or value.get("terminal") != terminal:
        raise BootstrapError("farmctl returned an invalid reservation release")
    return dict(value)


@contextlib.contextmanager
def exclusive_bootstrap_lock(path: Path = LOCK_PATH) -> Iterator[dict[str, Any]]:
    target = path.expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex
    try:
        descriptor = os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise BootstrapError(f"another FTMO/DXZ M1 bootstrap lock is present: {target}") from exc
    payload = {"pid": os.getpid(), "token": token, "created_at": utc_now()}
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(canonical_json(payload))
            handle.flush()
            os.fsync(handle.fileno())
        yield {**payload, "path": str(target)}
    finally:
        try:
            current = load_json(target, "bootstrap_lock")
            if isinstance(current, Mapping) and current.get("token") == token:
                target.unlink()
        except (BootstrapError, OSError):
            pass


def _new_run_root(mode: str, identity: str, report_root: Path = REPORT_ROOT) -> tuple[Path, str]:
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    tag = _safe_tag(f"{mode}_{identity}_{stamp}_{uuid.uuid4().hex[:8]}")
    run_root = report_root.expanduser().resolve() / "bootstrap_runs" / tag
    if run_root.exists():
        raise BootstrapError(f"bootstrap run root already exists: {run_root}")
    run_root.mkdir(parents=True)
    return run_root, tag


def run_ftmo_bootstrap(
    *,
    lane: str,
    execute: bool,
    timeout_seconds: int,
    replace_projections: bool,
    spec_path: Path = SPEC_PATH,
    report_root: Path = REPORT_ROOT,
) -> dict[str, Any]:
    if not execute:
        raise BootstrapError("FTMO bootstrap requires --execute after reviewer authorization")
    if spec_path.expanduser().resolve() != SPEC_PATH.resolve():
        raise BootstrapError("FTMO bootstrap requires the reviewed canonical calibration spec")
    if report_root.expanduser().resolve() != REPORT_ROOT.resolve():
        raise BootstrapError("FTMO bootstrap report root differs from the reviewed contract")
    if lane not in LANE_ROOTS:
        raise BootstrapError(f"unsupported FTMO lane: {lane}")
    symbol = LANE_SYMBOLS[lane]
    targets = load_calibration_targets(spec_path)
    target = targets.get(("FTMO", symbol))
    if target is None:
        raise BootstrapError(f"reviewed spec has no FTMO target for {symbol}")
    expected_hcc = (LANE_ROOTS[lane] / f"Bases/FTMO-Demo/History/{symbol}/2026.hcc").resolve()
    if tuple(Path(path).resolve() for path in target["hcc_paths"]) != (expected_hcc,):
        raise BootstrapError(f"reviewed FTMO HCC binding drift for {lane}/{symbol}")
    run_root, output_tag = _new_run_root("FTMO", lane, report_root)
    with exclusive_bootstrap_lock() as lock:
        preflight = assert_ftmo_preconditions(lane, scan_terminal_processes())
        compile_receipt = compile_harvest_script(LANE_ROOTS[lane], run_root)
        startup = prepare_startup_files(
            terminal_root=LANE_ROOTS[lane],
            run_root=run_root,
            symbols=[symbol],
            output_tag=output_tag,
            login=FTMO_DEMO_LOGIN,
            server=FTMO_DEMO_SERVER,
        )
        raw_path, coverage_path = local_harvest_paths(LANE_ROOTS[lane], output_tag, symbol)
        execution = launch_and_wait(
            terminal_root=LANE_ROOTS[lane],
            startup_ini=Path(startup["startup_ini"]["path"]),
            expected_artifacts=[raw_path, coverage_path],
            timeout_seconds=timeout_seconds,
            challenge_identity=preflight["challenge"],
        )
        assert_process_identity_present(
            preflight["challenge"], scan_terminal_processes(), "OWNER challenge terminal"
        )
        published = publish_harvest(
            terminal_root=LANE_ROOTS[lane],
            terminal_name=lane,
            output_tag=output_tag,
            target=target,
            run_binding=execution,
            replace=replace_projections,
        )
        history_handoffs = {
            observation_lane: build_history_handoff(
                lane=observation_lane,
                observation_path=(
                    run_root / f"history_observation_{observation_lane}.json"
                ),
                report_root=report_root,
            )
            for observation_lane in sorted(LANE_ROOTS)
        }
        history = history_handoffs[lane]
        receipt = {
            "schema": BOOTSTRAP_RECEIPT_SCHEMA,
            "status": "PASS" if history["status"] == "READY" else "HOLD_PARTIAL",
            "created_at": utc_now(),
            "mode": "FTMO",
            "lane": lane,
            "lane_root": str(LANE_ROOTS[lane].resolve()),
            "symbols": [symbol],
            "output_tag": output_tag,
            "lock": lock,
            "preflight": preflight,
            "compile": compile_receipt,
            "startup": startup,
            "execution": execution,
            "published": {symbol: published},
            "history_handoff": history,
            "history_handoffs": history_handoffs,
            "claims": {
                "q_pipeline_verdict": "NONE",
                "live_authority": "NONE",
                "autotrading_touched": False,
                "challenge_terminal_signaled": False,
                "t_live_signaled": False,
            },
        }
        receipt_path = run_root / "bootstrap_receipt.json"
        atomic_write_json(receipt_path, receipt)
        return {**receipt, "receipt": file_binding(receipt_path)}


def run_dxz_bootstrap(
    *,
    execute: bool,
    timeout_seconds: int,
    replace_projections: bool,
    reservation_minutes: int,
    spec_path: Path = SPEC_PATH,
    report_root: Path = REPORT_ROOT,
) -> dict[str, Any]:
    if not execute:
        raise BootstrapError("DXZ bootstrap requires --execute after reviewer authorization")
    if spec_path.expanduser().resolve() != SPEC_PATH.resolve():
        raise BootstrapError("DXZ bootstrap requires the reviewed canonical calibration spec")
    if report_root.expanduser().resolve() != REPORT_ROOT.resolve():
        raise BootstrapError("DXZ bootstrap report root differs from the reviewed contract")
    if reservation_minutes * 60 < timeout_seconds + 600:
        raise BootstrapError("DXZ terminal reservation must outlive the harvest timeout by 10 minutes")
    dxz_login, dxz_server = load_dxz_factory_login()
    targets = load_calibration_targets(spec_path)
    target_rows = []
    for symbol in DXZ_SYMBOLS:
        target = targets.get(("DXZ", symbol))
        if target is None:
            raise BootstrapError(f"reviewed spec has no DXZ target for {symbol}")
        expected_hcc = (MT5_ROOT / f"T1/Bases/Custom/history/{symbol}/2026.hcc").resolve()
        if tuple(Path(path).resolve() for path in target["hcc_paths"]) != (expected_hcc,):
            raise BootstrapError(f"reviewed DXZ HCC binding drift for {symbol}")
        target_rows.append(target)
    run_root, output_tag = _new_run_root("DXZ", "FACTORY", report_root)
    owner = f"ftmo_m1_bootstrap:{output_tag}"
    terminal: str | None = None
    reservation: dict[str, Any] | None = None
    release: dict[str, Any] | None = None
    receipt: dict[str, Any] | None = None
    with exclusive_bootstrap_lock() as lock:
        rows = scan_terminal_processes()
        snapshot = classified_terminal_snapshot(rows)
        if len(snapshot["challenge"]) != 1:
            raise BootstrapError("OWNER challenge terminal identity is unclear")
        terminal = select_free_factory_terminal(
            rows,
            read_active_factory_claims(),
            read_terminal_reservations(),
        )
        reservation = reserve_factory_terminal(terminal, owner, minutes=reservation_minutes)
        try:
            post_reservation_rows = scan_terminal_processes()
            if _exact_process_for_path(
                post_reservation_rows, MT5_ROOT / terminal / "terminal64.exe"
            ):
                raise BootstrapError("factory terminal became active while its reservation was acquired")
            if terminal in read_active_factory_claims():
                raise BootstrapError("factory terminal acquired an active work item during reservation")
            current = read_terminal_reservations().get(terminal)
            if current is None or current.get("reserved_by") != owner:
                raise BootstrapError("factory terminal reservation was not durably acquired")
            terminal_root = MT5_ROOT / terminal
            compile_receipt = compile_harvest_script(terminal_root, run_root)
            startup = prepare_startup_files(
                terminal_root=terminal_root,
                run_root=run_root,
                symbols=DXZ_SYMBOLS,
                output_tag=output_tag,
                login=dxz_login,
                server=dxz_server,
                chart_symbol="EURUSD",
            )
            expected: list[Path] = []
            for symbol in DXZ_SYMBOLS:
                expected.extend(local_harvest_paths(terminal_root, output_tag, symbol))
            execution = launch_and_wait(
                terminal_root=terminal_root,
                startup_ini=Path(startup["startup_ini"]["path"]),
                expected_artifacts=expected,
                timeout_seconds=timeout_seconds,
                challenge_identity=snapshot["challenge"][0],
            )
            published = {
                str(target["symbol"]): publish_harvest(
                    terminal_root=terminal_root,
                    terminal_name=terminal,
                    output_tag=output_tag,
                    target=target,
                    run_binding=execution,
                    replace=replace_projections,
                )
                for target in target_rows
            }
            receipt = {
                "schema": BOOTSTRAP_RECEIPT_SCHEMA,
                "status": "PASS",
                "created_at": utc_now(),
                "mode": "DXZ",
                "terminal": terminal,
                "terminal_root": str(terminal_root.resolve()),
                "symbols": list(DXZ_SYMBOLS),
                "output_tag": output_tag,
                "lock": lock,
                "challenge_identity": snapshot["challenge"][0],
                "t_live_observed": snapshot["t_live"],
                "reservation": reservation,
                "compile": compile_receipt,
                "startup": startup,
                "execution": execution,
                "published": published,
                "claims": {
                    "q_pipeline_verdict": "NONE",
                    "live_authority": "NONE",
                    "autotrading_touched": False,
                    "active_backtest_interrupted": False,
                    "challenge_terminal_signaled": False,
                    "t_live_signaled": False,
                },
            }
        finally:
            if terminal is not None and reservation is not None:
                release = release_factory_terminal_if_owned(terminal, owner)
        if receipt is None:
            raise BootstrapError("DXZ bootstrap finished without a receipt payload")
        receipt["reservation_release"] = release
        receipt_path = run_root / "bootstrap_receipt.json"
        atomic_write_json(receipt_path, receipt)
    return {**receipt, "receipt": file_binding(receipt_path)}


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    ftmo = subparsers.add_parser("ftmo", help="harvest one serialized FTMO research lane")
    ftmo.add_argument("--lane", required=True, choices=sorted(LANE_ROOTS))
    ftmo.add_argument("--execute", action="store_true")
    ftmo.add_argument("--timeout-seconds", type=int, default=7200)
    ftmo.add_argument("--replace-projections", action="store_true")
    ftmo.add_argument("--spec", type=Path, default=SPEC_PATH)
    ftmo.add_argument("--report-root", type=Path, default=REPORT_ROOT)

    dxz = subparsers.add_parser("dxz", help="harvest both DXZ symbols on one free reserved slot")
    dxz.add_argument("--execute", action="store_true")
    dxz.add_argument("--timeout-seconds", type=int, default=7200)
    dxz.add_argument("--reservation-minutes", type=int, default=150)
    dxz.add_argument("--replace-projections", action="store_true")
    dxz.add_argument("--spec", type=Path, default=SPEC_PATH)
    dxz.add_argument("--report-root", type=Path, default=REPORT_ROOT)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "ftmo":
            result = run_ftmo_bootstrap(
                lane=args.lane,
                execute=args.execute,
                timeout_seconds=args.timeout_seconds,
                replace_projections=args.replace_projections,
                spec_path=args.spec,
                report_root=args.report_root,
            )
        else:
            result = run_dxz_bootstrap(
                execute=args.execute,
                timeout_seconds=args.timeout_seconds,
                replace_projections=args.replace_projections,
                reservation_minutes=args.reservation_minutes,
                spec_path=args.spec,
                report_root=args.report_root,
            )
        print(canonical_json(result), end="")
        return 0
    except BootstrapError as exc:
        print(f"REFUSED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
