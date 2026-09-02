---
source_id: RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902
title: WTI monthly sample-entropy-gated trend
publisher: QuantMechanica governed synthesis from peer-reviewed statistical and trading records
source_type: ai_originated_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_sample_entropy_trend_source_approval.md
created: 2026-09-02
created_by: Research+Development
parent_source_ids:
  - MOP-TSMOM-2012
cards_extracted:
  - wti-msampen-tr
---

# WTI Monthly Sample-Entropy-Gated Trend

## Sources Of Record And Retrieval Boundary

The exact statistical-method record is Jiri Tomcala (2020), "New Fast ApEn
and SampEn Entropy Algorithms Implementation and Their Application to
Supercomputer Power Consumption," *Entropy* 22(8), 863, DOI
`10.3390/e22080863`. The complete open-access article was read end to end from
PubMed Central. Its Equation 2 defines original sample entropy as the log ratio
of matching length-`m` templates to matching length-`m+1` templates after
self-matches are removed. Appendix B fixes the conventional defaults `m=2`,
lag one, and `r=0.2*sd(series)`.

The complete pinned CRAN `TSEntropies` `SampEn_R` method file, SHA-256
`2E74A7DA4C836E039E48F7985E68218D8C23B954AAEE5051873AD2BC7CF73933`,
resolves implementation details: maximum-coordinate distance, strict
`distance < r`, sample standard deviation, no self-matches, 59 length-two
templates and 58 length-three templates for a sixty-value series, and
`ln(B/A)` when both match counts are positive. Retrieval roles and claim
limits are durable in `retrieval_route_20260902.json`.

Joshua S. Richman and J. Randall Moorman (2000), "Physiological time-series
analysis using approximate entropy and sample entropy," *American Journal of
Physiology-Heart and Circulatory Physiology* 278(6), H2039-H2049, DOI
`10.1152/ajpheart.2000.278.6.H2039`, supplies original provenance. Only its
publisher metadata and abstract were accessible in this session; its body is
not represented as completely read.

The trading carrier is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The existing governed record
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
preserves the complete 23-page read, monthly own-return continuation, and
explicit NYMEX WTI membership.

None of these sources tests the exact entropy/trend conjunction, a sixty-
return WTI window, the `2.5` threshold, Darwinex continuous-CFD mapping,
fixed-dollar risk, costs, activity, or portfolio correlation. Those are
transparent, pre-result QM hypotheses.

## Exact Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly sixty-one consecutive completed broker-month
end closes `C[0]..C[60]`, oldest to newest. Exclude every current-month price
and form sixty chronological adjacent log returns:

```text
x[i] = ln(C[i+1] / C[i]), i=0..59
mean = sum(x[i]) / 60
sd   = sqrt(sum((x[i]-mean)^2) / 59)
r    = 0.2 * sd
```

For dimension `d` in `{2,3}`, define every lag-one template
`T_d(i)=(x[i],...,x[i+d-1])`, `i=0..60-d`. Two distinct templates match iff
their Chebyshev distance is strictly less than `r`. Count each unordered pair
once:

```text
B = count(i<j, i,j in 0..58, max_k=0..1 abs(x[i+k]-x[j+k]) < r)
A = count(i<j, i,j in 0..57, max_k=0..2 abs(x[i+k]-x[j+k]) < r)
SampEn = ln(B/A)
mom12  = sum(x[i], i=48..59)

BUY  iff A>0, B>0, SampEn <= 2.5 and mom12 > +1e-12
SELL iff A>0, B>0, SampEn <= 2.5 and mom12 < -1e-12
FLAT otherwise
```

Require positive finite closes, finite returns and intermediates, `sd>1e-12`,
`r>0`, integer `B>=A>0`, and nonnegative finite sample entropy. A match exactly
at `r` does not count. Invalid counts, high complexity, or neutral direction
consume the month flat. Entropy and momentum magnitude never change risk.

The method supplies only a path-complexity state descriptor. The hypothesis
is that WTI's physical supply, storage, transport, refining, geopolitical,
hedging, and demand shocks sometimes produce a more recurrent monthly return
path in which the independently sourced twelve-month continuation carrier is
worth attempting.

## Event, Risk, And Lifecycle Contract

1. Persist normalized broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order checks. Never retry a consumed month.
2. Use the latest D1 close from each immediately prior consecutive broker
   month. Require strict timestamp chronology and a newest endpoint no more
   than ten calendar days stale.
3. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen
   `3.5*ATR(20,D1)` broker hard stop. Attach no target.
4. Cap entry spread at 1,500 points. Both news axes, legacy news, Friday
   close, and stress rejection are OFF.
5. Close at the next genuine broker-month transition or after forty elapsed
   calendar days. Repair duplicate, wrong-symbol, wrong-side, or stopless
   owned exposure immediately.

Runtime uses registered MT5 D1 price, timestamp, ATR, quote, symbol metadata,
position, deal-history, and terminal-global state only. No futures curve,
inventory, external file/API, optimizer output, portfolio state, randomness,
trained output, scale-in, grid, martingale, or pyramid is allowed.

## Market-Free Cadence Prior

The fixed-seed receipt
`artifacts/qm5_wti_msampen_tr_null_density_20260902.json` applies the exact
statistic to 100,000 independent sixty-observation standard-normal paths. It
records 59,272 finite observations at `SampEn<=2.5`, 13,328 zero-`A` invalid
paths, and 27,400 valid paths above the boundary. The qualification fraction
is `0.59272`, or `7.11264` theoretical attempts per twelve clocks.

This is a market-free activity sanity check, not WTI evidence, a p-value,
performance, independence, or a claim about the true monthly state frequency.
Q02 owns actual per-year activity and economics.

## Non-Duplicate Boundary

The corrected-root fail-closed checker scanned 4,796 EA identities, 1,425
card files, and 45 Strategy Wiki nodes without an exact or fuzzy match.
Receipt:
`artifacts/qm5_wti_msampen_tr_preallocation_dedup_20260902.json`, SHA-256
`1DC955560717980BCB73A2B69DBDB64CA038E5EFC990E7D0C1E9AFE827D11CF6`.

Manual review fixes the load-bearing distinctions:

- `QM5_41308_wti-mordinal-entropy-tr` counts six rank-order labels in eight
  disjoint triples. This candidate retains raw return magnitudes and counts
  all overlapping lag-one templates within a sample-standard-deviation
  radius; amplitude and local recurrence can change its state while ordinal
  labels stay unchanged.
- `QM5_41309_wti-mlz76-tr` parses a twenty-bit return-sign word into new
  phrases. It discards magnitude and has no distance radius or conditional
  length-two/length-three recurrence ratio.
- `QM5_41310_wti-mvnratio-tr` compares squared adjacent return changes with
  total dispersion. It has no template matching or entropy logarithm.
- Variance-ratio, sign-run/count, rank, regression, location, scale,
  distribution-shift, calendar, event, and channel systems use different
  state objects. `QM5_9520_mql5-entropy` is an intraday ternary Shannon-state
  crossover, not monthly WTI sample entropy.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_60_RETURN_M2_R020SD_SAMPEN_LE250_GATED_12M_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_SYNTHESIS_BOUNDARY`: complete peer-reviewed open-access
  method article, complete pinned transparent CRAN method file, original
  peer-reviewed provenance, and a complete governed peer-reviewed WTI
  trading-paper read. The conjunction is explicitly new synthesis.
- R2 `PASS`: clock, sample, mean, sample standard deviation, radius,
  templates, strict distance, counts, logarithm, boundary, direction,
  attempt, risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 and
  native MT5 state supply every runtime input.
- R4 `PASS`: bounded deterministic arithmetic and native framework state;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Retire at zero positions, below five completed positions in any full scored
post-warm-up year, on nonpositive governed economics, or on any endpoint,
return, standard-deviation, radius, template, match-count, entropy, threshold,
direction, attempt, risk, stop, or lifecycle defect. Do not rescue a failure
by changing the sample, tolerance, template dimension, boundary, direction,
carrier, stop, hold, spread, or retry policy.

This source authorizes one branch-only non-live card/build, strict Q01, and
one paced Q02 enqueue under the current OWNER mission. It authorizes no
manual backtest; live/demo/shadow/stress/optimization preset; `T_Live` or
AutoTrading action; deploy/T_Live manifest; portfolio-gate edit; portfolio
admission; correlation waiver; or manual terminal control.
