# QM5_20283 WTI Quartile-Trimean Return Trend G0 Authorization

Date: 2026-08-11

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20283_wti-trimean-mom`. The candidate observes twelve separate completed
broker-month WTI log returns, sorts them, estimates the lower quartile, median,
and upper quartile by fixed even-half indexes, and trades the sign of their
`1:2:1` quartile trimean. It renews one outright `XTIUSD.DWX` package only at
genuine broker-month transitions.

The candidate may proceed through bounded source/card extraction, schema and
G0 lint, deterministic registry and magic allocation, resolver regeneration,
strict compile, one `RISK_FIXED` backtest setfile, Q01 validation, and one
paced Q02 enqueue. This authorization does not pre-approve efficacy,
diversification, decorrelation, certification, execution-contract promotion,
or portfolio admission.

## Source Boundary

The approved source of record is the already complete governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz, Ooi,
and Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its durable retrieval
receipt records an end-to-end read of the 23-page published paper, the
author-hosted route, page count, byte count, and PDF SHA-256. The paper reports
positive own-return continuation over the first twelve monthly lags, defines
positions from an instrument's own past-return sign, and includes NYMEX WTI
crude in its commodity-futures universe.

The paper does not prescribe a quartile trimean, Darwinex continuous-CFD port,
broker-month endpoint reconstruction, fixed-dollar sizing, ATR stop, spread
ceiling, restart ledger, or lifecycle controls. The robust location statistic
and every execution choice below are transparent QM hypotheses. No source
return, WTI-specific alpha, trade density, CFD equivalence, correlation
result, or portfolio conclusion transfers.

No newly retrieved public source is used. The bounded child extraction may be
written at `strategy-seeds/sources/MOP-WTI-TRIMEAN-2026/source.md` only after
this durable approval exists. The complete governed parent packet and its
retrieval receipt have been read in full for this mission.

## Locked Rule

On the first processed `XTIUSD.DWX` D1 bar after each genuine broker-month
transition, reconstruct exactly thirteen consecutive completed broker-month
closes `C[0]..C[12]`, oldest to newest. The newest endpoint must belong to the
month immediately before the decision month. Form exactly twelve adjacent log
returns and sort an independent copy ascending:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
s = sort_ascending(r)
Q1 = (s[2] + s[3]) / 2
M  = (s[5] + s[6]) / 2
Q3 = (s[8] + s[9]) / 2
T  = (Q1 + 2 * M + Q3) / 4

signal = BUY  when T > 0
         SELL when T < 0
         FLAT when T == 0 or state is invalid
```

Require positive finite closes, twelve finite returns, consecutive completed
months, strictly increasing endpoint timestamps, finite order statistics, and
no endpoint from the current broker month. There is no fallback from an exact
zero or invalid trimean to a cumulative return, ordinary mean, trimmed mean,
median, Winsorized mean, MAD cap, price slope, vote, calendar direction, or
prior pipeline result. Signal magnitude never scales risk.

Consume and persist the decision month before history, signal, spread, quote,
ATR, sizing, news, or order gates. Close the prior package at the next genuine
month transition before considering replacement, including when the sign is
unchanged. Each entry uses one `RISK_FIXED=1000` budget and a frozen
`3.5 * ATR(20,D1)` hard stop. The entry spread ceiling is 1,500 points. No
take-profit is authorized. Close after forty calendar days if normal monthly
rollover is missed. Friday close and both news axes are disabled for the
native-price package.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,348 EA-registry rows and 459
cards for slug `wti-trimean-mom`, strategy ID
`MOP-TSMOM-2012_XTI_TRIMEAN12_S31`, and the declared mechanic. It found no
exact registry or card identity and returned four expected fuzzy same-source
neighbors for manual review: fixed-tail Winsorization, linear weighting, raw
median, and fixed-count trimmed mean.

Manual mechanic and registry review resolves those matches:

- `QM5_20269_wti-medret-mom` uses only sorted indexes 5 and 6;
- `QM5_20270_wti-trimmean-mom` equally averages every sorted observation from
  indexes 2 through 9;
- `QM5_20277_wti-winsor-mom` retains all twelve observations after replacing
  two observations in each tail with fixed order-statistic boundaries; and
- `QM5_20278_wti-linw-mom` weights unsorted observations by chronology.

This candidate deliberately ignores sorted indexes 0, 1, 4, 7, 10, and 11;
uses indexes 2, 3, 8, and 9 once; and uses indexes 5 and 6 twice. Equivalently,
the six selected order statistics receive weights `1/8, 1/8, 1/4, 1/4, 1/8,
1/8`. The endpoint count, sort, exact indexes, `1:2:1` aggregation, divisor
four, exact-zero rejection, consumed attempt, and monthly renewal are jointly
load-bearing. Verdict: `CLEAN_AFTER_ROBUST_LOCATION_FUZZY_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20283`, subject to deterministic registry allocation;
- slug: `wti-trimean-mom`;
- strategy ID: `MOP-TSMOM-2012_XTI_TRIMEAN12_S31`;
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `202830000`;
- expected cadence: approximately twelve completed monthly packages per full
  post-warm-up year; Q02 owns observed density and economics;
- retire below five completed packages per full post-warm-up year, on
  nonpositive governed economics, or later portfolio-correlation rejection;
- fail on a missing/interpolated/nonconsecutive endpoint, current-month
  leakage, wrong return orientation, wrong sort or quartile/median indexes,
  wrong weights or divisor, fallback after zero, wrong-side entry, repeated
  monthly attempt, missing hard stop, risk-mode mismatch, hold beyond forty
  days, or nondeterminism; and
- no post-result lookback, estimator, stop, hold, spread, retry, or carrier
  rescue is authorized.

WTI is a crude-oil carrier absent from the current XAU/SP500/NDX/XNG book.
That carrier difference and the robust slow-trend statistic are
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
