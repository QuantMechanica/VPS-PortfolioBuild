---
source_id: MOP-MEEK-WTI-MWEEKDAY-MED-2026
title: WTI completed-month weekday-balanced median momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_wti_monthly_weekday_median_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - MEEK-HOELSCHER-WTI-DOW-2023
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MEEK-HOELSCHER-WTI-DOW-2023: 0C6BBF1285C7C196F4D04FEB2254A62D9A9D89EDCA9E4DBBAC3D003EB3E88FDE
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - wti-mweekday-med-mom
---

# WTI Completed-Month Weekday-Balanced Median Momentum Source Packet

## Approved Source Of Record

The primary source is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` records a complete read of
the 23-page published paper from author Lasse Heje Pedersen's NYU faculty
site. The receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
the canonical URL, retrieval time, 976,459 bytes, 23 pages, and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The secondary source is Heather Meek and Susan A. Hoelscher (2023),
"Day-of-the-week effect: Petroleum and petroleum products," *Cogent Economics
& Finance* 11(1), DOI `10.1080/23322039.2023.2213876`. The governed packet
`strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md` records a
complete review of the 21-page EconStor copy, including methods, all result
tables, limitations, and references.

Both parent records and the momentum retrieval receipt were read completely
before approval. Their exact hashes and the durable OWNER authorization are
fixed in
`decisions/2026-08-23_wti_monthly_weekday_median_momentum_source_approval.md`,
committed before extraction at `1e3af965c`. No blocked page, inaccessible
table, inferred coefficient, secondary performance summary, or unrecorded
result is used.

## Source Findings Used

Moskowitz, Ooi, and Pedersen:

- test each instrument's own return at monthly lags one through sixty and
  report positive continuation over the first twelve monthly lags;
- form deterministic time-series-momentum positions from own past returns and
  renew them monthly;
- report a pooled commodity `k=1`, `h=1` implementation; and
- explicitly include NYMEX WTI crude in the commodity universe.

Meek and Hoelscher:

- study WTI and four other energy futures with ending-weekday coefficients;
- define close-to-close log returns and preserve the weekday of the return's
  ending session; and
- report heterogeneous WTI weekday coefficients, including a positive Friday
  coefficient in every fitted specification.

These findings support testing an own-price WTI monthly continuation carrier
while making weekday concentration visible. They do not establish the exact
within-month weekday grouping, equal bucket weighting, arithmetic weekday
means, median aggregation, WTI-only next-month result, or Darwinex CFD
implementation below. The source papers use rolling futures, different
formation statistics, and, in the weekday paper, conditional-variance
models. No such model runs in this extraction.

The continuous CFD, broker-month normalization, 17-23-session package,
weekday-balanced median, fixed cash risk, ATR stop, spread cap, and restart
ledger are QM translations. No source alpha, return, probability, density,
Sharpe ratio, drawdown, cost, WTI-only efficacy, CFD equivalence, or
portfolio-correlation statistic transfers.

## Bounded QM Mechanization

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
reconstruct every completed D1 close whose uniformly normalized timestamp is
in the immediately preceding calendar month plus one adjacent older close.
Require 17 through 23 completed-month sessions.

Starting from the older boundary, form one chronological close-to-close log
return ending on every completed-month session. Assign each return to the
Monday-through-Friday bucket of its ending session. For weekday `d`:

```text
bucket_sum[d]  = sum(r[j] where ending_weekday[j] == d)
bucket_count[d] = count(r[j] where ending_weekday[j] == d)
bucket_mean[d] = bucket_sum[d] / bucket_count[d]

weekday_median = ascending(bucket_mean[Monday..Friday])[2]

weekday_median > 0 => BUY XTIUSD.DWX
weekday_median < 0 => SELL XTIUSD.DWX
otherwise          => FLAT
```

Require all five weekdays and three through five observations in every
bucket. Reject a weekend label, duplicate or omitted return, nonfinite value,
or invalid count. Verify that the sum of all daily log returns equals the
direct older-boundary-to-final close log return within `1e-10`.

The raw month endpoint is diagnostic only. It may agree or disagree with the
weekday median and does not gate the trade. Each weekday has equal weight in
the final statistic regardless of whether it occurs three, four, or five
times. A zero median or any invalid state consumes the month flat. Neither
median nor endpoint magnitude changes risk.

## Exact Event Contract

1. Require exact `XTIUSD.DWX`, D1, and entry no later than 180 elapsed minutes
   after the raw first host D1 bar open of a new normalized broker month.
2. Choose one energy-label convention for current and historical bars. Permit
   raw broker date or a uniform `+1` calendar-day correction only. Reject
   every mixed, colliding, or other offset state.
3. Within a fixed 45-bar buffer, require the newest completed bar to belong to
   the immediately prior month, 17-23 unique completed-month bars in strict
   reverse-time order, and one adjacent older boundary bar. Exclude all
   current-month closes.
4. Reverse closes into chronological order and form every log return ending
   in the completed month exactly once. Verify endpoint identity within
   `1e-10`.
5. Bucket returns by the normalized ending bar's weekday. Require Monday
   through Friday only and counts of three through five in every bucket.
6. Divide each bucket sum by its count, sort the five finite means ascending
   without rounding, and take index two. Follow its strict sign; equality and
   invalid states remain flat.
7. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order submission. No outcome retries the
   month.
8. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
   ceiling.
9. Close on the first tick in a later normalized broker month, with a
   forty-calendar-day stale repair. Flatten malformed, duplicated,
   wrong-symbol, wrong-magic, or stopless owned exposure immediately.

News and Friday-close axes are OFF. Runtime uses registered MT5 history,
calendar, quotes, symbol metadata, ATR, position/deal state, and persistent
terminal state only.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,631 registry identities, 1,299
cards, and 45 Strategy Wiki nodes using the actual Company Reference root. It
found no exact or fuzzy candidate collision and returned `CLEAN`. Evidence is
`artifacts/qm5_wti_mweekday_med_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- `QM5_20187_wti-tsmom1m` follows the unpartitioned month endpoint.
- `QM5_41111_wti-mdaybreadth-mom` counts individual daily signs and requires
  raw endpoint agreement; this extraction averages by ending weekday, uses
  magnitudes, and does not gate on the endpoint.
- `QM5_41115_wti-mthirdvote-mom` partitions the month into three consecutive
  blocks; this extraction uses five noncontiguous weekday buckets.
- `QM5_41131_wti-mdaily-tailtrim-mom` sorts individual daily returns and
  deletes one per tail; this extraction first averages within weekday and
  takes the median of exactly five bucket means.
- `QM5_20269_wti-medret-mom` takes a median across twelve monthly returns.
- `QM5_41055_wti-medcal` takes a ten-year same-calendar-month median.
- fixed weekday WTI sleeves trade a declared weekday session; this extraction
  enters only at month boundary and treats all prior-month weekdays
  symmetrically.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback.

The exact carrier, completed month, older boundary, every daily return,
ending-weekday partition, per-bucket arithmetic mean, five-value median,
symmetric continuation, consumed month, fixed risk, and next-month lifecycle
are jointly load bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_WEEKDAY_BALANCED_MEDIAN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKDAY_BALANCING_TRANSLATION_RISK`. The lineage preserves a
  named-author peer-reviewed JFE momentum paper with DOI, complete-read
  receipt, durable PDF hash, and explicit WTI membership plus a named-author
  peer-reviewed open-access energy weekday paper with complete-read evidence.
  The exact median estimator is an untested translation.
- R2: `PASS`. Clock, labels, month, boundary, observations, returns, identity,
  weekday membership, bucket counts, means, sort, median index, direction,
  attempt, risk, stop, spread, and lifecycle are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history and MT5-native state supply every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, arithmetic, sorting,
  comparison, ATR, and execution state only; no conditional-variance model,
  trained output, banned signal, external feed, grid, martingale, scale-in,
  or pyramid.

## Claim And Kill Boundary

Every valid nonzero median may qualify, giving a pre-result density prior near
twelve decisions per year. This is not market evidence. Q02 must retire below
five completed positions in any full post-warm-up year, at zero trades, with
nonpositive governed economics, or on any label, month, return, partition,
count, median, side, attempt, risk, lifecycle, or determinism defect.

Direct WTI exposure is economically different from the certified XAU,
SP500, NDX, and XNG book but does not prove decorrelation. Q09 alone owns the
realized portfolio result. No failure may be rescued by changing the bucket
membership, weighting, aggregation, median direction, carrier, risk, hold, or
by adding endpoint agreement, seasonality, event, volatility, external, or
prior-result state.

## Safety Boundary

This packet supports one Strategy Card, one branch-only V5 build, strict
compile/Q01, and one paced non-live Q02 handoff only. It does not authorize a
manual backtest, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
control, or decorrelation claim.
