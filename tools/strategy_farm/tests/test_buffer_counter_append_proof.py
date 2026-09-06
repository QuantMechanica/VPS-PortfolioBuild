"""Frozen regressions for counter-indexed dynamic-buffer append proofs."""
from pathlib import Path

import pytest

from tools.strategy_farm import build_gate_hardening as gate


def findings(raw: str) -> list[str]:
    source = gate.SourceFile(
        path=Path("frozen.mq5"),
        raw=raw,
        code=gate.strip_comments_preserve_lines(raw),
    )
    return gate.check_indicator_buffer_bounds(source)


FROZEN_CLEAR_FIXTURES = {
    "QM5_20233_xauxag-skew-rank:L343": r"""
bool F(int count, int &observation_count) {
  observation_count = 0;
  double returns[]; ArrayResize(returns, count);
  for(int i = count - 1; i >= 0; --i) {
    if(i % 2 == 0) { returns[observation_count] = 1.0; ++observation_count; }
  }
  return true;
}
""",
    "QM5_20248_xng-vr-window:L309-L310": r"""
bool F(int copied, int needed_closes) {
  int month_keys[]; double month_closes[];
  ArrayResize(month_keys, needed_closes); ArrayResize(month_closes, needed_closes);
  int found = 0;
  for(int index = 0; index < copied && found < needed_closes; ++index) {
    if(index % 2 == 0) {
      month_keys[found] = index; month_closes[found] = 1.0; ++found;
    }
  }
  return true;
}
""",
    "QM5_20256_wti-vr6-mom:L297": r"""
bool F(int copied) { double month_end_closes[]; ArrayResize(month_end_closes, copied);
  int month_count = 0; for(int i = 0; i < copied; ++i) {
    if(i % 2 == 0) { month_end_closes[month_count] = 1.0; ++month_count; }
  } return true; }
""",
    "QM5_20257_wti-vr12-mom:L297": r"""
bool F(int copied) { double month_end_closes[]; ArrayResize(month_end_closes, copied);
  int month_count = 0; for(int i = 0; i < copied; ++i) {
    if(i % 3 == 0) { month_end_closes[month_count] = 1.0; ++month_count; }
  } return true; }
""",
    "QM5_20258_wti-mom-vote:L306": r"""
bool F(int copied) { double month_end_closes[]; ArrayResize(month_end_closes, copied);
  int month_count = 0; for(int i = 0; i < copied; ++i) {
    if(i % 4 == 0) { month_end_closes[month_count] = 1.0; ++month_count; }
  } return true; }
""",
    "QM5_41340_wti-xng-divtrend:L412": r"""
bool F(int common_count) { double month_end_closes[]; ArrayResize(month_end_closes, common_count);
  int month_count = 0; for(int i = 0; i < common_count; ++i) {
    if(i % 2 == 0) { month_end_closes[month_count] = 1.0; ++month_count; }
  } return true; }
""",
}


@pytest.mark.parametrize("origin,raw", FROZEN_CLEAR_FIXTURES.items())
def test_frozen_counter_append_false_positives_clear(origin: str, raw: str) -> None:
    source = gate.SourceFile(Path(origin), raw, gate.strip_comments_preserve_lines(raw))
    assert gate._check_indicator_buffer_bounds_legacy(source), origin
    assert findings(raw) == [], origin


def test_checked_resize_to_counter_plus_one_is_safe() -> None:
    raw = r"""
bool F() { double values[]; int count = 0;
  for(int i = 0; i < 8; ++i) {
    if(ArrayResize(values, count + 1) != count + 1) return false;
    values[count] = i; ++count;
  }
  return true;
}
"""
    assert findings(raw) == []


@pytest.mark.parametrize("raw", [
    r"""bool F() { double values[]; ArrayResize(values, 1); int count = 0;
      for(int i = 0; i < 4; ++i) { values[count] = i; ++count; } return true; }""",
    r"""bool F() { double values[]; ArrayResize(values, 4); int count = 0;
      for(int i = 0; i < 4; ++i) { ++count; values[count] = i; } return true; }""",
    r"""bool F() { double values[]; ArrayResize(values, 4); int count = 0;
      for(int i = 0; i < 4; ++i) { values[count] = i; ++count; ++count; } return true; }""",
])
def test_genuinely_unbounded_counter_access_still_fails(raw: str) -> None:
    assert findings(raw)
