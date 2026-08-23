---
source_id: MOP-MEEK-XNG-MDAILY-IQRMEAN-2026
title: XNG completed-month daily-return interquartile-mean momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-24_xng_monthly_daily_iqr_mean_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - MEEK-HOELSCHER-WTI-DOW-2023
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MEEK-HOELSCHER-WTI-DOW-2023: 0C6BBF1285C7C196F4D04FEB2254A62D9A9D89EDCA9E4DBBAC3D003EB3E88FDE
created: 2026-08-24
created_by: Research+Development
cards_extracted:
  - xng-mdaily-iqrmean-mom
---

# XNG Completed-Month Daily-Return Interquartile-Mean Momentum Source Packet

## Approved source of record

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
`decisions/2026-08-24_xng_monthly_daily_iqr_mean_momentum_source_approval.md`,
committed before this extraction at `c24a87615`. No blocked page,
inaccessible table, inferred coefficient, secondary performance summary, or
unrecorded result is used.

## Source findings used

Moskowitz, Ooi, and Pedersen:

- test each instrument's own return at monthly lags one through sixty and
  report positive continuation over the first twelve monthly lags;
- form deterministic time-series-momentum positions from own past returns and
  renew them monthly;
- report a pooled commodity `k=1,h=1` implementation; and
- explicitly include natural gas in the commodity universe.

Meek and Hoelscher:

- study natural gas and four petroleum futures using synchronized
  close-to-close log returns;
- preserve the ending session's daily label for each return; and
- document heterogeneous daily energy behavior, including natural gas.

These findings support testing an own-price natural-gas monthly continuation
carrier while exposing whether its direction survives removal of the
completed month's large positive and negative daily shocks. They do not
establish the exact interquartile mean, an XNG-only next-month result, or a
Darwinex CFD implementation. The source papers use rolling futures, different
formation statistics, and, in the weekday paper, conditional-variance models.
No such model runs in this extraction.

The continuous CFD, broker-month normalization, 17-23-session package,
integer-quartile trim, fixed cash risk, ATR stop, spread cap, and restart
ledger are QM translations. No source alpha, return, probability, density,
Sharpe ratio, drawdown, cost, XNG-only efficacy, CFD equivalence, or
portfolio-correlation statistic transfers.

## Bounded QM mechanization

On the first executable `XNGUSD.DWX` D1 bar of a new normalized broker month,
reconstruct every completed D1 close whose uniformly normalized timestamp is
in the immediately preceding calendar month plus one adjacent older close.
Require 17 through 23 completed-month sessions.

Starting from the older boundary, form one chronological close-to-close log
return ending on every completed-month session. Sort all `n` returns ascending
without rounding and compute the integer-quartile-trimmed arithmetic mean:

```text
sorted = ascending(r[0], ..., r[n-1])
trim_each_tail = floor(n / 4)
retained_count = n - 2 * trim_each_tail
central_sum = sum(sorted[i], i=trim_each_tail..n-trim_each_tail-1)
central_mean = central_sum / retained_count

central_mean > 0 => BUY XNGUSD.DWX
central_mean < 0 => SELL XNGUSD.DWX
otherwise        => FLAT
```

For the allowed 17-23 sessions, exactly four or five returns are removed from
each tail and exactly 9-13 central observations remain. Require positive
finite closes, finite log returns, valid indexes, a retained count of at least
nine, and a finite central sum and mean.

Verify that the sum of the unsorted chronological returns equals the direct
older-boundary-to-final-close log return within `1e-10`. Sorting and trimming
change only the direction estimator; they never change package membership or
the endpoint identity.

The raw month endpoint is diagnostic only. It may agree or disagree with the
central mean and does not gate the trade. A zero central mean or any invalid
state consumes the month flat. Neither central mean nor endpoint magnitude
changes risk.

## Exact event contract

1. Require exact `XNGUSD.DWX`, D1, and entry no later than 180 elapsed minutes
   after the raw first host D1 bar open of a new normalized broker month.
2. Choose one energy-label convention for current and historical bars. Permit
   raw broker date or a uniform `+1` calendar-day correction only. Reject
   every mixed, colliding, weekend-ending, or other offset state.
3. Within a fixed 45-bar buffer, require the newest completed bar to belong to
   the immediately prior month, 17-23 unique completed-month bars in strict
   reverse-time order, and one adjacent older boundary bar. Exclude all
   current-month closes.
4. Reverse closes into chronological order and form every log return ending
   in the completed month exactly once. Verify endpoint identity within
   `1e-10`.
5. Sort all returns ascending without rounding. Remove exactly `floor(n/4)`
   returns from each tail, retain the closed integer index interval between
   those tails, and average every retained observation once.
6. Follow the strict central-mean sign; equality and invalid states remain
   flat. The raw endpoint is an identity diagnostic, never a confirmation
   filter.
7. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order submission. No outcome retries the
   month.
8. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 3,000-point spread
   ceiling.
9. Close on the first tick in a later normalized broker month, with a
   forty-calendar-day stale repair. Flatten malformed, duplicated,
   wrong-symbol, wrong-magic, or stopless owned exposure immediately.

News and Friday-close axes are OFF. Runtime uses registered MT5 history,
calendar, quotes, symbol metadata, ATR, position/deal state, and persistent
terminal state only.

## Non-duplicate boundary

The fail-closed canonical checker scanned 4,635 registry identities, 1,303
cards, and 45 Strategy Wiki nodes using the current Company Reference root. It
found no exact candidate collision and raised only the expected WTI carrier
sibling for manual review. Evidence is
`artifacts/qm5_xng_mdaily_iqrmean_mom_preallocation_dedup_20260824.json`.

Manual semantic review fixes a new carrier-specific mechanic:

- `QM5_41134_wti-mdaily-iqrmean-mom` uses the same robust statistic on WTI.
  This extraction is locked to XNG and cannot execute on WTI. The separate
  WTI/XNG single-symbol precedent is `QM5_20187` and `QM5_20204`.
- `QM5_20204_xng-tsmom1m` follows the unpartitioned completed-month endpoint.
  This extraction instead follows a dynamic 9-13-observation central band and
  keeps the raw endpoint diagnostic only.
- XNG weekly range, close-location, flow, calendar, reversal, and multi-month
  trend systems do not select an order-statistic band from every daily return
  inside exactly one completed month.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only
  two-day cumulative-RSI pullback above SMA(200), not a symmetric monthly
  robust-return continuation rule.

The exact carrier, completed month, older boundary, every daily return,
full-sample ascending sort, dynamic integer-quartile tail removal,
central-band arithmetic mean, symmetric continuation, consumed month, fixed
risk, and next-month lifecycle are jointly load bearing. Manual verdict:
`CLEAN_XNG_COMPLETED_MONTH_DAILY_INTERQUARTILE_MEAN_MOMENTUM_AFTER_CARRIER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1: `PASS_WITH_WITHIN_MONTH_IQR_MEAN_TRANSLATION_RISK`. The lineage
  preserves a named-author peer-reviewed JFE momentum paper with DOI,
  complete-read receipt, durable PDF hash, and explicit natural-gas membership
  plus a named-author, peer-reviewed open-access natural-gas daily-return paper
  with complete-read evidence. The exact central-band estimator is untested.
- R2: `PASS`. Clock, labels, month, boundary, observations, returns, identity,
  ascending sort, integer tail count, retained indexes, arithmetic mean,
  direction, attempt, risk, stop, spread, and lifecycle are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  `XNGUSD.DWX` D1 history and MT5-native state supply every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, arithmetic, sorting,
  comparison, ATR, and execution state only; no conditional-variance model,
  trained output, banned signal, external feed, grid, martingale, scale-in,
  or pyramid.

## Claim and kill boundary

Every valid nonzero central mean may qualify, giving a pre-result density
prior near twelve decisions per year. This is not market evidence. Q02 must
retire below five completed positions in any full post-warm-up year, at zero
trades, with nonpositive governed economics, or on any label, month, return,
trim, mean, side, attempt, risk, lifecycle, or determinism defect.

The new logic is materially different from certified `QM5_12567`, but G0 does
not prove decorrelation. Q09 alone owns the realized portfolio result. No
failure may be rescued by changing the sample, trim formula, direction,
carrier, risk, hold, or by adding endpoint agreement, weekday, seasonal,
event, volatility, external, or prior-result state.

## Safety boundary

This packet supports one Strategy Card, one branch-only V5 build, strict
compile/Q01, and one paced non-live Q02 handoff only. It does not authorize a
manual backtest, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
control, or decorrelation claim.
