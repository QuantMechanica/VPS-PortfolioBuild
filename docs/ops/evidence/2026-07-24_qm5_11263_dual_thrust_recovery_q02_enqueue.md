# QM5_11263 Dual Thrust build recovery and Q02 enqueue

Date: 2026-07-24
Branch: `agents/board-advisor`
Build task: `6b05565a-ea78-45bb-9194-5a4b40ad9556`

## Outcome

`QM5_11263_qt-dual-thrust` was recovered from its exhausted Q01 compile
failure, compiled with zero errors and zero warnings, supplied with four
RISK_FIXED M1 setfiles, and advanced into the staged Q02 queue.

This unit adds a structural daily opening-range sleeve with two FX hosts
(`GBPUSD.DWX`, `EURUSD.DWX`) rather than adding another index/metal/energy-only
build.

## Authority and identity checks

- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11263_qt-dual-thrust.md`
  (`g0_status: APPROVED`, R1-R4 all PASS).
- Reproducible source:
  `je-suis-tm/quant-trading`, `Dual Thrust backtest.py`, source ID
  `72f9fcfa-6c75-5544-80c4-31e15c9817ab`.
- Existing EA registry identity:
  `11263,qt-dual-thrust,...,active`.
- Existing magic rows were retained unchanged:
  `GBPUSD.DWX` slot 0, `EURUSD.DWX` slot 1, `XAUUSD.DWX` slot 2, and
  `GDAXI.DWX` slot 3.
- The card's `GER40.DWX` label is absent from
  `dwx_symbol_matrix.csv`; the pre-registered, matrix-available DAX port
  `GDAXI.DWX` remains the governed substitute.
- Before source changes, the new farm task was atomically moved from
  `pending` to `active` with
  `claimed_by=codex:agents/board-advisor`. No other pending/active build task
  or Q02 work item existed for this EA.

## Recovery scope

The previous task `bf45d336-fba5-4b4c-a795-edec2649b385` was terminal
`failed` after exhausting retries on MQL5's illegal C++-style
`(void)broker_time` cast. The in-place recovery:

- removed that compile blocker;
- restored Q08 MAE sampling as the first `OnTick` action;
- placed Friday close and all management/exit paths above the entry-only news
  blackout;
- zero-initialized every `QM_EntryRequest`;
- changed the prior-session OHLC accumulator to bounded O(1) tick-state so
  news blackouts cannot remove observations from the next session's range;
- retained the card's five-session Dual Thrust thresholds, symmetric
  long/short rules, opposite-threshold close/reversal behavior, fixed-EST
  session, and catastrophic M30 ATR stop.

No registry, portfolio gate, T_Live manifest, or live terminal file was
changed.

## Deterministic validation

- `validate_spec_doc.py`: `PASS`.
- `build_check.ps1`: `PASS`, 0 failures; report
  `D:\QM\reports\framework\21\build_check_20260724_143513.json`.
- `compile_one.ps1 -Strict`: `PASS`, 0 errors, 0 warnings; summary
  `D:\QM\reports\compile\20260724_143543\summary.csv`.
- `.ex5`: 339,290 bytes, SHA256
  `d613a4459b028a5af353109bd4ec40f403f8d69ee8271bb15402d2be8e068ed4`.
- Four generated setfiles all specify `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and their registered magic slot.

| Symbol | Slot | Setfile SHA256 |
|---|---:|---|
| GBPUSD.DWX | 0 | `54af69a78485588678fecfb91a64c058f7f44a0b8578286176baefe1afa2f019` |
| EURUSD.DWX | 1 | `1710d1c389bbcf5c403a63d49e2d66c77398ef34a3735e4789f1684a059ea5bc` |
| XAUUSD.DWX | 2 | `2c255e974d812840d5f9aee250dfad6e4e9d7926df11c18e9274659e8fff1409` |
| GDAXI.DWX | 3 | `174097cad96ba93d200422997979a1da7f3771047f1bef513049dcd601fec94b` |

## Tester-capacity boundary

No smoke or backtest was launched. At the decision point the farm had nine
active work items and all nine live `terminal_worker` daemons were occupied
(`T1`, `T2`, `T3`, `T4`, `T6`, `T7`, `T8`, `T9`, `T10`); the `T5` daemon was
absent. The canonical build-result schema therefore authorized
`smoke_result: deferred_p2_smoke`.

`record-build` moved the task to `done` at
`2026-07-24T14:38:33Z` and created this diverse stage-1 Q02 wave:

| Work item | Symbol | Status at enqueue |
|---|---|---|
| `85b75307-6056-43aa-bb59-c9524c1bb4cb` | GBPUSD.DWX | pending |
| `5033f7f7-b705-451f-8d98-5aa52253ee74` | GDAXI.DWX | pending |
| `77d853cd-83b6-4cb4-b370-f844eaadc77f` | XAUUSD.DWX | pending |

`EURUSD.DWX` is preserved in
`D:\QM\strategy_farm\state\q02_deferred_symbols.json` as the fourth member of
the priority cohort and will be promoted by the normal staged-Q02 mechanism.

The recorder also emitted `fail_code=smoke_failed` because its generic
blocked-reason classifier sees the word "smoke" before its deferred-smoke
special case. Canonical state is nevertheless `done`, the deferred result is
sanctioned by `SCHEMAS.md`, and all three Q02 rows were created. This metadata
quirk was documented rather than expanding this EA-scoped unit into a farm
controller change.

## Artifact commits

- `1ba7ed91a832d3e291345ad3c6f5e09ac3b1d9bd` — recovered MQL5 source.
- `ecce271c91c6014fc7ea665202dad05f3509c25a` — compiled binary, SPEC, card
  copy, and four fixed-risk setfiles.

Both commits were created by the deterministic farm dirty-build guard while
the claimed task was active.
