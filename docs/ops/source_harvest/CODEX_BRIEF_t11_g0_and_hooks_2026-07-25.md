# CODEX BRIEF — Tranche 11 G0 review + hook implementations (20138/20139/20140)

Repo: C:\QM\repo (branch agents/board-advisor). Same contract as
tranches 2-10 (T10 pattern: G0 verdicts + hooks artifacts).

## Part A — G0 review (you are the approver; Claude built the cards)

Cards:
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20138_stoch-ema50-pullback-h4_card.md
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20139_dibs-inside-bar-h1_card.md
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20140_roundnum-sma50-h1_card.md

Check each against 00_source.md + 03_reconciliation.md + 04_spec_final.md
in the matching docs/ops/source_harvest/strategies/STR-08{5,6,7}-*/ dir
(you may read everything now — blind phase is over). R1-R4 verdicts per
QB source criteria. If APPROVE: set `g0_status: APPROVED` +
`g0_approval_reasoning: "..."` in the card frontmatter yourself. If
REJECT: write the objection into a G0_REVIEW_T11 section of your review
doc and do NOT touch the card. Write the review doc to
docs/ops/source_harvest/G0_REVIEW_T11_2026-07-25.md.

## Part B — hook implementations (one artifact per EA)

Write full V5 hook sections (from `input group "Strategy"` through the
last hook function, plus a header comment listing any PRE-MARKER wiring
you need) to:
- D:\QM\reports\source_harvest_build\hooks_QM5_20138.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20139.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20140.mq5.txt

Authority: the 04_spec_final.md of each strategy. Follow the T10
artifact format (see hooks_QM5_20129/20130/20131.mq5.txt).

Killer rules (postmortem-derived, binding):
1. NEVER call QM_IsNewBar() inside hooks — the skeleton's entry gate
   already consumes it (20096 postmortem). Use your own static
   datetime bar guards.
2. ZeroMemory(req) + set req.symbol_slot on every QM_EntryRequest.
3. Closed bars only (CopyRates/CopyBuffer shifts ≥ 1); `// perf-allowed`
   INLINE on the flagged CopyRates/CopyBuffer line itself.
4. Rejected OrderModify/PositionModify → per-bar retry latch, never
   tick-storm retries (20098 postmortem).
5. Partial close (20139): QM_TM_PartialClose fraction of ORIGINAL
   volume, QM_TM_NormalizeVolume down, once-latch, QM_EXIT_PARTIAL
   event (20101/20098 precedent).
6. Pending-order strategies (20139/20140): EntrySignal returns false;
   the pending state machine lives in ManagePosition (house pattern).
   20138 uses EntrySignal normally (market entry).
7. Magic slots start at 0 (EURUSD=0… per magic_numbers.csv rows).
8. EURJPY pip = 10*_Point (3-digit); no invented commission/swap/DST.

## Delivery

Commit the review doc (+ cards if approved) with pathspecs. Then
update-task to REVIEW with artifact paths. Finish with the line:
`T11_G0_HOOKS_DONE: <verdicts> | <hook paths>`
