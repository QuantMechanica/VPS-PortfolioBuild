"""Frozen regressions for the third bounded-array false-positive round."""
from pathlib import Path

import pytest

from tools.strategy_farm import build_gate_hardening as gate


ROOT = Path(__file__).resolve().parents[3]


def findings(raw: str) -> list[str]:
    source = gate.SourceFile(
        Path("frozen.mq5"), raw, gate.strip_comments_preserve_lines(raw)
    )
    return gate.check_indicator_buffer_bounds(source)


FROZEN_CLEAR = {
    "bounded_search_result": r"""
double F(double needle) { double sorted[]; if(ArrayResize(sorted, 4) != 4) return 0;
  int found = -1; for(int i=0; i<ArraySize(sorted); ++i) {
    if(sorted[i] >= needle) { found = i; break; }
  }
  if(found < 0) return 0; return sorted[found];
}
""",
    "diagnostic_fail_fast_counter": r"""
bool F(int expected) { double sorted[]; ArrayResize(sorted, expected); int index=0;
  for(int i=0; i<4; ++i) { for(int j=i+1; j<4; ++j) {
    if(index >= expected) { reason="overflow"; return false; }
    sorted[index]=1; ++index;
  }} return true;
}
""",
    "relational_fail_fast_chain": r"""
double F(int lower,int upper,int count) { double sorted[]; ArrayResize(sorted,count);
  if(lower < 0 || upper >= count || lower >= upper) { reason="bad"; return 0; }
  return sorted[lower];
}
""",
    "affine_loop_capacity": r"""
bool F(int window,int baseline) { if(window<2 || baseline<2) return false;
  int required=window+baseline+1; int count=required-1;
  double returns[]; if(ArrayResize(returns,count)!=count)return false;
  for(int i=0;i<window;++i) total+=returns[i]; return true;
}
""",
    "descending_cardinality_counter": r"""
bool F(int count) { double returns[]; if(ArrayResize(returns,count)!=count)return false;
  int used=0; for(int i=count;i>=1;--i) { returns[used]=i; ++used; }
  return true;
}
""",
    "unbraced_conditional_append": r"""
bool F(int count) { double values[]; if(ArrayResize(values,count)!=count)return false;
  int used=0; for(int i=0;i<count;++i)
    if(i%2==0) { values[used]=i; ++used; }
  return true;
}
""",
    "paired_merge_buffers": r"""
bool F(int left_count,int right_count) {
  int capacity=MathMin(left_count,right_count); datetime times[]; double left[]; double right[];
  if(ArrayResize(times,capacity)!=capacity || ArrayResize(left,capacity)!=capacity ||
     ArrayResize(right,capacity)!=capacity) return false;
  int i=0; int j=0; int used=0; while(i<left_count && j<right_count) {
    if(i==j) { times[used]=i; left[used]=1; right[used]=2; ++used; ++i; ++j; }
    else if(i<j) ++i; else ++j;
  } return true;
}
""",
}


@pytest.mark.parametrize("origin,raw", FROZEN_CLEAR.items())
def test_round3_frozen_false_positives_clear(origin: str, raw: str) -> None:
    assert gate._check_indicator_buffer_bounds_legacy(
        gate.SourceFile(Path(origin), raw, gate.strip_comments_preserve_lines(raw))
    ), origin
    assert findings(raw) == [], origin


AUTHORITY_EAS = {
    "20233": "QM5_20233_xauxag-skew-rank",
    "20248": "QM5_20248_xng-vr-window",
    "20256": "QM5_20256_wti-vr6-mom",
    "20257": "QM5_20257_wti-vr12-mom",
    "20258": "QM5_20258_wti-mom-vote",
    "20268": "QM5_20268_xauxag-qtail-rv",
    "20271": "QM5_20271_wti-theilsen-tr",
    "20276": "QM5_20276_wti-hl-mom",
    "20291": "QM5_20291_xauxag-kurt-rk",
    "20292": "QM5_20292_fx-carry-unwind",
    "20294": "QM5_20294_xauxag-max-rk",
    "21522": "QM5_21522_wti-lowdb-trend",
    "21527": "QM5_21527_wti-fallcorr-tr",
}


@pytest.mark.parametrize("ea_id,label", AUTHORITY_EAS.items())
def test_authority_bound_source_is_clear(ea_id: str, label: str) -> None:
    path = ROOT / "framework" / "EAs" / label / f"{label}.mq5"
    raw = path.read_text(encoding="utf-8-sig")
    source = gate.SourceFile(path, raw, gate.strip_comments_preserve_lines(raw))
    assert gate.check_indicator_buffer_bounds(source) == [], ea_id


@pytest.mark.parametrize("raw", [
    # Search result can exceed the cursor, target a different buffer, or remain -1.
    r"""double F(){double a[];ArrayResize(a,4);int found=-1;
      for(int i=0;i<ArraySize(a);++i){found=i+1;}if(found<0)return 0;return a[found];}""",
    r"""double F(){double a[];double b[];ArrayResize(a,4);ArrayResize(b,8);int found=-1;
      for(int i=0;i<ArraySize(b);++i){found=i;}if(found<0)return 0;return a[found];}""",
    r"""double F(){double a[];ArrayResize(a,4);int found=-1;
      for(int i=0;i<ArraySize(a);++i){if(flag){found=i;break;}}return a[found];}""",
    # A conditional return is not a dominating fail-fast arm.
    r"""double F(int i){double a[];ArrayResize(a,4);if(i>=4){if(flag)return 0;}return a[i];}""",
    # Affine capacity needs a proven non-negative remainder.
    r"""double F(int window,int extra){int count=window+extra;double a[];
      if(ArrayResize(a,count)!=count)return 0;for(int i=0;i<window;++i)total+=a[i];return total;}""",
    # Descending loops must have exactly the capacity cardinality and write before increment.
    r"""double F(int n){double a[];ArrayResize(a,n);int used=0;
      for(int i=n+1;i>=1;--i){a[used]=i;++used;}return 0;}""",
    r"""double F(int n){double a[];ArrayResize(a,n);int used=0;
      for(int i=n;i>=1;--i){++used;a[used]=i;}return 0;}""",
    # Paired merge proof rejects unequal sizes and incomplete cursor coupling.
    r"""double F(int l,int r){int cap=MathMin(l,r);long t[];double a[];
      ArrayResize(t,cap);ArrayResize(a,l);int i=0,j=0,k=0;while(i<l&&j<r){
      if(i==j){t[k]=i;a[k]=1;++k;++i;++j;}else ++i;}return 0;}""",
    r"""double F(int l,int r){int cap=MathMin(l,r);long t[];double a[];
      ArrayResize(t,cap);ArrayResize(a,cap);int i=0,j=0,k=0;while(i<l&&j<r){
      if(i==j){t[k]=i;a[k]=1;++k;++i;}else{++i;++j;}}return 0;}""",
])
def test_round3_unbounded_counterexamples_still_fail(raw: str) -> None:
    assert findings("// qm-build-generation: bounded-arrays-v2\n" + raw)


def test_default_rollout_does_not_surface_a_later_masked_finding() -> None:
    raw = r"""
double F(int window,int baseline,int unsafe_index) {
  if(window<2 || baseline<2) return 0;
  int required=window+baseline+1; int count=required-1;
  double returns[]; if(ArrayResize(returns,count)!=count)return 0;
  for(int i=0;i<window;++i) total+=returns[i];
  return total+returns[unsafe_index];
}
"""
    source = gate.SourceFile(
        Path("masked.mq5"), raw, gate.strip_comments_preserve_lines(raw)
    )
    before = gate._check_indicator_buffer_bounds_candidate(
        source, round3_enabled=False
    )
    after = gate._check_indicator_buffer_bounds_candidate(source)
    assert "returns[i]" in before[0]
    assert "returns[unsafe_index]" in after[0]
    assert gate.check_indicator_buffer_bounds(source) == []
    opted_in = findings("// qm-build-generation: bounded-arrays-v2\n" + raw)
    assert len(opted_in) == 1
    assert "returns[unsafe_index]" in opted_in[0]
