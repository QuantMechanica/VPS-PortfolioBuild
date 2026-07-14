# FTMO stream-gap root cause - 2026-07-10

## Result

The three A/B stream mismatches are deterministic framework-emission defects,
not partial closes or scale-in/out behavior. Every MT5 report has exactly one
entry and one exit deal per reported trade.

| sleeve | report exits | stream exits | missing | classification |
|---|---:|---:|---:|---|
| `10118/NDX` | 716 | 714 | 2 | 1 kill-switch close, 1 tester end close |
| `10546/XAUUSD` | 1,762 | 1,708 | 54 | 54 kill-switch closes |
| `10706/GBPUSD` | 367 | 364 | 3 | 3 kill-switch closes |

All 58 kill-switch gaps have a same-second `KILL_SWITCH_TRIGGERED` event with
`reason=KS_DAILY_LOSS` and `closed_positions=1` in the structured EA log. The
corresponding MT5 report exit deal has an empty comment and is absent from the
Q08 JSONL stream. The remaining `10118` gap is the final MT5 deal with comment
`end of test` at `2025-12-30 23:59:48`.

## Code cause

`QM_KillSwitchClosePositionsByMagic()` closes the selected position through the
global `CTrade g_qm_ks_trade`, but `QM_KillSwitchInit()` never calls
`g_qm_ks_trade.SetExpertMagicNumber(magic)`. The close order therefore uses the
default magic `0`.

`QM_FrameworkOnTradeTransaction()` reads the close deal magic and immediately
returns unless `QM_FrameworkOwnsMagicSymbol()` accepts it. Magic `0` is rejected,
so no `TRADE_CLOSED` event is written and the tracked MAE state is not consumed.

The tester's automatic end-of-test liquidation occurs after the EA shutdown
path has flushed the Q08 buffer. It consequently cannot be emitted by the EA's
normal `OnTradeTransaction` path.

Relevant ownership-controlled files:

- `framework/include/QM/QM_KillSwitch.mqh`
- `framework/include/QM/QM_Common.mqh`

## Required CTO / Quality-Tech repair

1. In `QM_KillSwitchInit()`, set the close helper's expert magic to the supplied
   `magic` before any possible close. Add a real tester fixture proving that a
   `KS_DAILY_LOSS` close deal retains the EA magic and produces one Q08 row.
2. Preserve the existing position-selection-by-magic guard; setting the close
   request magic is evidence attribution, not exposure broadening.
3. For tester shutdown, emit an `OPEN_AT_TEST_END` record before Q08 flush for
   every still-open owned position. It must contain position identifier, entry
   time, current tracked MAE, volume, symbol, and magic.
4. In Python report reconciliation, pair each `OPEN_AT_TEST_END` record with the
   report's `end of test` exit deal and create the final baseline row using the
   report's complete entry/exit commissions, swap, and profit. Fail if pairing
   is not one-to-one.
5. Stop duplicating closing commission heuristically once the emitter outputs
   allocated entry, exit, and round-trip commission fields as specified in
   `Q08_ROUND_TRIP_COMMISSION_HANDOFF_2026-07-10.md`.
6. Required regression cases: ordinary close, SL, TP, strategy close, Friday
   close, kill-switch close, partial close, scale-in/out, INOUT reversal, and
   open position at tester end. Every report exit must be represented exactly
   once and total stream net must reconcile to MT5 within cent-rounding tolerance.

## Operational decision

No affected stream is eligible for FTMO portfolio simulation. The prior A and B
book outputs remain invalidated. No preset, deploy manifest, or live account may
consume a synthesized replacement row with invented MAE.
