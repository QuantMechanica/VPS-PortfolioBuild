#!/usr/bin/env python3
"""Governed, no-DB MT5 research launch controller for the inert T11 canary.

This component is deliberately separate from the factory worker path.  It
never claims work, writes ``farm_state.sqlite``, acquires FACTORY_MUTATION, or
changes a terminal configuration.  Its only mutable scope is a new, uniquely
named research artifact directory.  ``--dry-run`` is the normal safe mode.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import time
import uuid
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
PRIMARY_TERMINAL = "T11"
DEFAULT_CPU_LIMIT = 90.0
DEFAULT_RAM_MIN_BYTES = 20 * 1024**3
_SAFE_COMPONENT = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$")


class CanaryRefused(RuntimeError):
    """A safety or input contract did not admit the canary run."""


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
    if bool(snapshot.get("factory_mutation_lock_present")):
        raise CanaryRefused("FACTORY_MUTATION.lock is present")
    if bool(snapshot.get("terminal_in_activation")):
        raise CanaryRefused("canary terminal is in active factory runner terminals")


def assert_isolation_unchanged(before: Mapping[str, Any], after: Mapping[str, Any]) -> None:
    keys = ("worker_pids_sha256", "work_items_count", "factory_mutation_lock_present")
    changed = {key: [before.get(key), after.get(key)] for key in keys if before.get(key) != after.get(key)}
    if changed:
        raise CanaryRefused(f"factory isolation changed during canary run: {changed}")
    assert_isolation_admitted(after)


def check_resources(*, max_agents: int, cpu_samples: int, sample_seconds: float,
                    cpu_limit: float = DEFAULT_CPU_LIMIT,
                    ram_min_bytes: int = DEFAULT_RAM_MIN_BYTES,
                    sleep: Callable[[float], None] = time.sleep) -> dict[str, Any]:
    if max_agents < 1 or max_agents > 4:
        raise CanaryRefused("max-agents must be in [1,4]")
    if cpu_samples < 1 or sample_seconds < 0:
        raise CanaryRefused("invalid CPU sampling window")
    available = int(psutil.virtual_memory().available)
    if available < ram_min_bytes:
        raise CanaryRefused(f"RAM guard: available={available} < minimum={ram_min_bytes}")
    agents = sum(1 for p in psutil.process_iter(["name"]) if (p.info.get("name") or "").lower() == "metatester64.exe")
    if agents >= max_agents:
        raise CanaryRefused(f"MetaTester guard: agents={agents} >= max_agents={max_agents}")
    samples: list[float] = []
    for index in range(cpu_samples):
        samples.append(float(psutil.cpu_percent(interval=None)))
        if index + 1 < cpu_samples and sample_seconds:
            sleep(sample_seconds)
    average = sum(samples) / len(samples)
    if average > cpu_limit:
        raise CanaryRefused(f"CPU guard: {len(samples)}-sample fleet average {average:.3f} > {cpu_limit}")
    return {"ram_available_bytes": available, "metatester_agents": agents,
            "cpu_samples_percent": samples, "cpu_average_percent": average,
            "cpu_limit_percent": cpu_limit, "max_agents": max_agents}


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
                      from_date: str, to_date: str, report_rel: str) -> str:
    for value, label in ((expert, "expert"), (symbol, "symbol"), (period, "period"),
                         (setfile_name, "setfile"), (from_date, "from-date"), (to_date, "to-date")):
        if "\n" in value or "\r" in value or not value:
            raise CanaryRefused(f"invalid tester {label}")
    return "\r\n".join(("[Tester]", f"Expert={expert}", f"ExpertParameters={setfile_name}",
        f"Symbol={symbol}", f"Period={period}", "Model=4", "ExecutionMode=0", "Optimization=0",
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


@dataclass(frozen=True)
class StagingRequest:
    """An explicitly hash-bound, T11-only copy of canary inputs.

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

    if request.terminal.upper() != PRIMARY_TERMINAL:
        raise CanaryRefused("staging is enabled only for inert T11")
    program = _safe_component(request.program, "program")
    ex5_expected = _sha256_argument(request.expected_ex5_sha256, "EX5")
    set_expected = _sha256_argument(request.expected_setfile_sha256, "setfile")
    source_root = REPO_ROOT.resolve()
    if not request.expert_source.resolve().is_relative_to(source_root):
        raise CanaryRefused("EX5 staging source must be inside the canonical repository")
    terminal_root = (mt5_root / PRIMARY_TERMINAL).resolve()
    if not terminal_root.is_dir():
        raise CanaryRefused(f"missing T11 terminal root: {terminal_root}")
    receipt_root = reports_root / program / "staging"
    receipt_root.mkdir(parents=True, exist_ok=True)
    receipt_path = receipt_root / f"{dt.datetime.now(dt.timezone.utc):%Y%m%d_%H%M%S}_{uuid.uuid4().hex[:8]}_receipt.json"
    receipt = {
        "schema": "qm.research-canary-staging/v1", "program": program, "terminal": PRIMARY_TERMINAL,
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
    if request.terminal not in ALLOWED_TERMINALS or request.terminal != PRIMARY_TERMINAL:
        raise CanaryRefused("only inert T11 is enabled; T12 is declared but disabled")
    _safe_component(request.program, "program")
    root = (mt5_root / request.terminal).resolve()
    for path, label in ((request.expert_path, "expert"), (request.setfile_path, "setfile")):
        if not path.is_file():
            raise CanaryRefused(f"missing {label}: {path}")
    if not request.expert_path.resolve().is_relative_to(root / "MQL5" / "Experts"):
        raise CanaryRefused("expert must be staged inside T11 MQL5/Experts")
    if not request.setfile_path.resolve().is_relative_to(root / "MQL5" / "Profiles" / "Tester"):
        raise CanaryRefused("setfile must be staged inside T11 MQL5/Profiles/Tester")


def run(request: CanaryRequest, *, farm_root: Path = FARM_ROOT, mt5_root: Path = MT5_ROOT,
        reports_root: Path = REPORTS_ROOT, resource_check: Callable[..., dict[str, Any]] = check_resources) -> dict[str, Any]:
    _validate_request(request, mt5_root=mt5_root)
    run_id = f"{dt.datetime.now(dt.timezone.utc):%Y%m%d_%H%M%S}_{uuid.uuid4().hex[:8]}"
    artifact = reports_root / request.program / run_id
    artifact.mkdir(parents=True, exist_ok=False)
    terminal_root = mt5_root / request.terminal
    report = artifact / "report.htm"
    ini = artifact / "tester.ini"
    rendered = render_tester_ini(expert=request.expert, symbol=request.symbol, period=request.period,
        setfile_name=request.setfile_path.name, from_date=request.from_date, to_date=request.to_date,
        report_rel=str(report))
    ini.write_text(rendered, encoding="utf-16", newline="")
    before = isolation_snapshot(farm_root=farm_root, terminal=request.terminal)
    assert_isolation_admitted(before)
    receipt: dict[str, Any] = {"schema": "qm.research-canary/v1", "run_id": run_id,
        "program": request.program, "terminal": request.terminal, "dry_run": request.dry_run,
        "started_at_utc": utc_now(), "artifact_root": str(artifact), "ini": {"path": str(ini), "sha256": sha256_file(ini)},
        "setfile": {"path": str(request.setfile_path), "sha256": sha256_file(request.setfile_path)},
        "ex5": {"path": str(request.expert_path), "sha256": sha256_file(request.expert_path)}, "isolation_before": before}
    try:
        receipt["history_audit"] = verify_private_history(terminal=request.terminal, symbol=request.symbol,
            farm_root=farm_root, mt5_root=mt5_root)
        receipt["resource_guard"] = resource_check(max_agents=request.max_agents, cpu_samples=5,
            sample_seconds=60.0)
        if request.dry_run:
            receipt["status"] = "DRY_RUN_PASS"
            return receipt
        exe = terminal_root / "terminal64.exe"
        if not exe.is_file():
            raise CanaryRefused(f"missing T11 terminal executable: {exe}")
        process = subprocess.Popen([str(exe), "/portable", f"/config:{ini}"], cwd=str(terminal_root),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=suspended_runner_creation_flags())
        receipt["process"] = bind_spawned_process_to_kill_job(process, lambda child: {
            "pid": child.pid, "process_creation_key": str((get_process_identity(child.pid) or {}).get("creation_key") or ""),
            "process_image_path": str((get_process_identity(child.pid) or {}).get("image_path") or "")},
            process_created_suspended=True)
        try:
            receipt["exit_code"] = process.wait(timeout=request.timeout_seconds)
        except subprocess.TimeoutExpired as exc:
            GLOBAL_JOB_REGISTRY.abort(int(process.pid), str(receipt["process"]["process_creation_key"]))
            raise CanaryRefused(f"tester timeout after {request.timeout_seconds}s") from exc
        if not report.is_file():
            raise CanaryRefused("tester exited without report")
        receipt["report"] = {"path": str(report), "sha256": sha256_file(report)}
        receipt["status"] = "COMPLETED_REVIEW_REQUIRED"
        return receipt
    except Exception as exc:
        receipt["status"] = "REFUSED" if isinstance(exc, CanaryRefused) else "ERROR"
        receipt["reason"] = str(exc)
        raise
    finally:
        receipt["ended_at_utc"] = utc_now()
        receipt["isolation_after"] = isolation_snapshot(farm_root=farm_root, terminal=request.terminal)
        try:
            assert_isolation_unchanged(before, receipt["isolation_after"])
            receipt["isolation_unchanged"] = True
        except CanaryRefused as exc:
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
    parser.add_argument("--stage", action="store_true",
                        help="hash-bind and copy the inputs into inert T11 before a canary run")
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
    request = CanaryRequest(args.program, args.terminal.upper(), args.expert, args.expert_path,
        args.setfile, args.symbol, args.period, args.from_date, args.to_date, args.max_agents,
        args.timeout_seconds, args.dry_run)
    try:
        result = run(request)
    except (CanaryRefused, OSError, sqlite3.Error) as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc)}, sort_keys=True))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
