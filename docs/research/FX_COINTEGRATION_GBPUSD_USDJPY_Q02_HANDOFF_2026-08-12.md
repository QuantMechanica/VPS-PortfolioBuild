# QM5_1257 GBPUSD/USDJPY FX cointegration Q02 handoff

Date: 2026-08-12

Branch: `agents/board-advisor`

Status: Q01 PASS; one exact logical-basket Q02 work item PENDING

## Outcome

The frozen sign-aware 66-pair scan is already fully mechanized, so a new Card
or EA would duplicate existing work. Following the existing-card fallback,
rank 58, `GBPUSD.DWX` / `USDJPY.DWX`, was advanced as pair slot 8 in the
OWNER-approved and built `QM5_1257_lemishko-fx-cointpair` EA. The slot now has
its own active logical basket manifest, fixed-risk setfile, and exact Q02 row.

Q02 task `39ee6910-5d04-4087-83b0-65a6fd6b22f9` created exactly one work
item, `d4cd660c-c81a-41d3-8a4c-ad21d3319816`, for logical symbol
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`. It was pending, unclaimed, and at
attempt zero when verified. No physical-symbol row was created or skipped,
and no dispatch tick was run.

## Anchor and frontier triage

- `QM5_12532` has logical Q02 PASS and Q04 PASS followed by Q05 FAIL.
- `QM5_12533` has logical Q02 PASS followed by Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.
- A relationship-level audit found all 66 frozen scan pairs already present
  in dedicated baskets or the `QM5_1156` / `QM5_1257` umbrellas. This pair is
  slot 8 in `QM5_1257`; it had no pair-specific logical Q02 identity.

The frozen rank-58 scan evidence is adverse: DEV net Sharpe
`-0.103537893720`, OOS net Sharpe `-0.419922430787`, OOS return
`-3.600289808739%`, 16 OOS state changes, DEV beta `-0.388288093234`, and
half-life `76.715376014881` D1 bars. Q02 is therefore a one-shot
cadence/economics gate. A zero-trade, cadence, or economic failure retires the
binding; it does not authorize refitting, extra filters, or rescue tuning.

## Source and implementation boundary

The existing Card cites Lemishko, Landi, and Caicedo-Llano (2024),
“Cointegration-Based Strategies in Forex Pairs Trading,” SSRN 4771108. Its
durable farm copy is OWNER-approved with G0 R1-R4 PASS. The source supports the
structural Engle-Granger/OLS residual-reversion method, not profitability for
this pair. The local approved Card was schema-normalized without changing its
approval or trading mechanics.

- Pair slot: 8 (`GBPUSD.DWX` / `USDJPY.DWX`).
- Host and execution period: `GBPUSD.DWX`, H1.
- Signal periods: completed D1 formation bars and completed H1 z-score bars.
- Entry/exit: frozen monthly OLS hedge ratio, fixed residual z-score
  thresholds, structural/combined-risk stops, and a 10-day time stop.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Forbidden mechanics: no ML, grid, martingale, averaging down, or
  PnL-adaptive parameters.

The completed slot-12 AUDUSD/USDJPY logical manifest is preserved verbatim at
`framework/EAs/QM5_1257_lemishko-fx-cointpair/docs/basket_manifest_slot12_q02_snapshot.json`.
Its prior logical Q02 verdict remains terminal FAIL and was not requeued.

## Q01 evidence

- Strict compile: PASS, zero errors and zero warnings.
- Compile summary: `D:\QM\reports\compile\20260811_234320\summary.csv`.
- Strict build check: PASS with no failures or warnings; report
  `D:\QM\reports\framework\21\build_check_20260811_234424.json`.
- MQ5 SHA-256:
  `28bd88d0a7a7401ec7fe3b3a4f99ef3ba6b9fec146298c512b1c76e1adf7e12b`.
- EX5 SHA-256:
  `86c6e9f077e37ddd5aea1e15b253cd4509c7f180c846cc6aebd806fa17d95cbd`.
- Logical setfile SHA-256:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`.
- Strategy Card schema lint: PASS with no missing sections or ML hits.
- Basket manifest and enqueue regressions: 63 passed.
- Target-only generic sweep dry run selected zero rows, confirming that the
  never-tested sweeper would not infer this new logical identity from old
  umbrella history. The supported approved-review-task path was used instead.
- Manual smoke or backtest run: none.

## Q02 enqueue and fleet safety

The immediate pre-enqueue sample at `2026-08-11T23:53:33Z` found three
factory terminals running, `T7`, `T8`, and `T10`, below the binding
seven-terminal CPU ceiling. `T_Live` and FTMO processes were observed only to
exclude them from the factory count and were not controlled. The Q02 row was
created 17 seconds later at `2026-08-11T23:53:50Z`.

No terminal was reserved, launched, stopped, or dispatched. No tester was
run. AutoTrading, the T_Live manifest, all portfolio admission/KPI/Q08
contribution paths, registries, and live artifacts were untouched. Existing
unrelated dirty-worktree files were left unchanged.

Machine-readable evidence is in
`artifacts/fx_cointegration_gbpusd_usdjpy_q02_handoff_20260811T235350Z_board_advisor.json`.
