# Claude review — QM5_9961_bandy-hma-supertrend-confluence-trend

Task: `1bec9666-7684-442f-b85a-982a3a981eb4` (review_ea, source_agent=gemini, source_execution_backend=agy)
Source build task: `cf579137-6e4e-4044-a2c1-fb0a4dfa84bb`, artifact `docs/ops/evidence/cf579137_qm5_9961_bandy-hma-supertrend-confluence-trend_build_identity.json`

## Checklist

- **Card fidelity**: Entry (card L56-57) requires HMA(14/50) ordering AND Supertrend(10,3) state AND close-vs-SMA(200) confluence on its first bar. `.mq5` `Strategy_EntrySignal` L220-222 (long) / L241-243 (short) implement exactly `confluence_now && !confluence_prev`, mirrored for shorts; `Strategy_GetSupertrendStates` (L83-142) computes the median±mult×ATR latch matching the card's recurrence definition. Stop (card L65): 3.0×ATR(14) adverse side — L224 `ask - strategy_stop_atr_mult*atr14` matches; TP=0 (exit-driven) matches card. Exit (card L60-62): filter-flip OR 60-bar time stop — `Strategy_ExitSignal` L299-308 matches. Two non-blocking deviations: (a) the card's optional 0.2×ATR noise-skip ablation (explicitly marked OPTIONAL in the card) is not implemented; (b) the 60-bar time stop uses `max_hold_bars*PeriodSeconds` (calendar days) where the card says "60 trading days" — a subtle semantic gap, not a thesis break.
- **Unwired-input check**: all 10 `strategy_*` inputs have real use-sites (hma_fast/slow, supertrend_period/mult, regime_sma_period, atr_period, stop_atr_mult, max_hold_bars, warmup_bars, max_spread_points). No QM5_1355-class dead input.
- **Host-slot/magic binding**: `req.symbol_slot = qm_magic_slot_offset` bound directly (L180, L235, L254), no independent derivation (QM5_10069 pattern avoided). `magic_numbers.csv` L17214-17226: 13 rows, slots 0-12, all `active`, magics 99610000-99610012, no collision with adjacent 9960 (99600xxx) / 9962 (99620xxx). EURUSD set's magic_slot=6 matches the registry's EURUSD slot 6.
- **Risk mode**: EURUSD backtest `.set` L19-20: `RISK_FIXED=1000`, `RISK_PERCENT=0` — compliant.
- **News guardrail**: `qm_news_stale_max_hours=336` (L26) — exactly at the fail-closed ceiling, not weakened above it.
- **Build evidence**: `build_check_passed=true`, `guardrails_verdict=PASS`, `symbol_scope_verdict=SINGLE_SYMBOL_OK`; `.ex5` present (sha `a5a021aa...`).
- **No ML / no invented values**: only `QM/QM_Common.mqh` included, no ML library. All numerics (HMA 14/50, ST 10/3, SMA 200, ATR 14, stop 3.0×, max_hold 60, warmup 250, max_spread 0/disabled) trace to the card.

## Verdict

All checklist items pass on independent read of the `.mq5`/card/setfile/registry. Two non-blocking nits noted above (optional ablation omitted — card-sanctioned; time-stop unit interpretation). Per the standing hard rule ("Gemini may draft code, but Codex review is mandatory before acceptance"), this task closes to **REVIEW**, not APPROVED — Codex must clear it before PIPELINE/Q02 admission. This is not pipeline evidence and does not admit the EA to Q02 on its own.
