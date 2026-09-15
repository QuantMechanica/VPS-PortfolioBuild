"""Regression tests for the book_reoptimizer advisory correlation change.

Review b2 MAJOR-3 / OWNER-DEC-CBE-20260915 sections 8/68B: the fixed 0.50
pairwise-correlation cut in the whole-book re-optimizer is now ADVISORY. A high
correlation no longer excludes a candidate (unless the opt-in ``--hard-max-corr``
experiment flag is set); it is surfaced as ``correlation_warnings`` plus a
``dependence_panel`` in a ``risk_diagnostics`` block (section 70: never a silent
no-op).
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))

from tools.strategy_farm.portfolio import book_reoptimizer as bro  # noqa: E402
from tools.strategy_farm.portfolio import risk_diagnostics  # noqa: E402


def _series_env():
    """Three sleeves whose return series are all strongly correlated."""
    base = list(range(1, 41))  # length 40 -> passes the >=30 overlap floor
    kA, kB, kC = (1, "AAA"), (2, "BBB"), (3, "CCC")
    series = {
        kA: [float(x) for x in base],
        kB: [float(x * 2) for x in base],
        kC: [float(x + 1) for x in base],
    }
    return series, [kA, kB, kC]


def test_correlation_is_advisory_by_default_no_hard_block():
    series, (kA, kB, kC) = _series_env()
    r = bro._pearson(series[kA], series[kB])
    assert r is not None and abs(r) > 0.5  # a genuinely high-correlation pair

    # Advisory default (hard_max_corr None): a perfectly correlated candidate is
    # NOT excluded.
    assert bro.correlation_hard_block(kA, [kB], series, None) is False


def test_hard_max_corr_opt_in_still_excludes():
    series, (kA, kB, _kC) = _series_env()
    r = abs(bro._pearson(series[kA], series[kB]))
    # A hard cut just below the measured |r| excludes; just above it admits.
    assert bro.correlation_hard_block(kA, [kB], series, r - 0.01) is True
    assert bro.correlation_hard_block(kA, [kB], series, r + 0.01) is False
    # Empty incumbent book never blocks.
    assert bro.correlation_hard_block(kA, [], series, 0.0) is False


def test_diagnostics_flag_high_corr_pairs_without_excluding():
    series, book = _series_env()
    warnings, panel = bro.build_correlation_diagnostics(book, series, reference=0.5)

    # C(3,2) = 3 pairs; all high-correlation => all WARN, none excluded.
    assert len(panel) == 3
    assert len(warnings) == 3
    for entry in panel:
        assert set(entry) >= {"a", "b", "correlation", "threshold", "severity"}
        assert entry["severity"] == "WARN"
    for w in warnings:
        assert w["severity"] == "WARN"
        assert w["superseded_hard_cap"] == risk_diagnostics.SUPERSEDING_DECISION
        assert w["correlation"] >= 0.5


def test_reference_above_all_pairs_yields_no_warnings_but_full_panel():
    series, book = _series_env()
    warnings, panel = bro.build_correlation_diagnostics(book, series, reference=2.0)
    assert warnings == []          # nothing reaches the (impossible) reference
    assert len(panel) == 3         # the measured panel is still emitted in full
    assert all(entry["severity"] != "WARN" for entry in panel)


def test_risk_diagnostics_block_carries_dependence_panel():
    series, book = _series_env()
    warnings, panel = bro.build_correlation_diagnostics(book, series, reference=0.5)
    diagnostics = risk_diagnostics.build(
        {}, dependence_panel=panel, correlation_warnings=warnings
    )
    assert diagnostics["schema"] == risk_diagnostics.RISK_DIAGNOSTICS_SCHEMA
    assert len(diagnostics["dependence_panel"]) == 3
    assert len(diagnostics["correlation_warnings"]) == 3
    # The reoptimizer computes no concentration caps here, so cap_warnings is empty
    # and the hard-guard summary passes.
    assert diagnostics["cap_warnings"] == []
    assert diagnostics["hard_guards"]["passed"] is True
