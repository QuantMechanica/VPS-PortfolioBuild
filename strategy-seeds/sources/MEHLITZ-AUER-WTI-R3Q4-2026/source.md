---
source_id: MEHLITZ-AUER-WTI-R3Q4-2026
title: WTI three-month memory-enhanced momentum using the R3-q4 variance ratio
publisher: The European Journal of Finance / BTU Cottbus-Senftenberg
source_type: peer_reviewed_paper_with_open_precursor
status: cards_ready
approval_basis: OWNER commodity/energy portfolio mission 2026-08-06
created: 2026-08-06
created_by: Research+Development
strategy_ids:
  - MEHLITZ-AUER-MEM-2024_XTI_R3Q4_S02
---

# Mehlitz-Auer WTI R3-q4 Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-06 authorizes one new non-duplicate structural
commodity/energy card, build, and paced Q02 enqueue. The bounded parent packet
`strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md` was read completely
for this extraction. That packet records an end-to-end review of Chapter 3,
pp. 51-74, and Appendix C, pp. 110-113, of the open doctoral precursor.

Canonical citation: Mehlitz, Julia S., and Benjamin R. Auer (2024),
"Memory-enhanced momentum in commodity futures markets," *The European
Journal of Finance* 30(8), 773-802, DOI
https://doi.org/10.1080/1351847X.2023.2220118.

## Source Findings Used

The source universe explicitly contains WTI crude oil. Section 3.3.1 defines
positive and negative completed ranking returns without a skip month. Sections
3.3.2.1-3.3.2.2 define the heteroskedasticity-robust Lo-MacKinlay variance
ratio, pair ranking periods with `q` in `{2,4,7,13}`, use 32 monthly
observations, require a fixed two-sided 10% significant deviation from one,
and map persistent winners/losers to continuation and anti-persistent
winners/losers to reversal. `R3-q4` is the source-declared three-month member
of that family.

No source return, Sharpe ratio, drawdown, hit rate, trade count, constituent
WTI statistic, CFD result, or portfolio correlation is imported.

## Locked R3-q4 Rule

For 32 completed monthly log returns `r[0..31]` in chronological order, let
`d[t]=r[t]-mean(r)` and `S=sum(d[t]^2)`.

For lags `k=1,2,3`:

- `rho(k)=sum(t=k..31, d[t]*d[t-k])/S`;
- `delta(k)=sum(t=k..31, d[t]^2*d[t-k]^2)/S^2`.

Then lock:

- `VR(4)=1+1.5*rho(1)+1.0*rho(2)+0.5*rho(3)`;
- `theta(4)=2.25*delta(1)+1.0*delta(2)+0.25*delta(3)`;
- `z=(VR(4)-1)/sqrt(theta(4))`;
- actionable memory only when `abs(z)>1.64485362695147`;
- `R3=r[29]+r[30]+r[31]`;
- direction `sign(R3)*sign(z)`; and
- flat on insignificant memory, zero R3, incomplete history, zero variance,
  zero robust variance, or invalid arithmetic.

A positive direction buys WTI and a negative direction sells WTI. The source
holds to the next monthly formation.

## Bounded QM Mechanization

At each genuine broker-month transition, the EA reconstructs 33 consecutive
completed WTI month-end closes from completed `XTIUSD.DWX` D1 bars, forms the
latest 32 returns, and applies the locked rule. It permits at most one attempt
per broker month, closes at the next month transition or after 35 calendar
days, and attaches a frozen `3.0*ATR(20,D1)` hard stop.

Runtime data are native MT5 D1 OHLC, ATR, spread, calendar, symbol metadata,
positions, and deals only. No futures curve, external file/API, volume, open
interest, optimizer, trained model, banned signal indicator, grid, martingale,
pyramiding, or PnL feedback is allowed.

## Non-Duplicate Boundary

The deterministic pre-allocation check scanned 4,310 registry rows and 427
cards. It returned no exact collision and the expected fuzzy source sibling
`QM5_13134_energy-vr-mom`.

`QM5_13134` is `R1-q2`; this extraction is `R3-q4`. The former uses one
monthly return, lag-one autocorrelation, and one robust term. The latter uses
a three-return rank, three autocorrelation lags, and three differently
weighted robust terms. Plain WTI three-month momentum has no memory test,
significance gate, or anti-persistence reversal. Existing q2/calendar and
q2/return-sign composites retain the one-month q2 state. No EA implements the
source's WTI `R3-q4` state.

Verdict: `CLEAN_AFTER_EXPECTED_SOURCE_SIBLING_REVIEW`.

## Reputable-Source Criteria And Safety

- R1: PASS. Peer-reviewed journal article with DOI and a completely reviewed
  open precursor chapter; WTI and `R3-q4` are source-declared.
- R2: PASS. Sample, return horizon, q, autocorrelation and robust weights,
  critical value, direction matrix, cadence, stop, and exits are frozen.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies all runtime inputs.
- R4: PASS. Deterministic arithmetic only; no ML, banned indicator, external
  feed, grid, martingale, pyramiding, or adaptive fitting.

The futures-index/continuous-CFD basis, slow warm-up, significance-gate
density, WTI concentration, gaps, roll/financing, and correlation remain Q02+
falsification risks. This packet authorizes no live artifact or portfolio
change.
