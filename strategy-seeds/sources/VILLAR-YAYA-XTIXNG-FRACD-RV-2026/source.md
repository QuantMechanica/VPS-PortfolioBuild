---
source_id: VILLAR-YAYA-XTIXNG-FRACD-RV-2026
title: XTI/XNG fixed fractional-difference ratio reversion extraction
publisher: QuantMechanica governed extraction of government, peer-reviewed, and governed method research
source_type: government_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-29_xtixng_fractional_difference_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - YAYA-CME-XAUXAG-FRACD-RV-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  YAYA-CME-XAUXAG-FRACD-RV-2026: CEC08E0FB0C040227A52053A7051F64CF5D530B2D68C67B8DD87851970B7E4DE
created: 2026-08-29
created_by: Research+Development
cards_extracted:
  - xtixng-fracd-rv
---

# XTI/XNG Fixed Fractional-Difference Ratio Reversion Source Packet

## Approval And Complete-Read Boundary

The durable source approval is
`decisions/2026-08-29_xtixng_fractional_difference_reversion_source_approval.md`,
committed as `77d16d8a1` before this extraction. The exact complete-read
parent hashes, byte counts, line counts, and roles are preserved in
`artifacts/qm5_xtixng_fracd_rv_source_provenance_20260829.json`.

The oil/gas relationship source is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It records
complete reads of Jose A. Villar and Frederick L. Joutz (2006), *The
Relationship Between Crude Oil and Natural Gas Prices*, a 43-page U.S. Energy
Information Administration report, and David J. Ramberg and John E. Parsons
(2012), *The Weak Tie Between Natural Gas and Oil Prices*, *The Energy
Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`.

The fixed-filter arithmetic and atomic-basket precedent is
`strategy-seeds/sources/YAYA-CME-XAUXAG-FRACD-RV-2026/source.md`. Its named
peer-reviewed parents concern gold/silver fractional cointegration, not
oil/gas. Only its already governed finite recurrence, held-out
standardization, consumed-month state, equal-target-notional aggregate risk,
atomic repair, and monthly renewal mechanics transfer.

Both parent packets were read completely before source approval. No new
public route, blocked content, source table, performance result, or external
runtime series is used.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons support a physical and economic connection
between crude oil and natural gas through substitution, co-production,
drilling, finance, transport, and LNG. Their adverse evidence is equally
binding: gas retains large idiosyncratic variation, the relationship changes
across regimes, regional gas fundamentals matter, and no permanently fixed
oil/gas ratio is justified.

Those findings support a falsifiable oil/gas relative-value experiment, not
a constant equilibrium, hedge coefficient, convergence speed, or profitable
contrarian rule. The method packet fixes arithmetic only. Its gold/silver
fractional-cointegration evidence does not transfer, and no source tests a
fixed fractionally differenced oil-minus-gas log-ratio as a next-month
predictor.

The synchronized CFD history, fixed `d=0.40`, 64-term truncation, 316-pair
input, held-out standardized output, inclusive `0.50` threshold, contrarian
direction, fixed cash risk, ATR stops, spread caps, atomic lifecycle, and
monthly renewal are transparent QM translations. No source return, alpha,
memory estimate, coefficient, probability, density, Sharpe ratio, drawdown,
cost, hedge ratio, neutrality, CFD equivalence, or portfolio-correlation
statistic transfers.

## Bounded QM Mechanization

On the first eligible synchronized D1 tick of a genuine new broker month,
load exactly 316 completed timestamp-matched XTI/XNG close pairs, oldest to
newest:

```text
s[t] = ln(XTIUSD.DWX_close[t]) - ln(XNGUSD.DWX_close[t])

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

z >= +0.50 => SELL XTI, BUY XNG
z <= -0.50 => BUY XTI, SELL XNG
otherwise  => FLAT
```

The recurrence implements a fixed finite approximation to `(1-L)^d`;
neither `d`, `K`, the center, scale, nor threshold is fitted to an outcome.
The held-out latest output never enters its own baseline center or scale.
Signal magnitude does not scale risk.

## Exact Event Contract

1. Require exact `XTIUSD.DWX` host, exact `XNGUSD.DWX` companion, D1, and an
   entry attempt no later than 180 elapsed minutes after the raw first host
   D1 bar open of a genuine new broker month.
2. Persist current decision `yyyymm` before history, news, spread, quote,
   ATR, sizing, margin, or order gates. A rejection, stop, restart, or partial
   package failure may not retry that month.
3. Copy both D1 series in a bounded 700-bar buffer and exact-join 316
   completed pairs by timestamp. Require positive finite closes, strictly
   increasing joined times, exact newest timestamps on both legs, and a
   latest endpoint no more than ten calendar days old.
4. Require all 64 recurrence weights and all 316 log ratios to be finite.
   Require exactly 253 finite filter outputs, a finite baseline mean, a
   finite positive sample standard deviation above `1e-12`, and a finite
   held-out z-score.
5. Fade the inclusive threshold with opposite equal-target-notional legs. A
   sub-threshold or invalid state consumes the month flat.
6. Use one aggregate `RISK_FIXED=1000`, split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, cap XTI/XNG entry spreads at 1,500/3,000
   points, and reject more than 20% rounded target-notional mismatch.
7. Submit XTI first and XNG second. Retain only one valid stopped position per
   registered slot in the required opposite directions. Close all owned legs
   immediately after any submission or final-composition failure.
8. Close the package at the first tick in the next broker month or after
   forty calendar days. Immediately repair an orphan, duplicate, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime reads no
external file, futures chain, API, paper estimate, optimizer output, trained
artifact, prior backtest result, portfolio state, or live manifest.

## Non-Duplicate Functional Boundary

The canonical checker returned `CLEAN` across 4,692 registry identities,
1,343 cards, and 45 Strategy Wiki nodes. The receipt is
`artifacts/qm5_xtixng_fracd_rv_preallocation_dedup_20260829.json`.

Manual semantic review fixes a new mechanic:

- `QM5_41185_xauxag-fracd-rv` uses the same arithmetic family and monthly
  lifecycle on a precious-metal path. This extraction owns an economically
  distinct oil/gas path, adverse weak-tie evidence, energy contract metadata,
  and XTI/XNG spread ceilings.
- `QM5_41192_xtixng-mdaily-hl-rv` summarizes 17-23 adjacent daily relative
  returns from one completed month using all inclusive pairwise averages.
  This extraction filters 316 ratio levels with 64 fixed coefficients and
  standardizes one held-out filtered output against 252 predecessors.
- `QM5_20237_xtixng-ecm-rv` fits a rolling intercept, oil beta, and time trend
  and trades residual crossings. This extraction fits no hedge coefficient,
  time trend, memory order, threshold, or convergence speed.
- Raw ratio, fixed ratio, return-spread, OLS, robust-slope, rank,
  change-point, calendar, and weekday cards consume different states and
  clocks.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback.

The exact carrier, 316 synchronized closes, fixed `d=0.40`, 64-term
recurrence, 253 outputs, 252-output held-out baseline, sample denominator
251, inclusive `abs(z)>=0.50` fade, consumed month, opposite equal-notional
package, fixed aggregate risk, and next-month lifecycle are jointly load
bearing. Verdict:
`CLEAN_XTIXNG_FIXED_D040_K64_HELDOUT252_FRACTIONAL_DIFFERENCE_REVERSION`.

## Reputable-Source Criteria

- R1: `PASS_WITH_FIXED_FRACDIFF_CROSS_CARRIER_TRANSLATION_RISK`. The lineage
  preserves complete U.S. government and peer-reviewed oil/gas evidence with
  binding instability findings plus a complete governed peer-reviewed method
  precedent. Fractional oil/gas integration and the exact trading conjunction
  remain untested.
- R2: `PASS`. Clock, synchronization, history count, recurrence, order,
  truncation, held-out baseline, variance formula, threshold, sides, attempt,
  aggregate risk, stops, atomicity, spread gates, and lifecycle are fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered native XTI
  and XNG D1 histories and MT5-native state supply every runtime input.
- R4: `PASS`. Fixed deterministic arithmetic only, without fitted memory,
  trained output, ML, banned signal, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Claim And Kill Boundary

Under a standard-normal reference, the inclusive `abs(z)>=0.50` boundary has
a two-tail probability near 0.617, or approximately 7.4 opportunities over
twelve monthly decisions. This is only a transparent pre-market density
prior. Q02 must retire below five completed packages in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any history,
filter, baseline, side, attempt, risk, package, lifecycle, or determinism
defect. No failure may be rescued by changing a load-bearing rule.

The opposite equal-notional legs are economically different from the
certified directional XAU, SP500, NDX, and XNG carriers but do not prove
dollar, beta, volatility, factor, market, or portfolio neutrality. Q09 alone
owns the realized portfolio result.

## Safety Boundary

This packet supports one Strategy Card, one branch-only V5 build, strict
compile/Q01, and one paced non-live logical Q02 handoff only. It does not
authorize a manual backtest, live artifact, `T_Live`, AutoTrading, deploy
manifest, portfolio-gate change, portfolio admission, correlation waiver,
terminal control, or component-leg Q02 row.
