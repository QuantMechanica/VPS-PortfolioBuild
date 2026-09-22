"""Read-only Sunday FTMO Demo Go/No-Go preflight.

The preflight consumes a Genesis Manifest plus explicit evidence declarations.
It never installs, launches, attaches, edits a terminal, or toggles AutoTrading.
Automatic checks are recomputed from hash-bound artifacts.  Checks that need
human/runtime evidence remain NOT_CHECKABLE (or RED when a required declared
artifact is absent); they are never silently inferred as GREEN.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Callable

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from tools.strategy_farm.ftmo.genesis_manifest import (  # noqa: E402
    ManifestError,
    _load_json,
    verify_manifest,
)


SCHEMA = "qm.ftmo-sunday-preflight/v1"
VALID_STATES = {"GREEN", "RED", "NOT_CHECKABLE"}

CHECKS: tuple[tuple[str, str, str, bool], ...] = (
    ("CODE_ARTIFACT", "compile_clean", "All included EAs compile with 0 errors / 0 warnings", True),
    ("CODE_ARTIFACT", "exact_ex5_binding", "Exact installed EX5 binding", True),
    ("CODE_ARTIFACT", "exact_setfile_binding", "Exact installed setfile binding", True),
    ("CODE_ARTIFACT", "magic_registry_clean", "Magic registry clean", True),
    ("CODE_ARTIFACT", "no_artifact_drift", "No unknown artifact drift", True),
    (
        "CODE_ARTIFACT",
        "sleeve_attribution_dry_run",
        "Sleeve attribution pre-launch dry-run reconciles to 0.00",
        False,
    ),
    (
        "CODE_EXECUTION",
        "live_news_feed_binding",
        "All sleeve presets bind the fresh live calendar, never a backtest CSV",
        True,
    ),
    ("ACCOUNT_RISK", "account_governor_present", "Account governor present and hash-bound", True),
    ("ACCOUNT_RISK", "daily_loss_anchor", "Daily Loss anchor mode correct", True),
    ("ACCOUNT_RISK", "prague_rollover", "Prague rollover helper and configuration present", True),
    ("ACCOUNT_RISK", "maximum_loss", "Maximum Loss logic present", True),
    ("ACCOUNT_RISK", "combined_open_risk", "Combined open-risk calculation present", True),
    ("ACCOUNT_RISK", "kill_switch_test", "Kill-Switch test evidence", True),
    ("ACCOUNT_RISK", "book_generation_identity", "Book-generation identity", True),
    (
        "ACCOUNT_RISK",
        "weekend_non_tick_rollover",
        "KS_DAY_ROLLOVER observed after a no-tick boundary",
        True,
    ),
    (
        "ACCOUNT_RISK",
        "clean_initial_account",
        "Balance 100000.00 with zero positions and orders immediately before attach",
        True,
    ),
    ("EXECUTION", "cost_assumptions", "Spread and commission assumptions realistic", True),
    ("EXECUTION", "fill_fidelity", "No known unrealistic fill dependency", True),
    ("EXECUTION", "oco", "OCO verified where relevant", True),
    ("EXECUTION", "session_calendars", "Session calendars valid", True),
    ("EXECUTION", "dst", "DST handling valid", True),
    ("EXECUTION", "news", "News handling valid", True),
    ("PORTFOLIO", "dependence_matrix", "Dependence matrix current", True),
    ("PORTFOLIO", "intentional_weights", "Sleeve weights intentional", True),
    ("PORTFOLIO", "duplicate_exposure", "No accidental duplicate exposure", True),
    ("PORTFOLIO", "xau_cluster", "XAU cluster documented", True),
    ("PORTFOLIO", "first_passage", "First-passage simulation current", True),
    ("OPERATIONS", "sleeve_attribution", "Sleeve P&L attribution working", True),
    ("OPERATIONS", "logs", "Logs working", True),
    ("OPERATIONS", "recovery", "Recovery procedure documented", True),
    (
        "OPERATIONS",
        "terminal_autotrading_flag",
        "Terminal and every attached sleeve chart allow automated trading",
        True,
    ),
    (
        "OPERATIONS",
        "server_request_thresholds",
        "Request WARN 200 / LIMIT 500 with a 60-second burst alarm",
        False,
    ),
    ("OPERATIONS", "demo_account_clean", "Demo account clean before attach", True),
    ("OPERATIONS", "post_attach", "Post-attach verification complete", True),
)


def _row(
    area: str,
    check_id: str,
    label: str,
    critical: bool,
    state: str,
    evidence: str | None,
    reason: str,
    *,
    automatic: bool,
) -> dict[str, Any]:
    if state not in VALID_STATES:
        raise ManifestError(f"preflight_state_invalid:{check_id}:{state}")
    return {
        "area": area,
        "check_id": check_id,
        "check": label,
        "critical": critical,
        "state": state,
        "evidence_path": evidence,
        "reason": reason,
        "automatic": automatic,
    }


def _verify_item_states(verification: dict[str, Any], predicate: Callable[[str], bool]) -> list[str]:
    return [row["state"] for row in verification["items"] if predicate(str(row["item"]))]


def _automatic_rows(manifest: dict[str, Any], verification: dict[str, Any]) -> dict[str, tuple[str, str | None, str]]:
    receipt_path = Path(manifest["build_evidence"]["resolved_path"])
    receipt = receipt_path.read_text(encoding="utf-8", errors="replace") if receipt_path.is_file() else ""
    compile_ok = bool(re.search(r"\b0\s+errors\s*/\s*0\s+warnings\b", receipt, flags=re.I))
    ex5 = _verify_item_states(verification, lambda name: "installed_ex5" in name)
    sets = _verify_item_states(verification, lambda name: name.endswith(".setfile"))
    registry = _verify_item_states(verification, lambda name: name == "registry_semantics")
    governor = _verify_item_states(verification, lambda name: name.startswith("governor."))
    kill = manifest.get("kill_switch") or {}
    daily = manifest.get("daily_loss_controls") or {}
    repo_source = Path(manifest["account_governor"]["source"]["resolved_path"]).parents[2]
    rollover_helper = repo_source / "include/QM/QM_FTMOGovernorPolicy.mqh"
    combined = repo_source / "include/QM/QM_AccountRiskReservation.mqh"
    governor_source = Path(manifest["account_governor"]["source"]["resolved_path"])
    governor_text = governor_source.read_text(encoding="utf-8", errors="replace") if governor_source.is_file() else ""
    helper_text = rollover_helper.read_text(encoding="utf-8", errors="replace") if rollover_helper.is_file() else ""
    combined_text = combined.read_text(encoding="utf-8", errors="replace") if combined.is_file() else ""
    anchor_ok = daily.get("configuration_status") == "CONFIGURED" and bool(daily.get("anchor_mode"))
    tag_ok = kill.get("configuration_status") == "CONFIGURED" and bool(kill.get("book_tag"))
    return {
        "compile_clean": (
            "GREEN" if compile_ok else "RED",
            str(receipt_path),
            "compile receipt states 0 errors / 0 warnings" if compile_ok else "bound receipt lacks a 0 errors / 0 warnings assertion",
        ),
        "exact_ex5_binding": (
            "GREEN" if ex5 and all(x == "MATCH" for x in ex5) else "RED",
            None,
            f"{sum(x == 'MATCH' for x in ex5)}/{len(ex5)} installed EX5 hashes match",
        ),
        "exact_setfile_binding": (
            "GREEN" if sets and all(x == "MATCH" for x in sets) else "RED",
            None,
            f"{sum(x == 'MATCH' for x in sets)}/{len(sets)} setfile hashes match",
        ),
        "magic_registry_clean": (
            "GREEN" if registry == ["MATCH"] else "RED",
            manifest["registries"]["magic"]["resolved_path"],
            "selected rows are active and formula-consistent" if registry == ["MATCH"] else "registry semantic mismatch",
        ),
        "no_artifact_drift": (
            "GREEN" if verification["status"] == "PASS" else "RED",
            None,
            f"Genesis verification status {verification['status']} ({verification['drift_count']} drift rows)",
        ),
        "account_governor_present": (
            "GREEN" if governor and all(x == "MATCH" for x in governor) else "RED",
            manifest["account_governor"]["source"]["resolved_path"],
            "governor source, installed EX5 and preset are hash-bound" if governor and all(x == "MATCH" for x in governor) else "governor binding missing or drifted",
        ),
        "daily_loss_anchor": (
            "GREEN" if anchor_ok else "RED",
            None,
            f"configuration_status={daily.get('configuration_status')}; anchor_mode={daily.get('anchor_mode')}",
        ),
        "prague_rollover": (
            "GREEN" if anchor_ok and "QM_FTMO_PragueDayKey" in helper_text else "RED",
            str(rollover_helper),
            "dynamic Prague helper and named anchor configuration present" if anchor_ok and "QM_FTMO_PragueDayKey" in helper_text else "helper or governed anchor configuration missing",
        ),
        "maximum_loss": (
            "GREEN" if "QM_FTMOGovernorPolicy.mqh" in governor_text and "official_total_floor" in helper_text else "RED",
            str(rollover_helper),
            "governor binds the signed policy's static official_total_floor" if "QM_FTMOGovernorPolicy.mqh" in governor_text and "official_total_floor" in helper_text else "Maximum Loss enforcement not located",
        ),
        "combined_open_risk": (
            "GREEN" if "QM_AccountRiskRequestLoss" in combined_text else "RED",
            str(combined),
            "account risk reservation calculates request loss" if "QM_AccountRiskRequestLoss" in combined_text else "combined open-risk implementation missing",
        ),
        "book_generation_identity": (
            "GREEN" if tag_ok and bool(manifest.get("generation_id")) else "RED",
            None,
            f"generation_id={manifest.get('generation_id')}; book_tag={kill.get('book_tag')}",
        ),
        "intentional_weights": (
            "GREEN" if abs(sum(float(s["weight"]) for s in manifest["roster"]["sleeves"]) - 1.0) <= 1e-8 else "RED",
            manifest["roster"]["binding"]["resolved_path"],
            "risk-normalized sleeve weights sum to one",
        ),
    }


def _declared_result(check_id: str, declaration: dict[str, Any] | None) -> tuple[str, str | None, str]:
    if not declaration:
        return "NOT_CHECKABLE", None, "no explicit evidence declaration supplied"
    state = str(declaration.get("state", "NOT_CHECKABLE")).upper()
    if state not in VALID_STATES:
        raise ManifestError(f"preflight_state_invalid:{check_id}:{state}")
    evidence = declaration.get("evidence_path")
    reason = str(declaration.get("reason") or "explicit evidence declaration")
    if state == "GREEN":
        if not evidence:
            return "RED", None, "GREEN declaration refused: evidence_path missing"
        path = Path(evidence)
        if not path.exists():
            return "RED", str(path), "GREEN declaration refused: evidence artifact missing"
        expected = declaration.get("contains")
        if expected:
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                return "RED", str(path), "GREEN declaration refused: evidence unreadable"
            if str(expected) not in text:
                return "RED", str(path), f"GREEN declaration refused: required marker absent: {expected}"
    return state, str(evidence) if evidence else None, reason


def run_preflight(
    manifest_path: Path,
    *,
    evidence_config: Path | None = None,
) -> dict[str, Any]:
    manifest_path = manifest_path.resolve()
    manifest = _load_json(manifest_path)
    verification = verify_manifest(manifest_path)
    declared: dict[str, Any] = {}
    if evidence_config:
        config = _load_json(evidence_config.resolve())
        declared = config.get("checks") or {}
        if not isinstance(declared, dict):
            raise ManifestError("preflight_checks_object_required")
    automatic = _automatic_rows(manifest, verification)
    rows: list[dict[str, Any]] = []
    for area, check_id, label, critical in CHECKS:
        if check_id in automatic:
            state, evidence, reason = automatic[check_id]
            is_auto = True
        else:
            state, evidence, reason = _declared_result(check_id, declared.get(check_id))
            is_auto = False
        rows.append(_row(area, check_id, label, critical, state, evidence, reason, automatic=is_auto))
    critical_red = [row["check_id"] for row in rows if row["critical"] and row["state"] == "RED"]
    critical_pending = [
        row["check_id"] for row in rows if row["critical"] and row["state"] == "NOT_CHECKABLE"
    ]
    decision = "NO_GO" if critical_red else ("PENDING" if critical_pending else "GO")
    return {
        "schema": SCHEMA,
        "generation_id": manifest.get("generation_id"),
        "manifest_path": str(manifest_path),
        "manifest_sha256": manifest.get("manifest_sha256"),
        "scope": manifest.get("inventory_scope"),
        "decision": decision,
        "critical_red": critical_red,
        "critical_not_checkable": critical_pending,
        "counts": {state: sum(row["state"] == state for row in rows) for state in sorted(VALID_STATES)},
        "checks": rows,
    }


def write_report(report: dict[str, Any], json_path: Path, markdown_path: Path | None = None) -> None:
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    md = markdown_path or json_path.with_suffix(".md")
    lines = [
        f"# Sunday preflight — {report['generation_id']}",
        "",
        f"Decision: **{report['decision']}**. Scope: `{report['scope']}`.",
        "",
        "| Area | Check | State | Evidence / reason |",
        "|---|---|---|---|",
    ]
    for row in report["checks"]:
        detail = row["evidence_path"] or row["reason"]
        lines.append(f"| {row['area']} | {row['check']} | **{row['state']}** | `{detail}` |")
    lines += [
        "",
        "A critical RED is NO-GO. A critical NOT_CHECKABLE is PENDING and cannot be treated as launch approval. This report is read-only and never launches or configures MT5.",
        "",
    ]
    md.write_text("\n".join(lines), encoding="utf-8")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--evidence-config", type=Path)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-md", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        report = run_preflight(args.manifest, evidence_config=args.evidence_config)
        write_report(report, args.output_json, args.output_md)
        print(json.dumps({"decision": report["decision"], "counts": report["counts"]}))
        return 0 if report["decision"] == "GO" else 2
    except ManifestError as exc:
        print(json.dumps({"decision": "REFUSED", "reason": str(exc)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
