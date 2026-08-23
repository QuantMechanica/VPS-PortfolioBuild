# Review: QM5_35005 sma-crossover-pullback-system (Gemini build, Claude review)

- Task: agent_tasks `954f01d5-652a-4d01-bf2b-0e243bf8955f` (review_ea, reason `codex_review_required_for_gemini_code`)
- Source build task: `da39e160-b043-4528-8592-4a23f672fc55` (`artifacts/builds/da39e160-b043-4528-8592-4a23f672fc55.json`), built_by Gemini, `build_check_passed=true`, `compile_succeeded=true`
- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_35005_sma-crossover-pullback-system.md` (status APPROVED, g0_status APPROVED)
- Reviewed file: `framework/EAs/QM5_35005_sma-crossover-pullback-system/QM5_35005_sma-crossover-pullback-system.mq5`
  - sha256 `758b0021667e9354415331c20dbee6389934813db590e3f837c242f4bac5be90` — matches the build record and current on-disk content (verified via `sha256sum`).

## Checklist

- **Card vs. code parity**: long/short entry formulas (`SMA(100)[1] vs SMA(200)[1]`, `Stoch_K[2]` oversold/overbought threshold, `Stoch_K[1]` vs `Stoch_D[1]` cross) match the card's Section 3.2/3.3 exactly, including shift indices. TP=300 pips / SL=150 pips / trailing 150-pip trigger+step match Section 3.4.
- **No-trade filter**: spread > 1.8×ATR(14,H1)[1], rollover blackout, 2.0% daily loss halt, max-1-open-position all present and match Section 3.1. Minor: rollover window check (`hhmm >= 2355 || hhmm < 5`) covers 23:55–00:04, one minute short of the documented 00:05 boundary — cosmetic, not a defect worth blocking.
- **Kill-switch**: `strategy_daily_hard_stop_pct=2.5`, `strategy_total_dd_halt_pct=5.0`, `strategy_per_trade_risk_cap_pct=0.5` wired into `QM_KillSwitchInit`, matches Section 4.2.
- **Unwired-input check** (per `feedback_ea_review_unwired_input_check`): every `strategy_*` input (fast/slow SMA, stoch k/d/slowing/oversold/overbought, tp/sl pips, trailing trigger/step, atr period, spread mult, daily loss halt, daily hard stop, total dd halt, per-trade risk cap) has a confirmed use-site in the hooks — none are declared-but-dead.
- **Risk-mode / set files**: all 3 generated set files (EURUSD/GBPUSD/EURJPY H1 backtest) carry `RISK_FIXED=1000`, `RISK_PERCENT=0`, `environment: backtest` — compliant with the RISK_FIXED>0/RISK_PERCENT=0 backtest hard rule.
- **News gate**: `qm_news_stale_max_hours=336` — at, not above, the 336h ceiling. Compliant.
- **Magic registry**: `framework/registry/magic_numbers.csv` rows 17413-17415 register ea_id 35005 slots 0/1/2 → 350050000/1/2 = `ea_id*10000+slot`, consistent with the 3 target symbols (EURUSD/GBPUSD/EURJPY.DWX) in the card and SPEC.md.
- **Exit path**: `Strategy_ExitSignal()` returns false by design — exits are SL/TP/trailing only, consistent with the card (no discrete exit-signal condition documented).

## Caveat (not a code defect, flagging for the record)

`farmctl health` (checked_at 2026-08-23T11:31:38Z) reports `pending_artifact_binding_drift` FAIL with 3 `CONTENT_CHANGED:HELD` rows for QM5_35005 Q02 mq5/setfile bindings across pending work_item rows `61f887b7`, `62156a75`, `ee0914f4` — evidence this EA has been rebuilt more than once recently and Q02 dispatch is currently held pending a governed rebind (per the health check's own action_hint: normalized-byte proof or per-EA review before rebind, no manual override). This is an existing infra-tracked condition, not something this review task is scoped to resolve; the reviewed .mq5 content (sha256 758b0021...) matches the specific build task da39e160 being reviewed here.

## Verdict

**PASS-leaning.** Code is a faithful, fully-wired mechanization of the approved card with no unwired inputs and compliant risk/news/magic wiring. Per the codex-mandatory-for-gemini-code rule, left in REVIEW rather than self-approved to PIPELINE — Codex review still required before acceptance. Router should also be aware of the pre-existing Q02 artifact-binding-drift hold on this EA (separate infra ticket) before dispatching backtests.
