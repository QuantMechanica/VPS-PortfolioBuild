# Claude review — QM5_9949_bandy-bbwidth-contraction-breakout-trend

Task: `315a0d2d-63aa-46e5-92d1-c0731183a255` (review_ea, source_agent=gemini, source_execution_backend=agy)
Source build task: `528d9db8-5f15-4c26-81bf-887a4b6deb17`, artifact `docs/ops/evidence/528d9db8_qm5_9949_bandy-bbwidth-contraction-breakout-trend_build_identity.json`

## Checklist

- **Card fidelity**: mostly faithful, one material omission. BB(20,2.0) population-stdev width matches card §Entry.1 (`Strategy_CalculateBBWidth`, L88-111). Compression window (shifts 3..122, tested at shift 2, excluding the tested bar) matches "today NOT in window" (L203-217). Regime SMA(200) at shift 1, breakout `close1>ub1 & >regime` / `close1<lb1 & <regime` (L228, L252, L271) matches card §4. Extreme-range guard `high1-low1 > 4*ATR` (L235) matches. Cat-SL entry∓2.5·ATR (L254, L273) matches card §Stop. Midband-touch trail-exit on fully-closed shift 1 (L304-334) correctly resolves the card's shift-semantics question. TP=0 matches.
  **MISMATCH (material)**: card §Entry.5 mandates a one-shot entry — the compression flag is consumed on use and only re-arms after `bb_width` exceeds the 60th-percentile of the 120-bar window (also in the card's build notes, L114/116(b)). The `.mq5` has **no episode/re-arm state at all** — `Strategy_EntrySignal` is stateless; re-entry is gated only by one-position-per-magic (L196). The card-required re-arm mechanic is simply absent.
  Minor: time stop uses wall-clock `max_hold_bars*period_seconds` (L320, ~30 calendar days) where the card says "30 trading days."
- **Unwired-input check**: 12 of 13 `strategy_*` inputs have real logic use-sites. **DEFECT**: `strategy_rearm_pct` (L42) appears only inside `Strategy_ParamsValid`'s bounds-check (L79-80) — it validates a value that never affects trading behavior. This is a textbook QM5_1355-class unwired input, and it is the direct symptom of the missing re-arm mechanic above.
- **Host-slot/magic binding**: correct. `req.symbol_slot = qm_magic_slot_offset` bound directly (L192, L265, L282), no independent derivation (QM5_10069 pattern avoided). `magic_numbers.csv` L17201-17213: 13 rows, slots 0-12, all `active`, magics 99490000-99490012, no collision with adjacent 9948 (99480xxx) / 9950.
- **Risk mode**: SP500 backtest `.set` L19-20: `RISK_FIXED=1000`, `RISK_PERCENT=0` — compliant. Note: L24 `card_defaults_status=none_found` — strategy params were not appended to the setfile, so backtest runs on compiled-in defaults (which do match the card).
- **News guardrail**: `qm_news_stale_max_hours=336` (L26) — at the ceiling, not exceeded.
- **Build evidence**: `build_check_passed=true`, `guardrails_verdict=PASS`, `symbol_scope_verdict=SINGLE_SYMBOL_OK`; `.ex5` present (sha `f1df93ea...`).
- **No ML / no invented values**: only `QM/QM_Common.mqh` included, no ML library. All numeric thresholds (20/2.0/120/10th-pct/200/ATR14/2.5/4.0/30) trace to the card; `rearm_pct=60` traces to the card but is unwired (see above).

## Verdict

**RECYCLE-recommend.** The card-mandated one-shot-consume + 60th-percentile re-arm gate (card §Entry.5) is entirely unimplemented — no episode state exists in the entry logic — leaving `strategy_rearm_pct` an unwired input and a genuine card-fidelity defect, not a cosmetic gap: without the re-arm gate the EA can re-enter on every bar of a still-compressed regime, which is a materially different (and materially riskier) trading behavior than the approved card describes.

Per the standing hard rule ("Gemini may draft code, but Codex review is mandatory before acceptance"), this task closes to **REVIEW**, not APPROVED/RECYCLE — Codex must independently confirm before a RECYCLE disposition is executed. This is not pipeline evidence and does not admit the EA to Q02.
