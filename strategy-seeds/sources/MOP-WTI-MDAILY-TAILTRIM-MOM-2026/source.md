---
source_id: MOP-WTI-MDAILY-TAILTRIM-MOM-2026
title: WTI completed-month daily single-tail-trim momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_wti_monthly_daily_tail_trim_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - MOP-WTI-TRIMMEAN-2026
  - MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MOP-WTI-TRIMMEAN-2026: 63F8C5FC06BAE2D90B50673C6B7B966FBAF5962150D70F695DD3DA8DBB221FA8
  MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026: 62FB3C500F4176047667F5194A446BFA7C53B0D1F4D3E523F226449416D398F4
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - wti-mdaily-tailtrim-mom
---

# WTI Completed-Month Daily Single-Tail-Trim Momentum Source Packet

## Approved Source Of Record

The canonical trading source is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse
Heje Pedersen (2012), "Time Series Momentum," *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site. The reproducible receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
the canonical faculty URL, retrieval time, 976,459 bytes, 23 pages, and PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

Two governed child packets fix already approved, auditable translations:

- `strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md` defines a robust
  direction statistic by sorting returns, deleting explicitly declared tail
  observations, and summing the retained center. It operates on twelve
  disjoint monthly returns and deletes two observations per tail.
- `strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`
  defines exact WTI completed-month packaging: every 17-23 daily return ending
  in the immediately completed month, an adjacent older boundary close,
  endpoint identity, durable attempt state, and next-month lifecycle. Its
  signal is corrected lag-one persistence, not a trimmed return center.

Every parent record was read completely before approval. The durable OWNER
authorization is
`decisions/2026-08-23_wti_monthly_daily_tail_trim_momentum_source_approval.md`,
committed before extraction at `77dca19cb`. No blocked page, inferred source
table value, secondary performance summary, or unrecorded result is used.

## Source Findings Used

Moskowitz, Ooi, and Pedersen:

- test each instrument's own return at monthly lags one through sixty and
  report positive continuation over the first twelve monthly lags;
- form deterministic time-series-momentum positions from own past returns and
  renew them monthly;
- report a pooled commodity `k=1`, `h=1` implementation; and
- explicitly include NYMEX WTI crude in the commodity universe.

These findings support testing an own-price WTI monthly continuation carrier.
They do not establish a WTI-only one-month result, a within-month daily-return
estimator, or a single-tail deletion rule. The source uses rolling liquid
futures, excess returns, portfolio aggregation, and ex-ante volatility
scaling. The Darwinex continuous CFD, close-to-close log returns, exact broker
month, daily robust statistic, fixed cash risk, ATR stop, spread cap, and
restart ledger are QM translations.

No source alpha, return, probability, density, Sharpe ratio, drawdown, trade
count, cost, WTI-only efficacy, CFD equivalence, or portfolio-correlation
statistic transfers.

## Bounded QM Mechanization

On the first executable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
reconstruct every completed D1 close whose uniformly normalized timestamp
belongs to the immediately preceding calendar month plus one adjacent older
close. Require 17 through 23 completed-month sessions. Starting from the older
boundary, form exactly one chronological log return ending on every session
of the completed month.

For `n` returns `r[0]..r[n-1]`:

```text
raw_sum   = sum(r[j]), j=0..n-1
sorted    = ascending copy of r[0..n-1]
inner_sum = sum(sorted[j]), j=1..n-2

inner_sum > 0 => BUY XTIUSD.DWX
inner_sum < 0 => SELL XTIUSD.DWX
otherwise     => FLAT
```

The raw sum must equal the direct boundary-to-final log return within
`1e-10`. Exactly one array element at the lower endpoint and one at the upper
endpoint is excluded. Tied extremes are valid because deleting any one equal
copy produces the same sum. Exact-zero constituent returns are valid. A zero
inner sum, nonfinite value, nonpositive close, endpoint mismatch, malformed
month, or invalid session count consumes the month flat. Neither raw endpoint
direction nor inner-sum magnitude gates or scales risk.

The deletion leaves 15 through 21 returns. It is fixed before any candidate
result and tests whether the central daily WTI path contains directional
information after removing one upside and one downside shock. It is not a
fitted threshold, standard score, volatility estimate, confidence measure,
or risk multiplier.

## Exact Event Contract

1. Require exact `XTIUSD.DWX`, D1, and entry no later than 180 elapsed minutes
   after the raw first host D1 bar open of a new broker month.
2. Select one uniform energy-label convention for current and historical
   bars. Require the newest completed bar to belong to the immediately prior
   normalized calendar month. Within a fixed 45-bar buffer, require 17 through
   23 unique completed-month bars in strict reverse-time order and one
   adjacent older bar. Exclude current-month closes.
3. Reverse selected closes into chronological order beginning with the older
   boundary. Form one log return into every completed-month session, with no
   gap, overlap, duplicate, or omitted endpoint.
4. Verify the raw endpoint identity, sort a copy ascending without rounding,
   delete exactly indexes zero and `n-1`, and sum exactly indexes `1..n-2`.
5. Follow the inner-sum sign. Equality and every invalid state consume the
   month flat. Raw endpoint sign may agree or disagree and is diagnostic only.
6. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, or order submission. No outcome may retry that month.
7. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
   ceiling.
8. Close on the first tick in a later broker month, with a forty-calendar-day
   stale repair. Flatten malformed, duplicated, wrong-symbol, wrong-magic, or
   stopless owned exposure immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,630 registry identities, 1,298
cards, and 45 Strategy Wiki nodes using the actual Company Reference root. It
found no exact or fuzzy candidate collision and returned `CLEAN`. Evidence is
`artifacts/qm5_wti_mdaily_tailtrim_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- `QM5_20187_wti-tsmom1m` follows the untrimmed month endpoint.
- `QM5_20270_wti-trimmean-mom` deletes two returns per tail from twelve
  completed monthly returns spanning a year. This extraction deletes one
  return per tail from 17-23 daily returns spanning exactly one month.
- `QM5_41111_wti-mdaybreadth-mom` counts signs and requires raw endpoint
  agreement. This extraction uses magnitudes, no sign count, and no endpoint
  agreement gate.
- `QM5_41124_wti-mrms-coherence-mom` and
  `QM5_41126_wti-mpath-eff-mom` normalize the untrimmed endpoint by L2 or L1
  path scale. This extraction sorts and removes observations, with no scale
  quotient or threshold.
- `QM5_41127_wti-mdaily-persist-mom` centers returns and multiplies adjacent
  observations to gate the raw endpoint. This extraction discards chronology
  after return construction and uses no autocorrelation or endpoint gate.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback.

The exact WTI carrier, immediately completed month, older boundary, every
month-ending daily return, ascending sort, exactly one deleted observation per
tail, inner-return sum, symmetric continuation, consumed attempt, fixed risk,
and next-month exit are jointly load bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_SINGLE_TAIL_TRIM_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_WITHIN_MONTH_ROBUST_AGGREGATION_TRANSLATION_RISK`. The
  canonical child preserves a named-author peer-reviewed JFE paper with DOI,
  complete-read evidence, durable hashes, explicit WTI membership, own-return
  momentum, and governed robust-statistic and completed-month lineage. The
  daily horizon and one-per-tail deletion are untested translations.
- R2: `PASS`. Exact clock, label convention, month membership, observation
  bounds, chronology, return inclusion, endpoint identity, sort, deleted and
  retained indexes, zero handling, direction, attempt, risk, stop, spread
  gate, and lifecycle are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 calendar, ATR, spread, quote,
  position, deal, and persistent state supplies every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, sorting, addition,
  comparison, ATR, and execution state only; no trained output, banned signal,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

Every valid nonzero month can qualify, giving a pre-result density prior near
twelve decisions per year. This is not market evidence. Q02 must retire below
five completed positions in any full post-warm-up year, at zero trades, with
nonpositive governed economics, or on any label, month, return, sort,
tail-deletion, side, attempt, risk, lifecycle, or determinism defect.

Direct WTI exposure is economically different from the certified XAU, SP500,
NDX, and XNG book but does not prove decorrelation. Q09 alone owns the realized
portfolio result. No failure may be rescued by changing the trim count,
retained indexes, direction, observation inclusion, carrier, risk, hold, or by
adding an endpoint agreement, sign count, persistence, volatility,
seasonality, event, external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
