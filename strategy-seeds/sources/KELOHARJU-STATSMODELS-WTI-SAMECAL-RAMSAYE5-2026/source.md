---
source_id: KELOHARJU-STATSMODELS-WTI-SAMECAL-RAMSAYE5-2026
title: WTI exact five-year same-calendar Ramsay-E robust location
publisher: QuantMechanica governed composite of peer-reviewed trading sources and official statsmodels source
source_type: peer_reviewed_trading_papers_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_same_calendar_ramsay_e_5_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
parent_sha256:
  KELOHARJU-RETSEAS-2016: 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-31
created_by: Research
cards_extracted:
  - wti-samecal-ramsaye5
---

# WTI Exact-Five-Year Same-Calendar Ramsay-E Source Packet

## Approval And Complete-Read Boundary

The durable source decision is
`decisions/2026-08-31_wti_same_calendar_ramsay_e_5_source_approval.md`.
It authorizes one card, deterministic allocation, one branch-only non-live
V5 build, strict Q01 validation, and one paced Q02 enqueue below the governed
CPU ceiling. It does not authorize a manual backtest or live action.

The following records were read completely under that decision:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, representing
   Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
   *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, plus the complete open NBER Working Paper 20815.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, representing Moskowitz,
   Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, plus the complete author-hosted published
   paper and its durable retrieval hash.
3. The complete bounded `RamsayE` class and `estimate_location` routine in
   the official statsmodels 0.15.0 module rendering. The 197,780-byte page
   has SHA-256
   `52994832B273BCC5F1F4F890F62E513B815CC46A1E4436367A64547DACBA819D`;
   retrieval evidence is
   `artifacts/qm5_wti_samecal_ramsaye5_statsmodels_retrieval_20260831.json`.
4. The complete governed soft-L1 packet
   `strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026/source.md`
   for the existing exact-calendar endpoint, median/MAD, frozen-scale, and
   fixed-iteration plumbing only.

## Trading-Source Findings Used

Keloharju, Linnainmaa, and Nyberg test whether historical returns for a named
calendar month recur when that month returns. Their commodity panel contains
24 futures, explicitly including crude oil, and requires at least five years
of history before a contract becomes eligible. Positions renew monthly.

Moskowitz, Ooi, and Pedersen test each instrument's own prior return as a
monthly directional state. Their commodity universe explicitly includes
NYMEX WTI crude. The paper supports own-return direction and monthly renewal
as a broad futures hypothesis.

Together those findings support falsifying whether WTI returns from the same
named calendar month in exact prior years contain recurring directional
information. Neither paper tests a single-WTI zero comparison, the fixed
five-observation Ramsay-E location below, or a Darwinex continuous CFD.

## Statistical-Source Findings Used

Official statsmodels source identifies `RamsayE` as Ramsay's Ea for
M-estimation, classifies it as soft redescending, and fixes default `a=0.3`.
For standardized residual `u`, it defines:

```text
rho(u)    = a^-2 * (1 - exp(-a*abs(u)) * (1 + a*abs(u)))
psi(u)    = u * exp(-a*abs(u))
weight(u) = psi(u)/u = exp(-a*abs(u))
```

The official `estimate_location` routine defaults to the sample median,
computes weights from `(observation-mu)/scale`, and updates location as
`sum(weight*observation)/sum(weight)`. This card locks the same update map but
uses exactly 32 updates with no early convergence. The five-return sample,
frozen scale, update budget, and trading direction are QM choices, not
statsmodels claims.

Ramsay-E exponentially attenuates large standardized residuals without a
finite hard cutoff. Every finite residual has mathematically positive weight.
The implementation rejects zero or nonfinite computed weights so numeric
underflow cannot silently delete a year.

## Bounded QM Mechanization

At the first processed D1 bar after a genuine normalized WTI broker-month
transition in year `Y` and month `M`, reconstruct the completed WTI log return
for month `M` in each exact year `Y-5` through `Y-1`. Require all five
observations. Compute the odd median and raw median absolute deviation,
freeze `scale=1.4826*MAD`, execute exactly 32 Ramsay-E reweighting updates
with `a=0.3`, and trade the final location's sign for one broker month.

The exact sample, single-CFD zero comparison, median start, scale
normalization, update budget, epsilon, endpoint normalization, fixed-dollar
sizing, ATR hard stop, spread ceiling, attempt ledger, and lifecycle are
transparent QM choices. The sources do not test or validate those choices.

## Exact Calendar And Endpoint Contract

- Host and traded carrier: exact `XTIUSD.DWX`, D1, symbol slot zero.
- Decision time: first executable host tick after normalized broker month
  changes.
- Target years: exactly `Y-5`, `Y-4`, `Y-3`, `Y-2`, and `Y-1`; no substitute
  year, shorter sample, or available-history compression.
- For each target `(year, month)`, require the last D1 close labelled in that
  month, the immediately preceding normalized month close, and at least one
  later D1 bar confirming completion.
- One uniform label rule applies to the copied D1 buffer: native broker labels
  when they contain at least two distinct months, otherwise the tested `+1`
  energy-label normalization. Mixed per-endpoint repair is forbidden.
- Endpoint timestamps must increase, prices must be positive and finite, and
  each completed return must be finite.

For each exact target year:

```text
r[year] = ln(close(year, M) / close(previous_month(year, M)))
```

The five original returns remain in chronological year order. Sorting is
applied only to copies used for the median and MAD.

## Exact Ramsay-E Contract

For finite returns `r[0]..r[4]`, ordered from `Y-5` through `Y-1`:

```text
s      = sort_ascending(copy(r))
median = s[2]
d[i]   = abs(r[i] - median)
a      = sort_ascending(copy(d))
MAD    = a[2]
scale  = 1.4826 * MAD

mu[0] = median
for j = 0..31:
  u[i]      = (r[i] - mu[j]) / scale
  weight[i] = exp(-0.3 * abs(u[i]))
  mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])

signal = BUY  when mu[32] > +1e-12
         SELL when mu[32] < -1e-12
         FLAT otherwise or when any state is invalid
```

Reject nonpositive or nonfinite MAD, scale, weight, weight sum, weighted sum,
or intermediate location. Reject a nonfinite standardized residual,
absolute residual, or exponent argument. The scale freezes before the first
update and all 32 updates execute. No early convergence, second start, scale
refit, observation replacement, deletion, fallback center, magnitude sizing,
or alternate location is permitted.

## Execution And Risk Contract

- Persist normalized `yyyymm` before history, signal, news, spread, quote,
  ATR, sizing, or submission. No failure retries within the month.
- Close the prior position at the next normalized broker-month boundary
  before replacement risk. A 40-calendar-day guard closes only a survivor.
- Close duplicate, wrong-symbol, invalid-side, wrong-magic, or stopless owned
  exposure before entry logic.
- Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for
  non-live pipeline tests.
- Attach one frozen `3.5 * ATR(20,D1)` broker hard stop and no take-profit.
- Reject negative/crossed spreads and positive spreads above 1,500 points.
- Lock current news temporal/compliance axes and legacy news mode OFF.
  Disable Friday flattening because the monthly hold spans weekends.
- Never scale in, pyramid, grid, martingale, partially close, trail, break
  even, optimize, read a runtime file/API, or consume portfolio state.

## Non-Duplicate Boundary

The canonical receipt
`artifacts/qm5_wti_samecal_ramsaye5_preallocation_dedup_20260831.json`,
SHA-256
`9F3FAEC5AE93C269494C4787DBFD87EF3E6B19D9926C7925DAD302E3CDF2459E`,
found no exact identity and only expected same-calendar robust-location
neighbors.

On `[-0.135,-0.010,-0.005,+0.005,+0.050]`, Ramsay-E finishes near
`+0.000567268656` and buys while otherwise matched soft-L1, Cauchy, and
arctangent paths plus raw mean and median sell. On
`[-0.130,-0.025,+0.005,+0.020,+0.190]`, Ramsay-E finishes near
`-0.000066275832` and sells while soft-L1, arctangent, raw mean, and median
buy. The exponential influence curve is not a renamed rational, piecewise,
compact-support, or order-statistic rule.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_RAMSAY_E_EXPONENTIAL_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Criteria

- R1: PASS with disclosed conjunction risk. Two named-author, DOI-bearing,
  peer-reviewed trading papers have complete-read evidence and explicit WTI
  membership. Official statsmodels source fixes Ramsay-E arithmetic and its
  default constant. The exact trading conjunction is untested.
- R2: PASS. Calendar, endpoints, exact years, return orientation, median,
  MAD, scale, constant, exponential weight, update count, side, attempt,
  risk, stop, spread, and exits are fixed before testing.
- R3: PASS with warm-up and basis risk. Registered `XTIUSD.DWX` D1 history
  and MT5-native calendar, quote, ATR, symbol, position, deal, and terminal
  state supply every runtime input.
- R4: PASS. Deterministic logarithm, sort, absolute deviation, exponential,
  multiplication, division, and fixed arithmetic only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Claim, Kill, And Safety Boundary

The sources support testing a recurring-calendar own-return WTI carrier and a
documented robust norm, not the efficacy of this five-observation statistic.
Q02 must retire at zero trades, below five completed positions in any full
post-warm-up year, or on nonpositive governed economics. Downstream gates
alone own robustness and realized correlation. No failure may be rescued by
changing the sample, scale, weight, constant, update count, direction,
carrier, stop, hold, spread, or retry contract.

This packet supports one card, deterministic allocation, one non-live V5
build, strict compile/Q01, and one paced target-only Q02 handoff below the CPU
ceiling. It does not authorize a manual tester run, live/demo/shadow/stress or
optimization preset, AutoTrading, `T_Live`, deploy manifest, T_Live manifest,
portfolio-gate change, portfolio admission, correlation waiver, or a claim of
profitability or decorrelation.
