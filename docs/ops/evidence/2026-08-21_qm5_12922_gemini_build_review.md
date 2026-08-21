# QM5_12922 Gemini build review

- Review task: `800cfced-22aa-49e9-83d0-2ef5356ef2a4`
- Source task: `11468a5a-89fc-4872-b6ec-2a78250ae792` (Gemini, retained in `REVIEW`)
- Reviewed artifact: `artifacts/qm5_12922_build_result.json`
- Reviewed card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12922_ariel-first-half-month-idx.md`
- Verdict: **RECYCLE**

## Blocking findings

1. Calendar initialization is not restart-safe. When `have_prior_bar` is false, `Strategy_AdvanceCalendarState()` assigns trading-day index 1 irrespective of the actual day of the month. Starting or restarting the EA mid-month can therefore manufacture a T+1 entry signal. The implementation must reconstruct the current month's D1 trading-session ordinal or fail closed.
2. The mandatory news-blackout deferral is not implemented. The card says a T+1 high-impact-news entry is deferred one session. The EA sets `g_strategy_entry_due` only while the index equals 1; after a news-blocked T+1 attempt, the next D1 advance overwrites it to false. The trade is dropped rather than deferred to T+2.

These are material strategy-fidelity defects; no pipeline verdict is inferred.

## Checks that passed

- The approved card exists and the five generated setfiles are limited to the card's index universe.
- Strict static build check passes with zero warnings in `D:/QM/reports/framework/21/build_check_20260821_152532.json`.
- Build guardrails, symbol-scope validation, and SPEC validation pass.
- The EA calls `QM_FrameworkTrackOpenPositionMae()`.
- Source SHA-256 matches the artifact: `780a41ddbe475ab5601df0ea78f3d248b05e69d02fc0c9d1cbbdca971572c376`.
- EX5 SHA-256 matches the artifact: `49ab4db2d889eff07eb7441388b6222bf253f16cb52446704991c3581204e274`.
- All generated setfiles include `qm_ea_id=12922`, fixed positive risk, zero percent risk, and `qm_news_stale_max_hours=336`.

## Focused verification

- Re-ran strict `build_check.ps1` static validation with compilation and set validation skipped.
- Re-ran build guardrails, symbol-scope validation, and SPEC validation.
- Recomputed MQ5/EX5 SHA-256 values and traced calendar initialization, new-bar ordering, news filtering, entry consumption, and all setfiles against the approved card.

No EA, setfile, registry, queue, terminal, or pipeline state was modified by this review.
