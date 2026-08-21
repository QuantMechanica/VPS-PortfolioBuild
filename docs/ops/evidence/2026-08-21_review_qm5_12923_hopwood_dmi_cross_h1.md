# Review: QM5_12923 hopwood-dmi-cross-h1-card (gemini build, Claude review pass)

- Router task: review_ea `a2effd9b-b0bb-4def-b95e-cee799c24f88` (reason:
  `codex_review_required_for_gemini_code`, source build task `f9e1abeb-a14c-4f02-9869-b9d99fcbf303`,
  source_agent gemini/agy)
- Source artifact reviewed: `C:/QM/repo/artifacts/qm5_12923_build_result.json`
- EA reviewed: `framework/EAs/QM5_12923_hopwood-dmi-cross-h1-card/QM5_12923_hopwood-dmi-cross-h1-card.mq5`
- SPEC reviewed: `framework/EAs/QM5_12923_hopwood-dmi-cross-h1-card/SPEC.md`

## Method

Read the .mq5 in full, cross-checked every `strategy_*` input against its use site
(unwired-input check per `feedback_ea_review_unwired_input_check`), verified framework
wiring (`QM_FrameworkInit` arg order, `OnTick` hook sequence, `req.symbol_slot =
qm_magic_slot_offset` per the host-slot-magic fix), verified `QM_StopATR`/`QM_TakeRR`/
`QM_ADX*` call signatures against `framework/include/QM/QM_StopRules.mqh` and
`QM_Indicators.mqh`, and checked the build-guardrail-sensitive inputs
(`qm_news_stale_max_hours`, RISK_FIXED/RISK_PERCENT) against Hard Rules.

## Findings

- All 7 `strategy_*` inputs (`strategy_dmi_period`, `strategy_adx_threshold`,
  `strategy_atr_period`, `strategy_atr_sl_mult`, `strategy_take_profit_rr`,
  `strategy_adx_exit_threshold`, `strategy_require_h1`) are read at a use site. No
  unwired inputs.
- `qm_news_stale_max_hours = 336` — at the ceiling, not above it. Compliant.
- `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0` — correct backtest risk mode.
- `req.symbol_slot = qm_magic_slot_offset` set correctly on both entry branches
  (matches the 2026-08-16 host-slot-magic-conflation fix criterion).
- DMI cross detection (`pdi1>mdi1 && pdi2<=mdi2` / mirror for bearish) reads on closed
  bars (shift 1/2), consistent with SPEC "on closed H1 bar" and the `QM_IsNewBar()` gate
  later in `OnTick`. Entry and exit crossover logic are symmetric.
- SL/TP construction (`QM_StopATR`, `QM_TakeRR`) matches framework signatures; both
  entry branches validate stop distance sign before returning true.
- Magic registry has 13 reserved slots (broader universe) but only 5 setfiles were
  generated (EURUSD, GBPUSD, USDJPY, AUDUSD, GDAXI) — a subset of the SPEC's stated
  8-symbol "Designed for" list (missing NDX, WS30, UK100 setfiles). Not a code defect;
  flagging for whoever closes this review to confirm intentional partial rollout vs.
  missing setfile-gen step before PIPELINE.
- `smoke_result: "framework_error"`, `blocked_reason`: active Custom-history isolation
  requires a worker-bound work item whose archives were privatized before `run_smoke`.
  This is the expected Variant A custom-history isolation gate (per CLAUDE.md
  Infrastructure Constants), not a code defect — smoke simply hasn't run under a
  privatized worker slot yet.

## Verdict (Claude pass)

No code defects found. `build_check` + `compile` already PASS per the gemini build
artifact; this pass adds unwired-input, framework-wiring, and hard-rule compliance
checks — all clean. Per CLAUDE.md ("Gemini may draft code, but Codex review is
mandatory before acceptance"), this task is left at **REVIEW**, not closed to
APPROVED/PIPELINE. Codex (or a subsequent close-review pass) should confirm the
setfile/SPEC symbol-count gap and clear the smoke-under-privatized-worker step before
acceptance.
