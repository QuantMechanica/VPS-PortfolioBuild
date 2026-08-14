---
source_id: 28681f5d-aa78-584e-9698-750d1402e485
title: Zhao-Ding-Yu-Kang Short-Term Commodity Momentum and Reversal
source_type: academic_working_paper_bounded_abstract_packet
status: approved_source_complete
approval_basis: decisions/2026-08-14_qm5_21504_xng_flowrev_g0.md
created: 2026-08-14
cards_extracted:
  - QM5_21504_xng-flowrev
---

# Zhao-Ding-Yu-Kang bounded source packet

## Source of record

Shen Zhao, Yiyi Ding, Jianfeng Yu, and Wenjin Kang (2026),
"Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity
Markets," SSRN working paper 6425598, posted 2026-03-16,
DOI `10.2139/ssrn.6425598`.

Canonical URL:
`https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598`.

This is the one strategy source for lineage. The runtime source record is
`D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md`.
The strategy-farm database records the source as `done`, priority 84, and the
approved-card reservoir records `QM5_21504` with `g0_status: APPROVED`.

## Bounded material reviewed

The governed research note was read completely. It records that the SSRN and
ResearchGate full-text endpoints were inaccessible and that the accessible
bounded material was the paper metadata plus abstract/methodology summaries
cross-checked against the Lingnan College seminar listing. No inaccessible
table, coefficient, return, or parameter is reconstructed.

The usable source finding is narrow:

- weekly commodity returns are decomposed into a speculative-flow component
  and a residual component;
- the speculative-flow component predicts the following week's return in the
  opposite direction; and
- the authors associate that reversal with trend-chasing speculative flow.

The source uses investor-position information. It does not specify a tick-
volume signal, an outright XNG CFD rule, an ATR stop, or the parameter values
used by this card.

## Reproducible retrieval evidence

On 2026-08-14 the deterministic QM source router classified the canonical SSRN
URL as `PERMISSION_REQUIRED`, adapter `generic`, adapter state `ROUTER_ONLY`,
and lead status `DEFERRED:SOURCE_POLICY`. No alternate proxy, authentication,
or access-control workaround was attempted. This packet therefore preserves
the previously OWNER-approved bounded research note and explicitly limits all
claims to its recorded abstract/methodology material.

## Bounded carrier translation

QM has no approved investor-position runtime feed. The card tests a disclosed
price/volume proxy rather than claiming replication: unusually high native MT5
D1 tick volume is treated as a candidate marker of flow-dominated weeks.

At the first completed-D1 transition into each framework broker-week bucket:

1. Sum tick volume over the latest five completed XNG D1 bars.
2. Compare that sum with 40 earlier, non-overlapping five-bar volume sums.
3. Compute its empirical percentile rank with ties included.
4. If rank is at least 75%, fade the sign of the same five-bar close return.
5. Hold for at most five completed D1 bars, subject to Friday close and a
   frozen `2.5 * ATR(14,D1)` broker hard stop.

The attempted week is persisted before history, signal, news, spread, quote,
or order gates. A stop or failed execution gate cannot cause same-week retry.

This is a falsification of the tick-volume proxy. Neither the source's futures
result nor the runtime research note establishes that tick volume identifies
speculator flow, that XNG will reverse, or that the resulting return stream is
uncorrelated with the certified book.

## Reputable-source criteria

- R1: PASS. Exactly one identified source and one durable `source_id`; the
  source URL, title, authors, date, DOI, access boundary, and bounded research
  note are recorded. Reputation is not used as a substitute for testing.
- R2: PASS. Cadence, completed-bar support, non-overlapping volume windows,
  percentile rule, direction, stop, hold, retry rule, and risk are mechanical.
- R3: PASS for the disclosed proxy. `XNGUSD.DWX` D1 close and tick volume are
  native MT5 fields. No investor-position or external feed is required.
- R4: PASS. The carrier is deterministic, owns one position under one magic,
  and has no trained output, PnL-dependent fit, grid, martingale, or scale-in.

## Non-duplicate and adverse-family boundary

- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only cumulative-RSI
  pullback with a slow price trend filter. This candidate is symmetric,
  weekly, raw-return based, and conditioned on a 40-window tick-volume rank.
- `QM5_13102_xng-1w-rev-vol` fades a thresholded five-day shock only when a
  rolling realized-volatility percentile is high, then permits a neutral-band
  exit. It passed Q02 and failed Q04. This candidate has no return-magnitude
  threshold, no realized-volatility regime, and no neutral-band exit; volume
  rank is its only signal conditioner. The Q04 failure is adverse family
  evidence and grants no waiver or parameter change.
- `QM5_12817_xng-volshock-fade` and longer-horizon XNG reversal carriers use
  shock size, volatility, or multi-month formation, not non-overlapping tick-
  volume ranks.
- Storage, weather, expiry, weekday, carry, trend, and relative-value XNG
  families use different information objects or clocks.

The canonical pre-allocation checker found no exact identity after normalizing
the strategy ID to `ZHAO-ST-MOMREV-2026_XNG_S03`. Its expected fuzzy matches
are same-source weekly momentum/reversal siblings. Manual verdict:
`CLEAN_XNG_WEEKLY_TICK_VOLUME_CONDITIONED_REVERSAL_AFTER_FAMILY_REVIEW`.

## Kill and safety boundary

Q02 retires the candidate below five completed trades per full post-warm-up
year or on nonpositive governed economics. Later portfolio evidence alone may
establish correlation. Do not change the five-bar support, non-overlapping
baseline, tick-volume field, 75% gate, fade direction, weekly attempt, stop,
hold, or risk to rescue a failure.

This source packet authorizes one branch-only, non-live build and one paced
Q02 handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, or AutoTrading change.
