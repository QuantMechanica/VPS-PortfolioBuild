# QM5_41189 XTI/XNG Monthly LAD Ratio Reversion — G0 Decision

Date: 2026-08-28

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41189_xtixng-mlad-rv_card.md` and only the
non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`.

## Identity

- EA ID: `QM5_41189`
- slug: `xtixng-mlad-rv`
- strategy ID: `VILLAR-KOENKER-BASSETT-XTIXNG-MLAD-RV-2026_S01`
- source ID: `VILLAR-KOENKER-BASSETT-XTIXNG-MLAD-RV-2026`
- host / slot 0: `XTIUSD.DWX`, D1
- companion / slot 1: `XNGUSD.DWX`, D1
- logical symbol: `QM5_41189_XTI_XNG_MLAD_RV_D1`

The deterministic allocator reserved row `41189` in
`framework/registry/ea_id_registry.csv`; the slug, strategy ID, and card
identity match exactly.

## Source And Claim Boundary

The bounded source packet is
`strategy-seeds/sources/VILLAR-KOENKER-BASSETT-XTIXNG-MLAD-RV-2026/source.md`,
SHA-256
`079DB453FD0BB6B095BC917BE03E1CA236CD4606966BC23D6081216508AA29D6`.
Its durable approval is
`decisions/2026-08-28_xtixng_monthly_lad_reversion_source_approval.md`.

R1 is `PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK`. Complete U.S. EIA
and peer-reviewed oil/gas evidence supports a weak, state-dependent physical
and economic relation while explicitly documenting instability and large
unexplained gas variation. The governed exact LAD packet supplies
Koenker–Bassett median-regression arithmetic. No source tests the exact
thirteen-month oil/gas ratio fade, Darwinex continuous CFDs, equal-notional
package, or the QM book. No source performance, coefficient, significance,
neutrality, or correlation result transfers.

## Mechanical Decision

R2 is `PASS`. On the first eligible tick of a new broker month, the card:

1. consumes the month before every fallible gate;
2. selects the latest exactly timestamp-matched XTI/XNG D1 close pair from
   each of the thirteen immediately prior consecutive completed months;
3. forms chronological oil-minus-gas log ratios;
4. enumerates all 78 forward pairwise slopes;
5. for each slope profiles residual-median intercept index six and sums the
   thirteen absolute vertical residuals in chronological order;
6. retains objectives within the fixed `1e-12` equality guard and takes the
   ordinary median of their slopes;
7. fades the strict sign with opposite XTI/XNG legs, consuming exact zero
   flat; and
8. closes at the next month, after forty days, or immediately on malformed
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

R4 is `PASS`. The signal uses only timestamps, logarithms, finite arithmetic,
sorting, absolute loss, comparisons, and fixed native execution state. There
is no trained output, prohibited signal indicator, external runtime feed,
grid, martingale, scale-in, pyramid, or adaptive PnL fit.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xtixng_mlad_rv_preallocation_dedup_20260828.json`, SHA-256
`22D67A6046EE162D757674CBABB994846CC2173E493CA6B375FEEE8D549683FC`,
returned `CLEAN` across 4,688 registry rows, 1,339 cards, and all 45 Strategy
Wiki nodes.

Manual review establishes functional non-equivalence:

- `QM5_41159_wti-lad-tr` follows an outright WTI LAD slope with one leg;
- `QM5_41160_xauxag-mlad-rv` fades an LAD slope on a precious-metal ratio;
- `QM5_41188_xtixng-mrepmedian-rv` takes pivot-specific slope medians and an
  outer median rather than minimizing an absolute-loss objective;
- `QM5_41157` / `QM5_20271` Theil–Sen systems take a global pairwise-slope
  median without profiling intercepts or losses;
- XTI/XNG Pettitt, Mann–Whitney, Cox–Stuart, Spearman, and median-runs cards
  use different change-point, ordinal, sign, rank, and transition states;
- `QM5_20237_xtixng-ecm-rv` uses daily rolling OLS residuals, a z-score, and a
  convergence exit; and
- `QM5_12578_eia-oilgas-ratio` standardizes a fixed ratio.

On the governed vector
`[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, exact LAD is
`-0.002` while Theil–Sen and repeated median are positive. With the locked
contrarian mapping, they can request opposite packages from identical valid
state. The estimator, paired energy carrier, synchronization, and lifecycle
are all load bearing.

Verdict:
`CLEAN_XTIXNG_MONTHLY_EXACT_LAD_RATIO_SLOPE_REVERSION_BASKET`.

## Portfolio Intent And Falsification

The opposite equal-target-notional energy legs are market-neutral-style and
reduce common outright energy direction. They add XTI exposure missing from
the certified directional XAU/SP500/NDX/XNG book. They do not prove dollar,
beta, volatility, factor, market, or portfolio neutrality. Only unchanged
Q09 evidence may decide realized overlap.

Q02 retires the card on zero trades, fewer than five completed packages in
any full post-warm-up year, nonpositive governed economics, or any defect in
month selection, synchronization, ratio orientation, candidate enumeration,
residual median, loss, minimizer, side, attempt, aggregate risk, atomicity,
hard stops, lifecycle, or determinism. No direction, horizon, estimator,
carrier, risk, stop, hold, spread cap, or gate may change after results to
rescue the lineage.

## Authorized Scope

This approval permits only:

- the deterministic magic allocation for slots 0 and 1;
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
