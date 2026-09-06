# XTI/XNG Weekly Close-Location Divergence Reversion - Source Approval

Date: 2026-09-06

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced logical-basket Q02 enqueue if the fresh host-CPU
admission check is below its ceiling. This does not authorize a manual tester
dispatch.

Authority: the current explicit OWNER commodity/energy sleeve mission
delivered to Codex on branch `agents/board-advisor`. It requests one new,
committed, non-duplicate structural low-frequency commodity edge, explicitly
permits a market-neutral basket, requires reputable sources and fixed-risk
backtests, and forbids live and portfolio-gate changes.

## Candidate Identity

- proposed slug: `xtixng-wclv-div-rv`
- strategy ID: `AI-CODEX-XTIXNG-WCLVDIV-RV-20260906_S01`
- source ID: `AI-CODEX-XTIXNG-WCLVDIV-RV-20260906`
- carrier: exact `XTIUSD.DWX` / `XNGUSD.DWX` D1 opposed-leg basket
- state: the two legs finish the same immediately completed broker week in
  strict opposite outer terciles of their own weekly high-low ranges
- direction: sell the upper-location leg and buy the lower-location leg
- lifecycle: one consumed weekly attempt and first-later-week closure

The deterministic allocator owns the EA ID. This decision neither predicts
nor hand-reserves it.

## Approved Source Basis

The complete governed parent packet
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
`4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`,
was read before approval. It covers Villar and Joutz (2006), U.S. EIA, and
Ramberg and Parsons (2012), *The Energy Journal* 33(2), DOI
`10.5547/01956574.33.2.2`, including their adverse evidence on weak and
time-varying oil/gas linkage.

The bounded child extraction is
`strategy-seeds/sources/AI-CODEX-XTIXNG-WCLVDIV-RV-20260906/source.md`.
No new online page or unrecorded empirical result is used. The sources support
the energy relative-value carrier; they do not test the CLV rule, direction,
CFD translation, fixed-risk basket, or portfolio correlation.

## Locked Mechanic

1. Require exact XTI host, XNG companion, D1, synchronized timestamps, and
   locked backtest/news/Friday inputs.
2. On the first synchronized tradable bar of a new broker week, within 180
   minutes, persist the attempt before every fallible gate.
3. Aggregate the immediately preceding synchronized broker week. Require
   three to five unique sessions and positive finite OHLC values.
4. Compute each leg's `clv=(week_close-week_low)/(week_high-week_low)`.
5. Qualify only strict XTI-above-2/3 plus XNG-below-1/3, or the reverse.
6. Fade the upper-location leg through one opposed, equal-notional package.
7. Cap combined frozen-stop risk at `RISK_FIXED=1000`; attach per-leg
   `3.5*ATR(20,D1)` stops and no targets.
8. Close at the first later broker week or after ten calendar days. No retry,
   current-week leakage, partial close, trail, scale-in, grid, martingale,
   fitted model, external data, or single-leg fallback is permitted.

## Reputable-Source Criteria

- R1 `PASS_WITH_RULE_TRANSLATION_RISK`: government plus peer-reviewed source
  lineage, with instability and the untested QM conjunction explicit.
- R2 `PASS`: exact endpoints, aggregation, strict state, side, attempt, risk,
  stops, atomicity, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 history and MT5 execution state supply all inputs.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned signal,
  external runtime feed, grid, or martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,844 registry rows and
1,457 cards. It found no exact match and one fuzzy sibling,
`QM5_41088_xauxag-wclv-div-rv`, because the transparent statistic is shared.
Manual review resolves that match as a carrier port: the new rule owns the
oil/gas physical thesis, energy contracts, cost surface, and realized return
stream rather than the existing gold/silver exposure. No result, parameter,
or correlation claim transfers.

Existing XTI/XNG systems use ratio levels, regression residuals, fixed-window
returns, monthly robust estimators, calendar/weekday states, common-shock
returns, flow decomposition, or weekly path changes. None uses the exact pair
of independently normalized completed-week close locations. The carrier,
strict opposite outer-tercile state, contrarian side, weekly clock, aggregate
risk, and next-week lifecycle are jointly load-bearing. Verdict:
`FUZZY_MECHANIC_PORT_RESOLVED_DISTINCT_XTIXNG_COMPLETED_WEEK_OPPOSITE_LEG_CLOSE_LOCATION_TERCILE_REVERSION`.

## Kill And Safety Boundary

Expected cadence is six to twelve completed packages per full post-warm-up
year. Q02 retires below five per year, on nonpositive economics, or on any
identity, synchronization, CLV, side, sizing, stop, atomicity, lifecycle, or
determinism defect. No weak result may be rescued by parameter or rule changes.

This approval excludes manual backtests, terminal control, live/demo/shadow/
optimization presets, AutoTrading, `T_Live`, deploy or live manifests,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. At or above the CPU ceiling, stop before Q02 mutation and
record a non-live handoff.
