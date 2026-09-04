# -*- coding: utf-8 -*-
"""Tests for tools/strategy_farm/research/edge_lab_stats.py.

The fixture is a fully synthetic M5 bar set plus a synthetic Forex-Factory
calendar with PLANTED, KNOWN effects and a PLANTED, KNOWN timestamp defect, so
every assertion has a ground truth that does not depend on the production data
on D:.  There is no RNG anywhere -- the "noise" is a deterministic sum of two
sines.

Planted facts the tests rely on
-------------------------------
* bars are generated on the BROKER clock (naive epoch, 300 s grid), weekdays
  only, 24h/day, 2018-01-01..2020-12-31 (IS 2018-2019, OOS 2020);
* the payroll block is planted every other Wednesday at a fixed 08:30 US
  EASTERN, so its true UTC instant ALTERNATES 13:30Z / 12:30Z across the US-DST
  boundary exactly like the real print.  (The r1 fixture pinned releases to a
  fixed UTC time; a single constant displacement is then exact by construction
  and no test could exercise the production failure mode.)  Every release
  carries a x20 tickvol spike; every SECOND release additionally carries a
  surprise and a post-release price drift of PLANTED_DRIFT_BP over the
  following 90 minutes, signed so that the *trade-direction* return is positive
  on both EURUSD (USD = quote leg) and USDJPY (USD = base leg);
* three calendar rows describe that one instant: NFP, Unemployment Rate (whose
  polarity and surprise sign agree with NFP) and Average Hourly Earnings (whose
  surprise sign is planted OPPOSITE, so its direction contradicts NFP's on the
  identical price path).  The sealed cluster rule must resolve to NFP, not
  average the three;
* the synthetic calendar stores that block with DateTime_UTC displaced by
  exactly -17h -- the shape the production clean calendar carries -- so Stage 0
  must recover applied_offset_min == +1020;
* a DEFECT family (USD Core Retail Sales, Fridays 14:30 US Eastern) is stored
  with a displacement that is NOT constant: -17h for most months, -16h for
  Nov/Dec/Jan, and in June the stamp is right while the market printed 45 min
  late.  The group constant is therefore correct for most rows and wrong for
  the rest, and Stage 0b must VOID the wrong ones -- gate A on the home
  wall-clock, gate B on the local tickvol peak;
* a GBP family is stored with the CORRECT timestamp (09:00 Europe/London), so
  the test also proves Stage 0 does not "correct" what is already right;
* a pre-fix ramp followed by a partial give-back is planted at the 15:00
  London gold fix only, so XAUUSD|LDN_PM_1500 must show reversion while
  EURUSD|WMR_1600 and the XAUUSD|LDN_AM_1030 negative control must not.

Run:  python -X utf8 -m pytest tools/strategy_farm/tests/test_edge_lab_stats.py -q
"""
from __future__ import annotations

import bisect
import calendar as _calendar
import csv
import datetime as dt
import filecmp
import json
import math
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from research import edge_lab_stats as els  # noqa: E402

UTC = dt.timezone.utc

SYNTH_START = dt.date(2018, 1, 1)
SYNTH_END = dt.date(2020, 12, 31)
IS_START, IS_END = "2018-01-01", "2019-12-31"
OOS_START, OOS_END = "2020-01-01", "2020-12-31"

SYNTH_SYMBOLS = ("EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX")
SYNTH_BASE = {"EURUSD.DWX": 1.15, "GBPUSD.DWX": 1.30, "USDJPY.DWX": 130.0, "XAUUSD.DWX": 1800.0}
SYNTH_DIGITS = {"EURUSD.DWX": 5, "GBPUSD.DWX": 5, "USDJPY.DWX": 3, "XAUUSD.DWX": 2}

PLANTED_OFFSET_MIN = -1020          # the calendar stores release_true - 17h
PLANTED_DRIFT_BP = 12.0             # drift injected over the 18 bars after a release
PLANTED_PREMOVE_BP = 24.0           # pre-fix ramp over the 30 min before the fix
PLANTED_FIX_REVERSION = 0.5         # fraction of the ramp given back over 45 min

CALIB_GRID_MIN = 1100               # covers +1020 and excludes the +1170 cross-family lag


# ===========================================================================
# DST rule unit tests -- these are the load-bearing conversions
# ===========================================================================

def test_us_dst_boundaries_exact():
    start, end = els.us_dst_interval_utc(2023)
    assert start == dt.datetime(2023, 3, 12, 7, tzinfo=UTC)
    assert end == dt.datetime(2023, 11, 5, 6, tzinfo=UTC)
    assert els.darwinex_offset_hours(start - dt.timedelta(seconds=1)) == 2
    assert els.darwinex_offset_hours(start) == 3
    assert els.darwinex_offset_hours(end - dt.timedelta(seconds=1)) == 3
    assert els.darwinex_offset_hours(end) == 2


def test_us_dst_is_not_eu_dst():
    """2023-03-14: US already on DST, EU not until 2023-03-26."""
    u = dt.datetime(2023, 3, 14, 12, 30, tzinfo=UTC)
    assert els.is_us_dst(u) is True
    assert els.darwinex_offset_hours(u) == 3
    # 2022-11-02: EU off DST since 10-30, US still on until 11-06
    u2 = dt.datetime(2022, 11, 2, 18, 0, tzinfo=UTC)
    assert els.is_us_dst(u2) is True
    assert els.darwinex_offset_hours(u2) == 3


def test_utc_broker_roundtrip_across_both_switches():
    for year in range(2018, 2026):
        start, end = els.us_dst_interval_utc(year)
        probes = [start - dt.timedelta(hours=3), start, start + dt.timedelta(hours=3),
                  end - dt.timedelta(hours=3), end, end + dt.timedelta(hours=3),
                  dt.datetime(year, 7, 1, 12, tzinfo=UTC),
                  dt.datetime(year, 1, 15, 12, tzinfo=UTC)]
        for u in probes:
            u = u.replace(second=0, microsecond=0)
            raw = els.utc_to_broker_epoch(u)
            back = els.broker_epoch_to_utc(raw)
            # the November fallback hour is genuinely ambiguous in broker time;
            # the rule pins it to the standard-time (+2) candidate, exactly like
            # QM_BrokerToUTC.  Everywhere else the round trip is exact.
            if end - dt.timedelta(hours=1) <= u < end:
                assert back == u + dt.timedelta(hours=1)
                with pytest.raises(ValueError):
                    els.broker_epoch_to_utc(raw, strict=True)
            else:
                assert back == u, (year, u, back)


def test_broker_epoch_matches_verified_production_examples():
    # NFP 2023-02-03 13:30Z (US standard) -> broker epoch 1675438200
    assert els.utc_to_broker_epoch(dt.datetime(2023, 2, 3, 13, 30, tzinfo=UTC)) == 1675438200
    # NFP 2024-11-01 12:30Z (US DST still on) -> broker epoch 1730475000
    assert els.utc_to_broker_epoch(dt.datetime(2024, 11, 1, 12, 30, tzinfo=UTC)) == 1730475000


def test_uk_dst_rule_and_mismatch_windows():
    s, e = els.uk_dst_interval_utc(2023)
    assert s == dt.datetime(2023, 3, 26, 1, tzinfo=UTC)
    assert e == dt.datetime(2023, 10, 29, 1, tzinfo=UTC)
    # ALIGNED winter: 16:00 London == 16:00Z -> broker 18:00
    u = els.london_local_to_utc(dt.date(2023, 1, 18), 16, 0)
    assert u == dt.datetime(2023, 1, 18, 16, tzinfo=UTC)
    assert els.broker_hour(els.utc_to_broker_epoch(u)) == 18
    # ALIGNED summer: 16:00 London == 15:00Z -> broker 18:00
    u = els.london_local_to_utc(dt.date(2023, 7, 18), 16, 0)
    assert u == dt.datetime(2023, 7, 18, 15, tzinfo=UTC)
    assert els.broker_hour(els.utc_to_broker_epoch(u)) == 18
    # MISMATCH (US on DST, UK not): 2023-03-20 -> broker 19:00
    u = els.london_local_to_utc(dt.date(2023, 3, 20), 16, 0)
    assert els.is_us_dst(u) and not els.is_uk_dst(u)
    assert els.broker_hour(els.utc_to_broker_epoch(u)) == 19
    # MISMATCH (UK off DST, US still on): 2023-10-31 -> broker 19:00
    u = els.london_local_to_utc(dt.date(2023, 10, 31), 16, 0)
    assert els.is_us_dst(u) and not els.is_uk_dst(u)
    assert els.broker_hour(els.utc_to_broker_epoch(u)) == 19


def test_broker_integer_helpers_agree_with_datetime():
    for raw in (1506902700, 1675438200, 1730475000, 1767225300):
        wall = dt.datetime(1970, 1, 1) + dt.timedelta(seconds=raw)
        assert els.broker_weekday(raw) == wall.weekday()
        assert els.broker_hour(raw) == wall.hour
        assert els.broker_minute(raw) == wall.minute


# ===========================================================================
# number parser
# ===========================================================================

@pytest.mark.parametrize("raw,expected", [
    ("3.2%", 3.2), ("-0.1%", -0.1), ("1,234", 1234.0), ("216K", 216000.0),
    ("1.5M", 1500000.0), ("2.3B", 2.3e9), ("1.1T", 1.1e12), ("50.4", 50.4),
    ("", None), ("  ", None), ("1.41|3.1", None), ("0-0-9", None),
    ("<0.25%", None), ("Pass", None), (None, None), ("-", None),
])
def test_parse_calendar_number(raw, expected):
    got = els.parse_calendar_number(raw)
    if expected is None:
        assert got is None
    else:
        assert got == pytest.approx(expected)


# ===========================================================================
# pure-maths unit tests
# ===========================================================================

def test_cell_prefix_sums_match_a_naive_recomputation():
    epochs = [1000 + 86400 * i for i in range(50)]
    vals = [float((i * 7) % 13) - 6.0 for i in range(50)]
    c = els.Cell(list(epochs), {90: list(vals)})
    n, mu, sd = c.stats(90, None, None)
    assert n == 50
    assert mu == pytest.approx(els._mean(vals))
    assert sd == pytest.approx(math.sqrt(els._pvar(vals)))
    lo, hi = epochs[10], epochs[20]
    keep = [vals[i] for i in range(50) if not (lo <= epochs[i] <= hi)]
    n2, mu2, sd2 = c.stats(90, lo, hi)
    assert n2 == len(keep) == 39
    assert mu2 == pytest.approx(els._mean(keep))
    assert sd2 == pytest.approx(math.sqrt(els._pvar(keep)))


def test_ols_slope_recovers_a_known_line():
    xs = [float(i) for i in range(40)]
    ys = [3.0 + 2.5 * x for x in xs]
    beta, se = els._ols_slope(xs, ys)
    assert beta == pytest.approx(2.5)
    assert se == pytest.approx(0.0, abs=1e-9)


def test_float_formatting_is_fixed_and_locale_free():
    assert els.fmt(1.0 / 3.0) == "0.3333333333"
    assert els.fmt(None) == ""
    assert els.fmt(float("nan")) == ""
    assert els.fmt(1e-12) == "1e-12"
    assert els.fmt(True) == "1"


def test_polarity_map_hash_is_stable_and_content_addressed():
    a = els.sha256_bytes(json.dumps(els.EVENT_POLARITY, sort_keys=True,
                                    ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    b = els.sha256_bytes(json.dumps(dict(reversed(list(els.EVENT_POLARITY.items()))),
                                    sort_keys=True, ensure_ascii=False,
                                    separators=(",", ":")).encode("utf-8"))
    assert a == b, "polarity hash must not depend on dict insertion order"
    assert len(a) == 64
    # every polarity is +1 or -1; a missing event is excluded, never defaulted
    assert set(els.EVENT_POLARITY.values()) == {1, -1}


def test_sealed_thresholds_are_the_doc_values():
    assert els.EDGE1_PRIMARY_CELL == {"surprise_z_threshold": 1.00, "entry_delay_min": 5,
                                      "holding_min": 90}
    assert els.EDGE1_EFFECT_SIGMA_FLOOR == 0.40
    assert els.EDGE1_N_EFF_FLOOR == 300
    assert els.EDGE1_DECLARED_TRIALS == 36
    assert els.EDGE3_PRIMARY_CELL == {"prefix_window_min": 30, "threshold_atr": 0.6,
                                      "holding_min": 45}
    assert els.EDGE3_R_FLOOR == 0.15
    assert els.EDGE3_N_DAYS_FLOOR == 800
    assert els.EDGE3_DECLARED_TRIALS == 108


# ===========================================================================
# synthetic fixture
# ===========================================================================

def _weekly_utc(start: dt.date, end: dt.date, weekday: int, hh: int, mm: int):
    out = []
    d = start
    while d <= end:
        if d.weekday() == weekday:
            out.append(dt.datetime(d.year, d.month, d.day, hh, mm, tzinfo=UTC))
        d += dt.timedelta(days=1)
    return out


def _home_local_to_utc(currency: str, day: dt.date, hh: int, mm: int) -> dt.datetime:
    """Home wall clock -> UTC, using the module's own home-timezone rule.

    Real scheduled releases are fixed in their HOME local time, so their UTC
    instant moves by an hour twice a year.  The old fixture pinned them to a
    fixed UTC time, which made a single constant displacement exact by
    construction and could therefore never exercise the production failure
    mode (see test_stage0_voids_the_dst_seasonal_displacement).
    """
    cands = {"USD": (-5, -4), "GBP": (0, 1), "EUR": (1, 2)}[currency]
    wall = dt.datetime(day.year, day.month, day.day, hh, mm, tzinfo=UTC)
    surv = [wall - dt.timedelta(hours=o) for o in cands
            if els.home_tz_offset_hours(currency, wall - dt.timedelta(hours=o)) == o]
    assert len(surv) == 1, (currency, day, hh, mm, surv)
    return surv[0]


def _biweekly_local(currency: str, weekday: int, hh: int, mm: int, phase: int = 0):
    """Releases on every OTHER matching weekday at a fixed HOME LOCAL time.

    Sparseness matters: if a release occupied every single Wednesday at that
    slot, the weekday/hour/minute-matched baseline cell would be news-
    contaminated on every candidate day and would be empty by construction.
    Real calendars are sparse in exactly this way (NFP monthly, CPI monthly).
    """
    out = []
    d = SYNTH_START
    i = 0
    while d <= SYNTH_END:
        if d.weekday() == weekday:
            if i % 2 == phase:
                out.append(_home_local_to_utc(currency, d, hh, mm))
            i += 1
        d += dt.timedelta(days=1)
    return out


def _usd_releases():
    """(true_utc, is_big, sign) -- big releases carry the surprise and the drift.

    Fixed at 08:30 US Eastern, so the true UTC instant alternates 13:30Z
    (US standard) and 12:30Z (US DST) exactly like the real payroll print.
    """
    out = []
    for i, u in enumerate(_biweekly_local("USD", 2, 8, 30)):
        big = (i % 2 == 0)
        sign = 1 if (i // 2) % 2 == 0 else -1
        out.append((u, big, sign))
    return out


# The DEFECT family.  True releases at a fixed 14:30 US Eastern (far enough
# from the payroll block that the +/-195 min confounding halo does not touch
# it), but the calendar stores them with a displacement that is NOT a constant:
#   * -17h for most months           -> +1020 recovers the exact instant
#   * -16h for Nov / Dec / Jan       -> +1020 lands them ONE HOUR LATE
#     (this is the production shape: raw NFP stamps are Thu 19:30Z Apr-Sep and
#      Thu 20:30Z Oct-Mar, a DST rule of the calendar's own)
# and in addition, in June, the calendar stamp is right but the market actually
# printed 45 minutes later, so the home clock agrees while the tickvol peak
# does not.  Gate A must catch the first class, gate B the second.
DEFECT_MODAL_OFFSET_MIN = 1020
DEFECT_SHORT_MONTHS = (11, 12, 1)
DEFECT_SHORT_OFFSET_MIN = 960
DEFECT_LATE_PRINT_MONTH = 6
DEFECT_LATE_PRINT_MIN = 45


def _usd_defect_releases():
    """(scheduled_utc, stored_utc, actual_print_utc, class) for the defect family."""
    out = []
    for u in _biweekly_local("USD", 4, 14, 30):
        if u.month in DEFECT_SHORT_MONTHS:
            stored = u - dt.timedelta(minutes=DEFECT_SHORT_OFFSET_MIN)
            printed = u
            cls = "home_clock_mismatch"
        elif u.month == DEFECT_LATE_PRINT_MONTH:
            stored = u - dt.timedelta(minutes=DEFECT_MODAL_OFFSET_MIN)
            printed = u + dt.timedelta(minutes=DEFECT_LATE_PRINT_MIN)
            cls = "local_peak_elsewhere"
        else:
            stored = u - dt.timedelta(minutes=DEFECT_MODAL_OFFSET_MIN)
            printed = u
            cls = "clean"
        out.append((u, stored, printed, cls))
    return out


def _gbp_releases():
    """Fixed at 09:00 Europe/London, stored with the CORRECT timestamp.

    Deliberately on the ODD biweekly phase: on the even phase its Thursday
    release would sit a constant -1050 min from the Friday defect family's
    stored stamp, i.e. inside that family's calibration grid, and would show up
    as a second peak of the same height.
    """
    out = []
    for i, u in enumerate(_biweekly_local("GBP", 3, 9, 0, phase=1)):
        big = (i % 2 == 0)
        sign = 1 if (i // 2) % 2 == 0 else -1
        out.append((u, big, sign))
    return out


# drift sign per symbol so that the TRADE-DIRECTION return is positive:
#   USD event, polarity(NFP)=+1 -> direction = sign
#     EURUSD: USD is the quote leg -> trade_dir = -sign -> price must move -sign
#     USDJPY: USD is the base leg  -> trade_dir = +sign -> price must move +sign
#   GBP event, polarity(Retail Sales m/m)=+1 -> direction = sign
#     GBPUSD: GBP is the base leg  -> trade_dir = +sign -> price must move +sign
_USD_DRIFT_LEG = {"EURUSD.DWX": -1, "USDJPY.DWX": +1}
_GBP_DRIFT_LEG = {"GBPUSD.DWX": +1}


def _build_bars(tmpdir: Path):
    usd = _usd_releases()
    gbp = _gbp_releases()
    spikes = {}
    drifts = {}
    for u, big, sign in usd:
        e = els.utc_to_broker_epoch(u)
        spikes[e] = 20.0
        if big:
            drifts.setdefault(e, {}).update({"family": "USD", "sign": sign})
    for _sched, _stored, printed, _cls in _usd_defect_releases():
        spikes[els.utc_to_broker_epoch(printed)] = 20.0
    for u, big, sign in gbp:
        e = els.utc_to_broker_epoch(u)
        spikes[e] = 20.0
        if big:
            drifts.setdefault(e, {}).update({"family": "GBP", "sign": sign})

    fix_epochs = {}
    d = SYNTH_START
    while d <= SYNTH_END:
        if d.weekday() < 5:
            e = els.utc_to_broker_epoch(els.london_local_to_utc(d, 15, 0))
            fix_epochs[e] = 1 if (e // 86400) % 2 == 0 else -1
        d += dt.timedelta(days=1)

    t0 = _calendar.timegm(dt.datetime(SYNTH_START.year, 1, 1).timetuple())
    t1 = _calendar.timegm(dt.datetime(SYNTH_END.year, 12, 31, 23, 55).timetuple())

    pre_steps = {}    # epoch -> bp added, the 6 bars before a fix
    post_steps = {}   # epoch -> bp added, the 9 bars after a fix
    for e, s in fix_epochs.items():
        for j in range(1, 7):
            pre_steps[e - j * els.SLOT_SECONDS] = s * PLANTED_PREMOVE_BP / 6.0
        for j in range(0, 9):
            post_steps[e + j * els.SLOT_SECONDS] = -s * PLANTED_FIX_REVERSION * PLANTED_PREMOVE_BP / 9.0

    for sym in SYNTH_SYMBOLS:
        px = SYNTH_BASE[sym]
        digits = SYNTH_DIGITS[sym]
        seedmix = sum(ord(c) for c in sym)
        usd_leg = _USD_DRIFT_LEG.get(sym, 0)
        gbp_leg = _GBP_DRIFT_LEG.get(sym, 0)
        fix_sym = 1 if sym == "XAUUSD.DWX" else 0
        rows = []
        drift_left = 0
        drift_step = 0.0
        t = t0
        while t <= t1:
            if els.broker_weekday(t) > 4:
                t += els.SLOT_SECONDS
                continue
            k = t // els.SLOT_SECONDS
            step_bp = (math.sin((k * 7 + seedmix) * 0.013) * 0.6
                       + math.sin((k * 3 + seedmix) * 0.0007) * 0.4) * 1.2
            tv = 100.0 + (k * 37 + seedmix) % 60

            sp = spikes.get(t)
            if sp:
                tv *= sp
            dr = drifts.get(t)
            if dr:
                leg = usd_leg if dr["family"] == "USD" else gbp_leg
                if leg:
                    drift_left = 18
                    drift_step = leg * dr["sign"] * PLANTED_DRIFT_BP / 18.0
            if drift_left > 0:
                step_bp += drift_step
                drift_left -= 1

            if fix_sym:
                if t in fix_epochs:
                    tv *= 8.0
                step_bp += pre_steps.get(t, 0.0)
                step_bp += post_steps.get(t, 0.0)

            o = px
            px = px * (1.0 + step_bp / 1e4)
            c = px
            hi = max(o, c) * 1.00004
            lo = min(o, c) * 0.99996
            rows.append((t, round(o, digits), round(hi, digits), round(lo, digits),
                         round(c, digits), int(tv)))
            t += els.SLOT_SECONDS

        with open(tmpdir / ("%s_M5.csv" % sym), "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f, lineterminator="\n")
            w.writerow(["time", "open", "high", "low", "close", "tickvol"])
            for r in rows:
                w.writerow(list(r))


def _build_calendar(path: Path):
    rows = []
    for u, big, sign in _usd_releases():
        stored = u + dt.timedelta(minutes=PLANTED_OFFSET_MIN)
        nfp = 200.0 + (60.0 * sign if big else 0.0)
        ur = 4.0 - (0.6 * sign if big else 0.0)
        # Average Hourly Earnings is planted with the OPPOSITE surprise sign, so
        # its direction contradicts NFP's on the identical price path.  The
        # sealed cluster rule must pick NFP (rank 2) over AHE (rank 15); a plain
        # row mean would rescale the observation by the 2:1 vote instead.
        ahe = 0.3 - (0.4 * sign if big else 0.0)
        rows.append([stored.strftime("%Y.%m.%d"), stored.strftime("%Y.%m.%d %H:%M"), "",
                     "USD", "High", "Non-Farm Employment Change",
                     "%.1fK" % nfp, "200.0K", "195.0K"])
        rows.append([stored.strftime("%Y.%m.%d"), stored.strftime("%Y.%m.%d %H:%M"), "",
                     "USD", "High", "Unemployment Rate",
                     "%.1f%%" % ur, "4.0%", "4.0%"])
        rows.append([stored.strftime("%Y.%m.%d"), stored.strftime("%Y.%m.%d %H:%M"), "",
                     "USD", "High", "Average Hourly Earnings m/m",
                     "%.2f%%" % ahe, "0.30%", "0.30%"])
    for i, (_sched, stored, _printed, _cls) in enumerate(_usd_defect_releases()):
        crs = 0.4 + (0.5 if i % 2 == 0 else -0.5)
        rows.append([stored.strftime("%Y.%m.%d"), stored.strftime("%Y.%m.%d %H:%M"), "",
                     "USD", "High", "Core Retail Sales m/m",
                     "%.1f%%" % crs, "0.4%", "0.4%"])
    for u, big, sign in _gbp_releases():
        rs = 0.5 + (0.6 * sign if big else 0.0)
        rows.append([u.strftime("%Y.%m.%d"), u.strftime("%Y.%m.%d %H:%M"), "",
                     "GBP", "High", "Retail Sales m/m", "%.1f%%" % rs, "0.5%", "0.4%"])
    rows.sort(key=lambda r: (r[1], r[3], r[5]))
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["Date", "DateTime_UTC", "DateTime_EET", "Currency", "Impact",
                    "Event", "Actual", "Forecast", "Previous"])
        for r in rows:
            w.writerow(r)
    return str(path)


@pytest.fixture(scope="module")
def fixture_env(tmp_path_factory):
    root = tmp_path_factory.mktemp("edge_lab_fixture")
    bars_dir = root / "bars"
    bars_dir.mkdir()
    _build_bars(bars_dir)
    cal = _build_calendar(root / "calendar.csv")
    return {"root": root, "bars_dir": str(bars_dir), "calendar": cal}


def _run(env, out: str, extra=None, hypothesis="both"):
    argv = ["--hypothesis", hypothesis, "--bars-dir", env["bars_dir"],
            "--calendar", env["calendar"], "--out", out,
            "--now-utc", "2026-09-04T20:45:00Z",
            "--is-start", IS_START, "--is-end", IS_END,
            "--oos-start", OOS_START, "--oos-end", OOS_END,
            "--calib-max-offset-min", str(CALIB_GRID_MIN),
            "--calib-min-obs", "20",
            "--calib-year-lo", "2018", "--calib-year-hi", "2020"]
    if extra:
        argv += extra
    assert els.main(argv) == 0
    return out


@pytest.fixture(scope="module")
def run_out(fixture_env, tmp_path_factory):
    return _run(fixture_env, str(tmp_path_factory.mktemp("edge_lab_run")))


def _read_csv(path):
    with open(path, "r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def _summary(run_out, hyp):
    with open(os.path.join(run_out, hyp, "summary.json"), encoding="utf-8") as f:
        return json.load(f)


# ===========================================================================
# Stage 0: timestamp calibration
# ===========================================================================

def test_stage0_recovers_planted_offset_and_leaves_correct_family_alone(run_out):
    rows = _read_csv(os.path.join(run_out, "EDGE-1", "calibration.csv"))
    by = {(r["currency"], r["event"]): r for r in rows}
    nfp = by[("USD", "Non-Farm Employment Change")]
    assert nfp["calib_status"] == "CALIBRATED", nfp
    assert int(nfp["applied_offset_min"]) == -PLANTED_OFFSET_MIN == 1020
    assert float(nfp["peak_ratio"]) > 2.0
    assert float(nfp["offset_stability_frac"]) >= 0.60
    # a second row describing the SAME instant must recover the SAME offset
    assert int(by[("USD", "Unemployment Rate")]["applied_offset_min"]) == 1020
    # the family whose timestamps are already correct must calibrate to 0
    rs = by[("GBP", "Retail Sales m/m")]
    assert rs["calib_status"] == "CALIBRATED", rs
    assert int(rs["applied_offset_min"]) == 0


def test_stage0_is_fail_closed_on_a_group_with_no_volume_signature(fixture_env, tmp_path):
    """A family planted where nothing happens must be excluded, not guessed."""
    src = _read_csv(fixture_env["calendar"])
    extra = [{"Date": u.strftime("%Y.%m.%d"),
              "DateTime_UTC": u.strftime("%Y.%m.%d %H:%M"), "DateTime_EET": "",
              "Currency": "USD", "Impact": "High", "Event": "CPI m/m",
              "Actual": "0.3%", "Forecast": "0.2%", "Previous": "0.2%"}
             for u in _weekly_utc(SYNTH_START, SYNTH_END, 1, 3, 5)]
    allrows = src + extra
    allrows.sort(key=lambda r: (r["DateTime_UTC"], r["Currency"], r["Event"]))
    cal = tmp_path / "cal.csv"
    with open(cal, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(src[0].keys()), lineterminator="\n")
        w.writeheader()
        w.writerows(allrows)
    out = str(tmp_path / "out")
    env2 = dict(fixture_env)
    env2["calendar"] = str(cal)
    _run(env2, out, extra=["--no-baseline-rows"], hypothesis="EDGE-1")
    rows = _read_csv(os.path.join(out, "EDGE-1", "calibration.csv"))
    cpi = [r for r in rows if r["event"] == "CPI m/m"][0]
    assert cpi["calib_status"] in ("NO_SIGNATURE", "AMBIGUOUS"), cpi
    assert cpi["applied_offset_min"] == ""
    ev = _read_csv(os.path.join(out, "EDGE-1", "events.csv"))
    assert not [r for r in ev if r["event"] == "CPI m/m"], \
        "a non-calibrated group must be excluded from EDGE-1 entirely"


# ===========================================================================
# Event alignment: no look-ahead
# ===========================================================================

def test_entry_bar_never_precedes_release_plus_delay(run_out):
    ev = {r["event_id"]: r for r in _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))}
    ew = _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
    assert ew
    for r in ew:
        e = ev[r["event_id"]]
        rel = dt.datetime.strptime(e["release_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)
        exact = els.utc_to_broker_epoch(rel)
        delay = int(r["entry_delay_min"])
        entry = int(r["entry_bar_epoch"])
        assert entry >= exact + delay * 60, "look-ahead: entry before release+delay"
        lag = int(r["entry_lag_sec"])
        assert lag == entry - (exact + delay * 60)
        assert lag >= 0, "entry lag must never be negative"
        if r["window_ok"] == "1":
            assert lag < els.SLOT_SECONDS


def test_release_broker_epoch_matches_the_calibrated_utc_instant(run_out):
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    assert ev
    for r in ev:
        raw = dt.datetime.strptime(r["raw_datetime_utc"], "%Y.%m.%d %H:%M").replace(tzinfo=UTC)
        rel = raw + dt.timedelta(minutes=int(r["applied_offset_min"]))
        assert r["release_utc"] == rel.strftime("%Y-%m-%dT%H:%M:%SZ")
        assert int(r["release_broker_epoch"]) == els.utc_to_broker_epoch(rel)
        assert int(r["us_dst"]) == (1 if els.is_us_dst(rel) else 0)


def test_atr_window_ends_strictly_before_the_release(fixture_env, run_out):
    """The ATR that scales the event must not see the release bar."""
    series = els.BarSeries("EURUSD.DWX",
                           os.path.join(fixture_env["bars_dir"], "EURUSD.DWX_M5.csv"))
    ew = [r for r in _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
          if r["symbol"] == "EURUSD.DWX" and r["window_ok"] == "1"][:80]
    ev = {r["event_id"]: r for r in _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))}
    assert ew
    for r in ew:
        rel = int(ev[r["event_id"]]["release_broker_epoch"])
        rslot = series.slot_floor(rel)
        expect = series.atr14[rslot - 1]
        got = float(r["atr_m5_bp"]) * float(r["entry_price"]) / 1e4
        assert got == pytest.approx(expect, rel=1e-9)
        # the release bar itself must NOT be inside the ATR window
        assert series.epoch_of(rslot - 1) < rel


def test_planted_edge1_drift_is_recovered_with_the_right_sign(run_out):
    s = _summary(run_out, "EDGE-1")
    prim = s["primary_cell_result"]
    assert prim["n_eff"] > 20, prim
    # the drift is injected in the trade direction, so the effect must be
    # positive on both legs and of the planted order of magnitude
    assert prim["effect_bp"] > 0, prim
    assert prim["effect_bp"] == pytest.approx(PLANTED_DRIFT_BP * 17.0 / 18.0, rel=0.45)
    for sym, blk in prim["per_symbol"].items():
        if blk["effect_bp"] is not None and blk["n_eff"] > 5:
            assert blk["effect_bp"] > 0, (sym, blk)


def test_no_polarity_means_excluded_not_defaulted(run_out):
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    ids_with_dir = {r["event_id"] for r in ev if r["direction"] != ""}
    ew_ids = {r["event_id"] for r in _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))}
    assert ew_ids <= ids_with_dir
    for r in ev:
        if r["polarity"] == "":
            assert r["direction"] == ""


def test_surprise_z_needs_enough_history(run_out):
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    for r in ev:
        if r["surprise_z"] != "":
            assert int(r["surprise_n_3y"]) >= els.EDGE1_SURPRISE_MIN_HISTORY
            assert float(r["surprise_sd_3y"]) > 0
        if r["surprise_n_3y"] != "" and int(r["surprise_n_3y"]) < els.EDGE1_SURPRISE_MIN_HISTORY:
            assert r["surprise_z"] == ""


# ===========================================================================
# Baseline sampling
# ===========================================================================

def test_baseline_is_is_only_and_news_free(run_out):
    cells = _read_csv(os.path.join(run_out, "EDGE-1", "baseline_cells.csv"))
    assert cells
    assert {r["era"] for r in cells} == {"IS"}
    rows = _read_csv(os.path.join(run_out, "EDGE-1", "baseline.csv"))
    assert rows
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    instants = sorted({int(r["release_broker_epoch"]) for r in ev})
    halo = els.EDGE1_BASELINE_NEWS_EXCL_MIN * 60
    for r in rows[::17]:
        b = int(r["bar_epoch"])
        i = bisect.bisect_left(instants, b - halo)
        j = bisect.bisect_right(instants, b + halo)
        assert j == i, "baseline anchor sits inside a news halo"
        assert 2018 <= dt.datetime.utcfromtimestamp(b).year <= 2019


def test_baseline_cell_key_matches_the_anchor_clock_fields(run_out):
    rows = _read_csv(os.path.join(run_out, "EDGE-1", "baseline.csv"))
    for r in rows[::23]:
        b = int(r["bar_epoch"])
        assert int(r["weekday"]) == els.broker_weekday(b)
        assert int(r["broker_hour"]) == els.broker_hour(b)
        assert int(r["minute_of_hour"]) == els.broker_minute(b)


def test_every_used_event_cell_has_a_baseline_cell(run_out):
    cells = {(r["symbol"], int(r["weekday"]), int(r["broker_hour"]), int(r["minute_of_hour"]))
             for r in _read_csv(os.path.join(run_out, "EDGE-1", "baseline_cells.csv"))}
    used = {(r["symbol"], int(r["weekday"]), int(r["broker_hour"]), int(r["minute_of_hour"]))
            for r in _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
            if r["window_ok"] == "1"}
    assert used
    assert used <= cells


def test_baseline_cell_means_match_a_naive_recomputation(run_out):
    rows = _read_csv(os.path.join(run_out, "EDGE-1", "baseline.csv"))
    cells = _read_csv(os.path.join(run_out, "EDGE-1", "baseline_cells.csv"))
    buckets = {}
    for r in rows:
        k = (r["symbol"], r["weekday"], r["broker_hour"], r["minute_of_hour"])
        buckets.setdefault(k, []).append(float(r["ret_p90"]))
    checked = 0
    for c in cells:
        k = (c["symbol"], c["weekday"], c["broker_hour"], c["minute_of_hour"])
        xs = buckets.get(k)
        if not xs:
            continue
        assert int(c["n"]) == len(xs)
        # Each per-row value in the CSV is rounded to 10 significant digits
        # (%.10g), so re-summing them accumulates ~1e-10 of drift per row.  The
        # tolerance sits above that noise floor and far below any real defect
        # (a wrong cell key moves the mean by orders of 1).
        assert float(c["mu0_p90_bp"]) == pytest.approx(els._mean(xs), rel=1e-6, abs=1e-8)
        assert float(c["sigma0_p90_bp"]) == pytest.approx(
            math.sqrt(els._pvar(xs)), rel=1e-6, abs=1e-8)
        checked += 1
    assert checked > 0


# ===========================================================================
# statistic wiring on the real outputs
# ===========================================================================

def test_edge1_effect_sigma_and_t_are_consistent(run_out):
    s = _summary(run_out, "EDGE-1")
    for c in s["cells"]:
        if c["effect_sigma"] is None or not c["sigma0_bp"]:
            continue
        assert c["effect_sigma"] == pytest.approx(c["effect_bp"] / c["sigma0_bp"], rel=1e-9)
        if c["se_cluster_bp"]:
            assert c["t_stat"] == pytest.approx(c["effect_bp"] / c["se_cluster_bp"], rel=1e-9)


def test_edge1_grid_is_exactly_the_declared_trial_count(run_out):
    s = _summary(run_out, "EDGE-1")
    assert len(s["cells"]) == els.EDGE1_DECLARED_TRIALS == 36
    assert s["rule_seal"]["declared_trial_count"] == 36
    assert s["fragility"]["cells_total"] == 36
    seen = {(c["surprise_z_threshold"], c["entry_delay_min"], c["holding_min"]) for c in s["cells"]}
    assert len(seen) == 36


def test_underpowered_is_never_reported_as_dead(run_out):
    s = _summary(run_out, "EDGE-1")
    for c in s["cells"]:
        if c["n_eff"] < els.EDGE1_N_EFF_FLOOR:
            assert c["status"] == "UNDERPOWERED"
    if s["primary_cell_result"]["n_eff"] < els.EDGE1_N_EFF_FLOOR:
        assert s["verdict"] == "UNDERPOWERED"


def test_cluster_aggregation_collapses_same_instant_rows(run_out):
    """Two calendar rows describing one release are ONE observation."""
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    usd = [r for r in ev if r["currency"] == "USD"]
    assert usd
    by_cluster = {}
    for r in usd:
        by_cluster.setdefault(r["cluster_id"], set()).add(r["event"])
    multi = [k for k, v in by_cluster.items() if len(v) > 1]
    assert multi, "fixture must contain simultaneous same-currency releases"
    s = _summary(run_out, "EDGE-1")
    prim = s["primary_cell_result"]
    assert prim["n_eff"] < prim["n_rows"], "n_eff must be clusters, not symbol rows"


# ===========================================================================
# EDGE-3
# ===========================================================================

def test_edge3_arms_and_dst_regime_labels(run_out):
    rows = _read_csv(os.path.join(run_out, "EDGE-3", "fix_days.csv"))
    assert rows
    arms = {(r["symbol"], r["fix_code"], r["arm_role"]) for r in rows}
    assert ("XAUUSD.DWX", "LDN_PM_1500", "CANDIDATE") in arms
    assert ("EURUSD.DWX", "WMR_1600", "CANDIDATE") in arms
    assert ("XAUUSD.DWX", "LDN_AM_1030", "NEGATIVE_CONTROL") in arms
    for r in rows[::37]:
        d = dt.date.fromisoformat(r["date_london"])
        u = els.london_local_to_utc(d, *els.EDGE3_FIXES[r["fix_code"]])
        assert r["fix_utc"] == u.strftime("%Y-%m-%dT%H:%M:%SZ")
        assert int(r["fix_broker_epoch"]) == els.utc_to_broker_epoch(u)
        assert int(r["uk_dst"]) == (1 if els.is_uk_dst(u) else 0)
        assert int(r["us_dst"]) == (1 if els.is_us_dst(u) else 0)
        assert r["dst_regime"] == ("ALIGNED" if r["uk_dst"] == r["us_dst"] else "MISMATCH")
    assert {r["dst_regime"] for r in rows} == {"ALIGNED", "MISMATCH"}


def test_edge3_planted_reversion_is_recovered_only_on_the_planted_arm(run_out):
    s = _summary(run_out, "EDGE-3")
    arms = {a["arm_id"]: a for a in s["arms"]}
    pm = arms["XAUUSD.DWX|LDN_PM_1500"]["primary_cell_result"]
    assert pm["n_trigger"] > 50, pm
    assert pm["r_fix_atr"] > 0.10, pm
    assert pm["r_excess_atr"] > 0.05, pm
    ctl = arms["XAUUSD.DWX|LDN_AM_1030"]["primary_cell_result"]
    if ctl["r_excess_atr"] is not None:
        assert abs(ctl["r_excess_atr"]) < abs(pm["r_excess_atr"]), \
            "the negative control must not carry the planted effect"


def test_edge3_signal_convention_is_reversion(run_out):
    """ret_h_atr is stored unsigned; the arm statistic signs it -sign(premove)."""
    rows = [r for r in _read_csv(os.path.join(run_out, "EDGE-3", "fix_days.csv"))
            if r["symbol"] == "XAUUSD.DWX" and r["fix_code"] == "LDN_PM_1500"
            and r["day_ok"] == "1" and r["prefix_window_min"] == "30"]
    assert rows
    pos = [r for r in rows if float(r["premove_norm"]) > 0.6]
    neg = [r for r in rows if float(r["premove_norm"]) < -0.6]
    assert pos and neg
    # the fixture reverts, so a positive pre-move is followed by a negative
    # 45-min return and vice versa
    assert els._mean([float(r["ret_45_atr"]) for r in pos]) < 0
    assert els._mean([float(r["ret_45_atr"]) for r in neg]) > 0


def test_edge3_atr_is_none_when_a_constituent_m5_bar_is_missing(fixture_env):
    series = els.BarSeries("EURUSD.DWX",
                           os.path.join(fixture_env["bars_dir"], "EURUSD.DWX_M5.csv"))
    good = None
    for s in range(1000, series.n):
        if els._atr_m30(series, s) is not None:
            good = s
            break
    assert good is not None
    series.present[good - 10] = False
    series.atr30_cache.clear()
    assert els._atr_m30(series, good) is None, "ATR must never bridge a missing bar"
    series.present[good - 10] = True
    series.atr30_cache.clear()
    assert els._atr_m30(series, good) is not None


def test_session_gap_index_flags_weekends(fixture_env):
    series = els.BarSeries("XAUUSD.DWX",
                           os.path.join(fixture_env["bars_dir"], "XAUUSD.DWX_M5.csv"))
    bad = sum(1 for s in range(500, min(series.n, 20000)) if not series.session_intact(s, s + 24))
    assert bad > 0, "the fixture must contain weekend gaps"
    # and a mid-week window must be intact
    ok = sum(1 for s in range(500, min(series.n, 20000)) if series.session_intact(s, s + 24))
    assert ok > bad


def test_edge3_declared_trials_and_cells(run_out):
    s = _summary(run_out, "EDGE-3")
    assert s["rule_seal"]["declared_trial_count"] == 108 == els.EDGE3_DECLARED_TRIALS
    for a in s["arms"]:
        assert len(a["cells"]) == 36


def test_edge3_negative_control_never_gets_a_candidate_verdict(run_out):
    s = _summary(run_out, "EDGE-3")
    ctl = [a for a in s["arms"] if a["arm_role"] == "NEGATIVE_CONTROL"][0]
    assert ctl["verdict"] == "NEGATIVE_CONTROL"
    assert s["negative_control"]["void_threshold"] == 0.10


def test_edge3_news_coverage_gate_is_applied(run_out):
    rows = _read_csv(os.path.join(run_out, "EDGE-3", "fix_days.csv"))
    for r in rows:
        if r["day_ok"] == "1":
            assert r["news_coverage_ok"] == "1", \
                "day_ok must not pass outside the calendar's covered span"


# ===========================================================================
# Determinism and manifest hashing
# ===========================================================================

def test_two_runs_are_byte_identical(fixture_env, tmp_path):
    a = _run(fixture_env, str(tmp_path / "a"), extra=["--no-baseline-rows"])
    b = _run(fixture_env, str(tmp_path / "b"), extra=["--no-baseline-rows"])
    names = []
    for hyp in ("EDGE-1", "EDGE-3"):
        for fn in sorted(os.listdir(os.path.join(a, hyp))):
            names.append(os.path.join(hyp, fn))
    assert names
    for rel in names:
        pa, pb = os.path.join(a, rel), os.path.join(b, rel)
        assert os.path.exists(pb), rel
        if rel.endswith("manifest.json"):
            # the manifest records the --out root it was written into, which is
            # deliberately different here; everything else must be identical
            with open(pa, encoding="utf-8") as f:
                ta = f.read().replace(a.replace("\\", "/"), "<OUT>").replace(a, "<OUT>")
            with open(pb, encoding="utf-8") as f:
                tb = f.read().replace(b.replace("\\", "/"), "<OUT>").replace(b, "<OUT>")
            assert ta == tb, "non-deterministic manifest: %s" % rel
            continue
        assert filecmp.cmp(pa, pb, shallow=False), "non-deterministic output: %s" % rel


def test_manifest_hashes_match_the_files_on_disk(run_out):
    for hyp in ("EDGE-1", "EDGE-3"):
        with open(os.path.join(run_out, hyp, "manifest.json"), encoding="utf-8") as f:
            man = json.load(f)
        assert man["schema_version"] == els.MANIFEST_SCHEMA
        assert man["determinism"]["rng_used"] is False
        assert man["constraints_honoured"]["registry_unmodified"] is True
        assert man["outputs"]
        for o in man["outputs"]:
            # r3: `path` is relative to the --out root, `abs_path` is provenance
            assert not os.path.isabs(o["path"]), o["path"]
            assert os.path.exists(o["abs_path"]), o["abs_path"]
            assert (os.path.abspath(os.path.join(man["out_root"], o["path"]))
                    == os.path.abspath(o["abs_path"])), o["path"]
            assert els.sha256_file(o["abs_path"]) == o["sha256"], o["path"]
            if o["rows"] is not None and not o["path"].endswith(".gz"):
                with open(o["abs_path"], "r", encoding="utf-8", newline="") as f:
                    assert sum(1 for _ in f) - 1 == o["rows"], o["path"]
        for inp in man["inputs"]:
            assert os.path.exists(inp["path"]), inp["path"]
            assert els.sha256_file(inp["path"]) == inp["sha256"], inp["path"]
        assert man["code"]["file_sha256"] == els.sha256_file(os.path.abspath(els.__file__))


def test_manifest_records_an_lf_normalised_hash_for_repo_text(run_out, tmp_path):
    """CRLF checkouts must not change the recorded identity of a repo file."""
    crlf = tmp_path / "crlf.json"
    lf = tmp_path / "lf.json"
    body = b'{\n  "a": 1,\n  "b": 2\n}\n'
    lf.write_bytes(body)
    crlf.write_bytes(body.replace(b"\n", b"\r\n"))
    assert els.sha256_file(str(crlf)) != els.sha256_file(str(lf))
    assert els.sha256_file_lf(str(crlf)) == els.sha256_file_lf(str(lf)) == els.sha256_file(str(lf))
    with open(os.path.join(run_out, "EDGE-1", "manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    assert man["code"]["file_sha256_lf"]
    cost = [i for i in man["inputs"] if i["role"] == "cost_registry"]
    if cost:
        assert cost[0]["sha256_lf"] == els.sha256_file_lf(cost[0]["path"])


def test_manifest_seal_is_false_on_a_dirty_tree(run_out):
    with open(os.path.join(run_out, "EDGE-1", "manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    if man["code"]["git_dirty"]:
        assert man["rule_seal"]["sealed_before_measurement"] is False


def test_manifest_records_input_period_in_both_time_bases(run_out):
    with open(os.path.join(run_out, "EDGE-1", "manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    bars = [i for i in man["inputs"] if i["role"] == "bars"]
    assert bars
    for b in bars:
        assert b["time_base"].startswith("broker_naive_epoch")
        assert b["price_side"] == "bid"
        assert b["period_first_utc"].endswith("Z")
        assert b["period_first_broker"] != b["period_first_utc"].rstrip("Z")
    cal = [i for i in man["inputs"] if i["role"] == "calendar"][0]
    assert cal["datetime_eet_used"] is False
    assert cal["timestamps_calibrated"] is True
    assert cal["known_at_utc_available"] is False


def test_summary_declares_the_unmodellable_things(run_out):
    for hyp in ("EDGE-1", "EDGE-3"):
        s = _summary(run_out, hyp)
        assert s["resolution"]["spread_modelled"] is False
        assert s["resolution"]["stops_measurable"] is False
        assert s["resolution"]["mae_mfe_is_envelope"] is True
        assert s["resolution"]["tick_data_used"] is False
        assert s["cost_anchor"]["spread_excluded"] is True
        assert s["open_gaps"]
        assert s["deviations_from_spec"]
        assert s["refutation_statistic"]


# ===========================================================================
# r2 -- STAGE 0b: per-EVENT instant verification
#
# The r1 fixture planted a PURE CONSTANT displacement on a PURE CONSTANT-UTC
# release schedule, which makes one group offset exact by construction: no
# assertion could ever fail on the production failure mode.  The fixture now
# plants (a) a real schedule fixed in home local time, and (b) a defect family
# whose stored displacement follows a rule of its OWN, so a single group
# constant is right for most rows and an hour late for the rest.
# ===========================================================================

def _defect_key():
    return ("USD", "Core Retail Sales m/m")


def test_stage0_voids_the_dst_seasonal_displacement(run_out):
    """A group constant that misplaces a minority of its rows must VOID them."""
    calib = {(r["currency"], r["event"]): r
             for r in _read_csv(os.path.join(run_out, "EDGE-1", "calibration.csv"))}
    d = calib[_defect_key()]
    assert d["calib_status"] == "CALIBRATED", d
    assert int(d["applied_offset_min"]) == DEFECT_MODAL_OFFSET_MIN
    assert int(d["n_voided_home_clock"]) > 0, d
    assert int(d["n_voided_local_peak"]) > 0, d
    assert 0.5 <= float(d["verified_frac"]) < 1.0, d

    ev = [r for r in _read_csv(os.path.join(run_out, "EDGE-1", "calibration_events.csv"))
          if (r["currency"], r["event"]) == _defect_key()]
    assert ev
    by_reason = {}
    for r in ev:
        by_reason.setdefault(r["void_reason"], []).append(r)
    assert "home_clock_mismatch" in by_reason
    assert "local_peak_elsewhere" in by_reason
    # gate A fires exactly on the months the calendar displaces differently
    for r in by_reason["home_clock_mismatch"]:
        rel = dt.datetime.strptime(r["release_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)
        sched = rel - dt.timedelta(hours=1)
        assert sched.month in DEFECT_SHORT_MONTHS, r
        assert r["home_local_hhmm"] != r["modal_home_local_hhmm"]
    # gate B fires on the month where the stamp is right but the print was late
    for r in by_reason["local_peak_elsewhere"]:
        rel = dt.datetime.strptime(r["release_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)
        assert rel.month == DEFECT_LATE_PRINT_MONTH, r
        assert r["home_local_hhmm"] == r["modal_home_local_hhmm"]
        assert int(r["local_peak_offset_min"]) == DEFECT_LATE_PRINT_MIN, r


def test_a_voided_instant_never_reaches_the_measurement(run_out):
    voided = {(r["currency"], r["event"], r["raw_datetime_utc"])
              for r in _read_csv(os.path.join(run_out, "EDGE-1", "calibration_events.csv"))
              if r["instant_verified"] == "0"}
    assert voided
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    ids_voided = set()
    for r in ev:
        k = (r["currency"], r["event"], r["raw_datetime_utc"])
        if k in voided:
            assert r["instant_verified"] == "0", r
            assert r["direction"] == "", "a voided instant must never carry a direction"
            ids_voided.add(r["event_id"])
    assert ids_voided
    ew_ids = {r["event_id"] for r in
              _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))}
    assert not (ids_voided & ew_ids), "a voided instant leaked into event_windows"


def test_every_verified_instant_lands_on_one_home_wall_clock_per_group(run_out):
    """The check that exposes a misplaced release: one group, one local time."""
    rows = _read_csv(os.path.join(run_out, "EDGE-1", "calibration_events.csv"))
    assert rows
    per_group = {}
    for r in rows:
        if r["instant_verified"] != "1":
            continue
        per_group.setdefault((r["currency"], r["event"]), set()).add(r["home_local_hhmm"])
    assert per_group
    for key, clocks in sorted(per_group.items()):
        assert len(clocks) == 1, (key, clocks)
    # and the recovered local time is the real one the fixture planted
    assert per_group[("USD", "Non-Farm Employment Change")] == {"08:30"}
    assert per_group[_defect_key()] == {"14:30"}
    assert per_group[("GBP", "Retail Sales m/m")] == {"09:00"}


def test_home_timezone_rule_tracks_the_right_dst_regime():
    # US Eastern follows the US rule: 2023-03-14 is already EDT
    u = dt.datetime(2023, 3, 14, 12, 30, tzinfo=UTC)
    assert els.home_tz_offset_hours("USD", u) == -4
    assert els.home_local_minute_of_day("USD", u) == 8 * 60 + 30
    # ... while Europe/London is still on GMT on that date (EU switches 03-26)
    assert els.home_tz_offset_hours("GBP", u) == 0
    # and in November the US is still on DST after the EU has left it
    u2 = dt.datetime(2022, 11, 2, 12, 30, tzinfo=UTC)
    assert els.home_tz_offset_hours("USD", u2) == -4
    assert els.home_tz_offset_hours("EUR", u2) == 1
    assert els.fmt_hhmm(els.home_local_minute_of_day("USD", u2)) == "08:30"


# ===========================================================================
# r2 -- Stage 0 probes in the SAME clock space EDGE-1 measures in
# ===========================================================================

def test_stage0_offset_grid_is_probed_in_utc_space(run_out):
    """A UTC-space shift and a broker-space shift are not the same instant."""
    for y in range(2018, 2026):
        s, e = els.us_dst_interval_utc(y)
        for u in (s - dt.timedelta(hours=2), s, s + dt.timedelta(hours=2),
                  e - dt.timedelta(hours=2), e, e + dt.timedelta(hours=2),
                  dt.datetime(y, 6, 15, 12, tzinfo=UTC)):
            ue = _calendar.timegm(u.timetuple())
            assert els.utc_epoch_to_broker_epoch(ue) == els.utc_to_broker_epoch(u), (y, u)
            assert els.is_us_dst_epoch(ue) == els.is_us_dst(u)
    # the two spaces genuinely disagree across a boundary -- so the choice matters
    raw = dt.datetime(2023, 3, 11, 20, 0, tzinfo=UTC)      # Sat, US DST starts 03-12
    off = 1020
    utc_space = els.utc_to_broker_epoch(raw + dt.timedelta(minutes=off))
    broker_space = els.utc_to_broker_epoch(raw) + off * 60
    assert utc_space - broker_space == 3600
    # and every emitted event uses the UTC-space instant
    for r in _read_csv(os.path.join(run_out, "EDGE-1", "events.csv")):
        rawu = dt.datetime.strptime(r["raw_datetime_utc"], "%Y.%m.%d %H:%M").replace(tzinfo=UTC)
        rel = rawu + dt.timedelta(minutes=int(r["applied_offset_min"]))
        assert int(r["release_broker_epoch"]) == els.utc_to_broker_epoch(rel)
        assert int(r["release_broker_epoch"]) == \
            els.utc_epoch_to_broker_epoch(_calendar.timegm(rel.timetuple()))


# ===========================================================================
# r2 -- surprise history seeding
# ===========================================================================

def test_surprise_history_block_is_emitted(run_out):
    s = _summary(run_out, "EDGE-1")
    sh = s["surprise_history"]
    assert sh["window_days"] == els.EDGE1_SURPRISE_WINDOW_DAYS
    assert sh["min_history"] == els.EDGE1_SURPRISE_MIN_HISTORY
    assert sh["n_hist_min"] is not None
    assert sh["n_hist_min"] >= sh["min_history"]
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    for r in ev:
        if r["surprise_z"] != "":
            assert int(r["surprise_n_3y"]) >= els.EDGE1_SURPRISE_MIN_HISTORY


def test_history_seed_rows_before_is_start_are_counted_and_not_measured(fixture_env, tmp_path):
    """Shrinking the study window must SEED, not discard, the earlier rows."""
    out = str(tmp_path / "seeded")
    argv = ["--hypothesis", "EDGE-1", "--bars-dir", fixture_env["bars_dir"],
            "--calendar", fixture_env["calendar"], "--out", out,
            "--now-utc", "2026-09-04T20:45:00Z",
            "--is-start", "2019-01-01", "--is-end", "2019-12-31",
            "--oos-start", "2020-01-01", "--oos-end", "2020-12-31",
            "--calib-max-offset-min", str(CALIB_GRID_MIN), "--calib-min-obs", "20",
            "--calib-year-lo", "2018", "--calib-year-hi", "2020",
            "--no-baseline-rows"]
    assert els.main(argv) == 0
    s = _summary(out, "EDGE-1")
    assert s["surprise_history"]["seed_rows_before_is_start"] > 0
    ev = _read_csv(os.path.join(out, "EDGE-1", "events.csv"))
    assert ev
    assert min(int(r["year"]) for r in ev) == 2019, "seed rows must not be measured"
    # the FIRST study year now has usable z values, because 2018 seeded the history
    y19 = [r for r in ev
           if r["year"] == "2019" and r["event"] == "Non-Farm Employment Change"]
    assert y19
    assert sum(1 for r in y19 if r["surprise_z"] != "") >= len(y19) - 1, \
        "the first study year must be usable once the history is seeded"


# ===========================================================================
# r2 -- cluster direction resolution
# ===========================================================================

def test_cluster_direction_is_resolved_not_averaged(run_out):
    """Two rows on one bar with opposite directions must not be averaged."""
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    by_cluster = {}
    for r in ev:
        if r["direction"] == "":
            continue
        by_cluster.setdefault(r["cluster_id"], []).append(r)
    contradictory = [c for c in by_cluster.values()
                     if len({r["direction"] for r in c}) > 1]
    assert contradictory, "the fixture must contain a direction conflict on one bar"
    for members in contradictory:
        prim = [r for r in members if r["cluster_is_primary"] == "1"]
        assert len(prim) == 1, members
        assert {r["cluster_direction"] for r in members} == {prim[0]["direction"]}
        assert int(prim[0]["cluster_rank"]) == min(
            int(r["cluster_rank"]) for r in members if r["cluster_rank"] != "")
    # and on the clusters where every member is usable, the sealed rank picks NFP
    full = [c for c in contradictory
            if {r["event"] for r in c} >= {"Non-Farm Employment Change",
                                           "Average Hourly Earnings m/m"}]
    assert full, "the fixture must contain a fully-populated conflicting cluster"
    for members in full:
        prim = [r for r in members if r["cluster_is_primary"] == "1"][0]
        assert prim["event"] == "Non-Farm Employment Change", members


def test_cluster_direction_rule_changes_the_headline_and_is_disclosed(run_out):
    s = _summary(run_out, "EDGE-1")
    sens = {c["dir_rule"]: c for c in s["cluster_direction_sensitivity"]}
    assert set(sens) == set(els.EDGE1_DIR_RULES)
    assert sens[els.EDGE1_DIR_RULE_PRIMARY]["sealed"] is True
    assert s["rule_seal"]["cluster_direction_rule"] == els.EDGE1_DIR_RULE_PRIMARY
    # the planted drift follows NFP; averaging the rows dilutes it, so the
    # sealed rule must recover a strictly larger magnitude than row_mean
    a = sens["primary_event_rank"]["effect_bp_is"]
    b = sens["row_mean"]["effect_bp_is"]
    assert a is not None and b is not None
    assert abs(a) > abs(b), (a, b)
    assert s["primary_cell_result"]["effect_bp"] == pytest.approx(a, rel=1e-12)


def test_event_window_rows_carry_both_directions(run_out):
    ew = _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
    assert ew
    seen_diff = False
    for r in ew:
        assert int(r["trade_dir"]) in (-1, 1)
        for h in els.EDGE1_HORIZONS:
            if r["ret_p%d" % h] == "":
                continue
            assert float(r["ret_p%d" % h]) == pytest.approx(
                float(r["ret_raw_p%d" % h]) * int(r["trade_dir"]), rel=1e-9, abs=1e-12)
        if r["cluster_trade_dir"] == "":
            continue
        assert int(r["cluster_trade_dir"]) in (-1, 1)
        if r["cluster_trade_dir"] != r["trade_dir"]:
            seen_diff = True
    assert seen_diff, "the fixture must exercise a cluster whose direction overrides a row"


# ===========================================================================
# r2 -- frequency counts trades, not calendar rows
# ===========================================================================

def test_frequency_counts_distinct_entry_bars(run_out):
    s = _summary(run_out, "EDGE-1")
    freq = s["frequency"]
    assert "tradeable_entries_per_symbol_year" in freq
    assert "triggers_per_symbol_year" not in freq
    ew = _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
    ev = {r["event_id"]: r for r in _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))}
    pd_ = els.EDGE1_PRIMARY_CELL["entry_delay_min"]
    years = int(IS_END[:4]) - int(IS_START[:4]) + 1
    for sym, rate in freq["tradeable_entries_per_symbol_year"].items():
        sel = [r for r in ew
               if r["symbol"] == sym and r["entry_delay_min"] == str(pd_)
               and r["window_ok"] == "1" and r["era"] == "IS"
               and ev[r["event_id"]]["is_confounded"] == "0"]
        bars_hit = {r["entry_bar_epoch"] for r in sel}
        # the published rate can never exceed the distinct-entry-bar rate
        assert rate <= len(bars_hit) / float(years) + 1e-9, sym
        assert rate <= freq["event_rows_per_symbol_year"][sym] + 1e-9, sym
    assert any(freq["event_rows_per_symbol_year"][k]
               > freq["tradeable_entries_per_symbol_year"][k]
               for k in freq["tradeable_entries_per_symbol_year"]), \
        "simultaneous releases must collapse to one entry bar"


# ===========================================================================
# r2 -- doc-literal results reported next to the strengthened ones
# ===========================================================================

def test_edge1_doc_literal_block_and_declared_additions(run_out):
    s = _summary(run_out, "EDGE-1")
    dl = s["doc_literal"]
    for k in ("effect_sigma_is", "n_clusters_is", "n_rows_is", "sigma_floor_met",
              "n_floor_met_clusters", "n_floor_met_rows", "holdout_sign_matches",
              "verdict"):
        assert k in dl, k
    assert dl["n_rows_is"] >= dl["n_clusters_is"]
    devs = " ".join(s["deviations_from_spec"])
    for needle in ("t_stat", "holdout floor", "fragility rule", "CLUSTERS",
                   "cluster-direction rule", "Stage 0b", "GBPJPY"):
        assert needle in devs, needle
    assert devs.count("NEEDS A SEAL") >= 5


def test_edge3_doc_literal_block_is_reported_per_arm(run_out):
    s = _summary(run_out, "EDGE-3")
    for a in s["arms"]:
        dl = a["doc_literal"]
        assert "r_fix_atr_is" in dl and "verdict" in dl
        assert a["primary_cell_result"]["status_doc_literal"] in (
            "SURVIVES_IS", "REFUTED", "UNDERPOWERED")
        assert a["primary_cell_result"]["verdict_basis"] in (
            "DOC_LITERAL_R_FIX", "R_EXCESS_STRENGTHENING_UNSEALED", "BOTH")
    devs = " ".join(s["deviations_from_spec"])
    assert "NEEDS A SEAL" in devs
    assert "CONFOUNDED WITH TIME OF DAY" in devs
    assert s["baseline_scopes"]["primary"] == "SESSION"


def test_program_doc_is_resolved_and_hashed_into_the_seal(run_out):
    for hyp in ("EDGE-1", "EDGE-3"):
        with open(os.path.join(run_out, hyp, "manifest.json"), encoding="utf-8") as f:
            man = json.load(f)
        seal = man["rule_seal"]
        if seal["doc_path"]:
            assert os.path.exists(seal["doc_path"])
            assert seal["doc_sha256"] == els.sha256_file(seal["doc_path"])
            assert seal["doc_sha256_lf"] == els.sha256_file_lf(seal["doc_path"])
            assert seal["doc_resolved_from"] in ("explicit", "repo_root", "canonical_repo")
        assert seal["cluster_rank_map_sha256"]


def test_explicit_program_doc_overrides_the_resolver(fixture_env, tmp_path):
    doc = tmp_path / "sealed.md"
    doc.write_text("# sealed rule\n", encoding="utf-8")
    out = str(tmp_path / "docrun")
    _run(fixture_env, out, extra=["--no-baseline-rows", "--program-doc", str(doc)],
         hypothesis="EDGE-1")
    with open(os.path.join(out, "EDGE-1", "manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    assert man["rule_seal"]["doc_resolved_from"] == "explicit"
    assert man["rule_seal"]["doc_sha256"] == els.sha256_file(str(doc))


# ===========================================================================
# r2 -- EDGE-3 MAE/MFE direction and arm statistic
# ===========================================================================

def test_edge3_mae_mfe_are_signed_by_the_fade_direction(run_out):
    rows = [r for r in _read_csv(os.path.join(run_out, "EDGE-3", "fix_days.csv"))
            if r["day_ok"] == "1" and r["mae_45_bp"] != ""]
    assert rows
    pos = [r for r in rows if float(r["premove_norm"]) > 0]
    neg = [r for r in rows if float(r["premove_norm"]) < 0]
    assert pos and neg
    for r in rows:
        tdir = -1 if float(r["premove_norm"]) > 0 else 1
        assert int(r["trade_dir"]) == tdir, r
        mae, mfe = float(r["mae_45_bp"]), float(r["mfe_45_bp"])
        assert mae <= 1e-12, r      # adverse excursion is never favourable
        assert mfe >= -1e-12, r
    assert any(int(r["trade_dir"]) == -1 for r in rows), \
        "a fade arm must contain short days"


def test_edge3_mae_mfe_direction_unit():
    """Directly: the same bar window signs opposite for a long and a short."""
    class _S(object):
        pass
    s = _S()
    s.n = 5
    s.high = [100.0, 102.0, 101.0, 100.5, 100.0]
    s.low = [99.0, 99.5, 98.0, 99.0, 99.5]
    long_mae, long_mfe = els._mae_mfe(s, 0, 100.0, 25, 1)
    short_mae, short_mfe = els._mae_mfe(s, 0, 100.0, 25, -1)
    assert long_mae == pytest.approx(1e4 * (98.0 - 100.0) / 100.0)
    assert long_mfe == pytest.approx(1e4 * (102.0 - 100.0) / 100.0)
    assert short_mae == pytest.approx(-long_mfe)
    assert short_mfe == pytest.approx(-long_mae)


def _edge3_recompute(run_out, symbol, code, pw, thr, hold, era, scope="SESSION",
                     bad_key=False):
    """Naive independent recomputation of the arm statistic from the CSVs."""
    fd = [r for r in _read_csv(os.path.join(run_out, "EDGE-3", "fix_days.csv"))
          if r["symbol"] == symbol and r["fix_code"] == code
          and r["prefix_window_min"] == str(pw) and r["era"] == era
          and r["day_ok"] == "1" and r["has_news"] == "0"]
    trig = [r for r in fd
            if abs(float(r["premove_norm"])) >= thr and float(r["premove_norm"]) != 0]
    vals = [(-1 if float(r["premove_norm"]) > 0 else 1) * float(r["ret_%d_atr" % hold])
            for r in trig]
    if not vals:
        return None
    cells = {}
    for c in _read_csv(os.path.join(run_out, "EDGE-3", "fix_baseline_cells.csv")):
        if c["scope"] != scope:
            continue
        k = (c["symbol"], c["fix_code"], int(c["weekday"]), int(c["minute_of_hour"]),
             int(c["prefix_window_min"]), float(c["threshold_atr"]), int(c["holding_min"]))
        cells[k] = (None if c["r_base_atr"] == "" else float(c["r_base_atr"]))
    diffs, bases = [], []
    for r, v in zip(trig, vals):
        wd = int(r["weekday"]) + (1 if bad_key else 0)
        k = (symbol, code, wd, int(r["minute_of_hour"]), pw, thr, hold)
        rb = cells.get(k)
        if rb is None:
            continue
        diffs.append(v - rb)
        bases.append(rb)
    out = {"n_days": len(fd), "n_trigger": len(trig), "r_fix": els._mean(vals)}
    if diffs:
        out["r_base"] = els._mean(bases)
        out["r_excess"] = els._mean(diffs)
        sd = math.sqrt(els._svar(diffs))
        out["se"] = sd / math.sqrt(len(diffs))
        out["t"] = out["r_excess"] / out["se"] if out["se"] else None
    return out


def test_edge3_arm_statistic_matches_a_naive_recomputation(run_out):
    s = _summary(run_out, "EDGE-3")
    ppw = els.EDGE3_PRIMARY_CELL["prefix_window_min"]
    pthr = els.EDGE3_PRIMARY_CELL["threshold_atr"]
    phold = els.EDGE3_PRIMARY_CELL["holding_min"]
    checked = 0
    for a in s["arms"]:
        prim = a["primary_cell_result"]
        if prim["r_fix_atr"] is None:
            continue
        got = _edge3_recompute(run_out, a["symbol"], a["fix_code"], ppw, pthr, phold, "IS")
        assert got is not None, a["arm_id"]
        assert got["n_days"] == prim["n_days_measured"], a["arm_id"]
        assert got["n_trigger"] == prim["n_trigger"], a["arm_id"]
        assert got["r_fix"] == pytest.approx(prim["r_fix_atr"], rel=1e-6, abs=1e-9)
        if "r_excess" in got and prim["r_excess_atr"] is not None:
            assert got["r_base"] == pytest.approx(prim["r_base_atr"], rel=1e-6, abs=1e-9)
            assert got["r_excess"] == pytest.approx(prim["r_excess_atr"], rel=1e-6, abs=1e-9)
            assert got["se"] == pytest.approx(prim["se"], rel=1e-6, abs=1e-9)
            assert got["t"] == pytest.approx(prim["t_stat"], rel=1e-6, abs=1e-9)
        got_all = _edge3_recompute(run_out, a["symbol"], a["fix_code"], ppw, pthr, phold,
                                   "IS", scope="ALL_HOURS")
        if got_all and "r_base" in got_all and prim["r_base_atr_all_hours"] is not None:
            assert got_all["r_base"] == pytest.approx(prim["r_base_atr_all_hours"],
                                                     rel=1e-6, abs=1e-9)
        checked += 1
    assert checked >= 2


def test_edge3_arm_statistic_join_key_is_load_bearing(run_out):
    """A deliberately wrong join key must NOT reproduce the published number."""
    s = _summary(run_out, "EDGE-3")
    ppw = els.EDGE3_PRIMARY_CELL["prefix_window_min"]
    pthr = els.EDGE3_PRIMARY_CELL["threshold_atr"]
    phold = els.EDGE3_PRIMARY_CELL["holding_min"]
    cands = [x for x in s["arms"] if x["primary_cell_result"]["r_excess_atr"] is not None]
    assert cands
    a = cands[0]
    bad = _edge3_recompute(run_out, a["symbol"], a["fix_code"], ppw, pthr, phold, "IS",
                           bad_key=True)
    good = a["primary_cell_result"]["r_excess_atr"]
    assert bad is None or "r_excess" not in bad or \
        abs(bad["r_excess"] - good) > 1e-9, "the weekday join key is not load-bearing"


def test_edge3_se_propagates_the_baseline_variance(run_out):
    """se must come from the DIFFERENCED series, not from the fix series alone."""
    s = _summary(run_out, "EDGE-3")
    checked = 0
    for a in s["arms"]:
        p = a["primary_cell_result"]
        if p["se"] is None or p["se_fix"] is None:
            continue
        assert p["se"] != p["se_fix"], a["arm_id"]
        assert p["t_stat"] == pytest.approx(p["r_excess_atr"] / p["se"], rel=1e-9)
        assert p["t_stat_fix"] == pytest.approx(p["r_fix_atr"] / p["se_fix"], rel=1e-9)
        checked += 1
    assert checked >= 1


def test_edge3_beta_fix_is_the_arms_own_slope_not_the_baseline(run_out):
    s = _summary(run_out, "EDGE-3")
    for a in s["arms"]:
        for blk in (a["primary_cell_result"], a["decay_2022_2023"], a["holdout"]):
            assert "beta0" not in blk, "the ambiguous key beta0 must be gone"
            assert "frozen_is_baseline_beta0" in blk
            assert "beta_fix" in blk
    for a in s["arms"]:
        betas = [a["primary_cell_result"]["beta_fix"], a["decay_2022_2023"]["beta_fix"],
                 a["holdout"]["beta_fix"]]
        if all(b is not None for b in betas):
            assert len({round(b, 12) for b in betas}) > 1, a["arm_id"]


def test_edge3_baseline_hours_table_shows_the_time_of_day_composition(run_out):
    rows = _read_csv(os.path.join(run_out, "EDGE-3", "fix_baseline_hours.csv"))
    assert rows
    hours = {int(r["broker_hour"]) for r in rows}
    assert len(hours) > 1, "the pooled baseline must disclose its hour spread"
    assert {r["in_session_band"] for r in rows} <= {"0", "1"}
    s = _summary(run_out, "EDGE-3")
    assert s["baseline_scopes"]["session_band_hours"] == els.EDGE3_SESSION_BAND_H
    assert s["baseline_scopes"]["fix_broker_hours"]


# ===========================================================================
# r3 -- MAJOR 2: the headline must be rebuildable from the PUBLISHED tables
# ===========================================================================

def _reproduce_primary_effect(run_out):
    """Recompute primary_cell_result.effect_bp from the published tables ONLY.

    Every input here is a column of events.csv / event_windows.csv /
    baseline.csv or a field of summary.reproduction.  Nothing about the sealed
    cluster-direction rule is assumed: the cluster's direction and its trigger
    are read off the table's own cluster_direction / cluster_is_primary columns,
    and the returns come from the CLUSTER-signed ret_cl_p* family.  Before r3
    this recomputation was impossible -- the only signed family published was
    signed by each row's own event direction, which differs from the cluster's
    on 330 of 1200 production rows.
    """
    s = _summary(run_out, "EDGE-1")
    rep = s["reproduction"]
    cell = s["primary_cell_result"]
    z_thr = cell["surprise_z_threshold"]
    delay = str(cell["entry_delay_min"])
    hold = cell["holding_min"]
    ret_col = "ret_cl_p%d" % hold
    base_col = "ret_p%d" % hold
    excl = rep["baseline_event_exclusion_days"] * 86400
    min_n = rep["thin_cell_min_n"]
    assert rep["return_column_family"] == "ret_cl_p<holding_min>"

    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    ew = _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
    base = _read_csv(os.path.join(run_out, "EDGE-1", "baseline.csv"))

    by_event = {r["event_id"]: r for r in ev}
    members = {}
    for r in ev:
        if r["era"] != "IS":
            continue
        members.setdefault(r["cluster_id"], []).append(r)

    trig = set()
    for cid, ms in members.items():
        dirs = {m["cluster_direction"] for m in ms if m["cluster_direction"] != ""}
        if len(dirs) != 1:
            continue
        prim = [m for m in ms if m["cluster_is_primary"] == "1"]
        if prim:
            z = prim[0]["surprise_z"]
            if z == "" or abs(float(z)) < z_thr:
                continue
        elif not any(m["direction"] != "" and m["surprise_z"] != ""
                     and abs(float(m["surprise_z"])) >= z_thr for m in ms):
            continue
        trig.add(cid)

    cells = {}
    for b in base:
        key = (b["symbol"], b["weekday"], b["broker_hour"], b["minute_of_hour"])
        cells.setdefault(key, []).append((int(b["bar_epoch"]), float(b[base_col])))
    for v in cells.values():
        v.sort()

    buckets = {}
    for r in ew:
        if r["era"] != "IS" or r["entry_delay_min"] != delay or r["window_ok"] != "1":
            continue
        e = by_event[r["event_id"]]
        if e["is_confounded"] != "0" or r["cluster_id"] not in trig:
            continue
        if r["cluster_trade_dir"] == "" or r[ret_col] == "":
            continue
        ctd = int(r["cluster_trade_dir"])
        key = (r["symbol"], r["weekday"], r["broker_hour"], r["minute_of_hour"])
        rel = els.utc_to_broker_epoch(
            dt.datetime.strptime(e["release_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC))
        xs = [x for (ep, x) in cells.get(key, []) if not (rel - excl <= ep <= rel + excl)]
        if len(xs) < min_n:
            continue
        mu = sum(xs) / len(xs)
        buckets.setdefault(r["cluster_id"], []).append((float(r[ret_col]), ctd * mu))

    diffs = []
    for cid in sorted(buckets):
        rows = buckets[cid]
        diffs.append(sum(x for x, _ in rows) / len(rows)
                     - sum(y for _, y in rows) / len(rows))
    return (sum(diffs) / len(diffs) if diffs else None), len(diffs)


def test_headline_is_reproducible_from_the_published_cluster_signed_columns(run_out):
    s = _summary(run_out, "EDGE-1")
    effect, n_eff = _reproduce_primary_effect(run_out)
    assert n_eff == s["primary_cell_result"]["n_eff"], (n_eff, s["primary_cell_result"]["n_eff"])
    assert effect is not None
    assert effect == pytest.approx(s["primary_cell_result"]["effect_bp"], rel=1e-9, abs=1e-12)


def test_the_own_direction_columns_alone_do_not_reproduce_the_headline(run_out):
    """The reason the twins had to be published, asserted rather than argued.

    Signing the same rows by trade_dir instead of cluster_trade_dir must give a
    DIFFERENT number on a fixture that contains a cluster whose primary
    overrides a member's own direction -- otherwise the twin columns would be
    decoration and this test would be vacuous.
    """
    ew = _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
    hold = _summary(run_out, "EDGE-1")["primary_cell_result"]["holding_min"]
    diff_rows = [r for r in ew
                 if r["cluster_trade_dir"] != "" and r["cluster_trade_dir"] != r["trade_dir"]
                 and r["ret_p%d" % hold] != ""]
    assert diff_rows, "fixture must contain rows where the cluster overrides the row"
    for r in diff_rows:
        assert float(r["ret_cl_p%d" % hold]) == pytest.approx(
            -float(r["ret_p%d" % hold]), rel=1e-9, abs=1e-12)


def test_event_windows_carry_cluster_signed_twins(run_out):
    ew = _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
    assert ew
    for h in els.EDGE1_HORIZONS:
        assert "ret_cl_p%d" % h in ew[0]
    assert "mae_cl_p90_bp" in ew[0] and "mfe_cl_p90_bp" in ew[0]
    seen_cluster = False
    for r in ew:
        raw = r["ret_raw_p90"]
        if r["cluster_trade_dir"] == "":
            assert r["ret_cl_p90"] == "" and r["mae_cl_p90_bp"] == ""
            continue
        seen_cluster = True
        ctd = int(r["cluster_trade_dir"])
        if raw != "":
            assert float(r["ret_cl_p90"]) == pytest.approx(float(raw) * ctd,
                                                           rel=1e-9, abs=1e-12)
        if r["mae_p90_bp"] != "" and ctd == int(r["trade_dir"]):
            assert r["mae_cl_p90_bp"] == r["mae_p90_bp"]
            assert r["mfe_cl_p90_bp"] == r["mfe_p90_bp"]
        if r["mae_cl_p90_bp"] != "":
            # an envelope: adverse excursion <= 0 <= favourable excursion
            assert float(r["mae_cl_p90_bp"]) <= 0.0 <= float(r["mfe_cl_p90_bp"])
    assert seen_cluster
    s = _summary(run_out, "EDGE-1")
    sign = s["resolution"]["event_windows_signing"]
    assert sign["headline_statistic_column_family"] == "ret_cl_p<h>"
    assert "ret_cl_p<h>" in sign["column_notes"]
    assert "ret_p<h>" in sign["column_notes"]


# ===========================================================================
# r3 -- MAJOR 1: the COVID composition of the primary-cell sample
# ===========================================================================

def test_regime_composition_sensitivity_is_published(run_out):
    s = _summary(run_out, "EDGE-1")
    sens = {b["scope"]: b for b in s["regime_composition_sensitivity"]}
    assert set(sens) == {"ALL_IS_CLUSTERS", "EX_COVID_2020Q2"}
    assert sens["ALL_IS_CLUSTERS"]["sealed"] is True
    assert sens["EX_COVID_2020Q2"]["sealed"] is False
    assert sens["ALL_IS_CLUSTERS"]["excluded_window"] is None
    assert sens["EX_COVID_2020Q2"]["excluded_window"] == els.EDGE1_COVID_WINDOW_LABEL
    # the sealed scope must equal the headline exactly -- the disclosure may not
    # quietly become the reported number
    prim = s["primary_cell_result"]
    for k, pk in (("n_eff_is", "n_eff"), ("effect_bp_is", "effect_bp"),
                  ("effect_sigma_is", "effect_sigma"), ("t_stat_is", "t_stat")):
        assert sens["ALL_IS_CLUSTERS"][k] == prim[pk]
    ex = sens["EX_COVID_2020Q2"]
    assert ex["n_eff_is"] <= prim["n_eff"]
    assert ex["n_eff_is"] + len(ex["excluded_clusters"]) == prim["n_eff"]
    lo, hi = els.EDGE1_COVID_WINDOW
    for c in ex["excluded_clusters"]:
        d = dt.date.fromisoformat(c["release_utc"][:10])
        assert lo <= d <= hi, c
        assert abs(c["primary_surprise_z"]) >= prim["surprise_z_threshold"]
    # the verdict rule is untouched: it is still computed on ALL clusters
    assert s["verdict"] in ("UNDERPOWERED", "REFUTED", "FRAGILE", "SURVIVES",
                            "INCONCLUSIVE_OOS")
    devs = " ".join(s["deviations_from_spec"])
    assert "outlier" in devs and "sealed" in devs.lower()
    gaps = " ".join(s["open_gaps"])
    assert "REGIME COMPOSITION" in gaps


def test_holdout_empty_reason_names_the_denominator(run_out):
    s = _summary(run_out, "EDGE-1")
    diag = s["holdout"]["trigger_diagnostics"]
    assert diag["trigger_threshold_abs_z"] == s["primary_cell_result"]["surprise_z_threshold"]
    assert diag["n_clusters_with_primary_z_oos"] >= 0
    if s["holdout"]["n_eff"] == 0 and diag["max_abs_primary_z_oos"] is not None:
        assert diag["max_abs_primary_z_oos"] < diag["trigger_threshold_abs_z"]
    reason = s["holdout"]["empty_reason"]
    assert "rolling" in reason.lower() or "ROLLING" in reason
    assert "coverage hole" in reason
    sd = s["surprise_history"]["rolling_sd_median_by_group_year"]
    assert sd, "the z denominator must be published per group per year"
    for group, years in sd.items():
        assert years
        for y, v in years.items():
            assert int(y) > 2000 and v is not None


def test_seed_row_counters_are_split_by_side_of_the_window(run_out):
    s = _summary(run_out, "EDGE-1")
    sh = s["surprise_history"]
    assert sh["seed_rows_before_is_start"] + sh["rows_after_oos_end"] \
        == sh["rows_outside_study_window"]
    assert "rows_after_oos_end" in sh["seed_label_note"]
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    assert all(IS_START[:4] <= r["release_utc"][:4] <= OOS_END[:4] for r in ev)


# ===========================================================================
# r3 -- MINOR 5: Stage-0b gate B reads inside the measurement window
# ===========================================================================

def test_stage0b_gate_b_sensitivity_is_published(run_out):
    s = _summary(run_out, "EDGE-1")
    sens = {b["scope"]: b for b in s["stage0b_gate_b_sensitivity"]}
    assert set(sens) == {"GATE_B_ON", "GATE_B_OFF"}
    assert sens["GATE_B_ON"]["sealed"] is True
    assert sens["GATE_B_OFF"]["sealed"] is False
    on, off = sens["GATE_B_ON"], sens["GATE_B_OFF"]
    assert off["events_instant_verified"] >= on["events_instant_verified"]
    assert (off["events_instant_verified"] - on["events_instant_verified"]
            == off["events_reinstated"]
            == s["calibration"]["events_voided_local_peak"])
    prim = s["primary_cell_result"]
    assert on["n_eff_is"] == prim["n_eff"] and on["effect_bp_is"] == prim["effect_bp"]
    assert isinstance(s["stage0b_gate_b_statistic_unchanged"], bool)
    assert s["calibration"]["stage0b_gate_b_circularity"]
    assert "holding window" in s["calibration"]["stage0b_gate_b_circularity"]
    assert any("gate B" in g for g in s["open_gaps"])
    assert "gate B" in els.__doc__ or "gate B" in els.__doc__.lower()


def test_gate_b_voided_events_never_reach_the_published_tables(run_out):
    """The shadow scope must not leak into the sealed outputs."""
    ce = _read_csv(os.path.join(run_out, "EDGE-1", "calibration_events.csv"))
    voided = {(r["currency"], r["event"], r["release_utc"])
              for r in ce if r["void_reason"] == "local_peak_elsewhere"}
    if not voided:
        pytest.skip("fixture produced no gate-B void")
    ev = _read_csv(os.path.join(run_out, "EDGE-1", "events.csv"))
    ids = {r["event_id"] for r in ev
           if (r["currency"], r["event"], r["release_utc"]) in voided}
    for r in ev:
        if r["event_id"] in ids:
            assert r["direction"] == "", r
            assert r["instant_verified"] == "0", r
    ew = _read_csv(os.path.join(run_out, "EDGE-1", "event_windows.csv"))
    assert not [r for r in ew if r["event_id"] in ids], \
        "gate-B-voided events must not appear in event_windows.csv"


# ===========================================================================
# r3 -- MINOR 4: the calibrated instant set must not depend on --hypothesis
# ===========================================================================

def test_calibrated_instant_set_is_hypothesis_independent(fixture_env, tmp_path):
    both = _run(fixture_env, str(tmp_path / "both"), extra=["--no-baseline-rows"],
                hypothesis="both")
    only3 = _run(fixture_env, str(tmp_path / "e3"), extra=["--no-baseline-rows"],
                 hypothesis="EDGE-3")
    a = os.path.join(both, "EDGE-3", "fix_days.csv")
    b = os.path.join(only3, "EDGE-3", "fix_days.csv")
    assert filecmp.cmp(a, b, shallow=False), \
        "fix_days.csv must not change with --hypothesis"
    assert els.sha256_file(a) == els.sha256_file(b)
    sa = json.load(open(os.path.join(both, "EDGE-3", "summary.json"), encoding="utf-8"))
    sb = json.load(open(os.path.join(only3, "EDGE-3", "summary.json"), encoding="utf-8"))
    assert sa["arms"] == sb["arms"]
    s1 = _summary(both, "EDGE-1")
    assert s1["counts"]["calibrated_instants"] >= \
        s1["counts"]["calibrated_instants_confound_window"]


def test_calibrated_instant_set_window_is_a_subset_of_the_full_set(fixture_env):
    cal_rows, _sha, _b, _n = els.load_calendar(fixture_env["calendar"])
    applied = {(r.currency, r.event): 0 for r in cal_rows}
    full = els.calibrated_instant_set(cal_rows, applied)
    win = els.calibrated_instant_set(cal_rows, applied,
                                     dt.date(2018, 1, 1), dt.date(2019, 12, 31))
    assert win and full
    assert set(win) <= set(full)
    assert len(full) > len(win)


# ===========================================================================
# r3 -- MINOR 9: Stage-0 group drops get their own statuses
# ===========================================================================

def test_modal_home_clock_drops_an_exact_tie_instead_of_breaking_it():
    assert els.modal_home_clock({}) == (None, False)
    assert els.modal_home_clock({510: 7}) == (510, False)
    assert els.modal_home_clock({510: 7, 570: 3}) == (510, False)
    # exact tie -> no modal value, group must be dropped
    assert els.modal_home_clock({510: 5, 570: 5}) == (None, True)
    assert els.modal_home_clock({570: 5, 510: 5}) == (None, True)
    # a tie further down the histogram is irrelevant
    assert els.modal_home_clock({510: 9, 570: 4, 630: 4}) == (510, False)


def test_calibration_statuses_are_distinct_and_all_countable(run_out):
    rows = _read_csv(os.path.join(run_out, "EDGE-1", "calibration.csv"))
    seen = {r["calib_status"] for r in rows}
    assert seen <= set(els.CALIB_STATUS_COUNT_KEY)
    assert "VERIFY_FRAC_LOW" in els.CALIB_STATUS_COUNT_KEY
    assert "HOME_CLOCK_TIE" in els.CALIB_STATUS_COUNT_KEY
    assert len(set(els.CALIB_STATUS_COUNT_KEY.values())) == len(els.CALIB_STATUS_COUNT_KEY)
    s = _summary(run_out, "EDGE-1")
    cal = s["calibration"]
    for k in ("groups_verify_frac_low", "groups_home_clock_tie",
              "groups_dropped_verify_frac", "groups_dropped_home_clock_tie",
              "events_voided_home_clock_tie"):
        assert k in cal, k
    sem = cal["status_semantics"]
    assert set(sem) == set(els.CALIB_STATUS_COUNT_KEY)
    assert cal["groups_examined"] == (
        cal["groups_calibrated"] + cal["groups_no_signature"] + cal["groups_ambiguous"]
        + cal["groups_underpowered"] + cal["groups_verify_frac_low"]
        + cal["groups_home_clock_tie"])


def test_verify_frac_low_is_reported_as_its_own_status(fixture_env, tmp_path, monkeypatch):
    """Forcing the verified-fraction floor above 1.0 must drop every group with
    a VERIFY_FRAC_LOW status, never a reused AMBIGUOUS."""
    monkeypatch.setattr(els, "CALIB_MIN_VERIFIED_FRAC", 1.01)
    out = _run(fixture_env, str(tmp_path / "vfl"), extra=["--no-baseline-rows"],
               hypothesis="EDGE-1")
    rows = _read_csv(os.path.join(out, "EDGE-1", "calibration.csv"))
    dropped = [r for r in rows if r["calib_status"] == "VERIFY_FRAC_LOW"]
    assert dropped, "the floor above 1.0 must drop every calibrated group"
    assert not [r for r in rows if r["calib_status"] == "CALIBRATED"]
    s = _summary(out, "EDGE-1")
    assert s["calibration"]["groups_verify_frac_low"] == len(dropped)
    assert s["calibration"]["groups_dropped_verify_frac"] == len(dropped)
    ce = _read_csv(os.path.join(out, "EDGE-1", "calibration_events.csv"))
    assert ce and all(r["void_reason"] == "group_verify_frac" for r in ce)


# ===========================================================================
# r3 -- MINOR 3 / 8: seal identity that survives a later edit and a CRLF checkout
# ===========================================================================

def test_manifest_records_the_program_doc_git_identity(run_out):
    with open(os.path.join(run_out, "EDGE-1", "manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    pd_ = man["rule_seal"]["program_doc"]
    for k in ("path", "sha256", "sha256_lf", "bytes", "resolved_from",
              "git_blob_sha", "read_at_commit", "committed_blob_sha",
              "matches_committed_blob", "hash_note"):
        assert k in pd_, k
    assert "git_blob_sha" in pd_["hash_note"] and "read_at_commit" in pd_["hash_note"]
    if pd_["path"]:
        assert pd_["sha256_lf"] == els.sha256_file_lf(pd_["path"])
        # the doc is a repo file, so its git identity must be recoverable
        assert pd_["git_blob_sha"], "a repo-resident sealed doc must carry a blob id"
        assert pd_["read_at_commit"], "the run must pin the revision it read the doc at"
    assert man["rule_seal"]["doc_sha256"] == pd_["sha256"]


def test_manifest_code_block_says_which_hash_is_authoritative(run_out):
    with open(os.path.join(run_out, "EDGE-1", "manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    code = man["code"]
    assert code["hash_note"]
    assert "file_sha256_lf" in code["hash_note"]
    assert "AUTHORITATIVE" in code["hash_note"]
    assert code["file_sha256_lf"] == els.sha256_file_lf(os.path.abspath(els.__file__))
    cost = [i for i in man["inputs"] if i["role"] == "cost_registry"]
    if cost:
        assert "authoritative" in cost[0]["hash_note"].lower() \
            or "compare across checkouts" in cost[0]["hash_note"]


# ===========================================================================
# r3 -- MINOR 7 / 10: determinism WITH the per-bar baselines, and the gzip copy
# ===========================================================================

def test_two_runs_with_baseline_rows_are_byte_identical(fixture_env, tmp_path):
    """The r2 determinism test ran --no-baseline-rows, so baseline.csv and
    fix_baseline.csv -- the two largest outputs -- were never compared."""
    a = _run(fixture_env, str(tmp_path / "ba"))
    b = _run(fixture_env, str(tmp_path / "bb"))
    checked = []
    for rel in ("EDGE-1/baseline.csv", "EDGE-3/fix_baseline.csv"):
        pa, pb = os.path.join(a, rel), os.path.join(b, rel)
        assert os.path.exists(pa) and os.path.exists(pb), rel
        assert filecmp.cmp(pa, pb, shallow=False), "non-deterministic output: %s" % rel
        checked.append(rel)
    assert len(checked) == 2
    for hyp in ("EDGE-1", "EDGE-3"):
        for fn in sorted(os.listdir(os.path.join(a, hyp))):
            rel = os.path.join(hyp, fn)
            pa, pb = os.path.join(a, rel), os.path.join(b, rel)
            if fn == "manifest.json":
                with open(pa, encoding="utf-8") as f:
                    ta = f.read().replace(a.replace("\\", "/"), "<OUT>").replace(a, "<OUT>")
                with open(pb, encoding="utf-8") as f:
                    tb = f.read().replace(b.replace("\\", "/"), "<OUT>").replace(b, "<OUT>")
                assert ta == tb, rel
                continue
            assert filecmp.cmp(pa, pb, shallow=False), rel


def test_fix_days_gzip_is_a_deterministic_byte_copy(run_out):
    import gzip as _gzip
    raw = os.path.join(run_out, "EDGE-3", "fix_days.csv")
    gz = raw + ".gz"
    assert os.path.exists(gz), "the compact EDGE-3 copy must ship a gzip of fix_days.csv"
    with open(raw, "rb") as f:
        want = f.read()
    with _gzip.open(gz, "rb") as f:
        assert f.read() == want
    assert os.path.getsize(gz) < os.path.getsize(raw)
    with open(os.path.join(run_out, "EDGE-3", "manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    out = {o["path"].replace("\\", "/"): o for o in man["outputs"]}
    for k in ("EDGE-3/fix_days.csv", "EDGE-3/fix_days.csv.gz"):
        assert k in out, sorted(out)
    assert out["EDGE-3/fix_days.csv.gz"]["sha256"] == els.sha256_file(gz)
    assert out["EDGE-3/fix_days.csv.gz"]["note"]
    assert out["EDGE-3/fix_days.csv.gz"]["rows"] == out["EDGE-3/fix_days.csv"]["rows"]


# ===========================================================================
# r3 -- MINOR 6: the EDGE-3 SE says exactly what it does and does not carry
# ===========================================================================

def test_edge3_se_states_what_it_omits_and_publishes_the_term(run_out):
    doc = els.run_edge3.__doc__ or ""
    s = _summary(run_out, "EDGE-3")
    for a in s["arms"]:
        for blk in (a["primary_cell_result"], a["decay_2022_2023"], a["holdout"]):
            for k in ("se_baseline_mean_rms_atr", "se_baseline_component_atr",
                      "se_incl_baseline_atr", "t_stat_incl_baseline",
                      "n_baseline_cells_used"):
                assert k in blk, k
            assert blk.get("se_excludes_baseline_mean_error") is True
            if blk["se"] is None or blk["se_baseline_component_atr"] is None:
                continue
            # the added term is exact, not a bound: se_incl^2 == se^2 + comp^2
            assert blk["se_incl_baseline_atr"] == pytest.approx(
                math.sqrt(blk["se"] ** 2 + blk["se_baseline_component_atr"] ** 2),
                rel=1e-12)
            # ... and widening the SE can only shrink |t|, never grow it
            assert blk["se_incl_baseline_atr"] >= blk["se"]
            assert abs(blk["t_stat_incl_baseline"]) <= abs(blk["t_stat"]) + 1e-12
            # the per-cell weighting must divide by CELLS, not by triggers
            assert blk["n_baseline_cells_used"] >= 1
            assert blk["se_baseline_component_atr"] <= blk["se_baseline_mean_rms_atr"] + 1e-12
    gaps = " ".join(s["open_gaps"])
    assert "KNOWN" in gaps and "SAMPLING error" in gaps
    assert "se_baseline_component_atr" in gaps and "per CELL" in gaps
    # the docstring must no longer claim the baseline's estimation variance is
    # propagated -- it is not
    src = open(os.path.abspath(els.__file__), encoding="utf-8").read()
    assert "propagates the baseline's own estimation variance" not in src
    assert "does NOT propagate the cell means' own SAMPLING error" in src
    assert "perfectly correlated" in src, \
        "the docstring must say why the term does not average away over triggers"
    assert doc is not None
