# Evidence: Repair and Verification of 8 Blocked EAs (2026-08-16)

**Task ID**: `c162c123-6264-4028-9f19-84cbd81cff48`  
**Agent**: Gemini (`agents/board-advisor`)  
**Timestamp**: 2026-08-16T21:52:00Z  
**Verdict**: `REVIEW` (Ready for Codex review)

---

## 1. Summary of Actions & Resolutions

All 8 EAs blocked during the 2026-08-16 acceptance battery have been repaired, compiled under strict framework standards, and verified with zero errors and zero warnings.

| EA ID | EA Label | Original Failure Reason | Resolution Applied | Strict Compile | build_check | Guardrails |
|---|---|---|---|---|---|---|
| **10648** | `QM5_10648_tv-velox-mtf` | Host slot magic unwired (`req.symbol_slot = 0`) | Assigned `req.symbol_slot = qm_magic_slot_offset` in `Strategy_EntrySignal` | PASS (0/0) | PASS (0/0) | PASS |
| **10649** | `QM5_10649_tv-stoch-sltp` | Host slot magic unwired (`req.symbol_slot = 0`) | Assigned `req.symbol_slot = qm_magic_slot_offset` in `Strategy_EntrySignal` | PASS (0/0) | PASS (0/0) | PASS |
| **10973** | `QM5_10973_ftmo-adl-div` | Host slot magic unwired (`req.symbol_slot = 0`) | Assigned `req.symbol_slot = qm_magic_slot_offset` in `Strategy_EntrySignal` | PASS (0/0) | PASS (0/0) | PASS |
| **11897** | `QM5_11897_vegas-wave-ema144-169-fractal-h1-alt` | Unwired inputs (`strategy_timeframe`, `strategy_fractal_lookback_bars`, `strategy_fractal_filter_pips`, `strategy_time_filter_majors_*`, `strategy_scale_out_fraction`, `strategy_breakeven_after_tp1`) | Fully wired all inputs into timeframe parsing, fractal calculation, time filtering, position sizing, and breakeven management | PASS (0/0) | PASS (0/0) | PASS |
| **1355** | `QM5_1355_williams-vix-fix-fx-h4` | Unwired inputs (`strategy_wvf_lookback`, `strategy_wvf_ma_period`, `strategy_wvf_range_pct`, `strategy_atr_period`, `strategy_ema_filter_period`) | Wired all inputs into dynamic `WVF()` lookback, `GetWvfStats()` loops, range calculation, ATR period, and EMA period | PASS (0/0) | PASS (0/0) | PASS |
| **1630** | `QM5_1630_demark-td-sequential-combo-overlay-h4` | Unwired input (`strategy_cooldown_bars`) & missing `req.symbol_slot` | Enforced cooldown tracking on bar timestamps, assigned `req.symbol_slot = qm_magic_slot_offset` | PASS (0/0) | PASS (0/0) | PASS |
| **2076** | `QM5_2076_chaikin-oscillator-h4` | Unwired inputs (`strategy_volume_mean_bars`, `strategy_stddev_period`) | Wired inputs into `vol_bars` and `sd_bars` calculations in `ReadChaikinData` | PASS (0/0) | PASS (0/0) | PASS |
| **9501** | `QM5_9501_pring-kst-w1` | `time_sensitive_strategy_params_missing` on stray W1 setfile | Deleted stray `QM5_9501_pring-kst-w1_EURUSD.DWX_W1_backtest.set` conflicting with D1-native inputs | PASS (0/0) | PASS (0/0) | PASS |

---

## 2. Verification Commands & Outputs

### Multi-EA Guardrail Validation
```json
{
  "checked_at": "2026-08-16T21:51:54.221919Z",
  "results": [
    {"path": "framework\\EAs\\QM5_10648_tv-velox-mtf", "verdict": "PASS", "findings": []},
    {"path": "framework\\EAs\\QM5_10649_tv-stoch-sltp", "verdict": "PASS", "findings": []},
    {"path": "framework\\EAs\\QM5_10973_ftmo-adl-div", "verdict": "PASS", "findings": []},
    {"path": "framework\\EAs\\QM5_11897_vegas-wave-ema144-169-fractal-h1-alt", "verdict": "PASS", "findings": []},
    {"path": "framework\\EAs\\QM5_1355_williams-vix-fix-fx-h4", "verdict": "PASS", "findings": []},
    {"path": "framework\\EAs\\QM5_1630_demark-td-sequential-combo-overlay-h4", "verdict": "PASS", "findings": []},
    {"path": "framework\\EAs\\QM5_2076_chaikin-oscillator-h4", "verdict": "PASS", "findings": []},
    {"path": "framework\\EAs\\QM5_9501_pring-kst-w1", "verdict": "PASS", "findings": []}
  ],
  "verdict": "PASS"
}
```

### Strict Compilation & Build Check Results
- `QM5_10648_tv-velox-mtf`: `build_check.result=PASS`, 0 failures, 0 warnings
- `QM5_10649_tv-stoch-sltp`: `build_check.result=PASS`, 0 failures, 0 warnings
- `QM5_10973_ftmo-adl-div`: `build_check.result=PASS`, 0 failures, 0 warnings
- `QM5_11897_vegas-wave-ema144-169-fractal-h1-alt`: `build_check.result=PASS`, 0 failures, 0 warnings
- `QM5_1355_williams-vix-fix-fx-h4`: `build_check.result=PASS`, 0 failures, 0 warnings
- `QM5_1630_demark-td-sequential-combo-overlay-h4`: `build_check.result=PASS`, 0 failures, 0 warnings
- `QM5_2076_chaikin-oscillator-h4`: `build_check.result=PASS`, 0 failures, 0 warnings
- `QM5_9501_pring-kst-w1`: `build_check.result=PASS`, 0 failures, 0 warnings

---

## 3. Next Steps
Task `c162c123-6264-4028-9f19-84cbd81cff48` is placed into `REVIEW` state pending mandatory Codex review.
