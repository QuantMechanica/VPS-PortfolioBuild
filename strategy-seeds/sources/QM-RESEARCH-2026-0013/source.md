---
source_id: QM-RESEARCH-2026-0013
title: Harness-v2 golden-test evidence for anchor-configurable session range breakout
source_type: internal_research
source_author: multi-agent:Fable+Codex
source_model: claude-fable-5-1+gpt-5.6-sol
created: 2026-09-22
originating_task_id: 955537dd-63d2-4f84-a1b1-c4d2499b78c4
status: reviewed
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0013
---

# Harness-v2 golden-test evidence for anchor-configurable session range breakout

## Research provenance

This source packages the reviewed harness-v2 golden test as the R1 input for a
new **research instrument**. The underlying family-F1 sweep was a deterministic
closed-bar execution study over the factory's `.DWX` custom history. The v2
review corrected placement quotes, stop-distance acceptance, lone-leg OCO
cancellation, gap fills, and native high-impact release tagging. Its conclusion
was deliberately limited: mechanics passed, while economic equivalence to MT5
remained unknown.

The bound sweep evaluated 315 defined cells, of which 314 were populated. Only
three were routed `WORTH_MT5_TEST`: NZDJPY A2, USDJPY A3, and USDJPY A4. Their
selection-period measurements and exact requested MT5 inputs are copied into
`harness_v2_cells.json`. That extract binds the checked-in v2 sweep, golden
comparison, review README, and the prior control-plane mapping by path, commit,
and SHA-256. No new search, retuning, or economic promotion is performed here.

This source authorizes only a neutral MT5 falsification build. It does not make
the EA a roster candidate, does not supersede the permanent negative lineage of
QM5_41485, and does not confer a pipeline or live verdict.

## Structural cause

A completed intraday range represents a bounded consolidation. Stop orders at
both range edges test whether the next session transition expands directionally.
The opposite edge supplies a mechanical initial stop, while a two-bar trailing
rule retains extended moves. The same geometry can be measured at different
session anchors without changing order semantics, so clock normalization and
range length must be genuine inputs rather than compiled constants.

## Mechanical specification

- Lineage: reproduce the QM5_13213 session-range breakout mechanics, with the
  hardened fail-closed OCO behavior already reviewed in QM5_41485. The chart
  timeframe is M30; strategy decisions run once per completed M30 bar while
  order and position management remain per tick.
- Clock: `anchor_clock` is one of `SERVER_RAW`, `GMT3_EQUIVALENT`, or `UTC`.
  Non-server modes convert through the framework broker-to-UTC helpers. The A
  anchor is 06:00 and flat is 18:00 in fixed GMT+3-equivalent time, which maps
  to DXZ raw server 05:00/17:00 in winter and 06:00/18:00 in summer.
- Inputs: range start hour/minute, range end hour/minute, flat hour/minute,
  60-minute-grid offset, and range-bar count are bounded runtime inputs. `OnInit`
  validates bounds, chronology, duration, and supported M30 grid alignment; it
  must not freeze a particular anchor or N value.
- Grid: each complete 60-minute strategy bar is reconstructed from two closed
  M30 halves. Offset 0 uses `hh:00..hh+1:00`; offset 30 uses
  `hh:30..hh+1:30`. A missing half invalidates the day's setup. Range start
  and end must span exactly `range_bars * 60` minutes in the selected clock.
- Range/filter: range high and low cover the requested completed grid bars.
  ATR(14) is the simple average of true range on the same grid. Reject when
  width is below 0.4 ATR or above 2.5 ATR.
- Entry/OCO: at the first eligible tick at or after the anchor, place a buy stop
  at the range high with SL at the range low and a sell stop at the range low
  with SL at the range high. No take profit. If either send fails, cancel the
  survivor and record no trade. A fill cancels the peer. Maximum one attempt
  and one position per selected-clock day.
- News: mandatory DXZ high-impact PRE30/POST30 placement blackout. Retry only
  inside the configured 60-minute post-anchor window. Stale-news tolerance is
  fail-closed and never exceeds 336 hours. News does not force-close an open
  position.
- Management: after movement reaches 1.0 times the distance from open price to
  the current stop, trail to the lower/higher of the two latest complete grid
  bars when that improves the stop. At the configured flat time, close the
  position and cancel pending orders on the first available tick. Framework
  Friday-close and risk controls remain active.
- Backtest risk: every falsification preset uses `RISK_FIXED=1000` and
  `RISK_PERCENT=0`; no live or AutoTrading authority exists.

## Registered cells

| cell | symbol | range | harness trades | E[R] | PF | worst-year DD |
|---|---|---:|---:|---:|---:|---:|
| A2 | NZDJPY.DWX | 04:00-06:00 GMT+3 | 970 | +0.0570 | 1.122 | 21.00R |
| A3 | USDJPY.DWX | 03:00-06:00 GMT+3 | 893 | +0.0675 | 1.161 | 21.87R |
| A4 | USDJPY.DWX | 02:00-06:00 GMT+3 | 821 | +0.0753 | 1.184 | 18.56R |

The intended tester window is 2018-07-02 through 2022-12-31. Each cell is an
independent frozen experiment even when two cells share the same EA/symbol.

## Golden comparison contract

After authentic Q02 reports exist, compare each cell independently against the
bound harness row. Emit:

- `EQUIVALENT` when the tester has a valid row, the trade count is within 15%
  of the harness, the absolute E[R] difference is at most 0.03R, and the
  absolute PF difference is at most 0.10;
- `HARNESS_OVERSTATES` when a valid tester row misses any equivalence bound and
  the harness value is more favorable on the failed measure; or
- `UNKNOWN` when a like-for-like tester row is absent, invalid, or execution
  facts cannot be bound.

These are research-comparison labels, not factory pipeline verdicts.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:         b5a2c54a1ccd9b9a3b32db353c08ca906e256dc54edc85a092b6d95cdd3c11ac
lineage.json:          eaf614e47edac7a84c199d9903a8b3e5b486d7155a996f4d4fdaf38e0a1542bd
critic_receipt.json:   7153b706a2158ddcffb9bac329dc80b1fc43e3ef7759cfc591280f2f2b38019e
harness_v2_cells.json: 5d23d62e567820df003e310bbcd14a4979f0d0ed5bad48e85ed86f73c8a535cf
```
