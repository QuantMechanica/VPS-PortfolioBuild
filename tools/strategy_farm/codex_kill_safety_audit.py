"""Audit every local QM worktree for process lifecycle code unsafe to Codex."""

from __future__ import annotations

import argparse
import ast
import json
import os
import subprocess
from pathlib import Path
from typing import Iterable


CANONICAL_REPO = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))
WORKTREE_PARENT = Path(os.environ.get("QM_WORKTREE_PARENT", r"C:\QM\worktrees"))
EXTRA_RUNTIME_FILES = (
    Path("scripts/aggregator/standalone_aggregator_loop.py"),
    Path("framework/scripts/mt5_worker.py"),
    Path("framework/scripts/q03_plateau_runner.py"),
    Path("framework/scripts/multi_ea_scheduler.py"),
)


def discover_repo_roots(
    canonical_repo: Path = CANONICAL_REPO,
    worktree_parent: Path = WORKTREE_PARENT,
) -> list[Path]:
    roots: set[Path] = set()
    if canonical_repo.exists():
        roots.add(canonical_repo.resolve())
    try:
        result = subprocess.run(
            ["git", "-C", str(canonical_repo), "worktree", "list", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if line.startswith("worktree "):
                    candidate = Path(line.removeprefix("worktree ").strip())
                    if candidate.exists():
                        roots.add(candidate.resolve())
    except Exception:
        pass

    # Include orphaned/unregistered directories as well.  One hazardous copy
    # found during the incident was no longer present in `git worktree list`.
    if worktree_parent.exists():
        for candidate in worktree_parent.iterdir():
            if (candidate / "tools" / "strategy_farm").is_dir():
                roots.add(candidate.resolve())
    return sorted(roots, key=lambda path: os.path.normcase(str(path)))


def _has_global_codex_kill(source: str) -> bool:
    lower = source.lower()
    discovers_codex_globally = (
        "get-process -name codex" in lower
        or ("win32_process" in lower and "codex.exe" in lower)
        or ("get-process" in lower and "codex.exe" in lower)
    )
    force_kills = "taskkill" in lower or "stop-process" in lower
    return discovers_codex_globally and force_kills


def _bare_pid_force_kill_scope(source: str, path: Path) -> str | None:
    """Reject unowned PID force-killers in controllers that can target Codex."""

    if path.name not in {
        "farmctl.py",
        "codex_fleet_pacer.py",
        "start_terminal_workers.py",
    }:
        return None
    try:
        tree = ast.parse(source)
    except SyntaxError:
        lower = source.lower()
        if "taskkill" in lower or "stop-process" in lower:
            return "python_parse_fallback"
        return None

    scopes: list[ast.AST]
    if path.name == "farmctl.py":
        # `_stop_pid_tree` is a narrowly scoped parent->own-child capability:
        # terminal_worker uses it only for the run_smoke/terminal64 tree it
        # launched.  The unsafe controller path is `_stop_pid`, which receives
        # historical database PIDs and must remain fail-closed.
        function_names = {"_stop_pid"}
        scopes = [
            node
            for node in ast.walk(tree)
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
            and node.name in function_names
        ]
    elif path.name == "start_terminal_workers.py":
        scopes = [
            node
            for node in ast.walk(tree)
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
            and node.name == "_stop_pid"
        ]
    else:
        scopes = [tree]
    for scope in scopes:
        for node in ast.walk(scope):
            if not isinstance(node, ast.Constant) or not isinstance(node.value, str):
                continue
            lower = node.value.lower()
            if "taskkill" in lower or "stop-process" in lower:
                return f"line:{getattr(node, 'lineno', 0)}"
    return None


def _windows_test_value(node: ast.AST) -> bool | None:
    """Return the value of a simple platform test when running on Windows."""

    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
        value = _windows_test_value(node.operand)
        return None if value is None else not value
    if not isinstance(node, ast.Compare) or len(node.ops) != 1 or len(node.comparators) != 1:
        return None

    left, right = node.left, node.comparators[0]

    def platform_literal(candidate: ast.AST) -> str | None:
        if isinstance(candidate, ast.Attribute) and isinstance(candidate.value, ast.Name):
            if candidate.value.id == "sys" and candidate.attr == "platform":
                return "win32"
            if candidate.value.id == "os" and candidate.attr == "name":
                return "nt"
        return None

    expected = platform_literal(left)
    actual = right.value if isinstance(right, ast.Constant) else None
    if expected is None:
        expected = platform_literal(right)
        actual = left.value if isinstance(left, ast.Constant) else None
    if expected is None or not isinstance(actual, str):
        return None
    equal = actual.lower() == expected
    if isinstance(node.ops[0], ast.Eq):
        return equal
    if isinstance(node.ops[0], ast.NotEq):
        return not equal
    return None


def _block_guarantees_exit(statements: list[ast.stmt]) -> bool:
    for statement in statements:
        if isinstance(statement, (ast.Return, ast.Raise, ast.Break, ast.Continue)):
            return True
        if isinstance(statement, ast.If):
            if (
                statement.orelse
                and _block_guarantees_exit(statement.body)
                and _block_guarantees_exit(statement.orelse)
            ):
                return True
        if isinstance(statement, (ast.With, ast.AsyncWith)):
            if _block_guarantees_exit(statement.body):
                return True
        if isinstance(statement, ast.Try):
            body_exits = _block_guarantees_exit(statement.body)
            handlers_exit = all(
                _block_guarantees_exit(handler.body) for handler in statement.handlers
            )
            if _block_guarantees_exit(statement.finalbody):
                return True
            if body_exits and handlers_exit:
                return True
    return False


def _zero_signal_reachable_on_windows(
    call: ast.Call, parents: dict[ast.AST, ast.AST]
) -> bool:
    """Conservatively prove whether a signal-zero call can run on Windows."""

    current: ast.AST = call
    while current in parents:
        parent = parents[current]
        if isinstance(parent, ast.If):
            value = _windows_test_value(parent.test)
            if value is not None:
                if current in parent.body and not value:
                    return False
                if current in parent.orelse and value:
                    return False

        if isinstance(current, ast.stmt):
            for _field_name, field_value in ast.iter_fields(parent):
                if not isinstance(field_value, list) or current not in field_value:
                    continue
                current_index = field_value.index(current)
                for previous in field_value[:current_index]:
                    if not isinstance(previous, ast.If):
                        continue
                    value = _windows_test_value(previous.test)
                    if value is True and _block_guarantees_exit(previous.body):
                        return False
                    if (
                        value is False
                        and previous.orelse
                        and _block_guarantees_exit(previous.orelse)
                    ):
                        return False
        current = parent
    return True


def _zero_signal_scope(source: str, path: Path) -> str | None:
    """Find Windows-destructive ``os.kill(pid, 0)`` probes.

    Signal zero is allowed only when AST control flow proves that a Windows
    platform guard returns, raises, breaks, or continues before the call.
    """

    try:
        tree = ast.parse(source)
    except SyntaxError:
        for index, line in enumerate(source.splitlines()):
            compact = "".join(line.split()).lower()
            if "os.kill(" in compact and compact.endswith(",0)"):
                return f"line:{index + 1}:python_parse_fallback"
        return None

    parents = {
        child: parent
        for parent in ast.walk(tree)
        for child in ast.iter_child_nodes(parent)
    }
    for child in ast.walk(tree):
        if not isinstance(child, ast.Call) or len(child.args) < 2:
            continue
        function = child.func
        is_os_kill = (
            isinstance(function, ast.Attribute)
            and isinstance(function.value, ast.Name)
            and function.value.id == "os"
            and function.attr == "kill"
        )
        zero_signal = isinstance(child.args[1], ast.Constant) and child.args[1].value == 0
        if not is_os_kill or not zero_signal:
            continue
        if not _zero_signal_reachable_on_windows(child, parents):
            continue
        owner = child
        while owner in parents and not isinstance(
            owner, (ast.FunctionDef, ast.AsyncFunctionDef)
        ):
            owner = parents[owner]
        owner_name = getattr(owner, "name", "<module>")
        return f"function:{owner_name}:line:{getattr(child, 'lineno', 0)}"
    return None


def _unsafe_scope(source: str, suffix: str) -> str | None:
    if suffix.lower() == ".py":
        try:
            tree = ast.parse(source)
        except SyntaxError:
            # The safety audit is not a general syntax gate.  Fall back to a
            # local text window so an unrelated legacy syntax error cannot
            # disable the pump.
            lines = source.splitlines()
            for index, line in enumerate(lines):
                lower = line.lower()
                if "codex.exe" not in lower and "get-process -name codex" not in lower:
                    continue
                window = "\n".join(lines[max(0, index - 30) : index + 31])
                if _has_global_codex_kill(window):
                    return f"line:{index + 1}:python_parse_fallback"
            return None
        lines = source.splitlines()
        for node in ast.walk(tree):
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            end_lineno = int(getattr(node, "end_lineno", node.lineno))
            segment = "\n".join(lines[node.lineno - 1 : end_lineno])
            if _has_global_codex_kill(segment):
                return f"function:{node.name}"
        return None

    # PowerShell has no stdlib parser here.  Require discovery and force-kill
    # within one compact window so unrelated diagnostics and lifecycle code do
    # not create a false positive.
    lines = source.splitlines()
    for index, line in enumerate(lines):
        lower = line.lower()
        if "codex.exe" not in lower and "get-process -name codex" not in lower:
            continue
        window = "\n".join(lines[max(0, index - 30) : index + 31])
        if _has_global_codex_kill(window):
            return f"line:{index + 1}"
    return None


def audit_repo_roots(repo_roots: Iterable[Path]) -> dict[str, object]:
    roots = list(repo_roots)
    unsafe: list[dict[str, str]] = []
    scanned_files = 0
    for repo_root in roots:
        farm_dir = repo_root / "tools" / "strategy_farm"
        if not farm_dir.is_dir():
            continue
        candidates = set((*farm_dir.glob("*.py"), *farm_dir.glob("*.ps1")))
        candidates.update(
            repo_root / relative
            for relative in EXTRA_RUNTIME_FILES
            if (repo_root / relative).is_file()
        )
        for path in sorted(candidates):
            if path.name == Path(__file__).name:
                continue
            scanned_files += 1
            try:
                source = path.read_text(encoding="utf-8", errors="replace")
            except OSError as exc:
                unsafe.append(
                    {"repo_root": str(repo_root), "path": str(path), "reason": f"read_failed:{exc}"}
                )
                continue
            zero_signal_scope = (
                _zero_signal_scope(source, path) if path.suffix.lower() == ".py" else None
            )
            if zero_signal_scope:
                unsafe.append(
                    {
                        "repo_root": str(repo_root),
                        "path": str(path),
                        "reason": (
                            "windows_destructive_os_kill_zero:"
                            f"{zero_signal_scope}"
                        ),
                    }
                )
                continue
            bare_pid_kill_scope = (
                _bare_pid_force_kill_scope(source, path)
                if path.suffix.lower() == ".py"
                else None
            )
            if bare_pid_kill_scope:
                unsafe.append(
                    {
                        "repo_root": str(repo_root),
                        "path": str(path),
                        "reason": (
                            "identity_less_persisted_pid_force_kill:"
                            f"{bare_pid_kill_scope}"
                        ),
                    }
                )
                continue
            unsafe_scope = _unsafe_scope(source, path.suffix)
            if unsafe_scope:
                unsafe.append(
                    {
                        "repo_root": str(repo_root),
                        "path": str(path),
                        "reason": (
                            "global_codex_discovery_combined_with_force_kill:"
                            f"{unsafe_scope}"
                        ),
                    }
                )
    return {
        "safe": not unsafe,
        "repo_roots_scanned": len(roots),
        "files_scanned": scanned_files,
        "unsafe": unsafe,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    roots = discover_repo_roots()
    report = audit_repo_roots(roots)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    elif report["safe"]:
        print(f"PASS: {report['files_scanned']} Strategy Farm scripts in {len(roots)} repo roots")
    else:
        for item in report["unsafe"]:
            print(f"FAIL: {item['path']}: {item['reason']}")
    return 0 if report["safe"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
