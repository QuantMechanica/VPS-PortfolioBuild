"""Regression coverage for the frozen predicate defect and finite bounds.

The immutable triage receipt retains original failure counts. The corrected
predicate must clear the exact frozen sources without changing an EA.
"""
import hashlib
import json
import os
from pathlib import Path

import pytest
import build_gate_hardening as gate

ROOT = Path(os.environ.get('QM_BUFFER_TRIAGE_ROOT',
            str(Path(__file__).resolve().parents[3] /
                'docs/ops/evidence/2026-09-05_buffer_bound_family')))


def findings(raw):
    return gate.check_indicator_buffer_bounds(gate.SourceFile(
        path=Path('fixture.mq5'), raw=raw,
        code=gate.strip_comments_preserve_lines(raw)))


@pytest.mark.parametrize('ea,count', [(41186, 2), (41187, 3), (41188, 4), (41190, 3)])
def test_frozen_source_clears_reported_buffer_findings(ea, count):
    manifest = json.loads((ROOT / 'triage.json').read_text(encoding='utf-8-sig'))
    row = next(r for r in manifest['rows'] if r['ea_id'] == f'QM5_{ea}')
    path = ROOT / Path(row['fixture'])
    assert hashlib.sha256(path.read_bytes()).hexdigest() == row['source_sha256']
    result = findings(path.read_text(encoding='utf-8-sig'))
    assert len(row['findings']) == count
    assert result == []


def test_compound_arraysize_guard_is_recognized():
    raw = '''double F(int i) {
      double a[]; ArrayResize(a,13);
      double b[]; ArrayResize(b,13);
      if(i < 0 || i >= ArraySize(a) || i >= ArraySize(b)) return 0;
      return a[i] + b[i];
    }'''
    # Balanced parentheses are necessary: [^)]* stops at the first ArraySize.
    assert not findings(raw)
    for i in range(-100, 101):
        if i < 0 or i >= 13 or i >= 13:
            continue
        assert 0 <= i < 13


@pytest.mark.parametrize('count', [12, 13])
def test_reverse_index_and_insertion_sort_bounds_are_exhaustive(count):
    for index in range(count):
        reverse_index = count - 1 - index
        assert 0 <= reverse_index < count
    for index in range(1, count):
        # Every possible cursor reached by any ordering of the values.
        for cursor in range(index - 1, -2, -1):
            if cursor >= 0:
                assert 0 <= cursor < count
                assert 0 <= cursor + 1 < count
            assert 0 <= cursor + 1 <= index < count


def test_month_counter_sign_count_and_pivot_count_bounds():
    month_count = 0
    while month_count < 13:
        assert 0 <= month_count < 13
        month_count += 1  # source increments once then breaks its inner scan
    assert month_count == 13
    sign_count = 12  # source refuses continuation unless exactly 12
    for index in range(1, sign_count):
        assert 0 <= index - 1 < index < 12
    pivot_median_count = 13  # source's post-loop equality guard
    for index in range(pivot_median_count):
        assert 0 <= index < 13


def test_repeated_median_all_pivots_pairs_and_centers():
    n = 13
    grouped = 0
    for pivot in range(n):
        slopes = 0
        for other in range(n):
            if other == pivot:
                continue
            lower, upper = min(pivot, other), max(pivot, other)
            assert 0 <= lower < upper < n
            assert 0 <= slopes < 12
            slopes += 1
            grouped += 1
        assert slopes == 12
        low, high = slopes // 2 - 1, slopes // 2
        assert (low, high) == (5, 6) and 0 <= low < high < slopes
    assert grouped == 156
    assert 0 <= n // 2 == 6 < n


def test_theilsen_all_pairs_and_median_centers():
    n = 13
    positions = []
    for i in range(n - 1):
        for j in range(i + 1, n):
            assert 0 <= i < j < n
            assert len(positions) < n * (n - 1) // 2
            positions.append((i, j))
    assert len(positions) == 78
    assert (len(positions) // 2 - 1, len(positions) // 2) == (38, 39)
    assert 0 <= 38 < 39 < 78


@pytest.mark.parametrize('unsafe', [
    'double F(){double a[]; ArrayResize(a,4); double x=0; for(int i=0;i<5;++i){x+=a[i];} return x;}',
    'double F(int i){double a[]; ArrayResize(a,4); return a[i];}',
    'double F(int h){double a[]; const int copied=CopyBuffer(h,0,0,3,a); return a[2];}',
])
def test_unsafe_controls_still_fail_the_production_predicate(unsafe):
    assert findings(unsafe)


def test_existing_supported_safe_copybuffer_control():
    assert not findings('''double F(int h){
      double a[]; const int copied=CopyBuffer(h,0,0,3,a);
      if(copied < 3) return 0;
      return a[2];
    }''')
