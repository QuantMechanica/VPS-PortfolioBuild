#!/usr/bin/env python3
"""Fail-closed PRE/LAUNCH/POST evidence chain for the QM5_20002 short-NY screen.

PRE is outcome-blind.  It seals the preregistered contract, source/build, all
four set files, the exact DEV1 Model-4 data bytes, both news calendars, and the
runtime used by the detached launcher.  LAUNCH requires a separate explicit
authorization receipt and starts a detached, checkpointing worker; this keeps
the four-cell/two-duplicate screen independent of an interactive Codex session.
POST accepts only a COMPLETE launch state and audits native reports, tester
inputs, real-tick evidence, exact duplicate Deals, opening-fill semantics, and
the frozen cost/slippage merit gates.

This tool never parses market prices.  The PRE/POST data check is an opaque
SHA-256 identity check over the preregistered .hcc/.tkc files only.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, getcontext
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


getcontext().prec = 34

TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
CONTRACT_PATH = EA_ROOT / "docs" / "candidate-analysis" / "short_ny_reverse_time_contract.json"
SET_MANIFEST_PATH = EA_ROOT / "sets" / "candidate-analysis" / "short_ny_reverse_time_manifest.json"
SOURCE_PATH = EA_ROOT / "QM5_20002_ict-icytea-core.mq5"
EX5_PATH = EA_ROOT / "QM5_20002_ict-icytea-core.ex5"
REPORT_CORE_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_20009_ict-liquidity-portfolio"
    / "tools"
    / "audit_mt5_report.py"
)
RUNNER_PATH = REPO_ROOT / "framework" / "scripts" / "run_dev1_smoke.ps1"
RUNNER_CHILD_PATH = REPO_ROOT / "framework" / "scripts" / "invoke_dev1_smoke_task.ps1"
RUN_SMOKE_PATH = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"
GROUP_CANONICAL_PATH = (
    REPO_ROOT
    / "framework"
    / "registry"
    / "tester_groups"
    / "Darwinex-Live_real.canonical.txt"
)
GROUP_DEV1_PATH = Path(r"D:\QM\mt5\DEV1\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt")
TERMINAL_PATH = Path(r"D:\QM\mt5\DEV1\terminal64.exe")
METATESTER_PATH = Path(r"D:\QM\mt5\DEV1\metatester64.exe")
POWERSHELL_PATH = Path(r"C:\Program Files\PowerShell\7\pwsh.exe")
DATA_ROOT = Path(r"D:\QM\mt5\DEV1\Bases")
DEV1_RUNS_ROOT = Path(r"D:\QM\reports\dev1\runs")
DEV1_COMMON_FILES_ROOT = Path(
    r"C:\Users\QMDev1\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
)

ANALYSIS_ID = "QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001"
CONTRACT_COMMIT = "6fbdaa0817324375ad25163194fbb9e6d6f50f9b"
EXPECTED_CONTRACT_SHA256 = "3186d8294e73c3777d5447738aaeb5e2839c8b7768faf41b788cba8722514164"
EXPECTED_SOURCE_SHA256 = "4951435e308d594de64f4a0ae9fe0e0785f00d7902487e7103990424da3c5d79"
EXPECTED_SOURCE_COMMIT = "37bb9798b78b41392ea8379432cfe3e5875a74b5"
EXPECTED_STRATEGY_CARD_SHA256 = "230e59ae40179333a3c7790cc56f371bede8edd2b8fa53913557b20d8cb8bded"
EXPECTED_BUILD_BRIEF_SHA256 = "57c16befda21c6fb1cc8e44a24b715c92940faee70de9adc1b9351c46d9c92bb"

SCHEMA_VERSION = 2
ZERO = Decimal("0")
CENT = Decimal("0.01")
INITIAL_BALANCE = Decimal("100000")
POINT_VALUE_USD_PER_LOT = Decimal("1.00")  # USD-quoted 5-digit FX: 0.00001*100000
MODEL4_MARKER = "generating based on real ticks"
EXPECTED_EXPERT = "QM5_20002_ict-icytea-core"
EXPECTED_MARKETS = {"EURUSD.DWX", "GBPUSD.DWX"}
EXPECTED_ARMS = {"A_SHORT_NY_NO_HTF", "B_SHORT_NY_H1_BIAS"}
RUNTIME_ROLES = {
    "report_html_parser": REPORT_CORE_PATH,
    "runner_controller": RUNNER_PATH,
    "runner_child": RUNNER_CHILD_PATH,
    "runner_smoke": RUN_SMOKE_PATH,
    "tester_groups_canonical": GROUP_CANONICAL_PATH,
    "tester_groups_dev1": GROUP_DEV1_PATH,
    "terminal_binary": TERMINAL_PATH,
    "metatester_binary": METATESTER_PATH,
    "powershell_binary": POWERSHELL_PATH,
}


class AuditError(RuntimeError):
    """Base class for every fail-closed rejection."""


class PreflightError(AuditError):
    """PRE evidence is incomplete, stale, or inconsistent."""


class AuthorizationError(AuditError):
    """MT5 execution was requested without an exact authorization receipt."""


class PostflightError(AuditError):
    """Native run evidence is incomplete or violates the frozen contract."""


@dataclass
class NativeAudit:
    receipt: dict[str, Any]
    deals: list[Any]
    fragments: list[dict[str, Any]]
    trades: list[dict[str, Any]]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("ascii")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _jsonable(value: Any) -> Any:
    if isinstance(value, Decimal):
        return decimal_text(value)
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%dT%H:%M:%S")
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, Mapping):
        return {str(key): _jsonable(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_jsonable(item) for item in value]
    return value


def atomic_json(path: Path, payload: Mapping[str, Any], *, replace: bool = True) -> str:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not replace:
        raise AuditError(f"refusing to replace existing evidence: {path}")
    encoded = (
        json.dumps(_jsonable(payload), indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    ).encode("utf-8")
    descriptor, temporary = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    return hashlib.sha256(encoded).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AuditError(f"invalid JSON {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise AuditError(f"JSON root must be an object: {path}")
    return payload


def file_binding(path: Path, expected_sha256: str | None = None) -> dict[str, Any]:
    path = path.resolve()
    if not path.is_file():
        raise AuditError(f"required file missing: {path}")
    observed = sha256_file(path)
    if expected_sha256 and observed != expected_sha256.lower():
        raise AuditError(f"SHA-256 drift for {path}: {observed} != {expected_sha256.lower()}")
    return {"path": str(path), "size": path.stat().st_size, "sha256": observed}


def assert_binding(binding: Mapping[str, Any], label: str) -> None:
    try:
        path = Path(str(binding["path"])).resolve()
        expected_size = int(binding["size"])
        expected_sha = str(binding["sha256"]).lower()
    except (KeyError, TypeError, ValueError) as exc:
        raise AuditError(f"malformed {label} binding") from exc
    if not path.is_file() or path.stat().st_size != expected_size:
        raise AuditError(f"{label} missing/size drift: {path}")
    observed = sha256_file(path)
    if observed != expected_sha:
        raise AuditError(f"{label} SHA drift: {observed} != {expected_sha}")


def _git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=check,
    )


def assert_committed_bytes(commit: str, path: Path, expected: bytes, label: str) -> None:
    relative = path.resolve().relative_to(REPO_ROOT).as_posix()
    result = subprocess.run(
        ["git", "show", f"{commit}:{relative}"],
        cwd=REPO_ROOT,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0 or result.stdout != expected:
        raise PreflightError(f"{label} is not byte-identical at commit {commit}")


def assert_ancestor(ancestor: str, descendant: str, label: str) -> None:
    result = _git("merge-base", "--is-ancestor", ancestor, descendant, check=False)
    if result.returncode != 0:
        raise PreflightError(f"{label}: {ancestor} is not an ancestor of {descendant}")


def parse_utc(value: str, label: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise AuditError(f"invalid {label}: {value!r}") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def decimal_text(value: Decimal) -> str:
    if value == ZERO:
        return "0"
    return format(value.normalize(), "f")


def money(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def money_text(value: Decimal) -> str:
    return format(money(value), ".2f")


def parse_decimal(value: str, label: str) -> Decimal:
    cleaned = value.strip().replace("\u00a0", " ").replace("\u202f", " ").replace(" ", "")
    if not cleaned:
        raise AuditError(f"missing numeric value: {label}")
    if "," in cleaned and "." in cleaned:
        if cleaned.rfind(",") > cleaned.rfind("."):
            cleaned = cleaned.replace(".", "").replace(",", ".")
        else:
            cleaned = cleaned.replace(",", "")
    elif "," in cleaned:
        cleaned = cleaned.replace(",", ".")
    try:
        result = Decimal(cleaned)
    except InvalidOperation as exc:
        raise AuditError(f"invalid numeric value for {label}: {value!r}") from exc
    if not result.is_finite():
        raise AuditError(f"non-finite numeric value for {label}")
    return result


def load_contract() -> dict[str, Any]:
    raw = CONTRACT_PATH.read_bytes()
    observed = hashlib.sha256(raw).hexdigest()
    if observed != EXPECTED_CONTRACT_SHA256:
        raise PreflightError(f"contract SHA drift: {observed}")
    assert_committed_bytes(CONTRACT_COMMIT, CONTRACT_PATH, raw, "contract")
    contract = json.loads(raw.decode("utf-8"))
    if (
        contract.get("schema_version") != 2
        or contract.get("contract_revision") != 2
        or contract.get("analysis_id") != ANALYSIS_ID
    ):
        raise PreflightError("unexpected contract schema/revision/analysis id")
    calendars = contract.get("data_bindings", {}).get("news_calendars")
    if not isinstance(calendars, list) or len(calendars) != 2:
        raise PreflightError("contract must bind exactly both QM_NewsInit calendars")
    roles = {str(row.get("role")) for row in calendars if isinstance(row, Mapping)}
    if roles != {
        "PRIMARY_QM_NEWS_CALENDAR",
        "SECONDARY_QM_NEWS_CALENDAR_REQUIRED_BY_QM_NewsInit",
    }:
        raise PreflightError("contract news role closure drift")
    fill_gate = contract.get("execution_integrity_gates", {})
    if (
        fill_gate.get("opening_fill_new_york_window")
        != "07:00:00_INCLUSIVE_TO_10:00:00_EXCLUSIVE"
        or fill_gate.get("opening_fill_must_be_outside_news_blackout_union") is not True
        or fill_gate.get("violation_disposition") != "INVALID"
    ):
        raise PreflightError("contract opening-fill INVALID gates drifted")
    tester = contract.get("tester", {})
    exact_tester = {
        "terminal": "DEV1",
        "model": 4,
        "execution_mode": 0,
        "optimization": 0,
        "deposit": 100000,
        "currency": "USD",
        "leverage": 100,
        "duplicates_per_cell": 2,
    }
    for key, expected in exact_tester.items():
        if tester.get(key) != expected:
            raise PreflightError(f"tester contract drift: {key}")
    return contract


def parse_set(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    try:
        lines = path.read_text(encoding="ascii").splitlines()
    except OSError as exc:
        raise PreflightError(f"cannot read set {path}: {exc}") from exc
    metadata: dict[str, str] = {}
    inputs: dict[str, str] = {}
    for line in lines:
        if not line.strip():
            continue
        if line.startswith(";"):
            body = line[1:].strip()
            if "=" in body:
                key, value = body.split("=", 1)
                if key in metadata:
                    raise PreflightError(f"duplicate set metadata {key}: {path}")
                metadata[key] = value
            continue
        if "=" not in line:
            raise PreflightError(f"malformed set line {line!r}: {path}")
        key, value = line.split("=", 1)
        if key in inputs:
            raise PreflightError(f"duplicate set input {key}: {path}")
        inputs[key] = value
    return metadata, inputs


def render_contract_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return format(value, ".15g")
    return str(value)


def validate_sets(contract: Mapping[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    manifest_binding = file_binding(SET_MANIFEST_PATH)
    manifest = load_json(SET_MANIFEST_PATH)
    if (
        manifest.get("analysis_id") != ANALYSIS_ID
        or manifest.get("contract_commit") != CONTRACT_COMMIT
        or manifest.get("contract_sha256") != EXPECTED_CONTRACT_SHA256
    ):
        raise PreflightError("set manifest contract identity drift")
    rows = manifest.get("sets")
    if not isinstance(rows, list) or len(rows) != 4:
        raise PreflightError("set manifest must contain exactly four cells")
    common = dict(contract["common_inputs"])
    arm_bias = {str(row["id"]): bool(row["UseHTFBias"]) for row in contract["arms"]}
    expected_cells = {(arm, symbol) for arm in EXPECTED_ARMS for symbol in EXPECTED_MARKETS}
    observed_cells: set[tuple[str, str]] = set()
    result: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, Mapping):
            raise PreflightError("malformed set manifest row")
        arm, symbol = str(row.get("arm")), str(row.get("symbol"))
        observed_cells.add((arm, symbol))
        relative = Path(str(row.get("path")))
        path = (EA_ROOT / relative).resolve()
        if EA_ROOT.resolve() not in path.parents:
            raise PreflightError(f"set escaped EA root: {path}")
        binding = file_binding(path, str(row.get("sha256", "")))
        if binding["size"] != int(row.get("size", -1)):
            raise PreflightError(f"set size drift: {path}")
        metadata, inputs = parse_set(path)
        if len(inputs) != 52 or int(row.get("visible_input_count", -1)) != 52:
            raise PreflightError(f"set input count drift: {path}")
        expected_inputs = dict(common)
        expected_inputs["UseHTFBias"] = arm_bias[arm]
        expected_inputs["qm_magic_slot_offset"] = 0 if symbol == "EURUSD.DWX" else 1
        rendered = {key: render_contract_value(value) for key, value in expected_inputs.items()}
        if inputs != rendered:
            missing = sorted(set(rendered) - set(inputs))
            extra = sorted(set(inputs) - set(rendered))
            drift = sorted(key for key in set(inputs) & set(rendered) if inputs[key] != rendered[key])
            raise PreflightError(
                f"set/report input surface drift {path}: missing={missing}, extra={extra}, values={drift}"
            )
        if (
            metadata.get("analysis_id") != ANALYSIS_ID
            or metadata.get("contract_commit") != CONTRACT_COMMIT
            or metadata.get("contract_sha256") != EXPECTED_CONTRACT_SHA256
            or metadata.get("arm") != arm
            or metadata.get("symbol") != symbol
            or metadata.get("window") != "2017-10-01..2021-12-31"
        ):
            raise PreflightError(f"set metadata drift: {path}")
        result.append(
            {
                "arm": arm,
                "symbol": symbol,
                "timeframe": "M1",
                "magic_slot": int(row["magic_slot"]),
                "binding": binding,
                "inputs": inputs,
            }
        )
    if observed_cells != expected_cells:
        raise PreflightError(f"four-cell closure drift: {sorted(observed_cells)}")
    return sorted(result, key=lambda item: (item["arm"], item["symbol"])), manifest_binding


def validate_source_closure(contract: Mapping[str, Any]) -> dict[str, Any]:
    frozen = contract["frozen_implementation"]
    if (
        frozen.get("source_git_commit") != EXPECTED_SOURCE_COMMIT
        or frozen.get("source_sha256") != EXPECTED_SOURCE_SHA256
        or frozen.get("fresh_compile_required") is not True
        or frozen.get("compiled_binary_must_bind_source_manifest") is not True
    ):
        raise PreflightError("frozen implementation closure drift")
    source = file_binding(SOURCE_PATH, EXPECTED_SOURCE_SHA256)
    assert_committed_bytes(EXPECTED_SOURCE_COMMIT, SOURCE_PATH, SOURCE_PATH.read_bytes(), "source")
    card_path = REPO_ROOT / str(frozen["strategy_card_path"])
    brief_path = REPO_ROOT / str(frozen["build_brief_path"])
    card = file_binding(card_path, EXPECTED_STRATEGY_CARD_SHA256)
    brief = file_binding(brief_path, EXPECTED_BUILD_BRIEF_SHA256)
    return {"source": source, "strategy_card": card, "build_brief": brief}


def _csv_rows(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = list(reader.fieldnames or [])
        return [dict(row) for row in reader], fields


def validate_compile_evidence(path: Path, contract: Mapping[str, Any]) -> dict[str, Any]:
    evidence_binding = file_binding(path)
    evidence = load_json(path)
    if evidence.get("result") != "PASS" or evidence.get("errors") != 0 or evidence.get("warnings") != 0:
        raise PreflightError("fresh compile evidence is not PASS/0/0")
    if str(evidence.get("source_sha256", "")).lower() != EXPECTED_SOURCE_SHA256:
        raise PreflightError("compile source SHA does not bind frozen MQ5")
    source_evidence_path = Path(str(evidence.get("source_path", ""))).resolve()
    if source_evidence_path != SOURCE_PATH.resolve():
        raise PreflightError("compile source path does not bind repository MQ5")
    finished = parse_utc(str(evidence.get("finished_utc", "")), "compile finished_utc")
    revision = parse_utc(str(contract["revision_2_created_utc"]), "contract revision_2_created_utc")
    if finished <= revision:
        raise PreflightError("compile is not fresh after contract revision 2")
    if finished > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise PreflightError("compile finished_utc is implausibly in the future")
    git_head = str(evidence.get("git_head_after", ""))
    if not re.fullmatch(r"[0-9a-fA-F]{40}", git_head):
        raise PreflightError("compile evidence git_head_after is missing")
    assert_ancestor(CONTRACT_COMMIT, git_head, "fresh compile ancestry")
    assert_ancestor(EXPECTED_SOURCE_COMMIT, git_head, "frozen source ancestry")

    artifact_fields = {
        "compile_log": ("compile_log_path", "compile_log_sha256"),
        "stage_ex5": ("stage_ex5_path", "ex5_sha256"),
        "repo_ex5": ("repo_ex5_path", "ex5_sha256"),
        "include_sync_manifest": ("include_manifest_path", "include_sync_manifest_sha256"),
        "include_path_audit": ("include_path_audit_path", "include_path_audit_sha256"),
    }
    artifacts: dict[str, Any] = {}
    for role, (path_field, sha_field) in artifact_fields.items():
        raw_path, raw_sha = evidence.get(path_field), evidence.get(sha_field)
        if not raw_path or not raw_sha:
            raise PreflightError(f"compile evidence omitted {path_field}/{sha_field}")
        artifacts[role] = file_binding(Path(str(raw_path)), str(raw_sha))
    source_manifest_path = path.resolve().parent / "source_manifest.csv"
    artifacts["source_manifest"] = file_binding(
        source_manifest_path, str(evidence.get("source_manifest_sha256", ""))
    )
    if Path(artifacts["repo_ex5"]["path"]).resolve() != EX5_PATH.resolve():
        raise PreflightError("compile repo EX5 path drift")
    if artifacts["repo_ex5"]["sha256"] != artifacts["stage_ex5"]["sha256"]:
        raise PreflightError("staged/repository EX5 mismatch")
    compile_log = Path(artifacts["compile_log"]["path"]).read_text(
        encoding="utf-8-sig", errors="replace"
    )
    if not re.search(r"Result:\s*0 errors,\s*0 warnings", compile_log, re.IGNORECASE):
        raise PreflightError("compile log lacks exact 0 errors / 0 warnings result")
    source_rows, source_fields = _csv_rows(Path(artifacts["source_manifest"]["path"]))
    if set(source_fields) != {"relative_path", "bytes", "sha256"} or len(source_rows) != 1:
        raise PreflightError("compile source_manifest must bind exactly one MQ5 source")
    source_row = source_rows[0]
    if (
        Path(source_row["relative_path"]).name != SOURCE_PATH.name
        or source_row["sha256"].lower() != EXPECTED_SOURCE_SHA256
        or int(source_row["bytes"]) != SOURCE_PATH.stat().st_size
    ):
        raise PreflightError("compile source_manifest MQ5 identity drift")
    sync_rows, sync_fields = _csv_rows(Path(artifacts["include_sync_manifest"]["path"]))
    required_sync = {"target_include_root", "relative_path", "bytes", "source_sha256", "destination_sha256"}
    if set(sync_fields) != required_sync or not sync_rows:
        raise PreflightError("compile include sync manifest malformed/empty")
    if any(row["source_sha256"].lower() != row["destination_sha256"].lower() for row in sync_rows):
        raise PreflightError("compile include sync manifest contains source/destination drift")
    if int(evidence.get("include_manifest_rows", -1)) != len(sync_rows):
        raise PreflightError("compile include manifest row count drift")
    audit_rows, audit_fields = _csv_rows(Path(artifacts["include_path_audit"]["path"]))
    if set(audit_fields) != {"included_path", "allowed"} or not audit_rows:
        raise PreflightError("compile include path audit malformed/empty")
    if any(row["allowed"].strip().casefold() != "true" for row in audit_rows):
        raise PreflightError("compile used a forbidden include path")
    if int(evidence.get("outside_include_paths_count", -1)) != 0:
        raise PreflightError("compile evidence reports outside include paths")
    if int(evidence.get("active_dev1_processes_after", -1)) != 0:
        raise PreflightError("compile left DEV1 processes active")
    if int(evidence.get("ephemeral_tasks_after", -1)) != 0:
        raise PreflightError("compile left ephemeral tasks active")
    metaeditor = file_binding(
        Path(str(evidence.get("metaeditor_path", ""))), str(evidence.get("metaeditor_sha256", ""))
    )
    return {
        "evidence": evidence_binding,
        "finished_utc": finished.isoformat(),
        "git_head_after": git_head.lower(),
        "source_sha256": EXPECTED_SOURCE_SHA256,
        "ex5_sha256": artifacts["repo_ex5"]["sha256"],
        "metaeditor": metaeditor,
        "artifacts": artifacts,
    }


def _expected_data_paths() -> list[str]:
    expected = ["symbols.custom.dat"]
    for symbol in sorted(EXPECTED_MARKETS):
        expected.extend(f"Custom\\history\\{symbol}\\{year}.hcc" for year in range(2017, 2022))
        cursor = date(2017, 10, 1)
        while cursor <= date(2021, 12, 1):
            expected.append(f"Custom\\ticks\\{symbol}\\{cursor:%Y%m}.tkc")
            cursor = date(cursor.year + (1 if cursor.month == 12 else 0), 1 if cursor.month == 12 else cursor.month + 1, 1)
    return sorted(expected, key=str.casefold)


def validate_model4_data(contract: Mapping[str, Any], *, hash_actual: bool = True) -> dict[str, Any]:
    bindings = contract["data_bindings"]
    manifest_path = Path(str(bindings["provisioning_manifest"]))
    manifest_binding = file_binding(manifest_path, str(bindings["provisioning_manifest_sha256"]))
    rows, fields = _csv_rows(manifest_path)
    expected_fields = {
        "relative_path", "source_length", "dest_length", "source_sha256", "dest_sha256", "match"
    }
    if set(fields) != expected_fields:
        raise PreflightError("provisioning manifest header drift")
    by_path: dict[str, dict[str, str]] = {}
    for row in rows:
        key = row["relative_path"].replace("/", "\\")
        if key in by_path:
            raise PreflightError(f"duplicate provisioning row: {key}")
        by_path[key] = row
    expected_paths = _expected_data_paths()
    selected: list[dict[str, Any]] = []
    for relative in expected_paths:
        row = by_path.get(relative)
        if row is None:
            raise PreflightError(f"provisioning manifest missing Model-4 input: {relative}")
        if (
            row["match"].strip().casefold() != "true"
            or row["source_length"] != row["dest_length"]
            or row["source_sha256"].lower() != row["dest_sha256"].lower()
            or not re.fullmatch(r"[0-9a-fA-F]{64}", row["dest_sha256"])
        ):
            raise PreflightError(f"provisioning identity mismatch: {relative}")
        destination = DATA_ROOT / Path(relative.replace("\\", os.sep))
        item: dict[str, Any] = {
            "relative_path": relative,
            "bytes": int(row["dest_length"]),
            "sha256": row["dest_sha256"].lower(),
            "destination_path": str(destination.resolve()),
        }
        if hash_actual:
            actual = file_binding(destination, item["sha256"])
            if actual["size"] != item["bytes"]:
                raise PreflightError(f"actual Model-4 file size drift: {destination}")
            item["actual_binding"] = actual
        selected.append(item)
    return {
        "provisioning_manifest": manifest_binding,
        "destination_root": str(DATA_ROOT.resolve()),
        "selected_file_count": len(selected),
        "selected_files": selected,
        "selected_tree_sha256": canonical_sha256(selected),
        "opaque_hash_only_no_market_values_parsed": True,
        "future_months_after_202112_selected": False,
    }


def validate_news_bindings(contract: Mapping[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for row in contract["data_bindings"]["news_calendars"]:
        seed_path = Path(str(row["path"]))
        binding = file_binding(seed_path, str(row["sha256"]))
        # MT5 build 5833+ rejects these absolute drive-letter FileOpen calls.
        # QM_NewsFilter therefore consumes the basename from FILE_COMMON under
        # the scheduled QMDev1 account.  Bind that effective input as well as
        # the D:\ seed and require byte identity before any terminal launch.
        tester_common_path = DEV1_COMMON_FILES_ROOT / seed_path.name
        tester_common_binding = file_binding(tester_common_path, str(row["sha256"]))
        if tester_common_binding["sha256"] != binding["sha256"]:
            raise PreflightError(f"tester FILE_COMMON news mirror drift: {tester_common_path}")
        result.append(
            {
                "role": str(row["role"]),
                "binding": binding,
                "tester_common_binding": tester_common_binding,
                "effective_tester_read": "ABSOLUTE_OR_BYTE_IDENTICAL_FILE_COMMON_FALLBACK",
            }
        )
    return sorted(result, key=lambda item: item["role"])


def validate_runtime() -> dict[str, Any]:
    result = {role: file_binding(path) for role, path in RUNTIME_ROLES.items()}
    if result["tester_groups_canonical"]["sha256"] != result["tester_groups_dev1"]["sha256"]:
        raise PreflightError("DEV1 tester groups are not canonical before PRE")
    return result


def build_plan(cells: Sequence[Mapping[str, Any]], timeout_seconds: int) -> dict[str, Any]:
    if not 60 <= timeout_seconds <= 28800:
        raise PreflightError("timeout_seconds outside runner contract")
    plan_cells: list[dict[str, Any]] = []
    for cell in cells:
        cell_id = f"{cell['arm']}__{cell['symbol'].replace('.', '_')}__M1"
        runner_arguments = [
            "-EAId", "20002",
            "-EALabel", "QM5_20002_ict-icytea-core",
            "-Symbol", str(cell["symbol"]),
            "-Year", "2017",
            "-FromDate", "2017.10.01",
            "-ToDate", "2021.12.31",
            "-Expert", r"QM\QM5_20002_ict-icytea-core",
            "-Period", "M1",
            "-Runs", "2",
            "-MinTrades", "0",
            "-Model", "4",
            "-TimeoutSeconds", str(timeout_seconds),
            "-SetFile", str(cell["binding"]["path"]),
            "-CommissionPerLot", "0",
            "-CommissionPerSideNative", "0",
            "-TesterCurrencyOverride", "USD",
            "-TesterDepositOverride", "100000",
            "-SmokeMode",
        ]
        plan_cells.append(
            {
                "cell_id": cell_id,
                "arm": cell["arm"],
                "symbol": cell["symbol"],
                "timeframe": "M1",
                "set_binding": cell["binding"],
                "expected_report_inputs": cell["inputs"],
                "duplicates": ["run_01", "run_02"],
                "runner_arguments": runner_arguments,
            }
        )
    plan_cells.sort(key=lambda item: item["cell_id"])
    plan = {
        "cell_count": 4,
        "duplicates_per_cell": 2,
        "total_native_runs": 8,
        "execution": "SEQUENTIAL_SINGLE_DEV1_TERMINAL",
        "model": 4,
        "cells": plan_cells,
    }
    plan["plan_sha256"] = canonical_sha256(plan)
    return plan


def preflight(compile_evidence: Path, timeout_seconds: int = 28800) -> dict[str, Any]:
    contract = load_contract()
    sources = validate_source_closure(contract)
    cells, set_manifest = validate_sets(contract)
    compile_binding = validate_compile_evidence(compile_evidence, contract)
    data = validate_model4_data(contract)
    news = validate_news_bindings(contract)
    runtime = validate_runtime()
    plan = build_plan(cells, timeout_seconds)
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_PRE_RECEIPT",
        "status": "PASS",
        "created_utc": utc_now(),
        "analysis_id": ANALYSIS_ID,
        "outcome_fence": {
            "market_values_parsed": False,
            "native_reports_opened": False,
            "mt5_started": False,
            "data_access": "OPAQUE_SHA256_ONLY",
        },
        "contract": {
            "commit": CONTRACT_COMMIT,
            "binding": file_binding(CONTRACT_PATH, EXPECTED_CONTRACT_SHA256),
        },
        "tool": file_binding(TOOL_PATH),
        "sources": sources,
        "compile": compile_binding,
        "set_manifest": set_manifest,
        "model4_data": data,
        "news_calendars": news,
        "runtime": runtime,
        "plan": plan,
    }


def _iter_bindings(value: Any, prefix: str = "receipt") -> Iterable[tuple[str, Mapping[str, Any]]]:
    if isinstance(value, Mapping):
        if set(("path", "size", "sha256")).issubset(value):
            yield prefix, value
            return
        for key, child in value.items():
            yield from _iter_bindings(child, f"{prefix}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _iter_bindings(child, f"{prefix}[{index}]")


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    binding = file_binding(path, expected_sha256)
    receipt = load_json(path)
    if (
        receipt.get("artifact_type") != "QM5_20002_SHORT_NY_PRE_RECEIPT"
        or receipt.get("status") != "PASS"
        or receipt.get("analysis_id") != ANALYSIS_ID
    ):
        raise AuditError("PRE receipt identity/status drift")
    if receipt.get("contract", {}).get("commit") != CONTRACT_COMMIT:
        raise AuditError("PRE receipt contract commit drift")
    if receipt.get("plan", {}).get("plan_sha256") != canonical_sha256(
        {key: value for key, value in receipt["plan"].items() if key != "plan_sha256"}
    ):
        raise AuditError("PRE plan canonical SHA drift")
    for label, item in _iter_bindings(receipt):
        assert_binding(item, label)
    receipt["_receipt_binding"] = binding
    return receipt


def validate_authorization(path: Path, pre_sha256: str) -> dict[str, Any]:
    binding = file_binding(path)
    payload = load_json(path)
    required = {
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_sha256": pre_sha256.lower(),
        "scope": "QM5_20002_4_CELLS_X_2_DUPLICATES_MODEL4",
        "mt5_execution_authorized": True,
    }
    for key, expected in required.items():
        actual = payload.get(key)
        if isinstance(expected, str):
            actual = str(actual).lower() if key.endswith("sha256") else actual
        if actual != expected:
            raise AuthorizationError(f"authorization field drift: {key}")
    if not str(payload.get("authorized_by", "")).strip():
        raise AuthorizationError("authorization lacks authorized_by")
    authorized = parse_utc(str(payload.get("authorized_utc", "")), "authorized_utc")
    if authorized > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise AuthorizationError("authorization timestamp is in the future")
    return {"binding": binding, "payload": payload}


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    powershell = str(pre["runtime"]["powershell_binary"]["path"])
    runner = str(pre["runtime"]["runner_controller"]["path"])
    return [
        powershell,
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        runner,
        *[str(item) for item in cell["runner_arguments"]],
    ]


def _parse_last_json(text: str) -> dict[str, Any]:
    decoder = json.JSONDecoder()
    candidates: list[dict[str, Any]] = []
    for match in re.finditer(r"\{", text):
        try:
            value, _ = decoder.raw_decode(text[match.start() :])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            candidates.append(value)
    if not candidates:
        raise AuditError("runner stdout contains no JSON object")
    return candidates[-1]


def _path_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def _find_summary(run_id: str) -> Path:
    root = DEV1_RUNS_ROOT / run_id / "output" / "smoke"
    if not root.is_dir():
        raise AuditError(f"runner smoke root missing: {root}")
    summaries = list(root.glob("QM5_20002_ict-icytea-core/*/summary.json"))
    if len(summaries) != 1:
        raise AuditError(f"expected one QM5_20002 summary under {root}, found {len(summaries)}")
    return summaries[0].resolve()


def _worker_run(job_path: Path) -> int:
    job_binding = file_binding(job_path)
    job = load_json(job_path)
    state_path = Path(str(job["state_path"])).resolve()
    pre_path = Path(str(job["pre_receipt_path"])).resolve()
    pre_sha = str(job["pre_receipt_sha256"])
    state: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_STATE",
        "analysis_id": ANALYSIS_ID,
        "status": "RUNNING",
        "worker_pid": os.getpid(),
        "started_utc": utc_now(),
        "job": job_binding,
        "pre_receipt_path": str(pre_path),
        "pre_receipt_sha256": pre_sha,
        "authorization": job["authorization"],
        "cells": [],
    }
    atomic_json(state_path, state)
    try:
        pre = assert_pre_receipt(pre_path, pre_sha)
        auth_path = Path(str(job["authorization"]["binding"]["path"]))
        validate_authorization(auth_path, pre_sha)
        work_root = state_path.parent / "worker"
        work_root.mkdir(parents=True, exist_ok=True)
        for cell in pre["plan"]["cells"]:
            # Seal all moving inputs again immediately before every terminal cell.
            assert_pre_receipt(pre_path, pre_sha)
            cell_root = work_root / str(cell["cell_id"])
            cell_root.mkdir(parents=True, exist_ok=True)
            stdout_path = cell_root / "runner.stdout.txt"
            stderr_path = cell_root / "runner.stderr.txt"
            command = runner_command(pre, cell)
            started = utc_now()
            completed = subprocess.run(
                command,
                cwd=REPO_ROOT,
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
                timeout=int(job["controller_timeout_seconds"]),
                check=False,
            )
            stdout_path.write_text(completed.stdout, encoding="utf-8")
            stderr_path.write_text(completed.stderr, encoding="utf-8")
            runner_result = _parse_last_json(completed.stdout)
            if completed.returncode != 0 or runner_result.get("success") is not True:
                raise AuditError(
                    f"runner rejected {cell['cell_id']}: exit={completed.returncode}, result={runner_result}"
                )
            run_id = str(runner_result.get("run_id", ""))
            if not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}", run_id):
                raise AuditError(f"runner returned malformed run_id: {run_id!r}")
            summary_path = _find_summary(run_id)
            cell_result = {
                "cell_id": cell["cell_id"],
                "started_utc": started,
                "finished_utc": utc_now(),
                "command_sha256": canonical_sha256(command),
                "runner_exit_code": completed.returncode,
                "runner_result": runner_result,
                "stdout": file_binding(stdout_path),
                "stderr": file_binding(stderr_path),
                "summary": file_binding(summary_path),
            }
            state["cells"].append(cell_result)
            atomic_json(state_path, state)
        assert_pre_receipt(pre_path, pre_sha)
        state["status"] = "COMPLETE"
        state["finished_utc"] = utc_now()
        atomic_json(state_path, state)
        return 0
    except Exception as exc:
        state["status"] = "REJECT"
        state["finished_utc"] = utc_now()
        state["error_type"] = type(exc).__name__
        state["error"] = str(exc)
        atomic_json(state_path, state)
        return 2


def launch_detached(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    controller_timeout_seconds: int,
) -> dict[str, Any]:
    pre = assert_pre_receipt(pre_path, pre_sha256)
    authorization = validate_authorization(authorization_path, pre_sha256)
    if not 600 <= controller_timeout_seconds <= 172800:
        raise AuthorizationError("controller timeout outside detached launcher contract")
    state_path = state_path.resolve()
    if state_path.exists():
        raise AuthorizationError(f"refusing to replace launch state: {state_path}")
    job_path = state_path.with_name("launch_job.json")
    if job_path.exists():
        raise AuthorizationError(f"refusing to replace launch job: {job_path}")
    job = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_JOB",
        "analysis_id": ANALYSIS_ID,
        "created_utc": utc_now(),
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "authorization": authorization,
        "state_path": str(state_path),
        "controller_timeout_seconds": controller_timeout_seconds,
        "plan_sha256": pre["plan"]["plan_sha256"],
        "tool": pre["tool"],
    }
    job_sha = atomic_json(job_path, job, replace=False)
    command = [sys.executable, str(TOOL_PATH), "_run-plan", "--job", str(job_path)]
    creationflags = 0
    popen_kwargs: dict[str, Any] = {}
    if os.name == "nt":
        creationflags = (
            getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
            | getattr(subprocess, "DETACHED_PROCESS", 0)
            | getattr(subprocess, "CREATE_NO_WINDOW", 0)
        )
    else:
        popen_kwargs["start_new_session"] = True
    process = subprocess.Popen(
        command,
        cwd=REPO_ROOT,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=creationflags,
        **popen_kwargs,
    )
    return {
        "status": "LAUNCHED_DETACHED",
        "worker_pid": process.pid,
        "job_path": str(job_path),
        "job_sha256": job_sha,
        "state_path": str(state_path),
        "plan_sha256": pre["plan"]["plan_sha256"],
    }


def _load_report_core(pre: Mapping[str, Any]) -> Any:
    binding = pre["runtime"]["report_html_parser"]
    assert_binding(binding, "report HTML parser")
    path = Path(str(binding["path"]))
    name = f"qm20002_bound_report_core_{binding['sha256'][:12]}"
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise PostflightError("cannot load bound native report parser")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def _report_inputs(core: Any, rows: Sequence[Sequence[str]]) -> tuple[list[str], dict[str, str]]:
    start: tuple[int, int] | None = None
    for row_index, row in enumerate(rows):
        for cell_index, cell in enumerate(row):
            if core._norm(cell) in core.FIELD_ALIASES["inputs"]:
                if start is not None:
                    raise PostflightError("multiple report Inputs sections")
                start = (row_index, cell_index)
    if start is None:
        raise PostflightError("report Inputs section missing")
    row_index, cell_index = start
    values = [core._clean_text(value) for value in rows[row_index][cell_index + 1 :] if core._clean_text(value)]
    for row in rows[row_index + 1 :]:
        if row and core._clean_text(row[0]):
            break
        values.extend(core._clean_text(value) for value in row[1:] if core._clean_text(value))
    mapping: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            continue
        key, raw = value.split("=", 1)
        key, raw = key.strip(), raw.strip()
        if not raw:
            continue  # MT5 input-group heading; all 52 frozen inputs are non-empty.
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            continue
        if key in mapping:
            raise PostflightError(f"duplicate report input: {key}")
        mapping[key] = raw
    return values, mapping


def _input_equivalent(expected: str, actual: str) -> bool:
    if expected in {"true", "false"}:
        return actual.casefold() == expected
    try:
        return parse_decimal(expected, "expected input") == parse_decimal(actual, "actual input")
    except AuditError:
        return actual == expected


def _field_after(core: Any, rows: Sequence[Sequence[str]], aliases: Iterable[str]) -> str | None:
    normalized = {core._norm(value) for value in aliases}
    matches: list[str] = []
    for row in rows:
        for index, cell in enumerate(row[:-1]):
            if core._norm(cell) in normalized:
                value = core._clean_text(row[index + 1])
                if value:
                    matches.append(value)
    unique = list(dict.fromkeys(matches))
    if len(unique) > 1:
        raise PostflightError(f"ambiguous report field {sorted(normalized)}: {unique}")
    return unique[0] if unique else None


def _position_trades(fragments: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    for fragment in fragments:
        entry_ids = list(dict.fromkeys(str(value) for value in fragment["entry_deals"]))
        if len(entry_ids) != 1:
            raise PostflightError("candidate close fragment does not map to exactly one opening Deal")
        key = entry_ids[0]
        if key not in grouped:
            order.append(key)
            grouped[key] = {
                "entry_deal": key,
                "symbol": fragment["symbol"],
                "side": fragment["side"],
                "entry_time": min(fragment["entry_times"]),
                "exit_time": fragment["exit_time"],
                "volume": ZERO,
                "raw_net": ZERO,
                "swap": ZERO,
                "external_cost": ZERO,
                "exit_deals": [],
            }
        trade = grouped[key]
        if trade["symbol"] != fragment["symbol"] or trade["side"] != fragment["side"]:
            raise PostflightError("opening Deal maps to inconsistent close fragments")
        trade["exit_time"] = max(trade["exit_time"], fragment["exit_time"])
        trade["volume"] += fragment["volume"]
        trade["raw_net"] += fragment["raw_net"]
        trade["swap"] += fragment["swap"]
        trade["external_cost"] += fragment["external_cost"]
        trade["exit_deals"].append(fragment["exit_deal"])
    return [grouped[key] for key in order]


def audit_native_report(
    report_path: Path,
    expected_symbol: str,
    expected_inputs: Mapping[str, str],
    core: Any,
) -> NativeAudit:
    report_binding = file_binding(report_path)
    rows = core._rows(report_path)
    settings = core._settings_rows(rows)
    expert_raw = str(core._field_value(settings, "expert"))
    expert = core._canonical_expert(expert_raw)
    symbol = str(core._field_value(settings, "symbol")).upper()
    timeframe, from_date, to_date = core._parse_period(str(core._field_value(settings, "period")))
    currency = str(core._field_value(settings, "currency")).upper()
    deposit = core._parse_decimal(str(core._field_value(settings, "deposit")), "Initial Deposit")
    if (
        expert != EXPECTED_EXPERT
        or symbol != expected_symbol
        or timeframe != "M1"
        or from_date.isoformat() != "2017-10-01"
        or to_date.isoformat() != "2021-12-31"
        or currency != "USD"
        or deposit != INITIAL_BALANCE
    ):
        raise PostflightError(
            f"native header drift: expert={expert}, symbol={symbol}, tf={timeframe}, "
            f"window={from_date}..{to_date}, currency={currency}, deposit={deposit}"
        )
    inputs_raw, inputs = _report_inputs(core, settings)
    if set(inputs) != set(expected_inputs):
        raise PostflightError(
            f"report input map is not exact: missing={sorted(set(expected_inputs)-set(inputs))}, "
            f"extra={sorted(set(inputs)-set(expected_inputs))}"
        )
    drift = [key for key in expected_inputs if not _input_equivalent(str(expected_inputs[key]), inputs[key])]
    if drift:
        raise PostflightError(f"report input value drift: {drift}")
    if parse_decimal(inputs["InpQMSimCommissionPerLot"], "InpQMSimCommissionPerLot") != ZERO:
        raise PostflightError("DOUBLE_COUNT_REJECT: simulated commission is not zero")
    if parse_decimal(inputs["qm_ea_id"], "qm_ea_id") != Decimal("20002"):
        raise PostflightError("wrong qm_ea_id in native report")
    quality = _field_after(
        core, settings, ["History Quality", "Qualität der Historie", "Qualitaet der Historie"]
    )
    if quality is None or not re.fullmatch(r"100(?:\.0+)?%\s+real ticks", quality.strip(), re.I):
        raise PostflightError(f"native report is not 100% real ticks: {quality!r}")
    deals = core._parse_deals(rows)
    initial = deals[0]
    if initial.kind != "balance" or initial.direction or initial.symbol:
        raise PostflightError("first Deals row is not the sole initial balance row")
    if initial.commission != ZERO or initial.swap != ZERO:
        raise PostflightError("initial balance Deal has commission/swap")
    if money(initial.profit) != money(deposit) or money(initial.balance) != money(deposit):
        raise PostflightError("initial balance/deposit mismatch")
    running = deposit
    opening_deals = []
    for deal in deals[1:]:
        if not (from_date <= deal.time.date() <= to_date):
            raise PostflightError(f"Deal outside report window: {deal.deal}")
        if deal.symbol != symbol:
            raise PostflightError(f"cross-symbol Deal in single-cell report: {deal.deal}")
        if deal.commission != ZERO:
            raise PostflightError(
                f"DOUBLE_COUNT_REJECT: native Commission on Deal {deal.deal} is {deal.commission}"
            )
        running += deal.raw_net
        if money(running) != money(deal.balance):
            raise PostflightError(f"native balance recurrence drift on Deal {deal.deal}")
        if deal.direction == "in":
            opening_deals.append(deal)
            if deal.kind != "sell":
                raise PostflightError(f"short-only candidate opened non-sell Deal {deal.deal}")
    report_net = core._parse_decimal(
        str(core._field_value(settings, "net_profit")), "Total Net Profit"
    )
    ledger_net = sum((deal.raw_net for deal in deals[1:]), ZERO)
    if money(report_net) != money(ledger_net):
        raise PostflightError("native Total Net Profit/deal-ledger mismatch")
    family = "EURUSD" if symbol == "EURUSD.DWX" else "GBPUSD"
    fragments = core._reconstruct_closes(deals, family)
    trades = _position_trades(fragments)
    if len(opening_deals) != len(trades):
        raise PostflightError("opening Deal / closed position lifecycle mismatch")
    reported_trades_raw = core._field_value(settings, "total_trades", required=False)
    trade_count_basis = "MISSING"
    if reported_trades_raw is not None:
        reported = core._parse_decimal(str(reported_trades_raw), "Total Trades")
        if reported != reported.to_integral_value():
            raise PostflightError("native Total Trades is not an integer")
        if int(reported) == len(trades):
            trade_count_basis = "POSITION_LIFECYCLES"
        elif int(reported) == len(fragments):
            trade_count_basis = "CLOSE_FRAGMENTS"
        else:
            raise PostflightError(
                f"native Total Trades matches neither lifecycles nor close fragments: {reported}"
            )
    canonical_deals = [deal.canonical() for deal in deals]
    deals_sha = canonical_sha256(canonical_deals)
    fingerprint_payload = {
        "expert": expert,
        "symbol": symbol,
        "timeframe": timeframe,
        "from": from_date.isoformat(),
        "to": to_date.isoformat(),
        "deposit": decimal_text(deposit),
        "currency": currency,
        "inputs": dict(sorted(inputs.items())),
        "deals_sha256": deals_sha,
    }
    receipt = {
        "status": "PASS",
        "report": report_binding,
        "header": {
            "expert": expert,
            "symbol": symbol,
            "timeframe": timeframe,
            "from": from_date,
            "to": to_date,
            "deposit": deposit,
            "currency": currency,
            "history_quality": quality,
            "inputs_ordered": inputs_raw,
            "inputs": inputs,
            "parsed_input_count": len(inputs),
        },
        "identity": {
            "canonical_deal_sequence_sha256": deals_sha,
            "run_fingerprint_sha256": canonical_sha256(fingerprint_payload),
        },
        "native_integrity": {
            "commission_exactly_zero": True,
            "simulated_commission_exactly_zero": True,
            "balance_recurrence": "PASS_CENT_EXACT",
            "reported_total_net_profit": money_text(report_net),
            "deal_ledger_net_profit": money_text(ledger_net),
            "reported_total_trades": str(reported_trades_raw),
            "reported_total_trades_basis": trade_count_basis,
            "opening_deals": len(opening_deals),
            "close_fragments": len(fragments),
            "position_lifecycles": len(trades),
        },
    }
    return NativeAudit(receipt=receipt, deals=deals, fragments=fragments, trades=trades)


def _parse_ini(path: Path) -> dict[str, str]:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    else:
        raise PostflightError(f"tester.ini encoding unsupported: {path}")
    values: dict[str, str] = {}
    section = ""
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section != "Tester" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in values:
            raise PostflightError(f"duplicate tester.ini key {key}: {path}")
        values[key] = value
    return values


def _nth_sunday(year: int, month: int, nth: int) -> date:
    cursor = date(year, month, 1)
    count = 0
    while True:
        if cursor.weekday() == 6:
            count += 1
            if count == nth:
                return cursor
        cursor += timedelta(days=1)


def _us_dst(utc_value: datetime) -> bool:
    start_day = _nth_sunday(utc_value.year, 3, 2)
    end_day = _nth_sunday(utc_value.year, 11, 1)
    start = datetime(utc_value.year, 3, start_day.day, 7)
    end = datetime(utc_value.year, 11, end_day.day, 6)
    return start <= utc_value < end


def broker_to_utc(broker: datetime) -> datetime:
    standard = broker - timedelta(hours=2)
    dst = broker - timedelta(hours=3)
    if not _us_dst(standard):
        return standard
    if _us_dst(dst):
        return dst
    return standard


def broker_to_new_york(broker: datetime) -> datetime:
    utc_value = broker_to_utc(broker)
    return utc_value - timedelta(hours=4 if _us_dst(utc_value) else 5)


def _parse_news_time(value: str) -> datetime | None:
    normalized = value.strip().replace("T", " ").rstrip("Z").replace("/", ".").replace("-", ".")
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y.%m.%d"):
        try:
            return datetime.strptime(normalized, fmt)
        except ValueError:
            continue
    return None


def load_news_events(news_bindings: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    events: list[tuple[datetime, str, str]] = []
    source_counts: dict[str, int] = {}
    skipped_counts: dict[str, int] = {}
    for item in news_bindings:
        binding = item["binding"]
        assert_binding(binding, str(item["role"]))
        path = Path(str(binding["path"]))
        added = skipped = 0
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fields = {str(field).strip().casefold(): str(field) for field in (reader.fieldnames or [])}
            dt_key = next((fields[key] for key in ("datetime_utc", "utc_datetime", "datetime") if key in fields), None)
            date_key = fields.get("date")
            time_key = fields.get("time_utc") or fields.get("time")
            currency_key = fields.get("currency")
            impact_key = fields.get("impact")
            if (dt_key is None and date_key is None) or currency_key is None or impact_key is None:
                raise PostflightError(f"news CSV header unsupported: {path}")
            for row in reader:
                raw_time = str(row.get(dt_key, "")) if dt_key else str(row.get(date_key, ""))
                if not dt_key and time_key:
                    raw_time += " " + str(row.get(time_key, ""))
                event_time = _parse_news_time(raw_time)
                if event_time is None:
                    skipped += 1
                    continue
                impact_raw = str(row.get(impact_key, "")).strip().upper()
                impact = "HIGH" if ("HIGH" in impact_raw or "RED" in impact_raw) else "OTHER"
                currency = str(row.get(currency_key, "")).strip().strip('"').upper()
                events.append((event_time, currency, impact))
                added += 1
        source_counts[str(item["role"])] = added
        skipped_counts[str(item["role"])] = skipped
    events.sort(key=lambda row: row[0])
    if not events or events[0][0].date() > date(2017, 9, 30) or events[-1][0].date() < date(2022, 1, 1):
        raise PostflightError("bound news union does not cover the tester window")
    return {
        "events": events,
        "times": [row[0] for row in events],
        "source_rows": source_counts,
        "skipped_rows_like_mql": skipped_counts,
    }


def _news_affects(currency: str, symbol: str) -> bool:
    if not currency or currency == "ALL":
        return True
    normalized = symbol.split(".", 1)[0].upper()
    return normalized[:3] in currency or normalized[3:6] in currency


def news_blackout(news: Mapping[str, Any], utc_value: datetime, symbol: str) -> bool:
    times: Sequence[datetime] = news["times"]
    events: Sequence[tuple[datetime, str, str]] = news["events"]
    start = bisect.bisect_left(times, utc_value - timedelta(minutes=30))
    end = bisect.bisect_right(times, utc_value + timedelta(minutes=30))
    return any(
        impact == "HIGH" and _news_affects(currency, symbol)
        for _, currency, impact in events[start:end]
    )


def _validate_opening_fills(audit: NativeAudit, symbol: str, news: Mapping[str, Any]) -> dict[str, Any]:
    violations: list[dict[str, Any]] = []
    per_day: dict[str, int] = defaultdict(int)
    openings = [deal for deal in audit.deals if deal.direction == "in"]
    for deal in openings:
        ny = broker_to_new_york(deal.time)
        utc_value = broker_to_utc(deal.time)
        day_key = ny.date().isoformat()
        per_day[day_key] += 1
        reasons: list[str] = []
        if not (7 <= ny.hour < 10):
            reasons.append("OUTSIDE_NY_07_10")
        if news_blackout(news, utc_value, symbol):
            reasons.append("INSIDE_BOUND_NEWS_BLACKOUT_UNION")
        if reasons:
            violations.append(
                {
                    "deal": deal.deal,
                    "broker_time": deal.time,
                    "utc_time": utc_value,
                    "new_york_time": ny,
                    "reasons": reasons,
                }
            )
    for day_key, count in sorted(per_day.items()):
        if count > 2:
            violations.append({"new_york_day": day_key, "opening_deals": count, "reasons": ["MAX_TRADES_PER_KZ_EXCEEDED"]})
    if violations:
        raise PostflightError(f"INVALID opening-fill semantics for {symbol}: {_jsonable(violations)}")
    return {
        "status": "PASS",
        "opening_deals": len(openings),
        "all_inside_ny_07_10": True,
        "all_outside_both_calendar_blackouts": True,
        "maximum_opening_deals_per_ny_day": max(per_day.values(), default=0),
    }


def _validate_ini(values: Mapping[str, str], cell: Mapping[str, Any], run_name: str) -> None:
    expected = {
        "Expert": r"QM\QM5_20002_ict-icytea-core",
        "Symbol": str(cell["symbol"]),
        "Period": "M1",
        "Model": "4",
        "ExecutionMode": "0",
        "Optimization": "0",
        "FromDate": "2017.10.01",
        "ToDate": "2021.12.31",
        "Deposit": "100000",
        "Currency": "USD",
        "Leverage": "100",
        "Visual": "0",
        "ShutdownTerminal": "1",
    }
    drift = {key: (wanted, values.get(key)) for key, wanted in expected.items() if values.get(key) != wanted}
    if drift:
        raise PostflightError(f"tester.ini drift {cell['cell_id']}/{run_name}: {drift}")


def audit_cell(
    pre: Mapping[str, Any],
    cell: Mapping[str, Any],
    launch_cell: Mapping[str, Any],
    core: Any,
    news: Mapping[str, Any],
) -> tuple[dict[str, Any], NativeAudit]:
    assert_binding(launch_cell["summary"], f"{cell['cell_id']} summary")
    summary_path = Path(str(launch_cell["summary"]["path"]))
    summary = load_json(summary_path)
    expected_summary = {
        "result": "PASS",
        "ea_id": 20002,
        "ea_label": "QM5_20002_ict-icytea-core",
        "expert": r"QM\QM5_20002_ict-icytea-core",
        "symbol": cell["symbol"],
        "terminal": "DEV1",
        "model": 4,
        "period": "M1",
        "requested_runs": 2,
        "deterministic": True,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "model4_log_marker_detected": True,
    }
    drift = {key: (wanted, summary.get(key)) for key, wanted in expected_summary.items() if summary.get(key) != wanted}
    if drift:
        raise PostflightError(f"runner summary drift {cell['cell_id']}: {drift}")
    commission = summary.get("commission_group", {})
    if (
        Decimal(str(commission.get("commission_per_lot", -1))) != ZERO
        or Decimal(str(commission.get("commission_per_side_native", -1))) != ZERO
        or commission.get("restored_to_canonical") is not True
        or str(commission.get("canonical_sha256", "")).lower()
        != pre["runtime"]["tester_groups_canonical"]["sha256"]
        or str(commission.get("restored_sha256", "")).lower()
        != pre["runtime"]["tester_groups_canonical"]["sha256"]
    ):
        raise PostflightError(f"native commission/group restore evidence drift: {cell['cell_id']}")
    runs = summary.get("runs")
    if not isinstance(runs, list) or [row.get("run") for row in runs] != ["run_01", "run_02"]:
        raise PostflightError(f"duplicate run closure drift: {cell['cell_id']}")
    native_audits: list[NativeAudit] = []
    run_receipts: list[dict[str, Any]] = []
    for run in runs:
        run_name = str(run["run"])
        if run.get("status") != "OK" or run.get("exit_code") != 0 or run.get("real_ticks_marker") is not True:
            raise PostflightError(f"runner duplicate is not OK/Model4: {cell['cell_id']}/{run_name}")
        report_path = Path(str(run.get("report_canonical_path", ""))).resolve()
        log_path = Path(str(run.get("tester_log_path", ""))).resolve()
        report_dir = Path(str(summary.get("report_dir", ""))).resolve()
        if not _path_within(report_path, report_dir) or not _path_within(log_path, report_dir):
            raise PostflightError(f"run artifact escaped report directory: {cell['cell_id']}/{run_name}")
        ini_path = report_path.parent / "tester.ini"
        ini_binding = file_binding(ini_path)
        ini_values = _parse_ini(ini_path)
        _validate_ini(ini_values, cell, run_name)
        log_binding = file_binding(log_path)
        log_text = log_path.read_text(encoding="utf-8-sig", errors="replace")
        if MODEL4_MARKER not in log_text.casefold():
            raise PostflightError(f"raw tester log lacks Model-4 marker: {cell['cell_id']}/{run_name}")
        if re.search(r"OnInit.*(?:failed|error)|INIT_FAILED", log_text, re.I):
            raise PostflightError(f"raw tester log contains OnInit failure: {cell['cell_id']}/{run_name}")
        native = audit_native_report(
            report_path,
            str(cell["symbol"]),
            {str(key): str(value) for key, value in cell["expected_report_inputs"].items()},
            core,
        )
        fill = _validate_opening_fills(native, str(cell["symbol"]), news)
        native_audits.append(native)
        run_receipts.append(
            {
                "run": run_name,
                "tester_ini": ini_binding,
                "tester_log": log_binding,
                "model4_log_marker": True,
                "native_report_audit": native.receipt,
                "opening_fill_integrity": fill,
            }
        )
    baseline, duplicate = native_audits
    if (
        baseline.receipt["identity"]["canonical_deal_sequence_sha256"]
        != duplicate.receipt["identity"]["canonical_deal_sequence_sha256"]
        or baseline.receipt["identity"]["run_fingerprint_sha256"]
        != duplicate.receipt["identity"]["run_fingerprint_sha256"]
    ):
        raise PostflightError(f"duplicate Deal sequence drift: {cell['cell_id']}")
    return (
        {
            "cell_id": cell["cell_id"],
            "arm": cell["arm"],
            "symbol": cell["symbol"],
            "summary": launch_cell["summary"],
            "duplicate_deal_sequence_check": "PASS_EXACT",
            "runs": run_receipts,
        },
        baseline,
    )


def _scenario_net(row: Mapping[str, Any], points: int) -> Decimal:
    slippage = Decimal(2 * points) * Decimal(row["volume"]) * POINT_VALUE_USD_PER_LOT
    return Decimal(row["raw_net"]) - Decimal(row["external_cost"]) - slippage


def profit_factor(values: Sequence[Decimal]) -> tuple[Decimal | None, str]:
    gross_profit = sum((max(value, ZERO) for value in values), ZERO)
    gross_loss = sum((min(value, ZERO) for value in values), ZERO)
    if gross_loss < ZERO:
        return gross_profit / -gross_loss, "FINITE"
    if gross_profit > ZERO:
        return None, "INFINITE_NO_LOSSES"
    return None, "UNDEFINED"


def _pf_pass(value: Decimal | None, state: str, floor: Decimal) -> bool:
    return state == "INFINITE_NO_LOSSES" or (value is not None and value >= floor)


def _scenario_metrics(trades: Sequence[Mapping[str, Any]], points: int) -> dict[str, Any]:
    values = [_scenario_net(row, points) for row in trades]
    pf, state = profit_factor(values)
    return {
        "slippage_points_per_side": points,
        "closed_trades": len(values),
        "net_usd": money_text(sum(values, ZERO)),
        "gross_profit_usd": money_text(sum((max(value, ZERO) for value in values), ZERO)),
        "gross_loss_usd": money_text(sum((min(value, ZERO) for value in values), ZERO)),
        "profit_factor": None if pf is None else decimal_text(pf),
        "profit_factor_state": state,
    }


def _adjudicate_arm(
    arm: str,
    audits: Sequence[tuple[str, NativeAudit]],
    merit: Mapping[str, Any],
) -> dict[str, Any]:
    trades: list[dict[str, Any]] = []
    fragments: list[dict[str, Any]] = []
    swap_failures: list[str] = []
    for symbol, audit in audits:
        for trade in audit.trades:
            trades.append({**trade, "symbol": symbol})
            entry_ny = broker_to_new_york(trade["entry_time"]).date()
            exit_ny = broker_to_new_york(trade["exit_time"]).date()
            if entry_ny != exit_ny or Decimal(trade["swap"]) != ZERO:
                swap_failures.append(str(trade["entry_deal"]))
        for fragment in audit.fragments:
            fragments.append({**fragment, "symbol": symbol})
    scenarios = {str(points): _scenario_metrics(trades, points) for points in (0, 2, 5)}
    center_values = [_scenario_net(row, 2) for row in trades]
    adverse_values = [_scenario_net(row, 5) for row in trades]
    center_pf, center_state = profit_factor(center_values)
    adverse_pf, adverse_state = profit_factor(adverse_values)
    by_symbol: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_year: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for trade in trades:
        by_symbol[str(trade["symbol"])].append(trade)
        by_year[trade["exit_time"].year].append(trade)
    symbol_metrics: dict[str, Any] = {}
    for symbol in sorted(EXPECTED_MARKETS):
        rows = by_symbol[symbol]
        values = [_scenario_net(row, 2) for row in rows]
        pf, state = profit_factor(values)
        symbol_metrics[symbol] = {
            "trades": len(rows),
            "net_usd": money_text(sum(values, ZERO)),
            "profit_factor": None if pf is None else decimal_text(pf),
            "profit_factor_state": state,
        }
    years = [2018, 2019, 2020, 2021]
    year_net = {
        str(year): sum((_scenario_net(row, 2) for row in by_year[year]), ZERO) for year in years
    }
    positive_years = sum(value > ZERO for value in year_net.values())
    best_year = max(years, key=lambda year: year_net[str(year)])
    leave_best_year_net = sum(center_values, ZERO) - year_net[str(best_year)]
    best_five = sorted(center_values, reverse=True)[:5]
    leave_best_five_net = sum(center_values, ZERO) - sum(best_five, ZERO)

    ordered_fragments = sorted(
        fragments, key=lambda row: (row["exit_time"], str(row["symbol"]), int(row["sequence"]))
    )
    balance = peak = INITIAL_BALANCE
    max_dd_pct = ZERO
    daily: dict[str, Decimal] = defaultdict(Decimal)
    for fragment in ordered_fragments:
        value = _scenario_net(fragment, 2)
        balance += value
        peak = max(peak, balance)
        if peak > ZERO:
            max_dd_pct = max(max_dd_pct, (peak - balance) / peak * Decimal("100"))
        day_key = broker_to_new_york(fragment["exit_time"]).date().isoformat()
        daily[day_key] += value
    worst_day_loss_pct = (
        max((max(-value, ZERO) for value in daily.values()), default=ZERO)
        / INITIAL_BALANCE
        * Decimal("100")
    )
    gates = {
        "minimum_pooled_closed_trades": len(trades) >= int(merit["minimum_pooled_closed_trades"]),
        "minimum_closed_trades_per_symbol": all(
            symbol_metrics[symbol]["trades"] >= int(merit["minimum_closed_trades_per_symbol"])
            for symbol in EXPECTED_MARKETS
        ),
        "center_cost_adjusted_profit_factor": _pf_pass(
            center_pf, center_state, Decimal(str(merit["center_cost_adjusted_profit_factor_min"]))
        ),
        "adverse_cost_adjusted_profit_factor": _pf_pass(
            adverse_pf, adverse_state, Decimal(str(merit["adverse_cost_adjusted_profit_factor_min"]))
        ),
        "minimum_positive_full_calendar_years": positive_years
        >= int(merit["minimum_positive_full_calendar_years"]),
        "each_symbol_net_positive_center": all(
            Decimal(symbol_metrics[symbol]["net_usd"]) > ZERO for symbol in EXPECTED_MARKETS
        ),
        "each_symbol_profit_factor_min_center": all(
            _pf_pass(
                None
                if symbol_metrics[symbol]["profit_factor"] is None
                else Decimal(symbol_metrics[symbol]["profit_factor"]),
                symbol_metrics[symbol]["profit_factor_state"],
                Decimal(str(merit["each_symbol_profit_factor_min_center"])),
            )
            for symbol in EXPECTED_MARKETS
        ),
        "leave_best_year_out_net_positive_center": leave_best_year_net > ZERO,
        "leave_best_five_trades_out_net_positive_center": len(trades) >= 5 and leave_best_five_net > ZERO,
        "maximum_closed_balance_drawdown_percent": max_dd_pct
        <= Decimal(str(merit["maximum_closed_balance_drawdown_percent"])),
        "maximum_single_ny_day_loss_percent_initial_balance": worst_day_loss_pct
        <= Decimal(str(merit["maximum_single_ny_day_loss_percent_initial_balance"])),
        "zero_overnight_swap_or_exact_swap_cost_proof": not swap_failures,
        "duplicate_deal_sequence_must_match": True,
    }
    return {
        "arm": arm,
        "status": "PASS" if all(gates.values()) else "FAIL",
        "gates": gates,
        "scenarios": scenarios,
        "symbols_center": symbol_metrics,
        "full_calendar_year_net_center_usd": {key: money_text(value) for key, value in year_net.items()},
        "positive_full_calendar_years": positive_years,
        "leave_best_year": best_year,
        "leave_best_year_out_net_center_usd": money_text(leave_best_year_net),
        "leave_best_five_trades_out_net_center_usd": money_text(leave_best_five_net),
        "maximum_closed_balance_drawdown_percent_center": decimal_text(max_dd_pct),
        "maximum_single_ny_day_loss_percent_initial_balance_center": decimal_text(worst_day_loss_pct),
        "swap_proof": {
            "status": "PASS_ZERO_SAME_NY_DAY" if not swap_failures else "FAIL_EXACT_SWAP_PROOF_REQUIRED",
            "violating_entry_deals": swap_failures,
        },
    }


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    pre = assert_pre_receipt(pre_path, pre_sha256)
    state_binding = file_binding(state_path)
    state = load_json(state_path)
    if (
        state.get("artifact_type") != "QM5_20002_SHORT_NY_LAUNCH_STATE"
        or state.get("analysis_id") != ANALYSIS_ID
        or state.get("status") != "COMPLETE"
        or state.get("pre_receipt_sha256") != pre_sha256.lower()
    ):
        raise PostflightError("launch state is not COMPLETE/bound to PRE")
    launch_cells = state.get("cells")
    if not isinstance(launch_cells, list) or len(launch_cells) != 4:
        raise PostflightError("launch state does not contain exactly four cells")
    launch_by_id = {str(row.get("cell_id")): row for row in launch_cells}
    if len(launch_by_id) != 4:
        raise PostflightError("launch state cell IDs are not unique")
    core = _load_report_core(pre)
    news = load_news_events(pre["news_calendars"])
    cell_receipts: list[dict[str, Any]] = []
    arm_audits: dict[str, list[tuple[str, NativeAudit]]] = defaultdict(list)
    for cell in pre["plan"]["cells"]:
        cell_id = str(cell["cell_id"])
        if cell_id not in launch_by_id:
            raise PostflightError(f"launch state omitted preregistered cell: {cell_id}")
        receipt, baseline = audit_cell(pre, cell, launch_by_id[cell_id], core, news)
        cell_receipts.append(receipt)
        arm_audits[str(cell["arm"])].append((str(cell["symbol"]), baseline))
    if set(arm_audits) != EXPECTED_ARMS or any(len(rows) != 2 for rows in arm_audits.values()):
        raise PostflightError("arm/symbol familywise closure drift")
    contract = load_contract()
    arms = [
        _adjudicate_arm(arm, arm_audits[arm], contract["merit_gates"])
        for arm in sorted(EXPECTED_ARMS)
    ]
    passing = [row["arm"] for row in arms if row["status"] == "PASS"]
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_POST_RECEIPT",
        "status": "PASS_CANDIDATE" if passing else "REJECT_NO_ARM_PASSED",
        "created_utc": utc_now(),
        "analysis_id": ANALYSIS_ID,
        "pre_receipt": file_binding(pre_path, pre_sha256),
        "launch_state": state_binding,
        "integrity_status": "PASS",
        "outcome_window": "2017-10-01..2021-12-31",
        "native_run_count": 8,
        "cell_count": 4,
        "news_union": {
            "source_rows": news["source_rows"],
            "skipped_rows_like_mql": news["skipped_rows_like_mql"],
        },
        "cells": cell_receipts,
        "arms": arms,
        "passing_arms": passing,
        "decision": contract["decision"]["on_pass"] if passing else contract["decision"]["on_fail"],
    }


def _rejection(phase: str, exc: Exception) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": f"QM5_20002_SHORT_NY_{phase}_REJECTION",
        "status": "REJECT",
        "created_utc": utc_now(),
        "analysis_id": ANALYSIS_ID,
        "error_type": type(exc).__name__,
        "error": str(exc),
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    pre = sub.add_parser("pre", help="Outcome-blind PRE validation and receipt")
    pre.add_argument("--compile-evidence", type=Path, required=True)
    pre.add_argument("--receipt", type=Path, required=True)
    pre.add_argument("--timeout-seconds", type=int, default=28800)
    launch = sub.add_parser("launch", help="Start the authorized detached four-cell worker")
    launch.add_argument("--pre-receipt", type=Path, required=True)
    launch.add_argument("--pre-sha256", required=True)
    launch.add_argument("--authorization", type=Path, required=True)
    launch.add_argument("--state", type=Path, required=True)
    launch.add_argument("--controller-timeout-seconds", type=int, default=43200)
    post = sub.add_parser("post", help="Audit COMPLETE native evidence and merit gates")
    post.add_argument("--pre-receipt", type=Path, required=True)
    post.add_argument("--pre-sha256", required=True)
    post.add_argument("--state", type=Path, required=True)
    post.add_argument("--receipt", type=Path, required=True)
    worker = sub.add_parser("_run-plan", help=argparse.SUPPRESS)
    worker.add_argument("--job", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    if args.command == "_run-plan":
        return _worker_run(args.job)
    try:
        if args.command == "pre":
            payload = preflight(args.compile_evidence, args.timeout_seconds)
            receipt_sha = atomic_json(args.receipt, payload, replace=False)
            output = {"status": "PASS", "receipt": str(args.receipt.resolve()), "sha256": receipt_sha}
        elif args.command == "launch":
            output = launch_detached(
                args.pre_receipt,
                args.pre_sha256,
                args.authorization,
                args.state,
                args.controller_timeout_seconds,
            )
        else:
            payload = postflight(args.pre_receipt, args.pre_sha256, args.state)
            receipt_sha = atomic_json(args.receipt, payload, replace=False)
            output = {
                "status": payload["status"],
                "receipt": str(args.receipt.resolve()),
                "sha256": receipt_sha,
                "passing_arms": payload["passing_arms"],
            }
        print(json.dumps(output, indent=2, sort_keys=True))
        return 0
    except (AuditError, OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
        phase = args.command.upper()
        payload = _rejection(phase, exc)
        receipt = getattr(args, "receipt", None)
        if receipt:
            try:
                atomic_json(receipt, payload, replace=False)
            except (AuditError, OSError):
                pass
        print(json.dumps(payload, indent=2, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
