# Codex brief — Tranche 3 G0 review + hook implementation (20104/20105/20106)

Same two-part protocol as CODEX_BRIEF_t2_g0_and_hooks_2026-07-24.md.

## Part A — G0 review (reciprocal approval; builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20104_notable-number-fade-m5_card.md      (STR-008)
- QM5_20105_notable-number-breakout-m5_card.md  (STR-009)
- QM5_20106_daily-wick-stop-breakout_card.md    (STR-012)

Check R1-R4 + validator criteria against 00_source.md + 04_spec_final.md +
03_reconciliation.md. KEY reconciliation outcomes to verify you accept:
- Session clock resolved to LITERAL BROKER HOURS via your own "(London+2h)"
  decomposition (London civil +2h ≡ NY-close broker clock year-round) — an
  MQL5 IANA-DST implementation would violate the no-invented-DST hard rule.
- USDJPY excluded from the 20104 cohort (Q02 frequency floor >=5/yr,
  OWNER-ratified economics rule) — your source-faithful inclusion was
  overridden by the binding house rule; the setup is documented, unbuilt.
- Your open-to-open crossing trigger, one-fire latch, percent-of-price
  exits, +2-pip sourced offsets (20106), cancel-at-roll all ADOPTED.
Verdict per card: APPROVE (edit g0_status: APPROVED + g0_approval_reasoning
into frontmatter) or REJECT with fixes. Deliver G0_REVIEW_T3.md.

## Part B — Hooks (approved cards only)

Deliver splice-ready strategy sections per the authoritative 04_spec_final:
- D:\QM\reports\source_harvest_build\hooks_QM5_20104.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20105.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20106.mq5.txt

Binding conventions (tranche 1+2): skeleton untouched; input group
"Strategy" literal; closed-bar reads; own static bar guards (NEVER
QM_IsNewBar in hooks); ZeroMemory+symbol_slot; perf-allowed markers on raw
series calls (bounded, bar-gated); registered event names; framework
helpers (QM_ReadBar/QM_LogEvent/QM_TM_*; pending path via QM_EntryRequest —
check QM_Entry.mqh for the pending order type/expiration fields);
fleet hook-placement: warmup/params in NoTradeFilter, session/exposure/latch
in EntrySignal, pending lifecycle in Manage.
20104/20105 shared machinery: implement the lattice/crossing/latch helpers
identically in both files (duplicated code is fine — EA files are
self-contained).
20104 note: window HHMM ints, [start,end) broker clock, start==end => all
day; the per-symbol matrix ships via set files — code defaults = EURUSD row
(20104) / CADJPY row (20105).
Constraints: read-only repo; deliverables only; no builds/DB/registry/
terminals.
