---
source_id: CME-MEHLITZ-XAUXAG-VRSPREAD-2026
title: Gold-silver relative spread with variance-ratio memory state
status: cards_ready
created: 2026-08-06
created_by: Research+Development
source_type: governed_composite
---

# CME-MEHLITZ-XAUXAG-VRSPREAD-2026 — Source Packet

## Approval

- Approval basis: OWNER commodity/energy portfolio mission delivered to Codex
  on 2026-08-06 to select, card, build, and enqueue one new non-duplicate
  structural commodity sleeve.
- Extraction scope: one monthly XAU/XAG two-leg basket (`S01`) whose state is
  the published `R1-q2` short-memory rule applied to synchronized gold-minus-
  silver monthly log returns.
- Review status: the two governed parent packets and their bounded primary
  materials were read completely for this extraction on 2026-08-06. The
  durable G0 boundary is
  `decisions/2026-08-06_qm5_20249_xauxag_vr_spread_g0.md`.

## Canonical Sources

1. Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced momentum
   in commodity futures markets," *The European Journal of Finance* 30(8),
   773-802. DOI: https://doi.org/10.1080/1351847X.2023.2220118.
   The complete open precursor is Mehlitz (2021), *Risk and return of passive
   and active commodity futures strategies*, Chapter 3 pp. 51-74 and Appendix
   C pp. 110-113, CC BY-NC-SA 4.0:
   https://www.researchgate.net/publication/357152829_Risk_and_return_of_passive_and_active_commodity_futures_strategies.
2. CME Group, "Gold & Silver Ratio Spread":
   https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.html.

Governed parents:

- `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`

## Relevant Source Locations

- Mehlitz Chapter 3, Section 3.2 and Table 3.1, pp. 53-54: the commodity
  futures universe explicitly contains gold and silver.
- Section 3.3.1, p. 55: the commodity momentum implementation uses the latest
  completed return without a skip month.
- Section 3.3.2.1, pp. 55-56, equations (3.1)-(3.3): variance ratios aggregate
  return autocorrelations and use the Lo-MacKinlay heteroskedasticity-robust
  standard-normal statistic.
- Section 3.3.2.2, pp. 56-57, equation (3.4): persistent winners are followed,
  persistent losers are shorted, anti-persistent winners are reversed, and
  anti-persistent losers are bought.
- Section 3.3.2.2, p. 57: `q=2` belongs to the one-month ranking rule; the test
  uses 32 monthly observations, a fixed two-sided 10% significance boundary,
  and no position when memory is insignificant.
- CME defines the gold-silver ratio as the per-ounce gold price divided by the
  per-ounce silver price. It describes gold/silver as an intermarket relative-
  value spread created with simultaneous opposing legs and explains that the
  metals share close economic links but retain different monetary, safe-haven,
  industrial, and business-cycle drivers.

## Locked Source Components

For a monthly return sequence `r[0..31]`, in chronological order:

1. Estimate the mean and the full sum of squared deviations `S`.
2. Estimate first-order autocorrelation from adjacent demeaned returns.
3. Set `VR(2) = 1 + rho(1)`.
4. Compute the heteroskedasticity-robust `q=2` standard error and
   `z = (VR(2)-1)/robust_se`.
5. Require `abs(z) > 1.64485362695147`, the fixed two-sided 10% critical value.
6. Use the latest return sign as the base direction. Follow it for significant
   persistence (`z > 0`) and reverse it for significant anti-persistence
   (`z < 0`). Remain flat for insignificant memory, a zero latest return, or
   invalid arithmetic.
7. Hold the decision until the next monthly formation.

The CME component locks only the two-leg gold/silver relative-value carrier:
positive relative direction means long gold and short silver; negative
relative direction means short gold and long silver.

## Bounded QM Mechanization

At each genuine broker-month transition, the candidate reconstructs exactly
33 synchronized completed month-end closes for both `XAUUSD.DWX` and
`XAGUSD.DWX`. It forms 32 relative monthly log returns:

```text
r_rel[t] = ln(XAU[t] / XAU[t-1]) - ln(XAG[t] / XAG[t-1])
```

The locked `R1-q2` statistic and direction matrix are applied to this relative
return sequence. A positive trade direction buys XAU and sells XAG; a negative
direction sells XAU and buys XAG. The pair closes at the next broker-month
transition or after a 35-calendar-day stale limit.

Applying the memory test to the relative series is a transparent QM composite
hypothesis. Mehlitz and Auer test individual commodity returns inside broad
portfolios, not a two-metal spread. CME establishes spread identity and
tradability, not a variance-ratio signal. Neither source tests Darwinex CFDs,
equal fixed-stop-risk halves, ATR hard stops, legging, financing, the chosen
spread caps, or the QM portfolio. No return, profit factor, drawdown, trade
count, hedge ratio, neutrality, or correlation statistic transfers.

## Risk And Allowability Boundary

- Runtime data are completed native MT5 D1 prices, calendar, spread, quotes,
  ATR, contract metadata, positions, and deals only.
- No futures curve, external file/API, volume, open interest, trained model,
  optimizer, banned signal indicator, PnL feedback, grid, or martingale is
  allowed.
- One `RISK_FIXED=1000` package budget is split equally by per-leg hard-stop
  risk. Opposite legs do not prove dollar, beta, volatility, factor, or
  portfolio neutrality.
- The continuous-CFD/futures basis, synchronized-history availability,
  significance-gate density, legging, stops, financing, and narrow two-name
  carrier are falsification risks owned by Q02 and later unchanged gates.

## Non-Duplicate Review

The deterministic pre-allocation command scanned 4,306 EA-registry rows and
423 canonical cards for slug `xauxag-vr-spread`, strategy ID
`CME-MEHLITZ-XAUXAG-VRSPREAD-2026_S01`, authors, and the complete mechanic. It
reported no exact or fuzzy match.

Manual review separates the hypothesis from:

- `QM5_12577`, fixed-beta rolling log-ratio z-score reversion;
- `QM5_12724`, fixed-beta ratio channel continuation;
- `QM5_12862`, fixed-beta D1 return-spread z-score reversion;
- `QM5_20161` and `QM5_13205`, OLS-residual and conditional-quantile
  disequilibrium baskets;
- `QM5_20194`, a synchronized 12/18-month rank-disagreement basket;
- `QM5_20234`-`QM5_20236`, realized jump, expected-shortfall, and
  volatility-of-volatility cross-sectional ranks; and
- `QM5_13134`, the source-method WTI single-carrier variance-ratio strategy.

No existing XAU/XAG build uses a 32-month relative-return `q=2` robust memory
test, fixed significance boundary, and persistence-follow / anti-persistence-
reverse matrix. Verdict: `CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

