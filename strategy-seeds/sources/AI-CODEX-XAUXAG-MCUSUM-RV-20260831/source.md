---
source_id: AI-CODEX-XAUXAG-MCUSUM-RV-20260831
source_type: ai_originated_governed_synthesis
title: XAU/XAG monthly centered-CUSUM relative-return reversion
author: OpenAI Codex
supporting_authors: Karsten Schweikert; E. S. Page; CME Group; NIST/SEMATECH
status: approved_source_complete
approval_basis: decisions/2026-08-31_xauxag_monthly_centered_cusum_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - AI-CODEX-WTI-MCUSUM-20260831
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  AI-CODEX-WTI-MCUSUM-20260831: 109CD229E8BAC6A26F56132C8FC9CA2CFA0925BB2FC9C0948C8C3F5F6114E73C
created: 2026-08-31
created_by: Research+Development
cards_extracted: []
---

# XAU/XAG Monthly Centered-CUSUM Relative-Return Reversion

## Canonical Origin And Evidence Boundary

This packet is the single R1 lineage for one bounded AI-originated
gold/silver relative-value Strategy Card. The current explicit OWNER mission
requests a new structural low-frequency commodity sleeve and expressly
permits an `XAUUSD`/`XAGUSD` market-neutral-style ratio-reversion basket.
`processes/qb_reputable_source_criteria.md` permits AI-originated strategies
when the exact hypothesis, evidence boundary, and prompt/output trail are
durable.

The governed Schweikert packet preserves peer-reviewed evidence that gold and
silver can have a state-dependent relationship; it warns against assuming one
universal constant equilibrium. The governed CME packet defines gold divided
by silver as an intermarket spread and distinguishes gold's monetary and
safe-haven drivers from silver's industrial-cycle exposure.

The governed centered-CUSUM packet preserves E. S. Page (1954), “Continuous
Inspection Schemes,” *Biometrika* 41(1/2), 100–115, DOI
`10.1093/biomet/41.1-2.100`, as a named peer-reviewed bibliographic record.
The article body was not accessible and no inaccessible formula or claim is
reconstructed. It also records a complete read of the public
NIST/SEMATECH Engineering Statistics Handbook page “CUSUM Control Charts,”
which defines cumulative deviations from an estimated mean and explains that
a mean shift produces directional drift in the path.

None of those sources tests the exact rule below. The synchronized relative
returns, finite retrospective bridge, maximum split, central-band admission,
contrarian side, continuous CFDs, equal-notional construction, fixed cash
risk, stops, spread ceilings, and lifecycle are transparent pre-result QM
choices. No source performance, p-value, density, neutrality, correlation, or
portfolio claim transfers.

## Locked Hypothesis

Gold and silver share broad precious-metal and USD drivers but can diverge as
safe-haven, monetary, industrial, and business-cycle forces change. When one
unique central split creates the largest mean-centered cumulative excursion
in twelve completed monthly gold-minus-silver returns, treat the post-split
relative displacement as exhaustion and fade it for the next broker month.

At the first synchronized executable D1 tick of a genuine new broker month:

1. Select one synchronized month-end XAU/XAG D1 close pair from each of the
   immediately prior thirteen consecutive broker months.
2. Define `L[i]=ln(XAU[i])-ln(XAG[i])`, oldest to newest, and
   `r[i]=L[i+1]-L[i]` for `i=0..11`.
3. Center the twelve relative returns by their arithmetic mean and compute
   all eleven nonterminal cumulative deviations.
4. Require one unique maximum absolute deviation beyond `1e-12` and require
   its split count in the fixed central band `4..8`.
5. Fade the arithmetic mean of the post-split relative returns: positive
   means sell XAU/buy XAG; negative means buy XAU/sell XAG.
6. Consume the month before fallible gates, risk one fixed aggregate budget,
   attach frozen hard stops to both legs, and exit at the next month or the
   forty-day stale boundary.

The CUSUM magnitude is an admission diagnostic only. It never changes side or
size. The strategy is contrarian and does not inherit the outright WTI
parent's continuation direction.

## Exact Statistical Contract

For thirteen synchronized positive finite completed-month close pairs:

```text
for i = 0..12:
    L[i] = ln(XAU_close[i]) - ln(XAG_close[i])

for i = 0..11:
    r[i] = L[i+1] - L[i]

mean = sum(r[0..11]) / 12
running = 0
for k = 1..11:
    running += r[k-1]
    S[k] = running - k*mean

M = max(abs(S[k]))
K = { k : abs(abs(S[k]) - M) <= 1e-12 }

qualify iff M > 1e-12 and size(K) == 1 and 4 <= K[0] <= 8
post_mean = sum(r[K[0]..11]) / (12-K[0])

SELL XAU / BUY XAG iff qualify and post_mean >  1e-12
BUY XAU / SELL XAG iff qualify and post_mean < -1e-12
FLAT otherwise
```

The terminal sum after all twelve returns is identically zero and is
excluded. Every close, logarithm, return, sum, mean, path value, and post mean
must be finite. Missing or duplicate months, unmatched or stale endpoints,
nonpositive closes, malformed chronology, zero path, tied maximum, edge
maximum, or zero post mean consumes the month flat. A p-value, control limit,
standardization, rank transform, Page tabular reset, endpoint fallback, or
adaptive window is forbidden.

## Event And Execution Contract

1. Require exact `XAUUSD.DWX` host, exact `XAGUSD.DWX` companion, D1, slots
   zero and one, and an entry attempt no later than 180 elapsed minutes after
   raw host-bar open in a genuine new broker month.
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
`artifacts/qm5_xauxag_mcusum_rv_preallocation_dedup_20260831.json`, SHA-256
`165C8CC9BCE9C560D2BF889DE1CBF5E3BA9A110147B921EF982D8CD8808D6C95`,
scanned 4,746 registry identities, 1,384 card files, and all 45 Strategy Wiki
nodes. It found no exact identity and one expected fuzzy method neighbor,
`QM5_41245_wti-mcusum-shift-tr`.

The mechanic is not an alias: `QM5_41245` follows a post-shift mean on one
outright WTI path and owns one directional position. This rule fades a
synchronized gold-minus-silver post-shift mean and owns an atomic opposite-leg
equal-notional basket. Existing XAU/XAG rank, pair-count, ECDF, local-extrema,
sign-run, regression, scale, z-score, and variance-ratio systems retain
different state objects and have no mean-centered endogenous CUSUM split.

Verdict:
`DISTINCT_XAUXAG_MONTHLY_CENTERED_RELATIVE_RETURN_CUSUM_UNIQUE_CENTRAL_SHIFT_POST_MEAN_CONTRARIAN_EQUAL_NOTIONAL_REVERSION`.

## Reputable-Source Criteria

- R1: `PASS_WITH_AI_SYNTHESIS_AND_METHOD_TRANSLATION_RISK`. One durable
  AI-originated source ID, peer-reviewed relationship evidence, official
  exchange carrier evidence, named peer-reviewed CUSUM lineage, a complete
  official NIST method-page record, parent hashes, and access boundaries.
- R2: `PASS`. Observation order, synchronization, returns, centering, all
  sums, uniqueness tolerance, split band, contrarian sides, attempt, risk,
  stops, atomicity, spread limits, and lifecycle are exact.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  XAU/XAG D1 data and native MT5 state supply all runtime inputs.
- R4: `PASS`. Deterministic native arithmetic and execution state only; no
  ML, trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

This packet establishes no profitability, statistical significance,
neutrality, independence, decorrelation, or portfolio fitness. Q02 retires
zero packages, fewer than five completed packages in any full post-warm-up
year, nonpositive governed economics, or any implementation defect. Q09 alone
owns realized overlap. No weak result may be repaired by changing the sample,
split band, tolerance, direction, carrier, stop, hold, notional tolerance, or
retry contract.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced logical Q02 handoff if CPU capacity permits. It authorizes no
manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading
action, `T_Live` change, deploy/live manifest, portfolio-gate edit,
correlation waiver, or portfolio admission.

