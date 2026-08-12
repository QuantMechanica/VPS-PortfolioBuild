#!/usr/bin/env python3
"""Read-only MT5 tester/history topology audit.

The filesystem layer resolves every runner terminal's mutable ``Tester`` and
history directories. A separate pure evaluator detects exact and nested
mutable-store overlaps across terminals/components and rejects live-adjacent
aliases. It never creates, relinks, copies, or removes a directory.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = "mt5-history-isolation-audit/v1"
DEFAULT_MT5_ROOT = Path(r"D:\QM\mt5")
DEFAULT_RUNNER_TERMINALS = ("T1", "T2", "T3", "T4", "T6", "T7", "T8", "T9", "T10")
DEFAULT_PROTECTED_ROOTS = (
    Path(r"C:\QM\mt5\T_Live"),
    Path(r"D:\QM\mt5\T_Live"),
    Path(r"D:\QM\mt5\T5"),
)
MUTABLE_COMPONENTS = ("Tester", "Bases", "Bases/Custom")


def _canonical_bytes(payload: Mapping[str, Any]) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def _identity(path: Path) -> str:
    # strict=False still resolves existing junction/symlink prefixes while
    # keeping missing components representable for a fail-closed finding.
    return os.path.normcase(str(path.resolve(strict=False))).rstrip("\\/")


def _normalize_identity_text(value: str) -> str:
    return os.path.normcase(os.path.normpath(value)).casefold().rstrip("\\/")


def _is_within(path_identity: str, root_identity: str) -> bool:
    try:
        return os.path.commonpath([path_identity, root_identity]) == root_identity
    except ValueError:
        return False


def _strictly_within(path_identity: str, root_identity: str) -> bool:
    return path_identity != root_identity and _is_within(path_identity, root_identity)


def _expected_same_terminal_nesting(
    left: Mapping[str, Any], right: Mapping[str, Any]
) -> bool:
    """Allow only the designed ``Bases`` -> ``Bases/Custom`` nesting."""

    if str(left["terminal"]).casefold() != str(right["terminal"]).casefold():
        return False
    components = {
        str(left["component"]).casefold(),
        str(right["component"]).casefold(),
    }
    if components != {"bases", "bases/custom"}:
        return False
    bases = left if str(left["component"]).casefold() == "bases" else right
    custom = right if bases is left else left
    return _strictly_within(
        str(custom["resolved_identity"]), str(bases["resolved_identity"])
    )


def evaluate_inventory(
    rows: Sequence[Mapping[str, Any]], *, protected_root_identities: Iterable[str]
) -> dict[str, Any]:
    """Evaluate already-resolved identity strings without filesystem access."""

    normalized_rows = []
    for source_row in rows:
        row = dict(source_row)
        missing = {
            key
            for key in ("terminal", "component", "path", "exists", "resolved_identity")
            if key not in row
        }
        if missing:
            raise ValueError(f"inventory row missing fields: {sorted(missing)}")
        if not str(row["terminal"]).strip() or not str(row["component"]).strip():
            raise ValueError("inventory terminal and component must be non-empty")
        row["resolved_identity"] = _normalize_identity_text(
            str(row["resolved_identity"])
        )
        if not row["resolved_identity"]:
            raise ValueError("inventory resolved_identity must be non-empty")
        normalized_rows.append(row)
    normalized_rows = sorted(
        normalized_rows,
        key=lambda row: (
            str(row["terminal"]).casefold(),
            str(row["component"]).casefold(),
            str(row["resolved_identity"]),
            str(row["path"]).casefold(),
            bool(row["exists"]),
        ),
    )
    findings: list[dict[str, Any]] = []
    identities: dict[tuple[str, str], list[str]] = {}

    for row in normalized_rows:
        terminal = str(row["terminal"])
        component = str(row["component"])
        exists = bool(row["exists"])
        identity = str(row["resolved_identity"])
        if not exists:
            findings.append(
                {
                    "code": "MUTABLE_STORE_MISSING",
                    "component": component,
                    "terminals": [terminal],
                    "resolved_identity": identity,
                }
            )
            continue
        identities.setdefault((component.casefold(), identity.casefold()), []).append(
            terminal
        )

    for (component, identity), terminals in sorted(identities.items()):
        unique = sorted(set(terminals))
        if len(unique) > 1:
            findings.append(
                {
                    "code": "CROSS_TERMINAL_MUTABLE_STORE_COLLISION",
                    "component": component,
                    "terminals": unique,
                    "resolved_identity": identity,
                }
            )

    # Exact cross-component aliases and ancestor/descendant aliases are unsafe
    # even when the component labels differ. The sole expected nesting is a
    # terminal's own Bases/Custom directory beneath that same terminal's Bases.
    existing_rows = [row for row in normalized_rows if bool(row["exists"])]
    for left_index, left in enumerate(existing_rows):
        for right in existing_rows[left_index + 1 :]:
            left_component = str(left["component"])
            right_component = str(right["component"])
            left_terminal = str(left["terminal"])
            right_terminal = str(right["terminal"])
            left_identity = str(left["resolved_identity"])
            right_identity = str(right["resolved_identity"])
            same_identity = left_identity == right_identity

            # The existing grouped finding is the compact representation for
            # exact same-component sharing across terminals.
            if (
                same_identity
                and left_component.casefold() == right_component.casefold()
                and left_terminal.casefold() != right_terminal.casefold()
            ):
                continue
            if _expected_same_terminal_nesting(left, right):
                continue

            left_contains_right = _strictly_within(right_identity, left_identity)
            right_contains_left = _strictly_within(left_identity, right_identity)
            if not (same_identity or left_contains_right or right_contains_left):
                continue

            components = sorted(
                {left_component.casefold(), right_component.casefold()}
            )
            terminals = sorted({left_terminal, right_terminal})
            if same_identity:
                code = (
                    "DUPLICATE_MUTABLE_STORE_INVENTORY_ROW"
                    if left_terminal.casefold() == right_terminal.casefold()
                    and left_component.casefold() == right_component.casefold()
                    else "CROSS_COMPONENT_MUTABLE_STORE_COLLISION"
                )
                relationship = "EXACT_IDENTITY"
                ancestor = None
                descendant = None
            else:
                code = (
                    "CROSS_TERMINAL_MUTABLE_STORE_OVERLAP"
                    if left_terminal.casefold() != right_terminal.casefold()
                    else (
                        "CROSS_COMPONENT_MUTABLE_STORE_OVERLAP"
                        if left_component.casefold() != right_component.casefold()
                        else "MUTABLE_STORE_ANCESTOR_OVERLAP"
                    )
                )
                relationship = "ANCESTOR_DESCENDANT"
                ancestor_row, descendant_row = (
                    (left, right) if left_contains_right else (right, left)
                )
                ancestor = {
                    "terminal": str(ancestor_row["terminal"]),
                    "component": str(ancestor_row["component"]),
                    "resolved_identity": str(ancestor_row["resolved_identity"]),
                }
                descendant = {
                    "terminal": str(descendant_row["terminal"]),
                    "component": str(descendant_row["component"]),
                    "resolved_identity": str(descendant_row["resolved_identity"]),
                }
            finding: dict[str, Any] = {
                "code": code,
                "component": " <-> ".join(components),
                "components": components,
                "terminals": terminals,
                "resolved_identity": (
                    left_identity
                    if same_identity
                    else str(ancestor["resolved_identity"])
                ),
                "relationship": relationship,
            }
            if ancestor is not None and descendant is not None:
                finding["ancestor"] = ancestor
                finding["descendant"] = descendant
            findings.append(finding)

    protected = sorted(
        {_normalize_identity_text(str(root)) for root in protected_root_identities}
    )
    for row in normalized_rows:
        if not row["exists"]:
            continue
        identity = str(row["resolved_identity"])
        overlaps = []
        for root in protected:
            if identity == root:
                relationship = "EXACT_IDENTITY"
            elif _strictly_within(identity, root):
                relationship = "MUTABLE_WITHIN_PROTECTED"
            elif _strictly_within(root, identity):
                relationship = "PROTECTED_WITHIN_MUTABLE"
            else:
                continue
            overlaps.append({"protected_root": root, "relationship": relationship})
        if overlaps:
            findings.append(
                {
                    "code": "LIVE_ADJACENT_STORE_ALIAS",
                    "component": str(row["component"]),
                    "terminals": [str(row["terminal"])],
                    "resolved_identity": identity,
                    "protected_roots": [
                        overlap["protected_root"] for overlap in overlaps
                    ],
                    "protected_root_overlaps": overlaps,
                }
            )

    findings.sort(
        key=lambda finding: (
            finding["code"],
            finding["component"],
            tuple(finding["terminals"]),
            finding["resolved_identity"],
        )
    )
    payload: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "audit_mode": "READ_ONLY",
        "runtime_action": "NONE",
        "status": "PASS_ISOLATED" if not findings else "FAIL_CLOSED",
        "runner_terminals": sorted({str(row["terminal"]) for row in normalized_rows}),
        "protected_roots": protected,
        "inventory": normalized_rows,
        "findings": findings,
    }
    payload["audit_sha256"] = hashlib.sha256(_canonical_bytes(payload)).hexdigest()
    return payload


def collect_inventory(
    *,
    mt5_root: Path | str = DEFAULT_MT5_ROOT,
    terminals: Sequence[str] = DEFAULT_RUNNER_TERMINALS,
) -> list[dict[str, Any]]:
    """Resolve the current topology. This function performs reads only."""

    root = Path(mt5_root)
    rows: list[dict[str, Any]] = []
    for terminal in sorted(set(terminals)):
        terminal_root = root / terminal
        for component in MUTABLE_COMPONENTS:
            path = terminal_root.joinpath(*component.split("/"))
            rows.append(
                {
                    "terminal": terminal,
                    "component": component,
                    "path": str(path),
                    "exists": path.is_dir(),
                    "resolved_identity": _identity(path),
                }
            )
    return rows


def resolve_protected_root_identities(
    protected_roots: Iterable[Path | str],
) -> tuple[str, ...]:
    """Filesystem boundary for protected roots; performs resolution reads only."""

    return tuple(
        sorted(
            {
                _normalize_identity_text(_identity(Path(root)))
                for root in protected_roots
            }
        )
    )


def audit_history_isolation(
    *,
    mt5_root: Path | str = DEFAULT_MT5_ROOT,
    terminals: Sequence[str] = DEFAULT_RUNNER_TERMINALS,
    protected_roots: Sequence[Path | str] = DEFAULT_PROTECTED_ROOTS,
) -> dict[str, Any]:
    return evaluate_inventory(
        collect_inventory(mt5_root=mt5_root, terminals=terminals),
        protected_root_identities=resolve_protected_root_identities(protected_roots),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    parser.add_argument("--terminal", action="append", dest="terminals")
    parser.add_argument("--protected-root", action="append", dest="protected_roots")
    args = parser.parse_args()
    payload = audit_history_isolation(
        mt5_root=args.mt5_root,
        terminals=tuple(args.terminals or DEFAULT_RUNNER_TERMINALS),
        protected_roots=tuple(
            Path(value)
            for value in (args.protected_roots or DEFAULT_PROTECTED_ROOTS)
        ),
    )
    print(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False))
    return 0 if payload["status"] == "PASS_ISOLATED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
