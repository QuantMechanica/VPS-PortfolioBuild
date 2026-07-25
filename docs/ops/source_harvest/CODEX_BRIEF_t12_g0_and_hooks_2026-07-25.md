# CODEX BRIEF — Tranche 12 G0 review + hook implementations (20142/20143/20144)

Repo: C:\QM\repo (branch agents/board-advisor). Same contract as T11
(CODEX_BRIEF_t11_g0_and_hooks_2026-07-25.md).

## Part A — G0 review (you approve; Claude built the cards)

Cards:
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20142_mtf-ema25-align-h4_card.md
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20143_macd-bb-campaign-m5_card.md
- D:\QM\strategy_farm\artifacts\cards_review\QM5_20144_ichimoku-atr-cloud-d1_card.md

Check each against 00_source.md + 03_reconciliation.md +
04_spec_final.md in docs/ops/source_harvest/strategies/
STR-{088-4x25ma-mtf-trend,104-macd-bb-campaign-m5,118-ichimoku-atr-cloud-d1}/
(blind phase over — read everything). R1-R4 per QB criteria. APPROVE →
set g0_status: APPROVED + g0_approval_reasoning in the card frontmatter.
REJECT → objection into docs/ops/source_harvest/G0_REVIEW_T12_2026-07-25.md,
card untouched. Also SIGN OFF (or contest) the two T11 post-integration
fixes flagged in task 26ed93c8's close-review verdict: the 2-axis news
hook lift and the 20138 perf-allowed pooled-stochastic marker.

## Part B — hook implementations

Write V5 hook sections (from `input group "Strategy"` through the last
hook, header comment listing any PRE-MARKER wiring) to:
- D:\QM\reports\source_harvest_build\hooks_QM5_20142.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20143.mq5.txt
- D:\QM\reports\source_harvest_build\hooks_QM5_20144.mq5.txt

Authority: 04_spec_final.md each. T11 artifact format.

Killer rules (binding, postmortem-derived):
1. NEVER call QM_IsNewBar() in hooks — own static datetime guards.
2. ZeroMemory(req) + req.symbol_slot on every QM_EntryRequest.
3. Closed bars only (shifts ≥ 1); `// perf-allowed` INLINE on any
   flagged CopyRates/CopyBuffer/raw-indicator line.
4. Rejected modifies → per-bar retry latch (no tick storms).
5. Pending strategies (20143): EntrySignal returns false, state
   machine in ManagePosition. 20142/20144 enter via EntrySignal
   (market entries); 20144's cross-exit lives in Manage with a
   per-bar retry latch.
6. Use the CURRENT news API: qm_news_temporal/qm_news_compliance +
   QM_NewsAllowsTrade2, fallback qm_news_mode_legacy — the T11
   artifacts used stale `qm_news_mode` and broke compile; do not
   repeat.
7. Pooled indicator readers (QM_EMA etc.); raw handles only
   pool-registered with inline perf-allowed + justification (T11
   20138 precedent). iIchimoku for 20144 with the OnInit causal
   self-test from the final spec; iBands for 20143 with the
   plot-shift-1 alignment self-test.
8. Magic slots start at 0 (magic_numbers.csv rows are authoritative).
9. No invented commission/swap/DST values; UK/US session arithmetic
   for 20142 per QM_DSTAware patterns (QM5_20119 precedent).

## Delivery

Commit review doc (+ cards if approved) with pathspecs; update-task to
REVIEW with artifacts. Final line:
`T12_G0_HOOKS_DONE: <verdicts> | <hook paths> | T11_FIXES: SIGNED_OFF|CONTESTED`
