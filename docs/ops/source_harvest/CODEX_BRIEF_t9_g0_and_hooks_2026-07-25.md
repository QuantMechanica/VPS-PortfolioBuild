# Codex brief — Tranche 9 G0 review + hooks (20125/20126/20127)

Same two-part protocol as tranches 2-8. Factory remains OFF — no terminal
interaction; deliverables only. (This brief runs via manual codex exec —
the orchestration lane is disabled while the factory is off.)

## Part A — G0 review (reciprocal; builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20125_rsi2-obos-scalp-m15_card.md  (STR-071; your persistence
  reading adopted)
- QM5_20126_abo-atr-straddle-h1_card.md  (STR-072; convergent)
- QM5_20127_sisyphus-2ma-rsi2-d1_card.md (STR-073; convergent; 7 slots)

Verify vs 00_source.md + 03_reconciliation.md + 04_spec_final.md.
Verdicts: APPROVE (edit g0_status + g0_approval_reasoning into the
frontmatter yourself) or REJECT with fixes. Deliver G0_REVIEW_T9.md to
D:\QM\reports\source_harvest_build\.

## Part B — Hooks (approved only)

hooks_QM5_20125/20126/20127.mq5.txt per 04_spec_final. Binding
conventions as tranches 2-8 (no QM_IsNewBar in hooks; own static guards;
ZeroMemory+symbol_slot; closed-bar reads; inline perf-allowed markers ON
flagged lines; registered events; fleet hook placement; BE/partial
latches with per-bar retry pacing). 20126: per-bar pending refresh in
Manage BEFORE EntrySignal places the fresh straddle (OnTick order:
Manage runs first); OCO delete on fill; per-tick 6xATR trail ratchet.
20127: ExitSignal touch-exit bar-gated; 7-slot cohort (defaults =
EURUSD row semantics identical across slots).
If any hook needs pre-marker wiring (includes/OnInit calls), put a
REQUIRED BUILDER WIRING header at the very top of the artifact as in
hooks_QM5_20123 — the builder now reads artifact headers first (T8
lesson).
