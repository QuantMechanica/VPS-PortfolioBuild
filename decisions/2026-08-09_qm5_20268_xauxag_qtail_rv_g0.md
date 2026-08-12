# QM5_20268 XAU/XAG Quantile-Tail Reversion G0 Authorization

Date: 2026-08-09

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20268_xauxag-qtail-rv`. The candidate observes synchronized completed D1
gold/silver log ratios and opens one opposite-leg reversion package only when
a central observation is followed by two consecutive closes beyond the same
frozen empirical outer-decile boundary.

The candidate may proceed through source/card lint, deterministic registry and
magic allocation, resolver regeneration, strict compile, one `RISK_FIXED`
logical-basket backtest setfile, Q01 validation, and one paced Q02 enqueue.
This authorization does not pre-approve efficacy, neutrality, diversification,
decorrelation, certification, execution-contract promotion, or portfolio
admission.

## Source Boundary

The approved source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-QTAIL-2026/source.md`, bounded by
two already complete durable parent packets:

- `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
  Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, and Yaya, Vo, Olayinka (2021),
  *Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group's
  gold/silver ratio-spread material.

The sources support testing a state-dependent gold/silver long-run relation
and treating the carrier as one intermarket relative-value package. They do
not prescribe empirical deciles, a 126-observation window, a two-close tail
event, Darwinex CFD translation, equal stop-risk allocation, ATR stops, or
lifecycle controls. Those are transparent QM hypotheses. No source return,
trade density, CFD equivalence, neutrality, or correlation result transfers.
No newly retrieved public source is used.

## Locked Rule

On each new `XAUUSD.DWX` D1 host bar, align exactly 129 completed
`XAUUSD.DWX` and `XAGUSD.DWX` timestamps and define
`r[k] = ln(XAU_close[k]) - ln(XAG_close[k])`, where shift 1 is newest.
Sort only the 126 pre-event ratios at shifts 4 through 129. With zero-based
ascending indexes, lock:

```text
q10 = sorted[12]                         # nearest-rank ceil(0.10*126)
q50 = (sorted[62] + sorted[63]) / 2     # even-sample median
q90 = sorted[113]                        # nearest-rank ceil(0.90*126)
```

Require positive finite prices, exact timestamp alignment, finite ratios,
and `q10 < q50 < q90`. The three event observations never enter the frozen
reference distribution.

- Upside tail: `q10 <= r[3] <= q90`, then `r[2] > q90` and `r[1] > q90`.
  SELL XAU and BUY XAG.
- Downside tail: `q10 <= r[3] <= q90`, then `r[2] < q10` and `r[1] < q10`.
  BUY XAU and SELL XAG.
- Otherwise remain flat.

Consume the newest decision bar before spread, quote, ATR, sizing, or order
gates. Maintain exactly zero or two opposite legs. Split one aggregate
`RISK_FIXED=1000` stop-risk budget equally after independent frozen
`3.5*ATR(20,D1)` normalization. No take-profit or scale-in is authorized.

For an open package, compute the median of the newest twenty-one synchronized
completed log ratios. Close a short-ratio package when the newest ratio is at
or below that rolling median; close a long-ratio package when it is at or above
the median. Also close on invalid package/state or after thirty-five calendar
days. Friday close is disabled; broker hard stops and the framework kill
switch remain binding.

## Non-Duplicate Decision

The canonical pre-allocation command returned `VERDICT: CLEAN` across 4,325
EA-registry rows and 441 cards for slug `xauxag-qtail-rv`, strategy ID
`SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03`, and the declared mechanic. Manual
review distinguishes the closest XAU/XAG families:

- `QM5_12577` and `QM5_20157` fade mean/standard-deviation ratio extremes;
- `QM5_20161` fades a rolling OLS log-price residual;
- `QM5_13205` solves monthly conditional 10/50/90 quantile regressions and
  trades a weekly conditional envelope with beta-notional sizing;
- `QM5_20263` uses separate rolling median/MAD scores and a fresh score cross;
- `QM5_12724` follows a current ratio-channel breakout; and
- `QM5_20265` waits for an outside channel break to return inside, then fades.

This rule uses no location/scale score, fitted hedge ratio, regression loss,
channel maximum, or re-entry. The frozen 126-value empirical distribution,
exact nearest-rank deciles, excluded three-bar event, central-to-two-tail
sequence, immediate inverse package, and rolling 21-ratio median exit are
jointly load-bearing. Verdict: `CLEAN_DISTRIBUTION_FREE_TWO_HIT_TAIL_EVENT`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20268`, subject to deterministic registry allocation;
- slug: `xauxag-qtail-rv`;
- strategy ID: `SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03`;
- intended slots: `XAUUSD.DWX` / 0 / `202680000` and `XAGUSD.DWX` / 1 /
  `202680001`;
- logical basket: `QM5_20268_XAU_XAG_QTAILRV_D1`;
- expected cadence: five to twelve completed packages per full post-warm-up
  year; Q02 owns realized density and economics;
- retire below five completed packages per year, on nonpositive governed
  economics, or later portfolio-correlation rejection;
- fail on timestamp mismatch, event contamination of the reference sample,
  wrong order-statistic indexes, a one-hit entry, wrong sides, repeat-bar
  entry, unpaired exposure, aggregate-risk breach, missing stop, or
  nondeterminism;
- no post-result lookback, quantile, event, side, exit median, stop, hold,
  retry, or carrier rescue is authorized.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one logical XAU/XAG D1 setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
