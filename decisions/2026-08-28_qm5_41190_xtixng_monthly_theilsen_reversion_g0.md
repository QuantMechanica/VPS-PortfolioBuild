# QM5_41190 XTI/XNG Monthly Theil-Sen Ratio Reversion — G0 Decision

Date: 2026-08-28

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41190_xtixng-mtheilsen-rv_card.md` and only
the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`.

## Identity

- EA ID: `QM5_41190`
- slug: `xtixng-mtheilsen-rv`
- strategy ID: `VILLAR-MOP-XTIXNG-MTHEILSEN-RV-2026_S01`
- source ID: `VILLAR-MOP-XTIXNG-MTHEILSEN-RV-2026`
- host / slot 0: `XTIUSD.DWX`, D1
- companion / slot 1: `XNGUSD.DWX`, D1
- logical symbol: `QM5_41190_XTI_XNG_MTHEILSEN_RV_D1`

The atomic allocator reserved row `41190` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded source packet is
`strategy-seeds/sources/VILLAR-MOP-XTIXNG-MTHEILSEN-RV-2026/source.md`,
SHA-256
`FE2AC3C27EB5445000635AE9EB7A136293C4035A7A169EE36F1C471DB4F139B4`.
Its durable approval is
`decisions/2026-08-28_xtixng_monthly_theilsen_reversion_source_approval.md`.

R1 is `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`. Complete U.S. EIA
and peer-reviewed oil/gas evidence supports a weak, state-dependent physical
and economic relation while explicitly documenting instability and large
unexplained gas variation. Complete peer-reviewed WTI trend evidence and its
governed child packet supply exact thirteen-endpoint Theil-Sen arithmetic.
No source tests the exact oil/gas ratio fade, Darwinex continuous CFDs,
equal-notional package, or QM book. No source performance, coefficient,
significance, neutrality, or correlation result transfers.

## Mechanical Decision

R2 is `PASS`. On the first eligible tick of a new broker month, the card:

1. consumes the month before every fallible gate;
2. selects the latest exactly timestamp-matched XTI/XNG D1 close pair from
   each of the thirteen immediately prior consecutive completed months;
3. forms chronological oil-minus-gas log ratios;
4. enumerates all 78 forward pairwise slopes with exact month-index
   denominators;
5. sorts without rounding and averages zero-based indexes 38 and 39;
6. fades the strict sign with opposite XTI/XNG legs, consuming exact zero
   flat; and
7. closes at the next month, after forty days, or immediately on malformed
   package state.

One aggregate `RISK_FIXED=1000` budget is split across two frozen
`3.5*ATR(20,D1)` hard stops. Equal target absolute notionals, a 20% realized
mismatch ceiling, XTI-first/XNG-second submission, and immediate rollback
bound legging risk. Both news axes, legacy news mode, and Friday close are
OFF. No parameter sweep or result-dependent rescue is authorized.

## Data And Determinism

R3 is `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
`XTIUSD.DWX` and `XNGUSD.DWX` D1 histories, quotes, contract metadata, ATR,
positions, deals, and terminal-persistent attempt state provide every runtime
field. Q02 must prove synchronized warm-up, density, fills, and economics.

R4 is `PASS`. The signal uses only timestamps, logarithms, finite pairwise
arithmetic, sorting, comparisons, and native execution state. There is no
trained output, prohibited signal indicator, external runtime feed, grid,
martingale, scale-in, pyramid, or adaptive PnL fit.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xtixng_mtheilsen_rv_preallocation_dedup_20260828.json`,
SHA-256
`FDAC2C5D78722C1C891F1638F7716D84781225B81630210B47362470E3C612D2`,
found no exact identity across 4,689 registry rows, 1,340 cards, and all 45
Strategy Wiki nodes. Its only fuzzy result was the expected precious-metal
family sibling `QM5_41157_xauxag-mtheilsen-rv` (two card copies at score
0.84), which requires and received manual review.

Manual review establishes functional non-equivalence:

- `QM5_41157` owns XAU/XAG precious-metal legs under a gold/silver source
  thesis; this card owns XTI/XNG energy legs under a weak oil/gas-linkage
  thesis. The carrier, costs, contracts, and economic exposure are load
  bearing.
- `QM5_20271_wti-theilsen-tr` follows one outright WTI slope with one leg;
  this card fades one synchronized oil/gas ratio slope with two opposite legs.
- `QM5_41188_xtixng-mrepmedian-rv` takes pivot-specific slope medians and an
  outer median. On governed vector
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, exact Theil-Sen is
  positive (`0.001555...`) while repeated median is negative (`-0.0045`), so
  the locked fade rules request opposite packages.
- `QM5_41189_xtixng-mlad-rv` profiles residual-median intercepts and minimizes
  total absolute vertical loss. On governed vector
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, exact Theil-Sen
  is positive (`0.003030...`) while LAD is negative (`-0.002`).
- XTI/XNG Pettitt, Mann-Whitney, Cox-Stuart, Spearman, and median-runs cards
  use different change-point, ordinal, sign, rank, and transition states;
- `QM5_20237_xtixng-ecm-rv` uses daily rolling OLS residuals, a z-score, and a
  convergence exit; `QM5_12578_eia-oilgas-ratio` standardizes a fixed ratio;
  and
- certified `QM5_12567` is a short-horizon long-only XNG oscillator pullback.

The estimator, paired energy carrier, synchronization, and lifecycle are all
load bearing. Verdict:
`CLEAN_XTIXNG_MONTHLY_THEILSEN_RATIO_SLOPE_REVERSION_AFTER_EXPECTED_FAMILY_FUZZY_REVIEW`.

## Portfolio Intent And Falsification

The opposite equal-target-notional energy legs are market-neutral-style and
reduce common outright energy direction. They add XTI exposure missing from
the certified directional XAU/SP500/NDX/XNG book. They do not prove dollar,
beta, volatility, factor, market, or portfolio neutrality. Only unchanged
Q09 evidence may decide realized overlap.

Q02 retires the card on zero trades, fewer than five completed packages in
any full post-warm-up year, nonpositive governed economics, or any defect in
month selection, synchronization, ratio orientation, pair enumeration,
denominators, sort, median indexes, side, attempt, aggregate risk, atomicity,
hard stops, lifecycle, or determinism. No direction, horizon, estimator,
carrier, risk, stop, hold, spread cap, or gate may change after results to
rescue the lineage.

## Authorized Scope

This approval permits only:

- deterministic magic allocation for slots 0 and 1;
- one branch-only V5 EA build;
- exact D1 `RISK_FIXED` backtest setfiles for both registered legs and the
  logical basket;
- strict compile and Q01 validation; and
- one paced logical-basket Q02 enqueue if the active factory remains below
  its CPU ceiling.

It does not permit a manual backtest, terminal control, component-leg Q02,
live/demo/shadow/stress/optimization setfiles, `T_Live`, AutoTrading, deploy
or live manifests, portfolio-gate mutation, portfolio admission, or a
correlation waiver.
