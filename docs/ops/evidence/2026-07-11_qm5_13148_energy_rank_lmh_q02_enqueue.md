# QM5_13148 Energy Rank Low-Minus-High - Q02 Enqueue Evidence

**Date:** 2026-07-11

**Branch:** agents/board-advisor

**EA:** QM5_13148_energy-rank-lmh

**Status:** Q01 PASS; one logical Q02 basket pending

## Edge And Evidence Boundary

The new edge is the commodity rank effect developed by Ricardo T. Fernholz
and Christoffer Koch in *The Rank Effect for Commodities*, Federal Reserve
Bank of Dallas Working Paper 1607. The complete institutional paper and arXiv
manuscript were reviewed. The source normalizes 30 commodity futures,
including crude oil and natural gas, to a common initial value; waits 20
trading days; and buys low normalized-price ranks against high ranks.

Institutional paper:
https://www.dallasfed.org/-/media/documents/research/papers/2016/wp1607.pdf

Complete arXiv manuscript and revision record:
https://arxiv.org/abs/1607.07510

The paper uses broad equal-dollar groups and daily rebalancing. QM5_13148 is a
predeclared low-frequency falsification: it ranks only XTI and XNG from a
locked common Darwinex-history origin and renews monthly. No source return,
alpha, significance, drawdown, cost, turnover, or correlation result is
imported as EA evidence.

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month t:

1. Parse the immutable `2017.01.03` broker-date origin.
2. For each leg, find the first completed D1 close on/after the origin. Require
   it within seven calendar days, require the identical anchor timestamp for
   both legs, and require at least 20 completed post-anchor bars.
3. Use each leg's latest completed close before the decision bar. Require
   identical endpoints and no more than ten calendar days of staleness.
4. Compute `normalized_i = latest_close_i / anchor_close_i` directly.
5. Buy the lower normalized-price leg and short the higher normalized-price
   leg. Reject a tie, invalid/missing anchor, stale/misaligned history,
   non-finite value, invalid spread/ATR/lot, or invalid package state.
6. Allocate one `RISK_FIXED=1000` package as equal fixed-risk halves with
   independent frozen ATR(20) times 3.5 hard stops. Close at the next broker
   month, after 40 days, or on orphan/invalid composition; prohibit same-month
   re-entry.

Expected density is approximately twelve packages/year after warm-up. Q02
owns the first economic evidence.

## Non-Duplicate Decision

The canonical clean-head pre-allocation checker found no exact registry or
card identity duplicate across 4,030 registry rows and 327 cards. It returned
five expected fuzzy matches because their slugs share `energy` and `rank`:

- QM5_13139 coefficient of variation: rolling monthly variance divided by
  absolute mean, not a fixed normalized-price origin.
- QM5_13143 expected shortfall: rolling downside-tail loss, not price rank.
- QM5_13141 information exposure and QM5_13142 salience: different
  characteristic inputs and estimators.
- QM5_13123 value: current price versus a rolling 54-66 month mean, not one
  immutable common origin.

Manual resolution also separated this mechanic from rolling XTI/XNG return-
spread z-scores, Gatev-style rolling normalized-pair distance, momentum,
carry, trend, calendar, beta, and the two-day long-only XNG RSI pullback in
QM5_12567. Verdict:
`FUZZY_ENERGY_RANK_SLUG_FAMILY_MANUALLY_RESOLVED_DISTINCT`.

## Identity And Registry Evidence

- EA reservation:
  `13148,energy-rank-lmh,FERNHOLZ-KOCH-RANK-2016_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131480000`.
- Magic slot 1: XNGUSD.DWX to `131480001`.
- The isolated clean resolver contains both values and retains 14,888 rows.
- Clean magic-registry SHA256:
  `095334EED3A435BAF88F81CCA9269A41052F6531CABFB83A50C74D619E65CCEC`.
- Resolver SHA256:
  `A7F15ACD95260D8260A0D0A6B3D9FBC530B18FADE8FF299E1C5240818A49E321`.

The clean resolver generator excluded four pre-existing rows whose EA
directories are absent in the clean base (1001, 1015, 1016, and 13122).
Unrelated dirty fleet allocations were excluded from build commit
`350bcf688a80d086e215120168d45da0b055656d`.

## Q01 Build Evidence

- Build commit: `350bcf688a80d086e215120168d45da0b055656d`.
- Final strict clean-resolver compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `D:/QM/reports/compile/20260711_213734/QM5_13148_energy-rank-lmh.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_213636.json`.
- Card schema/G0, SPEC, build guardrails, and basket symbol scope: PASS.
- Symbol-scope verdict: `BASKET_OK` for XTIUSD.DWX and XNGUSD.DWX.
- MQ5 SHA256:
  `F5B537AE85887AD3FACF4E8B6E35E262FB67DDF37E8B5417CE4F2A7A58B3193E`.
- EX5 SHA256:
  `62E7F98E430E70D0A83C35AABD92E8CFFBED0B5CCF8B09FB9480C242FEE05707`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13148_XTI_XNG_RANK_LMH_D1`; host XTIUSD.DWX, D1.
- Setfile:
  `framework/EAs/QM5_13148_energy-rank-lmh/sets/QM5_13148_energy-rank-lmh_QM5_13148_XTI_XNG_RANK_LMH_D1_D1_backtest.set`.
- Setfile SHA256:
  `BE2FC9127C1AF0CE67404D345D2389A65C96B9277165407646216D9419DBEED1`.
- Setfile build hash:
  `6759a93a9e8e4570fd2f02a5ce3d96f3a654d2f9bf8b58d144f69bbc7a271514`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the declared monthly paired hold.

## Q02 Queue Evidence

- Build task: `b4396bff-5c04-4810-a974-ede2d6d2a063`, done.
- Work item: `ce2bf983-059f-446f-ac69-f02b4a5f594d`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13148_XTI_XNG_RANK_LMH_D1`.
- Host/timeframe: XTIUSD.DWX / D1.
- Basket payload: XTIUSD.DWX and XNGUSD.DWX,
  `portfolio_scope=basket`, `risk_mode=RISK_FIXED`.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-11T21:40:40+00:00`.
- `farmctl record-build` enqueued one item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started by this work. No backtest CPU slot was consumed, so no CPU ceiling was
encountered; Q02 owns the first CPU-bearing validation pass.

## Safety And Kill Boundary

- Structural D1/monthly price arithmetic only; no ML or banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- The broad-to-two-name narrowing, daily-to-monthly translation, fixed-origin
  dependence, continuous-CFD basis, financing, XNG gaps, legging, and costs
  are kill risks, never waiver grounds.
- Opposite directions and equal fixed-risk halves reduce common direction but
  do not establish dollar, beta, volatility, factor, rank, or realized market
  neutrality. Portfolio certification and realized book orthogonality remain
  unclaimed until later gates measure them.
