# QM5_20181 — FTMO joint multi-symbol (OnTimer) — BACKTEST-ONLY

Measurement instrument. One EA runs the Q09-admitted runner+satellite book on ONE
simulated $100k account in ONE tester run so the account equity curve is REAL. Symbols
are input parameters; sleeves are dispatched by symbol; the EA is driven from OnTimer
for non-host satellites while the host runner stays on OnTick.

Built piece by piece (OWNER 2026-07-27, "Stück für Stück"), each sleeve admitted only at
`match_rate == 1.0` before the next is added:

- **Step 1 (this file):** scaffold + RUNNER only — 9936:USDJPY on the host chart, OnTick,
  byte-faithful. OnTimer scaffold present but dormant (no satellite enabled).
- Step 2: satellite-1 10145:XAUUSD (OnTimer, TIMER-SAFE).
- Step 3: satellite-2, measurement-gated GDAXI vs 12969:USDJPY.

## Architecture

- **Host runner (slot 0, OnTick).** Reuses the line-verified
  `QM_Mod_FtmoJointRangeBreakout_20180.mqh` through the DEFAULT single-symbol QM_Entry
  path (`explicit_magic == 0`), byte-identical to standalone QM5_9936. Its +1R 2-bar-swing
  trailing stop is per-tick (RECON B `:23-27`) and reproduces exactly because the runner
  sees the host tick stream (RECON A `:19-26`). The runner is NOT timer-driven — where the
  task's "OnTimer-driven loop" framing conflicts with the exit-cadence recon, the recon
  wins.
- **OnTimer (model-second, `EventSetTimer(1)`).** Drives the account-equity sampler at 1 s
  resolution and the non-host satellite dispatch (per-symbol new-bar detection via
  `QM_IsNewBar(sym, tf)`). Dormant in step 1.
- **Single-symbol vs basket.** Basket mode (`QM_SymbolGuardInit` + `QM_BasketWarmupHistory`)
  activates only when >1 distinct enabled sleeve symbol exists. Step 1 = {USDJPY} =>
  single-symbol mode => byte-identical framework path to standalone 9936. Fidelity
  (recon) is prioritised over the plan's "warm all three in the scaffold" (Step 0).
- **Magic.** Slot-pinned: slot 0 = USDJPY.DWX (magic 201810000), slot 1 = XAUUSD.DWX
  (201810001, registered ahead for step 2). `magic = ea_id*10000 + slot`.

## Fidelity control (fixes the 20180 cross-vintage defect)

Compile BOTH standalone 9936 and this EA from ONE framework state; run BOTH sequentially
on ONE reserved terminal over ONE window with matched (canonical) commission; harvest each
`TRADE_CLOSED` stream; diff with `tools/strategy_farm/compare_joint_replay.py`. Admission:
`match_rate == 1.0`, zero unmatched.

## Backtest-only guards

Refuses non-tester init, `RISK_PERCENT > 0`, any enforcing `prop_phase`, non-zero stress.
`RISK_FIXED` only (HR4). No live/demo/ftmo set, no deploy manifest; registry status
`backtest-only`.
