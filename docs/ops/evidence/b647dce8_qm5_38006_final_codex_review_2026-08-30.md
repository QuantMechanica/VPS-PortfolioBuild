# QM5_38006 final Gemini rework review

- Review task: `b647dce8-109f-4290-845a-c5d5800e6d9f`
- Gemini build task: `8eb1627c-03bb-4f59-ab0a-b6c46c8a63ab`
- EA: `QM5_38006_codetrading-doji-hammer-pivot-rejection`
- Reviewed at: `2026-08-30T18:05:10Z`
- Disposition: **PASS — code/build identity accepted; remain in REVIEW**
- Pipeline verdict: **none** (code review and `COMPILE_EA` evidence do not establish a Q-phase verdict)

## Outcome

The two findings from review `69866933` are closed in the source that produced
the current EX5:

1. `StrategyTotalDrawdownHaltCheck` captures initial equity, calculates total
   drawdown against that fixed baseline, latches at the card-authorized 5.0%,
   closes positions for the framework magic, and is called from the active
   `OnTick` path before management and entry. It is not gated out in tester
   mode. The same latch also blocks entry admission.
2. `StrategyDailyRealizedLossHalt` calls `HistorySelect(day_start, now)`
   directly. Selection failure emits `HISTORY_SELECT_FAILED` and returns
   `true`, so unavailable deal history fails closed. The separate 2.5% daily
   equity hard stop remains configured through `QM_KillSwitchInit`.

The approved-card values are preserved: 2.0% realized-loss entry halt, 2.5%
daily hard stop, 5.0% initial-equity total-drawdown stop, maximum three ticks
slippage, H1 closed-bar signals, rollover blackout, mandatory news filtering,
one position per strategy magic, 1.8R take profit, and break-even at 1R.

This is the mandatory Codex acceptance of Gemini-authored code. The linked
Gemini build task remains in `REVIEW`; this review does not self-promote it to
`PIPELINE`, enqueue Q02, or assert a pipeline verdict.

## Hash-matched build identity

The current files, durable identity, and governed compile receipt agree:

| Identity | SHA-256 | Match |
|---|---|---|
| Current MQ5 / identity / receipt `candidate_recheck.mq5_sha256` | `52edb8f216fb7f35df6e1298ef7fd2fb661e79ceb4ee156c952295c46d747dd2` | yes |
| Current EX5 / identity / receipt `ex5_sha256` | `e6a7905650cbd401095d3856afada8bbe5fb39fc0560b6629215f820bead39ff` | yes |
| Current compile receipt / identity `compile_evidence_sha256` | `0602c940626e7ec71ece564a8e3382e891e31a155e5385cc3f3d5b94d43b2f4e` | yes |

The receipt is
`D:/QM/reports/work_items/09320649-3bcf-453b-9828-19a8db881efe/QM5_38006/COMPILE_EA/compile_evidence.json`.
It records `COMPILE_OK`, compiler `PASS`, zero compiler errors, zero compiler
warnings, build check `PASS`, and completion at `2026-08-30T17:19:55Z` on T4.
Its three bound setfile build hashes also match the current setfile headers:

- EURUSD.DWX: `4e9dccc473a9e39e2260aee10167a3074c7462abaad2ee78ab8eb7c7c4e211e1`
- GBPUSD.DWX: `42e4c908c222b5bb4a42bb3eae80419da702d956d36be5ed7e9376c2d9f6b65b`
- USDJPY.DWX: `8348b5a1188310eea945b99907847988571a86a2293db51590be82170e907e09`

All three backtest sets use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The EA and
sets pass the 336-hour news-staleness ceiling guard; the source retains
`qm_news_stale_max_hours=336`.

## Unwired-input audit

A declaration/use grep found **31 declared inputs, 0 unwired inputs**. The
mechanical review screen independently reported `inputs=31`, three active magic
rows, and no problems when invoked with the canonical slug. The router build
payload omits its separate `slug` field (it carries `ea_label`), so the bulk
screen CLI reports a payload-shape `ea_dir_missing` false positive; direct
screening of the canonical identity passes.

Every Strategy-group input has at least one non-declaration use-site:

| Input | Non-declaration source lines |
|---|---|
| `strategy_signal_tf` | 82, 129-132, 137-138, 494 |
| `strategy_ema_period` | 83, 137 |
| `strategy_max_body_ratio` | 86, 150, 156 |
| `strategy_min_wick_ratio` | 87, 151, 157 |
| `strategy_zone_atr_mult` | 88, 153, 159 |
| `strategy_atr_period` | 84, 138 |
| `strategy_sl_buffer_pips` | 90, 327 |
| `strategy_tp_rr_mult` | 90, 340, 348 |
| `strategy_be_enabled` | 91, 361 |
| `strategy_be_trigger_r` | 91, 391, 404 |
| `strategy_rollover_start_hhmm` | 75-77, 98, 100 |
| `strategy_rollover_end_hhmm` | 75-77, 99, 101 |
| `strategy_spread_filter_mult` | 84, 286 |
| `strategy_max_slippage_ticks` | 92, 116, 118 |
| `strategy_daily_loss_halt_pct` | 103-105, 265, 271 |
| `strategy_daily_hard_stop_pct` | 103-105, 460 |
| `strategy_total_dd_halt_pct` | 106, 174, 188, 195, 461 |

Framework-group, risk, news, Friday-close, and stress inputs likewise each have
at least one non-declaration use-site. No inert configuration knob was found.

## Focused verification

| Check | Result |
|---|---|
| `pytest tools/strategy_farm/tests/test_qm5_38006_rework_static.py` | PASS — 11 passed |
| `pytest tools/strategy_farm/tests/test_build_guardrails.py` | PASS — 22 passed |
| `validate_build_guardrails.py` on MQ5 plus all three sets | PASS — no findings |
| `build_gate_hardening.py` for the EA | PASS — no failures or warnings |
| `skill_build_ea_guard.py` | PASS — EA registry, magic rows, and directory valid |
| `validate_spec_doc.py` | PASS |
| Mechanical build-review screen with canonical identity | PASS — no problems |
| MQ5 / EX5 / receipt identity comparison | PASS |
| Strategy-input declaration/use audit | PASS — 17/17 wired; full EA 31/31 wired |

No terminal was started, no active backtest was interrupted, and no live or
AutoTrading setting was changed during this review.
