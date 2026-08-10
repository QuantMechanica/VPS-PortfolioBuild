# QM5_1354 woodie-cci-dual-h1 — Claude review_ea pass

- Router task: `0c9d9f82-8b4a-408a-9b82-a9d89e9ab106` (review_ea, priority 51)
- Source: gemini `build_ea` task `eeb21d12-1358-4cf1-9e41-a5a1d21e6106`, backend `agy`
- Source artifact: `framework/EAs/QM5_1354_woodie-cci-dual-h1/QM5_1354_woodie-cci-dual-h1.mq5`
- Source verdict (gemini/agy): "PASS: Compiled and build check PASS."
- Reviewer: Claude, orchestration cycle 2026-08-10T21:08Z (worktree `agents/claude-orchestration-1`)

## Scope

Manual read-through of the full `.mq5` source (336 lines) against: QuantMechanica V5
framework wiring conventions, Edge Lab charter constraints (mechanical-only, no ML, no
martingale/grid, news blackout, swing horizon), and the build guardrail (`qm_news_stale_max_hours`
ceiling, RISK_FIXED/RISK_PERCENT input presence).

## Findings

1. **Cosmetic — `#property description` is a placeholder.** Line 3:
   `"QM5_1354 Unknown Strategy"` — every other reviewed EA in this cohort carries a
   real one-line description (see QM5_1355 sibling). Doesn't block acceptance; worth
   fixing before this becomes the card's canonical description elsewhere.
2. No correctness, closed-bar-hygiene, or framework-wiring defects found:
   - `AdvanceState_OnNewBar()` only reads bars `i>=1` (closed bars) for both CCI arrays —
     no forming-bar leakage.
   - Single-position guard via `QM_TM_OpenPositionCount(magic) > 0` in both
     `Strategy_EntrySignal` and before re-entry.
   - SL/TP direction checks are correct for both BUY (`sl < ask_now`) and SELL
     (`sl > bid_now`).
   - Entry/exit/partial-close/time-stop all route through `QM_TM_*` framework calls,
     no raw `OrderSend`/`trade.*` bypass.
   - No martingale/grid sizing; no ML; mechanical CCI trend + turbo zero-line-reject
     pattern only.
   - `qm_news_stale_max_hours = 336` — at the guardrail ceiling, not above it.
     `qm_news_temporal`/`qm_news_compliance` wired to `QM_NewsAllowsTrade2` (DXZ
     profile), legacy path only used as fallback when both are OFF/NONE. Compliant.
   - `RISK_PERCENT`/`RISK_FIXED` both present as inputs; actual mode is set by the
     `.set` file at dispatch time, not by this source default — nothing to flag here.
3. Suppression latches (`g_buy_suppressed`/`g_sell_suppressed`, reset on CCI sign
   flip) are an intentional one-shot-per-swing entry limiter, not a bug — confirmed
   by re-reading the reset logic in `AdvanceState_OnNewBar()`.

## Verdict

**No blocking defects.** One cosmetic doc-quality note (finding #1). Per the Q08.13
hard rule (Codex review mandatory before acceptance of Gemini-authored code), this
task is left in `REVIEW` state — not self-approved, not moved to PIPELINE.

Recommendation for the mandatory Codex pass: spot-check the CCI turbo threshold
constants (100.0 / -100.0 / 250.0 partial-close trigger) against the strategy card's
literature source, since this review only verified framework-wiring and closed-bar
correctness, not edge-source fidelity.
