#!/usr/bin/env python3
"""Lint Strategy Card v2 execution contracts against their MQL5 sources.

The contract deliberately separates source mechanics from framework execution
overrides. It is stdlib-only so it can run in the farm controller, prebuild
checks and CI without PyYAML/jsonschema dependencies.
"""
from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY = REPO_ROOT / "framework" / "registry" / "dxz23_execution_contracts.json"

TIMEFRAMES = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"}
FRIDAY_MODES = {"DISABLED", "CARD_RULE", "FRAMEWORK_OVERRIDE"}
QUALIFICATION_STATUSES = {"PASS", "REQUAL_REQUIRED", "BLOCKED"}
PROMOTION_STATUSES = {"ELIGIBLE", "REQUAL_REQUIRED", "BLOCKED"}
MODE_TOKENS = {
    "DISABLED": "QM_FRIDAY_CLOSE_DISABLED",
    "CARD_RULE": "QM_FRIDAY_CLOSE_CARD_RULE",
    "FRAMEWORK_OVERRIDE": "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE",
}

EXECUTION_CALL_RE = re.compile(
    r"QM_FrameworkDeclareExecutionContract\s*\(\s*"
    r"(?P<timeframe>PERIOD_[A-Z0-9]+)\s*,\s*"
    r"(?P<mode>QM_FRIDAY_CLOSE_[A-Z_]+)\s*,\s*"
    r'"(?P<declaration>[^"]*)"\s*\)',
    re.DOTALL,
)

CARD_V2_SECTIONS = (
    "## source-defined rules",
    "## qm interpretations",
    "## framework execution overrides",
    "## exit precedence",
    "## runtime data dependencies",
    "## falsification and requalification",
)


@dataclass(frozen=True)
class Issue:
    severity: str
    code: str
    message: str
    ea_id: int | None = None
    path: str | None = None


def _issue(
    code: str,
    message: str,
    *,
    ea_id: int | None = None,
    path: Path | str | None = None,
    severity: str = "ERROR",
) -> Issue:
    return Issue(
        severity=severity,
        code=code,
        message=message,
        ea_id=ea_id,
        path=str(path) if path is not None else None,
    )


def _flat_frontmatter(text: str) -> dict[str, str]:
    match = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not match:
        return {}
    result: dict[str, str] = {}
    for line in match.group(1).splitlines():
        field = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$", line)
        if field:
            result[field.group(1)] = field.group(2).strip().strip('"').strip("'")
    return result


def lint_card_v2(card: Path, contract: dict[str, Any] | None = None) -> list[Issue]:
    if not card.exists():
        return [_issue("card_missing", "Strategy Card does not exist", path=card)]
    text = card.read_text(encoding="utf-8-sig", errors="replace")
    fm = _flat_frontmatter(text)
    issues: list[Issue] = []
    if fm.get("card_schema_version") != "2":
        issues.append(_issue("card_v2_version_missing", "card_schema_version must be 2", path=card))
    if not fm.get("execution_contract_ref"):
        issues.append(_issue("card_v2_contract_ref_missing", "execution_contract_ref is required", path=card))
    if not fm.get("execution_contract_status"):
        issues.append(_issue("card_v2_contract_status_missing", "execution_contract_status is required", path=card))

    lower = text.lower()
    for heading in CARD_V2_SECTIONS:
        if heading not in lower:
            issues.append(
                _issue(
                    "card_v2_section_missing",
                    f"required Card-v2 section missing: {heading}",
                    path=card,
                )
            )

    if contract is not None:
        ea_id = int(contract["ea_id"])
        if str(ea_id) not in fm.get("execution_contract_ref", ""):
            issues.append(
                _issue(
                    "card_v2_contract_ref_mismatch",
                    f"execution_contract_ref does not bind ea_id {ea_id}",
                    ea_id=ea_id,
                    path=card,
                )
            )
    return issues


def _require_keys(obj: dict[str, Any], keys: Iterable[str], ea_id: int | None) -> list[Issue]:
    return [
        _issue("contract_field_missing", f"required field missing: {key}", ea_id=ea_id)
        for key in keys
        if key not in obj
    ]


def lint_contract(
    contract: dict[str, Any],
    *,
    repo_root: Path = REPO_ROOT,
    as_of: date | None = None,
) -> list[Issue]:
    issues: list[Issue] = []
    ea_id_raw = contract.get("ea_id")
    ea_id = ea_id_raw if isinstance(ea_id_raw, int) else None
    issues.extend(
        _require_keys(
            contract,
            (
                "ea_id",
                "slug",
                "card_ref",
                "source",
                "strategy_timeframe",
                "bar_gate_timeframe",
                "friday_close",
                "calendar",
                "promotion",
            ),
            ea_id,
        )
    )
    if issues:
        return issues

    strategy_tf = str(contract["strategy_timeframe"])
    gate_tf = str(contract["bar_gate_timeframe"])
    if strategy_tf not in TIMEFRAMES:
        issues.append(_issue("timeframe_invalid", f"invalid strategy_timeframe: {strategy_tf}", ea_id=ea_id))
    if gate_tf not in TIMEFRAMES:
        issues.append(_issue("timeframe_invalid", f"invalid bar_gate_timeframe: {gate_tf}", ea_id=ea_id))
    if strategy_tf != gate_tf:
        issues.append(
            _issue(
                "timeframe_gate_mismatch",
                f"strategy timeframe {strategy_tf} != bar gate {gate_tf}",
                ea_id=ea_id,
            )
        )

    friday = contract["friday_close"]
    if not isinstance(friday, dict):
        issues.append(_issue("friday_contract_invalid", "friday_close must be an object", ea_id=ea_id))
        return issues
    issues.extend(
        _require_keys(
            friday,
            ("enabled", "hour_broker", "mode", "declaration", "qualification_status"),
            ea_id,
        )
    )
    if issues:
        return issues

    mode = str(friday["mode"])
    qualification = str(friday["qualification_status"])
    enabled = friday["enabled"]
    hour = friday["hour_broker"]
    declaration = str(friday["declaration"])
    if mode not in FRIDAY_MODES:
        issues.append(_issue("friday_mode_invalid", f"invalid Friday mode: {mode}", ea_id=ea_id))
    if qualification not in QUALIFICATION_STATUSES:
        issues.append(_issue("friday_qualification_invalid", f"invalid status: {qualification}", ea_id=ea_id))
    if mode == "DISABLED" and (enabled is not False or hour is not None):
        issues.append(_issue("friday_disabled_mismatch", "DISABLED requires enabled=false and hour=null", ea_id=ea_id))
    if mode != "DISABLED" and (enabled is not True or not isinstance(hour, int) or not 0 <= hour <= 23):
        issues.append(_issue("friday_enabled_mismatch", "enabled Friday modes require a broker hour 0..23", ea_id=ea_id))
    if mode == "FRAMEWORK_OVERRIDE" and not declaration:
        issues.append(_issue("friday_override_reason_missing", "framework override requires a declaration", ea_id=ea_id))
    if mode == "CARD_RULE" and not friday.get("card_evidence"):
        issues.append(_issue("friday_card_evidence_missing", "CARD_RULE requires card evidence", ea_id=ea_id))

    promotion = contract["promotion"]
    if not isinstance(promotion, dict):
        issues.append(_issue("promotion_invalid", "promotion must be an object", ea_id=ea_id))
        return issues
    promotion_status = str(promotion.get("status", ""))
    reasons = promotion.get("block_reasons")
    if promotion_status not in PROMOTION_STATUSES:
        issues.append(_issue("promotion_status_invalid", f"invalid promotion status: {promotion_status}", ea_id=ea_id))
    if not isinstance(reasons, list):
        issues.append(_issue("promotion_reasons_invalid", "block_reasons must be a list", ea_id=ea_id))
    elif promotion_status != "ELIGIBLE" and not reasons:
        issues.append(_issue("promotion_reason_missing", "non-eligible contract requires block reasons", ea_id=ea_id))
    if mode == "FRAMEWORK_OVERRIDE" and qualification != "PASS" and promotion_status == "ELIGIBLE":
        issues.append(
            _issue(
                "unqualified_override_promotable",
                "an unqualified framework override cannot be promotion-eligible",
                ea_id=ea_id,
            )
        )
    if contract["card_ref"] == "MISSING_CANONICAL_APPROVED_CARD" and promotion_status != "BLOCKED":
        issues.append(_issue("missing_card_not_blocked", "missing canonical Card must block promotion", ea_id=ea_id))

    source = repo_root / Path(str(contract["source"]))
    if not source.exists():
        issues.append(_issue("ea_source_missing", "EA source does not exist", ea_id=ea_id, path=source))
        return issues
    text = source.read_text(encoding="utf-8-sig", errors="replace")
    expected_stem = f"QM5_{ea_id}_{contract['slug']}"
    if source.stem != expected_stem:
        issues.append(
            _issue(
                "ea_source_identity_mismatch",
                f"source stem {source.stem!r} != {expected_stem!r}",
                ea_id=ea_id,
                path=source,
            )
        )

    calls = list(EXECUTION_CALL_RE.finditer(text))
    if len(calls) != 1:
        issues.append(
            _issue(
                "execution_contract_call_count",
                f"expected exactly one runtime declaration, found {len(calls)}",
                ea_id=ea_id,
                path=source,
            )
        )
    else:
        call = calls[0].groupdict()
        expected_tf_token = f"PERIOD_{strategy_tf}"
        if call["timeframe"] != expected_tf_token:
            issues.append(
                _issue(
                    "runtime_timeframe_mismatch",
                    f"runtime {call['timeframe']} != contract {expected_tf_token}",
                    ea_id=ea_id,
                    path=source,
                )
            )
        expected_mode = MODE_TOKENS.get(mode)
        if expected_mode and call["mode"] != expected_mode:
            issues.append(
                _issue(
                    "runtime_friday_mode_mismatch",
                    f"runtime {call['mode']} != contract {expected_mode}",
                    ea_id=ea_id,
                    path=source,
                )
            )
        if call["declaration"] != declaration:
            issues.append(
                _issue(
                    "runtime_declaration_mismatch",
                    "runtime Friday declaration differs from registry",
                    ea_id=ea_id,
                    path=source,
                )
            )

    gate_pattern = re.compile(
        rf"QM_IsNewBar\s*\(\s*_Symbol\s*,\s*PERIOD_{re.escape(gate_tf)}\s*\)"
    )
    if not gate_pattern.search(text):
        issues.append(
            _issue(
                "runtime_bar_gate_missing",
                f"explicit PERIOD_{gate_tf} bar gate is missing",
                ea_id=ea_id,
                path=source,
            )
        )

    friday_input = re.search(r"qm_friday_close_enabled\s*=\s*(true|false)", text)
    if not friday_input:
        issues.append(_issue("runtime_friday_input_missing", "Friday input default not found", ea_id=ea_id, path=source))
    elif (friday_input.group(1) == "true") != bool(enabled):
        issues.append(_issue("runtime_friday_enabled_mismatch", "Friday input default differs from contract", ea_id=ea_id, path=source))

    calendar = contract["calendar"]
    if not isinstance(calendar, dict) or calendar.get("policy") not in {"NONE", "FIXED_EVENT_TABLE"}:
        issues.append(_issue("calendar_policy_invalid", "invalid calendar policy", ea_id=ea_id))
    elif calendar.get("policy") == "FIXED_EVENT_TABLE":
        valid_raw = str(calendar.get("valid_through", ""))
        try:
            valid_through = date.fromisoformat(valid_raw)
        except ValueError:
            issues.append(_issue("calendar_valid_through_invalid", f"invalid date: {valid_raw}", ea_id=ea_id))
        else:
            if as_of is not None and as_of > valid_through:
                issues.append(
                    _issue(
                        "calendar_expired",
                        f"calendar expired {valid_through.isoformat()} before {as_of.isoformat()}",
                        ea_id=ea_id,
                        path=source,
                    )
                )
            key = valid_through.strftime("%Y%m%d")
            if not re.search(rf"g_event_calendar_valid_through_key\s*=\s*{key}\b", text):
                issues.append(_issue("runtime_calendar_horizon_mismatch", "MQL calendar horizon differs from registry", ea_id=ea_id, path=source))
            if "SETUP_DATA_STALE" not in text or "Strategy_CalendarCoverageAllows" not in text:
                issues.append(_issue("runtime_calendar_fail_closed_missing", "calendar lacks fail-closed stale guard", ea_id=ea_id, path=source))

    return issues


def lint_registry(
    registry: Path = DEFAULT_REGISTRY,
    *,
    repo_root: Path = REPO_ROOT,
    as_of: date | None = None,
    ea_ids: set[int] | None = None,
) -> tuple[dict[str, Any], list[dict[str, Any]], list[Issue]]:
    payload = json.loads(registry.read_text(encoding="utf-8"))
    issues: list[Issue] = []
    if payload.get("schema_version") != 2:
        issues.append(_issue("registry_schema_version", "schema_version must be 2", path=registry))
    contracts = payload.get("contracts")
    if not isinstance(contracts, list):
        return payload, [], issues + [_issue("contracts_invalid", "contracts must be a list", path=registry)]

    selected = [
        item for item in contracts
        if isinstance(item, dict) and (ea_ids is None or item.get("ea_id") in ea_ids)
    ]
    seen: set[int] = set()
    for contract in selected:
        ea_id = contract.get("ea_id")
        if isinstance(ea_id, int) and ea_id in seen:
            issues.append(_issue("duplicate_ea_id", "duplicate execution contract", ea_id=ea_id, path=registry))
        if isinstance(ea_id, int):
            seen.add(ea_id)
        issues.extend(lint_contract(contract, repo_root=repo_root, as_of=as_of))
    if ea_ids is not None:
        missing = ea_ids - seen
        for ea_id in sorted(missing):
            issues.append(_issue("contract_missing", "requested EA has no execution contract", ea_id=ea_id, path=registry))
    return payload, selected, issues


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contracts", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--as-of", default=date.today().isoformat())
    parser.add_argument("--ea-id", action="append", type=int)
    parser.add_argument("--require-promotable", action="store_true")
    parser.add_argument("--card", type=Path, help="Optionally lint one Card-v2 Markdown file")
    args = parser.parse_args(argv)

    as_of = date.fromisoformat(args.as_of)
    requested = set(args.ea_id) if args.ea_id else None
    payload, selected, issues = lint_registry(
        args.contracts,
        repo_root=args.repo_root,
        as_of=as_of,
        ea_ids=requested,
    )
    if args.card:
        contract = selected[0] if len(selected) == 1 else None
        issues.extend(lint_card_v2(args.card, contract))

    errors = [item for item in issues if item.severity == "ERROR"]
    blocked = [
        {
            "ea_id": item["ea_id"],
            "status": item["promotion"]["status"],
            "reasons": item["promotion"]["block_reasons"],
        }
        for item in selected
        if item.get("promotion", {}).get("status") != "ELIGIBLE"
    ]
    status = "error" if errors else "ok"
    exit_code = 2 if errors else 0
    if not errors and args.require_promotable and blocked:
        status = "blocked"
        exit_code = 3

    print(
        json.dumps(
            {
                "status": status,
                "schema_version": payload.get("schema_version"),
                "book_id": payload.get("book_id"),
                "contracts_checked": len(selected),
                "issues": [asdict(item) for item in issues],
                "promotion_blocks": blocked,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
