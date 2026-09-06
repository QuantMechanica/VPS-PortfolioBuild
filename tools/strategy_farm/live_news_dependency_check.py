#!/usr/bin/env python3
"""Static ENV=live guard for the V5 native-calendar news decision path.

This is intentionally file based.  It resolves each EA's local/QM include
closure and verifies that every live-capable news call reaches the sealed
QM_NewsFilter live branch.  It never starts or queries a terminal.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


INCLUDE_RE = re.compile(r"(?m)^\s*#include\s*[<\"]([^>\"]+)[>\"]")
NEWS_CALL_RE = re.compile(r"\bQM_NewsAllowsTrade(?:2|2Fresh)?\s*\(")


def resolve_include(source: Path, token: str, repo_root: Path) -> Path | None:
    normalized = token.replace("\\", "/")
    candidates = [source.parent / normalized]
    if normalized.startswith("QM/"):
        candidates.append(repo_root / "framework" / "include" / normalized)
    else:
        candidates.append(repo_root / "framework" / "include" / "QM" / normalized)
        candidates.append(repo_root / "framework" / "include" / normalized)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    return None


def include_closure(
    entry: Path,
    repo_root: Path,
    memo: dict[Path, set[Path]] | None = None,
    stack: set[Path] | None = None,
) -> set[Path]:
    current = entry.resolve()
    memo = memo if memo is not None else {}
    stack = stack if stack is not None else set()
    if current in memo:
        return memo[current]
    if current in stack or not current.is_file():
        return set()
    stack.add(current)
    closure = {current}
    text = current.read_text(encoding="utf-8-sig", errors="ignore")
    for token in INCLUDE_RE.findall(text):
        resolved = resolve_include(current, token, repo_root)
        if resolved is not None:
            closure.update(include_closure(resolved, repo_root, memo, stack))
    stack.remove(current)
    memo[current] = closure
    return closure


def extract_function(text: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^;]*?\)\s*\{{", text, re.S)
    if not match:
        return ""
    start = match.start()
    brace = text.find("{", match.start())
    depth = 0
    for index in range(brace, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[start:index + 1]
    return ""


def contract_defects(news_text: str) -> list[str]:
    defects: list[str] = []
    required_functions = (
        "QM_NewsLiveCalendarHealthy",
        "QM_NewsLiveTemporalAllows",
        "QM_NewsLiveComplianceAllows",
        "QM_NewsAllowsTrade2",
    )
    for function in required_functions:
        if not extract_function(news_text, function):
            defects.append(f"native_contract_function_missing:{function}")

    healthy = extract_function(news_text, "QM_NewsLiveCalendarHealthy")
    if "CalendarValueHistory" not in healthy or not re.search(r"return\s*\(\s*n\s*>\s*0\s*\)", healthy):
        defects.append("native_health_probe_not_population_bound")

    init = extract_function(news_text, "QM_NewsInit")
    if not re.search(
        r"MQLInfoInteger\s*\(\s*MQL_TESTER\s*\)\s*==\s*0.*?QM_NewsLiveSelfTest\s*\(",
        init,
        re.S,
    ):
        defects.append("live_attach_native_calendar_probe_missing")

    verdict = extract_function(news_text, "QM_NewsAllowsTrade2")
    if not re.search(r"if\s*\(\s*!\s*MQLInfoInteger\s*\(\s*MQL_TESTER\s*\)\s*\)", verdict):
        defects.append("live_non_tester_branch_missing")
    for call in ("QM_NewsLiveTemporalAllows", "QM_NewsLiveComplianceAllows"):
        if call not in verdict:
            defects.append(f"live_native_decision_call_missing:{call}")
    unavailable = re.search(
        r"if\s*\(\s*!\s*ok\s*\|\|\s*!\s*ok_comp\s*\)\s*\{(?P<body>.*?)\}",
        verdict,
        re.S,
    )
    if not unavailable or not re.search(r"verdict_live\s*=\s*false", unavailable.group("body")):
        defects.append("live_calendar_unavailable_not_fail_closed")
    if "g_qm_news_available" in verdict.split("if(!MQLInfoInteger", 1)[-1].split("return verdict_live", 1)[0]:
        defects.append("live_branch_depends_on_archive_availability")

    fresh = extract_function(news_text, "QM_NewsAllowsTrade2Fresh")
    if "QM_NewsLiveTemporalAllows" not in fresh or "QM_NewsLiveComplianceAllows" not in fresh:
        defects.append("fresh_live_native_decision_missing")
    if not re.search(r"if\s*\(\s*!\s*temporal_ok\s*\|\|\s*!\s*compliance_ok\s*\).*?return\s+false", fresh, re.S):
        defects.append("fresh_live_calendar_unavailable_not_fail_closed")
    return defects


def scan(repo_root: Path, ea_label: str | None = None) -> dict:
    ea_root = repo_root / "framework" / "EAs"
    roots = [ea_root / ea_label] if ea_label else sorted(p for p in ea_root.iterdir() if p.is_dir())
    targets: list[tuple[Path, set[Path]]] = []
    closure_cache: dict[Path, set[Path]] = {}
    text_cache: dict[Path, str] = {}
    news_call_cache: dict[Path, bool] = {}

    def read(path: Path) -> str:
        if path not in text_cache:
            text_cache[path] = path.read_text(encoding="utf-8-sig", errors="ignore")
        return text_cache[path]

    def has_news_call(path: Path) -> bool:
        if path not in news_call_cache:
            news_call_cache[path] = NEWS_CALL_RE.search(read(path)) is not None
        return news_call_cache[path]

    for root in roots:
        if not root.is_dir():
            continue
        live_presets = any(
            re.search(r"(?:live|active)", preset.name, re.I)
            for preset in (root / "sets").glob("*.set")
        )
        for ea in sorted(root.glob("*.mq5")):
            closure = include_closure(ea, repo_root, closure_cache)
            if live_presets or any(has_news_call(path) for path in closure):
                targets.append((ea, closure))

    findings: list[dict] = []
    checked_news_filters: set[Path] = set()
    for ea, closure in targets:
        news_filters = [path for path in closure if path.name.lower() == "qm_newsfilter.mqh"]
        if not news_filters:
            if any(has_news_call(path) for path in closure):
                findings.append({"ea": str(ea.relative_to(repo_root)), "defect": "news_call_without_newsfilter_closure"})
            continue
        for news_filter in news_filters:
            if news_filter in checked_news_filters:
                continue
            checked_news_filters.add(news_filter)
            text = read(news_filter)
            for defect in contract_defects(text):
                findings.append({
                    "ea": str(ea.relative_to(repo_root)),
                    "include": str(news_filter.relative_to(repo_root)),
                    "defect": defect,
                })
    return {
        "schema": "qm.live-news-dependency-check/v1",
        "environment": "live",
        "ea_sources_checked": len(targets),
        "news_filter_contracts_checked": len(checked_news_filters),
        "findings": findings,
        "ok": not findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--ea-label")
    args = parser.parse_args()
    report = scan(args.repo_root.resolve(), args.ea_label)
    print(json.dumps(report, sort_keys=True))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
