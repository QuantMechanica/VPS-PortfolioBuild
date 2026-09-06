"""Read-only census for EA-owned pins on framework inputs.

The audit deliberately separates the ticket's exact ``qm_rng_seed !=`` cohort
from the broader fail-closed build predicate.  It never edits EA sources or the
farm database and never enqueues work.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Any


TASK_ID = "65c5d9a1-ffbe-40d1-bd58-9f98c062f39d"
SEED_NEQ_RE = re.compile(r"\bqm_rng_seed\s*!=")
EA_LABEL_RE = re.compile(r"^QM5_(\d+)_")
HIT_RE = re.compile(r"^EA_FRAMEWORK_INPUT_PINNED:\s*(?P<path>.*\.mq5):(?P<line>\d+)\s+(?P<detail>.*)$")


def _read_only_connection(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _extract_marker(path: Path, marker: str) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        rf"^\s*#\s*QM-MARK:\s*BEGIN\s+{marker}\s*$(?P<body>.*?)"
        rf"^\s*#\s*QM-MARK:\s*END\s+{marker}\s*$",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not match:
        raise RuntimeError(f"QM-MARK block {marker} missing from {path}")
    return match.group("body")


def _predicate_hits(build_check: Path, sources: list[Path]) -> list[str]:
    powershell = shutil.which("pwsh") or shutil.which("powershell")
    if not powershell:
        raise RuntimeError("PowerShell is required for the predicate census")
    quoted = ",".join("'" + str(path).replace("'", "''") + "'" for path in sources)
    with tempfile.TemporaryDirectory(prefix="qm_framework_pin_audit_") as tmp:
        harness = Path(tmp) / "predicate.ps1"
        harness.write_text(
            "$ErrorActionPreference = 'Stop'\n"
            "$script:found = New-Object 'System.Collections.Generic.List[string]'\n"
            "function Add-Failure { param([string]$Message) $script:found.Add($Message) }\n"
            f"$mqlFiles = @({quoted})\n"
            + _extract_marker(build_check, "FRAMEWORK_INPUT_PIN_PATTERNS")
            + "\n"
            + _extract_marker(build_check, "FRAMEWORK_INPUT_PIN_SCAN")
            + "\nConvertTo-Json -InputObject @($script:found) -Compress\n",
            encoding="utf-8",
        )
        result = subprocess.run(
            [powershell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(harness)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return list(json.loads(result.stdout or "[]"))


def _phase_number(phase: str) -> int | None:
    match = re.match(r"^Q(\d{2})(?:_|$)", phase or "")
    return int(match.group(1)) if match else None


def _work_history(conn: sqlite3.Connection, ea_ids: list[str]) -> dict[str, list[dict[str, Any]]]:
    placeholders = ",".join("?" for _ in ea_ids)
    rows = conn.execute(
        "SELECT id,ea_id,phase,status,verdict,claimed_by,payload_json,created_at,updated_at "
        f"FROM work_items WHERE ea_id IN ({placeholders})",
        ea_ids,
    )
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[str(row["ea_id"]).removeprefix("QM5_")].append(dict(row))
    return grouped


def _frontier(rows: list[dict[str, Any]]) -> dict[str, Any]:
    q_rows = [(number, row) for row in rows if (number := _phase_number(str(row["phase"]))) is not None]
    verdict_rows = [(number, row) for number, row in q_rows if str(row.get("verdict") or "").strip()]
    highest_any = max((number for number, _ in q_rows), default=None)
    highest_verdict = max((number for number, _ in verdict_rows), default=None)
    q02_plus_verdicts = [row for number, row in verdict_rows if number >= 2]
    return {
        "highest_q_phase_reached": f"Q{highest_any:02d}" if highest_any is not None else None,
        "highest_q_phase_with_verdict": f"Q{highest_verdict:02d}" if highest_verdict is not None else None,
        "q02_plus_verdict_count": len(q02_plus_verdicts),
        "batch_action": "APPEND_ONLY_IDENTITY_RESTART" if q02_plus_verdicts else "PLAIN_REBUILD",
    }


def _authority_dry_run(
    repo_root: Path,
    work_rows: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    import compile_work_items as cwi

    output = []
    for authority, binding in sorted(cwi.FRAMEWORK_INPUT_PIN_SOURCE_REPAIR_REGISTRATIONS.items()):
        ea_id = str(binding["ea_id"])
        eligible = cwi._source_repair_authorized(
            str(binding["ea_label"]),
            authority,
            repo_root=repo_root,
            ea_id=ea_id,
            source_sha=str(binding["source_sha256"]),
            inventory={"work_rows": {ea_id: work_rows.get(ea_id, [])}},
            current_work_item_id=None,
        )
        output.append({
            "ea_id": f"QM5_{ea_id}",
            "ea_label": binding["ea_label"],
            "authority": authority,
            "source_sha256": binding["source_sha256"],
            "predecessor_ids": sorted(binding["predecessors"]),
            "eligible": bool(eligible),
        })
    return output


def build_report(repo_root: Path, build_check: Path, db_path: Path) -> dict[str, Any]:
    sources = sorted((repo_root / "framework" / "EAs").rglob("*.mq5"))
    exact_paths = [
        path for path in sources
        if SEED_NEQ_RE.search(path.read_text(encoding="utf-8", errors="replace"))
    ]
    exact_resolved = {path.resolve() for path in exact_paths}
    hits = _predicate_hits(build_check, sources)
    broad: dict[Path, list[dict[str, Any]]] = defaultdict(list)
    unparsed: list[str] = []
    for hit in hits:
        match = HIT_RE.match(hit)
        if not match:
            unparsed.append(hit)
            continue
        path = Path(match.group("path")).resolve()
        broad[path].append({"line": int(match.group("line")), "detail": match.group("detail")})

    exact_ea_ids = []
    for path in exact_paths:
        match = EA_LABEL_RE.match(path.parent.name)
        if not match:
            raise RuntimeError(f"EA source directory has no numeric identity: {path}")
        exact_ea_ids.append(match.group(1))
    seven_ids = ["41171", "41319", "41358", "41359", "41360", "41361", "41362"]
    with _read_only_connection(db_path) as conn:
        histories = _work_history(conn, [f"QM5_{value}" for value in sorted(set(exact_ea_ids + seven_ids))])

    cohort = []
    for path, ea_id in sorted(zip(exact_paths, exact_ea_ids), key=lambda pair: int(pair[1])):
        cohort.append({
            "ea_id": f"QM5_{ea_id}",
            "ea_label": path.parent.name,
            "source_path": str(path),
            **_frontier(histories.get(ea_id, [])),
        })
    broad_rows = []
    for path, findings in sorted(broad.items(), key=lambda item: str(item[0])):
        broad_rows.append({
            "source_path": str(path),
            "ea_label": path.parent.name,
            "in_exact_seed_neq_cohort": path in exact_resolved,
            "findings": findings,
        })
    dry_run = _authority_dry_run(repo_root, histories)
    plain = sum(row["batch_action"] == "PLAIN_REBUILD" for row in cohort)
    identity = len(cohort) - plain
    return {
        "schema": "qm.framework-input-pin-audit.v1",
        "task_id": TASK_ID,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "read_only": True,
        "database": str(db_path),
        "repo_root": str(repo_root),
        "build_check": str(build_check),
        "source_count": len(sources),
        "acceptance_comparison": {
            "expected_exact_qm_rng_seed_neq_count": 200,
            "actual_exact_qm_rng_seed_neq_count": len(exact_paths),
            "expected_broad_predicate_other_count": 0,
            "actual_broad_predicate_flagged_source_count": len(broad),
            "actual_broad_predicate_other_source_count": len(set(broad) - exact_resolved),
            "expected_200_flagged_0_others_satisfied": len(exact_paths) == 200 and set(broad) == exact_resolved,
            "interpretation": (
                "The exact ticket cohort is reproducibly 200 files, but the broader required predicate "
                "also detects pre-existing pins on other named framework inputs. Those findings are retained."
            ),
        },
        "batch_plan_summary": {
            "plain_rebuild": plain,
            "append_only_identity_restart": identity,
            "rule": "No Q02+ verdict -> PLAIN_REBUILD; any Q02+ verdict -> APPEND_ONLY_IDENTITY_RESTART",
            "source_mutations_authorized_by_this_plan": 0,
        },
        "seven_authority_dry_run": dry_run,
        "seven_authority_all_eligible": all(row["eligible"] for row in dry_run) and len(dry_run) == 7,
        "exact_seed_neq_cohort": cohort,
        "broad_predicate_sweep": broad_rows,
        "unparsed_predicate_output": unparsed,
    }


def render_markdown(report: dict[str, Any]) -> str:
    comparison = report["acceptance_comparison"]
    plan = report["batch_plan_summary"]
    lines = [
        "# Framework-input pin repair review",
        "",
        f"Generated: `{report['generated_at_utc']}`  ",
        f"Router task: `{report['task_id']}`  ",
        "Mode: read-only census and dry run; no compile enqueue, worker reload, or cohort source edit.",
        "",
        "## Review result",
        "",
        f"- Canonical EA sources scanned: **{report['source_count']}**.",
        f"- Exact `qm_rng_seed !=` cohort: **{comparison['actual_exact_qm_rng_seed_neq_count']}** (expected 200).",
        f"- Broad `EA_FRAMEWORK_INPUT_PINNED` sources: **{comparison['actual_broad_predicate_flagged_source_count']}**.",
        f"- Broad-predicate sources outside the exact cohort: **{comparison['actual_broad_predicate_other_source_count']}** (acceptance expected 0).",
        f"- Seven source-repair authorities dry-run eligible: **{report['seven_authority_all_eligible']}**.",
        "",
        "The requested 200/0 sweep invariant is not true of the current canonical corpus. The broad fail-closed predicate correctly exposes additional pre-existing equality/inequality pins on the named framework inputs; the audit does not suppress them.",
        "",
        "## Seven immutable compile authorities",
        "",
        "| EA | Eligible | Predecessor | New source SHA-256 |",
        "|---|---:|---|---|",
    ]
    for row in report["seven_authority_dry_run"]:
        lines.append(f"| {row['ea_id']} | {str(row['eligible']).lower()} | `{row['predecessor_ids'][0]}` | `{row['source_sha256']}` |")
    lines += [
        "",
        "## Vorlage: 200-EA batch repair plan",
        "",
        "Apply the identical framework-input-pin removal hunk only under a separately routed ticket. Preserve EA identity, magic-slot, strategy, risk, and valid stress range guards. Do not alter this cohort in the present ticket.",
        "",
        f"- `PLAIN_REBUILD`: **{plan['plain_rebuild']}** EAs with no Q02+ verdict.",
        f"- `APPEND_ONLY_IDENTITY_RESTART`: **{plan['append_only_identity_restart']}** EAs with one or more Q02+ verdicts.",
        "",
        "| EA | Highest Q reached | Highest Q verdict | Q02+ verdicts | Batch action |",
        "|---|---:|---:|---:|---|",
    ]
    for row in report["exact_seed_neq_cohort"]:
        lines.append(
            f"| {row['ea_label']} | {row['highest_q_phase_reached'] or '-'} | "
            f"{row['highest_q_phase_with_verdict'] or '-'} | {row['q02_plus_verdict_count']} | "
            f"{row['batch_action']} |"
        )
    lines += [
        "",
        "## Broader predicate findings outside the exact cohort",
        "",
        "| EA | Findings |",
        "|---|---|",
    ]
    for row in report["broad_predicate_sweep"]:
        if row["in_exact_seed_neq_cohort"]:
            continue
        findings = "; ".join(f"L{item['line']}: `{item['detail']}`" for item in row["findings"])
        lines.append(f"| {row['ea_label']} | {findings} |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(r"C:\QM\repo"))
    parser.add_argument("--build-check", type=Path, default=Path(__file__).resolve().parents[2] / "framework" / "scripts" / "build_check.ps1")
    parser.add_argument("--db", type=Path, default=Path(r"D:\QM\strategy_farm\state\farm_state.sqlite"))
    parser.add_argument("--json-output", type=Path)
    parser.add_argument("--markdown-output", type=Path)
    parser.add_argument(
        "--check-source", type=Path, action="append", default=[],
        help="Fail-closed pre-build check for one or more generated .mq5 sources",
    )
    args = parser.parse_args()
    if args.check_source:
        sources = [path.resolve() for path in args.check_source]
        invalid = [str(path) for path in sources if not path.is_file() or path.suffix.lower() != ".mq5"]
        if invalid:
            print(json.dumps({"ok": False, "reason": "INVALID_SOURCE", "sources": invalid}, indent=2))
            return 2
        hits = _predicate_hits(args.build_check.resolve(), sources)
        print(json.dumps({
            "ok": not hits,
            "predicate": "EA_FRAMEWORK_INPUT_PINNED",
            "source_count": len(sources),
            "hit_count": len(hits),
            "hits": hits,
        }, indent=2))
        return 0 if not hits else 1
    if args.json_output is None or args.markdown_output is None:
        parser.error("--json-output and --markdown-output are required unless --check-source is used")
    report = build_report(args.repo_root.resolve(), args.build_check.resolve(), args.db.resolve())
    args.json_output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    args.markdown_output.write_text(render_markdown(report), encoding="utf-8")
    print(json.dumps({
        "json_output": str(args.json_output),
        "markdown_output": str(args.markdown_output),
        "source_count": report["source_count"],
        "acceptance_comparison": report["acceptance_comparison"],
        "seven_authority_all_eligible": report["seven_authority_all_eligible"],
        "batch_plan_summary": report["batch_plan_summary"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
