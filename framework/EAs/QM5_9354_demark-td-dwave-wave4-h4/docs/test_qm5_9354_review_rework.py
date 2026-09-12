from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_9354_demark-td-dwave-wave4-h4.mq5"
SPEC = EA_DIR / "SPEC.md"


def _on_tick(text: str) -> str:
    return text.split("void OnTick()", 1)[1].split("void OnTimer()", 1)[0]


def test_skeleton_state_commits_only_after_successful_open() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    entry = text.split("bool Strategy_EntrySignal", 1)[1].split(
        "void Strategy_ManageOpenPosition", 1
    )[0]
    assert "last_traded_w3_time =" not in entry
    assert "last_w4_extreme =" not in entry
    tick = _on_tick(text)
    success = tick.split("if(QM_TM_OpenPosition(req, out_ticket))", 1)[1]
    assert "last_traded_w3_time = pending_w3_time;" in success
    assert "last_w4_extreme = pending_w4_extreme;" in success


def test_management_and_exits_precede_entry_only_news_and_spread_gates() -> None:
    tick = _on_tick(SOURCE.read_text(encoding="utf-8"))
    assert tick.index("QM_FrameworkTrackOpenPositionMae()") < tick.index(
        "QM_KillSwitchCheck()"
    )
    assert tick.index("Strategy_ManageOpenPosition()") < tick.index(
        "QM_NewsAllowsTrade2"
    )
    assert tick.index("Strategy_ExitSignal()") < tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert "ZeroMemory(req);" in tick


def test_fixed_risk_sets_match_the_nine_registered_slots() -> None:
    expected = {
        "EURUSD.DWX": "0",
        "GBPUSD.DWX": "1",
        "USDJPY.DWX": "2",
        "XAUUSD.DWX": "3",
        "XTIUSD.DWX": "4",
        "NDX.DWX": "5",
        "WS30.DWX": "6",
        "GDAXI.DWX": "7",
        "UK100.DWX": "8",
    }
    paths = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(paths) == len(expected)
    for path in paths:
        text = path.read_text(encoding="utf-8")
        symbol = next(symbol for symbol in expected if symbol in path.name)
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        assert f"qm_magic_slot_offset={expected[symbol]}" in text


def test_spec_and_news_guardrail_are_sealed() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    spec = SPEC.read_text(encoding="utf-8")
    assert "qm_news_stale_max_hours      = 336" in source
    assert "**EA ID:** QM5_9354" in spec
    for section in range(1, 8):
        assert f"## {section}." in spec
