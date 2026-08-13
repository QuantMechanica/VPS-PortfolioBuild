---
source_id: HOLLSTEIN-WTI-VOV-REGIME-2026
parent_source_id: HOLLSTEIN-VOV-2021
title: WTI Self-Relative Realized Volatility-of-Volatility Regime
source_type: bounded_strategy_extraction
status: approved_source_bounded
approval_ref: decisions/2026-08-13_qm5_20298_wti_vov_regime_g0.md
created: 2026-08-13
created_by: Research+Development
primary_uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
doi: 10.1142/S2010139221500178
cards_extracted:
  - wti-vov-regime
---

# Hollstein-Prokopczuk-Tharann WTI Self-Relative VoV Extraction

## Durable Approval And Complete-Read Basis

The OWNER commodity/energy portfolio mission is durably bounded in
`decisions/2026-08-13_qm5_20298_wti_vov_regime_g0.md`. The governed parent
packet `strategy-seeds/sources/HOLLSTEIN-VOV-2021/source.md`, SHA-256
`F54F17F2DCDA40000D939D2D89122F4EA3F305293018AFF331A6C018F3DBDD00`, records
an end-to-end read of the 57-page accepted article and online appendix.

The source was independently reverified on 2026-08-13 against the University
of Reading institutional manuscript and the authors' university publication
record. This bounded packet uses no secondary performance claim.

## Primary Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017. DOI: https://doi.org/10.1142/S2010139221500178.

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

## Relevant Complete-Source Locations

- accepted-manuscript pp. 5-9: the 26-commodity universe, WTI membership,
  fixed-maturity futures returns, monthly sort construction, and one-year
  formation convention;
- p. 16 and Table 4 Panel D: negative high-minus-low VoV mean and alphas;
- Appendix B p. 29: source VoV is the population standard deviation of 252
  daily implied-volatility observations divided by their mean;
- Online Appendix Table A1: negative univariate cross-sectional VoV slope;
- Online Appendix Table A3 Panel D: negative two-portfolio robustness result;
- Online Appendix Table A4 Panel D: direction persists but weakens later; and
- Online Appendix Table A5 Panel D: annual holds weaken the effect, supporting
  monthly renewal rather than a one-year hold.

## Source Rule

For each commodity at month end, the source uses 252 daily option-implied-
volatility observations:

```text
mean_iv = average(iv[d], d=1..252)
vov     = sqrt(sum((iv[d] - mean_iv)^2) / 252) / mean_iv
```

It ranks a broad cross-section, holds for one month, and reports the
high-minus-low return. The negative spread fixes the implementable direction:
buy lower VoV and sell higher VoV.

## Bounded WTI Translation

Darwinex CFD runtime exposes no commodity option chain. This extraction does
not claim replication. It first applies the already governed price-native
proxy: 252 overlapping annualized realized-volatility observations, each
formed from 20 completed D1 log returns with sample-variance denominator 19,
then population VoV divided by mean realized volatility.

The new single-WTI carrier needs a fixed comparison state. It compares two
consecutive estimates with disjoint return support:

```text
r[b,s,k] = ln(close[b+s+k] / close[b+s+k+1]), k=0..19
rv[b,s]  = sqrt(sample_variance(r[b,s,0..19], denominator 19)) * sqrt(252)
mean_rv[b] = average(rv[b,0..251])
vov[b] = sqrt(sum((rv[b,s] - mean_rv[b])^2) / 252) / mean_rv[b]

recent block offset   b = 0    (return indices 0..270)
preceding block offset b = 271 (return indices 271..541)

BUY  XTIUSD.DWX when vov[0] < vov[271] - 1e-12
SELL XTIUSD.DWX when vov[0] > vov[271] + 1e-12
FLAT on a tie or invalid state
```

Exactly 543 completed closes cover the two blocks. They share only the
boundary close and no return. The first processed D1 bar of each new broker
month consumes one attempt. A position receives one frozen
`3.5 * ATR(20,D1)` hard stop and closes at the next month or after forty days.

## Claim Boundary And Adverse Evidence

- The source signal is option-implied; the EA signal is realized and may
  represent materially different information.
- The source ranks a broad cross-section; the EA compares WTI with its own
  preceding state. No paper result supports that time-series map.
- The source's later subperiod evidence is weaker, and its sample ends in
  2015. The QM baseline is a new falsification.
- `QM5_13146_energy-vov`, the paired realized-proxy parent, reached Q07 and
  failed Q08. That is adverse family evidence, not a result to suppress.
- Continuous CFD roll/basis, financing, gaps, fixed-dollar risk, ATR stops,
  costs, trade density, and book correlation are absent from the source.

No return, alpha, Sharpe ratio, drawdown, significance value, WTI-only result,
CFD equivalence, cost result, or portfolio conclusion is imported.

## Non-Duplicate Boundary

- `QM5_13146_energy-vov` ranks concurrent XTI and XNG VoV and trades a paired
  package; it has no preceding WTI block or outright topology.
- `QM5_20236_xauxag-vov-rank` ranks two metals and trades a paired package.
- `QM5_13046_xti-vrp-proxy` uses realized-volatility level as a stretch-fade
  gate; it does not measure instability along rolling realized volatility.
- `QM5_20295_wti-kurt-prem` measures a fourth central return moment around a
  fixed normal benchmark, not nested realized VoV or state change.
- WTI trend, robust-return, calendar, variance-ratio, event, breakout, and
  reversal systems use other information objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is short-horizon, long-only RSI pullback
  logic rather than monthly symmetric uncertainty-premium logic.

The deterministic checker found no exact identity across 4,363 registry rows
and 474 cards. Nine expected lexical/source-family fuzzy matches were manually
resolved. The two exact block offsets, disjoint support, nested denominators,
self-relative direction, single WTI carrier, and monthly attempt are jointly
load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_SOURCE_FAMILY_FUZZY_AND_MANUAL_REVIEW`.

## R1-R4

- R1: PASS with caveats. Tier-A peer-reviewed primary paper, DOI,
  institutional manuscript, complete-read record, exact source transform,
  robustness context, and explicit WTI membership.
- R2: PASS. Fixed nested estimator, two disjoint blocks, direction, consumed
  attempt, fixed risk, hard stop, monthly renewal, and stale guard.
- R3: PASS for the disclosed proxy. Registered `XTIUSD.DWX` D1 closes and
  native framework state suffice; exact implied-VoV replication is impossible.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited
  signal indicator, external runtime feed, grid, martingale, or pyramid.

## Safety Boundary

This extraction authorizes one card, deterministic allocation, non-live V5
build, strict compile/Q01, and one paced fixed-risk Q02 enqueue. It excludes a
manual backtest; live/demo/shadow/stress/optimization artifacts; `T_Live`;
AutoTrading; deploy manifests; portfolio-gate edits; portfolio admission; and
correlation waivers.
