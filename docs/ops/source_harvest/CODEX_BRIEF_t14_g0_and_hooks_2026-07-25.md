# CODEX BRIEF — Tranche 14 G0 review + hook implementations (20150/20151/20152) — FINAL

Repo: C:\QM\repo (branch agents/board-advisor). Same contract as T13.

## Part A — G0 review (you approve; Claude built the cards)

Cards:
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20150_emacross-stochhook-fib-h4_card.md
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20151_dual-supertrend-confluence-h1_card.md
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20152_sma-cross-pullback-h1_card.md

Check vs 00/03/04 in docs/ops/source_harvest/strategies/
STR-{137-emacross-stochhook-fibtrail-h4,141-dual-supertrend-confluence,
143-sma-cross-pullback-h1}/. Audit specifically: the STR-137 hard-stop
deviation labeling (D1/D2) and cohort declaration; the STR-141
Supertrend recursion transcription into the card; the STR-143
EURUSD-only baseline. APPROVE → g0_status: APPROVED + reasoning in
frontmatter. REJECT → docs/ops/source_harvest/G0_REVIEW_T14_2026-07-25.md.

## Part B — hook implementations

Write V5 hook sections to:
- D:\QM\reports\source_harvest_build\hooks_QM5_20150.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20151.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20152.mq5.txt

Authority: 04_spec_final.md each. T13 artifact format (header lists
OnInit/PRE-MARKER wiring).

Killer rules (binding; all prior postmortems):
1. NEVER QM_IsNewBar() in hooks — own static datetime guards.
2. ZeroMemory(req) + req.symbol_slot on every QM_EntryRequest.
3. Closed bars only (shifts ≥ 1).
4. Rejected modifies/closes → per-bar retry latch.
5. NO raw CopyBuffer — QM_IndicatorReadBuffer for ALL buffer access
   incl. self-tests. Raw indicator handles only pool-registered with
   inline perf-allowed + justification (20150's CLOSE/CLOSE stoch
   needs this — 20138 precedent; 20152's LOWHIGH stoch uses the
   pooled QM_Stoch_K reader directly).
6. Current news API (qm_news_temporal/compliance + QM_NewsAllowsTrade2
   + qm_news_mode_legacy fallback).
7. 20151 Supertrend: implement the exact codex 02 §3 recursion with
   own closed-bar state arrays (no iCustom); CopyRates via the
   sanctioned pattern with inline perf-allowed where flagged.
8. Entry paths: 20150 + 20152 use EntrySignal (market entries via
   state machines readable from Filter/Entry); 20151 uses EntrySignal
   too (flip detection on closed bars); ALL manage-side stop ratchets
   live in ManagePosition with tighten-only guards.
9. 20150 fib ladder: server-stop ratchet AFTER qualifying closes,
   monotonic, capped at F(4.618); regime walk capped 500 bars.
10. Magic slots start at 0 per magic_numbers.csv.

## Delivery

Commit review doc (+ cards if approved) with pathspecs; update-task to
REVIEW. Final line:
`T14_G0_HOOKS_DONE: <verdicts> | <hook paths>`
