---
source_id: ZHAO-WTI-FLOWSWITCH-2026
title: Zhao-Ding-Yu-Kang weekly momentum/reversal — bounded WTI two-tail flow proxy
source_type: academic_working_paper_bounded_abstract_packet
status: approved_source_complete
approval_basis: decisions/2026-08-14_qm5_21521_wti_flow_switch_g0.md
created: 2026-08-14
cards_extracted:
  - QM5_21521_wti-flow-switch
---

# Zhao-Ding-Yu-Kang bounded WTI flow-regime source packet

## Source of record

Shen Zhao, Yiyi Ding, Jianfeng Yu, and Wenjin Kang (2026), "Momentum and
Reversal on the Short-Term Horizon: Evidence from Commodity Markets," SSRN
working paper 6425598, posted 2026-03-16, DOI `10.2139/ssrn.6425598`.

Canonical URL:
`https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598`.

The complete governed research note is
`D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md`.
The canonical family record is
`strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`.
This packet narrows that lineage to one approved WTI two-tail card; it does
not expand the parent source's evidentiary claims.

## Bounded material reviewed

The governed note records that SSRN and ResearchGate full-text endpoints were
inaccessible. Its accessible evidence consists of paper metadata and
abstract/methodology summaries cross-checked against a Lingnan College
seminar listing. No inaccessible table, coefficient, result, or parameter is
reconstructed.

The usable finding is limited to the paper's weekly decomposition: the
residual component positively predicts next-week commodity returns, while
the speculative-flow component predicts reversal. The decomposition itself
uses investor-position data. QM has no approved runtime position/COT feed.

## Reproducible retrieval evidence

On 2026-08-14 the deterministic QM source router classified the canonical
SSRN URL as `PERMISSION_REQUIRED`, adapter `generic`, adapter state
`ROUTER_ONLY`, and lead status `DEFERRED:SOURCE_POLICY`. No alternate proxy,
authentication, cached mirror, or access-control workaround was attempted.
This packet uses only the already governed bounded research note.

## Bounded carrier translation

The card tests a disclosed native-data proxy instead of claiming replication:
the latest five-D1 WTI tick-volume sum is ranked against 40 earlier,
non-overlapping five-bar sums. Low-tail volume is treated as a candidate
marker of a quiet, residual-dominated week; high-tail volume is treated as a
candidate marker of a flow-dominated week.

At the first D1 bar of a new framework broker week:

1. Sum native tick volume over the latest five completed WTI D1 bars.
2. Rank the sum against 40 earlier, non-overlapping five-bar sums using
   `100 * count(baseline <= current) / 40`, ties included.
3. If the rank is at most 25%, follow the latest five-bar close-return sign.
4. If the rank is at least 75%, fade that return sign.
5. Consume ranks strictly between 25% and 75% flat.
6. Hold at most five completed D1 bars, subject to framework Friday close and
   a frozen `2.75 * ATR(14,D1)` broker hard stop.

The attempted week is persisted before any fallible gate. Return magnitude
and rank never scale risk. This ternary state machine tests both source
directions on one physical-energy carrier without treating middle-volume
weeks as either regime.

The source does not establish that MT5 tick volume identifies either paper
component, that the WTI proxy is profitable, or that it is uncorrelated with
the certified book. Q02 must falsify density and economics; Q09 alone may
evaluate realized portfolio overlap.

## Reputable-source criteria

- R1 PASS: one identified source with title, authors, date, URL, DOI,
  retrieval boundary, and complete governed research note.
- R2 PASS: cadence, exact completed-bar support, disjoint windows, percentile
  convention, two-tail direction map, middle state, stop, hold, retry rule,
  and risk are deterministic.
- R3 PASS for the disclosed proxy: `XTIUSD.DWX` D1 close and native tick
  volume are available in MT5; no investor-position or external feed is
  required or claimed.
- R4 PASS: deterministic arithmetic, one position per magic, and no trained
  output, PnL-dependent adaptation, grid, martingale, scale-in, or pyramid.

## Non-duplicate and adverse-family boundary

- `QM5_12567` is a long-only cumulative-RSI pullback above a slow trend, not
  a weekly price/volume state machine.
- `QM5_13049` and `QM5_13050` use thresholded WTI returns plus
  realized-volatility percentiles and signal exits; this card uses
  unthresholded return sign, disjoint native tick-volume ranks, and no signal
  exit.
- `QM5_21504` is an XNG top-tail-only fade and `QM5_21520` is an XNG
  bottom-tail-only continuation. This card maps both disjoint tails to
  opposite WTI directions in one locked ternary state machine and consumes
  the middle half flat.
- WTI trend, calendar, EIA, expiry, carry, relative-value, and robust-momentum
  families do not implement this two-tail volume-state direction switch.

Manual verdict:
`CLEAN_WTI_WEEKLY_TWO_TAIL_FLOW_REGIME_SWITCH_AFTER_SOURCE_FAMILY_REVIEW`.

## Kill and safety boundary

Retire below five completed trades per full post-warm-up year or on
nonpositive governed economics. Do not rescue failure by changing the
five-bar support, disjoint baseline, native tick-volume field, 25/75
boundaries, middle-flat state, tail directions, weekly attempt, stop, hold,
or fixed-risk contract.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change,
or portfolio-gate edit.
