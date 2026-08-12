from __future__ import annotations

import json
from pathlib import Path

from tools.strategy_farm import dxz_lineage_audit as audit


def _report(inputs: dict[str, str]) -> str:
    rows = [
        "<tr><td>Inputs:</td><td><b>Strategy=</b></td></tr>",
        *[f"<tr><td></td><td><b>{key}={value}</b></td></tr>" for key, value in inputs.items()],
        "<tr><td>Company:</td><td><b>Test</b></td></tr>",
    ]
    return "<html><table>" + "".join(rows) + "</table></html>"


def _fixture_spec(
    tmp_path: Path,
    *,
    source_inputs: str,
    preset_values: dict[str, str],
    report_values: dict[str, str],
) -> tuple[dict, Path]:
    repo = tmp_path / "repo"
    repo.mkdir()
    source = repo / "QM5_11132_test.mq5"
    source.write_text(source_inputs, encoding="utf-8")
    card = tmp_path / "QM5_11132_test.md"
    card.write_text("---\ng0_status: APPROVED\n---\n# Test\n", encoding="utf-8")
    preset = tmp_path / "live.set"
    preset.write_text(
        "\n".join(f"{key}={value}" for key, value in preset_values.items()) + "\n",
        encoding="utf-8",
    )
    report = tmp_path / "report.htm"
    report.write_text(_report(report_values), encoding="utf-8")
    receipt = tmp_path / "receipt.json"
    receipt.write_text(
        json.dumps(
            {
                "job": {"ea_id": 11132, "symbol": "SP500.DWX"},
                "identity": {"live_preset_path": str(preset)},
                "native_metrics": {"report_path": str(report)},
            }
        ),
        encoding="utf-8",
    )
    source_manifest = tmp_path / "source_manifest.json"
    source_manifest.write_text(
        json.dumps(
            {
                "deployment_eligible": False,
                "sleeves": [
                    {
                        "ea_id": 11132,
                        "symbol": "SP500.DWX",
                        "ea_label": "QM5_11132_test",
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    spec_path = tmp_path / "spec.json"
    spec = {
        "schema_version": 1,
        "bound_as_of_utc": "2026-07-16T12:00:00Z",
        "repo_root": str(repo),
        "source_manifest_path": str(source_manifest),
        "sleeves": [
            {
                "ea_id": 11132,
                "symbol": "SP500.DWX",
                "card_path": str(card),
                "source_path": str(source),
                "receipt_path": str(receipt),
                "preset_path": str(preset),
                "report_path": str(report),
            }
        ],
    }
    spec_path.write_text(json.dumps(spec), encoding="utf-8")
    return spec, spec_path


def _run_fixture(spec: dict, spec_path: Path) -> dict:
    bound = audit.bind_explicit_spec(spec, spec_path)
    input_path = spec_path.with_name("bound.json")
    audit.write_immutable_json(input_path, bound)
    return audit.audit_bound_input(bound, input_path, "2026-07-16T12:01:00Z")


def test_bool_and_timeframe_enum_normalization_avoid_false_drift() -> None:
    false_symbol = audit.normalize_value("false", "bool")
    false_numeric = audit.normalize_value("0", "bool")
    h1_symbol = audit.normalize_value("PERIOD_H1", "ENUM_TIMEFRAMES")
    h1_numeric = audit.normalize_value("16385", "ENUM_TIMEFRAMES")

    assert audit.normalized_equal(false_symbol, false_numeric)
    assert audit.normalized_equal(h1_symbol, h1_numeric)
    assert h1_symbol["canonical"] == 16385


def test_enum_parser_resolves_implicit_members() -> None:
    values = audit.parse_enum_values(
        ["enum News { OFF = 0, PRE30, PRE60, PRE30_POST30 };\n"]
    )

    assert values["OFF"] == 0
    assert values["PRE30_POST30"] == 3


def test_missing_strategy_keys_use_source_defaults_without_error(tmp_path: Path) -> None:
    spec, spec_path = _fixture_spec(
        tmp_path,
        source_inputs=(
            "input bool strategy_enabled = false;\n"
            "input int strategy_period = 20;\n"
        ),
        preset_values={},
        report_values={"strategy_enabled": "0", "strategy_period": "20"},
    )

    result = _run_fixture(spec, spec_path)
    sleeve = result["sleeves"][0]

    assert sleeve["classification"] == "SOURCE_DEFAULT"
    assert set(sleeve["missing_strategy_keys_using_defaults"]) == {
        "strategy_enabled",
        "strategy_period",
    }
    assert sleeve["evidence_missing_reasons"] == []


def test_11132_regression_detects_exact_live_variant(tmp_path: Path) -> None:
    source = """
input double strategy_cum_rsi_entry = 35.0;
input double strategy_rsi_exit = 65.0;
input int strategy_sma_period = 200;
input int strategy_atr_period = 14;
input double strategy_atr_sl_mult = 2.5;
"""
    live = {
        "strategy_cum_rsi_entry": "38.0",
        "strategy_rsi_exit": "66.0",
        "strategy_sma_period": "165",
        "strategy_atr_period": "12",
        "strategy_atr_sl_mult": "2.0",
    }
    spec, spec_path = _fixture_spec(
        tmp_path,
        source_inputs=source,
        preset_values=live,
        report_values=live,
    )

    sleeve = _run_fixture(spec, spec_path)["sleeves"][0]

    assert sleeve["classification"] == "PREDECLARED_VARIANT_UNPROVEN"
    assert set(sleeve["strategy_overrides"]) == set(live)
    assert sleeve["strategy_overrides"]["strategy_cum_rsi_entry"]["source_default"][
        "canonical"
    ] == "35"
    assert sleeve["strategy_overrides"]["strategy_cum_rsi_entry"]["effective_value"][
        "canonical"
    ] == "38"


def test_variant_has_precedence_over_unknown_keys_and_preserves_both_flags(tmp_path: Path) -> None:
    spec, spec_path = _fixture_spec(
        tmp_path,
        source_inputs="input int strategy_period = 20;\n",
        preset_values={"strategy_period": "30", "qm_filter_news_enabled": "1"},
        report_values={"strategy_period": "30"},
    )

    sleeve = _run_fixture(spec, spec_path)["sleeves"][0]

    assert sleeve["classification"] == "PREDECLARED_VARIANT_UNPROVEN"
    assert sleeve["classification_flags"] == [
        "UNKNOWN_PRESET_KEYS",
        "PREDECLARED_VARIANT_UNPROVEN",
    ]
    assert sleeve["unknown_preset_keys"] == ["qm_filter_news_enabled"]


def test_report_effective_mismatch_fails_closed(tmp_path: Path) -> None:
    spec, spec_path = _fixture_spec(
        tmp_path,
        source_inputs="input int strategy_period = 20;\n",
        preset_values={"strategy_period": "30"},
        report_values={"strategy_period": "20"},
    )

    sleeve = _run_fixture(spec, spec_path)["sleeves"][0]

    assert sleeve["classification"] == "EVIDENCE_MISSING"
    assert "report:EFFECTIVE_INPUT_MISMATCH" in sleeve["evidence_missing_reasons"]
    assert sleeve["report_effective_mismatches"] == ["strategy_period"]


def test_hash_drift_is_evidence_missing_not_silently_rebound(tmp_path: Path) -> None:
    spec, spec_path = _fixture_spec(
        tmp_path,
        source_inputs="input int strategy_period = 20;\n",
        preset_values={"strategy_period": "20"},
        report_values={"strategy_period": "20"},
    )
    bound = audit.bind_explicit_spec(spec, spec_path)
    input_path = tmp_path / "bound.json"
    audit.write_immutable_json(input_path, bound)
    Path(spec["sleeves"][0]["preset_path"]).write_text(
        "strategy_period=30\n", encoding="utf-8"
    )

    result = audit.audit_bound_input(bound, input_path, "2026-07-16T12:01:00Z")
    sleeve = result["sleeves"][0]

    assert sleeve["classification"] == "EVIDENCE_MISSING"
    assert "preset:SHA256_MISMATCH" in sleeve["evidence_missing_reasons"]


def test_immutable_writer_refuses_different_existing_payload(tmp_path: Path) -> None:
    path = tmp_path / "report.json"
    audit.write_immutable_json(path, {"a": 1})
    audit.write_immutable_json(path, {"a": 1})

    try:
        audit.write_immutable_json(path, {"a": 2})
    except audit.LineageAuditError as exc:
        assert "refusing to overwrite" in str(exc)
    else:
        raise AssertionError("immutable output was overwritten")
