# XAU/XAG Weekly Acceleration-Overshoot Reversion - Source Approval

Date: 2026-08-20

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch on 2026-08-20. The mission names
a market-neutral `XAUUSD` / `XAGUSD` gold/silver-ratio basket as an allowed
carrier, requires one new non-duplicate structural low-frequency edge under
the reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-waccel-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-WACCEL-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-WACCEL-RV-2026`
- carrier: exact `XAUUSD.DWX` / `XAGUSD.DWX` D1 paired basket
- state: the two immediately preceding synchronized, non-overlapping weekly
  gold-minus-silver log returns have the same strict sign and the newest
  absolute move is strictly larger than the older move
- direction: fade the accelerating newest relative move with an equal-
  notional opposite-leg package
- lifecycle: one consumed attempt on the first tradable bar of each broker
  week and first-later-week flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
   covering Karsten Schweikert (2018), *Journal of Banking & Finance* 88,
   44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and the supplemental robust
   fractional-cointegration lineage recorded there.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   covering CME Group's gold/silver ratio-spread research.

The bounded child extraction is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WACCEL-RV-2026/source.md`.
No new online page, blocked content, inferred table value, or unrecorded
source is used.

Schweikert supports testing a potentially state-dependent long-run gold/silver
relationship rather than assuming one immutable equilibrium. CME defines the
ratio and supports treating gold and silver as one intermarket relative-value
carrier. Neither source tests two same-sign adjacent weekly relative returns,
strict newest-move acceleration, an inverse one-week package, Darwinex
continuous CFDs, equal-notional sizing, ATR stops, or this lifecycle. Those
are disclosed QM choices. No efficacy, density, neutrality, CFD-equivalence,
or decorrelation result transfers.

## Locked Mechanic

1. Repair orphan, duplicate, same-side, wrong-symbol, wrong-magic, stopless,
   notional-invalid, later-week, or stale owned exposure before entry gates.
2. Require exact `XAUUSD.DWX` D1 host, exact `XAGUSD.DWX` D1 companion,
   synchronized timestamps, and locked backtest/news/Friday inputs.
3. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of raw host-bar open, reconstruct the three immediately
   preceding consecutive completed synchronized week-end closes for both legs.
4. For completed week-end index 1 newest through 3 oldest, compute
   `s_i=ln(XAU_i)-ln(XAG_i)`, `r_new=s_1-s_2`, and `r_old=s_2-s_3`.
   Require positive finite prices, finite non-zero returns, identical strict
   signs, and `abs(r_new)>abs(r_old)`. Equality, opposed signs, a smaller
   newest move, zero, missing weeks, or timestamp disagreement remains flat.
5. If both returns are positive, SELL XAU and BUY XAG. If both are negative,
   BUY XAU and SELL XAG. Signal magnitude does not scale risk.
6. Persist the current Monday anchor before spread, quote, ATR, sizing, news,
   or order gates. A rejected or failed attempt may not retry that week.
7. Target one-to-one absolute entry notional with at most 20 percent lot-step
   mismatch. Constrain combined broker-normalized stop risk to one
   `RISK_FIXED=1000` package.
8. Attach one frozen `3.5*ATR(20,D1)` stop per leg, no target, and require
   XAU/XAG spreads at or below 1,500/500 points respectively.
9. Keep both news axes and Friday close OFF. Close the complete package at the
   first later Monday anchor or after ten elapsed calendar days. Never retry,
   trail, partially close, scale in, grid, martingale, or pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_ACCELERATION_TRANSLATION_RISK`: one bounded
  `source_id` carries named peer-reviewed DOI and official exchange lineages;
  the same-sign acceleration fade is explicitly an untested QM hypothesis.
- R2 `PASS`: endpoints, return orientation, strict state, side, attempt,
  aggregate risk, spreads, and lifecycle are locked and mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU
  and XAG D1 histories supply every runtime input; Q02 owns alignment and
  continuous-CFD basis falsification.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, martingale,
  scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical `research_dedup_check.py` scan covered 4,563 registry rows and
625 root cards and returned `CLEAN`, with no exact or fuzzy match. Manual
family review distinguishes:

- `QM5_41066_xauxag-wdecay-rv`, which requires two strict same-sign weekly
  relative returns and a strictly *smaller* newest move; this candidate
  requires a strictly *larger* newest move, so their entry states are
  mutually exclusive;
- `QM5_41075_xauxag-wovershoot-rv`, which requires strict opposite signs and
  a dominant newest reversal; this candidate requires strict same-sign
  continuation before the fade;
- `QM5_20275_gsr-runfade`, which requires a fresh run of five same-sign D1
  relative returns and exits on a counter-return; this candidate aggregates
  exactly two non-overlapping completed broker weeks and holds one week;
- `QM5_20157`, `QM5_20161`, `QM5_20263`, `QM5_20265`, and `QM5_20268`, which
  estimate rolling centers, regression residuals, robust scores, channels,
  or empirical tails; this candidate estimates none; and
- `QM5_41030`, `QM5_41039`, `QM5_41040`, `QM5_41057`, `QM5_41060`, and
  `QM5_41062`, which use intraday-flow decomposition, weekly ranges and fresh
  breaks, or weekend gaps; this candidate uses week-end closes only.

The exact three weekly endpoints, two adjacent non-overlapping relative
returns, strict sign agreement, strict newest absolute acceleration, inverse
shared-return side, weekly attempt, equal-notional aggregate-risk package,
and next-week exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_SAME_SIGN_WEEKLY_ACCELERATION_OVERSHOOT_REVERSION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is eight to eighteen completed packages per full post-
warm-up year. Q02 must retire below five per year, at zero trades or
nonpositive governed economics, or on any synchronization, week-anchor,
endpoint, return, sign, acceleration, direction, attempt, basket, risk,
lifecycle, or determinism defect. No weak result may be rescued by accepting
equality or opposed signs, changing direction or hold, or adding a threshold,
fitted center, beta, calendar, trend, or volatility filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.

