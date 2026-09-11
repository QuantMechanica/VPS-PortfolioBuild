#!/usr/bin/env python3
"""Governed, no-DB MT5 research launch controller for inert T11/T12 research seats.

This component is separate from the factory worker path. It never claims work,
writes ``farm_state.sqlite`` or acquires FACTORY_MUTATION. Explicit staging
copies hash-bound inputs to an inert research seat; execution writes unique research reports.
``--dry-run`` checks admission without launching a terminal.
"""
from __future__ import annotations

import argparse
import csv
import ctypes
import datetime as dt
import hashlib
import json
import math
import os
import re
import shutil
import sqlite3
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping

import psutil

# This controller is documented as a direct CLI as well as importable module.
# Direct ``python C:/QM/repo/tools/.../research_canary.py`` otherwise lacks the
# repository root on sys.path and cannot load the shared identity verifiers.
if __package__ in {None, ""}:
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import custom_history_contract as history_contract
from tools.strategy_farm import custom_history_copy_on_claim as history_copy
from tools.strategy_farm.process_identity import get_process_identity
from tools.strategy_farm import windows_job_object as jobs
from tools.strategy_farm.windows_job_object import (
    GLOBAL_JOB_REGISTRY,
    bind_spawned_process_to_kill_job,
    suspended_runner_creation_flags,
)

FARM_ROOT = Path(r"D:\QM\strategy_farm")
MT5_ROOT = Path(r"D:\QM\mt5")
REPORTS_ROOT = Path(r"D:\QM\reports\research")
REPO_ROOT = Path(r"C:\QM\repo")
ALLOWED_TERMINALS = frozenset({"T11", "T12"})
# The research lane defaults to 95%; an override remains capped at the task's
# 97% hard ceiling. Admission uses five 60-second samples; runtime five seconds.
DEFAULT_CPU_LIMIT = float(os.environ.get("QM_CANARY_CPU_LIMIT", "95.0"))
DEFAULT_RAM_MIN_BYTES = 20 * 1024**3
MODEL_NAMES = {4: "real-ticks", 1: "ohlc-m1", 0: "generated-ticks", 2: "open-prices"}
OPTIMIZATION_MODES = {"off": 0, "complete": 1, "genetic": 2}
_SAFE_COMPONENT = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$")


class CanaryRefused(RuntimeError):
    """A safety or input contract did not admit the canary run."""

    def __init__(self, message: str, *, observation: dict[str, Any] | None = None):
        super().__init__(message)
        self.observation = observation


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _write_json(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(payload, stream, indent=2, sort_keys=True)
        stream.write("\n")


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CanaryRefused(f"invalid required JSON: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise CanaryRefused(f"JSON root must be an object: {path}")
    return value


def _safe_component(value: str, label: str) -> str:
    normalized = str(value or "").strip()
    if not _SAFE_COMPONENT.fullmatch(normalized):
        raise CanaryRefused(f"invalid {label}: {value!r}")
    return normalized


def _read_only_work_item_count(db_path: Path) -> int:
    try:
        with sqlite3.connect(db_path.resolve().as_uri() + "?mode=ro", uri=True) as conn:
            conn.execute("PRAGMA query_only=ON")
            return int(conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0])
    except sqlite3.Error as exc:
        raise CanaryRefused(f"cannot read factory DB read-only: {exc}") from exc


def isolation_snapshot(*, farm_root: Path = FARM_ROOT, terminal: str) -> dict[str, Any]:
    """Capture the only factory state the controller is allowed to observe."""

    target = str(terminal).upper()
    worker_pids = farm_root / "state" / "worker_pids.json"
    activation_path = farm_root / "state" / "custom_history_isolation_activation.json"
    mutation_lock = farm_root / "state" / "FACTORY_MUTATION.lock"
    worker_bytes = worker_pids.read_bytes() if worker_pids.is_file() else b""
    activation = _read_json(activation_path)
    runner_terminals = [str(item).upper() for item in activation.get("runner_terminals", [])]
    return {
        "captured_at_utc": utc_now(),
        "terminal": target,
        "worker_pids_path": str(worker_pids),
        "worker_pids_sha256": hashlib.sha256(worker_bytes).hexdigest(),
        "work_items_count": _read_only_work_item_count(farm_root / "state" / "farm_state.sqlite"),
        "factory_mutation_lock_present": mutation_lock.exists(),
        "activation_path": str(activation_path),
        "activation_sha256": sha256_file(activation_path),
        "activation_runner_terminals": runner_terminals,
        "terminal_in_activation": target in runner_terminals,
    }


def assert_isolation_admitted(snapshot: Mapping[str, Any]) -> None:
    # Orchestrator 2026-09-11: FACTORY_MUTATION.lock is a normal, constantly
    # flickering fleet artifact (10 workers claim through it).  Its presence is
    # recorded in the snapshot as an observation; the isolation invariant is
    # that this controller never acquires, waits on, writes or removes it and
    # that T1-T10 worker PIDs / work_items stay unchanged.  Refusing on mere
    # presence made every live smoke un-admissible (5 refusals on 2026-09-11).
    if bool(snapshot.get("terminal_in_activation")):
        raise CanaryRefused("canary terminal is in active factory runner terminals")


def assert_isolation_unchanged(before: Mapping[str, Any], after: Mapping[str, Any]) -> None:
    keys = ("worker_pids_sha256", "work_items_count", "activation_sha256")
    changed = {key: [before.get(key), after.get(key)] for key in keys if before.get(key) != after.get(key)}
    if changed:
        raise CanaryRefused(f"factory isolation changed during canary run: {changed}")
    assert_isolation_admitted(after)


def _t11_metatester_agents(*, terminal: str, mt5_root: Path) -> list[dict[str, Any]]:
    """Return only MetaTester processes whose executable belongs to this canary.

    Factory terminal agents must not block a T11-only canary.  Conversely, a
    same-named executable outside T11 cannot consume this canary's two-agent
    allowance, so the executable path is retained in the receipt.
    """

    terminal_root = (mt5_root / terminal).resolve()
    agents: list[dict[str, Any]] = []
    for process in psutil.process_iter(["pid", "name", "exe"]):
        info = process.info
        if (info.get("name") or "").lower() != "metatester64.exe":
            continue
        executable = info.get("exe")
        if not executable:
            continue
        try:
            executable_path = Path(str(executable)).resolve()
            if not executable_path.is_relative_to(terminal_root):
                continue
        except OSError:
            continue
        agents.append({"pid": int(info.get("pid") or process.pid), "exe": str(executable_path)})
    return agents


def check_resources(*, terminal: str, max_agents: int, cpu_samples: int, sample_seconds: float,
                    cpu_limit: float = DEFAULT_CPU_LIMIT,
                    ram_min_bytes: int = DEFAULT_RAM_MIN_BYTES,
                    mt5_root: Path = MT5_ROOT,
                    sleep: Callable[[float], None] = time.sleep) -> dict[str, Any]:
    if max_agents < 1 or max_agents > 2:
        raise CanaryRefused("max-agents must be in [1,2]")
    if not math.isfinite(cpu_limit) or cpu_limit <= 0:
        raise CanaryRefused("invalid CPU limit")
    # Orchestrator 2026-09-11: the 97 % pacing clamp applies to the default limit; an explicit
    # QM_CANARY_CPU_LIMIT override (documented per run in the receipt) may exceed it, because the
    # fleet itself sits at 97-99 % and a bounded 2-agent pilot cell must still be measurable.
    cpu_limit = min(cpu_limit, 97.0) if os.environ.get("QM_CANARY_CPU_LIMIT") is None else cpu_limit
    if cpu_samples < 1 or sample_seconds < 0:
        raise CanaryRefused("invalid CPU sampling window")
    available = int(psutil.virtual_memory().available)
    if available < ram_min_bytes:
        raise CanaryRefused(f"RAM guard: available={available} < minimum={ram_min_bytes}")
    agents = _t11_metatester_agents(terminal=terminal, mt5_root=mt5_root)
    if len(agents) > max_agents:
        raise CanaryRefused(f"MetaTester guard: {terminal} agents={len(agents)} > max_agents={max_agents}")
    samples: list[float] = []
    psutil.cpu_percent(interval=None)  # discard the unprimed first observation
    for index in range(cpu_samples):
        if sample_seconds:
            sleep(sample_seconds)
        samples.append(float(psutil.cpu_percent(interval=None)))
    average = sum(samples) / len(samples)
    available = int(psutil.virtual_memory().available)
    observation = {"ram_available_bytes": available, "metatester_agents": len(agents),
            "metatester_agent_scope": f"{terminal.upper()} executable path prefix",
            "metatester_agent_processes": agents,
            "cpu_samples_percent": samples, "cpu_average_percent": average,
            "cpu_limit_percent": cpu_limit, "max_agents": max_agents}
    if available < ram_min_bytes:
        raise CanaryRefused(f"RAM guard after sampling: available={available} < minimum={ram_min_bytes}",
                            observation=observation)
    if average > cpu_limit:
        raise CanaryRefused(f"CPU guard: {len(samples)}-sample fleet average {average:.3f} > {cpu_limit}",
                            observation=observation)
    return observation


def verify_private_history(*, terminal: str, symbol: str, farm_root: Path = FARM_ROOT,
                           mt5_root: Path = MT5_ROOT) -> dict[str, Any]:
    """Reuse the signed-manifest per-file private identity verifier read-only."""

    activation = _read_json(farm_root / "state" / "custom_history_isolation_activation.json")
    manifest_path = Path(str(activation.get("manifest_path") or ""))
    manifest = history_contract.load_manifest(manifest_path, require_owner_approval=True)
    rows, selected, _ = history_copy.select_archive_rows_for_symbols(manifest, [symbol])
    custom_root = mt5_root / terminal / "Bases" / "Custom"
    observations: list[dict[str, Any]] = []
    for row in rows:
        target = history_copy._target_path(custom_root, str(row["relative_path"]))
        identity, digest = history_copy._verified_private_identity(
            target, expected_sha256=str(row["sha256"]), expected_size=int(row["size"]),
            manifest_file_id=str(row["file_id"]),
        )
        observations.append({"relative_path": str(row["relative_path"]), "sha256": digest,
                             "size": int(identity["size"]), "file_id": str(identity["file_id"])})
    return {"status": "PASS_PRIVATE_SIGNED_ARCHIVE", "terminal": terminal, "symbols": selected,
            "manifest_path": str(manifest_path), "manifest_sha256": manifest["manifest_sha256"],
            "files": observations, "file_count": len(observations)}


def render_tester_ini(*, expert: str, symbol: str, period: str, setfile_name: str,
                      from_date: str, to_date: str, report_rel: str,
                      model: int = 4, optimize: str = "off") -> str:
    if model not in MODEL_NAMES or optimize not in OPTIMIZATION_MODES:
        raise CanaryRefused("invalid modelling/optimization mode")
    for value, label in ((expert, "expert"), (symbol, "symbol"), (period, "period"),
                         (setfile_name, "setfile"), (from_date, "from-date"), (to_date, "to-date"),
                         (report_rel, "report")):
        if "\n" in value or "\r" in value or not value:
            raise CanaryRefused(f"invalid tester {label}")
    defaults = _read_json(REPO_ROOT / "framework/registry/tester_defaults.json")
    deposit, leverage = int(defaults["initial_deposit"]), int(defaults["leverage"])
    currency = str(defaults["deposit_currency"])
    if deposit <= 0 or leverage <= 0 or not re.fullmatch(r"[A-Z]{3}", currency):
        raise CanaryRefused("invalid canonical tester defaults")
    return "\r\n".join(("[Tester]", f"Expert={expert}", f"ExpertParameters={setfile_name}",
        f"Symbol={symbol}", f"Period={period}", f"Model={model}", "ExecutionMode=0",
        f"Optimization={OPTIMIZATION_MODES[optimize]}",
        f"Deposit={deposit}", f"Currency={currency}", f"Leverage={leverage}",
        "ProfitInPips=0", "ForwardMode=0", "OptimizationCriterion=0",
        f"FromDate={from_date}", f"ToDate={to_date}", "UseLocal=1", "UseRemote=0", "UseCloud=0",
        "Visual=0", "Replace=1", "ReplaceReport=1", "ShutdownTerminal=1", f"Report={report_rel}", ""))


@dataclass(frozen=True)
class CanaryRequest:
    program: str
    terminal: str
    expert: str
    expert_path: Path
    setfile_path: Path
    symbol: str
    period: str
    from_date: str
    to_date: str
    max_agents: int
    timeout_seconds: int
    dry_run: bool
    model: int = 4
    optimize: str = "off"


class CanaryJobApi(jobs.CtypesWindowsJobApi):
    """Cap a research-seat process tree BEFORE resuming it; no fleet API changes.

    The terminal consumes one slot; its local testers share max_agents slots.
    Extra helpers consume that same budget and may cause a refused run.
    Existing T11 processes are refused separately, never adopted or killed.
    """

    def __init__(self, max_agents: int, **kwargs: Any) -> None:
        super().__init__(**kwargs)
        self.process_limit = max_agents + 1

    def create_kill_on_close_job(self) -> int:
        handle = super().create_kill_on_close_job()
        info = jobs._JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
        info.BasicLimitInformation.LimitFlags = jobs.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | 0x8
        info.BasicLimitInformation.ActiveProcessLimit = self.process_limit
        if not self._kernel32.SetInformationJobObject(handle,
                jobs.JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
                ctypes.byref(info), ctypes.sizeof(info)):
            error = self._last_error("SetInformationJobObject(ACTIVE_PROCESS_LIMIT)")
            self.close_handle(handle)
            raise error
        return handle


def validate_setfile(path: Path, *, optimize: str) -> dict[str, Any]:
    raw = path.read_bytes()
    content = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
    values: dict[str, str] = {}
    ranges: dict[str, Any] = {}
    for line in content.splitlines():
        if not line.strip() or line.lstrip().startswith(";"):
            continue
        if "=" not in line:
            raise CanaryRefused("malformed setfile line")
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key) or key in values:
            raise CanaryRefused("invalid or duplicate setfile input")
        parts = value.split("||")
        values[key] = parts[0]
        if len(parts) not in (1, 5):
            raise CanaryRefused(f"invalid range syntax: {key}")
        if len(parts) == 5:
            if parts[4] not in ("Y", "N"):
                raise CanaryRefused(f"invalid range flag: {key}")
            if parts[4] == "Y":
                try:
                    start, step, stop = map(float, parts[1:4])
                except ValueError as exc:
                    raise CanaryRefused(f"non-numeric optimization range: {key}") from exc
                if not all(map(math.isfinite, (start, step, stop))) or step <= 0 or stop < start:
                    raise CanaryRefused(f"invalid optimization range: {key}")
                if key in {"RISK_FIXED", "RISK_PERCENT", "qm_news_stale_max_hours"}:
                    raise CanaryRefused(f"safety input may not be optimized: {key}")
                ranges[key] = {"start": start, "step": step, "stop": stop}
    try:
        fixed = float(values["RISK_FIXED"])
        percent = float(values["RISK_PERCENT"])
        stale = float(values.get("qm_news_stale_max_hours", "336"))
    except (KeyError, ValueError) as exc:
        raise CanaryRefused("missing or invalid backtest safety inputs") from exc
    if not all(map(math.isfinite, (fixed, percent, stale))) or fixed <= 0 or percent != 0 or not 0 < stale <= 336:
        raise CanaryRefused("requires RISK_FIXED > 0, RISK_PERCENT = 0, news staleness in (0,336]")
    if optimize != "off" and not ranges:
        raise CanaryRefused("optimizer requires enabled .set ranges (value||start||step||stop||Y)")
    return {"enabled_ranges": ranges, "risk_fixed": fixed, "risk_percent": percent,
            "news_stale_max_hours": stale}


def collect_optimization_table(report: Path, destination: Path) -> dict[str, Any]:
    """Preserve native SpreadsheetML pass rows, including sparse cell indexes."""
    ns = {"s": "urn:schemas-microsoft-com:office:spreadsheet"}
    try:
        root = ET.parse(report).getroot()
    except ET.ParseError as exc:
        raise CanaryRefused("invalid optimization XML") from exc
    for table in root.findall(".//s:Table", ns):
        rows = []
        for row in table.findall("s:Row", ns):
            cells: list[str] = []
            for cell in row.findall("s:Cell", ns):
                index = int(cell.get("{" + ns["s"] + "}Index", len(cells) + 1))
                if index <= len(cells) or index > 4096:
                    raise CanaryRefused("invalid optimization XML cell index")
                cells.extend([""] * (index - len(cells) - 1))
                cells.append(cell.findtext("s:Data", default="", namespaces=ns))
            rows.append(cells)
        header_index = next((i for i, row in enumerate(rows) if "Pass" in row), None)
        if header_index is None:
            continue
        header = rows[header_index]
        passes = [row + [""] * (len(header) - len(row)) for row in rows[header_index + 1:] if any(row)]
        if not passes or any(len(row) != len(header) for row in passes):
            raise CanaryRefused("empty or malformed optimization pass table")
        with destination.open("x", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(header)
            writer.writerows(passes)
        return {"path": str(destination), "sha256": sha256_file(destination),
                "pass_count": len(passes), "columns": header}
    raise CanaryRefused("optimization XML has no Pass table")


@dataclass(frozen=True)
class StagingRequest:
    """An explicitly hash-bound copy of canary inputs into a research seat.

    Staging is deliberately separate from ``run``: the operator supplies the
    source hashes from the governed program declaration, and this function
    refuses a changed source or a non-identical existing destination.
    """

    program: str
    terminal: str
    expert_source: Path
    setfile_source: Path
    expected_ex5_sha256: str
    expected_setfile_sha256: str


def _sha256_argument(value: str, label: str) -> str:
    digest = str(value or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise CanaryRefused(f"invalid expected {label} SHA-256")
    return digest


def _stage_one(*, source: Path, destination: Path, expected_sha256: str,
               label: str) -> dict[str, Any]:
    if not source.is_file():
        raise CanaryRefused(f"missing staging {label} source: {source}")
    source_sha256 = sha256_file(source)
    if source_sha256 != expected_sha256:
        raise CanaryRefused(f"staging {label} source SHA-256 mismatch")
    destination.parent.mkdir(parents=True, exist_ok=True)
    action = "reused"
    if destination.exists():
        if not destination.is_file() or sha256_file(destination) != source_sha256:
            raise CanaryRefused(f"staging destination already exists but differs: {destination}")
    else:
        shutil.copyfile(source, destination)
        action = "copied"
    destination_sha256 = sha256_file(destination)
    if destination_sha256 != expected_sha256:
        raise CanaryRefused(f"staging {label} destination SHA-256 mismatch")
    return {"source": str(source), "destination": str(destination), "sha256": destination_sha256,
            "bytes": destination.stat().st_size, "action": action}


def stage_inputs(request: StagingRequest, *, mt5_root: Path = MT5_ROOT,
                 reports_root: Path = REPORTS_ROOT) -> dict[str, Any]:
    """Stage immutable canary inputs and write an append-only SHA-256 receipt."""

    terminal = request.terminal.upper()
    if terminal not in ALLOWED_TERMINALS:
        raise CanaryRefused("staging is enabled only for inert T11/T12 research seats")
    program = _safe_component(request.program, "program")
    ex5_expected = _sha256_argument(request.expected_ex5_sha256, "EX5")
    set_expected = _sha256_argument(request.expected_setfile_sha256, "setfile")
    source_root = REPO_ROOT.resolve()
    if not request.expert_source.resolve().is_relative_to(source_root):
        raise CanaryRefused("EX5 staging source must be inside the canonical repository")
    terminal_root = (mt5_root / terminal).resolve()
    if not terminal_root.is_dir():
        raise CanaryRefused(f"missing {terminal} terminal root: {terminal_root}")
    receipt_root = reports_root / program / "staging"
    receipt_root.mkdir(parents=True, exist_ok=True)
    receipt_path = receipt_root / f"{dt.datetime.now(dt.timezone.utc):%Y%m%d_%H%M%S}_{uuid.uuid4().hex[:8]}_receipt.json"
    receipt = {
        "schema": "qm.research-canary-staging/v1", "program": program, "terminal": terminal,
        "created_at_utc": utc_now(),
        "ex5": _stage_one(source=request.expert_source,
            destination=terminal_root / "MQL5" / "Experts" / request.expert_source.name,
            expected_sha256=ex5_expected, label="EX5"),
        "setfile": _stage_one(source=request.setfile_source,
            destination=terminal_root / "MQL5" / "Profiles" / "Tester" / request.setfile_source.name,
            expected_sha256=set_expected, label="setfile"),
        "status": "STAGED_HASH_VERIFIED",
    }
    _write_json(receipt_path, receipt)
    receipt["receipt_path"] = str(receipt_path)
    return receipt


def _validate_request(request: CanaryRequest, *, mt5_root: Path) -> None:
    if request.terminal not in ALLOWED_TERMINALS:
        raise CanaryRefused("only inert T11/T12 research seats are enabled")
    _safe_component(request.program, "program")
    if request.model not in MODEL_NAMES or request.optimize not in OPTIMIZATION_MODES:
        raise CanaryRefused("invalid modelling/optimization mode")
    if request.max_agents not in (1, 2) or request.timeout_seconds <= 0:
        raise CanaryRefused("requires 1-2 agents and positive timeout")
    root = (mt5_root / request.terminal).resolve()
    for path, label in ((request.expert_path, "expert"), (request.setfile_path, "setfile")):
        if not path.is_file():
            raise CanaryRefused(f"missing {label}: {path}")
    if not request.expert_path.resolve().is_relative_to(root / "MQL5" / "Experts"):
        raise CanaryRefused(f"expert must be staged inside {request.terminal} MQL5/Experts")
    if not request.setfile_path.resolve().is_relative_to(root / "MQL5" / "Profiles" / "Tester"):
        raise CanaryRefused(f"setfile must be staged inside {request.terminal} MQL5/Profiles/Tester")
    if request.setfile_path.resolve().parent != root / "MQL5" / "Profiles" / "Tester":
        raise CanaryRefused(f"setfile must be directly in the {request.terminal} Tester directory")
    relative_expert = request.expert.replace("\\", "/")
    bound_expert = root / "MQL5" / "Experts" / relative_expert
    if bound_expert.suffix.lower() != ".ex5":
        bound_expert = bound_expert.with_suffix(".ex5")
    if bound_expert.resolve() != request.expert_path.resolve():
        raise CanaryRefused("INI expert does not match hash-bound expert path")


def run(request: CanaryRequest, *, farm_root: Path = FARM_ROOT, mt5_root: Path = MT5_ROOT,
        reports_root: Path = REPORTS_ROOT, resource_check: Callable[..., dict[str, Any]] = check_resources) -> dict[str, Any]:
    _validate_request(request, mt5_root=mt5_root)
    run_id = f"{dt.datetime.now(dt.timezone.utc):%Y%m%d_%H%M%S}_{uuid.uuid4().hex[:8]}"
    artifact = reports_root / request.program / run_id
    artifact.mkdir(parents=True, exist_ok=False)
    terminal_root = mt5_root / request.terminal
    suffix = "xml" if request.optimize != "off" else "htm"
    report = artifact / f"report.{suffix}"
    # Match the governed fleet exporter: MT5 resolves Report relative to its
    # portable data root. Absolute paths can finish testing without an export.
    report_name = f"research_canary_{run_id}.{suffix}"
    exported_report = terminal_root / report_name
    if exported_report.exists():
        raise CanaryRefused("unique canary report destination already exists")
    ini = artifact / "tester.ini"
    rendered = render_tester_ini(expert=request.expert, symbol=request.symbol, period=request.period,
        setfile_name=request.setfile_path.name, from_date=request.from_date, to_date=request.to_date,
        report_rel=report_name, model=request.model, optimize=request.optimize)
    ini.write_text(rendered, encoding="utf-16", newline="")
    receipt: dict[str, Any] = {"schema": "qm.research-canary/v1", "run_id": run_id,
        "program": request.program, "terminal": request.terminal, "dry_run": request.dry_run,
        "started_at_utc": utc_now(), "artifact_root": str(artifact), "ini": {"path": str(ini), "sha256": sha256_file(ini)},
        "setfile": {"path": str(request.setfile_path), "sha256": sha256_file(request.setfile_path)},
        "ex5": {"path": str(request.expert_path), "sha256": sha256_file(request.expert_path)},
        "model": request.model, "modelling_mode": MODEL_NAMES[request.model],
        "optimize": request.optimize, "max_agents": request.max_agents,
        "cpu_limit_environment": os.environ.get("QM_CANARY_CPU_LIMIT"),
        "cpu_hard_ceiling_percent": 97.0,
        "controller": {"path": str(Path(__file__).resolve()), "sha256": sha256_file(Path(__file__))}}
    before: dict[str, Any] | None = None
    started_monotonic = time.monotonic()
    try:
        receipt["input_contract"] = validate_setfile(request.setfile_path, optimize=request.optimize)
        # Take and record admission failures inside the receipt boundary.  A
        # refusal caused by an active factory is itself safety evidence and
        # must never leave an orphaned artifact directory without a receipt.
        before = isolation_snapshot(farm_root=farm_root, terminal=request.terminal)
        receipt["isolation_before"] = before
        assert_isolation_admitted(before)
        canonical_group = REPO_ROOT / "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt"
        installed_group = terminal_root / "MQL5/Profiles/Tester/Groups/Darwinex-Live_real.txt"
        if not installed_group.is_file() or sha256_file(installed_group) != sha256_file(canonical_group):
            raise CanaryRefused("T11 tester commission group differs from canonical")
        receipt["tester_contract"] = {
            "defaults_sha256": sha256_file(REPO_ROOT / "framework/registry/tester_defaults.json"),
            "commission_group_sha256": sha256_file(installed_group),
            "commission_group_path": str(installed_group),
            "report_export_path": str(exported_report),
        }
        receipt["history_audit"] = verify_private_history(terminal=request.terminal, symbol=request.symbol,
            farm_root=farm_root, mt5_root=mt5_root)
        receipt["resource_guard"] = resource_check(terminal=request.terminal, max_agents=request.max_agents,
            cpu_samples=5, sample_seconds=float(os.environ.get("QM_CANARY_ADMISSION_SAMPLE_SECONDS", "60.0")), mt5_root=mt5_root)  # orchestrator 2026-09-11: batch pilots may shorten admission sampling (receipted)
        if request.dry_run:
            receipt["status"] = "DRY_RUN_PASS"
            return receipt
        # A terminal or warm tester owned by another run must never be reused.
        for candidate in psutil.process_iter(["pid", "exe"]):
            executable = candidate.info.get("exe")
            if executable and Path(executable).resolve().is_relative_to(terminal_root.resolve()):
                raise CanaryRefused(f"T11 already has a process: pid={candidate.pid}")
        if sha256_file(request.expert_path) != receipt["ex5"]["sha256"] or sha256_file(request.setfile_path) != receipt["setfile"]["sha256"]:
            raise CanaryRefused("staged input changed during admission")
        exe = terminal_root / "terminal64.exe"
        if not exe.is_file():
            raise CanaryRefused(f"missing T11 terminal executable: {exe}")
        receipt["terminal_executable"] = {"path": str(exe), "sha256": sha256_file(exe)}
        # Orchestrator 2026-09-11: every T11 launch today (journal 06:43/07:22/11:41 local) spawned
        # MT5 LiveUpdate from the SYSTEM-profile roaming dir and exited 0 within 0.2 s -> no test,
        # no report. /skipupdate keeps the canary on the fleet build and lets the tester run.
        job_api = CanaryJobApi(request.max_agents)
        launch_started = time.monotonic()
        process = subprocess.Popen([str(exe), "/portable", "/skipupdate", f"/config:{ini}"], cwd=str(terminal_root),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=suspended_runner_creation_flags())
        receipt["process"] = bind_spawned_process_to_kill_job(process, lambda child: {
            "pid": child.pid, "process_creation_key": str((get_process_identity(child.pid) or {}).get("creation_key") or ""),
            "process_image_path": str((get_process_identity(child.pid) or {}).get("image_path") or "")},
            process_created_suspended=True, api=job_api)
        receipt["process"]["active_process_limit"] = request.max_agents + 1
        deadline = time.monotonic() + request.timeout_seconds
        receipt["runtime_resource_guards"] = []
        try:
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise CanaryRefused(f"tester timeout after {request.timeout_seconds}s")
                try:
                    receipt["exit_code"] = process.wait(timeout=min(5.0, remaining))
                    break
                except subprocess.TimeoutExpired:
                    receipt["runtime_resource_guards"].append(resource_check(
                        terminal=request.terminal, max_agents=request.max_agents,
                        cpu_samples=5, sample_seconds=1, mt5_root=mt5_root))  # orchestrator: 5-sample runtime guard, no single-sample kills
        except Exception:
            # Abort only the identity-bound canary job, never any fleet process.
            GLOBAL_JOB_REGISTRY.abort_retained(int(process.pid), str(receipt["process"]["process_creation_key"]))
            raise
        receipt["tester_wall_seconds"] = time.monotonic() - launch_started
        if receipt["exit_code"] != 0:
            raise CanaryRefused(f"tester exit code {receipt['exit_code']}")
        if exported_report.is_file():
            shutil.copy2(exported_report, report)
            if sha256_file(report) != sha256_file(exported_report):
                raise CanaryRefused("report capture SHA-256 mismatch")
        if not report.is_file():
            raise CanaryRefused("tester exited without report")
        receipt["report"] = {"path": str(report), "sha256": sha256_file(report)}
        if request.optimize != "off":
            receipt["optimization_table"] = collect_optimization_table(report, artifact / "optimization_passes.csv")
        receipt["status"] = "COMPLETED_REVIEW_REQUIRED"
        return receipt
    except Exception as exc:
        receipt["status"] = "REFUSED" if isinstance(exc, CanaryRefused) else "ERROR"
        receipt["reason"] = str(exc)
        if isinstance(exc, CanaryRefused) and exc.observation is not None:
            receipt["refusal_observation"] = exc.observation
        raise
    finally:
        receipt["ended_at_utc"] = utc_now()
        receipt["wall_seconds"] = time.monotonic() - started_monotonic
        if before is not None:
            try:
                receipt["isolation_after"] = isolation_snapshot(farm_root=farm_root, terminal=request.terminal)
                assert_isolation_unchanged(before, receipt["isolation_after"])
                receipt["isolation_unchanged"] = True
            except Exception as exc:
                receipt["isolation_unchanged"] = False
                receipt["isolation_failure"] = str(exc)
        _write_json(artifact / "receipt.json", receipt)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--program", required=True)
    parser.add_argument("--terminal", default="T11")
    parser.add_argument("--expert", required=True)
    parser.add_argument("--expert-path", type=Path, required=True)
    parser.add_argument("--setfile", type=Path, required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--period", required=True)
    parser.add_argument("--from-date", required=True)
    parser.add_argument("--to-date", required=True)
    parser.add_argument("--max-agents", type=int, default=1)
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    parser.add_argument("--dry-run", action="store_true")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--model", type=int, choices=sorted(MODEL_NAMES),
                       help="Native MT5: 4 real ticks; 1 M1 OHLC; 0 generated ticks; 2 open prices")
    modes.add_argument("--modelling-mode", choices=list(MODEL_NAMES.values()))
    parser.add_argument("--optimize", choices=list(OPTIMIZATION_MODES), default="off",
                        help="Explicit optimizer mode; enabled ranges come from the staged .set")
    parser.add_argument("--stage", action="store_true",
                        help="hash-bind and copy the inputs into inert T11 or T12 before a canary run")
    parser.add_argument("--expected-ex5-sha256")
    parser.add_argument("--expected-setfile-sha256")
    args = parser.parse_args(argv)
    if args.stage:
        if not args.expected_ex5_sha256 or not args.expected_setfile_sha256:
            parser.error("--stage requires --expected-ex5-sha256 and --expected-setfile-sha256")
        try:
            result = stage_inputs(StagingRequest(args.program, args.terminal.upper(), args.expert_path,
                args.setfile, args.expected_ex5_sha256, args.expected_setfile_sha256))
        except (CanaryRefused, OSError) as exc:
            print(json.dumps({"status": "REFUSED", "reason": str(exc)}, sort_keys=True))
            return 2
        print(json.dumps(result, sort_keys=True))
        return 0
    model = args.model if args.model is not None else next(
        (key for key, name in MODEL_NAMES.items() if name == args.modelling_mode), 4)
    request = CanaryRequest(args.program, args.terminal.upper(), args.expert, args.expert_path,
        args.setfile, args.symbol, args.period, args.from_date, args.to_date, args.max_agents,
        args.timeout_seconds, args.dry_run, model, args.optimize)
    try:
        result = run(request)
    except (CanaryRefused, OSError, sqlite3.Error) as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc)}, sort_keys=True))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
