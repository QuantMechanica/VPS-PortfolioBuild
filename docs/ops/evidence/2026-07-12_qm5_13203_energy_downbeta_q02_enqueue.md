# QM5_13203 Energy Downside Beta - Q02 Enqueue Evidence

**Date:** 2026-07-12

**Branch:** agents/board-advisor

**EA:** QM5_13203_energy-downbeta

**Status:** Q01 PASS; one logical XTI/XNG Q02 item pending

## Edge And Evidence Boundary

The structural edge is the downside-beta characteristic in Hollstein,
Prokopczuk, and Tharann (2021), "Anomalies in Commodity Futures Markets,"
*Quarterly Journal of Finance* 11(4), article 2150017.

DOI and journal record:
https://doi.org/10.1142/S2010139221500178

Complete institutional accepted manuscript and online appendix:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

The complete 57-page document was reviewed. The source explicitly includes
WTI and natural gas, estimates commodity characteristics from the prior twelve
months of daily observations, and renews its sorts monthly. Its baseline
downside-beta high-minus-low return is -1.37% annualized and insignificant;
portfolio-count variants remain insignificant, the Fama-MacBeth slope is
null, and source subperiod signs are unstable. The paper therefore supplies a
reputable mechanical definition but an adverse performance prior.

QM5_13203 locks the observed sign as low-minus-high and treats Q02 as a strict
falsification. No source return, significance, drawdown, cost, correlation, or
diversification statistic is imported as QM evidence.

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month `t`:

1. Load 253 synchronized completed XTI, XNG, and read-only SP500 closes and
   form exactly 252 simple returns; current bars are excluded.
2. Compute the arithmetic mean of all 252 SP500 returns and retain only daily
   observations whose SP500 return is strictly below that mean.
3. Require at least 100 retained observations. Estimate each energy leg's
   contemporaneous SP500 slope by OLS with an intercept on the identical
   retained sample; reject nonpositive factor variance or a beta tie within
   `1e-8`.
4. Buy the lower-downside-beta energy leg and short the higher-beta leg.
   SP500.DWX remains factor data only and has no magic, order, close, sizing,
   or package-PnL path.
5. Split `RISK_FIXED=1000` equally between XTI and XNG and attach frozen
   `ATR(20) * 3.5` hard stops. A failed second order flattens the first.
6. Close at the next broker-month transition, after 40 calendar days, or on
   orphan/invalid composition. Position and entry-deal history prevent
   same-month re-entry after a restart or stopped leg.

Expected density is approximately twelve completed packages/year after
warm-up. The binding Q02 floor is five packages/year.

## Non-Duplicate Decision

- `QM5_13132_energy-bab` estimates unconditional lag-augmented Dimson beta to
  an endogenous energy benchmark, shrinks beta toward one, and inverse-beta
  sizes. QM5_13203 uses an unlagged conditional SP500 sample, no shrinkage,
  and equal fixed-risk halves.
- `QM5_13147_energy-jumpbeta` estimates incremental common-energy jump
  sensitivity. `QM5_13151_energy-volbeta` estimates sensitivity to smooth
  common-energy volatility changes. Neither uses a below-average external
  equity-factor observation mask.
- `QM5_13133_energy-ivol` ranks residual dispersion. Ratio, carry, trend,
  calendar, return-sign momentum, and incumbent XNG RSI builds use different
  mechanics and hypotheses.

Exact repository text search plus manual input/window/factor/direction review
found no commodity downside-beta implementation. Verdict:
`CLEAN_PRE_ALLOCATION`.

## Identity And Registry Evidence

- EA reservation:
  `13203,energy-downbeta,HOLLSTEIN-DOWNBETA-2021_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `132030000`.
- Magic slot 1: XNGUSD.DWX to `132030001`.
- The committed resolver contains both mappings and retains 14,895 rows.
- Committed LF magic-registry SHA256:
  `D084F7421F6CB0AC7BED49CFA377CE0C495FBF5CBAA0B11E1A6B252C525A96FF`.
- Committed resolver SHA256:
  `5140622CB30A8844CE0E1285463A8FBD8A3753133949163C44AFAB2B7DE58F9A`.

The shared canonical worktree contained unrelated fleet allocations before
this build. The feature commit was assembled from clean HEAD registry blobs
plus only EA 13203 in a `core.autocrlf=false` isolated checkout. The embedded
resolver digest matches the committed LF registry; the generator's same four
pre-existing missing-directory rows remained excluded.

## Q01 Build Evidence

- Build commit:
  `84a39712c2f9c8146371743e14643ecd0737ff85`.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Preserved compile log:
  `D:/QM/reports/compile/20260712_073757/QM5_13203_energy-downbeta.compile.log`.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260712_073757.json`.
- Card schema/G0 frontmatter, SPEC, build guardrails, and basket-manifest
  symbol scope: PASS.
- MQ5 SHA256:
  `E3F62318710DC0A821FC50BAA75C31DB7F55CA4C3508385CF91F148BA059D7BC`.
- Committed EX5 SHA256:
  `AE4C28D49BAB75FD83E63351745FC6E19EB461B738E127A54329D74328EA0C78`.

No compile or resolver claim depends on unrelated working changes.

## Risk And Setfile Evidence

- Logical symbol/timeframe: QM5_13203_XTI_XNG_DOWNBETA_D1 / D1.
- Runner host: XTIUSD.DWX / D1; traded legs: XTIUSD.DWX and XNGUSD.DWX;
  read-only factor: SP500.DWX.
- Setfile:
  `framework/EAs/QM5_13203_energy-downbeta/sets/QM5_13203_energy-downbeta_QM5_13203_XTI_XNG_DOWNBETA_D1_D1_backtest.set`.
- Setfile SHA256:
  `13F746837B07B7EFC1FB057A41965DD34BBF50F9FE2CBFD9DADC036C536B4D9F`.
- Setfile build hash:
  `d64705baf78b793ea7c91cedea69cfdaafc8e148a1a460a1cafa20fa515a98ec`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the declared monthly holding period.

## Q02 Queue Evidence

- Build task: `157f04fa-d348-4e26-a4e3-73b1d0ceee5c`, done.
- Work item: `503e2088-87a8-4663-8cec-a105bae90bfb`.
- Phase/kind: Q02 / backtest.
- Logical symbol/timeframe: QM5_13203_XTI_XNG_DOWNBETA_D1 / D1.
- Host symbol/timeframe: XTIUSD.DWX / D1.
- Basket symbols: XTIUSD.DWX, XNGUSD.DWX, and read-only SP500.DWX.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-12T07:47:08+00:00`.
- `farmctl record-build` enqueued one logical basket item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started. No backtest CPU slot was consumed, so the backtest CPU ceiling was not
encountered; Q02 owns the first CPU-bearing validation pass.

## Safety And Kill Boundary

- Structural D1/monthly return arithmetic plus ATR safety stops only; no ML or
  banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- Null source evidence, excess-return proxies, two-name narrowing,
  continuous-CFD basis, factor-history overlap, XNG gaps, legging, financing,
  and costs are kill risks, never waiver grounds.
- Opposite-side energy exposure and distinct conditional logic make
  diversification plausible; certification and realized book orthogonality
  remain unclaimed until later gates measure them.
