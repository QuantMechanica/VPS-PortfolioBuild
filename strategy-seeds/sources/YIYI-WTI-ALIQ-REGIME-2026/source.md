---
source_id: YIYI-WTI-ALIQ-REGIME-2026
parent_source_id: YIYI-ALIQ-2025
title: WTI Self-Relative Amihud-Illiquidity Regime
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_carrier
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20302_wti_aliq_regime_g0.md
parent_sha256: EB8D48BA2F04350634370358961686F24E7842AF09CBE30614FC001452558B85
created: 2026-08-13
created_by: Research+Development
cards_extracted:
  - wti-aliq-regime
---

# WTI Self-Relative Amihud-Illiquidity Regime Source Packet

## Approved Trading Source Of Record

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity
Futures Characteristics and Asset Pricing Models," *Journal of Futures
Markets* 45(3), 176-207, DOI `10.1002/fut.22559`.

The complete open prepublication article, appendices, tables, and references
were read end to end in the governed parent packet
`strategy-seeds/sources/YIYI-ALIQ-2025/source.md`, which is content-bound by
the SHA-256 above. The durable OWNER authorization for this carrier is
`decisions/2026-08-13_qm5_20302_wti_aliq_regime_g0.md`.

## Trading-Source Findings Used

- The source measures commodity characteristics before prediction month t,
  ranks a 34-futures cross-section monthly, and holds sorted portfolios during
  month t.
- ALIQ is the prior-twelve-month average of daily absolute return divided by
  dollar volume, multiplied by 1,000,000.
- The source direction is high ALIQ minus low ALIQ.
- The source reports a positive broad-universe one-way ALIQ relation, while
  its IPCA loading test for ALIQ is not statistically significant.
- ALIQ has low pairwise correlation with several other characteristics in the
  source universe; that does not establish correlation for this WTI carrier.
- The source studies exchange-traded futures and dollar volume, not an
  outright continuous CFD, quote-tick counts, or a time-series regime.

## Bounded Carrier Mechanization

At the first processed WTI D1 bar of a genuine broker-month transition, load
exactly 505 completed `XTIUSD.DWX` D1 `MqlRates` bars, newest first. Form two
consecutive blocks of exactly 252 log returns. Divide each absolute return by
the tick volume of its ending bar, scale by one million, and average all 252
terms in each block:

```text
r[b,k]       = ln(close[b+k] / close[b+k+1]), k = 0..251
aliq[b,k]    = abs(r[b,k]) / tick_volume[b+k] * 1,000,000
ALIQ[b]      = arithmetic_mean(aliq[b,0..251])

recent block:    b = 0
preceding block: b = 252
```

Buy WTI when recent ALIQ is higher than preceding ALIQ and sell WTI when it
is lower. Use one fixed-risk position, attach a frozen ATR hard stop, and
close at the next broker-month transition. A tie or invalid state consumes
the month without a trade or retry.

This preserves the source transform, high-minus-low direction, and monthly
cadence while translating a broad cross-sectional sort into a self-relative
two-block WTI state. Tick volume is explicitly an activity proxy, not source
dollar volume. No source return, alpha, significance, cost, WTI-only result,
CFD equivalence, trade density, neutrality, or correlation claim transfers.

## Family Evidence

`QM5_13140_energy-aliq-rank` uses the same source proxy in a two-leg XTI/XNG
rank. It passed Q02 through Q07 and failed Q08 hard on a runs-test p-value of
`0.00226`. Its 2024 Q02 row recorded 82 trades, PF 1.19, and net profit
1,787.12 at fixed risk. Those results are retained as material family evidence
but do not prove this distinct single-WTI state and supply no waiver,
parameter change, or performance inheritance.

## Exact Runtime Contract

- Use only completed D1 bars and exactly 505 rates. The recent block uses
  close pairs `0/1` through `251/252` and volumes `0..251`; the preceding
  block uses close pairs `252/253` through `503/504` and volumes `252..503`.
  The blocks share one boundary close and no return or volume observation.
- Require strictly older timestamps as series index increases, a newest
  endpoint before the decision bar and no more than ten calendar days stale,
  positive finite closes, strictly positive tick volumes, finite log returns
  and terms, and exactly 252 terms per block.
- Buy when `ALIQ[0] > ALIQ[252] + 1e-12`; sell when
  `ALIQ[0] < ALIQ[252] - 1e-12`; consume the month flat otherwise.
- Do not use simple returns, dollar or real volume, range, spread, turnover,
  a percentile, alternate scale, fitted threshold, overlapping blocks,
  score sizing, normalization, or a fallback signal.
- Host on WTI D1, use slot 0, risk one `RISK_FIXED=1000` position, renew
  monthly, close stale after forty days, and persist the attempted month
  before any history or execution gate.

## Non-Duplicate Boundary

The canonical checker found no exact slug, strategy-ID, or mechanic identity
across 4,367 registry rows and 478 root cards. Two expected fuzzy matches were
manually resolved:

- `QM5_13140_energy-aliq-rank` ranks two concurrent instruments over the prior
  twelve complete calendar months, uses two magics, splits package risk, and
  repairs orphan legs. This extraction compares two fixed WTI history blocks
  and owns one position.
- `QM5_20301_wti-es-regime` uses the same carrier and lifecycle architecture
  but averages the thirteen worst simple returns from each block. This
  extraction averages all 252 absolute log returns after dividing each by its
  same-bar tick volume.
- WTI trend, calendar, event, variance-ratio, robust-location, reversal,
  skewness, kurtosis, MAX, ES, and VoV systems use different information
  objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG pullback,
  not a monthly symmetric WTI activity-price-impact state.

The return type, same-bar tick-volume divisor, fixed scale, two offsets,
disjoint support, 252 terms per block, self-relative source direction, single
WTI carrier, and consumed monthly attempt are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_ALIQ_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS with proxy and family caveats. Peer-reviewed Journal of Futures
  Markets article, DOI, publisher record, complete-open-paper read, exact
  source transform, and sibling Q08 failure disclosed.
- R2: PASS. Fixed two-block estimator, return/volume alignment, scale,
  direction, cadence, risk, stop, attempt, renewal, and stale guard.
- R3: PASS for the disclosed proxy. Registered `XTIUSD.DWX` D1 bars provide
  closes and tick volume; tick volume is not source dollar volume.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited
  signal indicator, external runtime feed, grid, martingale, or pyramid.

## Claim, Kill, And Safety Boundary

Q02 must retire the carrier below five completed positions per full post-
warm-up year or on nonpositive governed economics. Q09 alone may establish
realized book correlation. No failed result may change the transform, block
offset, volume alignment, scale, direction, carrier, formation, cadence,
risk, stop, hold, spread, or retry policy.

This packet authorizes one branch-only non-live build and paced Q02 handoff.
It excludes manual testing, live/demo/shadow/stress/optimization artifacts,
AutoTrading, `T_Live`, deploy manifests, portfolio gates, portfolio admission,
and correlation waivers.
