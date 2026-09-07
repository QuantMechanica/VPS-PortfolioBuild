from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import news_calendar_scoped_activation as scoped


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _json(path: Path, value) -> Path:
    path.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")
    return path


def _fixture(tmp_path: Path, *, overlap: bool = False):
    candidate = tmp_path / "candidate"
    candidate.mkdir()
    primary = candidate / "news_calendar_2015_2025.csv"
    secondary = candidate / "forex_factory_calendar_clean.csv"
    primary.write_text(
        "datetime,currency,event_name,impact\n2024-01-15 13:30:00,USD,NFP,HIGH\n",
        encoding="utf-8",
    )
    secondary.write_text(
        "DateTime_UTC,Currency,Event,Impact\n2024.01.15 13:30:00,USD,NFP,High\n",
        encoding="utf-8",
    )
    declarations = [{
        "id": "decl-1", "currency": "USD",
        "event_class": "NFP" if overlap else "CPI",
        "months": ["2024-01"], "usage": "INADMISSIBLE",
    }]
    declaration_path = _json(candidate / "declared_inadmissible_ranges.json", declarations)
    manifest = {
        "schema": "qm.news-calendar-repair-e1a/v1",
        "publishable": False,
        "scoped_review_only": True,
        "declared_inadmissible_ranges": declarations,
        "declared_inadmissible_ranges_sha256": _sha(declaration_path),
        "files": [
            {"name": primary.name, "sha256": _sha(primary)},
            {"name": secondary.name, "sha256": _sha(secondary)},
        ],
    }
    manifest_path = _json(candidate / "manifest.json", manifest)
    config = {
        "schema": scoped.SCHEMA,
        "enabled": True,
        "decision": {"id": "OWNER-DEC-FIXTURE", "receipt_id": "receipt-1", "evidence": "e.md"},
        "candidate": {
            "manifest_path": str(manifest_path), "manifest_sha256": _sha(manifest_path),
            "declarations_path": str(declaration_path),
            "declarations_sha256": _sha(declaration_path),
            "calendar_files": {primary.name: _sha(primary), secondary.name: _sha(secondary)},
        },
        "admissibility": {
            "phase": "Q10_NEWS", "timeframes": ["D1"], "impact": "HIGH",
            "permitted_currencies": ["USD"],
            "symbol_currency_overrides": {"NDX.DWX": ["USD"], "GDAXI.DWX": ["EUR"]},
            "declaration_wildcards_for_high": ["ALL", "ALL_HIGH"],
            "require_sealed_q10_window": True, "release_mode": "OWNER_ROW_BY_ROW",
        },
        "counter_marker": {
            "schema": scoped.MARKER_SCHEMA, "payload_key": scoped.MARKER_KEY,
            "footnote": scoped.FOOTNOTE,
        },
        "readjudication": {
            "ticket_id": "FUTURE-TICKET", "trigger": "B-prime or full seal",
            "mode": "APPEND_ONLY_RERUN", "overwrite_existing_verdicts": False,
            "full_scope_seal_sha256": "f" * 64,
        },
    }
    config_path = _json(tmp_path / "config.json", config)
    input_manifest = _json(tmp_path / "input.json", {
        "windows": {
            "full_from_utc": "2024-01-01T00:00:00Z",
            "full_to_utc": "2024-01-31T23:59:59Z",
        }
    })
    plan = _json(tmp_path / "plan.json", {"input_manifest_path": str(input_manifest)})
    item = {
        "id": "row-1", "ea_id": "QM5_9999", "symbol": "NDX.DWX",
        "phase": "Q10_NEWS", "status": "pending", "setfile_path": "QM5_9999_NDX_D1.set",
        "payload_json": json.dumps({
            "q09_run_plan_path": str(plan), "q09_run_plan_file_sha256": _sha(plan),
            "q09_input_manifest_sha256": _sha(input_manifest),
        }),
    }
    return config_path, item, primary


def test_admissible_row_gets_bound_marker_and_tampering_fails(tmp_path: Path):
    config, item, _ = _fixture(tmp_path)
    activation = scoped.load_activation(config)
    assessment = scoped.assess_work_item(item, activation)
    assert assessment["verdict"] == "ADMISSIBLE"
    marker = scoped.marker_for(item, activation, adjudicated_at="2026-09-07T05:00:00+00:00")
    payload = json.loads(item["payload_json"])
    payload[scoped.MARKER_KEY] = marker
    marked = dict(item, payload_json=json.dumps(payload))
    assert scoped.marker_valid(marked, activation)
    tampered = json.loads(marked["payload_json"])
    tampered[scoped.MARKER_KEY]["binding_sha256"] = "0" * 64
    assert not scoped.marker_valid(dict(marked, payload_json=json.dumps(tampered)), activation)


def test_declared_overlap_intraday_nonusd_and_missing_seal_fail_closed(tmp_path: Path):
    config, item, _ = _fixture(tmp_path, overlap=True)
    activation = scoped.load_activation(config)
    assert scoped.assess_work_item(item, activation)["reasons"] == ["DECLARED_EXCLUSION_OVERLAP"]
    bad = dict(item, symbol="GDAXI.DWX", setfile_path="QM5_9999_GDAXI_H4.set", payload_json="{}")
    reasons = scoped.assess_work_item(bad, activation)["reasons"]
    assert "INTRADAY_OR_UNKNOWN_TIMEFRAME" in reasons
    assert "NON_USD_EXPOSURE" in reasons
    assert "SEALED_Q10_WINDOW_UNAVAILABLE" in reasons


def test_candidate_hash_drift_refuses_activation(tmp_path: Path):
    config, _, primary = _fixture(tmp_path)
    primary.write_text(primary.read_text(encoding="utf-8") + "2024-01-16 13:30:00,USD,CPI,HIGH\n",
                       encoding="utf-8")
    with pytest.raises(scoped.ActivationError, match="SHA-256 mismatch"):
        scoped.load_activation(config)
