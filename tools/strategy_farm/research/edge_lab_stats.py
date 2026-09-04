#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""EDGE-lab refutation statistics for EDGE-1 (scheduled-news drift) and EDGE-3
(London fix reversion).

Deterministic, read-only, no plotting, no model calls, no RNG.

    python -X utf8 tools/strategy_farm/research/edge_lab_stats.py \
        --hypothesis both --out <root>

=============================================================================
TIME BASE  --  the single most load-bearing assumption in this file
=============================================================================
The T_Export M5 CSVs (``D:/QM/mt5/T_Export/MQL5/Files/<SYM>.DWX_M5.csv``,
header ``time,open,high,low,close,tickvol``) are written by
``SecretMission/EXPORT_DWX_FX_M5.mq5`` / ``EXPORT_DWX_XAU_M5.mq5`` as
``FileWrite(handle, (long)rates[index].time, ...)`` -- i.e. the raw
``MqlRates.time`` integer with no conversion.  ``MqlRates.time`` is the
BROKER/SERVER wall clock rendered into a Unix-epoch field, NOT true UTC.
Treating it as UTC shifts every session by 2-3h.

The broker is Darwinex NY-Close: UTC+2 outside US DST, UTC+3 during US DST,
using **US** (not EU) DST boundaries.  Documentary anchors:

  * ``CLAUDE.md`` -> "Broker time (Darwinex/DXZ NY-Close): GMT+2 outside US
    DST, GMT+3 during US DST"
  * ``framework/include/QM/QM_DSTAware.mqh`` lines 1-141 -- the canonical MQL
    implementation this module is ported from.  US DST starts 07:00 UTC on the
    2nd Sunday of March and ends 06:00 UTC on the 1st Sunday of November;
    ``QM_BrokerToUTC`` prefers the standard-time (+2) candidate in the
    November-fallback ambiguous hour.
  * ``docs/ops/DWX_IMPORT_AUTOMATION.md`` line 104 -- "TDM defaults: GMT+2,
    DST = US ... Verified to match Darwinex's NY-Close server-time convention
    2026-04-25"; import filenames ``<SYMBOL>_GMT+2_US-DST.csv``.
  * ``docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md`` Sec.2 -- the rule id
    ``qm.dst_rule.us.v1`` used here.
  * Reference Python implementation with the same two-candidate structure:
    ``.private/secret_strategy_lab/pre_candidate_collins_contracting_range_
    fade_momentum_d1/structural_screen.py`` (``broker_epoch_to_utc_and_wall``).

Conversion, exactly as the data scout specified (no "noon of the broker date"
shortcut -- that shortcut misclassifies bars in the hours around a DST switch):

    us_dst_interval_utc(y) = (datetime(y, 3, nth_sunday(y,3,2), 7, UTC),
                              datetime(y,11, nth_sunday(y,11,1), 6, UTC))
    darwinex_offset_hours(u) = 3 if start <= u < end else 2

    broker_epoch -> UTC:  wall = utcfromtimestamp(raw)
                          for off in (2, 3):
                              cand = wall - off hours
                              keep cand iff darwinex_offset_hours(cand) == off
                          exactly one candidate must survive (0 or 2 == error)
    UTC -> broker_epoch:  wall = u + darwinex_offset_hours(u) hours
                          raw  = calendar.timegm(wall.timetuple())

Empirically re-verified in this worktree before the tool was written
(EURUSD.DWX_M5, tickvol at the release bar and its +/-3 neighbours):
    NFP 2023-02-03 13:30Z (US standard, offset +2) -> broker epoch 1675438200
        [700, 851, 991, 2629, 2455, 2240, 2130]  <- release bar 2629
        naive-UTC epoch 1675431000 -> [463,457,413,409,396,296,447] (no event)
    NFP 2024-11-01 12:30Z (US DST still on, offset +3) -> epoch 1730475000
        [314, 422, 541, 1885, 1246, 1132, 1027]  <- release bar 1885
        naive-UTC epoch 1730464200 -> [192,218,176,185,209,205,163] (no event)

A SECOND, SEPARATE rule is required for EDGE-3 because the London fixes are
defined in London local wall-clock time: ``qm.dst_rule.uk.v1`` -- BST starts
01:00 UTC on the LAST Sunday of March and ends 01:00 UTC on the LAST Sunday of
October, offset UTC+1 inside, UTC+0 outside.  The two rules are deliberately
kept as separate, separately versioned functions: in mid-March and late
October/early November the UK and US regimes disagree and 16:00 London is
broker 19:00 rather than broker 18:00.  Rows carry ``dst_regime`` so those
days can be inspected on their own.

=============================================================================
RESOLUTION LOSSES (binding on how every claim in the outputs may be phrased)
=============================================================================
L1  Entry is the OPEN of the first M5 bar whose open epoch is >= the exact
    release instant + entry_delay.  ``entry_lag_sec`` in [0,300) is emitted;
    rows with lag >= 300 (a missing bar) are voided.  This is unbiased, never
    optimistic: an M5 open is a real printed price and the lag is never
    negative.
L2  There is no intrabar path, so stop/target exits are NOT measurable.  Every
    refutation statistic here is a pure time-stopped close-to-close return.
    MAE/MFE from M5 high/low are emitted as an ENVELOPE only (true intrabar
    MAE >= M5 MAE), and must never be used to support a stop-loss claim.
L3  Bars are BID.  There is no ask/spread series.  All returns are GROSS.
    The only admissible cost anchor is ``framework/registry/live_commission.json``
    (forex pct_rate_rt 5e-05 = 0.5 bp round trip; commodity likewise).  Spread
    is unmodelled -> ``spread_modelled: false`` in every summary, and no net
    expectancy may be claimed anywhere.
L4  The first-seconds move is invisible at M5.  ``entry_delay_min`` cannot go
    below 5 and the "dealers fade the first move" mechanism is an UNVERIFIED
    assumption, not a supported finding.
L5  ``tickvol`` counts price updates, not volume.  It is used here only as a
    timestamp-calibration probe (Stage 0), where only the LOCATION of the
    maximum matters -- never as a liquidity or flow measure.
L6  The calendar has no ``known_at_utc`` column, so we cannot prove the
    Forecast was public before the release.  ``known_at_utc_available: false``
    is emitted and the look-ahead risk stays a named GAP.

=============================================================================
STAGE 0 -- the calendar's DateTime_UTC is NOT reliably UTC
=============================================================================
``forex_factory_calendar_clean.csv`` displaces a large class of US 08:30-ET
releases by -17h/-16h (every NFP row 2015-01..2025-04 sits on a Thursday).
The defect is a per-event-family constant, not noise, and it coexists with
correct rows in the same file.  Running EDGE-1 on the raw column would measure
a different market with full confidence.

Stage 0 therefore recovers the release INSTANT empirically from the
mean normalised-tickvol profile over a +/-26h offset grid, per
(currency, event) group, on a PRE-REGISTERED probe symbol.  A group is only
usable if it is CALIBRATED (see ``CALIB_*`` constants).  Non-calibrated groups
are excluded from EDGE-1 entirely; there is no fallback to the raw timestamp
and no manual override.

The grid is probed in **UTC space**: the candidate instant is ``raw_utc + off``
and the probe anchor is ``utc_to_broker_epoch`` of that -- exactly the epoch
EDGE-1 later measures at.  Probing ``broker_epoch(raw) + off`` instead names a
DIFFERENT instant, by one hour, whenever the raw stamp and the shifted stamp
straddle a US-DST boundary.

STAGE 0b -- the group offset is a CONSTANT, the defect is not.  Raw USD NFP
stamps sit at Thu 19:30Z from April to September and Thu 20:30Z from October to
March, so a single group constant lands a minority of rows an hour late.  Two
per-event gates therefore run after the group offset and can only VOID, never
shift: (A) the corrected instant must fall on the group's MODAL minute-of-day in
the release's own home timezone (US Eastern for USD, Europe/London for GBP,
Europe/Berlin for EUR); (B) the event's own normalised-tickvol profile on a
+/-90 min grid must peak within one M5 slot of the corrected instant, whenever
that local peak is prominent enough to be authoritative.  A group whose constant
explains fewer than ``CALIB_MIN_VERIFIED_FRAC`` of its own rows is dropped
entirely.  No event is ever re-fitted individually: a per-event offset fit would
be exactly the circularity Stage 0 exists to avoid.

The residual circularity is weak and is named rather than assumed away: the
argmax uses tickvol, the statistic uses returns, and the recovered offset is a
per-group constant.  Stage 0 CANNOT repair a wrong Actual/Forecast value and
CANNOT supply ``known_at_utc``.  Both remain declared GAPs.
"""

from __future__ import annotations

import argparse
import bisect
import calendar as _calendar
import csv
import datetime as dt
import hashlib
import json
import math
import os
import subprocess
import sys
from typing import Dict, List, Optional, Sequence, Tuple

CODE_VERSION = "qm.edge_lab_stats.v1"
SUMMARY_SCHEMA = "qm.edge_lab.summary.v1"
MANIFEST_SCHEMA = "qm.edge_lab.manifest.v1"
TRIALS_SCHEMA = "qm.edge-lab.trials.v1"

UTC = dt.timezone.utc

_MISSING = object()   # cache sentinel: None is a legitimate cached value

DEFAULT_BARS_DIR = "D:/QM/mt5/T_Export/MQL5/Files"
DEFAULT_CALENDAR = "D:/QM/data/news_calendar/forex_factory_calendar_clean.csv"
DEFAULT_OUT_ROOT = "docs/research/edge_lab"
# The sealed hypothesis document.  It lives in the CANONICAL repo checkout; an
# agent worktree branched before it landed will not have it, and reconstructing
# the criteria second-hand is exactly how an unsealed criterion slips in.  The
# resolver therefore falls back to the canonical checkout and the manifest
# records which path the hash came from.
DEFAULT_PROGRAM_DOC_REL = "docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md"
CANONICAL_REPO_ROOT = "C:/QM/repo"

SLOT_SECONDS = 300
# A run of >= 3 consecutive missing M5 slots is 15 minutes with no printed bar
# and marks the window as not session-intact (weekend, holiday, or the XAUUSD
# broker-hour-00 daily break, which is 13 slots).
GAP_RUN_SLOTS = 3

# ---------------------------------------------------------------------------
# Sealed universe / parameters (see the module docstring; changing any of these
# after a measurement is a criterion change, not a config tweak)
# ---------------------------------------------------------------------------

EDGE1_HORIZONS = (5, 15, 30, 60, 90, 120)
# NOTE (deviation, declared): the spec listed a p1 column.  A 1-minute horizon
# is not representable on M5 -- the last bar closing at or before entry+60s is
# the bar BEFORE entry -- so p1 is dropped rather than filled with a look-back.

EDGE1_CURRENCIES = ("USD", "EUR", "GBP")
# Currency -> symbol map.  Rule: the currency must be a LEG of the symbol.
# The task names EURUSD / GBPUSD / USDJPY as the EDGE-1 universe, which yields
# USD -> two crosses and EUR/GBP -> one each.  GBPJPY M5 also exists in
# T_Export and can be switched on with --edge1-include-gbpjpy, which gives GBP
# its second cross; it is OFF by default so the run matches the commissioned
# universe.  EUR has no second M5 cross in T_Export at all (no EURJPY/EURGBP
# M5 export exists) -- that is a declared universe GAP, not a choice.
EDGE1_SYMBOL_MAP_BASE = {
    "USD": ("EURUSD.DWX", "USDJPY.DWX"),
    "EUR": ("EURUSD.DWX",),
    "GBP": ("GBPUSD.DWX",),
}
EDGE1_SYMBOL_MAP_GBPJPY = {
    "USD": ("EURUSD.DWX", "USDJPY.DWX"),
    "EUR": ("EURUSD.DWX",),
    "GBP": ("GBPUSD.DWX", "GBPJPY.DWX"),
}
# Probe symbol per currency for Stage 0.  Pre-registered, never chosen per
# group: the probe only has to SEE the release, it is not the thing measured.
EDGE1_PROBE_SYMBOL = {"USD": "EURUSD.DWX", "EUR": "EURUSD.DWX", "GBP": "GBPUSD.DWX"}

EDGE1_PRIMARY_CELL = {"surprise_z_threshold": 1.00, "entry_delay_min": 5, "holding_min": 90}
EDGE1_GRID_Z = (0.75, 1.00, 1.50)
EDGE1_GRID_DELAY = (5, 10, 15)
EDGE1_GRID_HOLD = (30, 60, 90, 120)
EDGE1_DECLARED_TRIALS = len(EDGE1_GRID_Z) * len(EDGE1_GRID_DELAY) * len(EDGE1_GRID_HOLD)

EDGE1_EFFECT_SIGMA_FLOOR = 0.40
EDGE1_N_EFF_FLOOR = 300
EDGE1_T_FLOOR = 2.0
EDGE1_OOS_N_FLOOR = 60
EDGE1_FRAGILITY_SIGMA = 0.20
EDGE1_FRAGILITY_CELLS = 24
EDGE1_THIN_CELL_N = 30
EDGE1_SURPRISE_MIN_HISTORY = 12
EDGE1_SURPRISE_WINDOW_DAYS = 1095
EDGE1_BASELINE_NEWS_EXCL_MIN = 120
EDGE1_BASELINE_EVENT_EXCL_DAYS = 3
EDGE1_CONFOUND_MIN = max(EDGE1_GRID_DELAY) + max(EDGE1_GRID_HOLD) + 15

CALIB_MAX_OFFSET_MIN = 1560           # +/- 26h
CALIB_STEP_MIN = 5
CALIB_MIN_OBS = 20
CALIB_MIN_PEAK_RATIO = 2.0
CALIB_MIN_PEAK_OVER_BASE = 2.0
CALIB_MIN_SHARPNESS = 1.5
CALIB_SHARPNESS_EXCL_MIN = 30
CALIB_MIN_STABILITY = 0.60
CALIB_MAX_ERA_DISAGREE_MIN = 5
CALIB_MIN_PROFILE_FILL = 0.90
CALIB_ERA_SPLIT_YEAR = 2022

# --- STAGE 0b: per-EVENT instant verification (r2) --------------------------
# A single per-GROUP constant offset is not enough.  The production calendar's
# displacement is itself DST-seasonal: raw USD NFP stamps sit at Thu 19:30Z
# Apr-Sep and Thu 20:30Z Oct-Mar, so one constant lands a minority of rows an
# hour late.  Two independent per-event gates run after the group offset:
#
#   A. HOME WALL-CLOCK CONFORMITY.  Scheduled releases have a fixed local
#      release time in their own jurisdiction (US 08:30 ET, UK 07:00 London,
#      EA 10:00 Berlin, ...).  The corrected instants of one group must all map
#      to the SAME minute-of-day in that home timezone.  The modal value is the
#      group's release time; every event that disagrees is VOIDED, never
#      shifted.  Weekday is deliberately ignored -- a genuine pre-holiday
#      Thursday NFP is at 08:30 ET and must survive.
#   B. LOCAL TICKVOL PEAK.  The event's own normalised-tickvol profile on a
#      narrow +/-90 min grid around its corrected instant must peak within one
#      M5 slot of it.  An event whose own prominent local peak sits elsewhere
#      is VOIDED.  "Prominent" is required so a merely quiet release is not
#      voided for lack of a footprint -- absence of evidence is not used as
#      evidence of misplacement.
#
# Both gates only ever VOID.  Nothing is re-shifted per event: a per-event fit
# would be exactly the circularity Stage 0 exists to avoid.
CALIB_EVENT_LOCAL_GRID_MIN = 90
CALIB_EVENT_LOCAL_TOL_MIN = 5          # one M5 slot
CALIB_EVENT_LOCAL_PROMINENCE = 1.5     # local peak / local median to be authoritative
CALIB_MIN_VERIFIED_FRAC = 0.50         # below this the whole GROUP is dropped

# Home timezone per event currency, for gate A.  Standard offset in hours plus
# the DST rule that applies to it.  US Eastern uses qm.dst_rule.us.v1 (its
# boundaries ARE the US ones); EUR/GBP use qm.dst_rule.uk.v1 boundaries (the EU
# and UK switch on the same instants: last Sunday March / last Sunday October
# 01:00 UTC).
HOME_TZ = {
    "USD": ("America/New_York", -5, "us"),
    "GBP": ("Europe/London", 0, "uk"),
    "EUR": ("Europe/Berlin", 1, "uk"),
}

# --- EDGE-1 cluster direction resolution (r2) -------------------------------
# Simultaneous same-currency releases share a cluster_id.  Averaging the
# direction-signed returns of two rows that disagree on direction is not a
# tradeable rule: it silently scales an observation by the vote margin (a 2:1
# cluster keeps 1/3 of its magnitude) and mixes full-scale and fractional
# observations in one sample.
#
# SEALED RULE: the cluster's direction and its trigger are both taken from the
# cluster's PRIMARY member -- the highest-ranked event in the block by market
# convention (policy rate > payrolls > CPI > retail sales > PPI > GDP > rest).
# That is the tradeable reading: you read the headline print, and you take the
# trade when ITS surprise is large.  Ranks are authored from market convention
# only, never from observed returns, and a lower number wins.  Ties inside one
# rank are broken by the event name, so the rule is deterministic.
#
# Clusters with no ranked member fall back to unanimity: if every member agrees
# on direction that direction is used, otherwise the cluster is DROPPED and
# counted in ``dropped_direction_conflict``.  It is never averaged.
CLUSTER_PRIMARY_RANK: Dict[str, int] = {
    "Federal Funds Rate": 1,
    "Official Bank Rate": 1,
    "Main Refinancing Rate": 1,
    "Minimum Bid Rate": 1,
    "Non-Farm Employment Change": 2,
    "CPI m/m": 3,
    "CPI y/y": 3,
    "Core CPI m/m": 4,
    "Core CPI y/y": 4,
    "Prelim CPI y/y": 4,
    "Final CPI y/y": 5,
    "German Prelim CPI m/m": 5,
    "Retail Sales m/m": 6,
    "Core Retail Sales m/m": 7,
    "PPI m/m": 8,
    "Core PPI m/m": 9,
    "Core PCE Price Index m/m": 9,
    "Advance GDP q/q": 10,
    "Prelim GDP q/q": 11,
    "Final GDP q/q": 12,
    "GDP q/q": 11,
    "GDP m/m": 12,
    "Unemployment Rate": 13,
    "Unemployment Claims": 13,
    "Claimant Count Change": 13,
    "Employment Change": 14,
    "Average Hourly Earnings m/m": 15,
    "Average Earnings Index 3m/y": 15,
    "ADP Non-Farm Employment Change": 16,
    "ISM Manufacturing PMI": 17,
    "ISM Services PMI": 17,
    "ISM Non-Manufacturing PMI": 17,
    "Trade Balance": 20,
    "Industrial Production m/m": 20,
    "Core Durable Goods Orders m/m": 21,
    "Durable Goods Orders m/m": 21,
}
EDGE1_DIR_RULES = ("primary_event_rank", "unanimous_only", "row_mean")
EDGE1_DIR_RULE_PRIMARY = "primary_event_rank"

EDGE3_HORIZONS = (15, 30, 45, 60)
EDGE3_PRIMARY_CELL = {"prefix_window_min": 30, "threshold_atr": 0.6, "holding_min": 45}
EDGE3_GRID_PREFIX = (15, 30, 60)
EDGE3_GRID_THRESHOLD = (0.4, 0.6, 0.8)
EDGE3_GRID_HOLD = (15, 30, 45, 60)
EDGE3_CELLS_PER_ARM = len(EDGE3_GRID_PREFIX) * len(EDGE3_GRID_THRESHOLD) * len(EDGE3_GRID_HOLD)

EDGE3_R_FLOOR = 0.15
EDGE3_N_DAYS_FLOOR = 800
EDGE3_N_TRIGGER_FLOOR = 250
EDGE3_T_FLOOR = 2.0
EDGE3_OOS_TRIGGER_FLOOR = 100
EDGE3_DECAY_FLOOR = 0.05
EDGE3_CONTROL_VOID = 0.10
EDGE3_FRAGILITY_R = EDGE3_R_FLOOR / 2.0
EDGE3_FRAGILITY_CELLS = 24
EDGE3_BASELINE_MIN_N = 100
EDGE3_FIX_EXCL_MIN = 90
# The "at least 90 min from every fix" rule removes the fix's OWN broker hour
# from its baseline by construction, so the all-hours pooled baseline contrasts
# a London-NY-overlap arm against a mostly Asian/early-European ambient.  A
# SESSION-MATCHED baseline is therefore computed alongside: pseudo-anchors whose
# broker hour is within +/- EDGE3_SESSION_BAND_H of a fix hour (and still >= 90
# min from every fix).  R_EXCESS is reported under BOTH scopes.
EDGE3_SESSION_BAND_H = 3
EDGE3_ATR_AGG_MIN = 30
EDGE3_ATR_PERIOD = 14
EDGE3_NEWS_COVERAGE_DAYS = 7

# fix_code -> (london_hour, london_minute)
EDGE3_FIXES = {
    "LDN_AM_1030": (10, 30),
    "LDN_PM_1500": (15, 0),
    "WMR_1600": (16, 0),
}
# Sealed arm map.  LDN_AM_1030 is a NEGATIVE CONTROL, not a candidate: the
# 10:30 London gold fix has no detectable tickvol footprint at all (1.03x
# ambient), so any "effect" there is method, not market.
EDGE3_ARMS = (
    ("XAUUSD.DWX", "LDN_PM_1500", "CANDIDATE"),
    ("EURUSD.DWX", "WMR_1600", "CANDIDATE"),
    ("XAUUSD.DWX", "LDN_AM_1030", "NEGATIVE_CONTROL"),
)
EDGE3_DIAGNOSTIC_ARMS = (
    ("EURUSD.DWX", "LDN_PM_1500", "DIAGNOSTIC"),
    ("XAUUSD.DWX", "WMR_1600", "DIAGNOSTIC"),
)
EDGE3_DECLARED_TRIALS = EDGE3_CELLS_PER_ARM * len(EDGE3_ARMS)

# ---------------------------------------------------------------------------
# EDGE-1 event polarity map -- +1 iff a higher-than-forecast Actual STRENGTHENS
# the event's currency.  Authored from economic meaning ONLY.
#
# This map is embedded in the module rather than shipped as a side-car JSON on
# purpose: embedding it puts it inside the code sha256 recorded in the
# manifest, so the seal ("the rule predated the measurement") is provable from
# a single hash.  --polarity-map <path> overrides it, and the override's own
# sha256 is then recorded instead.
#
# Deriving polarity from observed returns would fit the sign and void the whole
# test.  A CALIBRATED group that is absent from this map is EXCLUDED, never
# defaulted to +1.
# ---------------------------------------------------------------------------
EVENT_POLARITY: Dict[str, int] = {
    # --- labour ---
    "Non-Farm Employment Change": 1,
    "ADP Non-Farm Employment Change": 1,
    "Unemployment Rate": -1,
    "Unemployment Claims": -1,
    "Average Hourly Earnings m/m": 1,
    "JOLTS Job Openings": 1,
    "Claimant Count Change": -1,
    "Employment Change": 1,
    "Average Earnings Index 3m/y": 1,
    # --- inflation ---
    "CPI m/m": 1,
    "CPI y/y": 1,
    "Core CPI m/m": 1,
    "Core CPI y/y": 1,
    "PPI m/m": 1,
    "Core PPI m/m": 1,
    "Core PCE Price Index m/m": 1,
    "German Prelim CPI m/m": 1,
    "Prelim CPI y/y": 1,
    "Final CPI y/y": 1,
    # --- activity / growth ---
    "Retail Sales m/m": 1,
    "Core Retail Sales m/m": 1,
    "Advance GDP q/q": 1,
    "Prelim GDP q/q": 1,
    "Final GDP q/q": 1,
    "GDP m/m": 1,
    "GDP q/q": 1,
    "Industrial Production m/m": 1,
    "Core Durable Goods Orders m/m": 1,
    "Durable Goods Orders m/m": 1,
    "Trade Balance": 1,
    # --- surveys ---
    "ISM Manufacturing PMI": 1,
    "ISM Services PMI": 1,
    "ISM Non-Manufacturing PMI": 1,
    "Flash Manufacturing PMI": 1,
    "Flash Services PMI": 1,
    "Manufacturing PMI": 1,
    "Services PMI": 1,
    "Final Manufacturing PMI": 1,
    "Final Services PMI": 1,
    "German Flash Manufacturing PMI": 1,
    "German Flash Services PMI": 1,
    "German ZEW Economic Sentiment": 1,
    "German Ifo Business Climate": 1,
    "CB Consumer Confidence": 1,
    "Consumer Confidence": 1,
    "Prelim UoM Consumer Sentiment": 1,
    "Revised UoM Consumer Sentiment": 1,
    "Empire State Manufacturing Index": 1,
    "Philly Fed Manufacturing Index": 1,
    # --- housing ---
    "Building Permits": 1,
    "Housing Starts": 1,
    "New Home Sales": 1,
    "Existing Home Sales": 1,
    "Halifax HPI m/m": 1,
    # --- policy rates ---
    "Federal Funds Rate": 1,
    "Official Bank Rate": 1,
    "Main Refinancing Rate": 1,
    "Minimum Bid Rate": 1,
}


# ===========================================================================
# qm.dst_rule.us.v1  /  qm.dst_rule.uk.v1
# ===========================================================================

def _nth_weekday(year: int, month: int, weekday: int, nth: int) -> int:
    """Day-of-month of the nth `weekday` (Mon=0..Sun=6) in `year`-`month`."""
    hits = 0
    for day in range(1, _calendar.monthrange(year, month)[1] + 1):
        if dt.date(year, month, day).weekday() == weekday:
            hits += 1
            if hits == nth:
                return day
    raise ValueError("no such weekday")


def _last_weekday(year: int, month: int, weekday: int) -> int:
    for day in range(_calendar.monthrange(year, month)[1], 0, -1):
        if dt.date(year, month, day).weekday() == weekday:
            return day
    raise ValueError("no such weekday")


def us_dst_interval_utc(year: int) -> Tuple[dt.datetime, dt.datetime]:
    """qm.dst_rule.us.v1 -- 2nd Sunday March 07:00Z .. 1st Sunday Nov 06:00Z."""
    start = dt.datetime(year, 3, _nth_weekday(year, 3, 6, 2), 7, 0, 0, tzinfo=UTC)
    end = dt.datetime(year, 11, _nth_weekday(year, 11, 6, 1), 6, 0, 0, tzinfo=UTC)
    return start, end


def is_us_dst(u: dt.datetime) -> bool:
    start, end = us_dst_interval_utc(u.year)
    return start <= u < end


def darwinex_offset_hours(u: dt.datetime) -> int:
    """Broker offset from UTC in hours for a given UTC instant."""
    return 3 if is_us_dst(u) else 2


def utc_to_broker_epoch(u: dt.datetime) -> int:
    """UTC instant -> the naive-epoch integer MT5 writes for the broker clock."""
    wall = u.astimezone(UTC) + dt.timedelta(hours=darwinex_offset_hours(u.astimezone(UTC)))
    return _calendar.timegm(wall.timetuple())


def broker_epoch_to_utc(raw: int, strict: bool = False) -> dt.datetime:
    """Broker naive epoch -> true UTC.

    Two candidates are tested (+2 and +3) and each is kept only if the US-DST
    rule agrees with the offset that produced it.  In the November-fallback
    hour BOTH survive -- broker wall time is genuinely ambiguous there, once a
    year.  Policy, taken verbatim from ``QM_BrokerToUTC``
    (framework/include/QM/QM_DSTAware.mqh): prefer the standard-time (+2)
    candidate.  ``strict=True`` raises instead, for callers that want to prove
    a timestamp set contains no ambiguous stamps.

    Zero survivors means the broker wall time does not exist (the spring-forward
    gap) and is always an error.
    """
    wall = dt.datetime(1970, 1, 1, tzinfo=UTC) + dt.timedelta(seconds=int(raw))
    survivors = []
    for off in (2, 3):
        cand = wall - dt.timedelta(hours=off)
        if darwinex_offset_hours(cand) == off:
            survivors.append(cand)
    if not survivors:
        raise ValueError("broker_epoch_to_utc: no valid candidate for raw=%d "
                         "(non-existent broker wall time)" % raw)
    if len(survivors) > 1 and strict:
        raise ValueError("broker_epoch_to_utc: %d valid candidates for raw=%d "
                         "(November fallback ambiguity)" % (len(survivors), raw))
    return survivors[0]


def uk_dst_interval_utc(year: int) -> Tuple[dt.datetime, dt.datetime]:
    """qm.dst_rule.uk.v1 -- last Sunday March 01:00Z .. last Sunday Oct 01:00Z."""
    start = dt.datetime(year, 3, _last_weekday(year, 3, 6), 1, 0, 0, tzinfo=UTC)
    end = dt.datetime(year, 10, _last_weekday(year, 10, 6), 1, 0, 0, tzinfo=UTC)
    return start, end


def is_uk_dst(u: dt.datetime) -> bool:
    start, end = uk_dst_interval_utc(u.year)
    return start <= u < end


def london_offset_hours(u: dt.datetime) -> int:
    return 1 if is_uk_dst(u) else 0


def london_local_to_utc(day: dt.date, hour: int, minute: int) -> dt.datetime:
    """London wall clock -> UTC (two-candidate check, same shape as the US rule)."""
    wall = dt.datetime(day.year, day.month, day.day, hour, minute, tzinfo=UTC)
    survivors = []
    for off in (0, 1):
        cand = wall - dt.timedelta(hours=off)
        if london_offset_hours(cand) == off:
            survivors.append(cand)
    if len(survivors) != 1:
        raise ValueError("london_local_to_utc: %d valid candidates" % len(survivors))
    return survivors[0]


# --- fast integer path: UTC epoch -> broker epoch ---------------------------
# Stage 0 probes ~625 offsets per event; building a datetime per probe is the
# hot loop.  The switch instants are precomputed once as a flat, sorted, strictly
# alternating [start, end, start, end, ...] list so the offset is a single
# bisect: an odd insertion index means "after a start, before the next end".
_DST_SWITCH_EPOCHS: List[int] = []


def _dst_switch_table() -> List[int]:
    global _DST_SWITCH_EPOCHS
    if not _DST_SWITCH_EPOCHS:
        acc = []
        for y in range(1990, 2101):
            s, e = us_dst_interval_utc(y)
            acc.append(_calendar.timegm(s.timetuple()))
            acc.append(_calendar.timegm(e.timetuple()))
        _DST_SWITCH_EPOCHS = acc
    return _DST_SWITCH_EPOCHS


def is_us_dst_epoch(u_epoch: int) -> bool:
    """qm.dst_rule.us.v1 on a raw UTC epoch (identical result to is_us_dst)."""
    return bisect.bisect_right(_dst_switch_table(), u_epoch) % 2 == 1


def utc_epoch_to_broker_epoch(u_epoch: int) -> int:
    """Integer twin of utc_to_broker_epoch(); same rule, no datetime objects."""
    return u_epoch + 3600 * (3 if is_us_dst_epoch(u_epoch) else 2)


# --- home timezone of the release (Stage 0b gate A) --------------------------

def home_tz_offset_hours(currency: str, u: dt.datetime) -> Optional[int]:
    """Offset from UTC of the release's HOME timezone at instant ``u``.

    US Eastern switches on the qm.dst_rule.us.v1 instants; Europe/London and
    Europe/Berlin on the qm.dst_rule.uk.v1 instants (the EU and the UK change
    their clocks on the same UTC instants).
    """
    spec = HOME_TZ.get(currency)
    if spec is None:
        return None
    _, std, rule = spec
    dst = is_us_dst(u) if rule == "us" else is_uk_dst(u)
    return std + (1 if dst else 0)


def home_local_minute_of_day(currency: str, u: dt.datetime) -> Optional[int]:
    """Minute-of-day of ``u`` on the release's home wall clock, or None."""
    off = home_tz_offset_hours(currency, u)
    if off is None:
        return None
    local = u + dt.timedelta(hours=off)
    return local.hour * 60 + local.minute


def fmt_hhmm(minute_of_day: Optional[int]) -> Optional[str]:
    if minute_of_day is None:
        return None
    return "%02d:%02d" % (minute_of_day // 60, minute_of_day % 60)


# Integer helpers on the broker naive epoch (fast paths; no datetime objects).
def broker_weekday(epoch: int) -> int:
    """Mon=0 .. Sun=6.  1970-01-01 was a Thursday -> weekday 3."""
    return (epoch // 86400 + 3) % 7


def broker_hour(epoch: int) -> int:
    return (epoch % 86400) // 3600


def broker_minute(epoch: int) -> int:
    return (epoch % 3600) // 60


# ===========================================================================
# Bar series
# ===========================================================================

class BarSeries(object):
    """Dense slot-indexed M5 series with O(1) gap / ATR / return lookups."""

    __slots__ = ("symbol", "path", "t0", "n", "open", "high", "low", "close",
                 "tv", "present", "pres_cum", "atr14", "next_big_gap",
                 "rows", "first_epoch", "last_epoch", "sha256", "nbytes",
                 "atr30_cache")

    def __init__(self, symbol: str, path: str):
        self.symbol = symbol
        self.path = path
        epochs: List[int] = []
        o: List[float] = []
        h: List[float] = []
        lo: List[float] = []
        c: List[float] = []
        v: List[int] = []
        digest = hashlib.sha256()
        nbytes = 0
        with open(path, "rb") as fb:
            while True:
                chunk = fb.read(1 << 20)
                if not chunk:
                    break
                nbytes += len(chunk)
                digest.update(chunk)
        self.sha256 = digest.hexdigest()
        self.nbytes = nbytes
        with open(path, "r", encoding="utf-8", newline="") as f:
            rdr = csv.reader(f)
            header = next(rdr)
            if [x.strip().lower() for x in header] != ["time", "open", "high", "low", "close", "tickvol"]:
                raise ValueError("unexpected bar header in %s: %r" % (path, header))
            for row in rdr:
                if not row:
                    continue
                epochs.append(int(row[0]))
                o.append(float(row[1]))
                h.append(float(row[2]))
                lo.append(float(row[3]))
                c.append(float(row[4]))
                v.append(int(row[5]))
        if not epochs:
            raise ValueError("empty bar file %s" % path)
        for i in range(1, len(epochs)):
            if epochs[i] <= epochs[i - 1]:
                raise ValueError("non-monotonic timestamps in %s at row %d" % (path, i))
        for e in (epochs[0], epochs[-1]):
            if e % SLOT_SECONDS:
                raise ValueError("timestamp not on the 300s grid in %s" % path)
        self.rows = len(epochs)
        self.first_epoch = epochs[0]
        self.last_epoch = epochs[-1]
        self.t0 = epochs[0]
        self.n = (epochs[-1] - epochs[0]) // SLOT_SECONDS + 1
        self.open = [None] * self.n
        self.high = [None] * self.n
        self.low = [None] * self.n
        self.close = [None] * self.n
        self.tv = [None] * self.n
        for i, e in enumerate(epochs):
            if (e - self.t0) % SLOT_SECONDS:
                raise ValueError("timestamp not on the 300s grid in %s: %d" % (path, e))
            k = (e - self.t0) // SLOT_SECONDS
            self.open[k] = o[i]
            self.high[k] = h[i]
            self.low[k] = lo[i]
            self.close[k] = c[i]
            self.tv[k] = v[i]
        self.present = [x is not None for x in self.open]
        # prefix count of present slots
        cum = [0] * (self.n + 1)
        run = 0
        for i in range(self.n):
            if self.present[i]:
                run += 1
            cum[i + 1] = run
        self.pres_cum = cum
        self.atr30_cache = {}
        self._build_atr()
        self._build_gap_index()

    # -- construction helpers -------------------------------------------------
    def _build_atr(self) -> None:
        """ATR(14) on M5, true range against the previous close.

        ``atr14[i]`` uses slots [i-13 .. i] and needs close[i-14], i.e. 15
        consecutive PRESENT slots ending at i.  None otherwise -- never
        interpolated across a gap.
        """
        n = self.n
        atr: List[Optional[float]] = [None] * n
        tr: List[Optional[float]] = [None] * n
        hi = self.high
        lo = self.low
        cl = self.close
        for i in range(1, n):
            if cl[i - 1] is None or hi[i] is None:
                continue
            pc = cl[i - 1]
            tr[i] = max(hi[i] - lo[i], abs(hi[i] - pc), abs(lo[i] - pc))
        window = 14
        run_sum = 0.0
        run_len = 0
        for i in range(n):
            if tr[i] is None:
                run_sum = 0.0
                run_len = 0
                continue
            run_sum += tr[i]
            run_len += 1
            if run_len > window:
                # the value leaving the window is guaranteed non-None
                run_sum -= tr[i - window]
                run_len = window
            if run_len == window:
                atr[i] = run_sum / window
        self.atr14 = atr

    def _build_gap_index(self) -> None:
        """next_big_gap[i] = smallest j >= i inside a missing run of >= GAP_RUN_SLOTS."""
        n = self.n
        runlen = [0] * n
        i = 0
        while i < n:
            if self.present[i]:
                i += 1
                continue
            j = i
            while j < n and not self.present[j]:
                j += 1
            L = j - i
            for k in range(i, j):
                runlen[k] = L
            i = j
        nxt = [n] * (n + 1)
        for i in range(n - 1, -1, -1):
            nxt[i] = i if runlen[i] >= GAP_RUN_SLOTS else nxt[i + 1]
        self.next_big_gap = nxt

    # -- lookups --------------------------------------------------------------
    def slot(self, epoch: int) -> Optional[int]:
        if epoch < self.t0:
            return None
        d = epoch - self.t0
        if d % SLOT_SECONDS:
            return None
        k = d // SLOT_SECONDS
        return k if 0 <= k < self.n else None

    def slot_floor(self, epoch: int) -> Optional[int]:
        if epoch < self.t0:
            return None
        k = (epoch - self.t0) // SLOT_SECONDS
        return k if 0 <= k < self.n else None

    def epoch_of(self, slot: int) -> int:
        return self.t0 + slot * SLOT_SECONDS

    def first_present_at_or_after(self, slot: int, max_scan: int = 12) -> Optional[int]:
        n = self.n
        for k in range(slot, min(slot + max_scan + 1, n)):
            if self.present[k]:
                return k
        return None

    def missing_in(self, a: int, b: int) -> int:
        """Missing slots in [a, b)."""
        a = max(a, 0)
        b = min(b, self.n)
        if b <= a:
            return 0
        return (b - a) - (self.pres_cum[b] - self.pres_cum[a])

    def session_intact(self, a: int, b: int) -> bool:
        """True iff no missing run of >= GAP_RUN_SLOTS overlaps [a, b)."""
        a = max(a, 0)
        b = min(b, self.n)
        if b <= a:
            return False
        return self.next_big_gap[a] >= b


# ===========================================================================
# Calendar
# ===========================================================================

_SCALE = {"K": 1e3, "M": 1e6, "B": 1e9, "T": 1e12}


def parse_calendar_number(raw: str) -> Optional[float]:
    """FF Actual/Forecast/Previous -> float, or None if not a plain number.

    Strips commas and a trailing '%'; applies K/M/B/T scaling.  REJECTS the
    pipe-delimited bond-auction rows ('1.41|3.1'), the malformed '0-0-9'
    shapes, inequalities ('<0.25%') and any non-numeric text.  Nothing is
    imputed.
    """
    if raw is None:
        return None
    s = raw.strip()
    if not s or "|" in s or "<" in s or ">" in s:
        return None
    s = s.replace(",", "")
    if s.endswith("%"):
        s = s[:-1]
    mult = 1.0
    if s and s[-1].upper() in _SCALE:
        mult = _SCALE[s[-1].upper()]
        s = s[:-1]
    if not s or s in ("-", "+"):
        return None
    try:
        return float(s) * mult
    except ValueError:
        return None


class CalendarRow(object):
    __slots__ = ("currency", "impact", "event", "raw_utc", "actual", "forecast")

    def __init__(self, currency, impact, event, raw_utc, actual, forecast):
        self.currency = currency
        self.impact = impact
        self.event = event
        self.raw_utc = raw_utc
        self.actual = actual
        self.forecast = forecast


def load_calendar(path: str) -> Tuple[List[CalendarRow], str, int, int]:
    digest = hashlib.sha256()
    nbytes = 0
    with open(path, "rb") as fb:
        while True:
            chunk = fb.read(1 << 20)
            if not chunk:
                break
            nbytes += len(chunk)
            digest.update(chunk)
    rows: List[CalendarRow] = []
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        rdr = csv.DictReader(f)
        cols = [c.strip() for c in (rdr.fieldnames or [])]
        for need in ("DateTime_UTC", "Currency", "Impact", "Event"):
            if need not in cols:
                raise ValueError("calendar %s lacks column %s (has %r)" % (path, need, cols))
        for r in rdr:
            ts = (r.get("DateTime_UTC") or "").strip()
            if not ts:
                continue
            try:
                d = dt.datetime.strptime(ts, "%Y.%m.%d %H:%M")
            except ValueError:
                try:
                    d = dt.datetime.strptime(ts, "%Y-%m-%d %H:%M:%S")
                except ValueError:
                    continue
            rows.append(CalendarRow(
                (r.get("Currency") or "").strip(),
                (r.get("Impact") or "").strip(),
                (r.get("Event") or "").strip(),
                d.replace(tzinfo=UTC),
                parse_calendar_number(r.get("Actual")),
                parse_calendar_number(r.get("Forecast")),
            ))
    rows.sort(key=lambda x: (x.raw_utc, x.currency, x.event))
    return rows, digest.hexdigest(), nbytes, len(rows)


# ===========================================================================
# small stats helpers (no numpy dependency; deterministic)
# ===========================================================================

def _mean(xs: Sequence[float]) -> float:
    return sum(xs) / float(len(xs))


def _pvar(xs: Sequence[float]) -> float:
    if len(xs) < 1:
        return 0.0
    m = _mean(xs)
    return sum((x - m) ** 2 for x in xs) / float(len(xs))


def _svar(xs: Sequence[float]) -> float:
    if len(xs) < 2:
        return 0.0
    m = _mean(xs)
    return sum((x - m) ** 2 for x in xs) / float(len(xs) - 1)


def _median(xs: Sequence[float]) -> float:
    s = sorted(xs)
    n = len(s)
    if n == 0:
        return float("nan")
    if n % 2:
        return s[n // 2]
    return 0.5 * (s[n // 2 - 1] + s[n // 2])


def _ols_slope(xs: Sequence[float], ys: Sequence[float]) -> Tuple[Optional[float], Optional[float]]:
    n = len(xs)
    if n < 3:
        return None, None
    mx = _mean(xs)
    my = _mean(ys)
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx <= 0.0:
        return None, None
    sxy = sum((xs[i] - mx) * (ys[i] - my) for i in range(n))
    beta = sxy / sxx
    alpha = my - beta * mx
    sse = sum((ys[i] - alpha - beta * xs[i]) ** 2 for i in range(n))
    if n <= 2:
        return beta, None
    se = math.sqrt(sse / (n - 2) / sxx) if sxx > 0 else None
    return beta, se


def _sign(x: float) -> int:
    return 1 if x > 0 else (-1 if x < 0 else 0)


# ===========================================================================
# deterministic writers
# ===========================================================================

def fmt(x) -> str:
    if x is None:
        return ""
    if isinstance(x, bool):
        return "1" if x else "0"
    if isinstance(x, float):
        if x != x or x in (float("inf"), float("-inf")):
            return ""
        return "%.10g" % x
    return str(x)


def write_csv(path: str, header: Sequence[str], rows: Sequence[Sequence]) -> Tuple[str, int]:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(list(header))
        for r in rows:
            w.writerow([fmt(x) for x in r])
    return sha256_file(path), len(rows)


def write_json(path: str, obj) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
        f.write("\n")
    return sha256_file(path)


def sha256_file(path: str) -> str:
    d = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(1 << 20)
            if not b:
                break
            d.update(b)
    return d.hexdigest()


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def sha256_file_lf(path: str) -> str:
    """sha256 of the file with CRLF normalised to LF.

    Repo-managed text files are checked out with CRLF on Windows when
    core.autocrlf is on, so the on-disk sha256 of the SAME committed content
    differs between a worktree and the canonical checkout.  Recording the
    LF-normalised hash alongside the raw one makes the manifest comparable
    across checkouts (the repo's documented Pin-SHA/LF-blob trap).
    """
    with open(path, "rb") as f:
        return hashlib.sha256(f.read().replace(b"\r\n", b"\n")).hexdigest()


def _clean_floats(obj):
    """Replace non-finite floats with None so json stays strict-parseable."""
    if isinstance(obj, dict):
        return {k: _clean_floats(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_clean_floats(v) for v in obj]
    if isinstance(obj, float):
        if obj != obj or obj in (float("inf"), float("-inf")):
            return None
        return obj
    return obj


# ===========================================================================
# STAGE 0 -- empirical timestamp calibration
# ===========================================================================

CALIB_HEADER = [
    "currency", "event", "probe_symbol", "n_obs", "peak_offset_min", "peak_ratio",
    "baseline_ratio", "ratio_at_zero", "second_peak_ratio", "sharpness",
    "offset_stability_frac", "peak_offset_2018_2021", "peak_offset_2022_2025",
    "peak_offset_first_half", "peak_offset_second_half", "split_year",
    "calib_status", "applied_offset_min",
    # --- Stage 0b, per-event instant verification -------------------------
    "home_tz", "modal_home_local_hhmm", "n_instant_verified",
    "n_voided_home_clock", "n_voided_local_peak", "verified_frac",
]

CALIB_EVENTS_HEADER = [
    "currency", "event", "raw_datetime_utc", "applied_offset_min", "release_utc",
    "home_tz", "home_local_hhmm", "modal_home_local_hhmm", "local_peak_offset_min",
    "local_peak_ratio", "local_prominent", "instant_verified", "void_reason",
]


def _argmax_offset(offsets: Sequence[int], values: Sequence[float]) -> int:
    best_i = 0
    best_v = values[0]
    for i in range(1, len(values)):
        v = values[i]
        if v > best_v or (v == best_v and abs(offsets[i]) < abs(offsets[best_i])):
            best_v = v
            best_i = i
    return offsets[best_i]


def run_stage0(cal_rows: List[CalendarRow], bars: Dict[str, BarSeries], cfg) -> Tuple[List[List], Dict[Tuple[str, str], Optional[int]], Dict[str, int], Dict[Tuple[str, str, int], Dict], List[List]]:
    """Recover the release instant per (currency, event) group from tickvol,
    then VERIFY each individual instant (Stage 0b) and void the ones the group
    constant misplaces.

    The offset grid is probed in **UTC space**: the candidate instant is
    ``raw_utc + off`` and its probe anchor is ``utc_to_broker_epoch`` of that,
    which is exactly the epoch EDGE-1 will later measure at.  Probing
    ``broker_epoch(raw) + off`` instead would name a DIFFERENT instant (by one
    hour) whenever the raw stamp and the shifted stamp straddle a US-DST
    boundary -- the profile would then be built at one instant and the
    statistic measured at another.
    """
    offsets = list(range(-cfg.calib_max_offset_min, cfg.calib_max_offset_min + 1, CALIB_STEP_MIN))
    zero_i = offsets.index(0)
    groups: Dict[Tuple[str, str], List[CalendarRow]] = {}
    for r in cal_rows:
        if r.impact != "High" or r.currency not in EDGE1_CURRENCIES:
            continue
        y = r.raw_utc.year
        if y < cfg.calib_year_lo or y > cfg.calib_year_hi:
            continue
        groups.setdefault((r.currency, r.event), []).append(r)

    out_rows: List[List] = []
    calib_event_rows: List[List] = []
    applied: Dict[Tuple[str, str], Optional[int]] = {}
    verify: Dict[Tuple[str, str, int], Dict] = {}
    counts = {"examined": 0, "calibrated": 0, "no_signature": 0, "ambiguous": 0,
              "underpowered": 0, "offset_nonzero": 0,
              "events_verified": 0, "events_voided_home_clock": 0,
              "events_voided_local_peak": 0, "groups_dropped_verify_frac": 0}

    local_grid = list(range(-CALIB_EVENT_LOCAL_GRID_MIN, CALIB_EVENT_LOCAL_GRID_MIN + 1,
                            CALIB_STEP_MIN))

    for key in sorted(groups.keys()):
        currency, event = key
        evs = groups[key]
        probe = EDGE1_PROBE_SYMBOL[currency]
        series = bars.get(probe)
        if series is None:
            continue
        counts["examined"] += 1
        home_tz = HOME_TZ[currency][0]
        per_event_profiles: List[Tuple[int, List[float]]] = []
        for r in evs:
            raw_epoch = _calendar.timegm(r.raw_utc.timetuple())
            vals: List[Optional[float]] = []
            filled = 0
            for off in offsets:
                s = series.slot(utc_epoch_to_broker_epoch(raw_epoch + off * 60))
                tvv = series.tv[s] if (s is not None and series.tv[s] is not None) else None
                if tvv is None:
                    vals.append(None)
                else:
                    vals.append(float(tvv))
                    filled += 1
            if filled < CALIB_MIN_PROFILE_FILL * len(offsets):
                continue
            present = [v for v in vals if v is not None]
            med = _median(present)
            if med <= 0:
                continue
            norm = [(v / med) if v is not None else None for v in vals]
            per_event_profiles.append((r.raw_utc.year, norm, r.raw_utc))

        n_obs = len(per_event_profiles)
        if n_obs == 0:
            applied[key] = None
            counts["underpowered"] += 1
            out_rows.append([currency, event, probe, 0, None, None, None, None, None,
                             None, None, None, None, None, None, None,
                             "UNDERPOWERED", None,
                             home_tz, None, 0, 0, 0, None])
            continue

        per_event_profiles.sort(key=lambda x: x[2])

        def mean_profile(sel) -> List[float]:
            acc = [0.0] * len(offsets)
            cnt = [0] * len(offsets)
            for item in sel:
                prof = item[1]
                for i, v in enumerate(prof):
                    if v is not None:
                        acc[i] += v
                        cnt[i] += 1
            return [(acc[i] / cnt[i]) if cnt[i] else 0.0 for i in range(len(offsets))]

        prof = mean_profile(per_event_profiles)
        peak_off = _argmax_offset(offsets, prof)
        peak_i = offsets.index(peak_off)
        peak_ratio = prof[peak_i]
        baseline_ratio = _median(prof)
        ratio_zero = prof[zero_i]
        outside = [prof[i] for i in range(len(offsets)) if abs(offsets[i] - peak_off) > CALIB_SHARPNESS_EXCL_MIN]
        second_peak = max(outside) if outside else 0.0
        sharpness = (peak_ratio / second_peak) if second_peak > 0 else float("inf")
        stable = 0
        for item in per_event_profiles:
            p = item[1]
            own = _argmax_offset(offsets, [(v if v is not None else -1.0) for v in p])
            if abs(own - peak_off) <= 10:
                stable += 1
        stability = stable / float(n_obs)

        # Sub-era stability.  The spec split at 2022; that split is empty on any
        # sample that does not straddle it, so the DECISION uses the group's own
        # chronological midpoint (equal power in both halves) and the year-based
        # split is emitted alongside as the spec-named audit column.
        early = [x for x in per_event_profiles if x[0] < cfg.calib_era_split_year]
        late = [x for x in per_event_profiles if x[0] >= cfg.calib_era_split_year]
        peak_early = _argmax_offset(offsets, mean_profile(early)) if early else None
        peak_late = _argmax_offset(offsets, mean_profile(late)) if late else None
        mid = n_obs // 2
        h1 = per_event_profiles[:mid]
        h2 = per_event_profiles[mid:]
        peak_h1 = _argmax_offset(offsets, mean_profile(h1)) if h1 else None
        peak_h2 = _argmax_offset(offsets, mean_profile(h2)) if h2 else None

        if n_obs < cfg.calib_min_obs:
            status = "UNDERPOWERED"
        elif not (peak_ratio >= CALIB_MIN_PEAK_RATIO
                  and baseline_ratio > 0
                  and peak_ratio / baseline_ratio >= CALIB_MIN_PEAK_OVER_BASE
                  and sharpness >= CALIB_MIN_SHARPNESS
                  and stability >= CALIB_MIN_STABILITY):
            status = "NO_SIGNATURE"
        elif (peak_h1 is None or peak_h2 is None
              or abs(peak_h1 - peak_h2) > CALIB_MAX_ERA_DISAGREE_MIN):
            status = "AMBIGUOUS"
        else:
            status = "CALIBRATED"

        applied_off = peak_off if status == "CALIBRATED" else None

        # -------- STAGE 0b: per-event instant verification -----------------
        n_ver = 0
        n_void_clock = 0
        n_void_peak = 0
        modal_local: Optional[int] = None
        ev_rows_this: List[List] = []
        if applied_off is not None:
            # gate A -- the modal home wall-clock minute-of-day of the group
            locals_: List[Tuple[CalendarRow, dt.datetime, Optional[int]]] = []
            hist: Dict[int, int] = {}
            for r in evs:
                rel = r.raw_utc + dt.timedelta(minutes=applied_off)
                lm = home_local_minute_of_day(currency, rel)
                locals_.append((r, rel, lm))
                if lm is not None:
                    hist[lm] = hist.get(lm, 0) + 1
            if hist:
                modal_local = sorted(hist.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]

            for r, rel, lm in locals_:
                raw_epoch = _calendar.timegm(r.raw_utc.timetuple())
                anchor = utc_epoch_to_broker_epoch(raw_epoch + applied_off * 60)
                # gate B -- the event's own local tickvol peak
                lvals: List[Optional[float]] = []
                for off in local_grid:
                    s = series.slot(anchor + off * 60)
                    tvv = series.tv[s] if (s is not None and series.tv[s] is not None) else None
                    lvals.append(float(tvv) if tvv is not None else None)
                pres = [v for v in lvals if v is not None]
                lpeak_off: Optional[int] = None
                lpeak_ratio: Optional[float] = None
                prominent = 0
                if pres:
                    lmed = _median(pres)
                    if lmed > 0:
                        lnorm = [(v / lmed) if v is not None else -1.0 for v in lvals]
                        lpeak_off = _argmax_offset(local_grid, lnorm)
                        lpeak_ratio = max(lnorm)
                        prominent = 1 if lpeak_ratio >= CALIB_EVENT_LOCAL_PROMINENCE else 0

                reason = ""
                if modal_local is not None and lm is not None and lm != modal_local:
                    reason = "home_clock_mismatch"
                    n_void_clock += 1
                elif (prominent and lpeak_off is not None
                      and abs(lpeak_off) > CALIB_EVENT_LOCAL_TOL_MIN):
                    reason = "local_peak_elsewhere"
                    n_void_peak += 1
                ok = 1 if not reason else 0
                n_ver += ok
                verify[(currency, event, raw_epoch)] = {
                    "instant_verified": ok, "void_reason": reason,
                    "home_local_min": lm, "modal_home_local_min": modal_local,
                    "local_peak_offset_min": lpeak_off, "home_tz": home_tz,
                }
                ev_rows_this.append([
                    currency, event, r.raw_utc.strftime("%Y.%m.%d %H:%M"), applied_off,
                    rel.strftime("%Y-%m-%dT%H:%M:%SZ"), home_tz, fmt_hhmm(lm),
                    fmt_hhmm(modal_local), lpeak_off, lpeak_ratio, prominent, ok, reason,
                ])

            ver_frac = n_ver / float(len(evs)) if evs else 0.0
            if ver_frac < CALIB_MIN_VERIFIED_FRAC:
                # the group constant explains less than half of its own rows:
                # the displacement is not a constant at all -> drop the group.
                status = "AMBIGUOUS"
                applied_off = None
                counts["groups_dropped_verify_frac"] += 1
                for (c, e, re_) in list(verify.keys()):
                    if (c, e) == key:
                        verify[(c, e, re_)]["instant_verified"] = 0
                        verify[(c, e, re_)]["void_reason"] = "group_verify_frac"
                for row in ev_rows_this:
                    row[-2] = 0
                    row[-1] = "group_verify_frac"
                n_ver = 0
            else:
                counts["events_verified"] += n_ver
                counts["events_voided_home_clock"] += n_void_clock
                counts["events_voided_local_peak"] += n_void_peak
        calib_event_rows.extend(ev_rows_this)

        counts[{"CALIBRATED": "calibrated", "NO_SIGNATURE": "no_signature",
                "AMBIGUOUS": "ambiguous", "UNDERPOWERED": "underpowered"}[status]] += 1
        applied[key] = applied_off
        if status == "CALIBRATED" and applied_off not in (None, 0):
            counts["offset_nonzero"] += 1

        out_rows.append([currency, event, probe, n_obs, peak_off, peak_ratio, baseline_ratio,
                         ratio_zero, second_peak,
                         (None if sharpness == float("inf") else sharpness),
                         stability, peak_early, peak_late, peak_h1, peak_h2,
                         cfg.calib_era_split_year, status, applied_off,
                         home_tz, fmt_hhmm(modal_local), n_ver, n_void_clock, n_void_peak,
                         (n_ver / float(len(evs)) if evs else None)])

    out_rows.sort(key=lambda r: (r[0], r[1]))
    calib_event_rows.sort(key=lambda r: (r[0], r[1], r[2]))
    return out_rows, applied, counts, verify, calib_event_rows


# ===========================================================================
# EDGE-1
# ===========================================================================

EVENTS_HEADER = [
    "event_id", "cluster_id", "currency", "event", "raw_datetime_utc",
    "applied_offset_min", "release_utc", "us_dst", "release_broker_epoch",
    "year", "weekday", "broker_hhmm", "era", "actual", "forecast", "surprise",
    "surprise_n_3y", "surprise_mean_3y", "surprise_sd_3y", "surprise_z",
    "polarity", "direction", "is_confounded",
    "instant_verified", "instant_void_reason", "home_tz", "home_local_hhmm",
    "local_peak_offset_min", "cluster_rank", "cluster_is_primary",
    "cluster_direction", "cluster_dir_rule",
]

EW_HEADER = (["event_id", "cluster_id", "currency", "era", "symbol", "currency_leg",
              "trade_dir", "cluster_trade_dir", "entry_delay_min", "entry_bar_epoch",
              "entry_lag_sec", "entry_price"]
             + ["px_p%d" % h for h in EDGE1_HORIZONS]
             + ["ret_p%d" % h for h in EDGE1_HORIZONS]
             + ["ret_raw_p%d" % h for h in EDGE1_HORIZONS]
             + ["mae_p90_bp", "mfe_p90_bp", "atr_m5_bp", "bars_missing",
                "session_intact", "window_ok", "weekday", "broker_hour",
                "minute_of_hour"])

BASELINE_HEADER = (["baseline_id", "symbol", "era", "weekday", "broker_hour",
                    "minute_of_hour", "bar_epoch", "entry_price"]
                   + ["ret_p%d" % h for h in EDGE1_HORIZONS]
                   + ["atr_m5_bp", "bars_missing", "window_ok"])

BASELINE_CELLS_HEADER = (["symbol", "era", "weekday", "broker_hour", "minute_of_hour", "n"]
                         + ["mu0_p%d_bp" % h for h in EDGE1_HORIZONS]
                         + ["sigma0_p%d_bp" % h for h in EDGE1_HORIZONS])


class Edge1Event(object):
    __slots__ = ("event_id", "cluster_id", "currency", "event", "raw_utc",
                 "applied_offset", "release_utc", "release_epoch", "era",
                 "surprise_z", "polarity", "direction", "is_confounded",
                 "instant_verified", "rank")


def _window_metrics(series: BarSeries, entry_slot: int, horizons: Sequence[int]):
    """Returns (entry_price, {h: px}, mae, mfe, bars_missing, intact, ok)."""
    max_h = max(horizons)
    span = max_h * 60 // SLOT_SECONDS
    entry_price = series.open[entry_slot]
    if entry_price is None or entry_price <= 0:
        return None
    end_slot = entry_slot + span
    if end_slot >= series.n:
        return None
    px = {}
    for h in horizons:
        s = entry_slot + (h * 60) // SLOT_SECONDS - 1
        px[h] = series.close[s] if 0 <= s < series.n else None
    bars_missing = series.missing_in(entry_slot, end_slot + 1)
    intact = series.session_intact(entry_slot, end_slot + 1)
    return entry_price, px, bars_missing, intact


def _mae_mfe(series: BarSeries, entry_slot: int, entry_price: float, minutes: int,
             direction: int) -> Tuple[Optional[float], Optional[float]]:
    span = minutes * 60 // SLOT_SECONDS
    hi = None
    lo = None
    for s in range(entry_slot, min(entry_slot + span, series.n)):
        if series.high[s] is None:
            continue
        hi = series.high[s] if hi is None else max(hi, series.high[s])
        lo = series.low[s] if lo is None else min(lo, series.low[s])
    if hi is None:
        return None, None
    up = 1e4 * (hi - entry_price) / entry_price
    dn = 1e4 * (lo - entry_price) / entry_price
    if direction >= 0:
        return dn, up          # mae (negative), mfe (positive)
    return -up, -dn


class Cell(object):
    """Frozen baseline cell with prefix sums for O(log n) +/-3d exclusion."""

    __slots__ = ("epochs", "psum", "psumsq", "n")

    def __init__(self, epochs: List[int], rets: Dict[int, List[float]]):
        self.epochs = epochs
        self.n = len(epochs)
        self.psum = {}
        self.psumsq = {}
        for h, xs in rets.items():
            s = [0.0] * (self.n + 1)
            q = [0.0] * (self.n + 1)
            acc = 0.0
            acq = 0.0
            for i, x in enumerate(xs):
                acc += x
                acq += x * x
                s[i + 1] = acc
                q[i + 1] = acq
            self.psum[h] = s
            self.psumsq[h] = q

    def stats(self, h: int, excl_lo: Optional[int], excl_hi: Optional[int]):
        """(n, mean, population sd) excluding bars with epoch in [excl_lo, excl_hi]."""
        n = self.n
        s = self.psum[h][n]
        q = self.psumsq[h][n]
        if excl_lo is not None:
            a = bisect.bisect_left(self.epochs, excl_lo)
            b = bisect.bisect_right(self.epochs, excl_hi)
            n -= (b - a)
            s -= (self.psum[h][b] - self.psum[h][a])
            q -= (self.psumsq[h][b] - self.psumsq[h][a])
        if n <= 0:
            return 0, None, None
        mu = s / n
        var = max(q / n - mu * mu, 0.0)
        return n, mu, math.sqrt(var)


def run_edge1(bars: Dict[str, BarSeries], cal_rows, calib_rows, applied, calib_counts,
              verify: Dict[Tuple[str, str, int], Dict],
              polarity: Dict[str, int], polarity_sha: str, cfg, out_dir: str,
              calib_event_rows: List[List]) -> Dict:
    symbol_map = EDGE1_SYMBOL_MAP_GBPJPY if cfg.edge1_include_gbpjpy else EDGE1_SYMBOL_MAP_BASE
    universe = sorted({s for v in symbol_map.values() for s in v})
    missing = [s for s in universe if s not in bars]
    if missing:
        raise SystemExit("EDGE-1 needs bar series for %r; missing %r" % (universe, missing))

    counts = {"events_total": 0, "events_z_computable": 0, "event_windows_total": 0,
              "dropped_unparseable": 0, "dropped_not_calibrated": 0,
              "dropped_no_polarity": 0, "dropped_window_not_ok": 0,
              "dropped_confounded": 0, "dropped_thin_cell": 0,
              "dropped_instant_unverified": 0, "dropped_direction_conflict": 0,
              "surprise_history_seed_rows": 0, "calibrated_instants": 0}

    # ---- 1. calibrated high-impact instants (for confounding + baseline excl.)
    # An event whose INSTANT failed Stage 0b is excluded from the tradeable set
    # but its applied instant is deliberately KEPT in this list: something did
    # happen near there, and the news-exclusion halo must stay conservative.
    calibrated_instants: List[int] = []
    cal_sel: List[Tuple[CalendarRow, int]] = []
    cal_hist: List[Tuple[CalendarRow, int]] = []      # history seed, NO window filter
    for r in cal_rows:
        if r.impact != "High" or r.currency not in EDGE1_CURRENCIES:
            continue
        off = applied.get((r.currency, r.event))
        if off is None:
            continue
        rel = r.raw_utc + dt.timedelta(minutes=off)
        cal_hist.append((r, off))
        if not (cfg.is_start <= rel.date() <= cfg.oos_end):
            continue
        cal_sel.append((r, off))
        calibrated_instants.append(utc_to_broker_epoch(rel))
    calibrated_instants = sorted(set(calibrated_instants))
    counts["calibrated_instants"] = len(calibrated_instants)
    counts["surprise_history_seed_rows"] = len(cal_hist) - len(cal_sel)

    # ---- 2. surprise z per (currency, event)
    # The z-history is accumulated over the FULL calendar, not over the study
    # window: truncating the stream at is_start silently discards the first
    # year of events (no history yet) and gives every early event a shorter
    # window than the declared 3 years.  Rows before is_start SEED the history
    # and are never measured.
    by_group: Dict[Tuple[str, str], List[Tuple[CalendarRow, int, dt.datetime]]] = {}
    for r, off in cal_hist:
        rel = r.raw_utc + dt.timedelta(minutes=off)
        by_group.setdefault((r.currency, r.event), []).append((r, off, rel))

    events: List[Edge1Event] = []
    event_rows: List[List] = []
    surprise_n_hist: List[int] = []
    for key in sorted(by_group.keys()):
        currency, ev_name = key
        items = sorted(by_group[key], key=lambda x: x[2])
        surprises: List[Tuple[dt.datetime, float]] = []
        for r, off, rel in items:
            in_window = (cfg.is_start <= rel.date() <= cfg.oos_end)
            if in_window:
                counts["events_total"] += 1
            actual = r.actual
            forecast = r.forecast
            surprise = None
            if actual is not None and forecast is not None:
                surprise = actual - forecast
            elif in_window:
                counts["dropped_unparseable"] += 1
            lo = rel - dt.timedelta(days=EDGE1_SURPRISE_WINDOW_DAYS)
            hist = [s for (t, s) in surprises if lo <= t < rel]
            n3 = len(hist)
            m3 = _mean(hist) if n3 else None
            sd3 = math.sqrt(_pvar(hist)) if n3 else None
            z = None
            if surprise is not None and n3 >= cfg.surprise_min_history and sd3 and sd3 > 0:
                z = (surprise - m3) / sd3
                if in_window:
                    counts["events_z_computable"] += 1
            if surprise is not None:
                surprises.append((rel, surprise))
            if not in_window:
                continue
            if z is not None:
                surprise_n_hist.append(n3)

            pol = polarity.get(ev_name)
            if pol is None:
                counts["dropped_no_polarity"] += 1
            vrec = verify.get((currency, ev_name, _calendar.timegm(r.raw_utc.timetuple())), {})
            inst_ok = int(vrec.get("instant_verified", 1))
            if not inst_ok:
                counts["dropped_instant_unverified"] += 1
            direction = None
            if z is not None and pol is not None and _sign(z) != 0 and inst_ok:
                direction = _sign(z) * pol

            year = rel.year
            era = "IS" if cfg.is_start.year <= year <= cfg.is_end.year else (
                "OOS" if cfg.oos_start.year <= year <= cfg.oos_end.year else None)
            if era is None:
                continue
            rel_epoch_exact = utc_to_broker_epoch(rel)
            rel_epoch = (rel_epoch_exact // SLOT_SECONDS) * SLOT_SECONDS
            eid = hashlib.sha1(("%s|%s|%s" % (currency, ev_name,
                                              rel.strftime("%Y-%m-%dT%H:%M:%SZ"))).encode("utf-8")).hexdigest()[:12]
            cid = hashlib.sha1(("%s|%d" % (currency, rel_epoch)).encode("utf-8")).hexdigest()[:12]
            # confounded: another calibrated instant within +/- CONFOUND at a
            # different time
            wlo = rel_epoch_exact - EDGE1_CONFOUND_MIN * 60
            whi = rel_epoch_exact + EDGE1_CONFOUND_MIN * 60
            a = bisect.bisect_left(calibrated_instants, wlo)
            b = bisect.bisect_right(calibrated_instants, whi)
            others = [t for t in calibrated_instants[a:b] if t != rel_epoch_exact]
            confounded = 1 if others else 0

            e = Edge1Event()
            e.event_id = eid
            e.cluster_id = cid
            e.currency = currency
            e.event = ev_name
            e.raw_utc = r.raw_utc
            e.applied_offset = off
            e.release_utc = rel
            e.release_epoch = rel_epoch_exact
            e.era = era
            e.surprise_z = z
            e.polarity = pol
            e.direction = direction
            e.is_confounded = confounded
            e.instant_verified = inst_ok
            e.rank = CLUSTER_PRIMARY_RANK.get(ev_name)
            events.append(e)

            event_rows.append([
                eid, cid, currency, ev_name, r.raw_utc.strftime("%Y.%m.%d %H:%M"), off,
                rel.strftime("%Y-%m-%dT%H:%M:%SZ"), 1 if is_us_dst(rel) else 0, rel_epoch,
                year, broker_weekday(rel_epoch), "%02d:%02d" % (broker_hour(rel_epoch), broker_minute(rel_epoch)),
                era, actual, forecast, surprise, n3, m3, sd3, z, pol, direction, confounded,
                inst_ok, vrec.get("void_reason", ""), vrec.get("home_tz"),
                fmt_hhmm(vrec.get("home_local_min")), vrec.get("local_peak_offset_min"),
                e.rank, None, None, EDGE1_DIR_RULE_PRIMARY,
            ])

    # ---- 2b. cluster direction resolution (sealed rule; see CLUSTER_PRIMARY_RANK)
    clusters: Dict[str, List[Edge1Event]] = {}
    for e in events:
        clusters.setdefault(e.cluster_id, []).append(e)

    def resolve_cluster(members: List[Edge1Event], rule: str):
        """(direction, primary_event or None, conflict) under one sealed rule."""
        with_dir = [m for m in members if m.direction is not None]
        if not with_dir:
            return None, None, False
        if rule == "primary_event_rank":
            ranked = [m for m in with_dir if m.rank is not None]
            if ranked:
                prim = sorted(ranked, key=lambda m: (m.rank, m.event))[0]
                return prim.direction, prim, False
            dirs = {m.direction for m in with_dir}
            if len(dirs) == 1:
                return with_dir[0].direction, None, False
            return None, None, True
        if rule == "unanimous_only":
            dirs = {m.direction for m in with_dir}
            if len(dirs) == 1:
                return with_dir[0].direction, None, False
            return None, None, True
        return None, None, False      # row_mean: no cluster-level direction

    cluster_dir: Dict[str, Optional[int]] = {}
    cluster_primary: Dict[str, Optional[str]] = {}
    for cid in sorted(clusters.keys()):
        d, prim, conflict = resolve_cluster(clusters[cid], EDGE1_DIR_RULE_PRIMARY)
        cluster_dir[cid] = d
        cluster_primary[cid] = prim.event_id if prim is not None else None
        if conflict:
            counts["dropped_direction_conflict"] += 1
    for row in event_rows:
        cid = row[1]
        row[-3] = 1 if cluster_primary.get(cid) == row[0] else 0
        row[-2] = cluster_dir.get(cid)

    event_rows.sort(key=lambda r: (r[8], r[2], r[3]))

    # ---- 3. event windows
    tradeable = [e for e in events if e.direction is not None]
    ew_rows: List[List] = []
    ew_recs: List[Dict] = []
    needed_cells: Dict[str, set] = {s: set() for s in universe}
    for e in sorted(tradeable, key=lambda x: (x.release_epoch, x.currency, x.event)):
        for symbol in symbol_map[e.currency]:
            base, quote = symbol[:3], symbol[3:6]
            if e.currency == base:
                leg = 1
            elif e.currency == quote:
                leg = -1
            else:
                continue
            trade_dir = e.direction * leg
            series = bars[symbol]
            for delay in EDGE1_GRID_DELAY:
                target = e.release_epoch + delay * 60
                tslot = series.slot_floor(target)
                if tslot is None:
                    continue
                if series.epoch_of(tslot) < target:
                    tslot += 1
                es = series.first_present_at_or_after(tslot, max_scan=1)
                if es is None:
                    continue
                lag = series.epoch_of(es) - target
                wm = _window_metrics(series, es, EDGE1_HORIZONS)
                if wm is None:
                    continue
                entry_price, px, bars_missing, intact = wm
                rets = {}
                rets_raw = {}
                for h in EDGE1_HORIZONS:
                    p = px[h]
                    rets_raw[h] = None if p is None else 1e4 * (p - entry_price) / entry_price
                    rets[h] = None if p is None else rets_raw[h] * trade_dir
                # ATR(14) over the 14 M5 bars ending strictly before release
                rslot = series.slot_floor(e.release_epoch)
                atr_bp = None
                if rslot is not None and rslot - 1 >= 0:
                    a = series.atr14[rslot - 1]
                    if a is not None:
                        atr_bp = 1e4 * a / entry_price
                mae, mfe = _mae_mfe(series, es, entry_price, 90, trade_dir)
                ok = (lag < SLOT_SECONDS and bars_missing <= 3 and intact
                      and atr_bp is not None and all(rets[h] is not None for h in EDGE1_HORIZONS))
                bep = series.epoch_of(es)
                wd, hh, mm = broker_weekday(bep), broker_hour(bep), broker_minute(bep)
                if ok:
                    needed_cells[symbol].add((wd, hh, mm))
                cdir = cluster_dir.get(e.cluster_id)
                ctd = None if cdir is None else cdir * leg
                ew_rows.append([e.event_id, e.cluster_id, e.currency, e.era, symbol, leg,
                                trade_dir, ctd, delay, bep, lag, entry_price]
                               + [px[h] for h in EDGE1_HORIZONS]
                               + [rets[h] for h in EDGE1_HORIZONS]
                               + [rets_raw[h] for h in EDGE1_HORIZONS]
                               + [mae, mfe, atr_bp, bars_missing, 1 if intact else 0,
                                  1 if ok else 0, wd, hh, mm])
                ew_recs.append({"event": e, "symbol": symbol, "delay": delay,
                                "leg": leg, "trade_dir": trade_dir, "rets": rets,
                                "rets_raw": rets_raw, "ok": ok,
                                "cell": (wd, hh, mm), "entry_epoch": bep})
    counts["event_windows_total"] = len(ew_rows)
    counts["dropped_window_not_ok"] = sum(1 for r in ew_recs if not r["ok"])
    ew_rows.sort(key=lambda r: (r[0], r[4], r[8]))

    # ---- 4. baseline (IS only), restricted to the cells events actually use
    news_slots: Dict[str, List[int]] = {}
    for symbol in universe:
        series = bars[symbol]
        marks = [False] * series.n
        halo = EDGE1_BASELINE_NEWS_EXCL_MIN * 60 // SLOT_SECONDS
        for t in calibrated_instants:
            s = series.slot_floor(t)
            if s is None:
                continue
            for k in range(max(0, s - halo), min(series.n, s + halo + 1)):
                marks[k] = True
        news_slots[symbol] = marks

    is_lo = _calendar.timegm(dt.datetime(cfg.is_start.year, cfg.is_start.month, cfg.is_start.day).timetuple())
    is_hi = _calendar.timegm(dt.datetime(cfg.is_end.year, cfg.is_end.month, cfg.is_end.day, 23, 59, 59).timetuple())

    baseline_rows: List[List] = []
    cells: Dict[Tuple[str, int, int, int], Cell] = {}
    cell_cells_rows: List[List] = []
    for symbol in universe:
        series = bars[symbol]
        want = needed_cells[symbol]
        if not want:
            continue
        marks = news_slots[symbol]
        buckets: Dict[Tuple[int, int, int], Tuple[List[int], Dict[int, List[float]]]] = {}
        s_lo = series.slot_floor(is_lo) or 0
        s_hi = series.slot_floor(is_hi)
        s_hi = series.n - 1 if s_hi is None else min(s_hi, series.n - 1)
        for s in range(max(s_lo, 0), s_hi + 1):
            if not series.present[s] or marks[s]:
                continue
            bep = series.epoch_of(s)
            key = (broker_weekday(bep), broker_hour(bep), broker_minute(bep))
            if key not in want:
                continue
            wm = _window_metrics(series, s, EDGE1_HORIZONS)
            if wm is None:
                continue
            entry_price, px, bars_missing, intact = wm
            if bars_missing > 3 or not intact:
                continue
            if any(px[h] is None for h in EDGE1_HORIZONS):
                continue
            atr = series.atr14[s - 1] if s - 1 >= 0 else None
            if atr is None:
                continue
            rets = {h: 1e4 * (px[h] - entry_price) / entry_price for h in EDGE1_HORIZONS}
            eb, rd = buckets.setdefault(key, ([], {h: [] for h in EDGE1_HORIZONS}))
            eb.append(bep)
            for h in EDGE1_HORIZONS:
                rd[h].append(rets[h])
            if cfg.emit_baseline_rows:
                bid = hashlib.sha1(("%s|%d" % (symbol, bep)).encode("utf-8")).hexdigest()[:12]
                baseline_rows.append([bid, symbol, "IS", key[0], key[1], key[2], bep, entry_price]
                                     + [rets[h] for h in EDGE1_HORIZONS]
                                     + [1e4 * atr / entry_price, bars_missing, 1])
        for key in sorted(buckets.keys()):
            eb, rd = buckets[key]
            cells[(symbol,) + key] = Cell(eb, rd)
            row = [symbol, "IS", key[0], key[1], key[2], len(eb)]
            for h in EDGE1_HORIZONS:
                row.append(_mean(rd[h]))
            for h in EDGE1_HORIZONS:
                row.append(math.sqrt(_pvar(rd[h])))
            cell_cells_rows.append(row)
    baseline_rows.sort(key=lambda r: (r[1], r[6]))
    cell_cells_rows.sort(key=lambda r: (r[0], r[2], r[3], r[4]))

    # ---- 5. grid statistics
    def cell_stat(z_thr: float, delay: int, hold: int, era: str,
                  symbol_filter: Optional[str] = None,
                  dir_rule: str = EDGE1_DIR_RULE_PRIMARY) -> Dict:
        """One grid cell under ONE sealed cluster-direction rule.

        Under ``primary_event_rank`` (the sealed rule) the cluster's direction
        AND its trigger both come from the cluster's highest-ranked member, so
        every row of a cluster is signed by ONE tradeable direction.  Under
        ``row_mean`` each row keeps its own event's direction and the cluster
        mean averages them -- that is the previous delivery's behaviour, kept
        only as a disclosed sensitivity: it can average a long and a short on
        the identical price path and rescale the observation by the vote margin.
        """
        # which clusters trigger, and with what direction
        trig_dir: Dict[str, Optional[int]] = {}
        conflicts = 0
        for cid in sorted(clusters.keys()):
            members = [m for m in clusters[cid] if m.era == era]
            if not members:
                continue
            if dir_rule == "row_mean":
                if any(m.direction is not None and m.surprise_z is not None
                       and abs(m.surprise_z) >= z_thr for m in members):
                    trig_dir[cid] = 0        # 0 == "use each row's own trade_dir"
                continue
            d, prim, conflict = resolve_cluster(members, dir_rule)
            if conflict:
                conflicts += 1
                continue
            if d is None:
                continue
            if dir_rule == "primary_event_rank" and prim is not None:
                if prim.surprise_z is None or abs(prim.surprise_z) < z_thr:
                    continue
            else:
                if not any(m.direction is not None and m.surprise_z is not None
                           and abs(m.surprise_z) >= z_thr for m in members):
                    continue
            trig_dir[cid] = d

        buckets: Dict[str, List[Tuple[float, float, float]]] = {}
        thin = 0
        for rec in ew_recs:
            e = rec["event"]
            if e.era != era or not rec["ok"] or e.is_confounded:
                continue
            if e.cluster_id not in trig_dir:
                continue
            if rec["delay"] != delay:
                continue
            if symbol_filter is not None and rec["symbol"] != symbol_filter:
                continue
            cd = trig_dir[e.cluster_id]
            if cd == 0:
                if e.direction is None or e.surprise_z is None or abs(e.surprise_z) < z_thr:
                    continue
                sdir = rec["trade_dir"]
            else:
                sdir = cd * rec["leg"]
            c = cells.get((rec["symbol"],) + rec["cell"])
            if c is None:
                thin += 1
                continue
            lo = e.release_epoch - EDGE1_BASELINE_EVENT_EXCL_DAYS * 86400
            hi = e.release_epoch + EDGE1_BASELINE_EVENT_EXCL_DAYS * 86400
            n, mu, sd = c.stats(hold, lo, hi)
            if n < EDGE1_THIN_CELL_N or mu is None:
                thin += 1
                continue
            buckets.setdefault(e.cluster_id, []).append(
                (rec["rets_raw"][hold] * sdir, sdir * mu, sd))
        clusters_agg = buckets
        n_rows = sum(len(v) for v in clusters_agg.values())
        diffs: List[float] = []
        s2: List[float] = []
        raw: List[float] = []
        for cid in sorted(clusters_agg.keys()):
            rows = clusters_agg[cid]
            r_c = _mean([x[0] for x in rows])
            b_c = _mean([x[1] for x in rows])
            s_c2 = _mean([x[2] * x[2] for x in rows])
            diffs.append(r_c - b_c)
            s2.append(s_c2)
            raw.append(r_c)
        n_eff = len(diffs)
        out = {"n_eff": n_eff, "n_rows": n_rows, "n_dropped_thin_cell": thin,
               "dir_rule": dir_rule, "n_clusters_direction_conflict": conflicts}
        if n_eff == 0:
            out.update({"effect_bp": None, "baseline_projected_bp": None, "sigma0_bp": None,
                        "effect_sigma": None, "se_cluster_bp": None, "t_stat": None,
                        "conditional_sd_bp": None, "status": "UNDERPOWERED"})
            return out
        effect = _mean(diffs)
        sigma0 = math.sqrt(_mean(s2))
        se = math.sqrt(_svar(diffs) / n_eff) if n_eff > 1 else None
        out["effect_bp"] = effect
        out["baseline_projected_bp"] = _mean(raw) - effect
        out["sigma0_bp"] = sigma0
        out["effect_sigma"] = (effect / sigma0) if sigma0 > 0 else None
        out["se_cluster_bp"] = se
        out["t_stat"] = (effect / se) if (se and se > 0) else None
        out["conditional_sd_bp"] = math.sqrt(_svar(raw)) if n_eff > 1 else None
        return out

    grid_cells: List[Dict] = []
    for z_thr in EDGE1_GRID_Z:
        for delay in EDGE1_GRID_DELAY:
            for hold in EDGE1_GRID_HOLD:
                st = cell_stat(z_thr, delay, hold, "IS")
                st.update({"surprise_z_threshold": z_thr, "entry_delay_min": delay,
                           "holding_min": hold, "era": "IS"})
                if st["n_eff"] < EDGE1_N_EFF_FLOOR:
                    st["status"] = "UNDERPOWERED"
                elif (st["effect_sigma"] is not None and st["effect_sigma"] >= EDGE1_EFFECT_SIGMA_FLOOR
                      and st["t_stat"] is not None and st["t_stat"] >= EDGE1_T_FLOOR):
                    st["status"] = "SURVIVES_IS"
                else:
                    st["status"] = "REFUTED"
                grid_cells.append(st)

    pz, pd_, ph = (EDGE1_PRIMARY_CELL["surprise_z_threshold"],
                   EDGE1_PRIMARY_CELL["entry_delay_min"], EDGE1_PRIMARY_CELL["holding_min"])
    primary = [c for c in grid_cells if (c["surprise_z_threshold"], c["entry_delay_min"],
                                         c["holding_min"]) == (pz, pd_, ph)][0]
    per_symbol = {}
    for s in universe:
        st = cell_stat(pz, pd_, ph, "IS", symbol_filter=s)
        per_symbol[s] = {"n_eff": st["n_eff"], "effect_sigma": st["effect_sigma"],
                         "effect_bp": st["effect_bp"]}
    primary["per_symbol"] = per_symbol
    counts["dropped_thin_cell"] = primary["n_dropped_thin_cell"]
    counts["dropped_confounded"] = sum(1 for r in ew_recs if r["event"].is_confounded)
    counts["dropped_not_calibrated"] = (calib_counts["examined"] - calib_counts["calibrated"])

    # holdout, frozen everything
    oos = cell_stat(pz, pd_, ph, "OOS")
    sign_is = _sign(primary["effect_bp"]) if primary["effect_bp"] is not None else 0
    sign_oos = _sign(oos["effect_bp"]) if oos["effect_bp"] is not None else 0
    if oos["n_eff"] < EDGE1_OOS_N_FLOOR:
        oos_status = "INCONCLUSIVE_OOS"
    elif sign_oos == sign_is and sign_is != 0 and (oos["effect_sigma"] or 0) > 0:
        oos_status = "SURVIVES_OOS"
    else:
        oos_status = "SIGN_FLIP"

    agreeing = 0
    for c in grid_cells:
        if c["status"] == "UNDERPOWERED":
            continue
        if c["effect_sigma"] is None or sign_is == 0:
            continue
        if _sign(c["effect_bp"]) == sign_is and abs(c["effect_sigma"]) >= EDGE1_FRAGILITY_SIGMA \
                and _sign(c["effect_sigma"]) == sign_is:
            agreeing += 1
    n_symbols = len(universe)
    sym_needed = max(1, int(math.ceil(0.75 * n_symbols)))
    sym_agree = sum(1 for s in universe
                    if per_symbol[s]["effect_bp"] is not None and _sign(per_symbol[s]["effect_bp"]) == sign_is
                    and sign_is != 0)
    fragile = not (agreeing >= EDGE1_FRAGILITY_CELLS and sym_agree >= sym_needed)

    # ---- 5b. the DOC-LITERAL result, reported alongside the strengthened one.
    # EDGE_DISCOVERY_PROGRAM_V1 Sec.EDGE-1 says exactly: ">= 0.4 sigma with
    # n >= 300; 2024-2025 holdout mean must have the same sign; otherwise dead".
    # It carries NO t-statistic, NO holdout sample floor, NO fragility rule and
    # it does not say whether n counts clusters or rows.  Every one of those is
    # an addition made by the implementing spec, and each is a strengthening in
    # the pass direction -- so with an adequate sample they can turn SURVIVES
    # into REFUTED.  They are therefore declared, and the doc-literal verdict is
    # computed under both readings of n.
    doc_lit = {
        "criterion": ("effect_sigma >= %.2f AND n >= %d AND sign(holdout) == sign(IS)"
                      % (EDGE1_EFFECT_SIGMA_FLOOR, EDGE1_N_EFF_FLOOR)),
        "effect_sigma_is": primary["effect_sigma"],
        "n_clusters_is": primary["n_eff"], "n_rows_is": primary["n_rows"],
        "n_clusters_oos": oos["n_eff"], "n_rows_oos": oos["n_rows"],
        "sigma_floor_met": bool(primary["effect_sigma"] is not None
                                and primary["effect_sigma"] >= EDGE1_EFFECT_SIGMA_FLOOR),
        "n_floor_met_clusters": bool(primary["n_eff"] >= EDGE1_N_EFF_FLOOR),
        "n_floor_met_rows": bool(primary["n_rows"] >= EDGE1_N_EFF_FLOOR),
        "holdout_sign_matches": bool(sign_oos == sign_is and sign_is != 0),
    }
    if not (doc_lit["n_floor_met_clusters"] or doc_lit["n_floor_met_rows"]):
        doc_lit["verdict"] = "UNDERPOWERED"
    elif not doc_lit["sigma_floor_met"]:
        doc_lit["verdict"] = "REFUTED"
    elif not doc_lit["holdout_sign_matches"]:
        doc_lit["verdict"] = "REFUTED"
    else:
        doc_lit["verdict"] = "SURVIVES"

    # ---- 5c. sensitivity to the cluster-direction rule (BLOCKER fix disclosure)
    dir_sensitivity = []
    for rule in EDGE1_DIR_RULES:
        st_is = cell_stat(pz, pd_, ph, "IS", dir_rule=rule)
        st_oos = cell_stat(pz, pd_, ph, "OOS", dir_rule=rule)
        dir_sensitivity.append({
            "dir_rule": rule, "sealed": rule == EDGE1_DIR_RULE_PRIMARY,
            "n_eff_is": st_is["n_eff"], "n_rows_is": st_is["n_rows"],
            "effect_bp_is": st_is["effect_bp"], "effect_sigma_is": st_is["effect_sigma"],
            "n_eff_oos": st_oos["n_eff"], "effect_bp_oos": st_oos["effect_bp"],
            "clusters_dropped_conflict": st_is["n_clusters_direction_conflict"],
        })

    if primary["status"] == "UNDERPOWERED":
        verdict = "UNDERPOWERED"
    elif primary["status"] == "REFUTED":
        verdict = "REFUTED"
    elif oos_status == "INCONCLUSIVE_OOS":
        verdict = "INCONCLUSIVE_OOS"
    elif oos_status == "SIGN_FLIP":
        verdict = "REFUTED"
    elif fragile:
        verdict = "FRAGILE"
    else:
        verdict = "SURVIVES"

    # ---- 6. write tables
    tables = []
    p = os.path.join(out_dir, "calibration.csv")
    sha, n = write_csv(p, CALIB_HEADER, calib_rows)
    tables.append({"path": p, "sha256": sha, "rows": n})
    p = os.path.join(out_dir, "calibration_events.csv")
    sha, n = write_csv(p, CALIB_EVENTS_HEADER, calib_event_rows)
    tables.append({"path": p, "sha256": sha, "rows": n})
    p = os.path.join(out_dir, "events.csv")
    sha, n = write_csv(p, EVENTS_HEADER, event_rows)
    tables.append({"path": p, "sha256": sha, "rows": n})
    p = os.path.join(out_dir, "event_windows.csv")
    sha, n = write_csv(p, EW_HEADER, ew_rows)
    tables.append({"path": p, "sha256": sha, "rows": n})
    if cfg.emit_baseline_rows:
        p = os.path.join(out_dir, "baseline.csv")
        sha, n = write_csv(p, BASELINE_HEADER, baseline_rows)
        tables.append({"path": p, "sha256": sha, "rows": n})
    p = os.path.join(out_dir, "baseline_cells.csv")
    sha, n = write_csv(p, BASELINE_CELLS_HEADER, cell_cells_rows)
    tables.append({"path": p, "sha256": sha, "rows": n})

    # FREQUENCY -- counted as TRADEABLE ENTRIES, not calendar rows.  Three
    # simultaneous releases produce three event rows but only ONE entry bar you
    # can take; counting rows inflated the rate 1.7x on the production data and
    # that number was then compared to the Q02 floor of 5.  The count therefore
    # uses distinct entry bars, under the same filters the statistic uses
    # (window_ok, not confounded, primary cell, sealed direction rule).
    years = cfg.is_end.year - cfg.is_start.year + 1
    prim_trig_clusters = set()
    for cid in sorted(clusters.keys()):
        members = [m for m in clusters[cid] if m.era == "IS"]
        if not members:
            continue
        d, prim, conflict = resolve_cluster(members, EDGE1_DIR_RULE_PRIMARY)
        if conflict or d is None:
            continue
        if prim is not None:
            if prim.surprise_z is None or abs(prim.surprise_z) < pz:
                continue
        elif not any(m.surprise_z is not None and abs(m.surprise_z) >= pz
                     and m.direction is not None for m in members):
            continue
        prim_trig_clusters.add(cid)
    triggers = {}
    trigger_rows = {}
    for s in universe:
        bars_hit = {r["entry_epoch"] for r in ew_recs
                    if r["symbol"] == s and r["delay"] == pd_ and r["ok"]
                    and r["event"].era == "IS" and not r["event"].is_confounded
                    and r["event"].cluster_id in prim_trig_clusters}
        rows_hit = sum(1 for r in ew_recs
                       if r["symbol"] == s and r["delay"] == pd_ and r["ok"]
                       and r["event"].era == "IS" and not r["event"].is_confounded
                       and r["event"].cluster_id in prim_trig_clusters)
        triggers[s] = len(bars_hit) / float(years)
        trigger_rows[s] = rows_hit / float(years)

    commission_bp = 0.5   # 5e-05 round trip, framework/registry/live_commission.json
    summary = {
        "schema_version": SUMMARY_SCHEMA,
        "hypothesis_id": "EDGE-1",
        "hypothesis_title": "Scheduled-news post-release drift on FX majors (surprise-conditioned)",
        "code_version": CODE_VERSION,
        "generated_utc": cfg.now_iso,
        "rule_seal": {
            "primary_cell": EDGE1_PRIMARY_CELL,
            "declared_trial_count": EDGE1_DECLARED_TRIALS,
            "trials_schema": TRIALS_SCHEMA,
            "polarity_map_sha256": polarity_sha,
            "polarity_map_source": cfg.polarity_map or "embedded in edge_lab_stats.py",
            "cluster_direction_rule": EDGE1_DIR_RULE_PRIMARY,
            "cluster_rank_map_sha256": sha256_bytes(json.dumps(
                CLUSTER_PRIMARY_RANK, sort_keys=True, separators=(",", ":")).encode("utf-8")),
            "program_doc": cfg.program_doc_meta,
            "sealed_before_measurement": None,
            "seal_note": ("sealed_before_measurement is reported by the manifest from the git "
                          "state; a dirty tree cannot prove the rule predated the measurement"),
        },
        "resolution": {
            "bar_timeframe": "M5", "tick_data_used": False,
            "entry_rule": "open of the first M5 bar with open_epoch >= exact release + delay",
            "return_rule": "close-to-close, time stop only",
            "atr_source": "ATR(14) on the 14 M5 bars ending strictly before the release",
            "stops_measurable": False, "mae_mfe_is_envelope": True,
            "spread_modelled": False, "price_side": "bid",
            "known_at_utc_available": False,
            "p1_horizon_representable": False,
        },
        "calibration": {
            "groups_examined": calib_counts["examined"],
            "groups_calibrated": calib_counts["calibrated"],
            "groups_no_signature": calib_counts["no_signature"],
            "groups_ambiguous": calib_counts["ambiguous"],
            "groups_underpowered": calib_counts["underpowered"],
            "groups_offset_nonzero": calib_counts["offset_nonzero"],
            "groups_dropped_verify_frac": calib_counts["groups_dropped_verify_frac"],
            "events_instant_verified": calib_counts["events_verified"],
            "events_voided_home_clock": calib_counts["events_voided_home_clock"],
            "events_voided_local_peak": calib_counts["events_voided_local_peak"],
            "stage0b_note": (
                "the group offset is a CONSTANT; the production calendar's displacement "
                "is not.  Stage 0b verifies every individual instant against (A) the "
                "modal home wall-clock minute-of-day of its own group and (B) its own "
                "local tickvol peak, and VOIDS the non-conforming ones.  No event is "
                "ever re-shifted individually -- a per-event fit would be exactly the "
                "circularity Stage 0 exists to avoid."),
            "probe_space": ("offsets are probed in UTC space: the profile is sampled at "
                            "utc_to_broker_epoch(raw_utc + off), the same epoch EDGE-1 "
                            "later measures at"),
        },
        "universe": {
            "currencies": list(EDGE1_CURRENCIES),
            "symbol_map": {k: list(v) for k, v in sorted(symbol_map.items())},
            "symbols": universe,
            "eur_second_cross_available": False,
            "probe_symbols": EDGE1_PROBE_SYMBOL,
        },
        "counts": counts,
        "surprise_history": {
            "window_days": EDGE1_SURPRISE_WINDOW_DAYS,
            "min_history": cfg.surprise_min_history,
            "seed_rows_before_is_start": counts["surprise_history_seed_rows"],
            "n_hist_min": (min(surprise_n_hist) if surprise_n_hist else None),
            "n_hist_median": (_median(surprise_n_hist) if surprise_n_hist else None),
            "n_hist_max": (max(surprise_n_hist) if surprise_n_hist else None),
            "frac_below_24": ((sum(1 for x in surprise_n_hist if x < 24)
                               / float(len(surprise_n_hist))) if surprise_n_hist else None),
            "note": ("the history stream is seeded from calendar rows BEFORE is_start; "
                     "those rows never become measured events.  min_history is the "
                     "declared floor -- events below it carry no z and cannot trigger"),
        },
        "cells": grid_cells,
        "primary_cell_result": primary,
        "doc_literal": doc_lit,
        "cluster_direction_sensitivity": dir_sensitivity,
        "holdout": {
            "era": "OOS", "n_eff": oos["n_eff"], "effect_bp": oos["effect_bp"],
            "effect_sigma": oos["effect_sigma"], "t_stat": oos["t_stat"],
            "sign_matches_is": bool(sign_oos == sign_is and sign_is != 0),
            "baseline_frozen_from": "IS", "status": oos_status,
        },
        "fragility": {"cells_agreeing": agreeing, "cells_total": len(grid_cells),
                      "threshold": EDGE1_FRAGILITY_CELLS, "symbols_agreeing": sym_agree,
                      "symbols_total": n_symbols, "symbols_needed": sym_needed,
                      "status": "FRAGILE" if fragile else "ROBUST"},
        "cost_anchor": {
            "registry": "framework/registry/live_commission.json",
            "class": "forex", "pct_rate_rt": 5e-05, "flat_per_lot_rt": 5.0,
            "commission_bp_rt": commission_bp,
            "effect_bp_minus_commission": (None if primary["effect_bp"] is None
                                           else primary["effect_bp"] - commission_bp),
            "spread_excluded": True,
        },
        "frequency": {
            "tradeable_entries_per_symbol_year": triggers,
            "event_rows_per_symbol_year": trigger_rows,
            "counting_unit": ("distinct entry bars at the primary cell under the sealed "
                              "cluster-direction rule, window_ok and not confounded"),
            "q02_floor": 5,
            "floor_met": bool(triggers and all(v >= 5 for v in triggers.values())),
        },
        "verdict": verdict,
        "refutation_statistic": (
            "EFFECT_SIGMA = (mean_cluster(signed %d-min close-to-close return) - "
            "mean_cluster(direction-projected unconditional cell mean)) / "
            "sqrt(mean_cluster(unconditional cell variance)); threshold %.2f at n_eff>=%d"
            % (ph, EDGE1_EFFECT_SIGMA_FLOOR, EDGE1_N_EFF_FLOOR)),
        "failure_modes_checked": [
            "calendar timestamp displacement (Stage 0, fail-closed)",
            "polarity fitted post hoc (sealed map, hashed into the code)",
            "cross-symbol double counting (cluster aggregation)",
            "conditional sd used as sigma (sigma0 is the unconditional cell sd)",
            "baseline re-estimated on holdout (IS cells frozen)",
            "session/gap spanning windows (session_intact + bars_missing)",
        ],
        "open_gaps": [
            "tick resolution: first-seconds mechanism untestable at M5",
            "spread: unmodelled, no ask series in the bars",
            "known_at_utc: absent from the calendar, forecast publicity unproven",
            "EUR second cross: no EURJPY/EURGBP M5 export exists in T_Export",
            "calendar coverage hole ~2025-04-10..2026-06-30 truncates the OOS era",
            ("the baseline's news exclusion uses exactly the CALIBRATED instant set "
             "(%d instants).  Groups Stage 0 could not calibrate are invisible to it, "
             "so the baseline is 'unconditional of calibrated news', not of all news -- "
             "the stricter Stage 0 is, the weaker this exclusion becomes"
             % len(calibrated_instants)),
            ("three .DWX history holes fall inside the study window and are not "
             "weekends or holidays: 2023-12-12..2023-12-18 (all four symbols), "
             "2025-10-08..2025-11-03 (FX only, ~26 days of the OOS era), "
             "2025-12-17..2025-12-22 (all four).  session_intact voids windows that "
             "span them; it cannot restore the missing observations"),
        ],
        "deviations_from_spec": [
            "p1 horizon dropped: not representable on M5 (the last bar closing at "
            "or before entry+60s precedes entry)",
            "window_ok requires ALL horizons {5,15,30,60,90,120} present, so the "
            "sample composition is identical across grid cells",
            "is_confounded uses the widest grid window (max delay + max holding + 15 "
            "= %d min) so the flag is uniform across cells" % EDGE1_CONFOUND_MIN,
            "event_polarity map is embedded in the module rather than a side-car "
            "JSON, so the seal is provable from the code sha256 alone",
            "symbol-consistency threshold generalised to ceil(0.75 * n_symbols)",
            # ---- criteria the DOC does not contain.  All are strengthenings in
            # the pass direction and each NEEDS A SEAL before it may carry a
            # verdict on its own.  The doc-literal result is reported in
            # summary.doc_literal so the two can be compared line by line.
            "NEEDS A SEAL: t_stat >= %.1f is an ADDED gate on SURVIVES_IS; the doc's "
            "EDGE-1 refutation contains no t-statistic" % EDGE1_T_FLOOR,
            "NEEDS A SEAL: the holdout floor n_eff >= %d is ADDED; the doc requires only "
            "that the holdout mean has the same sign" % EDGE1_OOS_N_FLOOR,
            "NEEDS A SEAL: the fragility rule (>= %d of %d grid cells at >= %.2f sigma, "
            "plus symbol consistency) is ADDED; the doc names no grid and no fragility "
            "criterion, and this rule can independently set the verdict to FRAGILE"
            % (EDGE1_FRAGILITY_CELLS, EDGE1_DECLARED_TRIALS, EDGE1_FRAGILITY_SIGMA),
            "NEEDS A SEAL: the doc's unqualified 'n >= 300' is read here as CLUSTERS "
            "(independent releases), not event x symbol rows; both readings are "
            "reported in summary.doc_literal",
            "NEEDS A SEAL: the cluster-direction rule '%s' (a cluster is signed and "
            "triggered by its highest-ranked member) is an ADDED rule; the doc says only "
            "'entry in the surprise direction' and does not say how simultaneous "
            "releases with opposite polarity are combined.  Sensitivity to the three "
            "candidate rules is reported in summary.cluster_direction_sensitivity"
            % EDGE1_DIR_RULE_PRIMARY,
            "NEEDS A SEAL: Stage 0b voids individual instants that disagree with their "
            "group's modal home wall-clock time or with their own local tickvol peak; "
            "the doc has no per-event verification step",
            "GBP is measured on ONE cross (GBPUSD.DWX) by default although GBPJPY.DWX M5 "
            "exists, so the doc's 'the currency's two most liquid crosses' is honoured "
            "for USD only.  --edge1-include-gbpjpy switches the second GBP cross on",
        ],
    }
    return {"summary": summary, "tables": tables, "verdict": verdict,
            "primary": primary, "holdout": summary["holdout"],
            "fragility": summary["fragility"],
            "calibrated_instants": calibrated_instants}


# ===========================================================================
# EDGE-3
# ===========================================================================

FIXDAYS_HEADER = (["day_id", "symbol", "fix_code", "arm_role", "date_london", "weekday",
                   "uk_dst", "us_dst", "broker_offset_h", "dst_regime", "fix_utc",
                   "fix_broker_epoch", "era", "prefix_window_min", "pre_open", "pre_close",
                   "premove_bp", "atr_m30_bp", "premove_norm", "entry_price"]
                  + ["post_%d" % h for h in EDGE3_HORIZONS]
                  + ["ret_%d_bp" % h for h in EDGE3_HORIZONS]
                  + ["ret_%d_atr" % h for h in EDGE3_HORIZONS]
                  + ["trade_dir", "mae_45_bp", "mfe_45_bp", "has_news", "news_coverage_ok",
                     "bars_missing", "session_intact", "day_ok", "minute_of_hour",
                     "broker_hour"])

FIXBASE_HEADER = (["symbol", "fix_code", "era", "pseudo_anchor_epoch", "weekday",
                   "broker_hour", "minute_of_hour", "prefix_window_min", "premove_bp",
                   "atr_m30_bp", "premove_norm"]
                  + ["ret_%d_bp" % h for h in EDGE3_HORIZONS]
                  + ["ret_%d_atr" % h for h in EDGE3_HORIZONS]
                  + ["in_session_band", "bars_missing", "session_intact", "day_ok"])

FIXBASECELL_HEADER = ["symbol", "fix_code", "era", "scope", "weekday", "minute_of_hour",
                      "prefix_window_min", "threshold_atr", "holding_min", "n_anchors",
                      "n_trigger", "mean_ret_atr", "sd_ret_atr",
                      "frozen_is_baseline_beta0", "frozen_is_baseline_beta0_se",
                      "r_base_atr"]

FIXBASEHOUR_HEADER = ["symbol", "fix_code", "era", "prefix_window_min", "threshold_atr",
                      "holding_min", "broker_hour", "in_session_band", "n_anchors",
                      "n_trigger", "r_base_atr"]


def _atr_m30(series: BarSeries, anchor_slot: int) -> Optional[float]:
    """ATR(14) over 14 non-overlapping 30-min bars ending AT the anchor.

    The doc asks for ATR(30m); no M30 series exists for these symbols, so M5
    bars are aggregated into non-overlapping 30-minute bars ending at the fix
    anchor.  15 aggregated bars are needed (14 + one previous close) and every
    one of the 90 constituent M5 bars must be present, else the value is None
    and the row is voided -- never interpolated.
    """
    cached = series.atr30_cache.get(anchor_slot, _MISSING)
    if cached is not _MISSING:
        return cached
    val = _atr_m30_compute(series, anchor_slot)
    series.atr30_cache[anchor_slot] = val
    return val


def _atr_m30_compute(series: BarSeries, anchor_slot: int) -> Optional[float]:
    per = EDGE3_ATR_AGG_MIN * 60 // SLOT_SECONDS   # 6 M5 bars
    need = EDGE3_ATR_PERIOD + 1                    # 15 aggregated bars
    start = anchor_slot - need * per
    if start < 0 or anchor_slot > series.n:
        return None
    aggs = []
    for k in range(need):
        a = start + k * per
        b = a + per
        hi = None
        lo = None
        cl = None
        for s in range(a, b):
            if not series.present[s]:
                return None
            hi = series.high[s] if hi is None else max(hi, series.high[s])
            lo = series.low[s] if lo is None else min(lo, series.low[s])
            cl = series.close[s]
        aggs.append((hi, lo, cl))
    trs = []
    for k in range(1, need):
        hi, lo, _ = aggs[k]
        pc = aggs[k - 1][2]
        trs.append(max(hi - lo, abs(hi - pc), abs(lo - pc)))
    return sum(trs) / float(len(trs))


def _edge3_anchor_metrics(series: BarSeries, anchor_slot: int, prefix_min: int):
    """Construct one fix/pseudo-anchor observation.  Returns dict or None."""
    pre_slot = anchor_slot - (prefix_min * 60) // SLOT_SECONDS
    if pre_slot < 0:
        return None
    if not series.present[pre_slot]:
        return None
    prev_slot = anchor_slot - 1
    if prev_slot < 0 or not series.present[prev_slot]:
        return None   # pre_close anchor must be the exact bar ending at the fix
    if not series.present[anchor_slot]:
        return None
    pre_open = series.open[pre_slot]
    pre_close = series.close[prev_slot]
    entry = series.open[anchor_slot]
    if not pre_open or not entry:
        return None
    premove_bp = 1e4 * (pre_close - pre_open) / pre_open
    atr = _atr_m30(series, anchor_slot)
    if atr is None or atr <= 0:
        return None
    atr_bp = 1e4 * atr / entry
    if atr_bp <= 0:
        return None
    post = {}
    for h in EDGE3_HORIZONS:
        s = anchor_slot + (h * 60) // SLOT_SECONDS - 1
        post[h] = series.close[s] if 0 <= s < series.n else None
    if any(post[h] is None for h in EDGE3_HORIZONS):
        return None
    end_slot = anchor_slot + (max(EDGE3_HORIZONS) * 60) // SLOT_SECONDS
    bars_missing = series.missing_in(pre_slot, end_slot)
    intact = series.session_intact(pre_slot, end_slot)
    return {
        "pre_slot": pre_slot, "pre_open": pre_open, "pre_close": pre_close,
        "entry": entry, "premove_bp": premove_bp, "atr_bp": atr_bp,
        "premove_norm": premove_bp / atr_bp, "post": post,
        "bars_missing": bars_missing, "intact": intact,
    }


def run_edge3(bars: Dict[str, BarSeries], calibrated_instants: List[int],
              calendar_day_ordinals: List[int], cfg, out_dir: str) -> Dict:
    arms = list(EDGE3_ARMS) + (list(EDGE3_DIAGNOSTIC_ARMS) if cfg.edge3_diagnostics else [])
    need_syms = sorted({s for s, _, _ in arms})
    missing = [s for s in need_syms if s not in bars]
    if missing:
        raise SystemExit("EDGE-3 needs bar series %r; missing %r" % (need_syms, missing))

    def news_coverage_ok(day: dt.date) -> bool:
        """True iff the calendar has at least one row within +/-7 days.

        Outside the calendar's covered span ``has_news == 0`` means "no
        calendar", not "no news".  The production clean calendar has a ~15
        month hole (~2025-04-10 .. 2026-06-30), so this gate is what stops the
        second half of the OOS era being scored as news-free.
        """
        o = day.toordinal()
        a = bisect.bisect_left(calendar_day_ordinals, o - EDGE3_NEWS_COVERAGE_DAYS)
        b = bisect.bisect_right(calendar_day_ordinals, o + EDGE3_NEWS_COVERAGE_DAYS)
        return b > a

    news_sorted = calibrated_instants

    def has_news(epoch_lo: int, epoch_hi: int) -> bool:
        a = bisect.bisect_left(news_sorted, epoch_lo)
        b = bisect.bisect_right(news_sorted, epoch_hi)
        return b > a

    # --- fix instants per day (needed both for rows and for the baseline's
    #     "at least 90 min from every fix on the day" rule)
    day0 = cfg.is_start
    day1 = cfg.oos_end
    fix_epochs_by_date: Dict[dt.date, Dict[str, int]] = {}
    d = day0
    while d <= day1:
        if d.weekday() < 5:
            m = {}
            for code, (hh, mm) in sorted(EDGE3_FIXES.items()):
                u = london_local_to_utc(d, hh, mm)
                m[code] = utc_to_broker_epoch(u)
            fix_epochs_by_date[d] = m
        d += dt.timedelta(days=1)
    all_fix_epochs = sorted({e for m in fix_epochs_by_date.values() for e in m.values()})

    fix_rows: List[List] = []
    fix_recs: List[Dict] = []
    for symbol, code, role in arms:
        series = bars[symbol]
        hh, mm = EDGE3_FIXES[code]
        for day in sorted(fix_epochs_by_date.keys()):
            u = london_local_to_utc(day, hh, mm)
            epoch = fix_epochs_by_date[day][code]
            anchor = series.slot(epoch)
            if anchor is None:
                continue
            era = "IS" if cfg.is_start.year <= day.year <= cfg.is_end.year else (
                "OOS" if cfg.oos_start.year <= day.year <= cfg.oos_end.year else None)
            if era is None:
                continue
            uk = 1 if is_uk_dst(u) else 0
            us = 1 if is_us_dst(u) else 0
            off_h = darwinex_offset_hours(u)
            regime = "ALIGNED" if uk == us else "MISMATCH"
            cov_ok = 1 if news_coverage_ok(day) else 0
            for pw in EDGE3_GRID_PREFIX:
                m = _edge3_anchor_metrics(series, anchor, pw)
                did = hashlib.sha1(("%s|%s|%s|%d" % (symbol, code, day.isoformat(), pw)).encode("utf-8")).hexdigest()[:12]
                if m is None:
                    fix_rows.append([did, symbol, code, role, day.isoformat(), day.weekday(),
                                     uk, us, off_h, regime, u.strftime("%Y-%m-%dT%H:%M:%SZ"),
                                     epoch, era, pw] + [None] * 6
                                    + [None] * (3 * len(EDGE3_HORIZONS))
                                    + [None, None, None, None, cov_ok, None, None, 0,
                                       broker_minute(epoch), broker_hour(epoch)])
                    continue
                news = 1 if has_news(epoch - pw * 60, epoch + 60 * 60) else 0
                rets_bp = {h: 1e4 * (m["post"][h] - m["entry"]) / m["entry"] for h in EDGE3_HORIZONS}
                rets_atr = {h: rets_bp[h] / m["atr_bp"] for h in EDGE3_HORIZONS}
                # the arm FADES the pre-fix move, so MAE/MFE must be taken on
                # the fade side.  Signing them long unconditionally understated
                # the adverse excursion on every short (positive pre-move) day.
                tdir = -1 if m["premove_norm"] > 0 else 1
                mae, mfe = _mae_mfe(series, anchor, m["entry"], 45, tdir)
                ok = (m["bars_missing"] <= 2 and m["intact"] and cov_ok == 1)
                fix_rows.append([did, symbol, code, role, day.isoformat(), day.weekday(),
                                 uk, us, off_h, regime, u.strftime("%Y-%m-%dT%H:%M:%SZ"),
                                 epoch, era, pw, m["pre_open"], m["pre_close"],
                                 m["premove_bp"], m["atr_bp"], m["premove_norm"], m["entry"]]
                                + [m["post"][h] for h in EDGE3_HORIZONS]
                                + [rets_bp[h] for h in EDGE3_HORIZONS]
                                + [rets_atr[h] for h in EDGE3_HORIZONS]
                                + [tdir, mae, mfe, news, cov_ok, m["bars_missing"],
                                   1 if m["intact"] else 0, 1 if ok else 0,
                                   broker_minute(epoch), broker_hour(epoch)])
                fix_recs.append({"symbol": symbol, "fix_code": code, "role": role,
                                 "era": era, "year": day.year, "pw": pw,
                                 "premove_norm": m["premove_norm"], "premove_bp": m["premove_bp"],
                                 "rets_atr": rets_atr, "has_news": news, "ok": ok,
                                 "cell": (day.weekday(), broker_minute(epoch)),
                                 "regime": regime, "hour": broker_hour(epoch)})
    fix_rows.sort(key=lambda r: (r[1], r[2], r[11], r[13]))

    # --- baseline pseudo-anchors -------------------------------------------
    fix_halo = EDGE3_FIX_EXCL_MIN * 60
    base_rows: List[List] = []
    base_cells: Dict[Tuple[str, str, int, int, int], List[Dict]] = {}
    base_hours: Dict[Tuple[str, str, int, int], List[Dict]] = {}
    fix_hours_by_code: Dict[str, set] = {}
    for code in EDGE3_FIXES:
        fix_hours_by_code[code] = {broker_hour(fix_epochs_by_date[d][code])
                                   for d in fix_epochs_by_date}
    is_lo = _calendar.timegm(dt.datetime(cfg.is_start.year, cfg.is_start.month, cfg.is_start.day).timetuple())
    is_hi = _calendar.timegm(dt.datetime(cfg.is_end.year, cfg.is_end.month, cfg.is_end.day, 23, 59, 59).timetuple())
    for symbol, code, role in arms:
        if role == "DIAGNOSTIC":
            continue
        series = bars[symbol]
        # the minute phase(s) the real fix anchors land on
        phases = sorted({broker_minute(fix_epochs_by_date[d][code])
                         for d in fix_epochs_by_date})
        fhours = fix_hours_by_code[code]

        def _in_band(hh: int, _fh=fhours) -> bool:
            return any(min((hh - f) % 24, (f - hh) % 24) <= EDGE3_SESSION_BAND_H
                       for f in _fh)
        s_lo = max(series.slot_floor(is_lo) or 0, 0)
        s_hi = series.slot_floor(is_hi)
        s_hi = series.n - 1 if s_hi is None else min(s_hi, series.n - 1)
        for s in range(s_lo, s_hi + 1):
            if not series.present[s]:
                continue
            ep = series.epoch_of(s)
            if broker_minute(ep) not in phases:
                continue
            wd = broker_weekday(ep)
            if wd > 4:
                continue
            # >= 90 min away from EVERY fix instant that day
            a = bisect.bisect_left(all_fix_epochs, ep - fix_halo)
            b = bisect.bisect_right(all_fix_epochs, ep + fix_halo)
            if b > a:
                continue
            for pw in EDGE3_GRID_PREFIX:
                if has_news(ep - pw * 60, ep + 60 * 60):
                    continue
                m = _edge3_anchor_metrics(series, s, pw)
                if m is None or m["bars_missing"] > 2 or not m["intact"]:
                    continue
                rets_bp = {h: 1e4 * (m["post"][h] - m["entry"]) / m["entry"] for h in EDGE3_HORIZONS}
                rets_atr = {h: rets_bp[h] / m["atr_bp"] for h in EDGE3_HORIZONS}
                hh = broker_hour(ep)
                band = 1 if _in_band(hh) else 0
                rec = {"premove_norm": m["premove_norm"], "rets_atr": rets_atr,
                       "hour": hh, "band": band}
                base_cells.setdefault((symbol, code, wd, broker_minute(ep), pw), []).append(rec)
                base_hours.setdefault((symbol, code, pw, hh), []).append(rec)
                if cfg.emit_baseline_rows:
                    base_rows.append([symbol, code, "IS", ep, wd, hh,
                                      broker_minute(ep), pw, m["premove_bp"], m["atr_bp"],
                                      m["premove_norm"]]
                                     + [rets_bp[h] for h in EDGE3_HORIZONS]
                                     + [rets_atr[h] for h in EDGE3_HORIZONS]
                                     + [band, m["bars_missing"], 1, 1])
    base_rows.sort(key=lambda r: (r[0], r[1], r[7], r[3]))

    base_cell_rows: List[List] = []
    base_stats: Dict[Tuple, Dict] = {}          # scope ALL_HOURS
    base_stats_session: Dict[Tuple, Dict] = {}  # scope SESSION (hour-band matched)
    for key in sorted(base_cells.keys()):
        symbol, code, wd, minute, pw = key
        allrecs = base_cells[key]
        for scope, recs, store in (("ALL_HOURS", allrecs, base_stats),
                                   ("SESSION", [r for r in allrecs if r["band"]],
                                    base_stats_session)):
            if not recs:
                continue      # no anchor in this scope -> the cell simply has no entry
            xs = [r["premove_norm"] for r in recs]
            for thr in EDGE3_GRID_THRESHOLD:
                for hold in EDGE3_GRID_HOLD:
                    ys = [r["rets_atr"][hold] for r in recs]
                    beta, bse = _ols_slope(xs, ys)
                    trig = [(-1 if r["premove_norm"] > 0 else 1) * r["rets_atr"][hold]
                            for r in recs
                            if abs(r["premove_norm"]) >= thr and r["premove_norm"] != 0]
                    r_base = _mean(trig) if trig else None
                    store[(symbol, code, wd, minute, pw, thr, hold)] = {
                        "n_anchors": len(recs), "n_trigger": len(trig),
                        "r_base_atr": r_base,
                        # NOTE: this slope is the BASELINE's ambient reversion
                        # coefficient, frozen from IS.  It is NOT a fix-day or
                        # out-of-sample statistic -- the arm's own slope is
                        # published separately as beta_fix.
                        "frozen_is_baseline_beta0": beta,
                    }
                    base_cell_rows.append([symbol, code, "IS", scope, wd, minute, pw, thr,
                                           hold, len(recs), len(trig),
                                           (_mean(ys) if ys else None),
                                           (math.sqrt(_pvar(ys)) if ys else None),
                                           beta, bse, r_base])
    base_cell_rows.sort(key=lambda r: (r[0], r[1], r[3], r[4], r[5], r[6], r[7], r[8]))

    # per-broker-hour breakdown of the ambient reversion, so the time-of-day
    # composition of the pooled baseline is visible instead of implied.
    base_hour_rows: List[List] = []
    for key in sorted(base_hours.keys()):
        symbol, code, pw, hh = key
        recs = base_hours[key]
        band = 1 if any(min((hh - f) % 24, (f - hh) % 24) <= EDGE3_SESSION_BAND_H
                        for f in fix_hours_by_code[code]) else 0
        for thr in EDGE3_GRID_THRESHOLD:
            for hold in EDGE3_GRID_HOLD:
                trig = [(-1 if r["premove_norm"] > 0 else 1) * r["rets_atr"][hold]
                        for r in recs
                        if abs(r["premove_norm"]) >= thr and r["premove_norm"] != 0]
                base_hour_rows.append([symbol, code, "IS", pw, thr, hold, hh, band,
                                       len(recs), len(trig),
                                       (_mean(trig) if trig else None)])
    base_hour_rows.sort(key=lambda r: (r[0], r[1], r[3], r[4], r[5], r[6]))

    # --- arm statistics -----------------------------------------------------
    def arm_cell(symbol, code, pw, thr, hold, era, year_lo=None, year_hi=None) -> Dict:
        sel = [r for r in fix_recs
               if r["symbol"] == symbol and r["fix_code"] == code and r["pw"] == pw
               and r["era"] == era and r["ok"] and not r["has_news"]]
        if year_lo is not None:
            sel = [r for r in sel if year_lo <= r["year"] <= year_hi]
        n_days = len(sel)
        trig = [r for r in sel if abs(r["premove_norm"]) >= thr and r["premove_norm"] != 0]
        vals = [(-1 if r["premove_norm"] > 0 else 1) * r["rets_atr"][hold] for r in trig]
        out = {"n_days_measured": n_days, "n_trigger": len(trig),
               "n_excluded_has_news": sum(1 for r in fix_recs
                                          if r["symbol"] == symbol and r["fix_code"] == code
                                          and r["pw"] == pw and r["era"] == era and r["ok"]
                                          and r["has_news"])}
        if not vals:
            out.update({"r_fix_atr": None, "se_fix": None, "t_stat_fix": None,
                        "r_base_atr": None, "r_excess_atr": None, "se": None,
                        "t_stat": None, "r_base_atr_all_hours": None,
                        "r_excess_atr_all_hours": None, "se_all_hours": None,
                        "t_stat_all_hours": None, "beta_fix": None, "beta_fix_se": None,
                        "frozen_is_baseline_beta0": None,
                        "baseline_cells_thin": True, "status": "UNDERPOWERED"})
            return out
        r_fix = _mean(vals)
        sd_fix = math.sqrt(_svar(vals)) if len(vals) > 1 else None
        se_fix = (sd_fix / math.sqrt(len(vals))) if sd_fix else None

        def _paired(store) -> Tuple[Optional[float], Optional[float], Optional[float],
                                    bool, List[float]]:
            """(r_base, r_excess, se, thin, baseline_betas) with the baseline
            differenced PER TRIGGER.

            Differencing each trigger against its own cell's frozen baseline and
            taking the SE of that differenced series propagates the baseline's
            own estimation variance.  Using sd(fix)/sqrt(n) with r_excess in the
            numerator treats an ESTIMATED baseline as a known constant, which
            inflates |t| -- always in the pass direction of the t >= 2 gate.
            """
            diffs: List[float] = []
            bases: List[float] = []
            betas: List[float] = []
            thin = False
            for r, v in zip(trig, vals):
                k = (symbol, code, r["cell"][0], r["cell"][1], pw, thr, hold)
                st = store.get(k)
                if st is None or st["r_base_atr"] is None:
                    thin = True
                    continue
                if st["n_anchors"] < EDGE3_BASELINE_MIN_N:
                    thin = True
                diffs.append(v - st["r_base_atr"])
                bases.append(st["r_base_atr"])
                if st["frozen_is_baseline_beta0"] is not None:
                    betas.append(st["frozen_is_baseline_beta0"])
            if not diffs:
                return None, None, None, True, betas
            rb = _mean(bases)
            rx = _mean(diffs)
            sdd = math.sqrt(_svar(diffs)) if len(diffs) > 1 else None
            se = (sdd / math.sqrt(len(diffs))) if sdd else None
            return rb, rx, se, thin, betas

        rb_s, rx_s, se_s, thin_s, betas_s = _paired(base_stats_session)
        rb_a, rx_a, se_a, thin_a, _ = _paired(base_stats)
        # the arm's OWN regression of the post-fix return on the pre-fix move,
        # per era -- NOT the baseline slope.
        beta_fix, beta_fix_se = _ols_slope([r["premove_norm"] for r in trig],
                                           [r["rets_atr"][hold] for r in trig])
        out.update({
            "r_fix_atr": r_fix, "se_fix": se_fix,
            "t_stat_fix": ((r_fix / se_fix) if se_fix else None),
            "r_base_atr": rb_s, "r_excess_atr": rx_s, "se": se_s,
            "t_stat": ((rx_s / se_s) if (rx_s is not None and se_s) else None),
            "r_base_atr_all_hours": rb_a, "r_excess_atr_all_hours": rx_a,
            "se_all_hours": se_a,
            "t_stat_all_hours": ((rx_a / se_a) if (rx_a is not None and se_a) else None),
            "beta_fix": beta_fix, "beta_fix_se": beta_fix_se,
            "frozen_is_baseline_beta0": (_mean(betas_s) if betas_s else None),
            "baseline_scope": "SESSION", "baseline_cells_thin": bool(thin_s or thin_a),
        })
        return out

    def _edge3_status(st: Dict) -> Dict:
        """Status under the DOC-LITERAL criterion first, then the strengthening.

        The doc's EDGE-3 refutation is exactly ``R_FIX >= 0.15 x ATR at
        n >= 800 days``.  R_EXCESS (fix reversion minus the matched ambient
        reversion) is a STRENGTHENING proposed by the implementing spec and is
        NOT sealed; it is also confounded with time of day, because the
        ">= 90 min from every fix" rule removes the fix's own broker hour from
        its baseline.  ``status_doc_literal`` therefore carries the verdict
        whenever it alone refutes, and ``verdict_basis`` names which test did
        the work.
        """
        under = (st["n_days_measured"] < EDGE3_N_DAYS_FLOOR
                 or st["n_trigger"] < EDGE3_N_TRIGGER_FLOOR)
        rf = st.get("r_fix_atr")
        if st["n_days_measured"] < EDGE3_N_DAYS_FLOOR:
            st["status_doc_literal"] = "UNDERPOWERED"
        elif rf is not None and rf >= EDGE3_R_FLOOR:
            st["status_doc_literal"] = "SURVIVES_IS"
        else:
            st["status_doc_literal"] = "REFUTED"
        if under:
            st["status"] = "UNDERPOWERED"
        elif (st.get("r_excess_atr") is not None and st["r_excess_atr"] >= EDGE3_R_FLOOR
              and rf is not None and rf >= EDGE3_R_FLOOR
              and st.get("t_stat") is not None and st["t_stat"] >= EDGE3_T_FLOOR):
            st["status"] = "SURVIVES_IS"
        else:
            st["status"] = "REFUTED"
        if st["status"] == "REFUTED":
            st["verdict_basis"] = ("DOC_LITERAL_R_FIX"
                                   if st["status_doc_literal"] == "REFUTED"
                                   else "R_EXCESS_STRENGTHENING_UNSEALED")
        else:
            st["verdict_basis"] = "BOTH"
        return st

    ppw, pthr, phold = (EDGE3_PRIMARY_CELL["prefix_window_min"],
                        EDGE3_PRIMARY_CELL["threshold_atr"],
                        EDGE3_PRIMARY_CELL["holding_min"])
    arm_blocks = []
    control_excess = None
    for symbol, code, role in arms:
        cells_out = []
        for pw in EDGE3_GRID_PREFIX:
            for thr in EDGE3_GRID_THRESHOLD:
                for hold in EDGE3_GRID_HOLD:
                    st = arm_cell(symbol, code, pw, thr, hold, "IS")
                    st.update({"prefix_window_min": pw, "threshold_atr": thr,
                               "holding_min": hold, "era": "IS"})
                    _edge3_status(st)
                    cells_out.append(st)
        primary = [c for c in cells_out
                   if (c["prefix_window_min"], c["threshold_atr"], c["holding_min"])
                   == (ppw, pthr, phold)][0]
        # dst regime split on the primary cell
        split = {}
        for reg in ("ALIGNED", "MISMATCH"):
            sel = [r for r in fix_recs
                   if r["symbol"] == symbol and r["fix_code"] == code and r["pw"] == ppw
                   and r["era"] == "IS" and r["ok"] and not r["has_news"]
                   and r["regime"] == reg and abs(r["premove_norm"]) >= pthr]
            vals = [(-1 if r["premove_norm"] > 0 else 1) * r["rets_atr"][phold] for r in sel]
            split[reg] = {"n": len(vals), "r_fix_atr": (_mean(vals) if vals else None)}
        primary["dst_regime_split"] = split

        decay = arm_cell(symbol, code, ppw, pthr, phold, "IS", 2022, 2023)
        if decay["n_trigger"] < EDGE3_N_TRIGGER_FLOOR:
            decay["status"] = "DECAY_UNDETERMINED"
        elif decay["r_excess_atr"] is not None and decay["r_excess_atr"] < EDGE3_DECAY_FLOOR:
            decay["status"] = "DEAD_DECAY"
        else:
            decay["status"] = "OK"
        decay["decay_note"] = ("frozen_is_baseline_beta0 in this block is the IS baseline's "
                               "ambient slope, unchanged by construction; beta_fix is the "
                               "2022-2023 fix days' own slope")

        oos = arm_cell(symbol, code, ppw, pthr, phold, "OOS")
        sis = _sign(primary["r_excess_atr"]) if primary["r_excess_atr"] is not None else 0
        soos = _sign(oos["r_excess_atr"]) if oos["r_excess_atr"] is not None else 0
        if oos["n_trigger"] < EDGE3_OOS_TRIGGER_FLOOR:
            oos["status"] = "INCONCLUSIVE_OOS"
        elif sis < 0:
            # The IS effect points AGAINST the hypothesis (the pre-fix move
            # continues instead of reverting).  A holdout that agrees with that
            # is not a "sign flip" -- calling it one would misreport a
            # consistently contradicted arm as an unstable one.
            oos["status"] = "IS_CONTRADICTED"
        elif soos == sis and sis > 0 and oos["r_excess_atr"] > 0:
            oos["status"] = "SURVIVES_OOS"
        else:
            oos["status"] = "SIGN_FLIP"
        oos["sign_matches_is"] = bool(soos == sis and sis != 0)
        oos["sign_matches_is_doc_literal"] = bool(
            primary["r_fix_atr"] is not None and oos["r_fix_atr"] is not None
            and _sign(primary["r_fix_atr"]) == _sign(oos["r_fix_atr"])
            and _sign(primary["r_fix_atr"]) != 0)
        oos["holdout_note"] = ("frozen_is_baseline_beta0 here is the IS baseline slope "
                               "carried in unchanged; it is NOT an out-of-sample slope. "
                               "beta_fix is the OOS fix days' own slope")

        agree = 0
        agree_doc = 0
        for c in cells_out:
            if c["status"] == "UNDERPOWERED":
                continue
            if c["r_excess_atr"] is not None and sis != 0 \
                    and _sign(c["r_excess_atr"]) == sis and abs(c["r_excess_atr"]) >= EDGE3_FRAGILITY_R:
                agree += 1
            if c["r_fix_atr"] is not None and primary["r_fix_atr"] is not None \
                    and _sign(c["r_fix_atr"]) == _sign(primary["r_fix_atr"]) \
                    and abs(c["r_fix_atr"]) >= EDGE3_FRAGILITY_R:
                agree_doc += 1
        fragile = agree < EDGE3_FRAGILITY_CELLS

        if primary["status"] == "UNDERPOWERED":
            verdict = "UNDERPOWERED"
        elif decay["status"] == "DEAD_DECAY":
            verdict = "DEAD_DECAY"
        elif primary["status"] == "REFUTED":
            verdict = "REFUTED"
        elif oos["status"] in ("SIGN_FLIP", "IS_CONTRADICTED"):
            verdict = "REFUTED"
        elif oos["status"] == "INCONCLUSIVE_OOS":
            verdict = "INCONCLUSIVE_OOS"
        elif fragile:
            verdict = "FRAGILE"
        else:
            verdict = "SURVIVES"

        if role == "NEGATIVE_CONTROL":
            control_excess = primary["r_excess_atr"]
            verdict = "NEGATIVE_CONTROL"

        arm_blocks.append({
            "arm_id": "%s|%s" % (symbol, code), "symbol": symbol, "fix_code": code,
            "arm_role": role, "cells": cells_out, "primary_cell_result": primary,
            "decay_2022_2023": decay, "holdout": oos,
            "fragility": {"cells_agreeing": agree, "cells_total": len(cells_out),
                          "threshold": EDGE3_FRAGILITY_CELLS,
                          "cells_agreeing_doc_literal_r_fix": agree_doc,
                          "status": "FRAGILE" if fragile else "ROBUST"},
            "doc_literal": {
                "criterion": "R_FIX >= %.2f x ATR at n_days_measured >= %d, holdout keeps sign"
                             % (EDGE3_R_FLOOR, EDGE3_N_DAYS_FLOOR),
                "r_fix_atr_is": primary["r_fix_atr"], "se_fix": primary["se_fix"],
                "t_stat_fix": primary["t_stat_fix"],
                "n_days_measured_is": primary["n_days_measured"],
                "n_trigger_is": primary["n_trigger"],
                "r_fix_atr_oos": oos["r_fix_atr"], "n_days_measured_oos": oos["n_days_measured"],
                "r_fix_atr_2022_2023": decay["r_fix_atr"],
                "holdout_sign_matches": oos["sign_matches_is_doc_literal"],
                "status_is": primary["status_doc_literal"],
                "verdict": ("UNDERPOWERED" if primary["status_doc_literal"] == "UNDERPOWERED"
                            else ("REFUTED" if primary["status_doc_literal"] == "REFUTED"
                                  else ("SURVIVES" if oos["sign_matches_is_doc_literal"]
                                        else "REFUTED"))),
            },
            "verdict_basis": primary.get("verdict_basis"),
            "verdict": verdict,
        })

    run_void = bool(control_excess is not None and control_excess >= EDGE3_CONTROL_VOID)
    if run_void:
        for b in arm_blocks:
            if b["arm_role"] == "CANDIDATE":
                b["verdict"] = "VOID_ARTEFACT"

    tables = []
    p = os.path.join(out_dir, "fix_days.csv")
    sha, n = write_csv(p, FIXDAYS_HEADER, fix_rows)
    tables.append({"path": p, "sha256": sha, "rows": n})
    if cfg.emit_baseline_rows:
        p = os.path.join(out_dir, "fix_baseline.csv")
        sha, n = write_csv(p, FIXBASE_HEADER, base_rows)
        tables.append({"path": p, "sha256": sha, "rows": n})
    p = os.path.join(out_dir, "fix_baseline_cells.csv")
    sha, n = write_csv(p, FIXBASECELL_HEADER, base_cell_rows)
    tables.append({"path": p, "sha256": sha, "rows": n})
    p = os.path.join(out_dir, "fix_baseline_hours.csv")
    sha, n = write_csv(p, FIXBASEHOUR_HEADER, base_hour_rows)
    tables.append({"path": p, "sha256": sha, "rows": n})

    freq = {}
    for symbol, code, role in arms:
        cnt = sum(1 for r in fix_recs if r["symbol"] == symbol and r["fix_code"] == code
                  and r["pw"] == ppw and r["era"] == "IS" and r["ok"] and not r["has_news"]
                  and abs(r["premove_norm"]) >= pthr)
        years = cfg.is_end.year - cfg.is_start.year + 1
        freq["%s|%s" % (symbol, code)] = cnt / float(years)

    summary = {
        "schema_version": SUMMARY_SCHEMA,
        "hypothesis_id": "EDGE-3",
        "hypothesis_title": "London fix pre-move reversion (gold fixes, WM/R FX fix)",
        "code_version": CODE_VERSION,
        "generated_utc": cfg.now_iso,
        "rule_seal": {"primary_cell": EDGE3_PRIMARY_CELL,
                      "declared_trial_count": EDGE3_DECLARED_TRIALS,
                      "trials_schema": TRIALS_SCHEMA,
                      "arm_map": [{"symbol": s, "fix_code": c, "arm_role": r} for s, c, r in arms],
                      "program_doc": cfg.program_doc_meta,
                      "sealed_before_measurement": None},
        "dst_rules": [
            {"id": "qm.dst_rule.us.v1",
             "source": "framework/include/QM/QM_DSTAware.mqh:4-141",
             "start": "07:00 UTC 2nd Sunday of March", "end": "06:00 UTC 1st Sunday of November",
             "offset_dst_h": 3, "offset_std_h": 2},
            {"id": "qm.dst_rule.uk.v1",
             "start": "01:00 UTC last Sunday of March", "end": "01:00 UTC last Sunday of October",
             "offset_dst_h": 1, "offset_std_h": 0},
        ],
        "resolution": {"bar_timeframe": "M5", "tick_data_used": False,
                       "return_rule": "close-to-close, time stop only",
                       "stops_measurable": False, "mae_mfe_is_envelope": True,
                       "spread_modelled": False, "price_side": "bid"},
        "atr_definition": ("ATR(14) over 14 non-overlapping M5-aggregated 30-min bars "
                           "ending at the fix anchor; all 90 constituent M5 bars must be "
                           "present or the row is voided"),
        "arms": arm_blocks,
        "negative_control": {"arm_id": "XAUUSD.DWX|LDN_AM_1030",
                             "r_excess_atr": control_excess,
                             "void_threshold": EDGE3_CONTROL_VOID, "run_void": run_void},
        "cost_anchor": {"XAUUSD.DWX": {"class": "commodity", "pct_rate_rt": 5e-05,
                                       "flat_per_lot_rt": 0.0},
                        "EURUSD.DWX": {"class": "forex", "pct_rate_rt": 5e-05,
                                       "flat_per_lot_rt": 5.0},
                        "commission_bp_rt": 0.5, "spread_excluded": True},
        "frequency": {"triggers_per_arm_year": freq, "q02_floor": 5,
                      "floor_met": all(v >= 5 for v in freq.values())},
        "baseline_scopes": {
            "primary": "SESSION",
            "session_band_hours": EDGE3_SESSION_BAND_H,
            "fix_broker_hours": {c: sorted(fix_hours_by_code[c]) for c in sorted(fix_hours_by_code)},
            "note": (
                "the '>= %d min from every fix instant' rule removes the fix's OWN broker "
                "hour from its baseline by construction, so the ALL_HOURS pooled baseline "
                "contrasts a London/NY-overlap arm against a mostly Asian and early-European "
                "ambient.  Baseline cells are matched on weekday and minute-of-hour but "
                "CANNOT be matched on broker hour.  SESSION restricts the pseudo-anchors to "
                "+/- %dh of a fix hour, which is the closest like-for-like available; both "
                "scopes are reported per cell (r_base_atr / r_excess_atr are SESSION, "
                "r_base_atr_all_hours / r_excess_atr_all_hours are ALL_HOURS) and the "
                "per-hour composition is in fix_baseline_hours.csv"
                % (EDGE3_FIX_EXCL_MIN, EDGE3_SESSION_BAND_H)),
        },
        "refutation_statistic": (
            "PRIMARY (doc-literal, EDGE_DISCOVERY_PROGRAM_V1): R_FIX = mean(signed %d-min "
            "close-to-close return / ATR30) over qualifying fix days must be >= %.2f ATR at "
            "n_days_measured >= %d, and the holdout must keep the sign.  REPORTED ALONGSIDE "
            "(a STRENGTHENING that is NOT sealed and is confounded with time of day): "
            "R_EXCESS = R_FIX minus the weekday/minute-phase-matched ambient reversion, "
            "under a SESSION-banded and an ALL_HOURS baseline, at n_trigger >= %d.  Each "
            "cell carries verdict_basis naming which test refuted it."
            % (phold, EDGE3_R_FLOOR, EDGE3_N_DAYS_FLOOR, EDGE3_N_TRIGGER_FLOOR)),
        "failure_modes_checked": [
            "London->UTC->broker chain (two separate DST rules, dst_regime split emitted)",
            "ambient reversion / bid-only bounce scored as edge (R_EXCESS baseline subtraction)",
            "pipeline manufacturing reversion (LDN_AM_1030 negative control arm)",
            "pooled IS pass driven by 2018-2020 (2022-2023 decay clause)",
            "baseline re-estimated on holdout (IS cells frozen)",
            "session/gap spanning windows incl. the XAUUSD broker-hour-00 break",
            "calendar coverage hole faking has_news=0 (news_coverage_ok gate)",
        ],
        "open_gaps": [
            "spread: unmodelled; gold's spread is materially wider than a major's",
            "tick resolution: intrabar path unavailable, stops undetermined",
            "R_EXCESS as the primary criterion is a STRENGTHENING of the doc's literal "
            "R_FIX and needs an explicit seal before it may be cited as the verdict",
            "n_trigger >= %d is a second floor not present in the doc and needs a seal"
            % EDGE3_N_TRIGGER_FLOOR,
            ("has_news uses exactly the CALIBRATED instant set inherited from EDGE-1's "
             "Stage 0 (%d instants).  Releases Stage 0 could not calibrate are invisible "
             "to it, so n_excluded_has_news understates the true news contamination"
             % len(calibrated_instants)),
            ("three .DWX history holes fall inside the study window (2023-12-12..18, "
             "2025-10-08..11-03 FX-only, 2025-12-17..22); session_intact voids windows "
             "spanning them but cannot restore the missing days"),
        ],
        "deviations_from_spec": [
            "baseline cells are keyed (symbol, fix_code, era, weekday, minute_of_hour) "
            "WITHOUT broker_hour: the spec's hour-matched cell plus its '>=90 min from "
            "every fix instant of the day' rule is unsatisfiable, because the fix recurs "
            "daily at the same broker hour and minute, so an hour-matched cell would be "
            "empty by construction.  R_EXCESS is therefore CONFOUNDED WITH TIME OF DAY "
            "and is reported under two baseline scopes (SESSION, ALL_HOURS) rather than "
            "described as matched",
            "day_ok additionally requires news_coverage_ok: outside the calendar's covered "
            "span has_news=0 means 'no calendar', not 'no news'",
            "ATR(30m) is substituted by ATR(14) over M5-aggregated 30-min bars (no M30 "
            "series exists for these symbols)",
            "NEEDS A SEAL: R_EXCESS (baseline subtraction) as a criterion at all -- the "
            "doc's literal EDGE-3 refutation is R_FIX >= %.2f.  Every cell carries "
            "status_doc_literal and verdict_basis so the doc-literal test can be read on "
            "its own" % EDGE3_R_FLOOR,
            "NEEDS A SEAL: n_trigger >= %d is a second floor not present in the doc, and "
            "t_stat >= %.1f is an ADDED gate; neither appears in the doc's EDGE-3 "
            "refutation" % (EDGE3_N_TRIGGER_FLOOR, EDGE3_T_FLOOR),
            "NEEDS A SEAL: the fragility rule (>= %d of %d cells per arm at >= %.3f) is "
            "ADDED; cells_agreeing_doc_literal_r_fix is reported next to it"
            % (EDGE3_FRAGILITY_CELLS, EDGE3_CELLS_PER_ARM, EDGE3_FRAGILITY_R),
            "mae_45_bp / mfe_45_bp are signed by the FADE direction (trade_dir = "
            "-sign(premove_norm)), emitted as an explicit column; they remain an M5 "
            "ENVELOPE and may never support a stop-loss claim",
        ],
    }
    return {"summary": summary, "tables": tables,
            "arms": arm_blocks, "run_void": run_void}


# ===========================================================================
# manifest
# ===========================================================================

def git_state(repo_root: str) -> Tuple[Optional[str], Optional[bool]]:
    try:
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo_root,
                                         stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        return None, None
    try:
        st = subprocess.check_output(["git", "status", "--porcelain"], cwd=repo_root,
                                     stderr=subprocess.DEVNULL).decode()
        dirty = bool(st.strip())
    except Exception:
        dirty = None
    return commit, dirty


def build_manifest(hypothesis: str, cfg, bars: Dict[str, BarSeries], cal_meta: Dict,
                   tables: List[Dict], summary_path: str, summary_sha: str,
                   extra_inputs: List[Dict], declared_trials: int, primary_cell: Dict,
                   polarity_sha: Optional[str]) -> Dict:
    commit, dirty = git_state(cfg.repo_root)
    code_path = os.path.abspath(__file__)
    inputs = []
    for sym in sorted(bars.keys()):
        b = bars[sym]
        inputs.append({
            "role": "bars", "symbol": sym, "timeframe": "M5", "path": b.path.replace("\\", "/"),
            "sha256": b.sha256, "bytes": b.nbytes, "rows": b.rows,
            "period_first_broker": dt.datetime.utcfromtimestamp(b.first_epoch).strftime("%Y-%m-%dT%H:%M:%S"),
            "period_last_broker": dt.datetime.utcfromtimestamp(b.last_epoch).strftime("%Y-%m-%dT%H:%M:%S"),
            "period_first_utc": broker_epoch_to_utc(b.first_epoch).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "period_last_utc": broker_epoch_to_utc(b.last_epoch).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "time_base": "broker_naive_epoch (Darwinex NY-close, GMT+2/+3 US-DST)",
            "price_side": "bid",
            "producer": "SecretMission/EXPORT_DWX_FX_M5.mq5 | EXPORT_DWX_XAU_M5.mq5 (not in repo)",
        })
    inputs.extend(extra_inputs)
    return {
        "schema_version": MANIFEST_SCHEMA,
        "hypothesis_id": hypothesis,
        "generated_utc": cfg.now_iso,
        "host": {"repo_root": cfg.repo_root.replace("\\", "/"),
                 "python": "%d.%d.%d" % sys.version_info[:3],
                 "invocation": cfg.invocation},
        "code": {"path": "tools/strategy_farm/research/edge_lab_stats.py",
                 "file_sha256": sha256_file(code_path),
                 "file_sha256_lf": sha256_file_lf(code_path),
                 "code_version": CODE_VERSION,
                 "git_commit": commit, "git_dirty": dirty},
        "rule_seal": {"primary_cell": primary_cell,
                      "declared_trial_count": declared_trials,
                      "trials_schema": TRIALS_SCHEMA,
                      "polarity_map_sha256": polarity_sha,
                      "cluster_rank_map_sha256": sha256_bytes(json.dumps(
                          CLUSTER_PRIMARY_RANK, sort_keys=True,
                          separators=(",", ":")).encode("utf-8")),
                      "cluster_direction_rule": EDGE1_DIR_RULE_PRIMARY,
                      "doc_path": cfg.program_doc_meta.get("path"),
                      "doc_sha256": cfg.program_doc_meta.get("sha256"),
                      "doc_sha256_lf": cfg.program_doc_meta.get("sha256_lf"),
                      "doc_resolved_from": cfg.program_doc_meta.get("resolved_from"),
                      "sealed_before_measurement": (False if dirty is not False else True),
                      "seal_note": "git_dirty=true forces sealed_before_measurement=false"},
        "inputs": inputs,
        "dst_rules": [
            {"id": "qm.dst_rule.us.v1",
             "source": "framework/include/QM/QM_DSTAware.mqh:4-141",
             "start": "07:00 UTC 2nd Sunday of March", "end": "06:00 UTC 1st Sunday of November",
             "offset_dst_h": 3, "offset_std_h": 2},
            {"id": "qm.dst_rule.uk.v1",
             "start": "01:00 UTC last Sunday of March", "end": "01:00 UTC last Sunday of October",
             "offset_dst_h": 1, "offset_std_h": 0},
        ],
        "period": {"is_start": cfg.is_start.isoformat(), "is_end": cfg.is_end.isoformat(),
                   "oos_start": cfg.oos_start.isoformat(), "oos_end": cfg.oos_end.isoformat(),
                   "decay_subsample": ["2022-01-01", "2023-12-31"]},
        "params": {"calib_max_offset_min": cfg.calib_max_offset_min,
                   "calib_min_obs": cfg.calib_min_obs,
                   "calib_year_lo": cfg.calib_year_lo, "calib_year_hi": cfg.calib_year_hi,
                   "calib_era_split_year": cfg.calib_era_split_year,
                   "surprise_min_history": cfg.surprise_min_history,
                   "emit_baseline_rows": cfg.emit_baseline_rows,
                   "edge1_include_gbpjpy": cfg.edge1_include_gbpjpy,
                   "edge3_diagnostics": cfg.edge3_diagnostics},
        "outputs": sorted([{"path": t["path"].replace("\\", "/"), "sha256": t["sha256"],
                            "rows": t["rows"]} for t in tables]
                          + [{"path": summary_path.replace("\\", "/"),
                              "sha256": summary_sha, "rows": None}],
                         key=lambda x: x["path"]),
        "determinism": {"rng_used": False, "rng_seed": None, "csv_encoding": "utf-8",
                        "csv_newline": "\\n", "float_format": "%.10g",
                        "reproducible": ("re-running with identical input shas and the same "
                                         "--now-utc must reproduce identical output shas")},
        "constraints_honoured": {"read_only_factory": True, "t_live_untouched": True,
                                 "registry_unmodified": True, "no_ml": True,
                                 "raw_ticks_in_model_context": False},
    }


# ===========================================================================
# CLI
# ===========================================================================

class Config(object):
    pass


def _date(s: str) -> dt.date:
    return dt.datetime.strptime(s, "%Y-%m-%d").date()


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="EDGE-lab refutation statistics (EDGE-1, EDGE-3)")
    p.add_argument("--hypothesis", choices=["EDGE-1", "EDGE-3", "both"], default="both")
    p.add_argument("--bars-dir", default=DEFAULT_BARS_DIR)
    p.add_argument("--calendar", default=DEFAULT_CALENDAR)
    p.add_argument("--out", default=DEFAULT_OUT_ROOT)
    p.add_argument("--repo-root", default=os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..")))
    p.add_argument("--is-start", type=_date, default=_date("2018-01-01"))
    p.add_argument("--is-end", type=_date, default=_date("2023-12-31"))
    p.add_argument("--oos-start", type=_date, default=_date("2024-01-01"))
    p.add_argument("--oos-end", type=_date, default=_date("2025-12-31"))
    p.add_argument("--now-utc", default=None,
                   help="freeze generated_utc (determinism / tests)")
    p.add_argument("--polarity-map", default=None,
                   help="JSON {event: +1|-1} overriding the embedded sealed map")
    p.add_argument("--program-doc", default=None,
                   help="path to the sealed EDGE program doc; default resolves "
                        "<repo-root>/%s then %s/%s" % (DEFAULT_PROGRAM_DOC_REL,
                                                       CANONICAL_REPO_ROOT,
                                                       DEFAULT_PROGRAM_DOC_REL))
    p.add_argument("--surprise-min-history", type=int, default=EDGE1_SURPRISE_MIN_HISTORY,
                   help="[power knob, recorded in the manifest] minimum prior surprises "
                        "before a z is computable")
    p.add_argument("--no-baseline-rows", action="store_true",
                   help="skip the per-bar baseline CSVs (cells are always written)")
    p.add_argument("--edge1-include-gbpjpy", action="store_true",
                   help="give GBP its second M5 cross (off by default)")
    p.add_argument("--edge3-diagnostics", action="store_true",
                   help="also run the cross-paired diagnostic arms")
    p.add_argument("--calib-max-offset-min", type=int, default=CALIB_MAX_OFFSET_MIN,
                   help="[power knob, recorded in the manifest] Stage-0 offset grid half-width")
    p.add_argument("--calib-min-obs", type=int, default=CALIB_MIN_OBS,
                   help="[power knob, recorded in the manifest] Stage-0 min events per group")
    p.add_argument("--calib-year-lo", type=int, default=2018)
    p.add_argument("--calib-year-hi", type=int, default=2025)
    p.add_argument("--calib-era-split-year", type=int, default=CALIB_ERA_SPLIT_YEAR,
                   help="audit-only year split for the calibration sub-era columns; the "
                        "AMBIGUOUS decision uses the group's own chronological midpoint")
    return p


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    cfg = Config()
    cfg.repo_root = args.repo_root
    cfg.is_start, cfg.is_end = args.is_start, args.is_end
    cfg.oos_start, cfg.oos_end = args.oos_start, args.oos_end
    cfg.emit_baseline_rows = not args.no_baseline_rows
    cfg.edge1_include_gbpjpy = args.edge1_include_gbpjpy
    cfg.edge3_diagnostics = args.edge3_diagnostics
    cfg.calib_max_offset_min = args.calib_max_offset_min
    cfg.calib_min_obs = args.calib_min_obs
    cfg.calib_year_lo = args.calib_year_lo
    cfg.calib_year_hi = args.calib_year_hi
    cfg.calib_era_split_year = args.calib_era_split_year
    cfg.polarity_map = args.polarity_map
    cfg.surprise_min_history = args.surprise_min_history
    cfg.now_iso = args.now_utc or dt.datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")

    # --- resolve + hash the sealed program doc ------------------------------
    doc_meta = {"path": None, "sha256": None, "sha256_lf": None, "bytes": None,
                "resolved_from": None,
                "note": ("the sealed doc is the source of the refutation criteria; a null "
                         "sha256 means the criteria could not be verified against it and "
                         "no seal may be claimed")}
    cands = []
    if args.program_doc:
        cands.append(("explicit", args.program_doc))
    cands.append(("repo_root", os.path.join(cfg.repo_root, DEFAULT_PROGRAM_DOC_REL)))
    cands.append(("canonical_repo", os.path.join(CANONICAL_REPO_ROOT, DEFAULT_PROGRAM_DOC_REL)))
    for src, cand in cands:
        if os.path.exists(cand):
            doc_meta.update({"path": cand.replace("\\", "/"),
                             "sha256": sha256_file(cand),
                             "sha256_lf": sha256_file_lf(cand),
                             "bytes": os.path.getsize(cand),
                             "resolved_from": src})
            break
    cfg.program_doc_meta = doc_meta
    cfg.invocation = "python -X utf8 tools/strategy_farm/research/edge_lab_stats.py " + " ".join(sys.argv[1:])

    polarity = dict(EVENT_POLARITY)
    if args.polarity_map:
        with open(args.polarity_map, "r", encoding="utf-8") as f:
            polarity = {str(k): int(v) for k, v in json.load(f).items()}
    polarity_sha = sha256_bytes(json.dumps(polarity, sort_keys=True, ensure_ascii=False,
                                           separators=(",", ":")).encode("utf-8"))

    want_syms = set()
    if args.hypothesis in ("EDGE-1", "both"):
        m = EDGE1_SYMBOL_MAP_GBPJPY if cfg.edge1_include_gbpjpy else EDGE1_SYMBOL_MAP_BASE
        for v in m.values():
            want_syms.update(v)
        want_syms.update(EDGE1_PROBE_SYMBOL.values())
    if args.hypothesis in ("EDGE-3", "both"):
        for s, _, _ in EDGE3_ARMS:
            want_syms.add(s)
        if cfg.edge3_diagnostics:
            for s, _, _ in EDGE3_DIAGNOSTIC_ARMS:
                want_syms.add(s)
        want_syms.update(EDGE1_PROBE_SYMBOL.values())   # Stage 0 always runs

    bars: Dict[str, BarSeries] = {}
    for sym in sorted(want_syms):
        path = os.path.join(args.bars_dir, "%s_M5.csv" % sym)
        if not os.path.exists(path):
            raise SystemExit("missing bar file: %s" % path)
        sys.stderr.write("[edge_lab] loading %s\n" % path)
        bars[sym] = BarSeries(sym, path)

    sys.stderr.write("[edge_lab] loading calendar %s\n" % args.calendar)
    cal_rows, cal_sha, cal_bytes, cal_n = load_calendar(args.calendar)
    cal_input = {"role": "calendar", "path": args.calendar.replace("\\", "/"),
                 "sha256": cal_sha, "bytes": cal_bytes, "rows": cal_n,
                 "period_first": cal_rows[0].raw_utc.strftime("%Y-%m-%d") if cal_rows else None,
                 "period_last": cal_rows[-1].raw_utc.strftime("%Y-%m-%d") if cal_rows else None,
                 "timestamp_column_used": "DateTime_UTC + Stage-0 calibration offset",
                 "datetime_eet_used": False, "timestamps_calibrated": True,
                 "known_at_utc_available": False,
                 "defect_note": ("DateTime_UTC displaces a large class of US 08:30-ET "
                                 "releases, and the displacement is NOT a constant: raw "
                                 "USD NFP stamps sit at Thu 19:30Z Apr-Sep and Thu 20:30Z "
                                 "Oct-Mar, so the -17h/-16h split follows a DST rule of "
                                 "its own.  Stage 0 recovers ONE offset per (currency, "
                                 "event) group; Stage 0b then verifies every individual "
                                 "instant against its group's modal home wall-clock time "
                                 "and its own local tickvol peak, and VOIDS the rows the "
                                 "constant misplaces.  Neither stage ever falls back to "
                                 "the raw timestamp and neither re-fits an offset per "
                                 "event")}
    cost_path = os.path.join(cfg.repo_root, "framework", "registry", "live_commission.json")
    extra_inputs = [cal_input]
    if os.path.exists(cost_path):
        extra_inputs.append({"role": "cost_registry",
                             "path": "framework/registry/live_commission.json",
                             "sha256": sha256_file(cost_path),
                             "sha256_lf": sha256_file_lf(cost_path),
                             "bytes": os.path.getsize(cost_path),
                             "hash_note": ("sha256 is the on-disk bytes of THIS checkout; "
                                           "sha256_lf is CRLF-normalised and is the value "
                                           "to compare across checkouts")})

    sys.stderr.write("[edge_lab] stage 0 calibration\n")
    calib_rows, applied, calib_counts, verify, calib_event_rows = run_stage0(cal_rows, bars, cfg)

    results = {}
    if args.hypothesis in ("EDGE-1", "both"):
        out_dir = os.path.join(args.out, "EDGE-1")
        sys.stderr.write("[edge_lab] EDGE-1\n")
        r1 = run_edge1(bars, cal_rows, calib_rows, applied, calib_counts, verify,
                       polarity, polarity_sha, cfg, out_dir, calib_event_rows)
        sp = os.path.join(out_dir, "summary.json")
        ssha = write_json(sp, _clean_floats(r1["summary"]))
        man = build_manifest("EDGE-1", cfg, bars, cal_input, r1["tables"], sp, ssha,
                             extra_inputs, EDGE1_DECLARED_TRIALS, EDGE1_PRIMARY_CELL,
                             polarity_sha)
        write_json(os.path.join(out_dir, "manifest.json"), _clean_floats(man))
        results["EDGE-1"] = r1
    else:
        r1 = None

    if args.hypothesis in ("EDGE-3", "both"):
        out_dir = os.path.join(args.out, "EDGE-3")
        sys.stderr.write("[edge_lab] EDGE-3\n")
        if r1 is not None:
            instants = r1["calibrated_instants"]
        else:
            instants = []
            for r in cal_rows:
                if r.impact != "High" or r.currency not in EDGE1_CURRENCIES:
                    continue
                off = applied.get((r.currency, r.event))
                if off is None:
                    continue
                instants.append(utc_to_broker_epoch(r.raw_utc + dt.timedelta(minutes=off)))
            instants = sorted(set(instants))
        # coverage is measured over EVERY calendar row, not just the calibrated
        # ones: "the calendar covers this day" is a property of the file.
        cal_days = sorted({r.raw_utc.date().toordinal() for r in cal_rows})
        r3 = run_edge3(bars, instants, cal_days, cfg, out_dir)
        sp = os.path.join(out_dir, "summary.json")
        ssha = write_json(sp, _clean_floats(r3["summary"]))
        man = build_manifest("EDGE-3", cfg, bars, cal_input, r3["tables"], sp, ssha,
                             extra_inputs, EDGE3_DECLARED_TRIALS, EDGE3_PRIMARY_CELL, None)
        write_json(os.path.join(out_dir, "manifest.json"), _clean_floats(man))
        results["EDGE-3"] = r3

    for hid in sorted(results.keys()):
        s = results[hid]["summary"]
        sys.stderr.write("[edge_lab] %s verdict=%s\n"
                         % (hid, s.get("verdict") or [a["verdict"] for a in s.get("arms", [])]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
