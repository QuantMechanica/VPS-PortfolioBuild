# Codex brief — Tranche 2 G0 review + hook implementation (20101/20102/20103)

Two-part task, same pattern as the 2026-07-24 tranche-1 brief.

## Part A — G0 card review (reciprocal approval; you approve, builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20101_simplicity-ha-ema100-london_card.md   (STR-002)
- QM5_20102_prevday-breakout-close-edge_card.md   (STR-003)
- QM5_20103_daylight-wpr-smma-m15_card.md         (STR-004)

Review each against Q00 R1-R4 + approve-card validator criteria (year+URL in
running text, literal TF token in body, flat ea_id in body, target_symbols
frontmatter, citations with locations). Cross-check the card against
docs/ops/source_harvest/strategies/<dir>/00_source.md and 04_spec_final.md
(now includes 03_reconciliation.md — your 02 specs won most conflicts; note
STR-004 C3: your Red=8/Blue=21 mapping was CONFIRMED by the ledger row and
claude's objection withdrawn — verify you agree with the final pullback-depth
reading). For each card: verdict APPROVE (edit `g0_status: APPROVED` +
`g0_approval_reasoning:` into the frontmatter yourself) or REJECT with
required fixes. Deliver G0_REVIEW_T2.md to D:\QM\reports\source_harvest_build\.

## Part B — Hook implementation (only for cards you approved)

For each approved EA implement the STRATEGY SECTION ONLY (inputs + statics +
helpers + the five Strategy_* hook bodies) per the authoritative
04_spec_final.md, as splice-ready MQL5 text:
- D:\QM\reports\source_harvest_build\hooks_QM5_20101.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20102.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20103.mq5.txt

Conventions (binding, from tranche 1 + operating rules):
- Base: framework/templates/EA_Skeleton.mq5 — do NOT modify skeleton code;
  your text replaces only the marked strategy section.
- `input group "Strategy"` literal (build_check).
- Closed-bar reads only (shifts >=1); own static new-bar guards — NEVER call
  QM_IsNewBar() in hooks (the skeleton's entry gate consumes that edge; see
  tranche-1 20096 postmortem).
- ZeroMemory(req) + req.symbol_slot = qm_magic_slot_offset in EntrySignal.
- Raw series calls (iTime/Bars/CopyRates/CopyBuffer/iHigh/iLow) need inline
  `// perf-allowed: <reason>` markers on flagged lines, bounded work,
  new-bar-gated.
- Events: use registered names (STRATEGY_ENTRY, STRATEGY_EXIT,
  SETUP_DATA_MISSING, SETUP_CONFIG_INVALID, TM_*); JSON payloads via
  QM_LoggerEscapeJson where strings are interpolated.
- QM helpers: QM_IndMA/QM_IndicatorReadBuffer/QM_ReadBar/QM_StopFixedPips/
  QM_TakeFixedPips/QM_TM_MoveSL/QM_TM_ClosePosition(+partial variant — check
  QM_TradeManagement.mqh for the exact partial-close entry point)/QM_LogEvent.
- Broker↔UTC: reuse the framework's existing conversion primitive (as used by
  the news filter internals) — grep QM_NewsFilter.mqh/QM_Common.mqh; do NOT
  invent DST arithmetic. If no reusable primitive exists, implement
  offset = TimeCurrent()-TimeGMT() measured per tick, and note it.
- 20101: netting partial-close 2/3 at +1R with once-only semantics + per-bar
  retry latch (20098 TP-storm lesson); campaign risk 1% total.
- 20103: in-EA SMMA-on-WPR recursion, fixed 400-bar seed, cached per closed
  bar; ONE unshifted SMMA(5) handle read at [1] and [1+displacement].
- Restart-safety per the final specs (replay/derive, no files).

Constraints: read-only on the repo; write ONLY the deliverables above +
G0_REVIEW_T2.md; no builds, no registry writes, no DB writes, no terminals.
