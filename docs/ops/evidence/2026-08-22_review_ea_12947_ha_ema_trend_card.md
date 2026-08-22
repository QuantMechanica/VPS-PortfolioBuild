# Claude review — QM5_12947 mql5-ha-ema-trend-card

Task: `da8668b2-6787-49fb-8211-1643365cf735` (review_ea, source_agent=gemini, source_execution_backend=agy)
Source build task: `fb7ed34a-46f1-479f-9f1c-b9b0ae91914e`, artifact `C:/QM/repo/artifacts/qm5_12947_build_result.json`

## Checklist

- **Card fidelity**: SPEC.md describes smoothed Heiken-Ashi flip + EMA(50) trend/slope filter, ATR(14)*2.0 stop (or signal-candle extreme, whichever wider), hard 2R take-profit, opposite-flip/EMA-cross discretionary exit. `.mq5` `Strategy_EntrySignal`/`Strategy_ExitSignal` implement exactly this; `req.tp` is set via `QM_StopRulesTakeFromDistance(..., strategy_tp_r_mult * sl_distance)` matching the hard-2R claim.
- **Unwired-input check**: every `strategy_*` input (`pre_smooth_period`, `post_smooth_period`, `ha_seed_bars`, `ema_period`, `ema_slope_lookback`, `ema_min_slope_atr_ratio`, `atr_period`, `atr_sl_mult`, `tp_r_mult`, `max_spread_points`) has a live use site in `ComputeSmoothedHA`, `Strategy_EntrySignal`, or `Strategy_NoTradeFilter`. No dead inputs (QM5_1355-class defect not present).
- **Host-slot/magic binding**: `req.symbol_slot = qm_magic_slot_offset` (line 187) — matches the QM5_10069-class fix requirement. `magic_numbers.csv` rows 17647-17649: slot 0=EURUSD.DWX/129470000, 1=GBPUSD.DWX/129470001, 2=GDAXI.DWX/129470002, all `active`, no collision with adjacent EA ids.
- **Risk mode**: backtest setfile (`..._EURUSD.DWX_H1_backtest.set`) carries `RISK_FIXED=1000` / `RISK_PERCENT=0`, matching Hard Rule (backtest=FIXED). SPEC.md §7 correctly scopes RISK_PERCENT to live burn-in/full-live only.
- **News**: `qm_news_stale_max_hours=336` — at the fail-closed ceiling, not above it (guardrail respected).
- **Build evidence** (from build_result.json): `build_check_passed=true`, `validate_spec_passed=true`, `validate_guardrails_passed=true`, `compile_succeeded=true` (0 errors/0 warnings per Gemini notes).
- **Freshness**: `.ex5` 2026-08-22 09:32:25 local, newer than `.mq5` 2026-08-22 09:29:31 local — current build matches current source.

## Verdict

All checklist items pass on independent read of the `.mq5`/SPEC/setfile/registry. Per the standing hard rule ("Gemini may draft code, but Codex review is mandatory before acceptance"), this task closes to **REVIEW**, not APPROVED — Codex must clear it before it can advance to PIPELINE/Q02. This is not pipeline evidence and does not admit the EA to Q02 on its own.
