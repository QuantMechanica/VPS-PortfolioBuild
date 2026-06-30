"""Audit EA/setfile conformance for strategy parameter drift.

This is a lightweight static guard for the failure mode where an EA compiles
but its backtest setfiles omit the strategy-specific values from the card/spec.
It does not prove the strategy is correct; it identifies EAs whose backtests are
likely evaluating defaults or stale parameters instead of the intended rule.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable


DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = Path("framework") / "EAs"

INPUT_RE = re.compile(
    r"^\s*input\s+(?P<type>[A-Za-z_][\w:<>,\s\*&]*)\s+"
    r"(?P<name>[A-Za-z_]\w*)\s*=\s*(?P<default>[^;]+);",
    re.MULTILINE,
)
TIME_RE = re.compile(r"\b(?:[01]?\d|2[0-3]):[0-5]\d\b")
SPEC_PARAM_RE = re.compile(
    r"\|\s*`?(?P<name>strategy_[A-Za-z0-9_]+)`?\s*\|\s*`?(?P<default>[^|`]+)`?\s*\|"
)

TIME_PARAM_TOKENS = (
    "hour",
    "hhmm",
    "minute",
    "session",
    "range_start",
    "range_end",
    "entry_start",
    "entry_end",
    "exit",
    "friday",
    "time",
)
TACTICAL_KEYWORDS = (
    "asian",
    "balke",
    "big-ben",
    "break",
    "breakout",
    "eod",
    "london",
    "open",
    "overnight",
    "range",
    "session",
    "time",
)


@dataclass(frozen=True)
class StrategyInput:
    name: str
    default: str
    type_name: str


@dataclass(frozen=True)
class Finding:
    severity: str
    ea: str
    symbol: str
    setfile: str
    code: str
    detail: str


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def _parse_strategy_inputs(mq5: Path) -> list[StrategyInput]:
    text = _read_text(mq5)
    inputs: list[StrategyInput] = []
    for match in INPUT_RE.finditer(text):
        name = match.group("name")
        if name.startswith("strategy_"):
            inputs.append(
                StrategyInput(
                    name=name,
                    default=match.group("default").strip(),
                    type_name=" ".join(match.group("type").split()),
                )
            )
    return inputs


def _parse_setfile(path: Path) -> tuple[dict[str, str], list[str]]:
    values: dict[str, str] = {}
    comments: list[str] = []
    for raw in _read_text(path).splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith(";") or line.startswith("#"):
            comments.append(line)
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values, comments


def _header_fields(comments: Iterable[str]) -> dict[str, str]:
    fields: dict[str, str] = {}
    for comment in comments:
        body = comment.lstrip(";#").strip()
        if ":" in body:
            key, value = body.split(":", 1)
            fields[key.strip()] = value.strip()
    return fields


def _symbol_from_setfile(ea_dir: Path, setfile: Path) -> str:
    stem = setfile.stem
    prefix = ea_dir.name + "_"
    if stem.startswith(prefix):
        stem = stem[len(prefix) :]
    for tf in ("_M1_", "_M5_", "_M15_", "_M30_", "_H1_", "_H4_", "_D1_", "_W1_"):
        if tf in stem:
            return stem.split(tf, 1)[0]
    return ""


def _is_time_input(name: str) -> bool:
    lower = name.lower()
    return any(token in lower for token in TIME_PARAM_TOKENS)


def _strategy_text(ea_dir: Path) -> str:
    parts = []
    for rel in ("SPEC.md", "strategy_card.md", "docs/strategy_card.md"):
        path = ea_dir / rel
        if path.exists():
            parts.append(_read_text(path))
    mq5s = list(ea_dir.glob("*.mq5"))
    if mq5s:
        parts.append(_read_text(mq5s[0])[:10000])
    return "\n".join(parts)


def _is_tactical(ea_dir: Path, text: str) -> bool:
    haystack = f"{ea_dir.name}\n{text}".lower()
    return any(keyword in haystack for keyword in TACTICAL_KEYWORDS)


def _spec_defaults(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for match in SPEC_PARAM_RE.finditer(text):
        result[match.group("name")] = match.group("default").strip()
    return result


def audit(repo_root: Path) -> list[Finding]:
    ea_root = repo_root / EA_ROOT
    findings: list[Finding] = []
    required_header = {
        "ea_id",
        "ea_slug",
        "ea_version",
        "set_version",
        "symbol",
        "timeframe",
        "environment",
        "magic_slot",
        "risk_mode",
        "portfolio_weight",
        "build_hash",
        "author",
        "date",
    }

    for ea_dir in sorted(p for p in ea_root.iterdir() if p.is_dir()):
        mq5s = sorted(ea_dir.glob("*.mq5"))
        if not mq5s:
            continue
        inputs = _parse_strategy_inputs(mq5s[0])
        input_names = {item.name for item in inputs}
        time_input_names = {item.name for item in inputs if _is_time_input(item.name)}
        text = _strategy_text(ea_dir)
        tactical = _is_tactical(ea_dir, text)
        spec_times = sorted(set(TIME_RE.findall(text)))
        spec_default_map = _spec_defaults(text)

        sets_dir = ea_dir / "sets"
        if not sets_dir.exists():
            continue

        for setfile in sorted(sets_dir.glob("*.set")):
            values, comments = _parse_setfile(setfile)
            strategy_keys = {key for key in values if key.startswith("strategy_")}
            symbol = _symbol_from_setfile(ea_dir, setfile)
            rel = str(setfile.relative_to(repo_root))
            header = _header_fields(comments)
            missing_header = sorted(required_header - set(header))
            comments_text = "\n".join(comments)

            if missing_header:
                findings.append(
                    Finding(
                        "medium",
                        ea_dir.name,
                        symbol,
                        rel,
                        "SETFILE_HEADER_INCOMPLETE",
                        "missing " + ",".join(missing_header[:6]) + ("..." if len(missing_header) > 6 else ""),
                    )
                )

            if "card_defaults_source=not_found" in comments_text:
                findings.append(
                    Finding(
                        "medium" if inputs else "low",
                        ea_dir.name,
                        symbol,
                        rel,
                        "CARD_DEFAULTS_SOURCE_NOT_FOUND",
                        "setfile was generated without card/default extraction evidence",
                    )
                )

            if inputs and not strategy_keys:
                findings.append(
                    Finding(
                        "high" if tactical else "medium",
                        ea_dir.name,
                        symbol,
                        rel,
                        "MISSING_STRATEGY_PARAMS_IN_SETFILE",
                        f"EA defines {len(inputs)} strategy inputs; setfile overrides none",
                    )
                )

            if tactical and time_input_names and not (strategy_keys & time_input_names):
                findings.append(
                    Finding(
                        "high",
                        ea_dir.name,
                        symbol,
                        rel,
                        "TIME_SENSITIVE_DEFAULTS_ONLY",
                        "time/session/range inputs exist but setfile does not override them: "
                        + ",".join(sorted(time_input_names)[:8]),
                    )
                )

            missing_inputs = sorted(input_names - strategy_keys)
            if strategy_keys and missing_inputs and tactical:
                findings.append(
                    Finding(
                        "medium",
                        ea_dir.name,
                        symbol,
                        rel,
                        "PARTIAL_STRATEGY_PARAM_SET",
                        f"{len(missing_inputs)} strategy inputs left at EA defaults",
                    )
                )

            mismatches = []
            for name, spec_default in spec_default_map.items():
                if name in values and values[name] != spec_default:
                    mismatches.append(f"{name}:spec={spec_default},set={values[name]}")
            if mismatches:
                findings.append(
                    Finding(
                        "medium",
                        ea_dir.name,
                        symbol,
                        rel,
                        "SPEC_DEFAULT_SETFILE_MISMATCH",
                        "; ".join(mismatches[:4]),
                    )
                )

            if tactical and spec_times and not strategy_keys:
                findings.append(
                    Finding(
                        "high",
                        ea_dir.name,
                        symbol,
                        rel,
                        "SPEC_HAS_TIMES_BUT_SETFILE_HAS_NO_STRATEGY_PARAMS",
                        "spec/card contains times " + ",".join(spec_times[:8]),
                    )
                )

    return findings


def write_csv(findings: list[Finding], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(asdict(findings[0]).keys()) if findings else ["severity", "ea", "symbol", "setfile", "code", "detail"])
        writer.writeheader()
        for finding in findings:
            writer.writerow(asdict(finding))


def write_markdown(findings: list[Finding], path: Path, limit: int = 200) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    counts: dict[str, int] = {}
    for finding in findings:
        counts[finding.code] = counts.get(finding.code, 0) + 1

    lines = [
        "# Strategy Conformance Audit",
        "",
        "Static audit for EA/setfile drift. High findings mean a backtest may be evaluating EA defaults or stale values instead of the intended card/spec.",
        "",
        "## Summary",
        "",
    ]
    for code, count in sorted(counts.items(), key=lambda item: (-item[1], item[0])):
        lines.append(f"- {code}: {count}")
    lines.extend(["", "## Top Findings", ""])
    lines.append("| severity | EA | symbol | code | detail | setfile |")
    lines.append("|---|---|---|---|---|---|")
    rank = {"high": 0, "medium": 1, "low": 2}
    for finding in sorted(findings, key=lambda f: (rank.get(f.severity, 9), f.ea, f.symbol, f.code))[:limit]:
        detail = finding.detail.replace("|", "\\|")
        lines.append(f"| {finding.severity} | {finding.ea} | {finding.symbol} | {finding.code} | {detail} | `{finding.setfile}` |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO_ROOT)
    parser.add_argument("--json", type=Path)
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--markdown", type=Path)
    parser.add_argument("--fail-on-high", action="store_true")
    args = parser.parse_args()

    findings = audit(args.repo_root.resolve())
    data = [asdict(finding) for finding in findings]
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")
    if args.csv:
        write_csv(findings, args.csv)
    if args.markdown:
        write_markdown(findings, args.markdown)
    if not (args.json or args.csv or args.markdown):
        print(json.dumps(data, indent=2, sort_keys=True))
    if args.fail_on_high and any(f.severity == "high" for f in findings):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
