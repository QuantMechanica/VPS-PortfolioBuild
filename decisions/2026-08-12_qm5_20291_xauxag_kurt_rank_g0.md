# QM5_20291 XAU/XAG Historical-Kurtosis Rank G0 Authorization

Date: 2026-08-12

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded carrier extension, V5 Strategy Card, non-live build,
strict compile/Q01 validation, and one paced Q02 enqueue for
`QM5_20291_xauxag-kurt-rk`.

On the first processed `XAUUSD.DWX` D1 bar of each broker month, calculate
Pearson historical kurtosis from exactly 252 completed simple daily returns
for XAU and XAG. Buy the higher-kurtosis metal, short the lower-kurtosis
metal, split one fixed-risk package equally between the legs, and close the
package at the next broker-month transition. A numerical tie or invalid
formation consumes the month without a trade.

This authorization does not pre-approve efficacy, decorrelation,
certification, execution-contract promotion, portfolio admission, or a
correlation waiver.

## Source Boundary

The approved source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed parent packet
`strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md` records a complete read
of the 57-page accepted article and online appendix. Its content is bound by
SHA-256
`66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47`.

The paper ranks a broad commodity-futures cross-section monthly. It reports a
positive full-sample high-minus-low historical-kurtosis result, but the
two-portfolio result is insignificant and the post-financialization result
reverses sign and is insignificant. The XAU/XAG two-CFD carrier is therefore
a deliberately low-prior falsification, not a replication or inherited
return claim.

## Locked Statistical Rule

For each metal, form exactly 252 simple returns from 253 completed D1 closes:

```text
r[d] = close[d] / close[d-1] - 1
mu = sum(r[d]) / 252
sample_variance = sum((r[d] - mu)^2) / 251
fourth_moment = sum((r[d] - mu)^4) / 252
kurtosis = fourth_moment / sample_variance^2
```

Require strictly increasing completed history, a fresh last endpoint,
positive finite closes, finite arithmetic, positive sample variance, and
positive finite kurtosis for both legs. If `kurtosis_XAU > kurtosis_XAG`, buy
XAU and sell XAG. If lower, sell XAU and buy XAG. Treat an absolute
difference at or below `1e-12` as flat. Do not use excess kurtosis, bias
correction, logarithmic returns, winsorization, a fitted threshold, score
sizing, a price ratio, or a fallback signal.

Each leg receives half of `RISK_FIXED=1000` stop risk and a frozen
`3.5 * ATR(20,D1)` hard stop. Friday close and both news axes are OFF in the
Q02 baseline. Close and renew at the next month boundary, close after forty
calendar days, repair orphans immediately, and persist the monthly attempt
before history or order gates so no failure or stop can retry that month.

## Reputable-Source Criteria

- R1: PASS. Peer-reviewed QJF article, DOI, institutional accepted
  manuscript, complete-read repository record, and explicit distributional
  characteristic. Weak and unstable source results are retained as kill
  risks.
- R2: PASS. Return count, denominators, Pearson formula, rank direction,
  cadence, attempt, aggregate risk, stops, renewal, stale close, and orphan
  repair are fixed.
- R3: PASS. Registered XAU/XAG `.DWX` D1 histories and native framework state
  provide every runtime input.
- R4: PASS. Deterministic price arithmetic and ATR safety stops only; no
  trained output, prohibited signal indicator, external feed, grid,
  martingale, scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical checker found no exact slug or strategy-ID identity and five
lexical fuzzy neighbors. Manual review resolves them:

- `QM5_13131_energy-kurt-rank` uses the same locked characteristic on XTI/XNG.
  This authorization is a new XAU/XAG carrier test; no estimator, direction,
  or result is tuned from the sibling.
- `QM5_20233_xauxag-skew-rank` measures a third standardized moment and buys
  lower skew. This rule measures the fourth standardized moment and buys
  higher kurtosis.
- `QM5_20234_xauxag-rsj` uses one month of signed semivariance;
  `QM5_20235_xauxag-es-rank` uses the worst return tail; and
  `QM5_20236_xauxag-vov-rank` measures dispersion across rolling volatility.
- XAU/XAG ratio, OLS-residual, quantile, return-shock, momentum, calendar,
  variance-ratio, and idiosyncratic-volatility baskets use different state
  variables or transforms.
- `QM5_1212`, `QM5_1221`, and `QM5_10322` combine kurtosis with other daily or
  weekly signals; none is a pure monthly two-metal historical-kurtosis rank.

The exact 252 simple returns, source denominators, Pearson fourth moment,
high-minus-low direction, XAU/XAG carrier, monthly package, equal risk halves,
and consumed-attempt lifecycle are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20291`, subject to deterministic allocation;
- strategy ID: `HOLLSTEIN-MAX-2021_XAU_XAG_S03`;
- intended symbols/slots/magics: XAU/0/`202910000`, XAG/1/`202910001`;
- retire below five completed packages per full post-warm-up year, on
  nonpositive governed economics, or on downstream portfolio-correlation
  rejection; and
- do not rescue failure by changing the estimator, denominators, direction,
  carrier, formation, threshold, cadence, stop, hold, or retry policy.

## Safety Boundary

Only one `RISK_FIXED` backtest setfile is authorized. Manual backtests, live,
demo, shadow, stress, optimization, `T_Live`, AutoTrading, deploy manifests,
T_Live manifests, portfolio-gate edits, and portfolio admission are excluded.
If the paced farm reaches its CPU ceiling before enqueue, record the stop and
do not enqueue or run a manual test.

