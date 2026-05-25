"""Static validator: flag multi-symbol leak in single-symbol EAs.

Audit context — 2026-05-23 Q02 hang investigation surfaced that several
"single-symbol" EAs were silently reading data for symbols other than
_Symbol (iClose(other), iTime(other), Bars(other), CopyXxx(other),
SymbolSelect(other), SymbolInfo<X>(other)), which forces the MT5 tester
to load history for those symbols. The runtime QM_SymbolGuard module
(FW7) logs violations but does not block — this validator catches them
at build time so they never reach the pipeline.

Verdicts:
  SINGLE_SYMBOL_OK         — no foreign-symbol calls
  BASKET_OK                — foreign-symbol calls present AND every foreign
                             symbol referenced is declared in
                             basket_manifest.json's basket_symbols[]
  MULTI_SYMBOL_LEAK_NOT_DECLARED
                           — foreign-symbol calls present, no manifest
  MULTI_SYMBOL_LEAK_NOT_IN_MANIFEST
                           — manifest present but a referenced symbol is
                             not in basket_symbols[]

Whitelist: bare `_Symbol`, the string "" (defaults to current symbol),
`NULL` literal, and variables explicitly named _Symbol — these count as
the EA's own symbol and are always permitted.

Usage:
    python validate_symbol_scope.py --ea-label QM5_10026_rw-fx-squeeze-mr
    python validate_symbol_scope.py --all              # audit every EA dir
    python validate_symbol_scope.py --json --all       # machine-readable
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[2]
EAS_DIR = REPO_ROOT / "framework" / "EAs"

# Functions whose first string argument is a symbol the tester must load
# data for. We grep the .mq5 for these and inspect the first argument.
SYMBOL_FIRST_ARG_FUNCS: set[str] = {
    # Series + price accessors
    "iClose", "iOpen", "iHigh", "iLow", "iTime", "iVolume", "iTickVolume",
    "iSpread", "iRealVolume", "iBars", "Bars",
    # Copy* family
    "CopyClose", "CopyOpen", "CopyHigh", "CopyLow", "CopyTime",
    "CopyTickVolume", "CopyRealVolume", "CopySpread", "CopyRates",
    # Symbol-info / select
    "SymbolSelect", "SymbolInfoDouble", "SymbolInfoInteger",
    "SymbolInfoString", "SymbolInfoTick", "SymbolInfoSessionQuote",
    "SymbolInfoSessionTrade", "SymbolInfoMarginRate",
    # Indicator-handle builders (also load symbol history)
    "iMA", "iATR", "iRSI", "iStdDev", "iBands", "iMACD", "iCCI", "iStochastic",
    "iADX", "iADXWilder", "iAlligator", "iAC", "iAD", "iAO", "iBearsPower",
    "iBullsPower", "iBWMFI", "iChaikin", "iDeMarker", "iEnvelopes",
    "iForce", "iFractals", "iGator", "iIchimoku", "iMomentum", "iMFI",
    "iOBV", "iOsMA", "iRVI", "iSAR", "iTriX", "iVIDyA", "iVolumes",
    "iWPR",
    # Framework wrappers — also accept first arg = symbol
    "QM_ATR", "QM_SMA", "QM_EMA", "QM_LWMA", "QM_SMMA", "QM_WMA",
    "QM_RSI", "QM_StdDev", "QM_BB_Upper", "QM_BB_Lower", "QM_BB_Middle",
    "QM_MACD_Main", "QM_MACD_Signal", "QM_ADX", "QM_CCI", "QM_Stoch_Main",
    "QM_Stoch_Signal", "QM_IndATR", "QM_IndMA", "QM_IndStdDev", "QM_IndRSI",
    "QM_IndBands", "QM_IndMACD", "QM_IndADX", "QM_IndCCI", "QM_IndStoch",
}

# These first-argument tokens are always considered "this EA's own symbol".
SELF_SYMBOL_TOKENS: set[str] = {
    "_Symbol", "NULL", '""', "'',", "Symbol()",
}

# Regex: function name followed by `(`. We then extract the first argument
# by parser-tracking matched parens/quotes.
CALL_PATTERN = re.compile(
    r"\b(" + "|".join(re.escape(f) for f in SYMBOL_FIRST_ARG_FUNCS) + r")\s*\("
)

# Identifiers we treat as "self-symbol variables" — common patterns in EA
# code that pass _Symbol indirectly via a const string at file scope.
SELF_SYMBOL_VAR_RE = re.compile(
    r"^(g_(qm_)?symbol|symbol|sym|_sym|own_symbol)$", re.IGNORECASE
)

# Symbol literals we treat as foreign. MT5 symbol naming: letters + digits
# + dot + underscore + slash + hyphen. e.g. "EURUSD.DWX", "SP500.DWX",
# "AUDUSD", "BTC/USD".
SYMBOL_LITERAL_RE = re.compile(
    r'^"([A-Za-z][A-Za-z0-9._/\-]{2,})"$'
)

LINE_COMMENT = re.compile(r"//.*$")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)


@dataclass
class Violation:
    ea_label: str
    file: str
    line: int
    col: int
    func: str
    first_arg: str
    raw_call: str


@dataclass
class EAResult:
    ea_label: str
    ea_dir: str
    verdict: str
    n_violations: int
    referenced_foreign_symbols: list[str] = field(default_factory=list)
    manifest_symbols: list[str] | None = None
    violations: list[Violation] = field(default_factory=list)
    note: str = ""


def strip_comments(text: str) -> str:
    """Remove // and /* */ comments — they may contain text that looks
    like a call but shouldn't be flagged."""
    text = BLOCK_COMMENT.sub("", text)
    out_lines = []
    for ln in text.splitlines():
        out_lines.append(LINE_COMMENT.sub("", ln))
    return "\n".join(out_lines)


def extract_first_arg(source: str, start_paren: int) -> tuple[str, int]:
    """Given the index of `(` after a function name, return (first_arg_text,
    end_index_of_arg). Handles nested parens and double-quoted strings."""
    depth = 1
    i = start_paren + 1
    arg_start = i
    while i < len(source):
        ch = source[i]
        if ch == '"':
            # Skip over string literal (no escape handling — MQL5 rarely uses it for symbol names)
            j = i + 1
            while j < len(source) and source[j] != '"':
                j += 1
            i = j + 1
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return source[arg_start:i].strip(), i
        elif ch == "," and depth == 1:
            return source[arg_start:i].strip(), i
        i += 1
    return source[arg_start:].strip(), len(source)


def classify_arg(arg: str) -> tuple[str, str | None]:
    """Return (kind, literal_value):
       kind in {'self', 'foreign_literal', 'variable', 'expression'}
       literal_value is the unquoted symbol if kind == 'foreign_literal'."""
    a = arg.strip()
    if not a:
        return "self", None  # empty arg → defaults to _Symbol in MT5
    if a in SELF_SYMBOL_TOKENS:
        return "self", None
    if a.endswith("()") and a[:-2].strip() == "Symbol":
        return "self", None
    m = SYMBOL_LITERAL_RE.match(a)
    if m:
        return "foreign_literal", m.group(1)
    # Identifier (no parens, no quotes, no operators)
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", a):
        if SELF_SYMBOL_VAR_RE.match(a):
            return "self", None
        return "variable", a  # unknown variable — could be self or foreign
    return "expression", a


def find_violations(ea_label: str, mq5_path: Path) -> tuple[list[Violation], set[str], set[str]]:
    """Walk the .mq5 source. Return (violations, foreign_literals, unknown_vars)."""
    raw = mq5_path.read_text(encoding="utf-8", errors="replace")
    text = strip_comments(raw)
    violations: list[Violation] = []
    foreign_literals: set[str] = set()
    unknown_vars: set[str] = set()

    # Build line-offset table for reporting
    line_starts = [0]
    for i, ch in enumerate(text):
        if ch == "\n":
            line_starts.append(i + 1)

    def pos_to_line_col(pos: int) -> tuple[int, int]:
        lo, hi = 0, len(line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if line_starts[mid] <= pos:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1, pos - line_starts[lo] + 1

    for m in CALL_PATTERN.finditer(text):
        func = m.group(1)
        paren_idx = m.end() - 1
        arg, _end = extract_first_arg(text, paren_idx)
        kind, val = classify_arg(arg)
        if kind == "self":
            continue
        if kind == "foreign_literal":
            assert val is not None
            foreign_literals.add(val)
            line, col = pos_to_line_col(m.start())
            violations.append(Violation(
                ea_label=ea_label, file=str(mq5_path), line=line, col=col,
                func=func, first_arg=arg, raw_call=text[m.start():_end + 1][:120],
            ))
        elif kind == "variable":
            # Variable holding a symbol — could be self or foreign. Record as
            # unknown rather than violation to avoid false positives.
            unknown_vars.add(val or arg)

    return violations, foreign_literals, unknown_vars


def load_manifest(ea_dir: Path) -> dict | None:
    mpath = ea_dir / "basket_manifest.json"
    if not mpath.exists():
        return None
    try:
        return json.loads(mpath.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def audit_ea(ea_label: str, ea_dir: Path) -> EAResult:
    mq5 = ea_dir / f"{ea_label}.mq5"
    if not mq5.exists():
        return EAResult(ea_label=ea_label, ea_dir=str(ea_dir), verdict="NO_MQ5",
                        n_violations=0, note=f".mq5 not found at {mq5}")

    violations, foreign_literals, unknown_vars = find_violations(ea_label, mq5)
    manifest = load_manifest(ea_dir)
    manifest_syms = sorted(set(manifest.get("basket_symbols") or [])) if manifest else None

    note_parts = []
    if unknown_vars:
        note_parts.append(f"unresolved variable args (not flagged): {sorted(unknown_vars)}")

    if not foreign_literals:
        verdict = "SINGLE_SYMBOL_OK" if not manifest else "BASKET_OK"
        if manifest and verdict == "BASKET_OK":
            note_parts.append("basket_manifest.json present but no foreign-symbol literals "
                              "found in source — manifest may be redundant or symbols are "
                              "passed via variables.")
        return EAResult(
            ea_label=ea_label, ea_dir=str(ea_dir), verdict=verdict, n_violations=0,
            referenced_foreign_symbols=[], manifest_symbols=manifest_syms,
            violations=[], note=" | ".join(note_parts),
        )

    if manifest is None:
        return EAResult(
            ea_label=ea_label, ea_dir=str(ea_dir),
            verdict="MULTI_SYMBOL_LEAK_NOT_DECLARED",
            n_violations=len(violations),
            referenced_foreign_symbols=sorted(foreign_literals),
            manifest_symbols=None,
            violations=violations,
            note=" | ".join(note_parts) or "Add basket_manifest.json declaring these symbols, "
                                            "OR refactor the EA to use _Symbol only.",
        )

    not_in_manifest = sorted(foreign_literals - set(manifest_syms or []))
    if not_in_manifest:
        return EAResult(
            ea_label=ea_label, ea_dir=str(ea_dir),
            verdict="MULTI_SYMBOL_LEAK_NOT_IN_MANIFEST",
            n_violations=len(violations),
            referenced_foreign_symbols=sorted(foreign_literals),
            manifest_symbols=manifest_syms,
            violations=[v for v in violations
                       if SYMBOL_LITERAL_RE.match(v.first_arg)
                       and SYMBOL_LITERAL_RE.match(v.first_arg).group(1) in not_in_manifest],
            note=("Symbols referenced in source but not in basket_manifest.json: "
                  + ", ".join(not_in_manifest)) + (" | " + " | ".join(note_parts) if note_parts else ""),
        )

    return EAResult(
        ea_label=ea_label, ea_dir=str(ea_dir), verdict="BASKET_OK",
        n_violations=0,
        referenced_foreign_symbols=sorted(foreign_literals),
        manifest_symbols=manifest_syms,
        violations=[], note=" | ".join(note_parts),
    )


def iter_all_eas() -> Iterable[tuple[str, Path]]:
    for d in sorted(EAS_DIR.iterdir()):
        if d.is_dir() and d.name.startswith("QM5_"):
            yield d.name, d


def format_text(result: EAResult, verbose: bool) -> str:
    lines = [f"{result.ea_label:<50}  {result.verdict}  n_violations={result.n_violations}"]
    if result.referenced_foreign_symbols:
        lines.append(f"    foreign symbols referenced: {', '.join(result.referenced_foreign_symbols)}")
    if result.manifest_symbols is not None:
        lines.append(f"    manifest declares:          {len(result.manifest_symbols)} symbols")
    if result.note:
        lines.append(f"    note: {result.note}")
    if verbose and result.violations:
        for v in result.violations[:10]:
            lines.append(f"    L{v.line:>4} col{v.col:>3}  {v.func}({v.first_arg})")
        if len(result.violations) > 10:
            lines.append(f"    ... +{len(result.violations) - 10} more")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--ea-label", help="single EA dir name, e.g. QM5_10026_rw-fx-squeeze-mr")
    ap.add_argument("--all", action="store_true", help="audit every EA under framework/EAs/")
    ap.add_argument("--json", action="store_true", help="machine-readable JSON output")
    ap.add_argument("--verbose", "-v", action="store_true", help="show first 10 violation sites")
    ap.add_argument("--fail-on-leak", action="store_true",
                    help="exit code 1 if any MULTI_SYMBOL_LEAK_* verdict found")
    args = ap.parse_args(argv)

    if not args.ea_label and not args.all:
        ap.error("specify --ea-label <name> or --all")

    targets: list[tuple[str, Path]]
    if args.all:
        targets = list(iter_all_eas())
    else:
        ea_dir = EAS_DIR / args.ea_label
        if not ea_dir.is_dir():
            print(f"no such EA dir: {ea_dir}", file=sys.stderr)
            return 2
        targets = [(args.ea_label, ea_dir)]

    results: list[EAResult] = [audit_ea(label, d) for label, d in targets]

    if args.json:
        out = []
        for r in results:
            d = {
                "ea_label": r.ea_label,
                "ea_dir": r.ea_dir,
                "verdict": r.verdict,
                "n_violations": r.n_violations,
                "referenced_foreign_symbols": r.referenced_foreign_symbols,
                "manifest_symbols": r.manifest_symbols,
                "note": r.note,
            }
            if args.verbose:
                d["violations"] = [
                    {"file": v.file, "line": v.line, "col": v.col,
                     "func": v.func, "first_arg": v.first_arg, "raw_call": v.raw_call}
                    for v in r.violations[:25]
                ]
            out.append(d)
        print(json.dumps(out, indent=2))
    else:
        # Summary
        from collections import Counter
        verdicts = Counter(r.verdict for r in results)
        print(f"=== validate_symbol_scope — {len(results)} EAs audited ===")
        for v, n in sorted(verdicts.items(), key=lambda x: -x[1]):
            print(f"  {v:<40}  {n}")
        print()
        # Detail per EA
        for r in sorted(results, key=lambda x: (
            0 if x.verdict.startswith("MULTI_SYMBOL_LEAK") else 1, x.ea_label
        )):
            print(format_text(r, verbose=args.verbose))
            print()

    if args.fail_on_leak:
        leaks = sum(1 for r in results if r.verdict.startswith("MULTI_SYMBOL_LEAK"))
        if leaks:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
