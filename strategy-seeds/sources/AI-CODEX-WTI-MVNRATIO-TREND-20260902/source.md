---
source_id: AI-CODEX-WTI-MVNRATIO-TREND-20260902
title: WTI monthly raw von Neumann ratio gated trend
publisher: QuantMechanica governed synthesis from primary statistical and peer-reviewed trading records
source_type: ai_originated_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_von_neumann_ratio_trend_source_approval.md
created: 2026-09-02
created_by: Research+Development
parent_source_ids:
  - MOP-TSMOM-2012
cards_extracted:
  - wti-mvnratio-tr
---

# WTI Monthly Raw von Neumann Ratio Gated Trend

## Sources Of Record And Retrieval Boundary

The exact statistical reference is the NIST/SEMATECH Dataplot page "Mean
Successive Differences Test," last updated 2023-12-11. The complete public
page was read in bounded sections. It defines the ratio of the sum of squared
successive differences to the sum of squared deviations from the sample mean,
states that its average under random normal data is two, and interprets small
values as long-term trend. Reproducible route and claim boundaries are in
`retrieval_route_20260902.json`.

Original provenance is John von Neumann (1941), "Distribution of the Ratio of
the Mean Square Successive Difference to the Variance," *Annals of
Mathematical Statistics* 12(4), 367-395, DOI
`10.1214/aoms/1177731677`. The original body is not represented as completely
read, so it contributes provenance only.

The trading carrier is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The existing governed
record `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
preserves the complete 23-page read, monthly own-return continuation, and
explicit NYMEX WTI membership.

The papers and NIST page do not test this exact 20-return conjunction, a
Darwinex continuous CFD, the threshold as a profitable trading gate,
fixed-dollar risk, an ATR stop, spread cap, attempt ledger, or portfolio
decorrelation. Those are disclosed QM hypotheses.

## Exact Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly twenty-one consecutive completed broker-month
end closes `C[0]..C[20]`, oldest to newest. Exclude every current-month price
and form twenty chronological adjacent log returns:

```text
r[i] = ln(C[i+1] / C[i]), i=0..19
mean = sum(r[i], i=0..19) / 20
V    = sum((r[i] - mean)^2, i=0..19)
D    = sum((r[i+1] - r[i])^2, i=0..18)
eta  = D / V
mom12 = sum(r[i], i=8..19)

BUY  iff eta < 2.0 and mom12 > 1e-12
SELL iff eta < 2.0 and mom12 < -1e-12
FLAT otherwise
```

Require positive finite closes, finite returns and intermediates, `V>1e-18`,
`D>=0`, and `eta>=0`. An inclusive `abs(mom12)<=1e-12` tie consumes the
month flat. The ratio magnitude never sets side, size, stop, or hold. The
strict mean boundary is a prespecified state split, not a claimed
significance threshold or p-value.

The newest twelve-month return supplies direction because the peer-reviewed
trading record documents own-price continuation through twelve months and
includes WTI. The raw von Neumann ratio supplies a structurally different
path gate: low successive variation relative to total return dispersion.

## Event, Risk, And Lifecycle Contract

1. Persist the normalized broker `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order checks. Never retry a consumed
   month.
2. Use the latest D1 close from each of the immediately prior twenty-one
   consecutive broker months. Require strict timestamp chronology and a
   newest endpoint no more than ten calendar days stale.
3. Open at most one WTI position under `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, sized against a frozen
   `3.5*ATR(20,D1)` broker hard stop. No target is attached.
4. Cap entry spread at 1,500 points. Both news axes, legacy news mode, Friday
   close, and stress rejection are OFF.
5. Close at the next genuine broker-month transition or after forty elapsed
   calendar days. Repair wrong-symbol, wrong-magic, duplicate, wrong-side,
   invalid-volume, or stopless owned exposure immediately.

Runtime uses registered MT5 D1 price, timestamp, ATR, quote, symbol metadata,
position, deal-history, and terminal-global state only. No futures curve,
inventory, external file/API, optimizer result, portfolio state, randomness,
trained output, scale-in, grid, martingale, or pyramid is allowed.

## Cadence Prior

The fixed-seed, market-free receipt
`artifacts/qm5_wti_mvnratio_tr_null_density_20260902.json` applies the exact
20-observation statistic to 200,000 independent standard-normal samples. It
qualifies 49.9715%, implying 5.9966 packages per twelve monthly attempts.
This only checks that the prespecified mean split is compatible with the
binding five-trades/year floor under a null thought experiment. It is not WTI
data, a backtest, or a probability claim. Q02 owns actual per-year density.

## Non-Duplicate Boundary

The corrected-root fail-closed checker scanned 4,795 EA identities, 1,424
cards, and 45 Strategy Wiki nodes with no exact or fuzzy match. Receipt:
`artifacts/qm5_wti_mvnratio_tr_preallocation_dedup_20260902.json`, SHA-256
`8539B7F5E61A88376EA0E2BA0CE1AF42E7EB2B7028C0356A3C7BB1C663D09142`.

Manual semantic review fixes the load-bearing distinction:

- `QM5_41170_wti-bartels-rank-tr` converts thirteen month-end price levels
  into ordinal ranks and sums successive squared rank gaps. This candidate
  computes the raw ratio on twenty monthly log-return magnitudes; monotone
  transforms and outlier amplitudes can change it.
- `QM5_20274_wti-path-eff` divides one net endpoint move by total absolute
  path length. This candidate centers all twenty returns and squares both
  adjacent changes and total dispersion.
- variance-ratio EAs aggregate multi-period return variances or weighted
  autocovariances. This candidate uses the one fixed adjacency/dispersion
  ratio and no q-horizon variance aggregation.
- ordinal entropy, LZ76, sign-run, sign-count, rank, regression, location,
  scale, distribution-shift, calendar, event, and channel EAs use different
  state objects.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not direct-WTI monthly raw-path continuation.

Verdict:
`CLEAN_WTI_MONTHLY_20_RAW_RETURN_VON_NEUMANN_ETA_LT2_GATED_12M_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_SYNTHESIS_BOUNDARY`: official NIST exact-method page,
  original peer-reviewed statistical provenance, and a complete governed
  peer-reviewed WTI trading-paper read. The conjunction is explicitly a new
  QM hypothesis.
- R2 `PASS`: clock, endpoint count, return orientation, centering,
  numerator, denominator, strict boundary, direction, consumed attempt, risk,
  stop, and lifecycle are fixed.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 and
  native MT5 state supply every runtime input.
- R4 `PASS`: deterministic closed-form arithmetic and framework state only;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Retire at zero positions, below five completed positions in any full
post-warm-up year, on nonpositive governed economics, or on any endpoint,
return, centering, numerator, denominator, threshold, direction, attempt,
risk, stop, or lifecycle defect. Do not rescue a failure by changing the
20-return sample, strict threshold, twelve-month side, carrier, stop, hold,
spread, or retry contract.

This source authorizes one branch-only non-live card/build, strict Q01, and
one paced Q02 handoff under the current OWNER mission. It authorizes no manual
backtest; live, demo, shadow, stress, or optimization setfile; `T_Live` or
AutoTrading action; deploy/T_Live manifest; portfolio-gate edit; portfolio
admission; correlation waiver; or terminal control.
