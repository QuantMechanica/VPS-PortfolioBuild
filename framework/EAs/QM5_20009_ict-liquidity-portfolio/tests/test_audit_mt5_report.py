"""Focused unit evidence for the QM5_20009 native-report auditor."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[1]
TOOLS = EA_ROOT / "tools"
FIXTURES = Path(__file__).resolve().parent / "fixtures"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import audit_mt5_report as audit  # noqa: E402


def test_english_utf8_report_reconciles_and_applies_deal_side_costs() -> None:
    receipt = audit.audit_report(FIXTURES / "mt5_report_en.html")

    assert receipt["status"] == "PASS"
    assert receipt["header"]["expert"] == audit.EXPECTED_EXPERT
    assert receipt["header"]["symbol"] == "NDX.DWX"
    assert receipt["header"]["timeframe"] == "M1"
    assert receipt["header"]["from_date"] == "2022-01-01"
    assert receipt["header"]["to_date"] == "2022-01-02"
    assert receipt["header"]["initial_deposit"] == "100000.00"
    assert receipt["header"]["currency"] == "USD"
    assert receipt["header"]["inputs"]["strategy_mode"] == "0"
    assert receipt["native_integrity"]["reported_total_net_profit"] == "150.00"
    assert receipt["native_integrity"]["deal_sum_profit_swap_commission"] == "150.00"
    assert receipt["metrics"]["external_cost_total_usd"] == "16.50"
    assert receipt["metrics"]["cost_adjusted_net_profit_usd"] == "133.50"
    assert receipt["metrics"]["cost_adjusted_gross_profit_usd"] == "189.00"
    assert receipt["metrics"]["cost_adjusted_gross_loss_usd"] == "-55.50"
    assert receipt["metrics"]["cost_adjusted_profit_factor"] == "3.40540541"
    assert receipt["metrics"]["max_cumulative_closed_balance_drawdown_usd"] == "55.50"
    assert receipt["same_day_swap_proof"]["status"] == "PASS"
    assert receipt["same_day_swap_proof"]["total_swap_usd"] == "0.00"
    assert re.fullmatch(
        r"[0-9a-f]{64}", receipt["identity"]["canonical_deal_sequence_sha256"]
    )
    assert re.fullmatch(r"[0-9a-f]{64}", receipt["report"]["sha256"])


def test_german_labels_decimal_commas_and_fx_base_conversion() -> None:
    receipt = audit.audit_report(FIXTURES / "mt5_report_de.html")

    assert receipt["header"]["symbol"] == "EURUSD.DWX"
    assert receipt["header"]["timeframe"] == "M5"
    # EUR entry: 2.50*1.10=2.75; exit: 2.50*1.11=2.775 -> 2.78 per deal.
    assert receipt["metrics"]["external_cost_total_usd"] == "5.53"
    assert receipt["metrics"]["cost_adjusted_net_profit_usd"] == "994.47"
    assert receipt["closed_positions"][0]["entry_external_cost_usd"] == "2.75"
    assert receipt["closed_positions"][0]["exit_external_cost_usd"] == "2.78"


def test_same_day_proof_uses_the_ea_frozen_new_york_date_not_server_midnight() -> None:
    assert audit._new_york_date_from_broker(datetime(2022, 1, 2, 0, 30)) == datetime(
        2022, 1, 1
    ).date()
    assert audit._new_york_date_from_broker(datetime(2022, 1, 2, 7, 0)) == datetime(
        2022, 1, 2
    ).date()
    receipt = audit.audit_report(FIXTURES / "mt5_report_en.html")
    assert receipt["same_day_swap_proof"]["date_basis"] == (
        "NEW_YORK_DATE_VIA_FROZEN_BROKER_MINUS_7_HOURS"
    )


def test_utf16_report_is_detected_without_a_bom_guess(tmp_path: Path) -> None:
    text = (FIXTURES / "mt5_report_en.html").read_text(encoding="utf-8")
    report = tmp_path / "report.htm"
    report.write_bytes(text.encode("utf-16-le"))

    receipt = audit.audit_report(report)

    assert receipt["status"] == "PASS"
    assert receipt["metrics"]["closed_positions"] == 2


def test_nonzero_native_commission_is_double_count_reject(tmp_path: Path) -> None:
    text = (FIXTURES / "mt5_report_en.html").read_text(encoding="utf-8")
    text = text.replace(
        "<td>2</td><td>0.00</td><td>0.00</td><td>0.00</td>",
        "<td>2</td><td>-5.50</td><td>0.00</td><td>0.00</td>",
        1,
    )
    report = tmp_path / "commission.htm"
    report.write_text(text, encoding="utf-8")

    with pytest.raises(audit.IntegrityError, match="DOUBLE_COUNT_REJECT"):
        audit.audit_report(report)


def test_total_net_profit_must_equal_deal_ledger_to_the_cent(tmp_path: Path) -> None:
    text = (FIXTURES / "mt5_report_en.html").read_text(encoding="utf-8")
    report = tmp_path / "bad_net.htm"
    report.write_text(text.replace("<td>150.00</td>", "<td>150.01</td>", 1), encoding="utf-8")

    with pytest.raises(audit.IntegrityError, match="Total Net Profit/deal-ledger drift"):
        audit.audit_report(report)


def test_duplicate_fingerprint_drift_rejects_even_when_each_report_is_consistent(
    tmp_path: Path,
) -> None:
    original = FIXTURES / "mt5_report_en.html"
    changed_text = original.read_text(encoding="utf-8")
    changed_text = changed_text.replace("<td>150.00</td>", "<td>149.99</td>", 1)
    changed_text = changed_text.replace("<td>-50.00</td>", "<td>-50.01</td>", 1)
    changed_text = changed_text.replace(
        "<td>-50.00</td><td>100 150.00</td>",
        "<td>-50.01</td><td>100 149.99</td>",
        1,
    )
    duplicate = tmp_path / "duplicate.htm"
    duplicate.write_text(changed_text, encoding="utf-8")
    assert audit.audit_report(duplicate)["status"] == "PASS"

    with pytest.raises(audit.DuplicateFingerprintDrift, match="DUPLICATE_FINGERPRINT_DRIFT"):
        audit.audit_reports([original, duplicate])


def test_cli_writes_reject_receipt_and_returns_nonzero_on_hash_drift(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    receipt_path = tmp_path / "receipt.json"
    exit_code = audit.main(
        [
            str(FIXTURES / "mt5_report_en.html"),
            "--expected-deal-sequence-sha256",
            "0" * 64,
            "--receipt",
            str(receipt_path),
        ]
    )

    assert exit_code == 2
    payload = json.loads(receipt_path.read_text(encoding="utf-8"))
    stdout_payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == stdout_payload["status"] == "REJECT"
    assert "SHA-256 drift" in payload["error"]
