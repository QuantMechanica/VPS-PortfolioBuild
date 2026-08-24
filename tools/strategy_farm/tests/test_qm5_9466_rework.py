from __future__ import annotations

import importlib.util
import re
import unicodedata
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_9466_connors-r2-d1"
MQ5 = EA_DIR / "QM5_9466_connors-r2-d1.mq5"
SPEC = EA_DIR / "SPEC.md"
SPEC_VALIDATOR_PATH = REPO / "framework" / "scripts" / "validate_spec_doc.py"
APPROVED_SETFILES = {
    "QM5_9466_connors-r2-d1_NDX.DWX_D1_backtest.set",
    "QM5_9466_connors-r2-d1_SP500.DWX_D1_backtest.set",
    "QM5_9466_connors-r2-d1_WS30.DWX_D1_backtest.set",
}


def _load_spec_validator():
    module_spec = importlib.util.spec_from_file_location(
        "qm_validate_spec_doc", SPEC_VALIDATOR_PATH
    )
    assert module_spec is not None and module_spec.loader is not None
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    return module


def _valid_spec_text(ea_id: int) -> str:
    sections = "\n".join(
        f"## {section}\ncomplete" for section in _load_spec_validator().REQUIRED_SECTIONS
    )
    return f"# Test\n\n**EA ID:** QM5_{ea_id}\n\n{sections}\n"


def test_spec_validator_rejects_disallowed_control_characters(tmp_path: Path) -> None:
    ea_dir = tmp_path / "QM5_9999_control-probe"
    ea_dir.mkdir()
    (ea_dir / "SPEC.md").write_text(
        _valid_spec_text(9999).replace("complete", "bad\x1btext", 1),
        encoding="utf-8",
    )

    ok, failures = _load_spec_validator().check_one(ea_dir)

    assert ok is False
    assert any("disallowed control character" in failure for failure in failures)
    assert any("U+001B" in failure for failure in failures)


def test_real_spec_is_clean_and_names_only_the_approved_index_ports() -> None:
    raw = SPEC.read_bytes()
    text = raw.decode("utf-8")
    assert all(
        char in "\t\n\r" or unicodedata.category(char) != "Cc" for char in text
    )
    assert "ef14a5d7-e3f1-52be-910a-3ca6b736a152" in text
    assert "D:/QM/strategy_farm/artifacts/cards_approved/QM5_9466_connors-r2-d1.md" in text
    assert "RISK_FIXED = $1,000" in text
    for symbol in ("SP500.DWX", "NDX.DWX", "WS30.DWX"):
        assert symbol in text
    for forbidden in ("EURUSD.DWX", "XAUUSD.DWX", "GDAXI.DWX", "UK100.DWX"):
        assert forbidden not in text

    ok, failures = _load_spec_validator().check_one(EA_DIR)
    assert ok, failures


def test_d1_contract_and_card_exits_are_independent_of_entry_filters() -> None:
    source = MQ5.read_text(encoding="utf-8")
    oninit = source.split("int OnInit()", 1)[1].split("void OnDeinit", 1)[0]
    ontick = source.split("void OnTick()", 1)[1].split("void OnTimer()", 1)[0]

    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" in oninit
    assert "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE" in oninit
    assert "CARD_HAS_NO_FRIDAY_RULE_FRAMEWORK_SAFETY_OVERRIDE" in oninit
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in ontick
    assert "QM_IsNewBar()" not in ontick

    manage = ontick.index("Strategy_ManageOpenPosition();")
    strategy_exit = ontick.index("if(Strategy_ExitSignal())")
    new_bar = ontick.index("QM_IsNewBar(_Symbol, PERIOD_D1)")
    entry_filter = ontick.index("if(Strategy_NoTradeFilter())")
    strategy_news = ontick.index("if(Strategy_NewsFilterHook(broker_now))")
    framework_news = ontick.index("QM_NewsAllowsTrade2")
    assert manage < entry_filter
    assert strategy_exit < entry_filter
    assert strategy_exit < strategy_news
    assert strategy_exit < framework_news
    assert new_bar < entry_filter


def test_all_inputs_are_wired_and_static_contract_is_bounded() -> None:
    source = MQ5.read_text(encoding="utf-8")
    input_names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*(?:\s+[A-Za-z_][A-Za-z0-9_]*)*\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )
    assert input_names
    assert {name for name in input_names if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2} == set()

    raw_series_calls = re.compile(r"\b(?:iBars|iClose|iOpen|iHigh|iLow|iTime|iBarShift)\s*\(")
    for line in source.splitlines():
        if raw_series_calls.search(line):
            assert "perf-allowed:" in line

    assert "QM_TM_HeldPeriods(" in source
    assert "CopyBuffer(" not in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "qm_ea_id *" not in source
    assert re.search(r"input double\s+RISK_PERCENT\s*=\s*0\.0\s*;", source)
    assert re.search(r"input double\s+RISK_FIXED\s*=\s*1000\.0\s*;", source)
    assert not re.search(r"\b(?:onnx|tensorflow|torch|sklearn|keras)\b", source, re.I)


def test_packaged_setfiles_match_the_approved_card_universe() -> None:
    actual = {path.name for path in (EA_DIR / "sets").glob("*.set")}
    assert actual == APPROVED_SETFILES
