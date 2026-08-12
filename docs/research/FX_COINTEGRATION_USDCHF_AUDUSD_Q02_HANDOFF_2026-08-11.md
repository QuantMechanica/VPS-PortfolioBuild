# QM5_1156 USDCHF/AUDUSD FX cointegration Q02 handoff

Date: 2026-08-11

Branch: `agents/board-advisor`

Status: Q01 PASS; one exact logical-basket Q02 work item PENDING

## Outcome

The frozen sign-aware 66-pair scan is fully mechanized, so creating a new
Card or EA would duplicate existing work. Rank 65, `USDCHF.DWX` /
`AUDUSD.DWX`, already exists as pair slot 12 in the OWNER-approved and built
`QM5_1156_caldeira-cointegration-pairs-fx` EA. This handoff advances that
existing FX card through the funnel by giving slot 12 its own logical basket
identity and exact Q02 row.

Q02 task `54d69913-4c50-498a-9f79-79d9d3163377` created exactly one work
item, `415cd6d3-560c-46d8-a9f9-ee4a5b399100`, for logical symbol
`QM5_1156_USDCHF_AUDUSD_COINTEGRATION_M30`. It was pending, unclaimed, and at
attempt zero when verified. No physical-symbol row was created or skipped,
and no dispatch tick was run.

## Anchor and frontier triage

- `QM5_12532` has logical Q02 PASS and Q04 PASS followed by Q05 FAIL.
- `QM5_12533` has logical Q02 PASS followed by Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.
- The repository is already mechanized through all 66 frozen relationships.
  Rank 65 is this explicit QM5_1156 slot; rank 66 is the terminally evaluated
  `QM5_12803` basket.

The frozen rank-65 scan evidence is adverse: DEV net Sharpe `-0.21`, OOS net
Sharpe `-0.66`, OOS return `-5.70%`, and 16 OOS state changes. Q02 is therefore
a one-shot cadence/economics gate. A frequency or economic failure retires
the pair; it does not authorize refitting, extra filters, or rescue tuning.

## Source and implementation boundary

The strategy is the existing OWNER-approved Caldeira and Moura (2013)
cointegration-pairs Card, backed by SSRN 2196391 and its peer-reviewed journal
publication. The pre-existing approved farm artifact was schema-normalized
into the canonical repository Card without changing approval or mechanics.
The paper supports the structural method, not profitability for this pair.

- Pair slot: 12 (`USDCHF.DWX` / `AUDUSD.DWX`).
- Host and execution period: `USDCHF.DWX`, M30.
- Signal period: completed D1 bars with weekly 60-bar OLS/residual refresh.
- Entry/exit: fixed residual z-score thresholds, divergence stop, and 30-D1
  time stop.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Forbidden mechanics: no ML, grid, martingale, averaging down, or PnL-adaptive
  parameters.

The retired slot-00 EURUSD/GBPUSD logical manifest is preserved verbatim at
`framework/EAs/QM5_1156_caldeira-cointegration-pairs-fx/docs/basket_manifest_slot00_q02_snapshot.json`.
It previously reached Q02 PASS and Q04 FAIL and was not requeued.

## Q01 evidence

- Strict compile: PASS, zero errors and zero warnings.
- Compile summary: `D:\QM\reports\compile\20260811_180754\summary.csv`.
- MQ5 SHA-256:
  `c717d4aeb91994c8f59c89938e133defd7757b97fe196d4de0927121cb96d509`.
- EX5 SHA-256:
  `b49906e0d11679c2c3522b1d95c7759d5fb59dda5c36bb77e27a71e1a2b2d2f6`.
- Logical setfile SHA-256:
  `246ba49e1721cdcc99c38dbb8681bb6fd4dc6a57ddd604b57226e16c41c48c1a`.
- Strategy Card schema lint: PASS on canonical and EA-local copies; their
  SHA-256 values match.
- Basket manifest and sweep enqueue regressions: 48 passed.
- Target-only sweep dry run: zero selected, confirming the generic
  never-tested sweeper would not infer a duplicate repair from older QM5_1156
  history. The supported exact review-task path was used instead.
- Manual smoke or backtest run: none.

## Q02 enqueue and fleet safety

The immediate pre-enqueue sample at `2026-08-11T18:14:38Z` found two factory
terminals running, `T7` and `T8`, below the binding seven-terminal CPU
ceiling. `T_Live` and FTMO processes were observed only to exclude them from
the factory count and were not controlled. The Q02 row was created ten
seconds later at `2026-08-11T18:14:48Z`.

No terminal was reserved, launched, stopped, or dispatched. No tester was
run. AutoTrading, the T_Live manifest, all portfolio admission/KPI/Q08
contribution paths, registries, and live artifacts were untouched. Existing
unrelated dirty-worktree files were left unchanged.

Machine-readable evidence is in
`artifacts/fx_cointegration_usdchf_audusd_q02_handoff_20260811T181448Z_board_advisor.json`.
