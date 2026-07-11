# QM5_13146 Energy Volatility-of-Volatility - Q02 Enqueue Evidence

**Date:** 2026-07-11

**Branch:** agents/board-advisor

**EA:** QM5_13146_energy-vov

**Status:** Q01 PASS; one logical Q02 basket pending

## Edge And Evidence Boundary

The new edge is the monthly commodity volatility-of-volatility sort in
Hollstein, Prokopczuk, and Tharann, "Anomalies in Commodity Futures Markets,"
*Quarterly Journal of Finance* 11(4), article 2150017. The complete accepted
manuscript and appendix were reviewed. Its universe explicitly contains WTI
and natural gas, and its VoV tests report a negative high-minus-low spread,
which fixes the executable direction as low VoV long and high VoV short.

Primary source DOI:
https://doi.org/10.1142/S2010139221500178

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

The paper uses 252 daily option-implied-volatility observations. Darwinex CFD
runtime has no commodity option chain, so QM5_13146 is an explicit price-only
falsification rather than a claimed replication: it applies the source's
dispersion-over-mean construction to a nested realized-volatility series. No
source return, significance, drawdown, cost, or correlation number is imported
as an EA result.

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month t:

1. For each of XTIUSD.DWX and XNGUSD.DWX, use completed D1 closes only.
2. Construct 252 overlapping annualized realized-volatility estimates. Each
   estimate uses 20 log returns and sample return variance with denominator 19.
3. For each leg calculate
   `sqrt(sum((rv_j - mean_rv)^2) / 252) / mean_rv`.
4. Buy the lower realized-VoV leg and short the higher realized-VoV leg. Reject
   ties, insufficient or stale endpoints, non-positive means, invalid
   arithmetic, spreads, ATRs, lots, or package state.
5. Allocate one `RISK_FIXED=1000` package as equal fixed-risk halves with
   independent frozen ATR(20) times 3.5 hard stops. Close at the next monthly
   transition or after 40 days, flatten invalid composition/orphans, and
   prohibit same-month re-entry.

Expected density is approximately twelve packages/year after the 273-close
warm-up. The first economic evidence belongs to Q02.

## Non-Duplicate Decision

The canonical pre-allocation check returned CLEAN across 4,032 registry rows
and 334 cards. Same-source and generic `energy-*` fuzzy hits were manually
resolved by signal input, statistic, window, direction, and carrier:

- Existing XTI/XNG/XBR VRP proxies are directional high-RV stretch fades with
  reversal/SMA confirmation, not a monthly cross-sectional VoV rank.
- QM5_13133 ranks factor-residual volatility level.
- QM5_13139 divides 36-month return variance by mean return.
- QM5_13129, QM5_13130, QM5_13131, QM5_13141, and QM5_13143 use semivariance,
  maximum return, kurtosis, idiosyncratic asymmetry, and expected shortfall.
- QM5_12567 is the incumbent two-day long-only XNG RSI pullback.

Verdict: `CLEAN_PRE_ALLOCATION; POST_ALLOCATION_EXACT_MATCH_IS_SELF`.

## Identity And Registry Evidence

- EA reservation:
  `13146,energy-vov,HOLLSTEIN-VOV-2021_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131460000`.
- Magic slot 1: XNGUSD.DWX to `131460001`.
- The clean staged resolver retains 14,885 rows and both new magic values.
- Clean checkout magic-registry SHA256:
  `17BFFA837697E5CB34DD59D4A171198F839030F699CB2404E6E2B16BCAB1B566`.
- Resolver blob SHA256:
  `7710239A132E747C05C62236F5DA05DDFD9EB87FDF2F15587F3B7F7B165B528D`.

The resolver preserves the pre-existing QM5_13122 binding and drops only the
historical missing-directory IDs 1001, 1015, and 1016. Unrelated dirty fleet
allocations were excluded from build commit
`1f4b6b599b09881ea963736c8f098ba668cdffae`.

## Q01 Build Evidence

- Build commit: `1f4b6b599b09881ea963736c8f098ba668cdffae`.
- Strict clean-staged-resolver compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `D:/QM/reports/compile/20260711_182316/QM5_13146_energy-vov.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_182316.json`.
- Approved-card prebuild/schema checks, SPEC validator, build prerequisite
  guard, and basket symbol-scope validator: PASS.
- Symbol-scope verdict: `BASKET_OK` for XTIUSD.DWX and XNGUSD.DWX.
- MQ5 SHA256:
  `24C51AC8E34AE1E5E287EC5DEC0E273F2B6B4631E4824F39986C2DECB4163556`.
- EX5 SHA256:
  `6663CC326E2C53F06A3C3DAAC96133E6A62E914514C104DEC44EEFAABAC963FC`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13146_XTI_XNG_VOV_D1`; host XTIUSD.DWX, D1.
- Traded symbols: XTIUSD.DWX and XNGUSD.DWX.
- Setfile:
  `framework/EAs/QM5_13146_energy-vov/sets/QM5_13146_energy-vov_QM5_13146_XTI_XNG_VOV_D1_D1_backtest.set`.
- Setfile SHA256:
  `ED8429D4460C6BDAC7C0FB148D5E1B0302943E49ECAD6C3144A191808FC423FD`.
- Setfile build hash:
  `6505cdc0d98a8b0b9b15465286cd5d0972681e145228bdc1b3d29003a66c4288`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: `fdb723b1-0e21-4091-9758-8ddc0fc6d8d2`, done.
- Work item: `0ea56657-2d8a-413d-9ac4-9c7b25501099`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13146_XTI_XNG_VOV_D1`.
- Host/timeframe: XTIUSD.DWX / D1.
- Basket payload: XTIUSD.DWX and XNGUSD.DWX, `portfolio_scope=basket`.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-11T18:30:23+00:00`.
- `farmctl record-build` enqueued one item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started by this work. No backtest CPU slot was consumed, so no CPU ceiling was
encountered; Q02 owns the first CPU-bearing validation pass.

## Safety And Kill Boundary

- Structural D1/monthly price arithmetic only; no ML or banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- The implied-to-realized substitution, two-name carrier, overlapping windows,
  continuous-CFD basis, XNG gaps, legging, and costs are kill risks, never
  waiver grounds.
- Opposite directions and equal fixed-risk halves reduce common direction but
  do not establish dollar, beta, volatility, factor, or realized market
  neutrality. Portfolio certification and realized book orthogonality remain
  unclaimed until later gates measure them.
