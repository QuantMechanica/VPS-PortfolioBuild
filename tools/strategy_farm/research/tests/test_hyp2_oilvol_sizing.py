"""Synthetic HYP-2 checks, isolated from Factory worker integration fixtures.

No real archive, sealed stream or outcome payload is opened anywhere in this
file; every input is fabricated. These tests validate the REVIEW.md-corrected
feature/state contract only -- they establish no coverage, scaling, cost or
strategy-value claim (mirrors the HYP-1 test suite's own disclaimer).
"""
from dataclasses import replace
from datetime import date, datetime, timedelta, timezone
from math import exp, sqrt
from statistics import median as _stdlib_median

import pytest

from tools.strategy_farm.research import hyp1_causal_tags as clock
from tools.strategy_farm.research import hyp1_trade_projection as projection
from tools.strategy_farm.research import hyp2_oilvol_sizing as h


def daily(returns, start=date(2020, 1, 1)):
    values = [100.0]
    for r in returns:
        values.append(values[-1] * exp(r))
    return [h.DailyClose(start + timedelta(days=i), v, "VALID") for i, v in enumerate(values)]


# --- 81-close warmup -------------------------------------------------------

def test_warmup_requires_81_closes_first_eligible_index_80():
    rows = daily([0.01] * 79 + [0.10])  # 80 returns -> 81 closes, indices 0..80.
    result = h.evaluate(rows)
    assert len(result) == 81
    assert not any(e.signal_available for e in result[:80])
    assert result[80].signal_available
    assert result[80].prior60_median == pytest.approx(.01)
    assert result[80].rv20 == pytest.approx(sqrt((19 * .01 ** 2 + .10 ** 2) / 20))
    assert result[80].regime == "HIGH"


def test_warmup_before_index_80_is_unavailable_not_normal():
    rows = daily([0.001] * 100)
    result = h.evaluate(rows)
    assert all(not e.signal_available and e.regime == "UNAVAILABLE" for e in result[:80])


# --- equality / zero median --------------------------------------------------

@pytest.mark.parametrize("rv,med,expected", [
    (1.5, 1, "NORMAL"),      # exact 1.5x median does not engage HIGH.
    (1.0, 1, "NORMAL"),      # exact 1.0x median does not count as LOW/restore.
    (1.50001, 1, "HIGH"),
    (0.99999, 1, "LOW"),
    (0, 0, "NORMAL"),        # zero current, zero median: neither fires.
    (1, 0, "HIGH"),          # positive current, zero median: HIGH.
])
def test_strict_thresholds_and_zero_median(rv, med, expected):
    assert h.classify(rv, med) == expected


def test_median60_is_average_of_order_30_and_31():
    values = tuple(float(i) for i in range(60))
    assert h.median60(values) == _stdlib_median(values) == 29.5


def test_rv20_is_rms_not_demeaned_standard_deviation():
    returns = tuple([0.02] * 10 + [-0.02] * 10)  # nonzero values, zero sample mean.
    rms = h.rv20(returns)
    assert rms == pytest.approx(sqrt(sum(r * r for r in returns) / 20))
    assert rms == pytest.approx(0.02)  # RMS of a +/-0.02 split; a demeaned stdev would differ for skewed sets.
    skewed = tuple([0.03] * 15 + [0.0] * 5)
    assert h.rv20(skewed) == pytest.approx(sqrt(sum(r * r for r in skewed) / 20))


def test_twenty_flat_sessions_is_valid_zero_not_missing():
    rows = daily([0.0] * 100)
    result = h.evaluate(rows)
    assert result[80].signal_available and result[80].rv20 == 0.0 and result[80].regime == "NORMAL"


# --- daily state machine: HIGH precedence/retrigger, hold, release ----------

def test_transition_high_always_resets_age_to_zero_including_retrigger():
    state = (False, 0)
    for regime in ("HIGH", "NORMAL", "NORMAL", "HIGH", "NORMAL"):
        state = h.transition(*state, regime)
    # HIGH at step1 -> (True,0); NORMAL,NORMAL -> age 1,2; HIGH retrigger -> (True,0); NORMAL -> age1.
    assert state == (True, 1)


def test_five_valid_intervals_release_on_low_but_hold_on_normal():
    # HIGH, then four NORMAL (age 1..4, still active), then at age==5 a NORMAL holds,
    # a LOW at age==5 releases.
    holding = (False, 0)
    for regime in ("HIGH", "NORMAL", "NORMAL", "NORMAL", "NORMAL"):
        holding = h.transition(*holding, regime)
    assert holding == (True, 4)
    held_by_normal = h.transition(*holding, "NORMAL")
    assert held_by_normal == (True, 5)
    released_by_low = h.transition(*held_by_normal, "LOW")
    assert released_by_low == (False, 0)


def test_neutral_hysteresis_can_retain_floor_beyond_five_intervals():
    state = (False, 0)
    for regime in ("HIGH", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL"):
        state = h.transition(*state, regime)
    assert state == (True, 5)  # age caps at 5; NORMAL alone never releases the floor.


def test_low_without_five_elapsed_intervals_does_not_release():
    state = h.transition(False, 0, "HIGH")
    state = h.transition(*state, "LOW")  # age -> 1, still below K=5.
    assert state == (True, 1)


# --- missing-state retention / CLOSED does not consume an interval ---------

def test_missing_day_retains_latent_active_age_and_keeps_latent_multiplier():
    # A spike at index79 forces HIGH at row80 (retriggering through row99 while the
    # spike ages inside the 20-return window), then genuinely decays through LOW once
    # the window clears it: rows100-103 are LOW at age1..4, and row104 would naturally
    # release to inactive (verified empirically against this exact module).
    rows = daily([0.01] * 79 + [0.10] + [0.001] * 30)
    rows[104] = replace(rows[104], close=None, quality="MISSING")
    result = h.evaluate(rows)
    before = result[103]
    missing = result[104]
    assert before.active and before.age == 4
    # Latent (active, age) must not advance -- and must NOT release -- on the missing day,
    # even though an actual LOW observation here would have released the floor.
    assert missing.active == before.active and missing.age == before.age
    assert not missing.signal_available and missing.gap
    assert missing.nominal_multiplier == h.SIZE_FLOOR  # latent floor still reported, not forced to 1.0x.
    # The missing day clears the rolling windows, so warmup must rebuild (81 more closes).
    assert not result[105].signal_available and result[105].gap


def test_closed_day_does_not_consume_a_standdown_interval():
    # Same HIGH-then-decaying-LOW path as above; insert a known market closure between
    # the age1 and age2 LOW evaluations instead of a data gap.
    rows = daily([0.01] * 79 + [0.10] + [0.001] * 30)
    closed_day = rows[101].day + timedelta(days=1)
    rows = (rows[:102] + [h.DailyClose(closed_day, None, "CLOSED")]
            + [replace(r, day=r.day + timedelta(days=1)) for r in rows[102:]])
    result = h.evaluate(rows)
    before, closed_eval, resumed = result[101], result[102], result[103]
    assert before.active and before.age == 2
    assert closed_eval.regime == "CLOSED"
    assert closed_eval.active == before.active and closed_eval.age == before.age
    assert closed_eval.signal_available and not closed_eval.gap
    # The next real LOW evaluation resumes counting from the pre-closure age, not from zero.
    assert resumed.regime == "LOW" and resumed.active and resumed.age == 3


# --- DST / strict cutoffs / exact boundary ----------------------------------

@pytest.mark.parametrize("day,hour", [(date(2020, 1, 15), 22), (date(2020, 7, 15), 21)])
def test_next_server_midnight_in_both_dst_seasons(day, hour):
    assert clock.bar_available_at(day) == datetime(day.year, day.month, day.day, hour, tzinfo=timezone.utc)


def test_exact_boundary_entry_uses_previous_available_state():
    rows = daily([0.01] * 79 + [0.10])
    features = h.evaluate(rows)
    midnight = datetime.combine(rows[-1].day + timedelta(days=1), datetime.min.time())
    exact = h.tag_entry(h.GATED_EA_ID, midnight, features)
    before = h.tag_entry(h.GATED_EA_ID, midnight - timedelta(seconds=1), features)
    after = h.tag_entry(h.GATED_EA_ID, midnight + timedelta(seconds=1), features)
    assert exact.source_day == before.source_day == rows[-2].day
    assert exact.nominal_multiplier == before.nominal_multiplier == 1.0
    assert after.source_day == rows[-1].day and after.nominal_multiplier == h.SIZE_FLOOR


# --- multiple same-day entries ------------------------------------------------

def test_multiple_same_day_entries_share_identical_state():
    rows = daily([0.01] * 79 + [0.10])
    features = h.evaluate(rows)
    day_start = datetime.combine(rows[-1].day + timedelta(days=1), datetime.min.time())
    early = h.tag_entry(h.GATED_EA_ID, day_start + timedelta(hours=1), features)
    late = h.tag_entry(h.GATED_EA_ID, day_start + timedelta(hours=20), features)
    assert replace(early, entry_at_utc=None) == replace(late, entry_at_utc=None)


# --- future-data perturbation: no lookahead --------------------------------

def test_future_close_mutation_cannot_change_an_earlier_entry_tag():
    rows = daily([0.01] * 79 + [0.10] + [0.02] * 10)
    original = h.evaluate(rows)
    boundary = datetime.combine(rows[81].day, datetime.min.time()) + timedelta(seconds=1)
    changed = rows[:81] + [replace(r, close=r.close * 50) for r in rows[81:]]
    assert (h.tag_entry(h.GATED_EA_ID, boundary, original)
            == h.tag_entry(h.GATED_EA_ID, boundary, h.evaluate(changed)))


# --- untargeted sleeve / outside-coverage refusal --------------------------

def test_untargeted_ea_is_always_1x_and_outside_coverage_is_refused():
    rows = daily([0.01] * 79 + [0.10])
    features = h.evaluate(rows)
    entry = datetime.combine(rows[-1].day + timedelta(days=1), datetime.min.time()) + timedelta(seconds=1)
    other = h.tag_entry(99999, entry, features)
    assert other.nominal_multiplier == 1.0 and other.reason == "UNTARGETED"
    with pytest.raises(ValueError, match="descriptive window"):
        h.tag_entry(h.GATED_EA_ID, datetime(2025, 1, 1), features)


# --- winner retention / unresolved-cohort census (reused generic projector) -

def test_trade_projection_retains_every_row_never_drops_a_winner_or_unresolved_row():
    # Synthetic JSONL, structurally identical to the sealed 11422 stream's shape;
    # no real archive or outcome payload is read. Window mirrors OBSERVATION_START/END.
    lines = [
        b'{"event":"TRADE_CLOSED","entry_time":1549440000,"time":1549450000,"profit":150.0}',  # winner, in-window
        b'{"event":"TRADE_CLOSED","entry_time":1549440100,"time":1549450100,"profit":-80.0}',  # loser, in-window
        b'{"event":"TRADE_OPENED","entry_time":1549440200,"time":1549440200}',                 # non-closed event
        b'{"event":"TRADE_CLOSED","entry_time":1500000000,"time":1500000100,"profit":10.0}',   # before window
        b'not even json',                                                                       # unresolved row
    ]
    blob = b"\n".join(lines) + b"\n"
    from hashlib import sha256
    digest = sha256(blob).hexdigest()
    rows = projection.project_stream(blob, digest)
    assert len(rows) == len(lines)  # every row retained; nothing dropped.
    states = [r.state for r in rows]
    assert states.count("CLOSED") == 2  # both the winner and the loser are retained as closed outcomes.
    assert "NON_CLOSED_EVENT" in states
    assert "OUTSIDE_WINDOW" in states
    assert "UNRESOLVED" in states
    # Non-CLOSED rows never carry a decoded profit field (no outcome leakage beyond the eligibility check).
    assert all(r.gross_profit is None for r in rows if r.state != "CLOSED")
