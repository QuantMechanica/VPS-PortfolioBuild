# QM5_1355 williams-vix-fix-fx-h4 — Claude review_ea pass

- Router task: `860da8d2-37db-4218-91f1-5c95b10897e4` (review_ea, priority 51)
- Source: gemini `build_ea` task `85abc20a-1798-4c0c-b705-f67bbab19cc8`, backend `agy`
- Source artifact: `framework/EAs/QM5_1355_williams-vix-fix-fx-h4/QM5_1355_williams-vix-fix-fx-h4.mq5`
- Source verdict (gemini/agy): "PASS: Compiled and build check PASS."
- Reviewer: Claude, orchestration cycle 2026-08-10T21:08Z (worktree `agents/claude-orchestration-1`)

## Scope

Manual read-through of the full `.mq5` source (365 lines) against: QuantMechanica V5
framework wiring conventions, Edge Lab charter constraints, and parameter-wiring
correctness (since this EA declares several strategy-shape inputs feeding the WVF
computation).

## Findings

1. **Blocking — three declared strategy inputs are never read; hardcoded literals
   are used instead.** Confirmed by direct comparison of the `input` declarations
   against every use site:

   | Input (line) | Default | Hardcoded literal actually used | Use site |
   |---|---|---|---|
   | `strategy_wvf_lookback` (36) | 22 | `for(int i = 0; i < 22; i++)` | `WVF()`, line 78 |
   | `strategy_wvf_ma_period` (37) | 20 | `for(int i = 0; i < 20; i++)` (×2) | `GetWvfStats()`, lines 92, 100 |
   | `strategy_wvf_range_pct` (39) | 0.85 | `range_high = 0.85 * max_wvf_51;` | `GetWvfStats()`, line 112 |

   None of `strategy_wvf_lookback`, `strategy_wvf_ma_period`, or
   `strategy_wvf_range_pct` is referenced anywhere in the file outside its own
   `input` declaration (grep-verified). At default settings the EA behaves exactly
   as intended — the literals match the defaults — so `compile` + `build_check`
   (syntax/link level only) cannot catch this; it's a semantic wiring defect.

   **Why this blocks pipeline admission as-is:** Q04/Q08 robustness and
   parameter-neighborhood testing depend on sweeping declared inputs and observing
   real behavioral sensitivity ([[q08-neighborhood-param-type]] precedent: a
   neighborhood sweep that shows zero change for a "varied" parameter is not
   evidence of robustness, it's evidence the parameter never reached the strategy).
   Any optimization or neighborhood pass run against this build over these three
   inputs would silently produce meaningless/misleadingly-flat sensitivity results.

   The 51-bar window in `GetWvfStats` (`for(int i = 0; i < 51; i++)`, line 107) has
   no corresponding input at all — likely intended to be derived from
   `strategy_wvf_ma_period` + lookback rather than a fourth hardcoded magic number;
   flagging for the fix pass to consider alongside the three above.

2. No other correctness or closed-bar-hygiene defects found:
   - `WVF()`/`GetWvfStats()` are always called with `shift >= 1` from
     `AdvanceState_OnNewBar()` — no forming-bar leakage.
   - Single-position guard, SL direction check (`sl <= 0.0 || sl >= ask_now` reject),
     partial-close/time-stop/EMA200-trend-exit all route through `QM_TM_*` framework
     calls.
   - No martingale/grid; no ML; mechanical volatility-spike-reversal pattern only.
   - `qm_news_stale_max_hours = 336` at ceiling, not above. News wiring identical
     pattern to QM5_1354 (DXZ profile via `QM_NewsAllowsTrade2`), compliant.
   - `#property description` is a real, specific one-liner (contrast with QM5_1354's
     placeholder) — good.

## Verdict

**NEEDS_FIX before pipeline admission.** Finding #1 is a semantic parameter-wiring
defect, not a compile/build-check failure, so it passed Gemini's build gate but
should not proceed to Q02+ without the three inputs actually being wired into
`WVF()`/`GetWvfStats()` (or removed if intentionally fixed constants — but then they
shouldn't be exposed as tunable inputs at all).

Per the hard rule (Codex review mandatory before acceptance of Gemini-authored code),
this task is left in `REVIEW` state with this verdict attached — not self-approved,
not moved to PIPELINE, not closed to RECYCLE by Claude. Recommend the mandatory
Codex pass either (a) confirms and fixes the wiring directly, or (b) closes this task
RECYCLE back to Gemini with this finding attached.
