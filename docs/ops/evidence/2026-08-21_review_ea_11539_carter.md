# review_ea — QM5_11539 carter-t-h1-ema5-10-rsi10-median

- **task_id:** 3875b68e-c7d3-4ff6-92ef-3ceb3823bcf3
- **ea_id:** 11539
- **slug:** carter-t-h1-ema5-10-rsi10-median
- **reviewer:** Claude
- **date:** 2026-08-21
- **verdict:** APPROVED

Independent review (not a rubber-stamp of the Codex BUILD verdict). EA had a
Codex-approved BUILD but no `review_ea` row, so it was gate-blocked by
`tools/strategy_farm/review_entry_gate.py:109-114` since 2026-05-23.

---

## 1. Card fidelity — PASS

Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11539_carter-t-h1-ema5-10-rsi10-median.md`.
Mechanism = EMA(5)/EMA(10) close cross + RSI(10, PRICE_MEDIAN) 50-midline cross,
synchronized within +/-2 bars; SL 30 / TP 50 pips; no Friday entry; spread cap 15p;
H1; EURUSD.DWX + GBPUSD.DWX; one position per signal.

Source `.mq5` implements exactly this:
- EMA cross via `QM_Sig_MA_Cross(_Symbol, PERIOD_H1, strategy_ema_fast, strategy_ema_slow, s)` (line 75).
- RSI on PRICE_MEDIAN cross of `strategy_rsi_level` (lines 83-89), guarding 0.0 reads as invalid.
- Sync window logic (`Carter_SyncSignal`, lines 96-119) anchors the later of the two crosses at shift 1 so the signal fires once per synchronized pair — matches card + SPEC.md prose.
- SL/TP fixed pips (lines 180-181), one-position-per-magic guard (lines 136-145), Friday block (lines 149-155), spread cap (lines 159-163).
SPEC.md (in EA dir) agrees with card. No drift to a neighboring idea.

## 2. Input wiring — PASS (all 9 strategy inputs have real use sites)

- `strategy_ema_fast` → line 75
- `strategy_ema_slow` → line 75
- `strategy_rsi_period` → lines 83, 84
- `strategy_rsi_level` → lines 87, 88
- `strategy_sync_window` → line 98 (used in loops 104, 113)
- `strategy_sl_pips` → line 180
- `strategy_tp_pips` → line 181
- `strategy_spread_cap_pips` → line 161
- `strategy_block_friday_entry` → line 149

No dead/unwired strategy inputs.

## 3. Magic / slug binding — PASS (no collision)

`framework/registry/ea_id_registry.csv:2420`: `11539,carter-t-h1-ema5-10-rsi10-median,3001a121-...,active,Claude,2026-05-23` (single row, slug matches).
`framework/registry/magic_numbers.csv:15693-15694`:
- slot 0 EURUSD.DWX → 115390000 = 11539*10000+0 ✓
- slot 1 GBPUSD.DWX → 115390001 = 11539*10000+1 ✓
Both magics unique across the registry (grep). Formula `ea_id*10000+slot` holds.

## 4. Set files — PASS (backtest convention)

`sets/..._EURUSD.DWX_H1_backtest.set` and `..._GBPUSD.DWX_H1_backtest.set`:
- `RISK_FIXED=1000` (>0), `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, `environment: backtest`.
- magic_slot 0 / 1 match registry. Strategy params match card defaults (EMA 5/10, RSI 10, level 50, sync 2, SL 30, TP 50, spread 15, friday 1).

## 5. Loss-limit / DD guard — PASS (framework default, no card override)

EA declares no custom kill-switch input; `QM_FrameworkInit` → `QM_KillSwitchInit(ea_id, magic, 3.0, 0.0, 1.0)` (QM_Common.mqh:298). Card specifies no explicit kill-switch R-limit — `expected_dd_pct: 16.0` is an *expectation*, not a hard limit, and SL is enforced per-trade at 30 pips (line 180). The 3.0R/0.0 default is the standard framework value for a pre-Q13 EA; nothing is silently overriding a card-stated number. Not a defect.

## 6. Broker-time / DST — PASS

Friday block uses `TimeToStruct(TimeCurrent(), bt); bt.day_of_week == 5` (lines 151-153) — broker (server) time, no hardcoded DST offset. Framework Friday close hour `qm_friday_close_hour_broker=21` (broker time). Consistent with documented DXZ NY-Close GMT+2/+3 convention. No hardcoded DST assumptions.

## 7. build_check (strict) — PASS

`pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_11539_carter-t-h1-ema5-10-rsi10-median`:
```
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
build_check.result=PASS
build_check.failures=0
build_check.warnings=0
EXITCODE=0
```
Report: `D:\QM\reports\framework\21\build_check_20260821_084615.json`.

## 8. News stale guard — PASS

`qm_news_stale_max_hours = 336` (line 37) = 14 days, `<= 336`. Fail-closed check not weakened.

---

## Overall verdict: APPROVED

All eight review dimensions clean: card-faithful implementation, every strategy
input wired, magic/slug binding consistent with no collision, backtest set files
correct (RISK_FIXED>0 / RISK_PERCENT=0 / ENV=backtest), sane broker-time handling,
strict build_check PASS (0/0), news stale guard at the ceiling 336. Ready for the
pipeline (Q02+).
