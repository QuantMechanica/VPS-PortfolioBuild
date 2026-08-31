---
source_id: KELOHARJU-SCIPY-WTI-SAMECAL-ARCTAN5-2026
title: WTI exact five-year same-calendar arctangent-weighted robust location
publisher: QuantMechanica governed composite of peer-reviewed trading sources and official SciPy statistical documentation
source_type: peer_reviewed_trading_papers_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_same_calendar_arctan5_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
parent_sha256:
  KELOHARJU-RETSEAS-2016: 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-31
created_by: Research
cards_extracted:
  - wti-samecal-arctan5
---

# WTI Exact-Five-Year Same-Calendar Arctangent Source Packet

## Approval And Complete-Read Boundary

The durable source decision is
`decisions/2026-08-31_wti_same_calendar_arctan5_source_approval.md` at commit
`184a4ebc7`, SHA-256
`9E96A4F4618CC14CA4E7CA6C7AA896C5B2C0E1562954F926C91E083B9B2C776A`.
It authorizes one card, deterministic allocation, one branch-only non-live
V5 build, strict Q01 validation, and one paced Q02 enqueue below the governed
CPU ceiling. It does not authorize a manual backtest or live action.

The following records were read completely under that decision:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, representing
   Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
   *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, plus the complete open 57-page NBER Working Paper
   20815.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, representing Moskowitz,
   Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, plus the complete author-hosted 23-page
   published paper and its durable retrieval hash.
3. The complete current `scipy.optimize.least_squares` reference page,
   `https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html`,
   maintained by the SciPy community and reviewed 2026-08-31. The retrieved
   93,197-byte HTML had SHA-256
   `CD8BCEEF256035736DDDE8E0F690C2487EFEFD5AFA773AEB50C822E5AF632435`.
   The relevant contract appears in the objective, `loss`, and `f_scale`
   entries.
4. The complete governed packet
   `strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026/source.md`,
   which preserves the already reviewed rescaled-MAD, median-start,
   frozen-scale, fixed-iteration robust-location convention and local-solution
   risk.

No inaccessible page, inferred table value, unreviewed source fragment, or
ungoverned performance claim is used.

## Trading-Source Findings Used

Keloharju, Linnainmaa, and Nyberg test whether historical returns for a named
calendar month recur when that month returns. Their commodity panel contains
24 futures, explicitly including crude oil, and requires at least five years
of history before a contract becomes eligible. The paper renews the
cross-sectional commodity position monthly.

Moskowitz, Ooi, and Pedersen test each instrument's own prior return as a
monthly directional state. Their commodity universe explicitly includes
NYMEX WTI crude. The paper supports own-return direction and monthly renewal
as a broad futures hypothesis.

Together those findings support falsifying whether WTI returns from the same
named calendar month in exact prior years contain recurring directional
information. Neither paper tests a single-WTI zero comparison, the fixed
five-observation arctangent location below, or a Darwinex continuous CFD.

## Statistical-Source Findings Used

The official SciPy documentation defines nonlinear robust least-squares
through a residual cost of the form:

```text
F = 0.5 * sum(rho(f_i^2))
```

For the arctangent option it fixes:

```text
rho(z) = arctan(z)
rho_C(f^2) = C^2 * rho(f^2 / C^2)
```

It states that this bounds the maximum loss contributed by one residual and
has properties similar to the Cauchy loss. The derivative of the documented
loss with respect to `z=(f/C)^2` is `1/(1+z^2)`. The bounded QM reweighting
therefore uses `weight=1/(1+u^4)` for standardized residual `u`. This
derivative translation is explicit arithmetic from the source formula;
SciPy does not prescribe this card's sample, start, scale estimator, fixed
iteration count, or trading direction.

The arctangent loss is non-convex as a location objective and may have local
solutions. The card does not claim a globally unique optimum. It makes one
path reproducible by locking the odd median start, a frozen scale, the
original sample, and exactly 32 updates without early convergence, restart,
or result selection.

The governed Cauchy packet supplies only the existing convention for odd
median, raw median absolute deviation, normal-consistency multiplier
`1.4826`, frozen scale, and fixed iteratively reweighted location plumbing.
It does not transfer the Cauchy weight curve or any prior result.

## Bounded QM Mechanization

At the first processed D1 bar after a genuine normalized WTI broker-month
transition in year `Y` and month `M`, reconstruct the completed WTI log return
for month `M` in each exact year `Y-5` through `Y-1`. Require all five
observations. Compute the odd median and raw median absolute deviation,
freeze `scale=1.4826*MAD`, execute exactly 32 arctangent-loss reweighting
updates, and trade the final location's sign for one broker month.

The exact sample, single-CFD zero comparison, median start, scale
normalization, derivative-weight mapping, update budget, epsilon, endpoint
normalization, fixed-dollar sizing, ATR hard stop, spread ceiling, attempt
ledger, and lifecycle are transparent QM choices. The sources do not test or
validate those choices.

## Exact Calendar And Endpoint Contract

- Host and traded carrier: exact `XTIUSD.DWX`, D1, symbol slot zero.
- Decision time: the first executable host tick after a normalized broker
  month key changes.
- Target years: exactly `Y-5`, `Y-4`, `Y-3`, `Y-2`, and `Y-1`; no substitute
  year, shorter sample, or available-history compression.
- For each target `(year, month)`, require the last D1 close labelled in that
  month, the immediately preceding normalized month close, and at least one
  later D1 bar confirming completion.
- One uniform label rule applies to the entire copied D1 buffer: native broker
  labels when they contain at least two distinct months, otherwise the tested
  `+1` energy-label normalization. Mixed per-endpoint repair is forbidden.
- Endpoint timestamps must increase, prices must be positive and finite, and
  each completed return must be finite.

For each exact target year:

```text
r[year] = ln(close(year, M) / close(previous_month(year, M)))
```

The five original returns remain in exact chronological year order. Sorting
is applied only to copies used for the median and MAD.

## Exact Arctangent Contract

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
  weight[i] = 1 / (1 + u[i]^4)
  mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])

signal = BUY  when mu[32] > +1e-12
         SELL when mu[32] < -1e-12
         FLAT otherwise or when any state is invalid
```

Reject nonpositive or nonfinite MAD or scale. Reject any nonfinite residual,
standardized residual, square, fourth power, denominator, weight, weighted
value, partial sum, total weight, weighted sum, or intermediate location. The
scale freezes before the first update. All 32 updates execute. Every finite
residual keeps a strictly positive weight. There is no early convergence
stop, second start, global optimizer, scale refit, observation replacement,
return deletion, fallback center, magnitude sizing, or alternate location.

## Execution And Risk Contract

- Persist the current normalized `yyyymm` attempt before history, signal,
  news, spread, quote, ATR, sizing, or submission. No failure retries within
  the month.
- Close the prior position at the next normalized broker-month boundary
  before considering replacement risk. A 40-calendar-day guard closes only a
  survivor.
- Close duplicate, wrong-symbol, invalid-side, wrong-magic, or stopless owned
  exposure before entry logic.
- Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for non-live pipeline tests.
- Attach one frozen `3.5 * ATR(20,D1)` broker hard stop and no take-profit.
- Reject negative or crossed spreads and genuinely positive spreads above
  1,500 points.
- Lock current news temporal/compliance axes and legacy news mode OFF. Disable
  Friday flattening because the monthly structural hold spans weekends.
- Never scale in, pyramid, grid, martingale, partially close, trail, break
  even, optimize, read a runtime file/API, or consume portfolio state.

## Non-Duplicate Boundary

The corrected canonical receipt
`artifacts/qm5_wti_samecal_arctan5_preallocation_dedup_20260831.json`,
SHA-256
`4A050EBE9CC45328B34FFC69CD18485A2A65B45246F1E4E625CEA81057F7232F`,
scanned 4,737 registry identities, 1,375 cards, and 45 Strategy Wiki nodes. It
found no exact identity and only expected same-calendar family neighbors.

For sorted returns `[-0.095,-0.045,-0.005,+0.050,+0.060]`, raw MAD is
`0.055`, scale is `0.081543`, and the locked arctangent iteration finishes
near `+0.006280955600`, so it buys. The otherwise matched Cauchy location
finishes near `-0.002436516741`; raw mean is `-0.007` and median is `-0.005`,
so all three sell. Sign reflection reverses every strict mapping.

`QM5_41237` uses the quadratic-tail rational weight `1/(1+u^2)`. This
candidate uses the quartic-tail rational weight `1/(1+u^4)`. `QM5_41204`
uses ten exact years and Huber's unit/inverse-linear weight. `QM5_41231` and
`QM5_41235` use compact-support bisquare and Hampel curves with exact-zero
tail regions. The arctangent curve and fixed path change the fixture's side
and cannot be reduced to a renamed lookback or threshold.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_ARCTAN_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Criteria

- R1: PASS with disclosed conjunction risk. Two named-author, DOI-bearing,
  peer-reviewed trading papers have complete-read evidence and explicit WTI
  membership. Official SciPy documentation fixes the arctangent loss and
  scale convention. The derivative-weight trading conjunction is not a
  published result.
- R2: PASS. Calendar, endpoints, exact years, return orientation, median,
  MAD, scale, quartic rational weight, update count, side, attempt, risk,
  stop, spread, and exits are fixed before testing.
- R3: PASS with warm-up and basis risk. Registered `XTIUSD.DWX` D1 history
  and MT5-native calendar, quote, ATR, symbol, position, deal, and terminal
  state supply every runtime input.
- R4: PASS. Deterministic logarithm, sort, absolute deviation, square,
  multiplication, division, and fixed arithmetic only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Claim And Kill Boundary

The sources support testing a recurring-calendar own-return WTI carrier and a
documented robust loss, not the efficacy of this fitted five-observation
statistic. Q02 must retire the card at zero trades, below five completed
positions in any full post-warm-up year, or on nonpositive governed
economics. Downstream gates alone own robustness and realized correlation.
No failure may be rescued by changing the sample, scale, weight, update
count, direction, carrier, stop, hold, spread, or retry contract.

## Safety Boundary

This packet supports one card, deterministic allocation, one non-live V5
build, strict compile/Q01, and one paced target-only Q02 handoff below the CPU
ceiling. It does not authorize a manual tester run, live/demo/shadow/stress or
optimization preset, AutoTrading, `T_Live`, deploy manifest, T_Live manifest,
portfolio-gate change, portfolio admission, correlation waiver, or a claim
of profitability or decorrelation.
