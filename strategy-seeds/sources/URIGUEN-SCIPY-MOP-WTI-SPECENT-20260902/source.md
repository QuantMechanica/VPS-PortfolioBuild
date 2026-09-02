---
source_id: URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902
title: WTI monthly spectral-entropy-gated trend
publisher: QuantMechanica governed synthesis from peer-reviewed statistical and trading records
source_type: ai_originated_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_spectral_entropy_trend_source_approval.md
created: 2026-09-02
created_by: Research+Development
parent_source_ids:
  - MOP-TSMOM-2012
cards_extracted:
  - wti-mspectral-entropy-tr
---

# WTI Monthly Spectral-Entropy-Gated Trend

## Sources Of Record And Retrieval Boundary

The exact entropy-method record is Jose Antonio Uriguen, Begona
Garcia-Zapirain, Julio Artieda, Jorge Iriarte, and Miguel Valencia (2017),
"Comparison of background EEG activity of different groups of patients with
idiopathic epilepsy using Shannon spectral entropy and cluster-based
permutation statistical testing," *PLOS ONE* 12(9), e0184044, DOI
`10.1371/journal.pone.0184044`. The complete open-access article was read end
to end from PubMed Central. Equation 1 defines Shannon spectral entropy as the
entropy of a unit-sum power spectrum and defines a zero-power bin's entropy
contribution as zero. Its methods explain the statistic's load-bearing
interpretation: high values accompany broad, flat spectral power, while low
values accompany power concentrated in fewer frequency bins.

The tagged SciPy 1.17.1 `scipy.signal._spectral_py` source, SHA-256
`9C1FA9FA599CE670EBE91617CE43D11229A9D95F4B7ADCBFD675BB2A44EB408E`,
pins the periodogram convention used for the QM translation. The complete
`periodogram` function and documentation and the relevant helper branches were
read. The default subtracts a constant, constructs the real one-sided
spectrum, adds paired negative-frequency power to positive-frequency power,
and leaves the even-length unpaired Nyquist bin undoubled. The EA reimplements
the fixed, small DFT directly; SciPy is neither imported nor run by MT5.

The trading carrier is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The existing governed record
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
preserves the complete 23-page read, monthly own-return continuation, and
explicit NYMEX WTI membership.

None of these sources tests the spectral-entropy/trend conjunction, a
48-return WTI window, the `0.88` boundary, Darwinex continuous-CFD mapping,
fixed-dollar risk, costs, activity, or portfolio correlation. The PLOS EEG
thresholds and results do not transfer. Every conjunction and execution
choice below is a transparent, pre-result QM hypothesis.

## Exact Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly forty-nine consecutive completed broker-month
end closes `C[0]..C[48]`, oldest to newest. Exclude every current-month price
and form forty-eight chronological adjacent log returns:

```text
x[i] = ln(C[i+1] / C[i]), i=0..47
mean = sum(x[i]) / 48
y[i] = x[i] - mean
```

For every one-sided non-DC frequency bin `k=1..24`, compute the length-48 DFT
without tapering or zero padding:

```text
Re[k] = sum(y[i] * cos(2*pi*k*i/48), i=0..47)
Im[k] = -sum(y[i] * sin(2*pi*k*i/48), i=0..47)
raw[k] = Re[k]^2 + Im[k]^2
power[k] = 2*raw[k], k=1..23
power[24] = raw[24]                       # unpaired Nyquist bin
total = sum(power[k], k=1..24)
p[k] = power[k] / total
Hspec = -sum(p[k]*ln(p[k]), p[k]>0) / ln(24)
mom12 = sum(x[i], i=36..47)

BUY  iff Hspec <= 0.88 and mom12 > +1e-12
SELL iff Hspec <= 0.88 and mom12 < -1e-12
FLAT otherwise
```

Require positive finite closes; finite returns, trigonometric terms, DFT
components, powers, probabilities, and entropy; `total>1e-24`; probability
sum within `1e-10` of one; and `Hspec` within `[-1e-12,1+1e-10]`. Clamp only
roundoff within the admitted entropy tolerance to `[0,1]`. Natural versus
base-two logarithms gives the same normalized value. High entropy, neutral
direction, or invalid arithmetic consumes the month flat. Entropy and
momentum magnitude never change risk.

The method supplies only a frequency-domain path-structure descriptor. The
hypothesis is that WTI's physical supply, storage, transport, refining,
geopolitical, hedging, and demand shocks sometimes concentrate completed
monthly-return power in fewer frequencies, a state in which the independently
sourced twelve-month continuation carrier is worth attempting.

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
`artifacts/qm5_wti_mspecent_tr_null_density_20260902.json` applies the exact
statistic to 100,000 independent 48-observation standard-normal paths. It
records 59,188 observations at `Hspec<=0.88`, no invalid total-power paths,
and 40,812 valid observations above the boundary. The qualification fraction
is `0.59188`, or `7.10256` theoretical attempts per twelve clocks.

This is a market-free activity sanity check, not WTI evidence, a p-value,
performance, independence, or a claim about the true monthly state frequency.
The `0.88` boundary was locked only to leave a plausible path to the unchanged
activity floor before any WTI observation was examined. Q02 owns actual
per-year activity and economics.

## Non-Duplicate Boundary

The corrected-root fail-closed checker scanned 4,797 EA identities, 1,426
card files, and 45 Strategy Wiki nodes without an exact or fuzzy match.
Receipt:
`artifacts/qm5_wti_mspecent_tr_preallocation_dedup_20260902.json`, SHA-256
`5CC47A1D3CDDC1C1BE9F706D0D368666D44B635D9380D05CE51D071578BCF7E8`.

Manual review fixes the load-bearing distinctions:

- `QM5_41308_wti-mordinal-entropy-tr` counts six time-domain rank-order
  patterns. This candidate takes a one-sided DFT of raw return magnitudes and
  measures how power is distributed across 24 frequency bins; rearrangement
  or magnitude changes can alter either state independently.
- `QM5_41309_wti-mlz76-tr` parses a twenty-bit return-sign word into phrases.
  It discards magnitude and has no frequency transform or spectral powers.
- `QM5_41310_wti-mvnratio-tr` compares squared adjacent return changes with
  total dispersion. It has no frequency-bin distribution or entropy sum.
- `QM5_41311_wti-msampen-tr` counts local raw-magnitude template recurrences
  at dimensions two and three. It has no global DFT or power spectrum.
- `QM5_9520_mql5-entropy` is an intraday ternary time-domain Shannon-state
  crossover, not monthly WTI power-spectrum entropy. Pure trend,
  variance-ratio, sign-run/count, rank, regression, location, scale,
  distribution-shift, calendar, event, and channel systems use different
  state objects.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_ONESIDED_DFT_SPECENT_LE088_GATED_12M_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_SYNTHESIS_BOUNDARY`: complete peer-reviewed open-access
  spectral-entropy article, pinned official tagged periodogram source, and a
  complete governed peer-reviewed WTI trading-paper read. The conjunction is
  explicitly new synthesis.
- R2 `PASS`: month clock, endpoints, returns, demeaning, DFT sign and bins,
  paired/Nyquist weights, power normalization, entropy, boundary, direction,
  attempt, risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 and
  native MT5 state supply every runtime input.
- R4 `PASS`: bounded deterministic arithmetic and native framework state;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Retire at zero positions, below five completed positions in any full scored
post-warm-up year, on nonpositive governed economics, or on any endpoint,
return, demeaning, DFT, frequency-bin, Nyquist-weight, power, normalization,
entropy, threshold, direction, attempt, risk, stop, or lifecycle defect. Do
not rescue a failure by changing the sample, transform, bins, weights,
boundary, direction, carrier, stop, hold, spread, or retry policy.

This source authorizes one branch-only non-live card/build, strict Q01, and
one paced Q02 enqueue under the current OWNER mission. It authorizes no
manual backtest; live/demo/shadow/stress/optimization preset; `T_Live` or
AutoTrading action; deploy/T_Live manifest; portfolio-gate edit; portfolio
admission; correlation waiver; or manual terminal control.
