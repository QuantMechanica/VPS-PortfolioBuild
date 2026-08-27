---
source_id: YAYA-CME-XAUXAG-FRACD-RV-2026
title: XAU/XAG fixed fractional-difference ratio reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xauxag_fractional_difference_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xauxag-fracd-rv
---

# XAU/XAG Fixed Fractional-Difference Ratio Reversion Source Packet

## Approved Source Of Record

The peer-reviewed relationship packet is
`strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`. It records:

- Karsten Schweikert (2018), “Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions,” *Journal of Banking & Finance*
  88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`; and
- OlaOluwa S. Yaya, Xuan Vinh Vo, and Hammed A. Olayinka (2021), “Gold and
  silver prices, their stocks and market fear gauges: Testing fractional
  cointegration using a robust approach,” *Resources Policy* 72, 102045, DOI
  `10.1016/j.resourpol.2021.102045`.

The first source supports a related but state-dependent gold/silver relation
and warns that one constant cointegrating vector can fail. The second reports
fractional-cointegration evidence for gold and silver prices. Neither source
publishes this trading rule, a fixed fractional-difference order, or a CFD
backtest.

The carrier packet is
`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME defines the
gold/silver ratio as gold price divided by silver price, presents the pair as
an intermarket spread, and identifies shared precious-metal drivers alongside
gold's stronger monetary/safe-haven demand and silver's stronger industrial-
cycle demand.

Both parent packets were read completely before source approval. Their exact
hashes, the current OWNER authority, and the clean preallocation receipt are
bound in
`decisions/2026-08-27_xauxag_fractional_difference_reversion_source_approval.md`,
committed before this extraction at `17d4b7b12`.

## Claim Boundary

The evidence supports testing a persistent, state-dependent intermetal
relationship and identifies a traded ratio carrier. It does not establish
that applying `(1-L)^0.40` to Darwinex daily CFD log ratios produces a
stationary series, that a 64-term truncation is correct, that a held-out
z-score predicts next-month reversion, or that opposite CFD legs are neutral.

The fixed order, coefficient recurrence, truncation, 316-pair history,
252-output baseline, `0.50` threshold, monthly cadence, equal-target-notional
construction, ATR stops, spread caps, atomic ordering, and lifecycle are
pre-result QM translations. No source alpha, return, Sharpe ratio, memory
estimate, p-value, coefficient, density, drawdown, cost, CFD equivalence,
neutrality, decorrelation, or portfolio statistic transfers.

## Bounded QM Mechanization

On the first eligible synchronized D1 tick of a genuine new broker month,
load exactly 316 completed timestamp-matched close pairs, oldest to newest:

```text
s[t] = ln(XAUUSD.DWX_close[t]) - ln(XAGUSD.DWX_close[t])

d = 0.40
K = 64
w[0] = 1
w[k] = w[k-1] * (k - 1 - d) / k, k = 1..63

fd[t] = sum(k=0..63, w[k] * s[t-k])
```

Exactly 253 filtered outputs exist from the 316 inputs. The first 252 are a
baseline; the latest output is held out:

```text
mu = sum(fd[0..251]) / 252
sd = sqrt(sum((fd[i]-mu)^2, i=0..251) / 251)
z = (fd[252] - mu) / sd

z >= +0.50 => SELL XAU, BUY XAG
z <= -0.50 => BUY XAU, SELL XAG
otherwise  => FLAT
```

The recurrence implements a fixed finite approximation to `(1-L)^d`; neither
`d`, `K`, the center, nor the threshold is fitted to an outcome. The held-out
latest output never enters its own baseline center or scale. The inclusive
threshold is fixed before Q02. Signal magnitude does not scale risk.

## Exact Event And Data Contract

1. Require exact `XAUUSD.DWX` host, exact `XAGUSD.DWX` companion, D1, and an
   entry attempt no later than 180 elapsed minutes after the raw first host
   D1 bar open of a genuine new broker month.
2. Persist current decision `yyyymm` before history, news, spread, quote,
   ATR, sizing, margin, or order gates. A rejection, stop, restart, or partial
   package failure may not retry that month.
3. Copy both D1 series in a bounded buffer, then exact-join 316 completed pairs
   by timestamp. Require positive finite closes, strictly increasing joined
   times, exact newest timestamps on both legs, and a latest endpoint no more
   than ten calendar days old.
4. Require all 64 recurrence weights and all 316 ratios to be finite. Require
   exactly 253 finite filter outputs, a finite baseline mean, a finite
   positive sample standard deviation, and a finite held-out z-score.
5. Fade the inclusive threshold with opposite equal-target-notional legs.
   A sub-threshold or invalid state consumes the month flat.
6. Use one aggregate `RISK_FIXED=1000`, split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, cap XAU/XAG entry spreads at 1,500/500 points,
   and reject more than 20 percent rounded target-notional mismatch.
7. Submit XAU first and XAG second. Retain only one valid stopped position per
   registered slot in the required opposite directions. Close all owned legs
   immediately after any submission or final-composition failure.
8. Close the package at the first tick in the next broker month or after forty
   calendar days. Immediately repair an orphan, duplicate, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime reads no
external file, futures chain, API, paper estimate, optimizer output, trained
artifact, prior backtest result, portfolio state, or live manifest.

## Non-Duplicate Boundary

The canonical checker returned CLEAN across 4,684 registry identities, 1,335
cards, and 45 Strategy Wiki nodes. The receipt is
`artifacts/qm5_xauxag_fracd_rv_preallocation_dedup_20260827.json`.

- raw ratio z-score (`QM5_20157`) does not apply the fixed fractional filter;
- rolling OLS (`QM5_20161`) fits a hedge relation from each rolling window;
- annual CADF/OU (`QM5_21526`) fits and gates a frozen annual model;
- threshold cointegration (`QM5_20012`) uses a published monthly error term;
- return-spread, stochastic, quantile, channel, seasonal, rank, sign, robust-
  location, daily-path, and calendar baskets transform different state.

The exact carrier, 316 synchronized closes, fixed `d=0.40`, 64-term recurrence,
253 outputs, 252-output held-out baseline, inclusive `abs(z)>=0.50` fade,
consumed month, opposite equal-notional package, fixed aggregate risk, and
next-month lifecycle are jointly load bearing. Verdict:
`CLEAN_XAUXAG_FIXED_D040_K64_HELDOUT252_FRACTIONAL_DIFFERENCE_REVERSION`.

## Reputable-Source Criteria

- R1: `PASS_WITH_FIXED_FRACDIFF_TRANSLATION_RISK`. Named peer-reviewed
  gold/silver relationship evidence includes fractional cointegration; CME
  supplies official carrier context. The exact conjunction is untested.
- R2: `PASS`. Clock, history count, exact join, recurrence, order,
  truncation, held-out baseline, variance formula, threshold, sides, attempt,
  risk, atomicity, and lifecycle are fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered native XAU
  and XAG D1 histories and MT5-native execution state supply every input.
- R4: `PASS`. Fixed deterministic arithmetic only, without fitted memory,
  trained output, ML, banned indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Density, Kill, And Safety Boundary

Under a standard-normal reference, the inclusive `abs(z)>=0.50` boundary has
two-tail probability about `0.617`, or approximately 7.4 opportunities over
twelve monthly decisions. This is only a transparent pre-market density
prior. Q02 must retire below five completed packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any history,
filter, baseline, side, attempt, risk, package, lifecycle, or determinism
defect. No failure may be rescued by changing a load-bearing rule.

Opposite equal-target-notional legs do not prove dollar, beta, volatility,
factor, market, or portfolio neutrality. Unchanged Q09 alone owns realized
correlation. This packet supports one approved card, one branch-only build,
strict Q01, and one paced non-live logical Q02 enqueue only. It excludes a
manual backtest, live/demo/shadow/stress/optimization preset, `T_Live`,
AutoTrading, deployment, live manifests, portfolio-gate mutation, portfolio
admission, correlation waiver, terminal control, and component-leg Q02 rows.
