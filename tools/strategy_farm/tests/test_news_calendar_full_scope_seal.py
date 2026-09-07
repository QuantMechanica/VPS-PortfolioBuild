from __future__ import annotations

import hashlib
import json
from pathlib import Path

from tools.strategy_farm import news_calendar_full_scope_seal as seal
from tools.strategy_farm import news_calendar_gate as gate
from tools.strategy_farm import news_calendar_repair as repair


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_candidate(path: Path) -> None:
    path.mkdir()
    primary = path / gate.PRIMARY_NAME
    secondary = path / gate.SECONDARY_NAME
    repair.write_csv(primary, [{
        **dict.fromkeys(repair.PRIMARY_FIELDS, ""),
        "datetime": "2026-01-01 12:00:00", "currency": "USD",
        "event_name": "Fixture HIGH", "impact": "high", "impact_numeric": "3",
        "is_high_impact": "1", "day_of_week": "3", "hour": "12", "day": "1",
    }], repair.PRIMARY_FIELDS)
    repair.write_csv(secondary, [{
        **dict.fromkeys(repair.SECONDARY_FIELDS, ""),
        "Date": "2026.01.01", "DateTime_UTC": "2026.01.01 12:00:00",
        "DateTime_EET": "2026.01.01 14:00:00", "Currency": "USD",
        "Impact": "High", "Event": "Fixture HIGH",
    }], repair.SECONDARY_FIELDS)
    footprints = [{
        "id": "a", "status": "MISSING_M5", "currency": "AUD",
        "event_code": "fixture", "utc": "2025-01-01T00:00:00Z",
    }]
    (path / "footprint_summary.json").write_text(json.dumps(footprints), encoding="utf-8")
    (path / "nonusd_offset_decisions.json").write_text("[]", encoding="utf-8")
    gates = {
        name: {
            "pass": name not in {"6.1_anchor_shares", "6.5_tick_footprints"},
            "scope_status": (
                "COVERED_BY_DECLARATION"
                if name in {"6.1_anchor_shares", "6.5_tick_footprints"}
                else "MEASURED_PASS"
            ),
        }
        for name in seal.ingress.GATES
    }
    gates["6.1_anchor_shares"]["failed_groups"] = [
        {"class": "Fixture HIGH", "source": "primary", "year": 2026, "total": 1}
    ]
    gates["6.2_coverage"].update(
        fresh_exports={"AUD": {"present": True, "rows": 1}},
        fresh_currencies_with_confirmed_official_anchor=[],
    )
    gates["6.5_tick_footprints"].update(checks=1, status_counts={"MISSING_M5": 1})
    verification = {
        "schema": repair.SCHEMA, "decision_id": repair.DECISION,
        "status": "FAIL", "publishable": False, "exit_code": 2, "gates": gates,
    }
    verification_path = path / "verification.json"
    verification_path.write_text(json.dumps(verification), encoding="utf-8")
    files = []
    for calendar_path in (primary, secondary):
        parsed = gate._parse_calendar_file(calendar_path, calendar_path.name)
        files.append({"name": calendar_path.name, "sha256": parsed.sha256, "row_count": parsed.row_count})
    declarations = [{"id": "fixture"}]
    declarations_path = path / "declared_inadmissible_ranges.json"
    declarations_path.write_text(json.dumps(declarations), encoding="utf-8")
    manifest = {
        "schema": repair.SCHEMA, "decision_id": repair.DECISION,
        "publishable": False, "production_write": False, "files": files,
        "input_files": [], "verification_sha256": _sha(verification_path),
        "declared_inadmissible_ranges": declarations,
        "declared_inadmissible_ranges_sha256": _sha(declarations_path),
        "scoped_review_only": True,
    }
    (path / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (path.parent / "anchor_taxonomy.json").write_text(json.dumps({
        "classes": [{
            "disposition": "DECLARED_EVENT_BY_EVENT_UNANCHORED",
            "event_class": "Fixture HIGH", "failed_or_unverified_high_rows": 1,
            "failed_groups": 1,
        }]
    }), encoding="utf-8")


def test_failed_or_scoped_candidate_cannot_prepare_multi_plan(tmp_path: Path) -> None:
    candidate = tmp_path / "candidate"
    _write_candidate(candidate)
    report = seal.analyze_candidate(candidate, verify_repin_chain=False)

    assert report["status"] == "NOT_READY_FAIL_CLOSED"
    assert report["failed_measured_gates"] == ["6.1_anchor_shares", "6.5_tick_footprints"]
    assert report["multi_plan"]["status"] == "WITHHELD_FAILED_FULL_SCOPE_ADMISSION"
    assert report["multi_plan"]["input_integrity_pass"] is True
    assert report["repin_record"] == {
        "status": "WITHHELD_NO_CEO_RELEASE", "record_called": False, "production_write": False,
    }
    assert report["gate_progress"][0]["residual"]["failed_group_rows"] == 1
    footprint_gate = next(row for row in report["gate_progress"] if row["gate"] == "6.5_tick_footprints")
    assert footprint_gate["residual"]["status_counts"] == {"MISSING_M5": 1}
    criteria = report["b_prime_criteria"]
    validated = gate.validate_b_prime_criteria_seal(criteria)
    assert validated["status"] == "VALIDATED"
    assert validated["residual_summaries"] == {
        "EVENT_BY_EVENT_HIGH_WITHOUT_OFFICIAL_SCHEDULE": {"entries": 1, "count": 1},
        "TICK_FOOTPRINT_BEYOND_FACTORY_HISTORY": {"entries": 1, "count": 1},
        "NON_USD_WITHOUT_CONFIRMED_FRESH_ANCHOR": {"entries": 1, "count": 1},
    }


def test_b_prime_criteria_tamper_and_unclassified_residual_refuse(tmp_path: Path) -> None:
    candidate = tmp_path / "candidate"
    _write_candidate(candidate)
    criteria = seal.analyze_candidate(candidate, verify_repin_chain=False)["b_prime_criteria"]
    criteria["residuals"]["EVENT_BY_EVENT_HIGH_WITHOUT_OFFICIAL_SCHEDULE"]["count"] = 2
    try:
        gate.validate_b_prime_criteria_seal(criteria)
    except gate.NewsCalendarError as exc:
        assert "content hash mismatch" in str(exc)
    else:
        raise AssertionError("tampered B-prime criteria seal was accepted")


def test_gate_set_and_boolean_values_are_exact() -> None:
    footprints = []
    checks = {name: {"pass": True} for name in seal.ingress.GATES}
    checks.pop("6.8_schema")
    try:
        seal._gate_progress(checks, footprints)
    except ValueError as exc:
        assert "exactly the eight" in str(exc)
    else:
        raise AssertionError("missing gate was accepted")

    checks["6.8_schema"] = {"pass": 1}
    try:
        seal._gate_progress(checks, footprints)
    except ValueError as exc:
        assert "exact boolean" in str(exc)
    else:
        raise AssertionError("integer gate verdict was accepted")


def test_production_b_prime_contract_has_exact_owner_approved_inventory() -> None:
    path = Path("docs/ops/evidence/2026-09-07_calendar_b_prime_full_scope_contract.json")
    report = json.loads(path.read_text(encoding="utf-8"))
    criteria = report["b_prime_criteria"]
    result = gate.validate_b_prime_criteria_seal(criteria)
    assert result["residual_summaries"] == {
        "EVENT_BY_EVENT_HIGH_WITHOUT_OFFICIAL_SCHEDULE": {"entries": 40, "count": 1865},
        "TICK_FOOTPRINT_BEYOND_FACTORY_HISTORY": {"entries": 19, "count": 19},
        "NON_USD_WITHOUT_CONFIRMED_FRESH_ANCHOR": {"entries": 5, "count": 152},
    }
    assert criteria["unclassified_residuals"] == []
