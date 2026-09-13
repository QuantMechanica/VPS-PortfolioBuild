#!/usr/bin/env python3
"""Fail-closed lint for the Hard Rule "symbols are inputs, never code literals".

OWNER 2026-09-06 (Vault `01 Identity/Hard Rules` annex; V5_FRAMEWORK_DESIGN.md
principle 7): a V5 EA must take its symbols from the chart symbol or from an
``input``. ``.DWX`` is the factory custom-symbol name only; live (Darwinex Zero)
and FTMO charts carry the bare broker name.

The defect class this lint exists to prevent was diagnosed on 2026-09-13
(`docs/ops/evidence/2026-09-13_dxz_book_v2/REPAIR_DIAGNOSIS_DARK_SLEEVES.md`):
five EAs compared ``_Symbol`` (or a position symbol) against a hardcoded
``"XXXUSD.DWX"`` literal, so on a live chart the comparison was permanently
false and the sleeve never reached its entry path. Three of them sat dark in the
live book for seven weeks.

Two shapes are violations:

``symbol_literal_comparison``
    an ``==`` / ``!=`` comparison with a ``"<NAME>.DWX"`` string literal on
    either side -- the direct form.

``symbol_literal_global``
    a mutable global scalar ``string x = "<NAME>.DWX";`` that is later used in a
    comparison -- the indirect form (the literal hides one hop away, which is
    exactly how QM5_12778 / QM5_13117 evaded review).

Deliberately NOT violations, because they carry no symbol identity decision:

* ``input string ... = "XXXUSD.DWX";`` -- an input IS the sanctioned mechanism;
  the factory default may be the ``.DWX`` name.
* ``const``-qualified name tables and ``string x[] = {...}`` array literals used
  as registry/universe reference data.
* ``.DWX`` inside comments.

There is no allow-list: every EA that carries the defect is reported, always.
What the repo CANNOT do today is fix all of them at once -- the first repo-wide
run (2026-09-13) found 1670 violations across 838 of 4117 EA directories. So the
enforcing mode is a **ratchet**, not an exemption list: ``--baseline`` compares
the live inventory against a committed per-EA debt ledger and fails on any EA
that is new to the ledger or whose count grew. Shrinking is always allowed; the
ledger is meant to be rewritten downward, never upward.

Exit codes: 0 = clean / within baseline, 1 = violations (or a ratchet breach),
2 = bad invocation.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EA_ROOT = REPO_ROOT / "framework" / "EAs"

# A factory custom-symbol literal: "EURUSD.DWX", "XAGUSD.DWX", "WS30.DWX", ...
DWX_LITERAL = r'"[A-Za-z0-9_]{2,15}\.DWX"'

# <literal> == / != <expr>   or   <expr> == / != <literal>
COMPARISON_RE = re.compile(
    r"(?:" + DWX_LITERAL + r"\s*(?:==|!=)"
    r"|(?:==|!=)\s*" + DWX_LITERAL + r")"
)

# A global scalar string initialised from a .DWX literal, without `input`/`const`.
GLOBAL_STRING_RE = re.compile(
    r"^[ \t]*(?!.*\b(?:input|const|extern|static)\b)"
    r"string[ \t]+([A-Za-z_]\w*)[ \t]*=[ \t]*" + DWX_LITERAL + r"[ \t]*;",
    re.MULTILINE,
)

COMMENT_RE = re.compile(r"/\*.*?\*/|//[^\r\n]*", re.DOTALL)


@dataclass(frozen=True)
class Violation:
    path: Path
    line: int
    code: str
    message: str

    def render(self, root: Path) -> str:
        try:
            shown = self.path.relative_to(root)
        except ValueError:
            shown = self.path
        return f"{shown}:{self.line}: {self.code}: {self.message}"


def _blank_comments(text: str) -> str:
    """Blank comments but keep every newline, so line numbers stay exact."""
    return COMMENT_RE.sub(lambda m: re.sub(r"[^\r\n]", " ", m.group(0)), text)


def _line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def lint_text(path: Path, text: str) -> list[Violation]:
    code = _blank_comments(text)
    violations: list[Violation] = []
    seen: set[tuple[int, str]] = set()

    for match in COMPARISON_RE.finditer(code):
        line = _line_of(code, match.start())
        key = (line, "symbol_literal_comparison")
        if key in seen:
            continue
        seen.add(key)
        snippet = code.splitlines()[line - 1].strip()
        violations.append(
            Violation(
                path=path,
                line=line,
                code="symbol_literal_comparison",
                message=(
                    "symbol compared against a hardcoded .DWX literal; use an "
                    f"input and compare base names: {snippet}"
                ),
            )
        )

    for match in GLOBAL_STRING_RE.finditer(code):
        name = match.group(1)
        # Only a violation once the hidden literal actually drives a comparison.
        used_in_comparison = re.search(
            r"(?:==|!=)\s*\b" + re.escape(name) + r"\b"
            r"|\b" + re.escape(name) + r"\b\s*(?:==|!=)",
            code,
        )
        if not used_in_comparison:
            continue
        line = _line_of(code, match.start())
        key = (line, "symbol_literal_global")
        if key in seen:
            continue
        seen.add(key)
        violations.append(
            Violation(
                path=path,
                line=line,
                code="symbol_literal_global",
                message=(
                    f"global '{name}' hardcodes a .DWX symbol literal and is used "
                    "in a symbol comparison; declare it as an input instead"
                ),
            )
        )

    return violations


def lint_file(path: Path) -> list[Violation]:
    return lint_text(path, path.read_text(encoding="utf-8-sig", errors="replace"))


def lint_tree(ea_root: Path) -> list[Violation]:
    violations: list[Violation] = []
    for path in sorted(ea_root.rglob("*.mq5")) + sorted(ea_root.rglob("*.mqh")):
        violations.extend(lint_file(path))
    return sorted(violations, key=lambda v: (str(v.path), v.line, v.code))


def ea_counts(violations: list[Violation], ea_root: Path) -> dict[str, int]:
    """Violations folded to one count per EA directory under ``ea_root``."""
    counts: dict[str, int] = {}
    for violation in violations:
        try:
            relative = violation.path.relative_to(ea_root)
        except ValueError:
            relative = violation.path
        ea_dir = relative.parts[0] if relative.parts else str(relative)
        counts[ea_dir] = counts.get(ea_dir, 0) + 1
    return counts


def read_baseline(path: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        ea_dir, _, count = line.rpartition(" ")
        counts[ea_dir.strip()] = int(count)
    return counts


def format_baseline(counts: dict[str, int]) -> str:
    header = (
        "# Per-EA hardcoded-symbol-literal debt ledger (framework/scripts/\n"
        "# lint_ea_symbol_literals.py --baseline). Ratchet only: an EA may shrink\n"
        "# or disappear, never grow or appear. Regenerate with --write-baseline\n"
        "# ONLY after the count actually went down.\n"
    )
    body = "".join(f"{ea_dir} {count}\n" for ea_dir, count in sorted(counts.items()))
    return header + body


def check_baseline(counts: dict[str, int], baseline: dict[str, int]) -> list[str]:
    breaches: list[str] = []
    for ea_dir, count in sorted(counts.items()):
        allowed = baseline.get(ea_dir)
        if allowed is None:
            breaches.append(
                f"RATCHET_NEW_EA: {ea_dir} introduced {count} hardcoded-symbol "
                "violation(s); symbols must be inputs (OWNER 2026-09-06)"
            )
        elif count > allowed:
            breaches.append(
                f"RATCHET_REGRESSION: {ea_dir} grew from {allowed} to {count} "
                "hardcoded-symbol violation(s)"
            )
    return breaches


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lint_ea_symbol_literals")
    parser.add_argument(
        "--ea-root",
        type=Path,
        default=DEFAULT_EA_ROOT,
        help=f"EA source root (default: {DEFAULT_EA_ROOT})",
    )
    parser.add_argument(
        "--baseline",
        type=Path,
        default=None,
        help="Ratchet mode: fail only on EAs new to, or grown beyond, this ledger",
    )
    parser.add_argument(
        "--write-baseline",
        type=Path,
        default=None,
        help="Rewrite the ledger from the current tree (use only when it shrank)",
    )
    args = parser.parse_args(argv)

    if not args.ea_root.is_dir():
        print(f"EA_ROOT_MISSING: {args.ea_root}", file=sys.stderr)
        return 2

    violations = lint_tree(args.ea_root)
    counts = ea_counts(violations, args.ea_root)

    if args.write_baseline is not None:
        args.write_baseline.write_text(format_baseline(counts), encoding="utf-8", newline="\n")
        print(f"WROTE: {args.write_baseline} ({len(counts)} EAs, {len(violations)} violations)")
        return 0

    if args.baseline is not None:
        if not args.baseline.is_file():
            print(f"BASELINE_MISSING: {args.baseline}", file=sys.stderr)
            return 2
        breaches = check_baseline(counts, read_baseline(args.baseline))
        if breaches:
            for violation in violations:
                print(violation.render(args.ea_root))
            for breach in breaches:
                print(breach)
            return 1
        print(
            f"OK: no new hardcoded .DWX symbol literals "
            f"({len(violations)} known violations in {len(counts)} EAs, within baseline)"
        )
        return 0

    if not violations:
        print("OK: no hardcoded .DWX symbol literals in EA sources")
        return 0

    for violation in violations:
        print(violation.render(args.ea_root))
    print(f"FAIL: {len(violations)} hardcoded-symbol violation(s) in {len(counts)} EAs")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
