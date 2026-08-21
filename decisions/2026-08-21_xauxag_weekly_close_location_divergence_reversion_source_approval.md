# XAU/XAG Weekly Close-Location Divergence Reversion - Source Approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch on 2026-08-21. The mission names
a market-neutral `XAUUSD` / `XAGUSD` gold/silver-ratio basket as an allowed
carrier, requires one new non-duplicate structural low-frequency edge under
the reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-wclv-div-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026`
- carrier: exact `XAUUSD.DWX` / `XAGUSD.DWX` D1 paired basket
- state: over the exact same immediately completed broker week, one metal
  closes strictly in its own upper range tercile and the other strictly in its
  own lower range tercile
- direction: sell the upper-location metal and buy the lower-location metal
  as one equal-notional package for one broker week
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
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026/source.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

Schweikert supports testing a potentially state-dependent long-run gold/silver
relationship rather than assuming one immutable equilibrium. CME defines the
ratio and supports treating gold and silver as one intermarket relative-value
carrier. Neither source tests opposite weekly close-location terciles, the
contrarian direction, Darwinex continuous CFDs, equal-notional sizing, ATR
stops, or this lifecycle. Those are disclosed QM choices. No efficacy,
density, neutrality, CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

1. Repair orphan, duplicate, same-side, wrong-symbol, wrong-magic, stopless,
   notional-invalid, later-week, or stale owned exposure before entry gates.
2. Require exact `XAUUSD.DWX` D1 host, exact `XAGUSD.DWX` D1 companion,
   synchronized timestamps, and locked backtest/news/Friday inputs.
3. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of raw host-bar open, reconstruct every synchronized
   D1 bar in the immediately preceding completed broker week. Require three to
   five unique sessions, identical timestamps on both legs, and no bar from
   the current decision week.
4. For each leg aggregate the completed week's high, low, and final close.
   Require finite positive closes and strict positive ranges. Compute
   `clv=(close-low)/(high-low)` separately for gold and silver.
5. Qualify only when gold CLV is strictly greater than `2/3` and silver CLV is
   strictly less than `1/3`, or gold CLV is strictly less than `1/3` and
   silver CLV is strictly greater than `2/3`. Equality, an interior value,
   invalid arithmetic, incomplete history, or timestamp disagreement is flat.
6. Sell the upper-tercile leg and buy the lower-tercile leg. CLV distance does
   not scale risk.
7. Persist the current Monday anchor before spread, quote, ATR, sizing, news,
   or order gates. A rejected or failed attempt may not retry that week.
8. Target one-to-one absolute entry notional with at most 20 percent lot-step
   mismatch. Constrain combined broker-normalized stop risk to one
   `RISK_FIXED=1000` package.
9. Attach one frozen `3.5*ATR(20,D1)` stop per leg, no target, and require
   XAU/XAG spreads at or below 1,500/500 points respectively.
10. Keep both news axes and Friday close OFF. Close the complete package at
    the first later Monday anchor or after ten elapsed calendar days. Never
    retry, trail, partially close, scale in, grid, martingale, or pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_CLOSE_LOCATION_TRANSLATION_RISK`: one bounded
  `source_id` carries named peer-reviewed DOI and official exchange lineages;
  the weekly opposite-tercile fade is explicitly an untested QM hypothesis.
- R2 `PASS`: week membership, synchronized aggregation, CLV orientation,
  strict tercile state, side, attempt, aggregate risk, spreads, and lifecycle
  are locked and mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU
  and XAG D1 histories supply every runtime input; Q02 owns alignment and
  continuous-CFD basis falsification.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, martingale,
  scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical `research_dedup_check.py` scan covered 4,577 registry rows and
625 root cards and returned `CLEAN`, with no exact or fuzzy match. Manual
family review distinguishes:

- `QM5_41083_xauxag-wlegdiv-rv`, which requires opposite signed completed-
  week returns; this candidate ignores open-to-close sign and classifies each
  leg's final close inside its own weekly high-low auction range;
- `QM5_41079_xauxag-wclose-extreme-rv`, which ranks the final ratio close
  against earlier synchronized ratio closes in that week; this candidate
  compares neither ratio levels nor earlier closes and instead requires
  opposite per-leg range locations;
- `QM5_41086_xauxag-commonshock-rv`, which requires same-sign weekly leg
  returns with strict magnitude dispersion; this candidate requires no
  return-sign or magnitude state;
- `QM5_41060_xauxag-week-nr7-brk`, which ranks completed-week relative ranges
  and waits for a current-week breakout rather than entering a first-bar fade;
- `QM5_41062_xauxag-wgap-fade`, which uses opposed weekend gaps instead of
  completed-week auction locations; and
- existing rolling ratio, fitted residual, robust-score, empirical-tail,
  calendar-rank, flow-decomposition, weekly return-path, and monthly-rank
  systems, none of which use this exact paired CLV state.

The exact paired carrier, one synchronized completed-week OHLC package, strict
opposite outer-tercile per-leg close locations, contrarian package, weekly
attempt, equal-notional aggregate-risk sizing, and next-week exit are jointly
load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_WEEK_OPPOSITE_LEG_CLOSE_LOCATION_TERCILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately six to twelve completed packages per full
post-warm-up year. Q02 must retire below five per year, at zero trades or
nonpositive governed economics, or on any synchronization, week membership,
OHLC aggregation, CLV, threshold, direction, attempt, basket, risk, lifecycle,
or determinism defect. No weak result may be rescued by moving either tercile
boundary, accepting equality or same-tercile states, changing direction or
hold, or adding a ratio center, beta, trend, calendar, or volatility filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
