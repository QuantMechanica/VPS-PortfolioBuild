from __future__ import annotations

from pathlib import Path

import pytest

from tools.strategy_farm import qm5_35005_equivalence as exact
from tools.strategy_farm import qm5_35005_equivalence_v2 as v2


def _deal(price: str = "1.10000") -> dict[str, str]:
    values = (
        "2022.07.01 01:00:00",
        "1",
        "EURUSD.DWX",
        "buy",
        "in",
        "1.00",
        price,
        "1",
        "0.00",
        "0.00",
        "0.00",
        "100000.00",
        "entry",
    )
    return dict(zip(exact.DEAL_FIELDS, values))


def _run(price: str = "1.10000", *, integration: bool = False) -> dict:
    history = {"sha256": "a" * 64}
    ini = {"Expert": v2.RUNTIME_EXPERT, "Symbol": v2.SYMBOL, "Model": "4"}
    profile = {
        "terminal": {"sha256": "b" * 64},
        "metatester": {"sha256": "c" * 64},
        "setfile": {"sha256": "d" * 64},
        "common_inputs": {
            "config": {"sha256": "e" * 64},
            "mql5_files": {"sha256": "f" * 64},
            "tester_groups": {"sha256": "1" * 64},
        },
    }
    return {
        "deal_rows": [_deal(price)],
        "execution_ini": ini,
        "inputs": (
            {"qm_ea_id": "35005", **{name: "0" for name in exact.POST_INPUTS}}
            if integration
            else {"qm_ea_id": "35005"}
        ),
        "history_before": history,
        "history_after": history,
        "profile": profile,
    }


def test_build_comparison_requires_byte_exact_deals_and_zero_echo() -> None:
    comparison, left, right = v2.build_comparison(_run(), _run(integration=True))
    assert left == right
    assert comparison["identical"] is True
    assert comparison["post_input_echo"]["pass"] is True

    comparison, _, _ = v2.build_comparison(
        _run(), _run("1.10001", integration=True)
    )
    assert comparison["identical"] is False
    assert comparison["row_diff"]["differences"][0]["fields"] == ["Price"]


def test_guardrails_require_fixed_risk_and_news_ceiling(tmp_path: Path) -> None:
    setfile = tmp_path / "test.set"
    source = tmp_path / "test.mq5"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    source.write_text(
        "input int qm_news_stale_max_hours = 336;\n", encoding="utf-8"
    )
    assert v2.parse_setfile_guard(setfile, source) == {
        "RISK_FIXED": 1000.0,
        "RISK_PERCENT": 0.0,
        "qm_news_stale_max_hours": 336,
    }
    source.write_text(
        "input int qm_news_stale_max_hours = 337;\n", encoding="utf-8"
    )
    with pytest.raises(v2.ProofError, match="exceeds 336"):
        v2.parse_setfile_guard(setfile, source)


def test_tester_ini_is_same_execution_contract_except_report(tmp_path: Path) -> None:
    left = tmp_path / "left.ini"
    right = tmp_path / "right.ini"
    v2.write_tester_ini(left, report_name="left.htm", setfile_name="same.set")
    v2.write_tester_ini(right, report_name="right.htm", setfile_name="same.set")
    assert exact.canonical_execution_ini(left) == exact.canonical_execution_ini(right)
    text = left.read_text(encoding="ascii")
    for required in (
        "Model=4",
        "UseLocal=1",
        "UseRemote=0",
        "UseCloud=0",
        "ShutdownTerminal=1",
    ):
        assert required in text


def test_create_only_scope_rejects_existing_or_parent_path(tmp_path: Path) -> None:
    candidate = tmp_path / "new"
    v2.assert_create_only_path(candidate, tmp_path)
    candidate.mkdir()
    with pytest.raises(v2.ProofError, match="already exists"):
        v2.assert_create_only_path(candidate, tmp_path)
    with pytest.raises(v2.ProofError, match="unsafe"):
        v2.assert_create_only_path(tmp_path, tmp_path)


def test_controller_has_no_factory_or_live_execution_target() -> None:
    source = Path(v2.__file__).read_text(encoding="utf-8")
    assert r"D:\QM\mt5\T1" not in source
    assert r"D:\QM\mt5\T_Live" not in source
    assert v2.DEFAULT_TEMPLATE.name == "DEV1"
