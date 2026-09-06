"""Inventory MQL symbol literals and non-chart market-data access.

The scanner is deliberately file based. It never imports, preprocesses, compiles, or
rewrites MQL. Build-check consumes the same JSON contract used for the corpus report.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re
import subprocess


DEFAULT_REPO = Path("C:/QM/repo")
DEFAULT_BASELINE_COMMIT = "bb584c73239c5bd9f7ba98d2bf5863bafa8cfe48"
SYMBOL_LITERAL = re.compile(
    r'"(?P<symbol>(?:(?:AUD|CAD|CHF|EUR|GBP|JPY|NZD|USD){2}'
    r'|XAUUSD|XAGUSD|XTIUSD|XNGUSD|NDX|WS30|GDAXI|UK100|SP500'
    r'|USOIL\.cash|GER40\.cash)(?:\.DWX)?)"'
)
MARKET_API = re.compile(
    r"\b(?P<api>SymbolSelect|CopyRates|CopyOpen|CopyHigh|CopyLow|CopyClose|CopyTime|"
    r"iOpen|iHigh|iLow|iClose|iTime|iBarShift|SymbolInfoDouble|SymbolInfoInteger|"
    r"SymbolInfoString|SymbolInfoTick)\s*\(\s*(?P<first>[^,\r\n]{1,200})\s*,",
    re.IGNORECASE,
)
EA_ID = re.compile(r"(?:^|/)QM5_(?P<ea_id>\d+)_")
REGISTRY_INCLUDE = re.compile(
    r"^framework/include/QM/(?:QM_MagicRegistry|QM_MagicResolver|QM_SymbolAliases)\.mqh$",
    re.IGNORECASE,
)


def blank_comments(text: str) -> str:
    return re.sub(
        r"/\*.*?\*/|//[^\r\n]*",
        lambda match: re.sub(r"[^\r\n]", " ", match.group(0)),
        text,
        flags=re.DOTALL | re.MULTILINE,
    )


def generated_slot_lines(text: str) -> set[int]:
    allowed: set[int] = set()
    active = False
    structural = False
    lines = text.splitlines()
    for number, line in enumerate(lines, 1):
        if "QM_SYMBOL_LITERAL_ALLOW: GENERATED_SLOT_TABLE_BEGIN" in line:
            active = True
            continue
        if "QM_SYMBOL_LITERAL_ALLOW: GENERATED_SLOT_TABLE_END" in line:
            active = False
            continue
        if not structural and re.search(
            r"\bstring\s+\w*(?:registry|slot|basket)\w*\s*\[\s*\d+\s*\]\s*=", line, re.IGNORECASE
        ):
            context = "\n".join(lines[max(0, number - 8) : number])
            structural = "Registry slot order" in context and "contract" in context
        if active or structural:
            allowed.add(number)
        if structural and re.match(r"^\s*};\s*$", line):
            structural = False
    return allowed


def tracked_at_cutover(repo: Path, commit: str) -> set[str]:
    result = subprocess.run(
        ["git", "-C", str(repo), "ls-tree", "-r", "--name-only", commit],
        capture_output=True,
        text=True,
        check=True,
    )
    return set(result.stdout.splitlines())


def mql_files(repo: Path, ea_label: str | None) -> list[Path]:
    if ea_label:
        roots = [repo / "framework/EAs" / ea_label]
    else:
        roots = [repo / "framework/EAs", repo / "framework/include", repo / "framework/templates"]
    files: list[Path] = []
    for root in roots:
        if root.is_dir():
            files.extend(path for path in root.rglob("*") if path.suffix.lower() in {".mq5", ".mqh"})
    return sorted(set(files))


def scan(repo: Path, ea_label: str | None, baseline_commit: str, priority_ids: list[int]) -> dict:
    findings: list[dict] = []
    multisymbol: dict[str, dict] = {}
    files = mql_files(repo, ea_label)
    cutover_paths = tracked_at_cutover(repo, baseline_commit)

    for path in files:
        relative = path.relative_to(repo).as_posix()
        raw = path.read_text(encoding="utf-8", errors="replace")
        code = blank_comments(raw)
        slot_lines = generated_slot_lines(raw)
        input_lines = {
            number
            for number, line in enumerate(code.splitlines(), 1)
            if re.match(r"^\s*input\s+string\s+\w+\s*=", line)
        }
        existing = relative in cutover_paths

        for match in SYMBOL_LITERAL.finditer(code):
            line_number = code.count("\n", 0, match.start()) + 1
            if REGISTRY_INCLUDE.match(relative):
                classification = "registry_include"
            elif line_number in slot_lines:
                classification = "generated_slot_table"
            elif line_number in input_lines:
                classification = "symbol_input_default"
            else:
                classification = "trading_logic_literal"
            if classification == "trading_logic_literal":
                severity = "WARN" if existing else "FAIL"
            else:
                severity = "ALLOW"
            findings.append(
                {
                    "path": relative,
                    "line": line_number,
                    "symbol": match.group("symbol"),
                    "classification": classification,
                    "severity": severity,
                    "existed_at_cutover": existing,
                }
            )

        api_counts: Counter[str] = Counter()
        examples: list[dict] = []
        for match in MARKET_API.finditer(code):
            first = re.sub(r"\s+", " ", match.group("first")).strip()
            if first in {"_Symbol", "NULL"}:
                continue
            api = match.group("api")
            api_counts[api] += 1
            if len(examples) < 5:
                examples.append(
                    {"line": code.count("\n", 0, match.start()) + 1, "api": api, "first_arg": first}
                )
        if api_counts:
            id_match = EA_ID.search(relative)
            ea_id = int(id_match.group("ea_id")) if id_match else None
            multisymbol[relative] = {
                "path": relative,
                "ea_id": ea_id,
                "priority_candidate": ea_id in priority_ids,
                "call_count": sum(api_counts.values()),
                "apis": dict(sorted(api_counts.items())),
                "examples": examples,
            }

    class_counts = Counter(item["classification"] for item in findings)
    severity_counts = Counter(item["severity"] for item in findings)
    literal_sources = {item["path"] for item in findings}
    rows = sorted(
        multisymbol.values(),
        key=lambda row: (not row["priority_candidate"], row["ea_id"] is None, row["ea_id"] or 0, row["path"]),
    )
    api_source_paths: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        for api in row["apis"]:
            api_source_paths[api].add(row["path"])
    core_paths = api_source_paths["SymbolSelect"] | api_source_paths["CopyRates"]
    findings_by_id: dict[int, list[dict]] = defaultdict(list)
    files_by_id: dict[int, list[str]] = defaultdict(list)
    for path in files:
        relative = path.relative_to(repo).as_posix()
        match = EA_ID.search(relative)
        if match:
            files_by_id[int(match.group("ea_id"))].append(relative)
    for finding in findings:
        match = EA_ID.search(finding["path"])
        if match:
            findings_by_id[int(match.group("ea_id"))].append(finding)
    priority_candidates = []
    for ea_id in priority_ids:
        candidate_paths = sorted(files_by_id.get(ea_id, []))
        if not candidate_paths:
            continue
        candidate_multisymbol = [multisymbol[path] for path in candidate_paths if path in multisymbol]
        candidate_findings = findings_by_id.get(ea_id, [])
        priority_candidates.append(
            {
                "ea_id": ea_id,
                "paths": candidate_paths,
                "classification": "MULTI_SYMBOL_ACCESS" if candidate_multisymbol else "CHART_SYMBOL_ONLY",
                "non_chart_market_data_calls": sum(row["call_count"] for row in candidate_multisymbol),
                "symbol_literal_counts": dict(
                    sorted(Counter(row["classification"] for row in candidate_findings).items())
                ),
            }
        )
    return {
        "schema": "qm.ea-symbol-literal-inventory/v1",
        "baseline_commit": baseline_commit,
        "ea_label": ea_label,
        "summary": {
            "mql_sources_scanned": len(files),
            "symbol_literal_sources": len(literal_sources),
            "symbol_literal_occurrences": len(findings),
            "literal_class_counts": dict(sorted(class_counts.items())),
            "literal_severity_counts": dict(sorted(severity_counts.items())),
            "non_chart_market_data_sources": len(rows),
            "non_chart_market_data_calls": sum(row["call_count"] for row in rows),
            "symbolselect_or_copyrates_sources": len(core_paths),
            "api_source_counts": {
                api: len(paths) for api, paths in sorted(api_source_paths.items())
            },
            "priority_candidate_sources": sum(1 for row in rows if row["priority_candidate"]),
        },
        "findings": [row for row in findings if row["classification"] != "registry_include"],
        "priority_candidates": priority_candidates,
        "multi_symbol_sources": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--ea-label")
    parser.add_argument("--baseline-commit", default=DEFAULT_BASELINE_COMMIT)
    parser.add_argument(
        "--priority-ea-ids",
        default=(
            "10706,11421,11422,11910,13054,20048,1537,21505,"
            "13301,13213,1567,10919,11165,12778,11708,10939,10911,13128,10440,"
            "11132,12969,10403,10513,12567,12989,1556,13117,41372"
        ),
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    priority_ids = [int(value) for value in args.priority_ea_ids.split(",") if value.strip()]
    report = scan(args.repo_root.resolve(), args.ea_label, args.baseline_commit, priority_ids)
    encoded = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
