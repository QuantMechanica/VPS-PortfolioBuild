# QM5_13149 Energy Trend36 - Q02 Enqueue Evidence

**Date:** 2026-07-12

**Branch:** agents/board-advisor

**EA:** QM5_13149_energy-trend36

**Status:** Q01 PASS; one logical Q02 basket pending

## Edge And Evidence Boundary

The new edge is the source-labelled `3Y Reversal` characteristic in Fabian
Hollstein, Marcel Prokopczuk, and Bjoern Tharann, *Anomalies in Commodity
Futures Markets*, *Quarterly Journal of Finance* 11(4), article 2150017. The
complete 57-page accepted manuscript and online appendix were reviewed.

DOI and journal record:
https://doi.org/10.1142/S2010139221500178

Complete institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

The source defines the characteristic as average commodity-futures excess
return over the prior 36 months, forms portfolios at month end, and trades
high minus low. Despite the source label, the tested direction is continuation,
so this implementation is named 36-month relative trend and does not reverse
the sign to fit the label.

The evidence prior is deliberately low. The source's three-portfolio
high-minus-low annual mean is 2.36% and only weakly significant. Its
two-portfolio result, the closest source carrier to this two-leg package, is
1.23% and insignificant; the cross-sectional slope is also insignificant, and
subperiod evidence is unstable. No source alpha, significance, cost result,
drawdown, or correlation is imported as evidence for this EA. Q02 owns the
first economic evidence for the CFD translation.

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month `t`:

1. Reconstruct the last completed D1 close in each of the 37 consecutive
   completed broker months ending at `t-1`, independently for XTI and XNG.
2. For each leg, calculate exactly 36 simple monthly returns and their
   arithmetic average.
3. Buy the higher-average-return leg and short the lower-average-return leg.
   Reject an absolute difference at or below `1e-10`, missing month, invalid
   close, nonfinite arithmetic, excessive spread, or invalid ATR/lot state.
4. Allocate one `RISK_FIXED=1000` package as equal fixed-risk halves with
   independent frozen ATR(20) times 3.5 hard stops.
5. Close both legs at the next broker month or after 40 days. Flatten an
   orphan or invalid composition immediately and prohibit same-month re-entry
   through position and deal-history checks.

Expected density is approximately twelve completed packages/year after the
37-month warm-up. The binding Q02 floor is five packages/year.

## Non-Duplicate Decision

The canonical pre-allocation checker found no exact registry, strategy-ID, or
card duplicate. It returned three same-source fuzzy candidates:

- `energy-kurt-rank` uses rolling return kurtosis, not average return.
- `energy-vov` uses variance of variance, not a 36-month directional mean.
- `xti-xng-lowmax` ranks a prior-maximum characteristic, not monthly returns.

Manual input, formula, direction, and window review also separated the rule
from 12-month commodity momentum, conditional momentum/reversal disagreement,
54-66-month value, immutable-origin normalized price rank, one-year
contrarian baskets, rolling spread z-scores, calendar trades, and
QM5_12567's two-day long-only XNG RSI pullback. Verdict:
`FUZZY_SAME_SOURCE_MANUALLY_RESOLVED_DISTINCT`.

## Identity And Registry Evidence

- EA reservation:
  `13149,energy-trend36,HOLLSTEIN-3YR-2021_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131490000`.
- Magic slot 1: XNGUSD.DWX to `131490001`.
- The committed resolver contains both mappings and retains 14,890 rows.
- Committed magic-registry SHA256:
  `3D64196E57E5724A04C5676C51138BAFDE2AB90EE92FFDF2DCA2751F08939D2D`.
- Committed resolver SHA256:
  `BD77C811003A16C5EF595658B84AE77D1E90CE8841C25DA11BDB07BB72261B8F`.

The shared worktree contained unrelated fleet allocations before this build.
The commit was therefore assembled from clean HEAD registry blobs plus only
EA 13149's rows. Array lengths, row macro, mapping tails, and registry SHA were
verified from the staged blobs; unrelated working changes were not staged.

## Q01 Build Evidence

- Build commit: `1c0929c588691c3277342e91cef36dc6ecf82ac5`.
- Canonical strict compile: PASS, 0 errors, 0 warnings.
- Canonical build check: PASS, 0 failures, 0 warnings.
- Canonical compile log:
  `C:/QM/repo/framework/build/compile/20260711_224256/QM5_13149_energy-trend36.compile.log`.
- Canonical build report:
  `D:/QM/reports/framework/21/build_check_20260711_224256.json`.
- Detached clean-commit strict recompile: PASS, 0 errors, 0 warnings.
- Detached clean-commit build check: PASS, 0 failures, 0 warnings.
- Preserved clean verification compile log:
  `D:/QM/reports/compile/20260711_225212/QM5_13149_energy-trend36.compile.log`.
- Clean verification build report:
  `D:/QM/reports/framework/21/build_check_20260711_225212.json`.
- Card schema/G0, SPEC, build guardrails, and basket symbol scope: PASS.
- MQ5 SHA256:
  `68200CB592E653D950EECE6C131D2FE73FE920700E2388FA3808D776767A6C64`.
- Committed EX5 SHA256:
  `E74269A668551BAAA43DA2A94D3D906F48FC92E9930825C2CEA2FB3B5D429049`.

The detached verification proves that the committed source and clean resolver
compile together. EX5 hashes are artifact-specific across separate compiler
invocations, so no binary-hash equality claim is made for the recompile.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13149_XTI_XNG_TREND36_D1`; host XTIUSD.DWX, D1.
- Setfile:
  `framework/EAs/QM5_13149_energy-trend36/sets/QM5_13149_energy-trend36_QM5_13149_XTI_XNG_TREND36_D1_D1_backtest.set`.
- Setfile SHA256:
  `DCB6BA08CD8BC7DEF1B1524E63202F769071D8D5E370BDA9FDB71BA052F1F954`.
- Setfile build hash:
  `cb288de42c5ac002ed9b81a165b47346615100881a80cf32c3356814d6e112de`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the declared monthly paired hold.

## Q02 Queue Evidence

- Build task: `525938b6-d501-415b-838c-a7dd3d12d3a5`, done.
- Work item: `be4eb919-5e5a-4b0b-8c88-561a5fcc2b1e`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13149_XTI_XNG_TREND36_D1`.
- Host/timeframe: XTIUSD.DWX / D1.
- Basket payload: XTIUSD.DWX and XNGUSD.DWX,
  `portfolio_scope=basket`, `risk_mode=RISK_FIXED`.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-11T22:49:48+00:00`.
- `farmctl record-build` enqueued one item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started by this work. No backtest CPU slot was consumed, so the backtest CPU
ceiling was not encountered; Q02 owns the first CPU-bearing validation pass.

## Safety And Kill Boundary

- Structural D1/monthly price arithmetic only; no ML or banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- The insignificant narrow source evidence, broad-to-two-name narrowing,
  fixed-maturity-futures-to-continuous-CFD translation, financing, XNG gaps,
  monthly legging, and costs are kill risks, never waiver grounds.
- Opposite directions and equal fixed-risk halves reduce common direction but
  do not establish dollar, beta, volatility, factor, or realized market
  neutrality. Certification and realized book orthogonality remain unclaimed
  until later gates measure them.
