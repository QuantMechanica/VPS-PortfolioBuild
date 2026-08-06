---
source_id: MEHLITZ-PAPAILIAS-WTI-VRRSM-2026
title: WTI variance-ratio memory conditioned return-signal momentum
publisher: The European Journal of Finance / Journal of Banking & Finance
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-06
strategy_ids:
  - MEHLITZ-PAPAILIAS-WTI-VRRSM-2026_S01
parent_sources:
  - MEHLITZ-AUER-MEM-2024
  - PAPAILIAS-RSM-2021
---

# WTI Variance-Ratio / Return-Signal Momentum Source Packet

## Source identity and complete-read evidence

This packet joins two governed peer-reviewed lineages whose complete mechanics,
source scope, adverse boundaries, and durable citations are already preserved
locally:

1. Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced
   momentum in commodity futures markets," *The European Journal of Finance*
   30(8), 773-802, DOI `10.1080/1351847X.2023.2220118`. The complete strategy
   chapter in the open doctoral precursor, including methodology, robustness,
   results, conclusion, and Appendix C, was reviewed end-to-end and is recorded
   in `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`.
2. Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021),
   "Return Signal Momentum," *Journal of Banking & Finance* 124, 106063,
   DOI `10.1016/j.jbankfin.2021.106063`. The complete accepted manuscript,
   including Appendices A-I and WTI-specific Tables G.1-G.3, is reviewed in
   `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`.

Both source universes explicitly include WTI futures. Mehlitz and Auer supply
the 32-completed-month, q=2 heteroskedasticity-robust Lo-MacKinlay
variance-ratio test, its two-sided 10% significance threshold, and the rule
that persistent states continue a return direction while anti-persistent
states reverse it. Papailias et al. supply a direction state based on the
equal-weight fraction of non-negative returns across twelve completed months,
with the fixed threshold `P >= 0.40` long and `P < 0.40` short.

Neither paper substitutes twelve-month sign breadth for the latest one-month
winner/loser state inside the variance-ratio matrix. That conjunction is a
transparent QM hypothesis. No paper coefficient, performance result, trade
count, drawdown, cost, correlation, or WTI-CFD claim transfers.

The public-source router classified the canonical open RSM manuscript URL as
`DEFERRED:SOURCE_POLICY` on 2026-08-06 because the generic runtime adapter is
router-only. This packet does not claim a new retrieval from that URL; it
relies on the already-approved durable complete-read parent record.

## Bounded mechanization

`MEHLITZ-PAPAILIAS-WTI-VRRSM-2026_S01` locks one monthly WTI rule:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker-calendar month;
- history: thirty-three consecutive completed broker-month closes defining
  thirty-two chronological monthly log returns;
- memory state: q=2 robust variance-ratio z-statistic over all thirty-two
  returns, actionable only when `abs(z) > 1.64485362695147`;
- direction state: count non-negative signs in the newest twelve of those
  returns, set `P = count / 12`, and map `P >= 0.40` long, otherwise short;
- entry direction: `sign_direction * sign(z)`, so significant persistence
  follows the return-sign state and significant anti-persistence reverses it;
- flat state: insignificant memory, incomplete or nonconsecutive endpoints,
  invalid arithmetic, or unavailable risk inputs;
- lifecycle: close before each monthly decision, persist one consumed attempt
  per month before fallible gates, and hold no longer than forty calendar days;
- risk controls: fixed `3.0 * ATR(20,D1)` hard stop, 1,500-point spread cap,
  no target, no scale-in, and no Friday close; and
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The monthly clock offers at most twelve decisions per complete post-warm-up
year. The parent variance-ratio extraction estimated six to ten significant
months per year; this remains an unproved density prior. Q02 retires the exact
candidate below five completed packages per full post-warm-up year.

Runtime reads only native MT5 OHLC, ATR, broker calendar, spread, quotes,
positions, deal history, and framework state. It does not read futures curves,
inventory releases, volume, open interest, files, APIs, or trained outputs.

## Non-duplicate boundary

The deterministic pre-allocation checker scanned 4,302 EA-registry rows and
419 canonical cards. It found no exact identity and no fuzzy match above its
threshold. Manual mechanic review fixes the nearest boundaries:

- `QM5_13134_energy-vr-mom` applies the same robust q=2 memory state to only
  the newest one-month return sign. This candidate instead uses the breadth of
  twelve binary completed-month signs and the fixed 0.40 RSM threshold.
- `QM5_13150_wti-signmom` trades the twelve-sign state every month without a
  variance-ratio estimator, significance gate, persistence continuation, or
  anti-persistence reversal.
- `QM5_20244_wti-trend-sign` requires agreement between twelve-month
  cumulative return and twelve-sign breadth; it neither estimates serial
  dependence nor reverses the sign state in an anti-persistent regime.
- `QM5_20222_wti-seas-sign` compares return-sign breadth with a fixed physical
  winter/summer direction, not a statistical memory regime.
- `QM5_20242_xng-rsm-window` is an XNG seasonal-window gate and never computes
  WTI variance-ratio memory.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator pullback
  with a different symbol, clock, state, and holding period.

The thirty-two-return robust q=2 test, two-sided fixed significance boundary,
newest-twelve binary-sign probability, fixed 0.40 direction state,
persistence-follow / anti-persistence-reverse matrix, and monthly consumed
attempt are jointly load-bearing. Removing the return-sign breadth recreates
the existing variance-ratio parent; removing the memory state recreates the
existing RSM parent.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed papers with DOI records, governed
  complete-read packets, and explicit WTI membership.
- R2: PASS. Completed endpoints, both state formulas, fixed thresholds,
  direction matrix, monthly renewal, stop, stale exit, spread cap, and retry
  state are frozen.
- R3: PASS. Registered `XTIUSD.DWX` D1 history and native MT5 state supply
  every runtime input.
- R4: PASS. Deterministic arithmetic only; no trained model, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramiding.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest setfile,
and one paced Q02 enqueue under the 2026-08-06 OWNER mission. It does not
authorize a manual backtest; live, demo, or shadow execution; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
changes; correlation waivers; or post-result parameter repair.
