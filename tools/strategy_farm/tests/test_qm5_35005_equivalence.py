from __future__ import annotations

import json
from pathlib import Path

from tools.strategy_farm import compile_work_items
from tools.strategy_farm import qm5_35005_equivalence as equivalence


def _report(path: Path, *, price: str = "1.10000", inputs: str = "") -> None:
    path.write_text(
        """
        <html><body><table>
        <tr><td>Inputs</td></tr>
        <tr><td>qm_ea_id=35005</td><td>opt_pp_buy1=0</td><td>opt_pp_buy2=0</td></tr>
        <tr><td>opt_pp_buy3=0</td><td>opt_pp_sell1=0</td><td>opt_pp_sell2=0</td></tr>
        <tr><td>opt_pp_sell3=""" + inputs + """</td></tr>
        <tr><td>Company</td></tr>
        <tr><td>Deals</td></tr>
        <tr>"""
        + "".join(f"<td>{field}</td>" for field in equivalence.DEAL_FIELDS)
        + """</tr>
        <tr><td>2022.07.01 00:00:00</td><td>1</td><td></td><td>balance</td>
        <td></td><td></td><td></td><td></td><td>0.00</td><td>0.00</td>
        <td>100 000.00</td><td>100 000.00</td><td></td></tr>
        <tr><td>2022.07.01 01:00:00</td><td>2</td><td>EURUSD.DWX</td><td>buy</td>
        <td>in</td><td>1.00</td><td>"""
        + price
        + """</td><td>2</td><td>-2.50</td><td>0.00</td><td>0.00</td>
        <td>99 997.50</td><td>entry</td></tr>
        <tr><td>2022.07.01 02:00:00</td><td>3</td><td>EURUSD.DWX</td><td>sell</td>
        <td>out</td><td>1.00</td><td>1.10100</td><td>3</td><td>-2.50</td>
        <td>0.00</td><td>100.00</td><td>100 095.00</td><td>exit</td></tr>
        </table></body></html>
        """,
        encoding="utf-8",
    )


def test_native_deal_canonicalization_is_field_and_byte_exact(tmp_path: Path) -> None:
    left = tmp_path / "left.htm"
    right = tmp_path / "right.htm"
    _report(left)
    _report(right)
    left_rows = equivalence.extract_deal_rows(left)
    right_rows = equivalence.extract_deal_rows(right)

    assert len(left_rows) == 3
    assert tuple(left_rows[0]) == equivalence.DEAL_FIELDS
    assert equivalence.compare_deal_rows(left_rows, right_rows)["identical"] is True
    assert equivalence.canonical_deal_bytes(left_rows) == equivalence.canonical_deal_bytes(right_rows)


def test_native_deal_parser_stops_at_multicell_report_footer(tmp_path: Path) -> None:
    report = tmp_path / "report.htm"
    _report(report)
    text = report.read_text(encoding="utf-8")
    report.write_text(
        text.replace(
            "</table>",
            "<tr><td></td><td>-1.00</td><td>100.00</td><td></td></tr></table>",
        ),
        encoding="utf-8",
    )
    assert len(equivalence.extract_deal_rows(report)) == 3


def test_native_deal_diff_names_exact_field(tmp_path: Path) -> None:
    left = tmp_path / "left.htm"
    right = tmp_path / "right.htm"
    _report(left)
    _report(right, price="1.10001")
    result = equivalence.compare_deal_rows(
        equivalence.extract_deal_rows(left), equivalence.extract_deal_rows(right)
    )

    assert result["identical"] is False
    assert result["different_row_count"] == 1
    assert result["differences"][0]["row_index"] == 1
    assert result["differences"][0]["fields"] == ["Price"]


def test_post_input_echo_requires_all_six_literal_zero(tmp_path: Path) -> None:
    report = tmp_path / "report.htm"
    _report(report, inputs="0")
    values = equivalence.extract_report_inputs(report)
    assert equivalence.post_input_echo_check(values) == {
        "pass": True,
        "observed": {name: "0" for name in equivalence.POST_INPUTS},
        "failures": {},
    }
    values["opt_pp_sell3"] = "1"
    assert equivalence.post_input_echo_check(values)["pass"] is False


def test_risk_contract_is_fixed_only(tmp_path: Path) -> None:
    setfile = tmp_path / "test.set"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    assert equivalence.validate_risk_contract(setfile) == {
        "RISK_FIXED": 1000.0,
        "RISK_PERCENT": 0.0,
    }


def test_tester_ini_comparison_excludes_only_report_outputs(tmp_path: Path) -> None:
    left = tmp_path / "left.ini"
    right = tmp_path / "right.ini"
    common = "[Tester]\nExpert=QM\\EQV35005\\ea\nSymbol=EURUSD.DWX\nModel=4\n"
    left.write_text(common + "Report=left.htm\nReplaceReport=0\n", encoding="utf-8")
    right.write_text(common + "Report=right.htm\nReplaceReport=1\n", encoding="utf-8")
    assert equivalence.canonical_execution_ini(left) == equivalence.canonical_execution_ini(right)


def test_compile_worker_delegates_exact_equivalence_contract(monkeypatch, tmp_path: Path) -> None:
    expected = {"action": "delegated"}
    monkeypatch.setattr(equivalence, "run_work_item", lambda *args: expected)
    item = {
        "id": "test-id",
        "payload_json": json.dumps(
            {"equivalence_contract_version": equivalence.CONTRACT_VERSION}
        ),
    }

    assert compile_work_items.run_compile_work_item(
        tmp_path / "farm", tmp_path / "repo", item, "T1"
    ) is expected
