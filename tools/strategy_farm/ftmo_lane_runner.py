#!/usr/bin/env python3
"""Fail-closed provisioning and isolated runner for the two FTMO research lanes.

This module deliberately does not use the normal Strategy Farm database or its
T1-T10 worker queues.  Provision inspection is read-only.  Campaign preparation
is admitted only after a reviewed provision receipt proves the requested native
history window and a separate probe receipt proves the native symbol contract.

The execution model is always explicit:

* ``REAL_TICKS`` -> MT5 model 4, evidence class ``FTMO_REAL_TICKS``;
* ``M1_MODELLED`` -> MT5 model 1, evidence class ``FTMO_M1_MODELLED``.

There is no fallback between the two.  The existing FTMO daily exporter accepts
only the first class; this runner records an explicit refusal for M1 output.
Nothing in this file writes a Q-phase verdict or touches T_Live/AutoTrading.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any, Mapping, Sequence


PROVISION_RECEIPT_SCHEMA = "qm.ftmo-lane-provision-receipt/v1"
HISTORY_OBSERVATION_SCHEMA = "qm.ftmo-history-coverage/v1"
SYMBOL_PROBE_SCHEMA = "qm.ftmo-symbol-probe-receipt/v1"
JOB_MANIFEST_SCHEMA = "qm.ftmo-lane-job-manifest/v1"
RUN_RECEIPT_SCHEMA = "qm.ftmo-lane-run-receipt/v1"

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REPORT_STATE = Path("D:/QM/reports/state")
DEFAULT_QUEUE_ROOT = Path("D:/QM/strategy_farm/ftmo_lane_queue")
DEFAULT_OUTPUT_ROOT = Path("D:/QM/reports/ftmo_stream/wave1")
DEFAULT_COMMON_FILES = Path(os.environ.get("APPDATA", "")) / "MetaQuotes/Terminal/Common/Files"

LANE_ROOTS: dict[str, Path] = {
    "FTMO_STREAM1": Path("D:/QM/mt5/FTMO_STREAM1"),
    "FTMO_STREAM2": Path("D:/QM/mt5/FTMO_STREAM2"),
}
NATIVE_SYMBOLS = ("XAUUSD", "GER40.cash")
FTMO_CODES = {"XAUUSD": "XAU/USD", "GER40.cash": "GER40.cash"}
EXECUTION_MODELS: dict[str, dict[str, Any]] = {
    "REAL_TICKS": {"mt5_model": 4, "evidence_class": "FTMO_REAL_TICKS"},
    "M1_MODELLED": {"mt5_model": 1, "evidence_class": "FTMO_M1_MODELLED"},
}
MAX_FTMO_CONCURRENT = 2
NORMAL_FACTORY_SLOTS = 10
MIN_NORMAL_FACTORY_SLOTS_PRESERVED = 8
EXPECTED_COST_SNAPSHOT_SHA256 = (
    "7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da"
)
SHA_RE = re.compile(r"^[0-9a-f]{64}$")


class FtmoLaneError(ValueError):
    """The requested lane operation cannot be proved safe/admissible."""


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def _reject_forbidden_path(path: Path, label: str) -> Path:
    resolved = path.expanduser().resolve()
    lowered = str(resolved).lower().replace("/", "\\")
    if "\\t_live" in lowered or "\\appdata\\" in lowered:
        raise FtmoLaneError(f"{label}: live/AppData terminal data paths are forbidden")
    return resolved


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise FtmoLaneError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def file_binding(path: Path) -> dict[str, Any]:
    resolved = path.expanduser().resolve()
    if not resolved.is_file():
        raise FtmoLaneError(f"required file is absent: {resolved}")
    return {
        "path": str(resolved),
        "size_bytes": resolved.stat().st_size,
        "sha256": sha256_file(resolved),
    }


def _canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        indent=2,
        sort_keys=True,
    ) + "\n"


def atomic_write_json(path: Path, value: Any, *, replace: bool = False) -> None:
    target = path.expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and not replace:
        raise FtmoLaneError(f"refusing to replace existing artifact: {target}")
    descriptor, temp_name = tempfile.mkstemp(prefix=f".{target.name}.", dir=str(target.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(_canonical_json(value))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def load_json(path: Path, label: str) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise FtmoLaneError(f"{label}: invalid JSON: {exc}") from exc


def _assert_sha(value: Any, label: str) -> str:
    digest = str(value).strip().lower()
    if not SHA_RE.fullmatch(digest):
        raise FtmoLaneError(f"{label}: expected lowercase SHA-256")
    return digest


def _resolve_lane(lane: str, root_override: Path | None = None) -> Path:
    if lane not in LANE_ROOTS:
        raise FtmoLaneError(f"lane must be one of {sorted(LANE_ROOTS)}")
    expected = LANE_ROOTS[lane].resolve()
    actual = (root_override or expected).expanduser().resolve()
    lowered = str(actual).lower().replace("/", "\\")
    if actual != expected:
        raise FtmoLaneError(f"lane root differs from the registered dedicated root: {actual}")
    if "\\appdata\\" in lowered or "\\t_live" in lowered:
        raise FtmoLaneError(f"live/AppData terminal roots are forbidden: {actual}")
    return actual


def _read_ini_sections(path: Path) -> dict[str, dict[str, str]]:
    """Read only non-secret INI state needed for the receipt.

    The returned mapping stays in memory.  Callers publish an allowlisted subset
    and never serialize arbitrary keys or values from the account profile.
    """

    try:
        raw = path.read_text(encoding="utf-16" if b"\x00" in path.read_bytes()[:80] else "utf-8-sig")
    except (OSError, UnicodeError) as exc:
        raise FtmoLaneError(f"cannot read terminal profile {path}: {exc}") from exc
    sections: dict[str, dict[str, str]] = {}
    section = ""
    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith((";", "#")):
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1].strip()
            sections.setdefault(section, {})
            continue
        if "=" in stripped and section:
            key, value = stripped.split("=", 1)
            sections.setdefault(section, {})[key.strip()] = value.strip()
    return sections


def _safe_profile_identity(common_ini: Path) -> dict[str, Any]:
    sections = _read_ini_sections(common_ini)
    common = sections.get("Common", {})
    experts = sections.get("Experts", {})
    server = common.get("Server", "")
    source = common.get("Source", "")
    login = common.get("Login", "")
    enabled = experts.get("Enabled", "")
    try:
        login_number: int | None = int(login) if login else None
    except ValueError:
        login_number = None
    return {
        "server": server,
        "broker_source": source,
        "demo_login": login_number,
        "company_contains_ftmo": "ftmo" in source.lower(),
        "company_evidence": "Config/common.ini [Common] Source (report-level company still unproven)",
        "experts_enabled": enabled == "1",
        "experts_enabled_raw_is_zero": enabled == "0",
    }


def _history_cache_inventory(root: Path, symbol: str) -> dict[str, Any]:
    """Inventory native caches without turning filenames into coverage claims."""

    bases = root / "Bases"
    token = symbol.lower()
    tick_files: list[Path] = []
    m1_files: list[Path] = []
    if bases.is_dir():
        for path in bases.rglob("*"):
            if not path.is_file() or token not in str(path.parent).lower():
                continue
            suffix = path.suffix.lower()
            if suffix == ".tkc":
                tick_files.append(path)
            elif suffix == ".hcc":
                m1_files.append(path)
    return {
        "real_ticks": {
            "cache_file_count": len(tick_files),
            "cache_files_sha256": [sha256_file(path) for path in sorted(tick_files)],
            "coverage_from": None,
            "coverage_to": None,
            "coverage_proven": False,
            "reason": "CACHE_FILES_ALONE_DO_NOT_PROVE_ACTUAL_TICK_WINDOW",
        },
        "m1_bars": {
            "cache_file_count": len(m1_files),
            "cache_files_sha256": [sha256_file(path) for path in sorted(m1_files)],
            "coverage_from": None,
            "coverage_to": None,
            "coverage_proven": False,
            "reason": "CACHE_FILES_ALONE_DO_NOT_PROVE_ACTUAL_M1_WINDOW",
        },
    }


def _validate_iso_date(value: Any, label: str) -> dt.date:
    if not isinstance(value, str):
        raise FtmoLaneError(f"{label}: expected YYYY-MM-DD")
    try:
        parsed = dt.date.fromisoformat(value)
    except ValueError as exc:
        raise FtmoLaneError(f"{label}: expected YYYY-MM-DD") from exc
    if parsed.isoformat() != value:
        raise FtmoLaneError(f"{label}: non-canonical date")
    return parsed


def _apply_history_observation(
    history: dict[str, Any], observation_path: Path, lane: str, root: Path
) -> dict[str, Any]:
    observation = load_json(observation_path, "history_observation")
    if not isinstance(observation, Mapping) or observation.get("schema") != HISTORY_OBSERVATION_SCHEMA:
        raise FtmoLaneError("history observation has an unsupported schema")
    if observation.get("lane") != lane or Path(str(observation.get("lane_root", ""))).resolve() != root:
        raise FtmoLaneError("history observation is bound to a different lane/root")
    symbols = observation.get("symbols")
    if not isinstance(symbols, Mapping) or set(symbols) != set(NATIVE_SYMBOLS):
        raise FtmoLaneError("history observation must cover exactly XAUUSD and GER40.cash")
    for symbol in NATIVE_SYMBOLS:
        item = symbols[symbol]
        if not isinstance(item, Mapping) or set(item) != {"real_ticks", "m1_bars"}:
            raise FtmoLaneError(f"history observation {symbol}: unexpected fields")
        for class_name in ("real_ticks", "m1_bars"):
            coverage = item[class_name]
            if not isinstance(coverage, Mapping) or set(coverage) != {
                "coverage_from", "coverage_to", "source_artifact", "source_sha256"
            }:
                raise FtmoLaneError(f"history observation {symbol}.{class_name}: unexpected fields")
            start = _validate_iso_date(coverage["coverage_from"], f"{symbol}.{class_name}.from")
            end = _validate_iso_date(coverage["coverage_to"], f"{symbol}.{class_name}.to")
            if end < start:
                raise FtmoLaneError(f"history observation {symbol}.{class_name}: reversed window")
            source = _reject_forbidden_path(
                Path(str(coverage["source_artifact"])),
                f"history observation {symbol}.{class_name}.source_artifact",
            )
            expected = _assert_sha(coverage["source_sha256"], f"{symbol}.{class_name}.source_sha256")
            if sha256_file(source) != expected:
                raise FtmoLaneError(f"history observation {symbol}.{class_name}: source hash drift")
            history[symbol][class_name].update(
                {
                    "coverage_from": start.isoformat(),
                    "coverage_to": end.isoformat(),
                    "coverage_proven": True,
                    "reason": "PROVEN_BY_HASH_BOUND_HISTORY_OBSERVATION",
                    "source_artifact": str(source),
                    "source_sha256": expected,
                }
            )
    return file_binding(observation_path)


def scan_terminal_processes() -> list[dict[str, Any]]:
    command = (
        "Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | "
        "Select-Object ProcessId,ExecutablePath,CommandLine | ConvertTo-Json -Depth 3"
    )
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", command],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
    except Exception as exc:
        raise FtmoLaneError(f"cannot inspect terminal capacity: {exc}") from exc
    if result.returncode != 0:
        raise FtmoLaneError("terminal capacity scan failed")
    if not result.stdout.strip():
        return []
    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise FtmoLaneError("terminal capacity scan returned invalid JSON") from exc
    rows = value if isinstance(value, list) else [value]
    return [dict(row) for row in rows if isinstance(row, Mapping)]


def capacity_observation(process_rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    factory: list[int] = []
    ftmo: list[int] = []
    unknown: list[int] = []
    for row in process_rows:
        exe = str(row.get("ExecutablePath") or "").replace("/", "\\")
        try:
            pid = int(row.get("ProcessId"))
        except (TypeError, ValueError):
            continue
        if re.search(r"\\mt5\\T(?:[1-9]|10)\\terminal64\.exe$", exe, re.IGNORECASE):
            factory.append(pid)
        elif re.search(r"\\mt5\\FTMO_STREAM[12]\\terminal64\.exe$", exe, re.IGNORECASE):
            ftmo.append(pid)
        else:
            unknown.append(pid)
    permit = len(factory) <= NORMAL_FACTORY_SLOTS and len(ftmo) < MAX_FTMO_CONCURRENT
    return {
        "permit": permit,
        "observed_factory_terminal_processes": len(factory),
        "observed_ftmo_terminal_processes": len(ftmo),
        "observed_other_terminal_processes": len(unknown),
        "max_ftmo_concurrent": MAX_FTMO_CONCURRENT,
        "normal_factory_slots": NORMAL_FACTORY_SLOTS,
        "normal_factory_slots_claimed_by_ftmo": 0,
        "normal_factory_slots_preserved": NORMAL_FACTORY_SLOTS,
        "minimum_normal_factory_slots_preserved": MIN_NORMAL_FACTORY_SLOTS_PRESERVED,
        "preemption_allowed": False,
        "reason": "ADMIT" if permit else "CAPACITY_LIMIT",
    }


def build_provision_receipt(
    lane: str,
    *,
    root_override: Path | None = None,
    history_observation_path: Path | None = None,
    process_rows: Sequence[Mapping[str, Any]] | None = None,
) -> dict[str, Any]:
    root = _resolve_lane(lane, root_override)
    terminal = root / "terminal64.exe"
    config = root / "Config"
    common_ini = config / "common.ini"
    required = {
        "terminal_exe": terminal,
        "common_ini": common_ini,
        "servers_dat": config / "servers.dat",
        "accounts_dat": config / "accounts.dat",
    }
    bindings = {name: file_binding(path) for name, path in required.items()}
    profile = _safe_profile_identity(common_ini)
    if profile["server"] != "FTMO-Demo":
        raise FtmoLaneError(f"profile server is not FTMO-Demo: {profile['server']!r}")
    if not profile["company_contains_ftmo"]:
        raise FtmoLaneError("profile broker/company evidence does not contain FTMO")
    if profile["experts_enabled"] or not profile["experts_enabled_raw_is_zero"]:
        raise FtmoLaneError("Experts/AutoTrading must be explicitly disabled")

    history = {symbol: _history_cache_inventory(root, symbol) for symbol in NATIVE_SYMBOLS}
    observation_binding = None
    if history_observation_path is not None:
        observation_binding = _apply_history_observation(
            history, history_observation_path.expanduser().resolve(), lane, root
        )
    capacity = capacity_observation(process_rows if process_rows is not None else scan_terminal_processes())
    history_complete = all(
        history[symbol][kind]["coverage_proven"]
        for symbol in NATIVE_SYMBOLS
        for kind in ("real_ticks", "m1_bars")
    )
    campaign_ready = bool(capacity["permit"] and history_complete)
    return {
        "schema": PROVISION_RECEIPT_SCHEMA,
        "created_at": utc_now(),
        "lane": lane,
        "lane_root": str(root),
        "status": "READY" if campaign_ready else "HOLD",
        "campaign_ready": campaign_ready,
        "hold_reasons": [
            reason
            for condition, reason in (
                (capacity["permit"], "CAPACITY_NOT_AVAILABLE"),
                (history_complete, "NATIVE_HISTORY_WINDOWS_UNPROVEN"),
            )
            if not condition
        ],
        "dedicated_research_root": {
            "proven": True,
            "registered_root_match": True,
            "not_t_live": True,
            "not_appdata_live_trial": True,
            "portable_mode_assertion": "RUNNER_ALWAYS_USES_ROOT_TERMINAL_WITH_/portable_AND_ROOT_LOCAL_CONFIG",
        },
        "profile": profile,
        "autotrading_touched": False,
        "bindings": bindings,
        "history": history,
        "history_observation": observation_binding,
        "capacity": capacity,
        "claims": {
            "pipeline_verdict": "NONE",
            "selection_credit": "NONE",
            "live_authority": "NONE",
        },
    }


def validate_provision_receipt(
    receipt: Any,
    *,
    lane: str,
    native_symbol: str | None = None,
    execution_model: str | None = None,
    requested_from: dt.date | None = None,
    requested_to: dt.date | None = None,
    require_campaign_ready: bool = False,
) -> None:
    if not isinstance(receipt, Mapping) or receipt.get("schema") != PROVISION_RECEIPT_SCHEMA:
        raise FtmoLaneError("unsupported provision receipt")
    root = _resolve_lane(lane)
    if receipt.get("lane") != lane or Path(str(receipt.get("lane_root", ""))).resolve() != root:
        raise FtmoLaneError("provision receipt is bound to a different lane/root")
    if receipt.get("autotrading_touched") is not False:
        raise FtmoLaneError("provision receipt indicates an AutoTrading mutation")
    profile = receipt.get("profile", {})
    if profile.get("server") != "FTMO-Demo" or profile.get("company_contains_ftmo") is not True:
        raise FtmoLaneError("provision receipt does not prove an FTMO-Demo profile")
    if profile.get("experts_enabled") is not False or profile.get("experts_enabled_raw_is_zero") is not True:
        raise FtmoLaneError("provision receipt does not prove Experts disabled")
    if receipt.get("capacity", {}).get("permit") is not True:
        raise FtmoLaneError("provision receipt has no capacity permit")
    bindings = receipt.get("bindings", {})
    expected_paths = {
        "terminal_exe": root / "terminal64.exe",
        "common_ini": root / "Config/common.ini",
        "servers_dat": root / "Config/servers.dat",
        "accounts_dat": root / "Config/accounts.dat",
    }
    for name in ("terminal_exe", "common_ini", "servers_dat", "accounts_dat"):
        binding = bindings.get(name, {})
        path = Path(str(binding.get("path", ""))).resolve()
        if path != expected_paths[name].resolve():
            raise FtmoLaneError(f"provision receipt path escaped the lane root: {name}")
        expected = _assert_sha(binding.get("sha256", ""), f"bindings.{name}.sha256")
        if sha256_file(path) != expected:
            raise FtmoLaneError(f"provision receipt binding drift: {name}")
    actual_profile = _safe_profile_identity(expected_paths["common_ini"])
    for field in (
        "server",
        "broker_source",
        "demo_login",
        "company_contains_ftmo",
        "experts_enabled",
        "experts_enabled_raw_is_zero",
    ):
        if profile.get(field) != actual_profile[field]:
            raise FtmoLaneError(f"provision receipt profile drift/tampering: {field}")
    if require_campaign_ready and receipt.get("campaign_ready") is not True:
        raise FtmoLaneError("provision receipt is HOLD, not campaign-ready")
    if native_symbol is None:
        return
    if native_symbol not in NATIVE_SYMBOLS or execution_model not in EXECUTION_MODELS:
        raise FtmoLaneError("unsupported native symbol/execution model")
    if requested_from is None or requested_to is None:
        raise FtmoLaneError("history validation requires an explicit window")
    kind = "real_ticks" if execution_model == "REAL_TICKS" else "m1_bars"
    coverage = receipt.get("history", {}).get(native_symbol, {}).get(kind, {})
    if coverage.get("coverage_proven") is not True:
        raise FtmoLaneError(f"{native_symbol} {kind} coverage is unproven")
    coverage_from = _validate_iso_date(coverage.get("coverage_from"), f"{native_symbol}.{kind}.from")
    coverage_to = _validate_iso_date(coverage.get("coverage_to"), f"{native_symbol}.{kind}.to")
    if coverage_from > requested_from or coverage_to < requested_to:
        raise FtmoLaneError(
            f"{native_symbol} {kind} coverage {coverage_from}..{coverage_to} "
            f"does not contain {requested_from}..{requested_to}"
        )


def _set_values(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line_number, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = (part.strip() for part in stripped.split("=", 1))
        if key in values:
            raise FtmoLaneError(f"setfile line {line_number}: duplicate {key}")
        values[key] = value
    return values


def validate_set_guardrails(text: str) -> None:
    values = _set_values(text)
    try:
        risk_fixed = float(values["RISK_FIXED"])
        risk_percent = float(values["RISK_PERCENT"])
    except (KeyError, ValueError) as exc:
        raise FtmoLaneError("setfile must define numeric RISK_FIXED/RISK_PERCENT") from exc
    if risk_fixed <= 0 or risk_percent != 0:
        raise FtmoLaneError("setfile must use RISK_FIXED > 0 and RISK_PERCENT = 0")
    stale = values.get("qm_news_stale_max_hours")
    if stale is not None:
        try:
            stale_value = float(stale)
        except ValueError as exc:
            raise FtmoLaneError("setfile qm_news_stale_max_hours is not numeric") from exc
        if stale_value > 336:
            raise FtmoLaneError("setfile qm_news_stale_max_hours exceeds 336")


def derive_ftmo_set(
    source: Path,
    destination: Path,
    *,
    source_symbol: str,
    native_symbol: str,
    replace: bool = False,
) -> dict[str, Any]:
    source = source.expanduser().resolve()
    destination = destination.expanduser().resolve()
    if source == destination:
        raise FtmoLaneError("derived set must not alias the sealed source")
    raw = source.read_bytes()
    encoding = "utf-16-le" if b"\x00" in raw[:80] else "utf-8-sig"
    try:
        text = raw.decode(encoding)
    except UnicodeError as exc:
        raise FtmoLaneError("setfile encoding is unsupported") from exc
    validate_set_guardrails(text)
    pattern = re.compile(r"(?im)^(;\s*symbol:\s*)" + re.escape(source_symbol) + r"\s*$")
    derived, count = pattern.subn(lambda match: match.group(1) + native_symbol, text)
    if count != 1:
        raise FtmoLaneError(
            f"sealed set must contain exactly one '; symbol: {source_symbol}' provenance line"
        )
    if _set_values(text) != _set_values(derived):
        raise FtmoLaneError("venue rebinding changed strategy input values")
    if destination.exists() and not replace:
        raise FtmoLaneError(f"refusing to replace derived set: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(derived, encoding="utf-8", newline="\n")
    return {
        "contract": "SEALED_SET_VENUE_REBIND_V1",
        "source_symbol": source_symbol,
        "native_symbol": native_symbol,
        "ftmo_code": FTMO_CODES[native_symbol],
        "strategy_inputs_identical": True,
        "source": file_binding(source),
        "derived": file_binding(destination),
        "mutation_scope": "SET_METADATA_SYMBOL_LINE_ONLY; TESTER_INI_BINDS_HOST_SYMBOL",
    }


def validate_symbol_probe(
    probe: Any, *, lane: str, native_symbol: str, provision_sha256: str
) -> None:
    if not isinstance(probe, Mapping) or probe.get("schema") != SYMBOL_PROBE_SCHEMA:
        raise FtmoLaneError("unsupported native-symbol probe receipt")
    if probe.get("status") != "PASS" or probe.get("lane") != lane:
        raise FtmoLaneError("native-symbol probe did not PASS for this lane")
    if probe.get("native_symbol") != native_symbol:
        raise FtmoLaneError("native-symbol probe is for a different symbol")
    if probe.get("provision_receipt_sha256") != provision_sha256:
        raise FtmoLaneError("native-symbol probe is not bound to this provision receipt")
    guard = probe.get("symbol_guard", {})
    specs = probe.get("symbol_spec", {})
    if guard.get("event") != "SYMBOL_GUARD_INIT" or guard.get("mode") != "single":
        raise FtmoLaneError("native-symbol probe lacks a single-symbol guard event")
    if guard.get("symbol") != native_symbol or guard.get("violations") != 0:
        raise FtmoLaneError("native-symbol probe guard mismatch/violation")
    for field in ("digits", "contract_size", "tick_size", "tick_value"):
        try:
            value = float(specs[field])
        except (KeyError, TypeError, ValueError) as exc:
            raise FtmoLaneError(f"native-symbol probe lacks numeric {field}") from exc
        if value <= 0:
            raise FtmoLaneError(f"native-symbol probe {field} must be positive")
    for name in ("tester_log", "report", "symbol_spec_observation"):
        binding = probe.get("bindings", {}).get(name, {})
        expected = _assert_sha(binding.get("sha256", ""), f"probe.{name}.sha256")
        path = _reject_forbidden_path(
            Path(str(binding.get("path", ""))), f"probe.{name}.path"
        )
        if sha256_file(path) != expected:
            raise FtmoLaneError(f"native-symbol probe binding drift: {name}")


def _ea_directory(repo_root: Path, ea_id: int, ex5_path: Path) -> Path:
    matches = [
        path.resolve()
        for path in (repo_root / "framework/EAs").glob(f"QM5_{ea_id}_*")
        if path.is_dir()
    ]
    if len(matches) != 1:
        raise FtmoLaneError(f"EA {ea_id} build identity is ambiguous: {len(matches)} directories")
    if ex5_path.resolve().parent != matches[0]:
        raise FtmoLaneError("EX5 is not inside the unique EA directory")
    return matches[0]


def _tester_ini_text(manifest: Mapping[str, Any]) -> str:
    model = manifest["execution_model"]
    run_root = Path(manifest["run_root"])
    report_stem = run_root / "raw/run_01/report"
    staged_expert = manifest["staged_expert_relpath"].replace("/", "\\")
    set_path = Path(manifest["set_rebinding"]["derived"]["path"])
    return "\n".join(
        [
            "; Generated by ftmo_lane_runner.py; research evidence only",
            f"; EvidenceClass={manifest['evidence_class']}",
            f"; ExecutionModel={model['name']}",
            "[Tester]",
            f"Expert={staged_expert}",
            f"ExpertParameters={set_path}",
            f"Symbol={manifest['native_symbol']}",
            f"Period={manifest['timeframe']}",
            f"Model={model['mt5_model']}",
            f"FromDate={manifest['window']['from'].replace('-', '.')} ",
            f"ToDate={manifest['window']['to'].replace('-', '.')} ",
            "ForwardMode=0",
            "Deposit=100000",
            "Currency=USD",
            "Leverage=100",
            f"Report={report_stem}",
            "ReplaceReport=0",
            "ShutdownTerminal=1",
            "Visual=0",
            "Optimization=0",
            "",
        ]
    )


def prepare_job(
    *,
    lane: str,
    sleeve_id: str,
    ea_id: int,
    evaluator_symbol: str,
    source_symbol: str,
    native_symbol: str,
    timeframe: str,
    from_date: dt.date,
    to_date: dt.date,
    execution_model: str,
    ex5_path: Path,
    expected_ex5_sha256: str,
    setfile_path: Path,
    expected_set_sha256: str,
    provision_receipt_path: Path,
    symbol_probe_path: Path,
    cost_snapshot_path: Path,
    expected_cost_sha256: str,
    max_concurrent: int,
    output_root: Path,
    queue_root: Path,
    repo_root: Path = REPO_ROOT,
) -> tuple[Path, dict[str, Any]]:
    if execution_model not in EXECUTION_MODELS:
        raise FtmoLaneError(f"execution model must be one of {sorted(EXECUTION_MODELS)}")
    if max_concurrent != MAX_FTMO_CONCURRENT:
        raise FtmoLaneError(f"max_concurrent must equal {MAX_FTMO_CONCURRENT}")
    if to_date < from_date:
        raise FtmoLaneError("job window is reversed")
    if output_root.expanduser().resolve() != DEFAULT_OUTPUT_ROOT.resolve():
        raise FtmoLaneError("output root must be the isolated FTMO wave-1 root")
    if queue_root.expanduser().resolve() != DEFAULT_QUEUE_ROOT.resolve():
        raise FtmoLaneError("queue root must be the isolated FTMO queue")
    root = _resolve_lane(lane)
    provision_receipt_path = provision_receipt_path.expanduser().resolve()
    provision = load_json(provision_receipt_path, "provision_receipt")
    validate_provision_receipt(
        provision,
        lane=lane,
        native_symbol=native_symbol,
        execution_model=execution_model,
        requested_from=from_date,
        requested_to=to_date,
        require_campaign_ready=True,
    )
    provision_sha = sha256_file(provision_receipt_path)
    symbol_probe_path = _reject_forbidden_path(symbol_probe_path, "symbol_probe")
    probe = load_json(symbol_probe_path, "symbol_probe")
    validate_symbol_probe(
        probe, lane=lane, native_symbol=native_symbol, provision_sha256=provision_sha
    )

    ex5_path = ex5_path.expanduser().resolve()
    setfile_path = setfile_path.expanduser().resolve()
    expected_ex5 = _assert_sha(expected_ex5_sha256, "expected_ex5_sha256")
    expected_set = _assert_sha(expected_set_sha256, "expected_set_sha256")
    if sha256_file(ex5_path) != expected_ex5:
        raise FtmoLaneError("EX5 drift from reviewed wave-1 identity")
    if sha256_file(setfile_path) != expected_set:
        raise FtmoLaneError("setfile drift from reviewed wave-1 identity")
    _ea_directory(repo_root.expanduser().resolve(), ea_id, ex5_path)
    if sleeve_id != f"{ea_id}:{evaluator_symbol}":
        raise FtmoLaneError("sleeve identity does not match EA/evaluator symbol")
    cost_snapshot_path = cost_snapshot_path.expanduser().resolve()
    expected_cost = _assert_sha(expected_cost_sha256, "expected_cost_sha256")
    if expected_cost != EXPECTED_COST_SNAPSHOT_SHA256 or sha256_file(cost_snapshot_path) != expected_cost:
        raise FtmoLaneError("cost snapshot differs from the pinned FTMO snapshot")

    job_id = f"W1_{ea_id}_{native_symbol.replace('.', '_')}_{uuid.uuid4().hex[:12]}"
    run_root = (output_root.expanduser().resolve() / job_id)
    if run_root.exists():
        raise FtmoLaneError(f"run root already exists: {run_root}")
    run_root.mkdir(parents=True)
    (run_root / "raw/run_01").mkdir(parents=True)
    derived_set = run_root / "inputs" / f"{setfile_path.stem}_{native_symbol.replace('.', '_')}.set"
    rebinding = derive_ftmo_set(
        setfile_path,
        derived_set,
        source_symbol=source_symbol,
        native_symbol=native_symbol,
    )
    model = EXECUTION_MODELS[execution_model]
    manifest: dict[str, Any] = {
        "schema": JOB_MANIFEST_SCHEMA,
        "created_at": utc_now(),
        "job_id": job_id,
        "lane": lane,
        "lane_root": str(root),
        "sleeve_id": sleeve_id,
        "ea_id": ea_id,
        "evaluator_symbol": evaluator_symbol,
        "source_symbol": source_symbol,
        "native_symbol": native_symbol,
        "timeframe": timeframe,
        "window": {"from": from_date.isoformat(), "to": to_date.isoformat()},
        "execution_model": {"name": execution_model, "mt5_model": model["mt5_model"]},
        "evidence_class": model["evidence_class"],
        "bootstrap_serialization": "ONE_FIRST_CONNECTION_AT_A_TIME_PER_SHARED_DEMO_ACCOUNT",
        "max_concurrent": max_concurrent,
        "run_root": str(run_root),
        "staged_expert_relpath": f"QM\\FTMO_STREAM\\{job_id}\\{ex5_path.name}",
        "bindings": {
            "terminal_exe": provision["bindings"]["terminal_exe"],
            "server_profile": provision["bindings"]["common_ini"],
            "ex5": file_binding(ex5_path),
            "provision_receipt": file_binding(provision_receipt_path),
            "symbol_probe": file_binding(symbol_probe_path),
            "cost_snapshot": file_binding(cost_snapshot_path),
        },
        "set_rebinding": rebinding,
        "artifact_contract": {
            "report": str(run_root / "raw/run_01/report.htm"),
            "q08_delta": str(run_root / "q08_trades.jsonl"),
            "equity_delta": str(run_root / "equity_log.jsonl"),
            "run_receipt": str(run_root / "runner_receipt.json"),
            "ordinary_factory_visibility": False,
            "survivor_collection_visibility": False,
            "q_pipeline_verdict": "NONE",
        },
        "export_contract": {
            "producer": "tools/strategy_farm/portfolio/ftmo_daily_net_export.py",
            "admissible": execution_model == "REAL_TICKS",
            "refusal_reason": None if execution_model == "REAL_TICKS" else "FTMO_M1_MODELLED_IS_NOT_TICK_LEVEL_VENUE_EXECUTION",
            "summary": str(run_root / "summary.json"),
            "stream": str(run_root / f"{ea_id}_{evaluator_symbol}.ftmo_daily_net_v1.jsonl"),
            "receipt": str(run_root / f"{ea_id}_{evaluator_symbol}.ftmo_daily_net_v1.receipt.json"),
        },
    }
    ini_path = run_root / "tester.ini"
    ini_path.write_text(_tester_ini_text(manifest), encoding="utf-8", newline="\n")
    manifest["bindings"]["tester_ini"] = file_binding(ini_path)
    manifest_path = run_root / "job_manifest.json"
    atomic_write_json(manifest_path, manifest)
    queue_pending = queue_root.expanduser().resolve() / "pending"
    queue_pending.mkdir(parents=True, exist_ok=True)
    queued_path = queue_pending / f"{job_id}.json"
    try:
        os.link(manifest_path, queued_path)
    except OSError:
        shutil.copyfile(manifest_path, queued_path)
    return queued_path, manifest


def verify_job_binding(manifest: Any, *, lane: str) -> None:
    if not isinstance(manifest, Mapping) or manifest.get("schema") != JOB_MANIFEST_SCHEMA:
        raise FtmoLaneError("unsupported job manifest")
    if manifest.get("lane") != lane or Path(str(manifest.get("lane_root", ""))).resolve() != _resolve_lane(lane):
        raise FtmoLaneError("job manifest is bound to another lane/root")
    name = manifest.get("execution_model", {}).get("name")
    if name not in EXECUTION_MODELS:
        raise FtmoLaneError("job has an unsupported execution model")
    expected_class = EXECUTION_MODELS[name]["evidence_class"]
    if manifest.get("evidence_class") != expected_class:
        raise FtmoLaneError("job evidence class/model mismatch")
    if int(manifest.get("max_concurrent", -1)) != MAX_FTMO_CONCURRENT:
        raise FtmoLaneError("job changed the FTMO concurrency cap")
    run_root = Path(str(manifest.get("run_root", ""))).resolve()
    if not _is_within(run_root, DEFAULT_OUTPUT_ROOT) or run_root == DEFAULT_OUTPUT_ROOT.resolve():
        raise FtmoLaneError("job run root escaped the isolated FTMO evidence root")
    artifact_contract = manifest.get("artifact_contract", {})
    for name in ("report", "q08_delta", "equity_delta", "run_receipt"):
        if not _is_within(Path(str(artifact_contract.get(name, ""))), run_root):
            raise FtmoLaneError(f"job artifact path escaped its run root: {name}")
    export_contract = manifest.get("export_contract", {})
    for name in ("summary", "stream", "receipt"):
        if not _is_within(Path(str(export_contract.get(name, ""))), run_root):
            raise FtmoLaneError(f"job export path escaped its run root: {name}")
    terminal_path = Path(str(manifest.get("bindings", {}).get("terminal_exe", {}).get("path", ""))).resolve()
    profile_path = Path(str(manifest.get("bindings", {}).get("server_profile", {}).get("path", ""))).resolve()
    lane_root = _resolve_lane(lane)
    if terminal_path != (lane_root / "terminal64.exe").resolve():
        raise FtmoLaneError("job terminal binding escaped its registered lane")
    if profile_path != (lane_root / "Config/common.ini").resolve():
        raise FtmoLaneError("job profile binding escaped its registered lane")
    for name, binding in manifest.get("bindings", {}).items():
        if not isinstance(binding, Mapping) or "path" not in binding or "sha256" not in binding:
            raise FtmoLaneError(f"job binding is malformed: {name}")
        expected = _assert_sha(binding["sha256"], f"bindings.{name}.sha256")
        if sha256_file(Path(str(binding["path"]))) != expected:
            raise FtmoLaneError(f"job binding drift: {name}")
    if not _is_within(Path(manifest["bindings"]["tester_ini"]["path"]), run_root):
        raise FtmoLaneError("job tester INI escaped its run root")
    rebinding = manifest.get("set_rebinding", {})
    for name in ("source", "derived"):
        binding = rebinding.get(name, {})
        expected = _assert_sha(binding.get("sha256", ""), f"set_rebinding.{name}.sha256")
        if sha256_file(Path(str(binding.get("path", "")))) != expected:
            raise FtmoLaneError(f"job set binding drift: {name}")
    if not _is_within(Path(rebinding["derived"]["path"]), run_root):
        raise FtmoLaneError("derived set escaped its run root")


def _claim_next(queue_root: Path, lane: str) -> tuple[Path, dict[str, Any]]:
    queue_root = queue_root.expanduser().resolve()
    pending = queue_root / "pending"
    active = queue_root / "active"
    active.mkdir(parents=True, exist_ok=True)
    for candidate in sorted(pending.glob("*.json")):
        manifest = load_json(candidate, "queued_manifest")
        if not isinstance(manifest, Mapping) or manifest.get("lane") != lane:
            continue
        target = active / candidate.name
        try:
            candidate.replace(target)
        except OSError:
            continue
        verify_job_binding(manifest, lane=lane)
        return target, dict(manifest)
    raise FtmoLaneError(f"no pending job for {lane}")


def _snapshot(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"exists": False, "size_bytes": 0, "sha256": None}
    return {"exists": True, "size_bytes": path.stat().st_size, "sha256": sha256_file(path)}


def _capture_full(path: Path, target: Path, before: Mapping[str, Any]) -> dict[str, Any]:
    if not path.is_file():
        raise FtmoLaneError(f"expected run artifact was not created: {path}")
    after = _snapshot(path)
    if after == dict(before):
        raise FtmoLaneError(f"run artifact did not change: {path}")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)
    return {"before": dict(before), "after": after, "captured": file_binding(target)}


def _capture_append_delta(path: Path, target: Path, before: Mapping[str, Any]) -> dict[str, Any]:
    if not path.is_file():
        raise FtmoLaneError(f"expected append log was not created: {path}")
    raw = path.read_bytes()
    offset = int(before.get("size_bytes", 0)) if before.get("exists") else 0
    if offset > len(raw):
        offset = 0
    delta = raw[offset:]
    if not delta:
        raise FtmoLaneError(f"append log has no run delta: {path}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(delta)
    return {"before": dict(before), "after": _snapshot(path), "captured": file_binding(target), "offset": offset}


def _validate_guard_delta(path: Path, native_symbol: str) -> dict[str, Any]:
    guard_rows: list[Mapping[str, Any]] = []
    violations = 0
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise FtmoLaneError(f"equity/log delta line {line_number}: invalid JSON") from exc
        if row.get("event") == "SYMBOL_GUARD_VIOLATION":
            violations += 1
        if row.get("event") == "SYMBOL_GUARD_INIT":
            payload = row.get("payload", {})
            if isinstance(payload, str):
                payload = json.loads(payload)
            if isinstance(payload, Mapping):
                guard_rows.append(payload)
    matches = [row for row in guard_rows if row.get("mode") == "single" and row.get("symbol") == native_symbol]
    if not matches or violations:
        raise FtmoLaneError("run does not prove a clean native single-symbol guard initialization")
    return {"event": "SYMBOL_GUARD_INIT", "mode": "single", "symbol": native_symbol, "violations": violations}


def _export_real_ticks(
    manifest: Mapping[str, Any], *, report: Path, q08_path: Path, equity_path: Path
) -> dict[str, Any]:
    """Build a non-Q run adapter and invoke the existing strict exporter."""

    try:
        from tools.strategy_farm.portfolio.ftmo_daily_net_export import (
            export_ftmo_daily_stream,
            parse_ftmo_report_identity,
        )
    except ImportError as exc:  # pragma: no cover - repository execution contract
        raise FtmoLaneError(f"cannot import FTMO daily exporter: {exc}") from exc

    if manifest.get("evidence_class") != "FTMO_REAL_TICKS":
        raise FtmoLaneError("daily exporter handoff refuses non-tick FTMO evidence")
    identity = parse_ftmo_report_identity(
        report, native_symbol=str(manifest["native_symbol"])
    )
    derived_set = Path(manifest["set_rebinding"]["derived"]["path"])
    summary_path = Path(manifest["export_contract"]["summary"])
    summary = {
        "evidence_schema": "run_smoke/v2",
        "result": "PASS",
        "claim": "FTMO_RESEARCH_RUN_ADAPTER_NOT_A_Q_PIPELINE_VERDICT",
        "ea_id": int(manifest["ea_id"]),
        "symbol": manifest["native_symbol"],
        "model": 4,
        "execution_identity": {
            "stable_during_run": True,
            "terminal_exe": manifest["bindings"]["terminal_exe"],
            "server_profile": manifest["bindings"]["server_profile"],
            "ex5": manifest["bindings"]["ex5"],
            "setfile": {"source": file_binding(derived_set)},
            "tester_ini": manifest["bindings"]["tester_ini"],
        },
        "runs": [
            {
                "run": "run_01",
                "status": "OK",
                "real_ticks_marker": True,
                "total_trades": int(identity["total_trades"]),
                "net_profit": float(identity["total_net_profit"]),
                "profit_factor": None,
                "drawdown": None,
                "report_canonical_path": str(report.resolve()),
                "report_sha256": sha256_file(report),
                "report_size_bytes": report.stat().st_size,
            }
        ],
    }
    atomic_write_json(summary_path, summary)
    output_path = Path(manifest["export_contract"]["stream"])
    export_receipt_path = Path(manifest["export_contract"]["receipt"])
    cost_snapshot = Path(manifest["bindings"]["cost_snapshot"]["path"])
    export_receipt = export_ftmo_daily_stream(
        sleeve_id=str(manifest["sleeve_id"]),
        symbol=str(manifest["evaluator_symbol"]),
        native_symbol=str(manifest["native_symbol"]),
        ftmo_code=str(manifest["ftmo_code"]),
        summary_path=summary_path,
        report_path=report,
        q08_trades_path=q08_path,
        equity_log_path=equity_path,
        cost_snapshot_path=cost_snapshot,
        setfile_path=derived_set,
        output_path=output_path,
        receipt_path=export_receipt_path,
        expected_cost_sha256=EXPECTED_COST_SNAPSHOT_SHA256,
    )
    return {
        "admissible": True,
        "producer": "tools/strategy_farm/portfolio/ftmo_daily_net_export.py",
        "status": "EXPORTED_AFTER_STRICT_VALIDATION",
        "summary": file_binding(summary_path),
        "stream": file_binding(output_path),
        "receipt": file_binding(export_receipt_path),
        "export_status": export_receipt.get("status"),
    }


def run_next(
    *,
    lane: str,
    queue_root: Path,
    common_files_root: Path,
    timeout_seconds: int,
    execute: bool,
) -> dict[str, Any]:
    if not execute:
        raise FtmoLaneError("run-next requires --execute after reviewer authorization")
    if queue_root.expanduser().resolve() != DEFAULT_QUEUE_ROOT.resolve():
        raise FtmoLaneError("queue root must be the isolated FTMO queue")
    if common_files_root.expanduser().resolve() != DEFAULT_COMMON_FILES.resolve():
        raise FtmoLaneError("FILE_COMMON root differs from the registered shared root")
    processes = scan_terminal_processes()
    capacity = capacity_observation(processes)
    if not capacity["permit"]:
        raise FtmoLaneError("capacity permit unavailable; active tests are never preempted")
    if any(
        re.search(
            rf"\\mt5\\{re.escape(lane)}\\terminal64\.exe$",
            str(row.get("ExecutablePath") or "").replace("/", "\\"),
            re.IGNORECASE,
        )
        for row in processes
    ):
        raise FtmoLaneError(f"{lane} already has an active terminal process")
    claimed_path, manifest = _claim_next(queue_root, lane)
    run_root = Path(manifest["run_root"])
    lane_root = _resolve_lane(lane)
    source_ex5 = Path(manifest["bindings"]["ex5"]["path"])
    staged_ex5 = lane_root / "MQL5/Experts" / manifest["staged_expert_relpath"]
    staged_ex5.parent.mkdir(parents=True, exist_ok=True)
    if staged_ex5.exists() and sha256_file(staged_ex5) != sha256_file(source_ex5):
        raise FtmoLaneError(f"refusing to overwrite a different staged EX5: {staged_ex5}")
    shutil.copyfile(source_ex5, staged_ex5)
    if sha256_file(staged_ex5) != manifest["bindings"]["ex5"]["sha256"]:
        raise FtmoLaneError("staged EX5 hash mismatch")

    ea_id = int(manifest["ea_id"])
    native_token = str(manifest["native_symbol"]).replace(".", "_")
    q08_source = common_files_root / "QM/q08_trades" / f"{ea_id}_{native_token}.jsonl"
    slug = source_ex5.stem.removeprefix(f"QM5_{ea_id}_")
    ea_log = lane_root / "MQL5/Logs/QM" / f"QM5_{ea_id:04d}_{slug}.log"
    q08_before = _snapshot(q08_source)
    log_before = _snapshot(ea_log)
    terminal = Path(manifest["bindings"]["terminal_exe"]["path"])
    tester_ini = Path(manifest["bindings"]["tester_ini"]["path"])
    command = [str(terminal), "/portable", f"/config:{tester_ini}"]
    started = utc_now()
    process = subprocess.Popen(command, cwd=str(lane_root))
    try:
        exit_code = process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired as exc:
        raise FtmoLaneError("FTMO tester timed out; runner did not preempt any other terminal") from exc
    if exit_code != 0:
        raise FtmoLaneError(f"FTMO terminal exited with code {exit_code}")
    report = Path(manifest["artifact_contract"]["report"])
    if not report.is_file():
        raise FtmoLaneError("FTMO tester did not produce the bound report")
    q08_capture = _capture_full(q08_source, Path(manifest["artifact_contract"]["q08_delta"]), q08_before)
    log_capture = _capture_append_delta(ea_log, Path(manifest["artifact_contract"]["equity_delta"]), log_before)
    q08_path = Path(manifest["artifact_contract"]["q08_delta"])
    equity_path = Path(manifest["artifact_contract"]["equity_delta"])
    guard = _validate_guard_delta(equity_path, manifest["native_symbol"])
    if manifest["execution_model"]["name"] == "REAL_TICKS":
        export_handoff = _export_real_ticks(
            manifest, report=report, q08_path=q08_path, equity_path=equity_path
        )
    else:
        export_handoff = {
            "admissible": False,
            "producer": "tools/strategy_farm/portfolio/ftmo_daily_net_export.py",
            "status": "REFUSED",
            "reason": "REFUSED_FTMO_M1_MODELLED_MERGE_WITH_TICK_LEVEL_STREAM",
        }
    receipt = {
        "schema": RUN_RECEIPT_SCHEMA,
        "status": "HARVESTED_NOT_A_Q_VERDICT",
        "started_at": started,
        "finished_at": utc_now(),
        "lane": lane,
        "job_id": manifest["job_id"],
        "sleeve_id": manifest["sleeve_id"],
        "execution_model": manifest["execution_model"],
        "evidence_class": manifest["evidence_class"],
        "bindings": {
            "manifest": file_binding(claimed_path),
            "terminal_exe": file_binding(terminal),
            "server_profile": file_binding(Path(manifest["bindings"]["server_profile"]["path"])),
            "ex5_source": file_binding(source_ex5),
            "ex5_staged": file_binding(staged_ex5),
            "set_source": manifest["set_rebinding"]["source"],
            "set_derived": manifest["set_rebinding"]["derived"],
            "tester_ini": file_binding(tester_ini),
            "report": file_binding(report),
        },
        "q08_delta": q08_capture,
        "equity_log_delta": log_capture,
        "symbol_guard": guard,
        "export_handoff": export_handoff,
        "claims": {"q_pipeline_verdict": "NONE", "live_authority": "NONE"},
    }
    receipt_path = Path(manifest["artifact_contract"]["run_receipt"])
    atomic_write_json(receipt_path, receipt)
    done = queue_root.expanduser().resolve() / "done"
    done.mkdir(parents=True, exist_ok=True)
    claimed_path.replace(done / claimed_path.name)
    return receipt


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    provision = sub.add_parser("provision-receipt", help="inspect one dedicated lane")
    provision.add_argument("--lane", required=True, choices=sorted(LANE_ROOTS))
    provision.add_argument("--root", type=Path)
    provision.add_argument("--history-observation", type=Path)
    provision.add_argument("--out", required=True, type=Path)
    provision.add_argument("--replace", action="store_true")

    prepare = sub.add_parser("prepare", help="prepare an isolated, fully gated campaign job")
    prepare.add_argument("--lane", required=True, choices=sorted(LANE_ROOTS))
    prepare.add_argument("--sleeve-id", required=True)
    prepare.add_argument("--ea-id", required=True, type=int)
    prepare.add_argument("--evaluator-symbol", required=True)
    prepare.add_argument("--source-symbol", required=True)
    prepare.add_argument("--native-symbol", required=True, choices=NATIVE_SYMBOLS)
    prepare.add_argument("--timeframe", required=True)
    prepare.add_argument("--from-date", required=True)
    prepare.add_argument("--to-date", required=True)
    prepare.add_argument("--execution-model", required=True, choices=sorted(EXECUTION_MODELS))
    prepare.add_argument("--ex5", required=True, type=Path)
    prepare.add_argument("--expected-ex5-sha256", required=True)
    prepare.add_argument("--setfile", required=True, type=Path)
    prepare.add_argument("--expected-set-sha256", required=True)
    prepare.add_argument("--provision-receipt", required=True, type=Path)
    prepare.add_argument("--symbol-probe", required=True, type=Path)
    prepare.add_argument("--cost-snapshot", required=True, type=Path)
    prepare.add_argument("--expected-cost-sha256", default=EXPECTED_COST_SNAPSHOT_SHA256)
    prepare.add_argument("--max-concurrent", required=True, type=int, choices=(MAX_FTMO_CONCURRENT,))
    prepare.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    prepare.add_argument("--queue-root", type=Path, default=DEFAULT_QUEUE_ROOT)

    run = sub.add_parser("run-next", help="claim and execute one reviewed isolated job")
    run.add_argument("--lane", required=True, choices=sorted(LANE_ROOTS))
    run.add_argument("--queue-root", type=Path, default=DEFAULT_QUEUE_ROOT)
    run.add_argument("--common-files-root", type=Path, default=DEFAULT_COMMON_FILES)
    run.add_argument("--timeout-seconds", type=int, default=14400)
    run.add_argument("--execute", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "provision-receipt":
            if args.out.expanduser().resolve().parent != DEFAULT_REPORT_STATE.resolve():
                raise FtmoLaneError("provision receipts must be written under D:/QM/reports/state")
            receipt = build_provision_receipt(
                args.lane,
                root_override=args.root,
                history_observation_path=args.history_observation,
            )
            atomic_write_json(args.out, receipt, replace=args.replace)
            print(_canonical_json(receipt), end="")
            return 0
        if args.command == "prepare":
            queued_path, manifest = prepare_job(
                lane=args.lane,
                sleeve_id=args.sleeve_id,
                ea_id=args.ea_id,
                evaluator_symbol=args.evaluator_symbol,
                source_symbol=args.source_symbol,
                native_symbol=args.native_symbol,
                timeframe=args.timeframe,
                from_date=_validate_iso_date(args.from_date, "from_date"),
                to_date=_validate_iso_date(args.to_date, "to_date"),
                execution_model=args.execution_model,
                ex5_path=args.ex5,
                expected_ex5_sha256=args.expected_ex5_sha256,
                setfile_path=args.setfile,
                expected_set_sha256=args.expected_set_sha256,
                provision_receipt_path=args.provision_receipt,
                symbol_probe_path=args.symbol_probe,
                cost_snapshot_path=args.cost_snapshot,
                expected_cost_sha256=args.expected_cost_sha256,
                max_concurrent=args.max_concurrent,
                output_root=args.output_root,
                queue_root=args.queue_root,
            )
            print(_canonical_json({"queued_manifest": str(queued_path), "job_id": manifest["job_id"]}), end="")
            return 0
        if args.command == "run-next":
            receipt = run_next(
                lane=args.lane,
                queue_root=args.queue_root,
                common_files_root=args.common_files_root,
                timeout_seconds=args.timeout_seconds,
                execute=args.execute,
            )
            print(_canonical_json(receipt), end="")
            return 0
    except FtmoLaneError as exc:
        print(f"REFUSED: {exc}", file=sys.stderr)
        return 2
    raise AssertionError(args.command)


if __name__ == "__main__":
    raise SystemExit(main())
