# QM5_20270 WTI Trimmed-Mean Momentum G0 Authorization

Date: 2026-08-10

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20270_wti-trimmean-mom`. The candidate observes twelve disjoint completed
broker-month WTI log returns, removes the two smallest and two largest returns,
and holds one outright `XTIUSD.DWX` position in the direction of the remaining
eight-return arithmetic mean until the next broker-month boundary.

The candidate may proceed through source/card lint, deterministic registry and
magic allocation, resolver regeneration, strict compile, one `RISK_FIXED`
backtest setfile, Q01 validation, and one paced Q02 enqueue. This authorization
does not pre-approve efficacy, diversification, decorrelation, certification,
execution-contract promotion, or portfolio admission.

## Source Boundary

The approved source of record is the already complete governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz, Ooi, and
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its durable retrieval
receipt records an end-to-end read of the 23-page published paper, the author-
hosted route, page count, byte count, and PDF SHA-256.

The source supports testing monthly own-return direction in WTI over the first
twelve monthly lags. It does not prescribe a trimmed-mean estimator, a
standalone continuous CFD port, fixed-dollar sizing, ATR stop, spread ceiling,
restart ledger, or lifecycle controls. Those are transparent QM hypotheses.
No source return, WTI-specific alpha, trade density, CFD equivalence,
correlation result, or portfolio conclusion transfers.

No newly retrieved public source is used. The bounded child extraction will be
recorded at `strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md` only after
this durable approval exists.

## Locked Rule

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct exactly thirteen consecutive completed broker-month-
end closes `C[0]..C[12]`, oldest to newest. The newest endpoint must belong to
the month immediately before the decision month. Define twelve disjoint log
returns:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
```

Require positive finite closes, consecutive completed months, strictly
increasing endpoint timestamps, finite returns, and no endpoint from the
current broker month. Sort a copy of the twelve returns ascending, discard
exactly indexes `0`, `1`, `10`, and `11`, and lock the middle-eight mean:

```text
trimmed_sum = sum(sorted[i], i = 2..9)
trimmed_mean = trimmed_sum / 8
```

- `trimmed_mean > 0`: BUY WTI.
- `trimmed_mean < 0`: SELL WTI.
- exact zero or invalid state: consume the month flat.

The trimmed-mean magnitude never scales risk. Consume and persist the decision
month before history, signal, spread, quote, ATR, sizing, news, or order gates.
Close the prior package at the next month boundary before considering
replacement risk. Use exactly one `RISK_FIXED=1000` stop-risk budget, one
frozen `3.5 * ATR(20,D1)` broker hard stop, a 1,500-point entry spread ceiling,
no take-profit, and a forty-calendar-day stale exit. Friday close and both news
axes are disabled for the full-month native-price package. The framework kill
switch remains binding.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,327 EA-registry rows and 443
cards for slug `wti-trimmean-mom`, strategy ID
`MOP-TSMOM-2012_XTI_TRIM12_S19`, and the declared mechanic. It found no exact
or fuzzy identity.

Manual review distinguishes the closest WTI systems:

- pure one-, two-, three-, six-, nine-, and twelve-month TSMOM uses one
  cumulative endpoint return rather than a trimmed distribution of twelve
  disjoint returns;
- dual-horizon and one/three/twelve vote systems compare cumulative horizons;
- `QM5_13150` and `QM5_20244` count binary monthly signs, with the latter also
  requiring cumulative-return concordance;
- `QM5_20264` uses all pairwise month-end price orderings and an integer
  Mann-Kendall boundary;
- `QM5_20261` fits log-price OLS slope and gates on `R^2`; and
- `QM5_20269` uses only the two central order statistics, while this rule
  retains and equally weights the middle eight returns after fixed tail
  deletion.

This rule sorts twelve non-overlapping monthly returns, deletes exactly two
observations from each tail, averages indexes 2 through 9, and maps that robust
central-distribution estimate symmetrically long/short. It has no cumulative-
return, sign-count, pairwise-rank, regression, oscillator, calendar-direction,
event, or external-data fallback. Verdict:
`CLEAN_ROBUST_MONTHLY_RETURN_TRIMMED_MEAN`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20270`, subject to deterministic registry allocation;
- slug: `wti-trimmean-mom`;
- strategy ID: `MOP-TSMOM-2012_XTI_TRIM12_S19`;
- intended slot: `XTIUSD.DWX` / 0 / magic `202700000`;
- expected cadence: approximately twelve completed monthly packages per full
  post-warm-up year; Q02 owns realized density and economics;
- retire below five completed packages per full post-warm-up year, on
  nonpositive governed economics, or later portfolio-correlation rejection;
- fail on endpoint leakage or nonconsecutiveness, overlapping returns, wrong
  sort, wrong tail deletion or divisor, wrong direction, repeated monthly
  attempt, missing hard stop, risk-mode mismatch, hold beyond forty days, or
  nondeterminism;
- no post-result return window, trim definition, side, stop, hold, spread,
  retry, or carrier rescue is authorized.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. If the paced farm reaches its
binding backtest CPU ceiling before enqueue, record the stop and do not enqueue
or run a manual test.
