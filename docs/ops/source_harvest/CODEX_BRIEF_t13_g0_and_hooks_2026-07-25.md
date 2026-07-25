# CODEX BRIEF — Tranche 13 G0 review + hook implementations (20146/20147/20148)

Repo: C:\QM\repo (branch agents/board-advisor). Same contract as T12.

## Part A — G0 review (you approve; Claude built the cards)

Cards:
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20146_london-orb-3candle-h1_card.md
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20147_ndx-ema50-momentum-d1_card.md
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20148_usdjpy-pretokyo-straddle_card.md

Check vs 00_source.md + 03_reconciliation.md + 04_spec_final.md in
docs/ops/source_harvest/strategies/STR-{120-london-orb-3candle-h1,
127-ndx-ema50-momentum-d1,132-usdjpy-pretokyo-straddle}/ (blind phase
over). Note the two reconciliation resolutions to audit specifically:
the 16:45-ET cutoff derivation for STR-120 (FLAG-120-01 resolution)
and the volume-splittability date-reject rule for STR-132. APPROVE →
g0_status: APPROVED + reasoning in frontmatter. REJECT → objection in
docs/ops/source_harvest/G0_REVIEW_T13_2026-07-25.md, card untouched.

## Part B — hook implementations

Write V5 hook sections to:
- D:\QM\reports\source_harvest_build\hooks_QM5_20146.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20147.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20148.mq5.txt

Authority: 04_spec_final.md each. T12 artifact format (header lists
any PRE-MARKER/OnInit wiring).

Killer rules (binding; T11/T12 postmortems):
1. NEVER QM_IsNewBar() in hooks — own static datetime guards.
2. ZeroMemory(req) + req.symbol_slot on every QM_EntryRequest.
3. Closed bars only (shifts ≥ 1).
4. Rejected modifies/closes → per-bar retry latch.
5. All three are pending/state-machine strategies: EntrySignal returns
   false where the final spec says so (20146/20147/20148 all run their
   state machines in ManagePosition).
6. Current news API only (qm_news_temporal/compliance +
   QM_NewsAllowsTrade2, fallback qm_news_mode_legacy).
7. NO raw CopyBuffer anywhere — QM_IndicatorReadBuffer(handle, buf,
   shift) for any buffer access incl. self-tests (T12 lesson:
   EA_FRAMEWORK_RAW_COPYBUFFER is a hard rule without override).
   Pooled QM_* readers for EMA; raw handles only pool-registered with
   inline perf-allowed + justification.
8. Partial close (20148): QM_TM_PartialClose of ORIGINAL volume,
   QM_TM_NormalizeVolume, once-latch, QM_EXIT_PARTIAL event
   (20139/20101 precedent); volume-splittability gate at date start.
9. DST arithmetic: UK helper pattern (QM5_20119) for 20146 London
   open; US/ET helper (QM_DSTAware) for 20146 cutoff + 20148 anchors.
10. Magic slots start at 0 per magic_numbers.csv.

## Delivery

Commit review doc (+ cards if approved) with pathspecs; update-task to
REVIEW. Final line:
`T13_G0_HOOKS_DONE: <verdicts> | <hook paths>`
