---
source_id: MOP-MEEK-WTI-MDAILY-MED-2026
title: WTI completed-month ordinary daily-return median momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_wti_monthly_daily_median_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - MEEK-HOELSCHER-WTI-DOW-2023
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MEEK-HOELSCHER-WTI-DOW-2023: 0C6BBF1285C7C196F4D04FEB2254A62D9A9D89EDCA9E4DBBAC3D003EB3E88FDE
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - wti-mdaily-median-mom
---

# WTI Completed-Month Ordinary Daily-Return Median Momentum Source Packet

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
before source approval. Their exact hashes and the durable OWNER
authorization are fixed in
`decisions/2026-08-23_wti_monthly_daily_median_momentum_source_approval.md`,
committed before extraction at `37bb3f499`. No blocked page, inaccessible
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

- study WTI and four other energy futures using close-to-close log returns;
- preserve the ending session's daily label for each return; and
- document heterogeneous WTI daily behavior across weekday coefficients.

These findings support testing an own-price WTI monthly continuation carrier
while exposing whether its direction reflects the typical completed daily
move rather than a small number of outliers. They do not establish the exact
ordinary daily-return median, a WTI-only next-month result, or a Darwinex CFD
implementation. The source papers use rolling futures, different formation
statistics, and, in the weekday paper, conditional-variance models. No such
model runs in this extraction.

The continuous CFD, broker-month normalization, 17-23-session package,
ordinary odd/even median, fixed cash risk, ATR stop, spread cap, and restart
ledger are QM translations. No source alpha, return, probability, density,
Sharpe ratio, drawdown, cost, WTI-only efficacy, CFD equivalence, or
portfolio-correlation statistic transfers.

## Bounded QM Mechanization

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
reconstruct every completed D1 close whose uniformly normalized timestamp is
in the immediately preceding calendar month plus one adjacent older close.
Require 17 through 23 completed-month sessions.

Starting from the older boundary, form one chronological close-to-close log
return ending on every completed-month session. Sort all `n` returns ascending
without rounding and compute the ordinary sample median:

```text
sorted = ascending(r[0], ..., r[n-1])

if n is odd:
    daily_median = sorted[n/2]
else:
    daily_median = (sorted[n/2-1] + sorted[n/2]) / 2

daily_median > 0 => BUY XTIUSD.DWX
daily_median < 0 => SELL XTIUSD.DWX
otherwise        => FLAT
```

Require every close and return to be finite and positive where applicable.
Verify that the sum of the unsorted chronological returns equals the direct
older-boundary-to-final-close log return within `1e-10`. Sorting changes only
the estimator view, never membership or the endpoint identity.

The raw month endpoint is diagnostic only. It may agree or disagree with the
daily median and does not gate the trade. A zero median or any invalid state
consumes the month flat. Neither median nor endpoint magnitude changes risk.

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
5. Sort all returns ascending without rounding. Select the exact center for
   odd `n`; average only the two exact center values for even `n`. Reject any
   invalid count, center index, or nonfinite arithmetic.
6. Follow the strict median sign; equality and invalid states remain flat.
   The raw endpoint is an identity diagnostic, never a confirmation filter.
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

The fail-closed canonical checker scanned 4,632 registry identities, 1,300
cards, and 45 Strategy Wiki nodes using the actual Company Reference root. It
found no exact or fuzzy candidate collision and returned `CLEAN`. Evidence is
`artifacts/qm5_wti_mdaily_median_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- `QM5_20187_wti-tsmom1m` follows the unpartitioned month endpoint.
- `QM5_20269_wti-medret-mom` takes a median across twelve disjoint monthly
  returns, not across daily returns inside one month.
- `QM5_41111_wti-mdaybreadth-mom` counts daily signs and requires endpoint
  agreement; this extraction retains center magnitude and has no endpoint
  gate.
- `QM5_41127_wti-mdaily-persist-mom` estimates adjacent demeaned-return
  dependence and follows the endpoint. This extraction ignores adjacency
  after exact reconstruction and follows an order statistic.
- `QM5_41131_wti-mdaily-tailtrim-mom` removes one observation per tail and
  sums all remaining returns. This extraction uses only the ordinary one- or
  two-value center.
- `QM5_41132_wti-mweekday-med-mom` averages five ending-weekday buckets and
  takes the median of those means. This extraction has no bucket or weekday
  state and sorts all 17-23 individual daily returns directly.
- the earlier trim, Winsor, MAD-cap, trimean, pseudomedian, Huber, and
  bisquare WTI cards transform twelve monthly returns rather than the latest
  month's daily sample.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback.

The exact carrier, completed month, older boundary, every daily return,
full-sample ascending sort, ordinary odd/even median, symmetric continuation,
consumed month, fixed risk, and next-month lifecycle are jointly load
bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_ORDINARY_DAILY_RETURN_MEDIAN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_WITHIN_MONTH_MEDIAN_TRANSLATION_RISK`. The lineage preserves
  a named-author peer-reviewed JFE momentum paper with DOI, complete-read
  receipt, durable PDF hash, and explicit WTI membership plus a named-author,
  peer-reviewed open-access WTI daily-return paper with complete-read
  evidence. The exact median estimator is an untested translation.
- R2: `PASS`. Clock, labels, month, boundary, observations, returns, identity,
  ascending sort, odd/even center formula, direction, attempt, risk, stop,
  spread, and lifecycle are fixed.
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
nonpositive governed economics, or on any label, month, return, sort, median,
side, attempt, risk, lifecycle, or determinism defect.

Direct WTI exposure is economically different from the certified XAU,
SP500, NDX, and XNG carriers but does not prove decorrelation. Q09 alone owns
the realized portfolio result. No failure may be rescued by changing the
sample, center formula, direction, carrier, risk, hold, or by adding endpoint
agreement, weekday, seasonal, event, volatility, external, or prior-result
state.

## Safety Boundary

This packet supports one Strategy Card, one branch-only V5 build, strict
compile/Q01, and one paced non-live Q02 handoff only. It does not authorize a
manual backtest, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
control, or decorrelation claim.
