---
source_id: ZHAO-XNG-QUIETFLOW-2026
title: Zhao-Ding-Yu-Kang residual momentum — bounded XNG quiet-flow proxy
source_type: academic_working_paper_bounded_abstract_packet
status: approved_source_complete
approval_basis: decisions/2026-08-14_qm5_21520_xng_flow_mom_g0.md
created: 2026-08-14
cards_extracted:
  - QM5_21520_xng-flow-mom
---

# Zhao-Ding-Yu-Kang bounded XNG quiet-flow source packet

## Source of record

Shen Zhao, Yiyi Ding, Jianfeng Yu, and Wenjin Kang (2026), "Momentum and
Reversal on the Short-Term Horizon: Evidence from Commodity Markets," SSRN
working paper 6425598, posted 2026-03-16, DOI `10.2139/ssrn.6425598`.

Canonical URL:
`https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598`.

The complete governed research note is
`D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md`.
The broader canonical family record is
`strategy-seeds/sources/ZHAO-ST-MOMREV-2026/source.md`. This packet narrows
that lineage to one approved XNG quiet-flow momentum card; it does not expand
the parent source's evidentiary claims.

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
authentication, or access-control workaround was attempted. This packet uses
only the already governed bounded research note.

## Bounded carrier translation

The card tests a disclosed native-data proxy instead of claiming replication:
an unusually low five-D1 XNG tick-volume sum is treated as a candidate marker
of a quiet, residual-dominated week, and the following position continues the
same five-D1 return sign.

At the first D1 bar of a new framework broker week:

1. Sum native tick volume over the latest five completed XNG D1 bars.
2. Rank the sum against 40 earlier, non-overlapping five-bar sums using
   `100 * count(baseline <= current) / 40`.
3. If the rank is at most 25%, follow the latest five-bar close-return sign.
4. Hold at most five completed D1 bars, subject to framework Friday close and
   a frozen `2.5 * ATR(14,D1)` broker hard stop.

The week is persisted as attempted before any fallible gate. Average- and
high-volume weeks stay flat. Tick-volume rank, not return magnitude or
realized volatility, is the only signal conditioner.

The source does not establish that MT5 tick volume identifies the paper's
residual component, that the XNG proxy is profitable, or that it is
uncorrelated with the certified book. Q02 must falsify density and economics;
Q09 alone may evaluate realized portfolio overlap.

## Reputable-source criteria

- R1 PASS: one identified source with title, authors, date, URL, DOI,
  retrieval boundary, and a complete governed research note.
- R2 PASS: cadence, exact completed-bar support, disjoint volume windows,
  percentile convention, direction, stop, hold, retry rule, and risk are
  mechanical.
- R3 PASS for the disclosed proxy: `XNGUSD.DWX` D1 close and native tick
  volume are available in MT5; no investor-position or external feed is
  required or claimed.
- R4 PASS: deterministic arithmetic, one position per magic, and no trained
  output, PnL-dependent adaptation, grid, martingale, scale-in, or pyramid.

## Non-duplicate and adverse-family boundary

- `QM5_12567` is long-only cumulative-RSI pullback plus slow trend, not a
  weekly price/volume continuation rule.
- `QM5_13101` conditions thresholded weekly momentum on low realized
  volatility and has a signal exit; this card conditions unthresholded weekly
  momentum on low tick volume and exits only by hold, hard stop, or Friday.
- `QM5_21504` admits top-quartile tick-volume weeks and reverses them; this
  card admits the non-overlapping bottom quartile and continues them.
- The unbuilt `QM5_21505` allocation is a silver carrier. It contributes no
  XNG build or validation evidence.

Manual verdict:
`CLEAN_XNG_WEEKLY_QUIET_FLOW_MOMENTUM_AFTER_SOURCE_FAMILY_REVIEW`.

## Kill and safety boundary

Retire below five completed trades per full post-warm-up year or on
nonpositive governed economics. Do not rescue failure by changing the
five-bar window, disjoint baseline, native tick-volume field, 25% cap,
continuation direction, weekly attempt, stop, hold, or fixed-risk contract.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
