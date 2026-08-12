# QM5_20286 WTI Redescending Bisquare Trend G0 Authorization

Date: 2026-08-12

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20286_wti-bisquare-mom`. At each genuine broker-month transition, the
candidate reconstructs twelve completed WTI monthly log returns and trades the
sign of a fixed-step redescending bisquare location. It renews one outright
`XTIUSD.DWX` package monthly.

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
defines monthly own-return-sign positions, and includes NYMEX WTI crude in its
commodity universe.

The redescending bisquare score below is a transparent QM robust-location
mechanization, not a claim imported from the trading paper. The paper does not
prescribe this estimator, the fixed cutoff or iteration count, the Darwinex
continuous-CFD port, broker-month reconstruction, fixed-dollar sizing, ATR
stop, spread ceiling, restart ledger, or lifecycle controls. No source return,
WTI-specific alpha, trade density, CFD equivalence, correlation result, or
portfolio conclusion transfers.

## Locked Rule

On the first processed `XTIUSD.DWX` D1 bar after a genuine broker-month
transition, reconstruct exactly thirteen consecutive completed broker-month
closes `C[0]..C[12]`, oldest to newest, and define:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
s    = ascending copy of r
m    = (s[5] + s[6]) / 2
d[i] = abs(r[i] - m)
a    = ascending copy of d
MAD  = (a[5] + a[6]) / 2
scale = 1.4826 * MAD
cutoff = 4.685 * scale

mu[0] = m
for j = 0..31:
  u[i] = (r[i] - mu[j]) / cutoff
  w[i] = (1 - u[i]^2)^2                  if abs(u[i]) < 1
         0                               otherwise
  mu[j+1] = sum(w[i] * r[i]) / sum(w[i])

bisquare_location = mu[32]
signal = BUY  when bisquare_location > 0
         SELL when bisquare_location < 0
         FLAT when bisquare_location == 0 or state is invalid
```

Require positive finite closes, consecutive completed months, finite returns,
strictly positive raw MAD/scale/cutoff, finite nonnegative weights, strictly
positive total weight at every update, and finite iteration state. The scale
and cutoff freeze before iteration. Exactly 32 updates run; there is no early
convergence exit, tolerance gate, fallback statistic, optimizer, or
magnitude-based sizing.

Consume and persist the decision month before history, signal, spread, quote,
ATR, sizing, news, or order gates. Close the prior package at the next genuine
month transition before considering replacement, even when direction is
unchanged. Each entry uses one `RISK_FIXED=1000` budget and a frozen
`3.5 * ATR(20,D1)` hard stop. The entry spread ceiling is 1,500 points. No
take-profit is authorized. Close after forty calendar days if normal monthly
rollover is missed. Friday close and both news axes are disabled.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,351 EA-registry rows and 463
root cards for slug `wti-bisquare-mom`, strategy ID
`MOP-TSMOM-2012_XTI_BISQUARE12_S34`, and the declared mechanic. It found no
exact identity and returned one expected fuzzy neighbor,
`QM5_20285_wti-huber-mom`.

Manual mechanic review resolves that neighbor and the closest robust-location
systems:

- `QM5_20285` uses Huber weights: every finite tail observation retains
  positive influence `delta / residual`; this candidate's bisquare weight
  falls smoothly to exactly zero at the frozen cutoff and remains zero beyond
  it;
- `QM5_20282_wti-madcap-mom` clips each return once around a permanently
  frozen median, then takes an equal-weight mean;
- `QM5_20283_wti-trimean-mom` is a fixed quartile summary and is unrelated to
  the redescending bisquare score despite the shared Tukey naming lineage;
- `QM5_20277`, `QM5_20270`, and `QM5_20276` use fixed Winsor replacement,
  fixed trimming, and a Hodges-Lehmann pseudomedian; and
- cumulative, sign/vote/run, recency-weighted, regression, rank,
  path-efficiency, and skip-month systems estimate different functionals or
  use different endpoint objects.

The even-sample median/MAD, `1.4826` normalization, `4.685` frozen cutoff,
strict `abs(u)<1` support, squared bisquare weight, zero-tail influence,
exactly 32 re-centering updates, zero-total-weight failure, exact-zero
rejection, consumed attempt, and monthly renewal are jointly load-bearing.
Verdict: `CLEAN_AFTER_MANUAL_HUBER_NEIGHBOR_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20286`, subject to deterministic registry allocation;
- slug: `wti-bisquare-mom`;
- strategy ID: `MOP-TSMOM-2012_XTI_BISQUARE12_S34`;
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `202860000`;
- expected cadence: approximately eleven to twelve completed monthly packages
  per full post-warm-up year; Q02 owns observed density and economics;
- retire below five completed packages per full post-warm-up year, on
  nonpositive governed economics, or later portfolio-correlation rejection;
- fail on malformed endpoints, wrong return orientation, wrong median/MAD,
  nonpositive scale, mutable cutoff, wrong support/weight formula,
  other-than-32 update count, zero-weight fallback, wrong-side entry, repeated
  attempt, missing hard stop, risk mismatch, hold beyond forty days, or
  nondeterminism; and
- no post-result tuning, scale, iteration, horizon, direction, stop, hold,
  spread, retry, or carrier rescue is authorized.

WTI is a crude-oil carrier absent from the current XAU/SP500/NDX/XNG book.
That carrier difference and redescending slow-trend state are diversification
hypotheses, not correlation evidence; unchanged Q09 alone may measure overlap.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. If the paced farm reaches its
binding backtest CPU ceiling before enqueue, record the stop and do not enqueue
or run a manual test.
