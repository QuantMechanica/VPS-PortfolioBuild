from pathlib import Path
import re


EA_DIR = Path(__file__).resolve().parents[1]
SOURCE = EA_DIR / "QM5_21514_qs-klinger-vol-osc-xag.mq5"
SETS_DIR = EA_DIR / "sets"


def test_single_xag_scope_is_input_driven_and_suffix_safe() -> None:
    text = SOURCE.read_text(encoding="utf-8-sig")

    assert 'input string strategy_host_symbol        = "XAGUSD.DWX";' in text
    assert (
        "QM_MagicSymbolCanonical(_Symbol) != "
        "QM_MagicSymbolCanonical(strategy_host_symbol)"
    ) in text
    assert not re.search(r'_Symbol\s*(?:==|!=)\s*"XAGUSD\.DWX"', text)


def test_all_shipped_sets_bind_symbol_and_fixed_risk() -> None:
    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert setfiles

    for setfile in setfiles:
        text = setfile.read_text(encoding="utf-8-sig")
        assert "strategy_host_symbol=XAGUSD.DWX" in text
        assert re.search(r"(?m)^RISK_FIXED=(?!0(?:\.0+)?$)\d+(?:\.\d+)?$", text)
        assert re.search(r"(?m)^RISK_PERCENT=0(?:\.0+)?$", text)
        assert re.search(r"(?m)^qm_news_stale_max_hours=(?:[0-9]|[1-2][0-9]{1,2}|3[0-2][0-9]|33[0-6])$", text)
