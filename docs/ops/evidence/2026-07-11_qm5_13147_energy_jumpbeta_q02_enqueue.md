# QM5_13147 Energy Jump-Beta - Q02 Enqueue Evidence

**Date:** 2026-07-11

**Branch:** agents/board-advisor

**EA:** QM5_13147_energy-jumpbeta

**Status:** Q01 PASS; one logical Q02 basket pending

## Edge And Evidence Boundary

The new edge is the aggregate-jump-sensitivity anomaly documented by
Hollstein, Prokopczuk, and Tharann, "Anomalies in Commodity Futures Markets,"
*Quarterly Journal of Finance* 11(4), article 2150017. The complete accepted
manuscript and appendix were reviewed. Its monthly commodity sorts find a
negative high-minus-low aggregate-jump-beta spread, fixing the economic
direction as low incremental jump beta long and high jump beta short.

Primary source DOI:
https://doi.org/10.1142/S2010139221500178

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

Commodity-jump context:
https://doi.org/10.1016/j.jcomm.2018.10.002

The paper uses a broad futures cross-section and an option-derived aggregate
equity jump factor. Darwinex runtime supplies neither commodity options nor
that factor, so QM5_13147 is an explicit price-only falsification: it estimates
incremental exposure to synchronized extreme innovations in an inverse-vol
XTI/XNG energy benchmark. No source return, significance, drawdown, cost, or
correlation number is imported as an EA result.

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month t:

1. Load 253 synchronized completed D1 closes for XTIUSD.DWX and XNGUSD.DWX,
   producing 252 simple returns per leg.
2. Estimate each leg's sample volatility and form an inverse-volatility
   weighted energy benchmark.
3. Demean that benchmark. Define the realized jump factor as its innovation
   on observations whose absolute value is at least two sample standard
   deviations; set it to zero otherwise. Require at least six jump days.
4. For each leg solve deterministic OLS
   `r_i = alpha + beta_energy * energy + beta_jump * jump + error`.
5. Buy the lower `beta_jump` leg and short the higher `beta_jump` leg. Reject
   ties, stale/misaligned histories, singular systems, non-finite values,
   invalid spreads/ATRs/lots, or invalid package state.
6. Allocate one `RISK_FIXED=1000` package as equal fixed-risk halves with
   independent frozen ATR(20) times 3.5 hard stops. Close at the next broker
   month, after 40 days, or on orphan/invalid composition; prohibit same-month
   re-entry.

Expected density is approximately twelve packages/year after warm-up. Q02
owns the first economic evidence.

## Non-Duplicate Decision

The canonical pre-allocation check returned CLEAN across 4,033 registry rows
and 335 cards. Manual resolution separated this mechanic from:

- QM5_13132 total energy beta/BAB: total benchmark exposure, not incremental
  extreme-innovation beta after controlling continuous energy return.
- QM5_13129 semivariance and other skew/MAX/kurtosis/ES tail ranks: marginal
  distribution statistics, not common-jump-factor sensitivity.
- Existing XTI/XNG ratio, trend, carry, and calendar builds.
- QM5_12567: a two-day long-only XNG RSI pullback.

Verdict: `CLEAN_PRE_ALLOCATION; POST_ALLOCATION_EXACT_MATCH_IS_SELF`.

## Identity And Registry Evidence

- EA reservation:
  `13147,energy-jumpbeta,HOLLSTEIN-AGGJUMP-2021_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131470000`.
- Magic slot 1: XNGUSD.DWX to `131470001`.
- The isolated clean resolver contains both values and retains 14,886 rows.
- Clean magic-registry SHA256:
  `2B06021FE7641B650AC07AA29B38E487CA7F5D6BE0AD059C7BA33733C8852658`.
- Resolver SHA256:
  `84750359F4FDC6463757FB333F342BBC237A6044E0B08B39935C3758E312F8F1`.

The canonical resolver generator excluded four pre-existing rows whose EA
directories are absent in the clean base (1001, 1015, 1016, and 13122).
Unrelated dirty fleet allocations were excluded from build commit
`30ffcf860c06741d78a4314f91237f6407ca17b8`.

## Q01 Build Evidence

- Build commit: `30ffcf860c06741d78a4314f91237f6407ca17b8`.
- Final strict clean-resolver compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `D:/QM/reports/compile/20260711_195132/QM5_13147_energy-jumpbeta.compile.log`.
- Build check: PASS, 0 failures. Its one static performance advisory asked for
  an explicit `perf-allowed` marker on the single monthly-path `CopyRates`;
  that marker was corrected before the final strict compile.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_195053.json`.
- Card schema/G0, SPEC, build guardrails, and basket symbol scope: PASS.
- Symbol-scope verdict: `BASKET_OK` for XTIUSD.DWX and XNGUSD.DWX.
- MQ5 SHA256:
  `9BE47992127C375E63A60CBCE842A967AA0B14404067E83A64C9FA42308B4192`.
- EX5 SHA256:
  `80B8ACA54026535D6537352A3E804D4C211F8B7844BB8249B1964EC7A54DDEDB`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13147_XTI_XNG_JBETA_D1`; host XTIUSD.DWX, D1.
- Setfile:
  `framework/EAs/QM5_13147_energy-jumpbeta/sets/QM5_13147_energy-jumpbeta_QM5_13147_XTI_XNG_JBETA_D1_D1_backtest.set`.
- Setfile SHA256:
  `ABB3416844FB204E9A761BCCBF43C438DDBB10FAE9BDD0B7B1158AE595D53626`.
- Setfile build hash:
  `27ff6b9479a9c04b6c7d0ce61d4b27bc557fef77ddf9453f303e7dd978be3944`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: `6bafc767-d3f9-44d0-97db-e27e2bc33fc0`, done.
- Work item: `23ffc0f5-d6bf-4c4d-a9d9-c671bfeb56f9`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13147_XTI_XNG_JBETA_D1`.
- Host/timeframe: XTIUSD.DWX / D1.
- Basket payload: XTIUSD.DWX and XNGUSD.DWX,
  `portfolio_scope=basket`, `risk_mode=RISK_FIXED`.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-11T19:55:47+00:00`.
- `farmctl record-build` enqueued one item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started by this work. No backtest CPU slot was consumed, so no CPU ceiling was
encountered; Q02 owns the first CPU-bearing validation pass.

## Safety And Kill Boundary

- Structural D1/monthly price arithmetic only; no ML or banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- The source-to-proxy substitution, endogenous two-name factor, D1 jump
  approximation, continuous-CFD basis, XNG gaps, legging, and costs are kill
  risks, never waiver grounds.
- Opposite directions and equal fixed-risk halves reduce common direction but
  do not establish dollar, beta, volatility, factor, or realized market
  neutrality. Portfolio certification and realized book orthogonality remain
  unclaimed until later gates measure them.
