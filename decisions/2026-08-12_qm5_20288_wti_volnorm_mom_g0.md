# QM5_20288 WTI Volatility-Normalized Monthly Trend G0 Authorization

Date: 2026-08-12

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20288_wti-volnorm-mom`. At each genuine broker-month transition, the
candidate reconstructs twelve completed WTI monthly log returns, divides each
return by the realized L2 norm of the completed daily log-return path inside
that same month, and trades the sign of the equal-weight mean of those twelve
normalized monthly states. It renews one outright `XTIUSD.DWX` package monthly.

The candidate may proceed through bounded source/card extraction, schema and
G0 lint, deterministic registry and magic allocation, resolver regeneration,
strict compile, one `RISK_FIXED` backtest setfile, Q01 validation, and one paced
Q02 enqueue. This authorization does not pre-approve efficacy,
diversification, decorrelation, certification, execution-contract promotion,
or portfolio admission.

## Source Boundary

The approved trading source of record is the complete governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz, Ooi,
and Pedersen (2012), "Time Series Momentum," *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its
retrieval receipt records an end-to-end read of the 23-page published paper,
the author-hosted route, byte and page counts, and PDF SHA-256. The paper
reports positive own-return continuation across the first twelve monthly lags,
defines monthly own-return-sign positions, uses ex-ante volatility scaling,
and includes NYMEX WTI crude in its commodity universe.

The within-month realized-L2 normalization below is a transparent QM
mechanization, not a source-authored signal or an imported performance claim.
The paper does not normalize each historical monthly return by its own
realized daily path, average twelve such normalized states, use a Darwinex
continuous CFD, reconstruct broker months, size fixed-dollar risk, attach an
ATR stop, cap spread, persist an attempt ledger, or prescribe the lifecycle
controls below. No source return, WTI-specific alpha, density, CFD equivalence,
correlation result, or portfolio conclusion transfers.

## Locked Rule

On the first processed `XTIUSD.DWX` D1 bar after a genuine broker-month
transition, reconstruct exactly thirteen consecutive completed broker-month
closes `C[0]..C[12]`, oldest to newest. For each interval `m=0..11`, retain
every completed D1 close-to-close log return whose left endpoint is at or after
`C[m]` and whose right endpoint is at or before `C[m+1]`. Define:

```text
d[m,j] = ln(P[m,j+1] / P[m,j])
r[m]   = sum_j d[m,j] = ln(C[m+1] / C[m])
v[m]   = sqrt(sum_j d[m,j]^2)
u[m]   = r[m] / v[m]
score  = (u[0] + ... + u[11]) / 12

signal = BUY  when score > 0
         SELL when score < 0
         FLAT when score == 0 or any state is invalid
```

Each interval must contain at least fifteen and at most twenty-five daily
returns. Every endpoint and return must be finite, all prices must be positive,
`v[m]` must be strictly positive, and the direct endpoint return must agree
with the daily-return sum within `1e-10`. Daily returns may appear in exactly
one interval. No demeaning, annualization, clipping, winsorization, sign vote,
threshold, magnitude-based risk scaling, or fallback statistic is allowed.

The position is opened with one fixed `RISK_FIXED=1000` budget and a frozen
`3.5 * ATR(20,D1)` hard stop, without take-profit. Close the prior package on
the first processed D1 bar of the next broker month before considering a new
entry. A forty-calendar-day stale guard closes a missed rollover. Persist the
current month as consumed before history, signal, spread, quote, news, sizing,
or order checks; no failed or flat attempt retries within the month. Friday
close and both news axes are OFF. At most one position exists for the magic.

## Reputable-Source Criteria

- R1: PASS. Exactly one canonical source lineage, backed by named authors, a
  peer-reviewed trading paper, DOI, author-hosted complete paper, durable
  retrieval hash, complete read, and explicit WTI membership.
- R2: PASS. Month endpoints, daily-return inclusion, interval count, minimum
  and maximum observations, L2 denominator, no-demean rule, endpoint identity,
  equal-month mean, direction, attempt, risk, stop, rollover, and stale exit
  are exact.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every input.
- R4: PASS. Deterministic logarithm, addition, multiplication, division, and
  square root only; no trained output, prohibited signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,353 EA-registry rows and 465
root cards. It found no exact identity and no fuzzy match above threshold.
Manual family review resolves the closest structural neighbors:

- `QM5_20274_wti-path-eff` divides one twelve-month signed return by the L1
  sum of twelve monthly absolute returns and applies a fixed threshold. This
  candidate normalizes each month separately by its own daily L2 path and then
  gives every completed month equal weight, with no threshold.
- `QM5_20245`, `QM5_20253`, `QM5_20256`, and `QM5_20257` use Lo-MacKinlay
  variance-ratio memory states at fixed horizons; none constructs twelve
  per-month realized-path-normalized returns.
- `QM5_13049_xti-1w-mom-vol` gates a five-day continuation signal with a
  separate low-volatility state. It neither normalizes monthly returns nor
  forms a twelve-month equal-month aggregate.
- Cumulative, raw-return median, trimmed/Winsorized/robust-location,
  recency-weighted, regression, rank, sign/run/vote, block, and skip-month
  systems use different signal objects and aggregation contracts.

The twelve fixed broker-month intervals, daily close-to-close paths, separate
L2 denominator per month, endpoint-sum identity, equal weight per normalized
month, and sign of the final mean are jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_PATH_AND_VOLATILITY_NEIGHBOR_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20288`, subject to deterministic registry allocation;
- slug: `wti-volnorm-mom`;
- strategy ID: `MOP-TSMOM-2012_XTI_VOLNORM12_S36`;
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `202880000`;
- expected cadence: approximately eleven to twelve completed monthly packages
  per full post-warm-up year; Q02 owns observed density and economics;
- retire below five completed packages per full post-warm-up year, on
  nonpositive governed economics, or later portfolio-correlation rejection;
- fail on malformed or nonconsecutive endpoints, an interval outside fifteen
  to twenty-five returns, wrong return orientation, cross-month leakage,
  duplicate/omitted daily returns, nonpositive L2 norm, endpoint identity
  failure, demeaning/annualization, unequal month weights, wrong-side entry,
  repeated attempt, missing hard stop, risk mismatch, hold beyond forty days,
  or nondeterminism; and
- no post-result horizon, normalization, threshold, direction, stop, hold,
  spread, retry, or carrier rescue is authorized.

WTI is a crude-oil carrier absent from the current XAU/SP500/NDX/XNG book.
That carrier difference and volatility-balanced slow-trend state are
diversification hypotheses, not correlation evidence; unchanged Q09 alone may
measure realized overlap.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. If the paced farm reaches its
binding backtest CPU ceiling before enqueue, record the stop and do not enqueue
or run a manual test.
