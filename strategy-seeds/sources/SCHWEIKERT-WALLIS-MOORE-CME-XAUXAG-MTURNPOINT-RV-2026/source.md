---
source_id: SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026
source_type: peer_reviewed_and_exchange_composite_bounded_mechanization
title: XAU/XAG thirteen-month turning-point persistence reversion
authors: Karsten Schweikert; W. Allen Wallis; Geoffrey H. Moore; CME Group
status: approved_source_complete
approval_basis: decisions/2026-08-31_xauxag_monthly_turning_point_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026: 91C2B08A1CEB8384CCEB8B1264E5CFF69FC590E544D052DB58C0C38CB19A2EBB
created: 2026-08-31
created_by: Research+Development
cards_extracted:
  - QM5_41246_xauxag-mturnpoint-rv
---

# XAU/XAG Thirteen-Month Turning-Point Persistence Reversion

## Canonical Source Boundary

This packet is the single R1 lineage for one bounded gold/silver
relative-value Strategy Card. It was extracted only after the three governed
parent packets named in frontmatter were read completely and their hashes
verified.

Karsten Schweikert (2018), “Are gold and silver cointegrated? New evidence
from quantile cointegrating regressions,” *Journal of Banking & Finance* 88,
44–51, DOI `10.1016/j.jbankfin.2017.11.010`, supports testing a related,
state-dependent gold/silver relation and warns against assuming one universal
constant equilibrium.

CME Group defines the gold/silver ratio as gold price divided by silver price
per troy ounce, presents it as an intermarket spread, and distinguishes
gold's monetary/safe-haven drivers from silver's industrial-cycle exposure.

The governed turning-point parent preserves W. Allen Wallis and Geoffrey H.
Moore (1941), “A Significance Test for Time Series Analysis,” *Journal of the
American Statistical Association* 36(215), 401–409, DOI
`10.1080/01621459.1941.10500577`, only as a named peer-reviewed method record.
Its article body is not claimed as completely read. The parent also preserves
complete pinned public CRAN implementation and documentation files that count
strict local peaks/troughs and define the iid null mean as `2*(n-2)/3`.

None of these sources tests the exact rule below. The thirteen synchronized
monthly ratio endpoints, below-mean gate, contrarian direction, continuous
CFD mapping, equal-notional construction, fixed cash risk, stops, spread
ceilings, and lifecycle are transparent pre-result QM choices. No source
performance or portfolio claim transfers.

## Locked Hypothesis

Gold and silver share a long-run relation but respond differently to monetary,
safe-haven, and industrial forces. A thirteen-month gold/silver ratio path
with fewer strict direction reversals than the iid null mean represents a
persistent relative displacement. Fade that displacement for the next broker
month with opposite equal-notional XAU/XAG legs.

At the first synchronized executable D1 tick of a new broker month:

1. Select one synchronized month-end XAU/XAG D1 close pair from each of the
   immediately prior thirteen consecutive broker months.
2. Define `L[i]=ln(XAU[i])-ln(XAG[i])`, oldest to newest.
3. Count a strict local peak or trough at each interior `i=1..11`.
4. Qualify only when `3*TP < 22`, exactly `TP <= 7`, and the endpoint
   displacement exceeds `1e-12` in absolute value.
5. If `L[12] > L[0]`, sell XAU and buy XAG. If `L[12] < L[0]`, buy XAU and
   sell XAG.
6. Consume the month before fallible gates, risk one fixed aggregate budget,
   attach frozen hard stops to both legs, and exit at the next month or the
   forty-day stale boundary.

The turning-point count is an admission gate only. It never changes side or
size. The strategy is contrarian; it does not inherit the WTI parent's
continuation direction.

## Exact Statistical Contract

For thirteen finite pairwise-distinct log-ratio endpoints `L[0]..L[12]`:

```text
TP = 0
for i = 1..11:
  peak   = L[i-1] < L[i] and L[i] > L[i+1]
  trough = L[i-1] > L[i] and L[i] < L[i+1]
  if peak or trough:
    TP += 1

require 0 <= TP <= 11
persistent = 3*TP < 22          # exactly TP <= 7
delta = L[12] - L[0]

SELL XAU / BUY XAG iff persistent and delta >  1e-12
BUY XAU / SELL XAG iff persistent and delta < -1e-12
FLAT otherwise
```

Positive finite leg closes are mandatory before logarithms. Every pair of
ratio endpoints must differ by more than `1e-12`. Wrong endpoint count,
missing month, unsynchronized timestamp, stale endpoint, nonpositive close,
nonfinite value, tie, impossible count, or zero displacement consumes the
month flat. A p-value, normal approximation, continuity correction, fitted
threshold, rank transform, magnitude fallback, or adaptive window is
forbidden.

## Event And Execution Contract

1. Require exact `XAUUSD.DWX` host, exact `XAGUSD.DWX` companion, D1, slots
   zero and one, and an entry attempt no later than 180 elapsed minutes after
   the raw host-bar open in a genuine new broker month.
2. Persist `yyyymm` before history, signal, news, spread, quote, ATR, sizing,
   margin, or order gates. A flat state, reject, repair, stop, restart, or
   order failure never retries the month.
3. Require thirteen consecutive completed broker-month endpoints, strict
   timestamp order, no current-month signal price, and at most ten calendar
   days of endpoint staleness.
4. Open one atomic opposite-side package with equal target absolute USD
   notionals, at most 20% realized notional mismatch, aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
5. Attach a frozen `3.5*ATR(20,D1)` hard stop to each leg, no target, and
   entry-spread ceilings of 1,500 XAU points and 500 XAG points.
6. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately flatten malformed, orphaned, duplicated,
   same-side, wrong-symbol, wrong-magic, stopless, or notional-invalid owned
   exposure.

Both news axes, legacy news, and Friday close are off. Runtime reads only
registered native MT5 history, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The corrected-root canonical receipt
`artifacts/qm5_xauxag_mturnpoint_rv_preallocation_dedup_20260831.json`,
SHA-256 `B7839F5EC0EC0E9EF188908B0D168F600AB76E183D2D657EC1491AEE93812D18`,
scanned 4,745 registry identities, 1,383 card files, and all 45 Strategy Wiki
nodes and returned `CLEAN`.

The closest families remain mechanically different:

- outright WTI `QM5_41171` follows a single-leg endpoint; this rule fades a
  synchronized two-leg gold/silver ratio displacement;
- XAU/XAG Mann-Kendall and Spearman systems use global ranks; this rule counts
  only strict local extrema;
- Cox-Stuart and KS systems use fixed half-sample comparisons; this rule has
  no split or empirical distribution;
- path-efficiency and RMS systems retain magnitudes; this rule discards
  magnitudes after strict comparisons; and
- rolling ratio, OLS, MAD, and quantile systems fit centers, betas, scales, or
  thresholds; this rule fits none.

Verdict:
`CLEAN_XAUXAG_THIRTEEN_MONTH_STRICT_TURNING_POINT_PERSISTENCE_CONTRARIAN_EQUAL_NOTIONAL_REVERSION`.

## Reputable-Source Criteria

- R1: `PASS_WITH_CARRIER_STATISTIC_AND_DIRECTION_TRANSLATION_RISK`.
  Peer-reviewed gold/silver research, official-exchange carrier evidence,
  named peer-reviewed turning-point lineage, complete public method files,
  durable parent hashes, and explicit access boundaries are preserved.
- R2: `PASS`. Observation order, synchronization, strict comparisons, count,
  integer gate, contrarian sides, attempt, risk, stops, atomicity, spread
  limits, and lifecycle are exact.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  XAU/XAG D1 data and native MT5 state supply all runtime inputs.
- R4: `PASS`. Deterministic native arithmetic and execution state only; no
  ML, trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

This packet establishes no profitability, significance, neutrality,
independence, decorrelation, or portfolio fitness. Q02 retires zero packages,
fewer than five completed packages in any full post-warm-up year,
nonpositive governed economics, or any implementation defect. Q09 alone owns
realized overlap. No weak result may be repaired by changing the sample,
count boundary, direction, carrier, stop, hold, notional tolerance, or retry
contract.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced logical Q02 handoff if CPU capacity permits. It authorizes no
manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading
action, `T_Live` change, deploy/live manifest, portfolio-gate edit,
correlation waiver, or portfolio admission.
