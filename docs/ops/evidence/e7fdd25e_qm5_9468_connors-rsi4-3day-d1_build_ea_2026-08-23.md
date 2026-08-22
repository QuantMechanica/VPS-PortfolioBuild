# QM5_9468 Build Evidence - Connors RSI 4 Three-Day Reversion D1

- Task: 7fdd25e-d16c-44d3-bcbe-c22756021747 (uild_ea, priority 50, assigned to Gemini)
- EA: QM5_9468_connors-rsi4-3day-d1
- Approved card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9468_connors-rsi4-3day-d1.md
- Source MQ5 SHA-256: 34b09783e49b2b84319c15b56ff1d42620bb6ab76a16af21ef9954d5e76b4c7
- EX5 SHA-256: 466bc58004efef8f721cbc0e19fe40add71bf71605fac7e00a47a23ccba0729
- Outcome: BUILD_READY_REVIEW

## Governed Identity and Registries

- EA ID 9468 registered in ramework/registry/ea_id_registry.csv with source f14a5d7-e3f1-52be-910a-3ca6b736a152 and slug connors-rsi4-3day-d1.
- 13 active magic rows allocated in ramework/registry/magic_numbers.csv across slots 0..12 (base 94680000):
  - 0: GDAXI.DWX
  - 1: NDX.DWX
  - 2: SP500.DWX
  - 3: UK100.DWX
  - 4: WS30.DWX
  - 5: XAUUSD.DWX
  - 6: EURUSD.DWX
  - 7: GBPUSD.DWX
  - 8: USDJPY.DWX
  - 9: USDCHF.DWX
  - 10: AUDUSD.DWX
  - 11: USDCAD.DWX
  - 12: NZDUSD.DWX
- ramework/include/QM/QM_MagicResolver.mqh contains active 9468 entries across all 13 slots.

## Strategy Implementation

The EA implements Larry Connors' 4-Period RSI Three-Day Reversion (D1) specification:
- Macro trend filter: Close > SMA(200) on closed D1 bars.
- Entry signal: RSI(4) < 20.0 in an uptrend, buying on next bar open.
- Fixed Horizon Exit: Position closed mechanically after 3 daily bars (strategy_hold_bars = 3).
- Cooldown: 3 bars after exit before entering again.
- Protective Stop Loss: 2.5 * ATR(14) below entry.
- Spread filter: skip entry if spread > 0.25 * ATR(14).
- Risk model: ,000 fixed risk per trade in backtest (RISK_FIXED=1000, RISK_PERCENT=0.0).
- Framework conformance: OnTick MAE hook, news compliance gate, Friday close handling, zero-initialized QM_EntryRequest.

## Focused Verification

- alidate_spec_doc.py: PASS (1/1).
- uild_gate_hardening.py: PASS (0 failures, 0 warnings across all D2-D11 checks).
- alidate_build_guardrails.py: PASS (0 findings, 336 hr stale news ceiling).
- alidate_symbol_scope.py --fail-on-leak: PASS (SINGLE_SYMBOL_OK, 0 violations).
- gen_setfile.ps1: 13 setfiles generated in sets/ with strategy parameters and matching uild_hash.
