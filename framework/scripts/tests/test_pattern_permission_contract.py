"""P1 contract tests for framework/include/QM/QM_PatternPermission.mqh.

MQL5 cannot be executed here, so these tests enforce the properties that are
decidable from the source and that a future edit could silently break. They are
deliberately adversarial: each one encodes a defect the source reference actually
had (repaint via the forming bar, fail-open on bad data, a single global lookback
that made two predicates dead code, kill-list material sneaking back in).
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

HEADER = (Path(__file__).resolve().parents[2]
          / "include" / "QM" / "QM_PatternPermission.mqh")

SRC = HEADER.read_text(encoding="utf-8")


def _strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", " ", text)


# Semantic checks run against code only. The file header deliberately *names* the
# kill-list families it excludes, so prose must not trip the bans.
CODE = _strip_comments(SRC)


def _predicate_enum_block() -> str:
    m = re.search(r"enum QM_PatternId\s*\{(.*?)\};", CODE, re.S)
    assert m, "QM_PatternId enum not found"
    return m.group(1)

# Kill-list ids that must never be implemented: SMC/ICT/FVG/order-block/
# BOS/ChoCh (61-76), Wyckoff (85,86), Hurst (95,96), fake correlation (97).
KILL_LIST_IDS = set(range(61, 77)) | {85, 86, 95, 96, 97}
CONTROL_IDS = {1, 2}  # ALWAYS_ALLOW / ALWAYS_BLOCK are degenerate, not predicates


def _enum_ids() -> dict[str, int]:
    return {n: int(v) for n, v
            in re.findall(r"(QM_PP_[A-Z0-9_]+)\s*=\s*(\d+)", _predicate_enum_block())}


def _case_labels() -> set[str]:
    return set(re.findall(r"case\s+(QM_PP_[A-Z0-9_]+):", CODE))


def test_header_exists_and_is_guarded():
    assert HEADER.is_file()
    assert "#ifndef __QM_PATTERN_PERMISSION_MQH__" in SRC
    assert SRC.count("#endif") >= 1


def test_exactly_77_predicates_declared():
    ids = {n: v for n, v in _enum_ids().items() if n != "QM_PP_NONE"}
    assert len(ids) == 77, f"expected 77 predicates, found {len(ids)}"


def test_every_predicate_has_an_implementation_branch():
    ids = {n for n in _enum_ids() if n != "QM_PP_NONE"}
    missing = sorted(ids - _case_labels())
    assert not missing, f"declared but never evaluated: {missing}"


def test_no_kill_list_id_is_implemented():
    used = set(_enum_ids().values())
    leaked = sorted(used & KILL_LIST_IDS)
    assert not leaked, f"kill-list ids present: {leaked}"


def test_no_degenerate_control_ids():
    used = set(_enum_ids().values())
    assert not (used & CONTROL_IDS), "ALWAYS_ALLOW/ALWAYS_BLOCK must not exist"


def test_kill_list_terms_absent_from_source():
    """Names matter: a relabelled ICT predicate is still an ICT predicate."""
    banned = ["fair_value_gap", "fairvaluegap", "order_block", "orderblock",
              "liquidity_grab", "breaker_block", "mitigation_block",
              "break_of_structure", "change_of_character", "wyckoff",
              "hurst", "accumulation_phase", "distribution_phase",
              "silver_bullet", "judas", "imbalance_zone"]
    low = CODE.lower()
    found = [b for b in banned if b in low]
    assert not found, f"kill-list terminology in source: {found}"


def test_no_ml_constructs():
    low = CODE.lower()
    for term in ["onnx", "neural", "hiddenmarkov", "hmm_", "train(", "predict("]:
        assert term not in low, f"ML construct present: {term}"


def test_forming_bar_is_never_read():
    """CopyRates must start at the caller's closed shift, never at 0."""
    assert re.search(r"CopyRates\(\s*symbol\s*,\s*tf\s*,\s*closed_shift\s*,", SRC), \
        "CopyRates must be anchored on closed_shift"
    assert not re.search(r"CopyRates\([^)]*,\s*0\s*,\s*\d", SRC), \
        "a CopyRates call starts at the forming bar"


def test_shift_zero_is_rejected_at_the_api_boundary():
    assert "closed_shift < 1" in SRC
    assert "invalid_closed_shift_must_be_ge_1" in SRC


def test_partial_history_is_a_failure_not_a_best_effort():
    assert re.search(r"copied\s*<\s*need", SRC), \
        "a short CopyRates fill must abort, not proceed"


def test_deny_helper_blocks_both_directions():
    m = re.search(r"void QM_PP_Deny\([^)]*\)\s*\{(.*?)\n  \}", SRC, re.S)
    assert m, "QM_PP_Deny not found"
    body = m.group(1)
    assert "out.allow_buy = false" in body
    assert "out.allow_sell = false" in body
    assert "out.valid = false" in body


def test_every_deny_path_sets_valid_false():
    """No branch may return a permissive result with valid unset."""
    for reason in ["invalid_closed_shift_must_be_ge_1", "unsupported_profile_mode",
                   "reference_bar_unavailable", "insufficient_or_invalid_history"]:
        assert f'QM_PP_Deny(out, "{reason}")' in SRC, f"{reason} must deny"


def test_history_denial_is_cached():
    """A history gap must not be re-probed per tick nor flip mid-bar."""
    idx = SRC.index("insufficient_or_invalid_history")
    tail = SRC[idx:idx + 800]
    assert "g_qm_pp_cache_key = key" in tail
    assert "g_qm_pp_cache_valid = false" in tail


def test_cache_key_covers_symbol_tf_bar_and_profile():
    m = re.search(r"const string key = (.*?);", SRC, re.S)
    assert m, "cache key not found"
    key = m.group(1)
    assert "symbol" in key
    assert "reference_tf" in key
    assert "ref_bar" in key
    assert "QM_PP_ProfileKey(profile)" in key


def test_profile_key_includes_both_direction_lists():
    m = re.search(r"string QM_PP_ProfileKey\(.*?\n  \}", SRC, re.S)
    assert m
    body = m.group(0)
    assert "buy_predicates" in body and "sell_predicates" in body
    assert "reference_tf" in body and "closed_shift" in body


def test_required_bars_table_covers_the_percentile_predicates():
    """The reference shipped a global lookback of 22, which made 90/91 dead code."""
    m = re.search(r"case QM_PP_VOL_PERCENTILE_HIGH:\s*case QM_PP_VOL_PERCENTILE_LOW:\s*return (\d+);", SRC)
    assert m, "percentile predicates must declare their own lookback"
    assert int(m.group(1)) >= 101


def test_profile_lookback_is_the_max_over_its_predicates():
    m = re.search(r"int QM_PP_ProfileRequiredBars\(.*?\n  \}", SRC, re.S)
    assert m
    body = m.group(0)
    assert "MathMax" in body and "buy_predicates" in body and "sell_predicates" in body


def test_calendar_predicates_use_the_bar_timestamp_not_server_time():
    assert "QM_PP_IsThirdFriday(b.time[0])" in SRC
    assert "QM_PP_IsQuarterEnd(b.time[0])" in SRC
    for fn in ["QM_PP_IsThirdFriday", "QM_PP_IsQuarterEnd"]:
        m = re.search(rf"bool {fn}\(.*?\n  \}}", SRC, re.S)
        assert m and "TimeCurrent" not in m.group(0), \
            f"{fn} must not read server time"


def test_evaluator_never_touches_orders_or_risk():
    """The gate is a pure opinion; execution surfaces stay untouched."""
    for term in ["OrderSend", "PositionOpen", "trade.", "QM_TM_OpenPosition",
                 "PositionClose", "OrderModify", "AccountInfo"]:
        assert term not in CODE, f"evaluator touches an execution surface: {term}"


def test_v1_is_blacklist_only():
    assert "QM_PP_MODE_BLACKLIST" in SRC
    assert "WHITELIST" not in CODE.upper(), "whitelist is out of scope for v1"
    assert "unsupported_profile_mode" in SRC


def test_not_included_by_qm_common():
    """Including this in the umbrella would force a fleet-wide recompile."""
    common = HEADER.parent / "QM_Common.mqh"
    assert "QM_PatternPermission" not in common.read_text(encoding="utf-8")


@pytest.mark.parametrize("guard", ["b.count < QM_PP_RequiredBars(id)"])
def test_evaluate_guards_its_own_window(guard):
    assert guard in SRC, "each evaluation must verify its own bar requirement"
