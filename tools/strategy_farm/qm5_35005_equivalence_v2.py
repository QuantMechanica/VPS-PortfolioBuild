#!/usr/bin/env python3
"""One-variable, hermetic equivalence proof for QM5_35005.

The controller is bound to router task cbfca92a.  It creates detached worktrees
at the exact parent and exact integration commit, overlays the same current EA
source bytes, compiles in separate disposable portable MetaEditor profiles, and
backtests the resulting private EX5 files in separate fresh portable profiles.
It never addresses T1-T10 or T_Live and never publishes either EX5.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


REPO_IMPORT_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_IMPORT_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_IMPORT_ROOT))

from tools.strategy_farm import qm5_35005_equivalence as exact
from tools.strategy_farm.include_mirror import running_terminal_names


SCHEMA = "qm.qm5-35005-pattern-include-equivalence/v2"
TASK_ID = "cbfca92a-79ca-4cde-9dc8-1992a6023f39"
FLAG_NAME = "QM_ENABLE_QM5_35005_EQUIVALENCE_V2"
PARENT_COMMIT = "73d81a93e7df539d51f7496c3b3c9a428611e29c"
INTEGRATION_COMMIT = "b0bdc4d72f23876398b707db72450a560718ef4a"
EA_LABEL = "QM5_35005_sma-crossover-pullback-system"
EA_RELATIVE = Path("framework") / "EAs" / EA_LABEL
SOURCE_RELATIVE = EA_RELATIVE / f"{EA_LABEL}.mq5"
SET_RELATIVE = EA_RELATIVE / "sets" / f"{EA_LABEL}_EURUSD.DWX_H1_backtest.set"
INCLUDE_RELATIVE = Path("framework") / "include"
RUNTIME_EXPERT = rf"QM\EQV35005_V2\{EA_LABEL}"
SYMBOL = "EURUSD.DWX"
PERIOD = "H1"
MODEL = 4
SEED = 42
FROM_DATE = "2022.07.01"
TO_DATE = "2022.12.31"
DEFAULT_TEMPLATE = Path(r"D:\QM\mt5\DEV1")
DEFAULT_ARTIFACT_ROOT = (
    # Keep the disposable checkout prefix short.  The exact historical trees
    # contain tracked paths long enough to exceed Win32's checkout boundary
    # under the descriptive artifact path used by the first fail-closed run.
    Path(r"D:\QM\strategy_farm\artifacts\e2") / "cbfca92a-a2"
)
ARTIFACTS_BASE = Path(r"D:\QM\strategy_farm\artifacts")
DEFAULT_EVIDENCE_DIR = Path(r"C:\QM\repo\docs\ops\evidence")
OUTPUT_STEM = "cbfca92a_qm5_35005_pattern_include_equivalence_v2_2026-08-27"
BASES_FILE_ALLOWLIST = (
    "alerts.dat",
    "books.dat",
    "indicators.dat",
    "objects.dat",
    "options.dat",
    "strategy.dat",
    "symbols.custom.dat",
)


class ProofError(RuntimeError):
    """A fail-closed proof precondition or execution invariant failed."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).astimezone().isoformat()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def atomic_bytes(path: Path, value: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("xb") as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def atomic_json(path: Path, value: Any) -> None:
    atomic_bytes(path, json.dumps(value, indent=2, sort_keys=True).encode("utf-8") + b"\n")


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ProofError(f"expected JSON object: {path}")
    return value


def _run(
    command: Sequence[str],
    *,
    cwd: Path | None = None,
    timeout: int = 300,
    env: Mapping[str, str] | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        [str(value) for value in command],
        cwd=None if cwd is None else str(cwd),
        env=None if env is None else dict(env),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=timeout,
        check=False,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    if check and completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "").strip()
        raise ProofError(
            f"command failed exit={completed.returncode}: {' '.join(command)}: {detail}"
        )
    return completed


def _git(repo_root: Path, *args: str, timeout: int = 300) -> str:
    return _run(["git", *args], cwd=repo_root, timeout=timeout).stdout.strip()


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def assert_create_only_path(path: Path, allowed_root: Path) -> None:
    resolved = path.resolve()
    if not _is_within(resolved, allowed_root.resolve()) or resolved == allowed_root.resolve():
        raise ProofError(f"unsafe create-only path: {resolved}")
    if resolved.exists():
        raise ProofError(f"create-only path already exists: {resolved}")
    if not resolved.parent.is_dir():
        raise ProofError(f"create-only parent missing: {resolved.parent}")


def _assert_no_reparse_tree(root: Path) -> None:
    if root.is_symlink():
        raise ProofError(f"reparse/symlink root refused: {root}")
    for path in root.rglob("*"):
        if path.is_symlink():
            raise ProofError(f"reparse/symlink member refused: {path}")


def tree_inventory(root: Path) -> dict[str, Any]:
    root = root.resolve()
    if not root.is_dir():
        raise ProofError(f"tree missing: {root}")
    rows: list[dict[str, Any]] = []
    total = 0
    for path in sorted((p for p in root.rglob("*") if p.is_file()), key=lambda p: p.as_posix().casefold()):
        relative = path.relative_to(root).as_posix()
        size = path.stat().st_size
        total += size
        rows.append({"relative_path": relative, "size": size, "sha256": sha256_file(path)})
    if not rows:
        raise ProofError(f"tree inventory empty: {root}")
    return {
        "root": str(root),
        "file_count": len(rows),
        "total_bytes": total,
        "sha256": sha256_bytes(canonical_json_bytes(rows)),
        "files": rows,
    }


def file_binding(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise ProofError(f"required file missing: {resolved}")
    stat = resolved.stat()
    return {
        "path": str(resolved),
        "size": stat.st_size,
        "sha256": sha256_file(resolved),
    }


def parse_setfile_guard(path: Path, source_path: Path) -> dict[str, Any]:
    values = exact.parse_setfile(path)
    try:
        risk_fixed = float(values["RISK_FIXED"])
        risk_percent = float(values["RISK_PERCENT"])
    except (KeyError, ValueError) as exc:
        raise ProofError("setfile risk values invalid") from exc
    if risk_fixed <= 0 or risk_percent != 0:
        raise ProofError("setfile must use RISK_FIXED > 0 and RISK_PERCENT = 0")
    source = source_path.read_text(encoding="utf-8-sig")
    match = re.search(r"(?m)^input\s+int\s+qm_news_stale_max_hours\s*=\s*(\d+)\s*;", source)
    if match is None:
        raise ProofError("source news stale default not found")
    stale = int(match.group(1))
    if stale > 336:
        raise ProofError("qm_news_stale_max_hours exceeds 336")
    return {
        "RISK_FIXED": risk_fixed,
        "RISK_PERCENT": risk_percent,
        "qm_news_stale_max_hours": stale,
    }


def validate_authorization(path: Path, artifact_root: Path) -> dict[str, Any]:
    if os.environ.get(FLAG_NAME) != "1":
        raise ProofError(f"{FLAG_NAME}=1 process-scoped authorization required")
    manifest = _load_json(path)
    expected = {
        "schema": "qm.qm5-35005-equivalence-v2-authorization/v1",
        "task_id": TASK_ID,
        "parent_commit": PARENT_COMMIT,
        "integration_commit": INTEGRATION_COMMIT,
        "factory_terminals_allowed": False,
        "live_allowed": False,
        "publish_ex5": False,
    }
    failed = [key for key, value in expected.items() if manifest.get(key) != value]
    if failed:
        raise ProofError(f"authorization manifest mismatch: {failed}")
    declared = Path(str(manifest.get("artifact_root") or "")).resolve()
    if declared != artifact_root.resolve():
        raise ProofError("authorization artifact_root mismatch")
    return manifest


def prepare_worktrees(repo_root: Path, artifact_root: Path) -> dict[str, Any]:
    actual_parent = _git(repo_root, "rev-parse", f"{INTEGRATION_COMMIT}^")
    if actual_parent != PARENT_COMMIT:
        raise ProofError(f"integration parent drift: {actual_parent}")
    worktrees_root = artifact_root / "worktrees"
    worktrees_root.mkdir(parents=True, exist_ok=False)
    current_source = repo_root / SOURCE_RELATIVE
    source_before = file_binding(current_source)
    result: dict[str, Any] = {}
    for side, commit in (("parent", PARENT_COMMIT), ("integration", INTEGRATION_COMMIT)):
        worktree = worktrees_root / side
        _run(
            ["git", "worktree", "add", "--detach", str(worktree), commit],
            cwd=repo_root,
            timeout=1200,
        )
        observed = _git(worktree, "rev-parse", "HEAD")
        if observed != commit:
            raise ProofError(f"{side} worktree commit mismatch: {observed}")
        staged_source = worktree / SOURCE_RELATIVE
        shutil.copy2(current_source, staged_source)
        staged_binding = file_binding(staged_source)
        if staged_binding["sha256"] != source_before["sha256"]:
            raise ProofError(f"{side} source overlay hash mismatch")
        include_root = worktree / INCLUDE_RELATIVE
        result[side] = {
            "commit": observed,
            "worktree": str(worktree.resolve()),
            "git_include_tree": _git(worktree, "rev-parse", f"HEAD:{INCLUDE_RELATIVE.as_posix()}"),
            "include": tree_inventory(include_root),
            "source": staged_binding,
            "status": _git(worktree, "status", "--porcelain=v1", "--", SOURCE_RELATIVE.as_posix()),
        }
    changed = _git(
        repo_root,
        "diff",
        "--name-status",
        PARENT_COMMIT,
        INTEGRATION_COMMIT,
        "--",
        INCLUDE_RELATIVE.as_posix(),
    ).splitlines()
    if not changed:
        raise ProofError("integration Include delta unexpectedly empty")
    result["include_delta"] = changed
    result["current_source"] = source_before
    result["source_byte_identical"] = (
        result["parent"]["source"]["sha256"]
        == result["integration"]["source"]["sha256"]
        == source_before["sha256"]
    )
    return result


def _copy_tree(source: Path, destination: Path) -> None:
    _assert_no_reparse_tree(source)
    shutil.copytree(source, destination, copy_function=shutil.copy2)


def parse_compile_summary(text: str) -> dict[str, int]:
    matches = list(
        re.finditer(
            r"(?im)(?P<errors>\d+)\s+errors?\s*,\s*(?P<warnings>\d+)\s+warnings?",
            text,
        )
    )
    if not matches:
        raise ProofError("compile log has no errors/warnings summary")
    match = matches[-1]
    return {
        "errors": int(match.group("errors")),
        "warnings": int(match.group("warnings")),
    }


def _copy_compiler_runtime(template_root: Path, compiler_root: Path) -> None:
    compiler_root.mkdir(parents=True, exist_ok=False)
    for name in ("MetaEditor64.exe", "Terminal.ico"):
        source = template_root / name
        if source.is_file():
            shutil.copy2(source, compiler_root / name)
    (compiler_root / "portable.txt").touch(exist_ok=False)
    if not (compiler_root / "MetaEditor64.exe").is_file():
        raise ProofError("portable compiler copy missing MetaEditor64.exe")


def prepare_compiler(
    *, side: str, worktree: Path, template_root: Path, artifact_root: Path
) -> dict[str, Any]:
    compiler_root = artifact_root / "compilers" / side
    compiler_root.parent.mkdir(parents=True, exist_ok=True)
    _copy_compiler_runtime(template_root, compiler_root)
    isolated_include = compiler_root / "MQL5" / "Include"
    isolated_include.parent.mkdir(parents=True, exist_ok=True)
    _copy_tree(template_root / "MQL5" / "Include", isolated_include)

    # Replace every repository-owned include namespace; never leave a newer
    # stale QM file underneath the selected commit's tree.
    for relative in (Path("QM"), Path("news_rules")):
        target = isolated_include / relative
        if target.exists():
            if not _is_within(target, compiler_root):
                raise ProofError(f"compiler overlay target escaped: {target}")
            shutil.rmtree(target)
    branding = isolated_include / "QM_Branding.mqh"
    branding.unlink(missing_ok=True)
    for member in (worktree / INCLUDE_RELATIVE).iterdir():
        destination = isolated_include / member.name
        if member.is_dir():
            _copy_tree(member, destination)
        else:
            shutil.copy2(member, destination)

    staged_dir = compiler_root / "MQL5" / "Experts" / "QM" / "EQV35005_V2"
    staged_dir.mkdir(parents=True, exist_ok=False)
    staged_source = staged_dir / f"{EA_LABEL}.mq5"
    shutil.copy2(worktree / SOURCE_RELATIVE, staged_source)
    staged_ex5 = staged_source.with_suffix(".ex5")
    compile_log = artifact_root / "compile_logs" / f"{side}.compile.log"
    compile_log.parent.mkdir(parents=True, exist_ok=True)
    profile_roaming = compiler_root / "profile" / "Roaming"
    profile_local = compiler_root / "profile" / "Local"
    profile_roaming.mkdir(parents=True, exist_ok=False)
    profile_local.mkdir(parents=True, exist_ok=False)
    return {
        "side": side,
        "root": compiler_root,
        "metaeditor": compiler_root / "MetaEditor64.exe",
        "include_root": isolated_include,
        "include_before": tree_inventory(isolated_include),
        "source": staged_source,
        "source_before": file_binding(staged_source),
        "ex5": staged_ex5,
        "log": compile_log,
        "roaming": profile_roaming,
        "local": profile_local,
    }


def compile_side(prepared: Mapping[str, Any], timeout_seconds: int = 600) -> dict[str, Any]:
    side = str(prepared["side"])
    metaeditor = Path(prepared["metaeditor"])
    source = Path(prepared["source"])
    ex5 = Path(prepared["ex5"])
    log = Path(prepared["log"])
    env = os.environ.copy()
    env["APPDATA"] = str(Path(prepared["roaming"]))
    env["LOCALAPPDATA"] = str(Path(prepared["local"]))
    started = utc_now()
    completed = _run(
        [
            str(metaeditor),
            "/portable",
            f"/compile:{source}",
            f"/log:{log}",
        ],
        cwd=Path(prepared["root"]),
        timeout=timeout_seconds,
        env=env,
        check=False,
    )
    if not log.is_file() or not ex5.is_file():
        raise ProofError(
            f"{side} compiler output missing: exit={completed.returncode} log={log} ex5={ex5}"
        )
    log_text = log.read_text(encoding="utf-16", errors="replace")
    summary = parse_compile_summary(log_text)
    if summary != {"errors": 0, "warnings": 0}:
        raise ProofError(f"{side} strict compile failed: {summary}")
    source_after = file_binding(source)
    include_after = tree_inventory(Path(prepared["include_root"]))
    if source_after != prepared["source_before"]:
        raise ProofError(f"{side} staged source changed during compile")
    if include_after["sha256"] != prepared["include_before"]["sha256"]:
        raise ProofError(f"{side} include tree changed during compile")
    remaining = _target_processes(Path(prepared["root"]))
    if remaining:
        raise ProofError(f"{side} compiler profile did not become idle: {remaining}")
    return {
        "side": side,
        "started_at": started,
        "completed_at": utc_now(),
        "metaeditor": file_binding(metaeditor),
        "process_exit_code": completed.returncode,
        "source": source_after,
        "include": include_after,
        "log": file_binding(log),
        "ex5": file_binding(ex5),
        "strict_summary": summary,
        "processes_after": remaining,
    }


def _copy_if_present(source: Path, destination: Path) -> None:
    if source.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)


def prepare_test_profile(
    *,
    side: str,
    template_root: Path,
    artifact_root: Path,
    ex5_path: Path,
    setfile_path: Path,
    tester_groups_path: Path,
) -> dict[str, Any]:
    profile = artifact_root / "profiles" / side
    profile.mkdir(parents=True, exist_ok=False)
    for name in ("terminal64.exe", "metatester64.exe", "Terminal.ico"):
        _copy_if_present(template_root / name, profile / name)
    (profile / "portable.txt").touch(exist_ok=False)
    # A portable tester needs the template's broker/account cache to resolve
    # tester groups.  The copied executables are outbound-blocked before start;
    # these private config bytes are never copied into repository evidence.
    _copy_tree(template_root / "Config", profile / "Config")
    for name in BASES_FILE_ALLOWLIST:
        _copy_if_present(template_root / "Bases" / name, profile / "Bases" / name)

    for kind in ("history", "ticks"):
        source = template_root / "Bases" / "Custom" / kind / SYMBOL
        destination = profile / "Bases" / "Custom" / kind / SYMBOL
        destination.parent.mkdir(parents=True, exist_ok=True)
        _copy_tree(source, destination)
    _copy_tree(template_root / "MQL5" / "Files", profile / "MQL5" / "Files")
    groups = profile / "MQL5" / "Profiles" / "Tester" / "Groups"
    groups.mkdir(parents=True, exist_ok=False)
    shutil.copy2(tester_groups_path, groups / "Darwinex-Live_real.txt")
    expert_dir = profile / "MQL5" / "Experts" / "QM" / "EQV35005_V2"
    expert_dir.mkdir(parents=True, exist_ok=False)
    staged_ex5 = expert_dir / f"{EA_LABEL}.ex5"
    shutil.copy2(ex5_path, staged_ex5)
    tester_dir = profile / "MQL5" / "Profiles" / "Tester"
    staged_set = tester_dir / setfile_path.name
    shutil.copy2(setfile_path, staged_set)
    (profile / "Tester").mkdir(exist_ok=False)

    report = profile / f"{side}_equivalence_report.htm"
    ini = artifact_root / "tester_ini" / f"{side}.ini"
    ini.parent.mkdir(parents=True, exist_ok=True)
    write_tester_ini(ini, report_name=report.name, setfile_name=staged_set.name)
    return {
        "side": side,
        "root": profile,
        "terminal": profile / "terminal64.exe",
        "metatester": profile / "metatester64.exe",
        "ex5": staged_ex5,
        "setfile": staged_set,
        "ini": ini,
        "report": report,
        "history_before": history_inventory(profile),
        "common_inputs": {
            "config": tree_inventory(profile / "Config"),
            "mql5_files": tree_inventory(profile / "MQL5" / "Files"),
            "tester_groups": file_binding(groups / "Darwinex-Live_real.txt"),
        },
    }


def write_tester_ini(path: Path, *, report_name: str, setfile_name: str) -> None:
    lines = [
        "[Tester]",
        f"Expert={RUNTIME_EXPERT}",
        f"ExpertParameters={setfile_name}",
        f"Symbol={SYMBOL}",
        f"Period={PERIOD}",
        f"Model={MODEL}",
        "ExecutionMode=0",
        "Optimization=0",
        "OptimizationCriterion=0",
        f"FromDate={FROM_DATE}",
        f"ToDate={TO_DATE}",
        "ForwardMode=0",
        "Deposit=100000",
        "Currency=USD",
        "ProfitInPips=0",
        "Leverage=100",
        "UseLocal=1",
        "UseRemote=0",
        "UseCloud=0",
        "Visual=0",
        "Replace=1",
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        f"Report={report_name}",
        "",
    ]
    atomic_bytes(path, "\r\n".join(lines).encode("ascii"))


def history_inventory(profile: Path) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    total = 0
    custom = profile / "Bases" / "Custom"
    for kind in ("history", "ticks"):
        root = custom / kind / SYMBOL
        for path in sorted(root.rglob("*"), key=lambda p: p.as_posix().casefold()):
            if not path.is_file():
                continue
            size = path.stat().st_size
            total += size
            rows.append(
                {
                    "relative_path": path.relative_to(custom).as_posix(),
                    "size": size,
                    "sha256": sha256_file(path),
                }
            )
    if not rows:
        raise ProofError("portable profile history inventory empty")
    return {
        "file_count": len(rows),
        "total_bytes": total,
        "sha256": sha256_bytes(canonical_json_bytes(rows)),
        "files": rows,
    }


def _firewall_rule_name(side: str, program: Path) -> str:
    token = re.sub(r"[^A-Za-z0-9]+", "_", program.name).strip("_")
    return f"QM_EQV35005_V2_{side}_{token}_{os.getpid()}"


def add_firewall_rule(side: str, program: Path) -> dict[str, Any]:
    program = program.resolve()
    if not program.is_file():
        raise ProofError(f"firewall program missing: {program}")
    name = _firewall_rule_name(side, program)
    added = _run(
        [
            "netsh",
            "advfirewall",
            "firewall",
            "add",
            "rule",
            f"name={name}",
            "dir=out",
            "action=block",
            f"program={program}",
            "enable=yes",
            "profile=any",
        ],
        timeout=60,
    )
    shown = _run(
        ["netsh", "advfirewall", "firewall", "show", "rule", f"name={name}", "verbose"],
        timeout=60,
    )
    if "Block" not in shown.stdout and "Blockieren" not in shown.stdout:
        raise ProofError(f"firewall block rule could not be authenticated: {name}")
    return {
        "name": name,
        "program": str(program),
        "add_output": added.stdout.strip(),
        "active_proof": shown.stdout,
        "removed": False,
    }


def remove_firewall_rule(rule: Mapping[str, Any]) -> dict[str, Any]:
    result = dict(rule)
    completed = _run(
        [
            "netsh",
            "advfirewall",
            "firewall",
            "delete",
            "rule",
            f"name={rule['name']}",
        ],
        timeout=60,
        check=False,
    )
    result["remove_exit_code"] = completed.returncode
    result["remove_output"] = (completed.stdout or completed.stderr).strip()
    shown = _run(
        [
            "netsh",
            "advfirewall",
            "firewall",
            "show",
            "rule",
            f"name={rule['name']}",
        ],
        timeout=60,
        check=False,
    )
    result["removed"] = (
        shown.returncode != 0
        or "No rules match" in shown.stdout
        or "Keine Regeln" in shown.stdout
    )
    return result


def _target_processes(profile: Path) -> list[dict[str, Any]]:
    escaped = str(profile.resolve()).replace("'", "''")
    script = (
        f"$root=[IO.Path]::GetFullPath('{escaped}').TrimEnd('\\')+'\\';"
        "$rows=@(Get-CimInstance Win32_Process -Property ProcessId,Name,ExecutablePath "
        "-ErrorAction Stop|Where-Object{$_.ExecutablePath -and "
        "[IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($root,"
        "[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object{"
        "[pscustomobject]@{pid=[int]$_.ProcessId;name=$_.Name;path=$_.ExecutablePath}});"
        "$rows|ConvertTo-Json -Compress"
    )
    completed = _run(
        ["pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script],
        timeout=60,
    )
    text = completed.stdout.strip()
    if not text:
        return []
    value = json.loads(text)
    if isinstance(value, dict):
        return [value]
    if not isinstance(value, list):
        raise ProofError("portable process probe returned malformed JSON")
    return value


def _wait_report_stable(path: Path, deadline: float) -> dict[str, Any]:
    previous: tuple[int, int] | None = None
    stable = 0
    while time.monotonic() < deadline:
        if path.is_file():
            stat = path.stat()
            current = (stat.st_size, stat.st_mtime_ns)
            if current == previous and stat.st_size > 0:
                stable += 1
                if stable >= 3:
                    return file_binding(path)
            else:
                stable = 0
                previous = current
        time.sleep(1)
    raise ProofError(f"native report did not become stable: {path}")


def _latest_tester_log(profile: Path) -> Path | None:
    candidates = [path for path in (profile / "Tester").rglob("*.log") if path.is_file()]
    return max(candidates, key=lambda path: path.stat().st_mtime_ns) if candidates else None


def report_identity(path: Path) -> dict[str, Any]:
    observed: dict[str, str] = {}
    for row in exact.report_rows(path):
        if len(row) < 2:
            continue
        label = row[0].strip().rstrip(":").casefold()
        if label in {"expert", "symbol", "period", "history quality"}:
            observed[label] = row[1].strip()
    checks = {
        "expert": observed.get("expert") == EA_LABEL,
        "symbol": observed.get("symbol") == SYMBOL,
        "period_and_window": bool(
            re.fullmatch(
                rf"{re.escape(PERIOD)} \({re.escape(FROM_DATE)} - {re.escape(TO_DATE)}\)",
                observed.get("period", ""),
            )
        ),
        "real_ticks": "real ticks" in observed.get("history quality", "").casefold(),
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise ProofError(f"native report identity failed: {failed} observed={observed}")
    return {"observed": observed, "checks": checks}


def run_test_profile(prepared: Mapping[str, Any], timeout_seconds: int = 1800) -> dict[str, Any]:
    side = str(prepared["side"])
    profile = Path(prepared["root"])
    terminal = Path(prepared["terminal"])
    report = Path(prepared["report"])
    if _target_processes(profile):
        raise ProofError(f"{side} portable profile is not idle")
    command = [str(terminal), "/portable", f"/config:{Path(prepared['ini']).resolve()}"]
    started = utc_now()
    process = subprocess.Popen(
        command,
        cwd=str(profile),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    timed_out = False
    try:
        process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        timed_out = True
        # Only the PID returned from this create-only profile is targeted.
        _run(["taskkill", "/PID", str(process.pid), "/T", "/F"], timeout=60, check=False)
        try:
            process.wait(timeout=30)
        except subprocess.TimeoutExpired as exc:
            raise ProofError(f"{side} portable tester could not be contained") from exc
    deadline = time.monotonic() + 30
    while _target_processes(profile) and time.monotonic() < deadline:
        time.sleep(1)
    remaining = _target_processes(profile)
    log = _latest_tester_log(profile)
    log_binding = file_binding(log) if log is not None else None
    if timed_out or remaining:
        raise ProofError(
            f"{side} portable tester containment failed: timed_out={timed_out} remaining={remaining} log={log}"
        )
    report_binding = _wait_report_stable(report, time.monotonic() + 30)
    deals = exact.extract_deal_rows(report)
    deal_bytes = exact.canonical_deal_bytes(deals)
    inputs = exact.extract_report_inputs(report)
    identity = report_identity(report)
    required_inputs = {
        "qm_ea_id": "35005",
        "qm_rng_seed": str(SEED),
        "RISK_PERCENT": "0",
        "RISK_FIXED": "1000",
        "qm_news_stale_max_hours": "336",
    }
    input_failures = {
        key: inputs.get(key)
        for key, value in required_inputs.items()
        if inputs.get(key) != value
    }
    if input_failures:
        raise ProofError(f"{side} native report input binding failed: {input_failures}")
    return {
        "side": side,
        "started_at": started,
        "completed_at": utc_now(),
        "command_contract": ["<portable-terminal64.exe>", "/portable", "/config:<absolute-ini>"],
        "process": {"pid": process.pid, "exit_code": process.returncode, "timed_out": timed_out},
        "report": report_binding,
        "tester_ini": file_binding(Path(prepared["ini"])),
        "execution_ini": exact.canonical_execution_ini(Path(prepared["ini"])),
        "tester_log": log_binding,
        "deal_rows": deals,
        "deal_count": len(deals),
        "canonical_deals_sha256": sha256_bytes(deal_bytes),
        "inputs": inputs,
        "report_identity": identity,
        "history_before": prepared["history_before"],
        "history_after": history_inventory(profile),
        "profile": {
            "root": str(profile.resolve()),
            "terminal": file_binding(Path(prepared["terminal"])),
            "metatester": file_binding(Path(prepared["metatester"])),
            "ex5": file_binding(Path(prepared["ex5"])),
            "setfile": file_binding(Path(prepared["setfile"])),
            "common_inputs": prepared["common_inputs"],
        },
        "processes_after": remaining,
    }


def common_news_bindings() -> dict[str, Any]:
    root = Path(os.environ.get("APPDATA", "")) / "MetaQuotes" / "Terminal" / "Common" / "Files"
    names = (
        "news_calendar_2015_2025.csv",
        "news_calendar_bundle_manifest.json",
        "forex_factory_calendar_clean.csv",
    )
    rows = [file_binding(root / name) for name in names if (root / name).is_file()]
    if len(rows) < 2:
        raise ProofError(f"common news seed incomplete: {root}")
    return {
        "root": str(root.resolve()),
        "files": rows,
        "sha256": sha256_bytes(canonical_json_bytes(rows)),
    }


def _copy_evidence_file(source: Path, destination: Path) -> dict[str, Any]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    if sha256_file(source) != sha256_file(destination):
        raise ProofError(f"evidence copy hash mismatch: {source}")
    return file_binding(destination)


def build_comparison(
    pre: Mapping[str, Any], post: Mapping[str, Any]
) -> tuple[dict[str, Any], bytes, bytes]:
    pre_deals = pre["deal_rows"]
    post_deals = post["deal_rows"]
    pre_bytes = exact.canonical_deal_bytes(pre_deals)
    post_bytes = exact.canonical_deal_bytes(post_deals)
    row_diff = exact.compare_deal_rows(pre_deals, post_deals)
    echo = exact.post_input_echo_check(post["inputs"])
    pre_shared = {key: value for key, value in pre["inputs"].items() if key not in exact.POST_INPUTS}
    post_shared = {key: value for key, value in post["inputs"].items() if key not in exact.POST_INPUTS}
    integration_only_inputs = sorted(set(post["inputs"]) - set(pre["inputs"]))
    checks = {
        "canonical_deal_bytes_equal": pre_bytes == post_bytes,
        "all_deal_fields_equal": row_diff["identical"],
        "execution_ini_equal": pre["execution_ini"] == post["execution_ini"],
        "post_six_opt_pp_inputs_zero": echo["pass"],
        "shared_report_inputs_equal": pre_shared == post_shared,
        "integration_only_adds_six_opt_pp_inputs": integration_only_inputs
        == sorted(exact.POST_INPUTS),
        "nonempty_deals": bool(pre_deals and post_deals),
        "history_pre_profile_stable": (
            pre["history_before"]["sha256"] == pre["history_after"]["sha256"]
        ),
        "history_post_profile_stable": (
            post["history_before"]["sha256"] == post["history_after"]["sha256"]
        ),
        "history_profiles_identical": (
            pre["history_before"]["sha256"] == post["history_before"]["sha256"]
        ),
        "terminal_binary_identical": (
            pre["profile"]["terminal"]["sha256"]
            == post["profile"]["terminal"]["sha256"]
        ),
        "metatester_binary_identical": (
            pre["profile"]["metatester"]["sha256"]
            == post["profile"]["metatester"]["sha256"]
        ),
        "setfile_bytes_identical": (
            pre["profile"]["setfile"]["sha256"]
            == post["profile"]["setfile"]["sha256"]
        ),
        "portable_config_identical": (
            pre["profile"]["common_inputs"]["config"]["sha256"]
            == post["profile"]["common_inputs"]["config"]["sha256"]
        ),
        "portable_registry_files_identical": (
            pre["profile"]["common_inputs"]["mql5_files"]["sha256"]
            == post["profile"]["common_inputs"]["mql5_files"]["sha256"]
        ),
        "tester_groups_identical": (
            pre["profile"]["common_inputs"]["tester_groups"]["sha256"]
            == post["profile"]["common_inputs"]["tester_groups"]["sha256"]
        ),
    }
    return {
        "checks": checks,
        "row_diff": row_diff,
        "post_input_echo": echo,
        "identical": all(checks.values()),
    }, pre_bytes, post_bytes


def write_comparison_csv(path: Path, packet: Mapping[str, Any]) -> None:
    comparison = packet["comparison"]
    pre = packet["runs"]["parent"]
    post = packet["runs"]["integration"]
    rows = [
        ("worktree commit", PARENT_COMMIT, INTEGRATION_COMMIT, "EXPECTED_VARIABLE"),
        (
            "Include tree SHA-256",
            packet["worktrees"]["parent"]["include"]["sha256"],
            packet["worktrees"]["integration"]["include"]["sha256"],
            "EXPECTED_VARIABLE",
        ),
        (
            "EA source SHA-256",
            packet["worktrees"]["parent"]["source"]["sha256"],
            packet["worktrees"]["integration"]["source"]["sha256"],
            "IDENTICAL",
        ),
        (
            "EX5 SHA-256",
            packet["compiles"]["parent"]["ex5"]["sha256"],
            packet["compiles"]["integration"]["ex5"]["sha256"],
            "COMPILED_PRIVATE",
        ),
        (
            "Setfile SHA-256",
            packet["setup"]["setfile"]["sha256"],
            packet["setup"]["setfile"]["sha256"],
            "IDENTICAL",
        ),
        ("Symbol/period", f"{SYMBOL}/{PERIOD}", f"{SYMBOL}/{PERIOD}", "IDENTICAL"),
        ("Window", f"{FROM_DATE}..{TO_DATE}", f"{FROM_DATE}..{TO_DATE}", "IDENTICAL"),
        ("Model/seed", f"{MODEL}/{SEED}", f"{MODEL}/{SEED}", "IDENTICAL"),
        (
            "History SHA-256",
            pre["history_before"]["sha256"],
            post["history_before"]["sha256"],
            "IDENTICAL" if comparison["checks"]["history_profiles_identical"] else "DIFFERENT",
        ),
        (
            "Deals rows",
            str(pre["deal_count"]),
            str(post["deal_count"]),
            "IDENTISCH" if comparison["row_diff"]["identical"] else "ABWEICHEND",
        ),
        (
            "Canonical Deals SHA-256",
            pre["canonical_deals_sha256"],
            post["canonical_deals_sha256"],
            "IDENTISCH" if comparison["checks"]["canonical_deal_bytes_equal"] else "ABWEICHEND",
        ),
        (
            "Integration opt_pp echo",
            "not exposed by parent Include tree",
            json.dumps(comparison["post_input_echo"]["observed"], sort_keys=True),
            "PASS" if comparison["post_input_echo"]["pass"] else "FAIL",
        ),
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    with temporary.open("x", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(("check", "parent", "integration", "result"))
        writer.writerows(rows)
    os.replace(temporary, path)


def render_markdown(packet: Mapping[str, Any]) -> str:
    outcome = packet["outcome"]
    comparison = packet.get("comparison") or {}
    pre = (packet.get("runs") or {}).get("parent") or {}
    post = (packet.get("runs") or {}).get("integration") or {}
    lines = [
        "# QM5_35005 one-variable Include equivalence v2",
        "",
        f"- Router task: `{TASK_ID}`",
        f"- Outcome: **{outcome}**",
        "- Pipeline verdict: **none**; this artifact remains subject to Orchestrator/OWNER review.",
        "- Factory/live terminals: **not targeted**; both compiles and tests used create-only disposable profiles.",
        "",
    ]
    if packet.get("execution_status") != "COMPLETE":
        lines.extend(
            [
                "## Fail-closed stop",
                "",
                f"`{packet.get('exception')}`",
                "",
                "No equivalence conclusion is claimed.",
                "",
            ]
        )
        return "\n".join(lines)
    lines.extend(
        [
            "## Isolated build identities",
            "",
            "| Side | Detached commit | Include tree SHA-256 | MQ5 SHA-256 | Private EX5 SHA-256 | Compile |",
            "|---|---|---|---|---|---|",
        ]
    )
    for side in ("parent", "integration"):
        worktree = packet["worktrees"][side]
        compile_row = packet["compiles"][side]
        lines.append(
            f"| {side} | `{worktree['commit']}` | `{worktree['include']['sha256']}` | "
            f"`{worktree['source']['sha256']}` | `{compile_row['ex5']['sha256']}` | "
            f"{compile_row['strict_summary']['errors']} errors, {compile_row['strict_summary']['warnings']} warnings |"
        )
    lines.extend(
        [
            "",
            "The only deliberate compiler-input difference is the complete `framework/include` tree at the parent versus `b0bdc4d72`. The EA source bytes, MetaEditor bytes, standard-library source, set file, tester build, custom history, window, model, seed, deposit, currency, and leverage are frozen identically.",
            "",
            "Include delta:",
            "",
        ]
    )
    lines.extend(f"- `{row}`" for row in packet["worktrees"]["include_delta"])
    lines.extend(
        [
            "",
            "## Exact Deals comparison",
            "",
            "| Measure | Parent | Integration | Result |",
            "|---|---:|---:|---|",
            f"| Native Deals rows | {pre['deal_count']} | {post['deal_count']} | {'IDENTISCH' if comparison['row_diff']['identical'] else 'ABWEICHEND'} |",
            f"| Canonical Deals SHA-256 | `{pre['canonical_deals_sha256']}` | `{post['canonical_deals_sha256']}` | {'IDENTISCH' if comparison['checks']['canonical_deal_bytes_equal'] else 'ABWEICHEND'} |",
            f"| Differing rows | {comparison['row_diff']['different_row_count']} | {comparison['row_diff']['different_row_count']} | {'none' if comparison['row_diff']['identical'] else 'see JSON diff'} |",
            f"| History inventory | `{pre['history_before']['sha256']}` | `{post['history_before']['sha256']}` | {'IDENTICAL' if comparison['checks']['history_profiles_identical'] else 'DIFFERENT'} |",
            "",
            "## Integration-run input echo",
            "",
        ]
    )
    echo = comparison["post_input_echo"]["observed"]
    lines.extend(f"- `{name}={echo.get(name)}`" for name in exact.POST_INPUTS)
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            (
                "The two native Deals byte streams are identical and every documented Deals field matches. The six new pattern-permission inputs echo zero. Orchestrator/OWNER may review this proof when deciding the compile-wave hold; this artifact does not lift the hold itself."
                if outcome == "IDENTISCH"
                else "The exact one-variable comparison differs. Because all non-Include inputs are frozen, retain the hold and use the machine-readable first-field differences for root-cause review in the pattern integration path."
            ),
            "",
            "## Safety",
            "",
            "- No EX5 is stored in Git or the EA inventory.",
            "- T1-T10, T_Live, AutoTrading, queue rows, and pipeline verdicts were not changed.",
            "- Outbound firewall blocks covered every disposable MetaEditor, terminal, and tester executable for the duration of its use and were removed at closeout.",
            "- `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and `qm_news_stale_max_hours <= 336` were enforced before launch.",
            "",
        ]
    )
    return "\n".join(lines)


def _write_run_artifacts(
    *,
    evidence_dir: Path,
    packet: dict[str, Any],
    pre_bytes: bytes,
    post_bytes: bytes,
) -> dict[str, Any]:
    paths = {
        "report": evidence_dir / f"{OUTPUT_STEM}.md",
        "packet": evidence_dir / f"{OUTPUT_STEM}_packet.json",
        "comparison": evidence_dir / f"{OUTPUT_STEM}_comparison.csv",
        "deal_diff": evidence_dir / f"{OUTPUT_STEM}_deal_diff.json",
        "parent_deals": evidence_dir / f"{OUTPUT_STEM}_parent_deals.jsonl",
        "integration_deals": evidence_dir / f"{OUTPUT_STEM}_integration_deals.jsonl",
        "input_echo": evidence_dir / f"{OUTPUT_STEM}_integration_input_echo.json",
    }
    atomic_bytes(paths["parent_deals"], pre_bytes)
    atomic_bytes(paths["integration_deals"], post_bytes)
    atomic_json(paths["deal_diff"], packet["comparison"]["row_diff"])
    atomic_json(paths["input_echo"], packet["comparison"]["post_input_echo"])
    write_comparison_csv(paths["comparison"], packet)
    copies: dict[str, Any] = {}
    for side in ("parent", "integration"):
        copies[f"{side}_compile_log"] = _copy_evidence_file(
            Path(packet["compiles"][side]["log"]["path"]),
            evidence_dir / f"{OUTPUT_STEM}_{side}.compile.log",
        )
        copies[f"{side}_report"] = _copy_evidence_file(
            Path(packet["runs"][side]["report"]["path"]),
            evidence_dir / f"{OUTPUT_STEM}_{side}_native_report.htm",
        )
        copies[f"{side}_tester_ini"] = _copy_evidence_file(
            Path(packet["runs"][side]["tester_ini"]["path"]),
            evidence_dir / f"{OUTPUT_STEM}_{side}_tester.ini",
        )
        tester_log = packet["runs"][side].get("tester_log")
        if tester_log:
            copies[f"{side}_tester_log"] = _copy_evidence_file(
                Path(tester_log["path"]),
                evidence_dir / f"{OUTPUT_STEM}_{side}_tester.log",
            )
    packet["evidence_files"] = {
        **{name: str(path.resolve()) for name, path in paths.items()},
        "copies": copies,
    }
    atomic_json(paths["packet"], packet)
    atomic_bytes(paths["report"], (render_markdown(packet) + "\n").encode("utf-8"))
    return {name: str(path.resolve()) for name, path in paths.items()}


def execute(args: argparse.Namespace) -> dict[str, Any]:
    repo_root = args.repo_root.resolve()
    evidence_dir = args.evidence_dir.resolve()
    artifact_root = args.artifact_root.resolve()
    template_root = args.template_root.resolve()
    expected_evidence_dir = repo_root / "docs" / "ops" / "evidence"
    if evidence_dir != expected_evidence_dir.resolve():
        raise ProofError(f"evidence directory must be canonical: {expected_evidence_dir}")
    if _git(repo_root, "branch", "--show-current") != "agents/board-advisor":
        raise ProofError("canonical checkout is not on agents/board-advisor")
    if not ARTIFACTS_BASE.is_dir():
        raise ProofError(f"artifact base missing: {ARTIFACTS_BASE}")
    authorization = validate_authorization(args.authorization_manifest, artifact_root)
    artifact_root.parent.mkdir(parents=True, exist_ok=True)
    assert_create_only_path(artifact_root, ARTIFACTS_BASE)
    if not template_root.is_dir():
        raise ProofError(f"template root missing: {template_root}")
    if re.search(r"(?i)\\(?:T_Live|T(?:10|[1-9]))(?:\\|$)", str(artifact_root)):
        raise ProofError(f"artifact root may not target a factory/live terminal: {artifact_root}")

    source_path = repo_root / SOURCE_RELATIVE
    setfile_path = repo_root / SET_RELATIVE
    groups_path = repo_root / "framework" / "registry" / "tester_groups" / "Darwinex-Live_real.canonical.txt"
    packet: dict[str, Any] = {
        "schema": SCHEMA,
        "task_id": TASK_ID,
        "generated_at": utc_now(),
        "execution_status": "FAILED",
        "outcome": "NOT_PROVEN",
        "pipeline_verdict": None,
        "authorization": {
            "path": str(args.authorization_manifest.resolve()),
            "sha256": sha256_file(args.authorization_manifest),
            "manifest": authorization,
            "feature_flag": FLAG_NAME,
            "process_value": os.environ.get(FLAG_NAME),
        },
        "artifact_root": str(artifact_root),
        "factory_terminals_before": sorted(running_terminal_names()),
        "firewall": {"rules": [], "closeout": []},
    }
    firewall_rules: list[dict[str, Any]] = []
    artifact_root.mkdir(parents=True, exist_ok=False)
    canonical_before = {
        "source": file_binding(source_path),
        "setfile": file_binding(setfile_path),
        "runner": file_binding(Path(__file__)),
        "tester_groups": file_binding(groups_path),
    }
    packet["setup"] = {
        "symbol": SYMBOL,
        "period": PERIOD,
        "model": MODEL,
        "seed": SEED,
        "from_date": FROM_DATE,
        "to_date": TO_DATE,
        "runtime_expert": RUNTIME_EXPERT,
        "setfile": canonical_before["setfile"],
        "guardrails": parse_setfile_guard(setfile_path, source_path),
        "canonical_before": canonical_before,
        "template_root": str(template_root),
        "template_programs_before": {
            name: file_binding(template_root / name)
            for name in ("MetaEditor64.exe", "terminal64.exe", "metatester64.exe")
        },
        "template_history_before": history_inventory(template_root),
        "template_standard_include_before": tree_inventory(
            template_root / "MQL5" / "Include"
        ),
        "template_config_before": tree_inventory(template_root / "Config"),
        "template_mql5_files_before": tree_inventory(template_root / "MQL5" / "Files"),
        "common_news_before": common_news_bindings(),
    }
    try:
        packet["worktrees"] = prepare_worktrees(repo_root, artifact_root)
        prepared_compilers = {
            side: prepare_compiler(
                side=side,
                worktree=Path(packet["worktrees"][side]["worktree"]),
                template_root=template_root,
                artifact_root=artifact_root,
            )
            for side in ("parent", "integration")
        }
        for side, prepared in prepared_compilers.items():
            rule = add_firewall_rule(f"compiler_{side}", Path(prepared["metaeditor"]))
            firewall_rules.append(rule)
            packet["firewall"]["rules"].append(rule)
        packet["compiles"] = {
            side: compile_side(prepared_compilers[side])
            for side in ("parent", "integration")
        }
        if (
            packet["compiles"]["parent"]["metaeditor"]["sha256"]
            != packet["compiles"]["integration"]["metaeditor"]["sha256"]
        ):
            raise ProofError("compiler executable bytes differ between sides")
        if not (
            packet["compiles"]["parent"]["source"]["sha256"]
            == packet["compiles"]["integration"]["source"]["sha256"]
            == canonical_before["source"]["sha256"]
        ):
            raise ProofError("compiler staged source bytes differ between sides")
        prepared_profiles = {
            side: prepare_test_profile(
                side=side,
                template_root=template_root,
                artifact_root=artifact_root,
                ex5_path=Path(packet["compiles"][side]["ex5"]["path"]),
                setfile_path=setfile_path,
                tester_groups_path=groups_path,
            )
            for side in ("parent", "integration")
        }
        if not (
            prepared_profiles["parent"]["history_before"]["sha256"]
            == prepared_profiles["integration"]["history_before"]["sha256"]
            == packet["setup"]["template_history_before"]["sha256"]
        ):
            raise ProofError("portable history projections are not identical")
        for side, prepared in prepared_profiles.items():
            common_inputs = prepared["common_inputs"]
            if (
                common_inputs["config"]["sha256"]
                != packet["setup"]["template_config_before"]["sha256"]
                or common_inputs["mql5_files"]["sha256"]
                != packet["setup"]["template_mql5_files_before"]["sha256"]
                or common_inputs["tester_groups"]["sha256"]
                != canonical_before["tester_groups"]["sha256"]
            ):
                raise ProofError(f"{side} portable shared-input copy mismatch")
        for side, prepared in prepared_profiles.items():
            for label in ("terminal", "metatester"):
                rule = add_firewall_rule(f"profile_{side}", Path(prepared[label]))
                firewall_rules.append(rule)
                packet["firewall"]["rules"].append(rule)
        packet["runs"] = {
            side: run_test_profile(prepared_profiles[side])
            for side in ("parent", "integration")
        }
        comparison, pre_bytes, post_bytes = build_comparison(
            packet["runs"]["parent"], packet["runs"]["integration"]
        )
        packet["comparison"] = comparison
        packet["outcome"] = "IDENTISCH" if comparison["identical"] else "ABWEICHEND"
        packet["execution_status"] = "COMPLETE"
        packet["completed_at"] = utc_now()
        packet["factory_terminals_after"] = sorted(running_terminal_names())
        packet["setup"]["template_programs_after"] = {
            name: file_binding(template_root / name)
            for name in ("MetaEditor64.exe", "terminal64.exe", "metatester64.exe")
        }
        packet["setup"]["template_history_after"] = history_inventory(template_root)
        packet["setup"]["template_standard_include_after"] = tree_inventory(
            template_root / "MQL5" / "Include"
        )
        packet["setup"]["template_config_after"] = tree_inventory(template_root / "Config")
        packet["setup"]["template_mql5_files_after"] = tree_inventory(
            template_root / "MQL5" / "Files"
        )
        packet["setup"]["common_news_after"] = common_news_bindings()
        canonical_after = {
            "source": file_binding(source_path),
            "setfile": file_binding(setfile_path),
            "runner": file_binding(Path(__file__)),
            "tester_groups": file_binding(groups_path),
        }
        packet["setup"]["canonical_after"] = canonical_after
        packet["setup"]["canonical_inputs_unchanged"] = canonical_before == canonical_after
        packet["setup"]["template_programs_unchanged"] = (
            packet["setup"]["template_programs_before"]
            == packet["setup"]["template_programs_after"]
        )
        packet["setup"]["template_history_unchanged"] = (
            packet["setup"]["template_history_before"]["sha256"]
            == packet["setup"]["template_history_after"]["sha256"]
        )
        packet["setup"]["template_standard_include_unchanged"] = (
            packet["setup"]["template_standard_include_before"]["sha256"]
            == packet["setup"]["template_standard_include_after"]["sha256"]
        )
        packet["setup"]["template_config_unchanged"] = (
            packet["setup"]["template_config_before"]["sha256"]
            == packet["setup"]["template_config_after"]["sha256"]
        )
        packet["setup"]["template_mql5_files_unchanged"] = (
            packet["setup"]["template_mql5_files_before"]["sha256"]
            == packet["setup"]["template_mql5_files_after"]["sha256"]
        )
        packet["setup"]["common_news_unchanged"] = (
            packet["setup"]["common_news_before"] == packet["setup"]["common_news_after"]
        )
        if not all(
            packet["setup"][name]
            for name in (
                "canonical_inputs_unchanged",
                "template_programs_unchanged",
                "template_history_unchanged",
                "template_standard_include_unchanged",
                "template_config_unchanged",
                "template_mql5_files_unchanged",
                "common_news_unchanged",
            )
        ):
            raise ProofError("shared frozen input changed during proof")
    except Exception as exc:
        packet["execution_status"] = "FAILED"
        packet["outcome"] = "NOT_PROVEN"
        packet["exception"] = f"{type(exc).__name__}: {exc}"
        packet["completed_at"] = utc_now()
        pre_bytes = b""
        post_bytes = b""
    finally:
        for rule in reversed(firewall_rules):
            packet["firewall"]["closeout"].append(remove_firewall_rule(rule))
        packet["firewall"]["all_removed"] = all(
            row.get("removed") is True for row in packet["firewall"]["closeout"]
        )
        if not packet["firewall"]["all_removed"]:
            packet["execution_status"] = "FAILED"
            packet["outcome"] = "NOT_PROVEN"
            packet["exception"] = "FIREWALL_CLOSEOUT_NOT_PROVEN"

    if packet["execution_status"] == "COMPLETE":
        outputs = _write_run_artifacts(
            evidence_dir=evidence_dir,
            packet=packet,
            pre_bytes=pre_bytes,
            post_bytes=post_bytes,
        )
    else:
        packet_path = evidence_dir / f"{OUTPUT_STEM}_packet.json"
        report_path = evidence_dir / f"{OUTPUT_STEM}.md"
        atomic_json(packet_path, packet)
        atomic_bytes(report_path, (render_markdown(packet) + "\n").encode("utf-8"))
        outputs = {"packet": str(packet_path), "report": str(report_path)}
    return {
        "status": packet["execution_status"],
        "outcome": packet["outcome"],
        "outputs": outputs,
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=REPO_IMPORT_ROOT)
    parser.add_argument("--template-root", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--evidence-dir", type=Path, default=DEFAULT_EVIDENCE_DIR)
    parser.add_argument("--authorization-manifest", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    try:
        result = execute(parse_args(argv))
    except Exception as exc:
        print(json.dumps({"status": "FAILED", "outcome": "NOT_PROVEN", "error": f"{type(exc).__name__}: {exc}"}, indent=2))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "COMPLETE" else 2


if __name__ == "__main__":
    raise SystemExit(main())
