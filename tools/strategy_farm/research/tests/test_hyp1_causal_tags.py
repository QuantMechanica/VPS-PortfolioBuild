"""Synthetic causal checks, isolated from Factory worker integration fixtures."""
from dataclasses import replace
from datetime import date, datetime, timedelta, timezone
from math import exp, sqrt

import pytest

from tools.strategy_farm.research import hyp1_causal_tags as h


def daily(returns, start=date(2020, 1, 1)):
    values = [100.0]
    for r in returns:
        values.append(values[-1] * exp(r))
    return [h.DailyClose(start + timedelta(days=i), v, "VALID") for i, v in enumerate(values)]


def test_first_evaluation_requires_66_closes_and_excludes_current_rv():
    rows = daily([0.01] * 64 + [0.10])
    result = h.evaluate(rows)
    assert not any(e.signal_available for e in result[:65])
    assert result[65].prior60_median == pytest.approx(sqrt(5) * .01)
    assert result[65].rv5 == pytest.approx(sqrt(4 * .01 ** 2 + .10 ** 2))
    assert result[65].regime == "HIGH"
    assert result[65].hold == 3


@pytest.mark.parametrize("rv,med,expected", [(1.5, 1, "NORMAL"), (.8, 1, "NORMAL"),
    (1.50001, 1, "HIGH"), (.79999, 1, "LOW"), (0, 0, "NORMAL"), (1, 0, "HIGH")])
def test_strict_thresholds_and_zero_median(rv, med, expected):
    assert h.classify(rv, med) == expected


def test_hold_refresh_low_restore_expiry_and_absent_evaluation():
    state = 0
    actual = []
    for regime in ("HIGH", "NORMAL", "HIGH", "UNAVAILABLE", "CLOSED", "LOW",
                   "HIGH", "NORMAL", "NORMAL", "NORMAL"):
        state = h.transition(state, regime)
        actual.append(state)
    assert actual == [3, 2, 3, 3, 3, 0, 3, 2, 1, 0]


@pytest.mark.parametrize("day,hour", [(date(2020, 1, 15), 22), (date(2020, 7, 15), 21)])
def test_next_server_midnight_in_both_dst_seasons(day, hour):
    assert h.bar_available_at(day) == datetime(day.year, day.month, day.day, hour, tzinfo=timezone.utc)


def test_ambiguous_and_nonexistent_server_wall_times_are_rejected():
    for dt in (datetime(2020, 11, 1, 8, 30), datetime(2020, 3, 8, 9, 30)):
        with pytest.raises(ValueError, match="ambiguous or nonexistent"):
            h.server_to_utc(dt)


def test_exact_boundary_and_same_day_cannot_consume_new_close():
    rows = daily([.01] * 64 + [.10])
    features = h.evaluate(rows)
    midnight = datetime.combine(rows[-1].day + timedelta(days=1), datetime.min.time())
    exact = h.tag_entry(13213, midnight, features)
    after = h.tag_entry(13213, midnight + timedelta(seconds=1), features)
    same_day = h.tag_entry(13213, midnight - timedelta(seconds=1), features)
    assert exact.nominal_multiplier == same_day.nominal_multiplier == 1
    assert exact.source_day == rows[-2].day
    assert after.nominal_multiplier == .5 and after.source_day == rows[-1].day


def test_future_price_mutation_cannot_change_earlier_entry_tag():
    rows = daily([.01] * 64 + [.10] + [.02] * 8)
    original = h.evaluate(rows)
    boundary = datetime.combine(rows[66].day, datetime.min.time()) + timedelta(seconds=1)
    changed = rows[:66] + [replace(r, close=r.close * 40) for r in rows[66:]]
    assert h.tag_entry(10706, boundary, original) == h.tag_entry(10706, boundary, h.evaluate(changed))


def test_missing_data_holds_counter_and_invalidates_cross_gap_windows():
    rows = daily([.01] * 64 + [.10] + [.01] * 67)
    rows[66] = replace(rows[66], close=None, quality="MISSING")
    features = h.evaluate(rows)
    assert features[66].hold == 3 and features[66].gap
    entry = datetime.combine(rows[66].day + timedelta(days=1), datetime.min.time()) + timedelta(seconds=1)
    tag = h.tag_entry(10700, entry, features)
    assert tag.nominal_multiplier == .5 and tag.feature_gap and not tag.signal_available
    assert not any(e.signal_available for e in features[66:132])
    assert features[132].signal_available and not features[132].gap


def test_closed_day_is_not_a_missing_observation_or_evaluation():
    rows = daily([.01] * 64 + [.10])
    rows.append(h.DailyClose(rows[-1].day + timedelta(days=1), None, "CLOSED"))
    feature = h.evaluate(rows)[-1]
    assert feature.hold == 3 and feature.signal_available and not feature.gap


def test_no_implicit_calendar_gap_or_holdout_price_access():
    rows = daily([.01] * 70)
    with pytest.raises(ValueError, match="calendar"):
        h.evaluate(rows[:10] + rows[11:])
    with pytest.raises(ValueError, match="input window"):
        h.evaluate([h.DailyClose(date(2025, 1, 1), 100, "VALID")])


@pytest.mark.parametrize("value", [0, -1, float("nan"), float("inf")])
def test_invalid_close_is_unavailable_not_silently_dropped(value):
    rows = daily([.01] * 64 + [.10])
    rows.append(h.DailyClose(rows[-1].day + timedelta(days=1), value, "VALID"))
    result = h.evaluate(rows)
    assert len(result) == len(rows)
    assert result[-1].gap and not result[-1].signal_available and result[-1].hold == 3


def test_six_sleeves_preserved_and_outcomes_cannot_influence_tags():
    rows = daily([.01] * 64 + [.10])
    features = h.evaluate(rows)
    entry = datetime.combine(rows[-1].day + timedelta(days=1), datetime.min.time()) + timedelta(seconds=1)
    # Two hypothetical outcome populations share exact entry facts, including losers.
    sleeves = (13213, 10706, 10700, 11422, 10403, 41219)
    winners = [{"ea": s, "pnl": 100} for s in sleeves]
    losers = [{"ea": s, "pnl": -200} for s in sleeves]
    a = [h.tag_entry(t["ea"], entry, features) for t in winners]
    b = [h.tag_entry(t["ea"], entry, features) for t in losers]
    assert a == b and len(a) == 6
    assert [t.nominal_multiplier for t in a] == [.5, .5, .5, 1, 1, 1]
    neutral = h.evaluate(daily([0] * 65))
    assert [h.tag_entry(s, entry, neutral).nominal_multiplier for s in sleeves] == [1] * 6


def test_no_feature_extrapolation_and_no_holdout_entry():
    features = h.evaluate(daily([.01] * 65))
    tag = h.tag_entry(13213, datetime(2020, 6, 1), features)
    assert tag.nominal_multiplier is None and not tag.signal_available
    with pytest.raises(ValueError, match="descriptive window"):
        h.tag_entry(13213, datetime(2025, 1, 1), features)
