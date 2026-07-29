# QM5_20181 — FTMO joint multi-symbol (OnTimer) — BACKTEST-ONLY

Measurement instrument. One EA runs the Q09-admitted runner+satellite book on ONE
simulated $100k account in ONE tester run so the account equity curve is REAL. Symbols
are input parameters; sleeves are dispatched by symbol; the EA is driven from OnTimer
for non-host satellites while the host runner stays on OnTick.

Built piece by piece (OWNER 2026-07-27, "Stück für Stück"), each sleeve admitted only at
`match_rate == 1.0` before the next is added:

- **Step 1:** scaffold + RUNNER only — 9936:USDJPY on the host chart, OnTick.
- **Step 2:** satellite-1 10145:XAUUSD is fully wired on OnTimer.
- **Step 3:** OWNER locked slot 2 to the deployable, timer-safe
  **13108:XTIUSD** sleeve on 2026-07-29. The governed three-sleeve set enables
  9936 + 10145 + 13108. The per-tick 13301 variant is not a slot in this EA.

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
  a restart-persisted closed-bar timestamp).
- **Isolation.** The host framework remains in single-symbol mode even with a
  satellite enabled. The satellite warms its own history and uses the explicit
  `QM_BasketOrder` symbol/magic path; it never mutates slot 0's framework ownership.
- **Magic.** Slot-pinned: slot 0 = USDJPY.DWX (magic 201810000), slot 1 = XAUUSD.DWX
  (201810001), slot 2 = XTIUSD.DWX (201810002). `magic = ea_id*10000 + slot`.

The source defaults keep both satellites disabled so singleton and two-sleeve controls
cannot silently change when loaded without their set file. Sleeve membership is explicit
in each governed set; `..._book3_9936_10145_13108.set` is the authoritative step-3 input.

## Fidelity control (fixes the 20180 cross-vintage defect)

Compile BOTH standalone 9936 and this EA from ONE framework state; run BOTH sequentially
on ONE reserved terminal over ONE window with matched (canonical) commission; harvest each
`TRADE_CLOSED` stream; diff with `tools/strategy_farm/compare_joint_replay.py`. Admission:
`match_rate == 1.0`, zero unmatched.

## Backtest-only guards

Refuses non-tester init, `RISK_PERCENT > 0`, any enforcing `prop_phase`, non-zero stress.
`RISK_FIXED` only (HR4). No live/demo/ftmo set, no deploy manifest; registry status
`backtest-only`.
