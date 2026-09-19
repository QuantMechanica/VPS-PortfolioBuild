# QM5_41483 WTI Eleven-Month Momentum Build And Q02 Enqueue

Date: 2026-09-19

Branch: `agents/board-advisor`

Outcome: `COMPILE_OK_Q02_ENQUEUED`

## Edge and non-duplicate boundary

`QM5_41483_wti-tsmom11-h1` adds a structural oil sleeve on
`XTIUSD.DWX`, distinct from the certified index/metal/XNG book. On the first
D1 bar of each broker month it follows the sign of the exact eleven-completed-
month WTI log return, holds one package for one month, and protects it with a
frozen `3.5*ATR(20,D1)` stop.

The Tier-A source is Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete-read parent and bounded WTI
extraction are recorded in the source packet and OWNER source-approval
decision. Canonical dedup found no exact identity; manual family review
distinguished this every-month `k=11,h=1` contract from `QM5_41390`'s
two-month lifecycle, `QM5_41391`'s ten-month formation, `QM5_12603`'s 252-D1
proxy, and `QM5_20284`'s skipped-month formation.

## Build and PACER guard

- EA ID / magic: `41483` / `414830000` (slot 0).
- Approved card: `strategy-seeds/cards/approved/QM5_41483_wti-tsmom11-h1_card.md`.
- EA source: `framework/EAs/QM5_41483_wti-tsmom11-h1/QM5_41483_wti-tsmom11-h1.mq5`.
- The binding framework-input-pin audit ran after source generation and before
  compile enqueue: `ok=true`, `EA_FRAMEWORK_INPUT_PINNED` findings `0`.
- Reference vectors: PASS.
- COMPILE_EA item: `2969169d-f11b-4b69-aaf3-dc37d3f5ba02`.
- Compile verdict: `COMPILE_OK`; compiler errors `0`, warnings `0`; build check
  PASS.
- MQ5 SHA-256: `29c1d6a18d8117d22a7bb587d5ae95b7dae604e0b55a0307c2f5f5082697cd04`.
- EX5 SHA-256: `3d67a36290dc708118925e718d197b46fce2697463a57cafad81f72e40117809`.
- Final Q02-bound setfile SHA-256:
  `e332bef808157ddfa9c042889d8781295b907b866943c4a78ef1a8f904e600fd`.
- The sole backtest set uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The compile activation hold was released only for the exact work item after a
source-hash-matching dry run. Its protected database backup initially exceeded
the default 60-second timeout; the same one-row operation succeeded with a
300-second backup allowance, without relaxing selection or hash controls.

## Capacity and smoke boundary

The pre-smoke five-sample whole-host CPU window was `42.373250`, `32.345932`,
`45.707007`, `25.809531`, and `34.482219` percent (average `36.143588`, maximum
`45.707007`). Both were strictly below the binding 97% ceiling.

One canonical `run_smoke.ps1 -Terminal any -SmokeMode -MinTrades 1` attempt
was made with the EX5 hash bound. Terminal resolution returned `no_capacity`
before launch, so there is no smoke tester run or strategy outcome to report.

## Q02 handoff

The read-only `intake-first-q02` plan returned `eligible=true` after binding
the done/COMPILE_OK evidence, current EX5, fixed-risk setfile, and exact active
magic row. Immediately before apply, the five CPU samples were `40.558481`,
`47.074774`, `40.154033`, `39.669441`, and `46.293512` percent (average
`42.750048`, maximum `47.074774`), again strictly below 97%.

- Q02 work item: `134fa3fc-5ad3-4437-b69b-89a0c21df0a4`.
- Tuple: `QM5_41483 × XTIUSD.DWX × D1 × Q02`.
- Intake receipt SHA-256:
  `4a2e4a8338c32ac1ecba5a42e5eec947079d58d297671e5c1e20e4b4ade1bea5`.
- State when verified: `active`, normally claimed by factory terminal `T5`,
  attempt count `0`, no verdict yet.

This unit does not claim profitability, certification, or realized portfolio
decorrelation. It did not access `T_Live`, change AutoTrading, edit the
portfolio gate, edit the live manifest, optimize parameters, or issue any live
authorization.
