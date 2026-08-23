"""Fail closed when dispatch code grows a v3-only gate literal.

The active contract remains v3 until the separate activation ticket.  This
check therefore inspects source without importing dispatch workers, then builds
both manifests' runtime advancement tables explicitly.  Numeric dependency
tokens passed to ``GateManifest.dependency_role`` are lookups, not storage gate
decisions.  The only source allowlists are database UNION-read compatibility
and legacy alias/nomenclature maps.
"""

from __future__ import annotations

import ast
import re
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.strategy_farm.gate_manifest import (  # noqa: E402
    V3_MANIFEST,
    V4_DRAFT_MANIFEST,
    load_gate_manifest,
)
from tools.strategy_farm.phase_ids import build_advancement_table  # noqa: E402


DISPATCH_MODULES = (
    "tools/strategy_farm/farmctl.py",
    "tools/strategy_farm/q09_news_schema.py",
    "tools/strategy_farm/q10_confirmation_contract.py",
    "tools/strategy_farm/q09_news_runner.py",
    "tools/strategy_farm/q09_autoseal_hold_census.py",
    "tools/strategy_farm/health.py",
    "tools/strategy_farm/ea_metrics.py",
    "tools/strategy_farm/analyze_q04_survivor_cohort.py",
    "tools/strategy_farm/terminal_worker.py",
    "tools/strategy_farm/sweep_enqueue_built_eas.py",
    "tools/strategy_farm/repair.py",
    "tools/strategy_farm/r_eval_drain.py",
    "framework/scripts/q14_opt_admission.py",
    "framework/scripts/q15_freeze_check.py",
    "framework/scripts/q16_head_to_head.py",
    "framework/scripts/q10_confirmation.py",
)

# Tokens whose v3 meaning changes under the v4 proposal.  Q09/Q10 are included
# alongside the moved downstream gates; Q10A is the display-only v3 baseline.
V3_GATE_TOKENS = frozenset(
    {"Q09", "Q09_NEWS", "Q09_PORTFOLIO", "Q10", "Q10A"}
    | {f"Q{ordinal:02d}" for ordinal in range(11, 17)}
)
V4_COMPATIBILITY_TOKEN = {
    "Q09": "Q10",
    "Q09_NEWS": "Q10_NEWS",
    "Q09_PORTFOLIO": "Q10_PORTFOLIO",
    "Q10": "Q11",
    "Q10A": "Q09",
    "Q11": "Q15",
    "Q12": "Q16",
    "Q13": "Q17",
    "Q14": "Q12",
    "Q15": "Q13",
    "Q16": "Q14",
}
LEGACY_MAP_NAMES = frozenset({"PHASE_NOMENCLATURE", "LEGACY_P_TO_Q", "Q_TO_LEGACY_P"})
SQL_COMPAT_NAMES = frozenset(
    {"SCHEMA_SQL", "TRIGGERS", "ELIGIBILITY_VIEW", "DEPENDENCY_ROLES"}
)


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    token: str
    reason: str
    allowlisted: bool


def _parent_map(tree: ast.AST) -> dict[ast.AST, ast.AST]:
    return {child: parent for parent in ast.walk(tree) for child in ast.iter_child_nodes(parent)}


def _assignment_name(node: ast.AST, parents: dict[ast.AST, ast.AST]) -> str | None:
    cursor = node
    while cursor in parents:
        cursor = parents[cursor]
        if isinstance(cursor, ast.Assign):
            target = cursor.targets[0]
            return target.id if isinstance(target, ast.Name) else None
        if isinstance(cursor, ast.AnnAssign):
            return cursor.target.id if isinstance(cursor.target, ast.Name) else None
        if isinstance(cursor, (ast.FunctionDef, ast.ClassDef, ast.Module)):
            return None
    return None


def _is_manifest_lookup(node: ast.AST, parents: dict[ast.AST, ast.AST]) -> bool:
    parent = parents.get(node)
    return bool(
        isinstance(parent, ast.Call)
        and isinstance(parent.func, ast.Attribute)
        and parent.func.attr in {"dependency_role", "equivalent_gate"}
    )


def _is_sql_context(node: ast.AST, parents: dict[ast.AST, ast.AST]) -> bool:
    assignment = _assignment_name(node, parents)
    if assignment and (
        assignment in SQL_COMPAT_NAMES
        or any(marker in assignment.upper() for marker in ("SQL", "QUERY", "DDL", "VIEW"))
    ):
        return True
    cursor = node
    while cursor in parents:
        cursor = parents[cursor]
        if isinstance(cursor, ast.Call):
            func = cursor.func
            return isinstance(func, ast.Attribute) and func.attr in {
                "execute", "executemany", "executescript"
            }
        if isinstance(cursor, ast.Return):
            parent = parents.get(cursor)
            return isinstance(parent, ast.FunctionDef) and parent.name.endswith("_sql")
        if isinstance(cursor, (ast.FunctionDef, ast.ClassDef, ast.Module)):
            return False
    return False


def scan_source(path: Path) -> list[Finding]:
    relative = path.relative_to(REPO_ROOT).as_posix()
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(path))
    parents = _parent_map(tree)
    findings: list[Finding] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Constant) or not isinstance(node.value, str):
            continue
        value = node.value
        assignment = _assignment_name(node, parents)
        if value in V3_GATE_TOKENS:
            if _is_manifest_lookup(node, parents):
                continue
            if assignment in LEGACY_MAP_NAMES:
                findings.append(Finding(relative, node.lineno, value, "legacy P*/nomenclature alias map", True))
                continue
            if assignment in SQL_COMPAT_NAMES:
                findings.append(Finding(relative, node.lineno, value, "SQL UNION-read/schema compatibility", True))
                continue
            findings.append(Finding(relative, node.lineno, value, "exact v3 gate literal", False))
            continue
        if not _is_sql_context(node, parents):
            continue
        # Only gate tokens used in SQL phase/dependency predicates are routing
        # literals.  Prose, schema names, payload labels and error messages may
        # retain their historical contract names without dispatching work.
        sql_value = re.sub(r"--[^\n]*", "", value)
        decision_tokens = {
            token
            for token in V3_GATE_TOKENS
            if re.search(
                rf"(?:\bphase\b|\bdependency_role\b)[^;]{{0,320}}"
                rf"(?<![A-Z0-9_]){re.escape(token)}(?![A-Z0-9_])",
                sql_value,
                re.I,
            )
        }
        if not decision_tokens:
            continue
        for token in sorted(decision_tokens, key=len, reverse=True):
            v4_token = V4_COMPATIBILITY_TOKEN[token]
            compatible = assignment in SQL_COMPAT_NAMES or bool(
                re.search(rf"(?<![A-Z0-9_]){re.escape(v4_token)}(?![A-Z0-9_])", value)
            )
            findings.append(
                Finding(
                    relative,
                    node.lineno,
                    token,
                    "SQL UNION-read/schema compatibility" if compatible else "v3-only SQL gate literal",
                    compatible,
                )
            )
    return findings


def runtime_findings() -> list[str]:
    failures: list[str] = []
    contracts = (
        ("v3", load_gate_manifest(V3_MANIFEST)),
        ("v4", load_gate_manifest(V4_DRAFT_MANIFEST)),
    )
    expected = {
        "v3": ("Q08", "Q09_NEWS", "Q10", "Q14", "Q15", "Q16"),
        "v4": ("Q08", "Q09", "Q10_NEWS", "Q11", "Q12", "Q13", "Q14"),
    }
    for version, manifest in contracts:
        table = build_advancement_table(manifest)
        path: list[str] = ["Q08"]
        while table[path[-1]].next is not None:
            successor = table[path[-1]].next
            if successor in path:
                failures.append(f"{version}: routing cycle at {successor}")
                break
            path.append(str(successor))
        if tuple(path) != expected[version]:
            failures.append(f"{version}: runtime path {tuple(path)!r} != {expected[version]!r}")
        portfolio = manifest.gate_for_role("PORTFOLIO")
        if any(row.next == portfolio for row in table.values()):
            failures.append(f"{version}: automatic portfolio successor remains: {portfolio}")
        if manifest.portfolio_route(optimized=False) is not None or manifest.portfolio_route(optimized=True) is not None:
            failures.append(f"{version}: portfolio_routes remains executable")
    return failures


def main() -> int:
    findings = [
        finding
        for relative in DISPATCH_MODULES
        for finding in scan_source(REPO_ROOT / relative)
    ]
    for finding in sorted(findings, key=lambda row: (row.path, row.line, row.token)):
        disposition = "ALLOWLISTED" if finding.allowlisted else "VIOLATION"
        print(f"{disposition} {finding.path}:{finding.line} {finding.token} [{finding.reason}]")
    violations = [finding for finding in findings if not finding.allowlisted]
    runtime = runtime_findings()
    for failure in runtime:
        print(f"RUNTIME_VIOLATION {failure}")
    print(f"remaining_hardcoded_v3_gate_literals={len(violations)}")
    print(f"runtime_violations={len(runtime)}")
    return 1 if violations or runtime else 0


if __name__ == "__main__":
    raise SystemExit(main())
