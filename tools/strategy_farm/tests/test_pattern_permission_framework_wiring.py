"""Static contracts for default-inert framework Pattern Permission wiring."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
QM = ROOT / "framework" / "include" / "QM"
COMMON = (QM / "QM_Common.mqh").read_text(encoding="utf-8")
ENTRY = (QM / "QM_Entry.mqh").read_text(encoding="utf-8")
BASKET = (QM / "QM_BasketOrder.mqh").read_text(encoding="utf-8")


def _body(source: str, signature: str) -> str:
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace : index + 1]
    raise AssertionError(f"unterminated function {signature}")


def test_common_exposes_six_zero_default_inputs_and_configures_current_timeframe():
    assert '#include "QM_PatternPermission.mqh"' in COMMON
    for name in ("opt_pp_buy1", "opt_pp_buy2", "opt_pp_buy3",
                 "opt_pp_sell1", "opt_pp_sell2", "opt_pp_sell3"):
        assert f"input int {name}" in COMMON
        assert f"input int {name}" in COMMON and "= 0;" in COMMON.split(f"input int {name}", 1)[1].splitlines()[0]
    assert "QM_EntryPatternConfigure(opt_pp_buy1, opt_pp_buy2, opt_pp_buy3," in COMMON
    assert "(ENUM_TIMEFRAMES)_Period, 1" in COMMON


def test_default_off_is_an_early_no_op_before_evaluation():
    body = _body(ENTRY, "bool QM_EntryPatternAllows(")
    inactive = body.index("if(!g_qm_entry_pattern_active)")
    returns = body.index("return true;", inactive)
    evaluates = body.index("QM_PatternPermissionEvaluate(")
    assert inactive < returns < evaluates
    no_op = body[inactive:returns]
    for forbidden in ("iTime", "CopyRates", "QM_LogEvent", "QM_Rand", "g_qm_pp_cache"):
        assert forbidden not in no_op


def test_standard_and_basket_boundaries_share_one_directional_opinion():
    entry_internal = _body(ENTRY, "QM_EntryResult QM_EntryInternal(")
    basket_open = _body(BASKET, "bool QM_BasketOpenPosition(")
    assert "QM_EntryPatternAllows(_Symbol, req.type, pattern_detail)" in entry_internal
    assert "QM_ENTRY_REJECTED_PATTERN" in entry_internal
    assert "QM_EntryPatternAllows(req.symbol, req.type, pattern_detail)" in basket_open
    assert "QM_BASKET_REJECTED_PATTERN" in basket_open
    opinion = _body(ENTRY, "bool QM_EntryPatternAllows(")
    assert "QM_OrderTypeIsBuy(type)" in opinion
    assert "permission.allow_buy" in opinion
    assert "permission.allow_sell" in opinion


def test_invalid_nonzero_predicates_fail_framework_initialization():
    configure = _body(ENTRY, "bool QM_EntryPatternConfigure(")
    assert configure.count("QM_EntryPatternAddConfigured(") == 6
    assert "PATTERN_PERMISSION_CONFIG_INVALID" in configure
    assert "return false;" in configure
    assert "if(!QM_EntryPatternConfigure(" in COMMON


def test_preintegration_pilot_siblings_keep_their_ea_managed_contract():
    labels = (
        "QM5_41161_tv-mon-ls-opt",
        "QM5_41162_ohlc-daily-squeeze-reversal-d1-opt",
        "QM5_41163_williams-18ma-outside-bar-entry-d1-opt",
    )
    for label in labels:
        source = (ROOT / "framework" / "EAs" / label / f"{label}.mq5").read_text(encoding="utf-8")
        assert source.index("#define QM_PATTERN_PERMISSION_EA_MANAGED") < source.index("QM_Common.mqh")
        assert source.count("input int opt_pp_") == 6
        assert "Pattern_AllowsRequest" in source
        assert "Opt_AddPattern" in source
