# QM5_12844 card-of-record alignment

Task: `49a19ccb-ba4c-4dac-92d6-6bde1e5776f9`
EA: `QM5_12844_commodity-trend-crude`
Date: 2026-07-02

## Verdict

REVIEW: the EA is aligned to the OWNER-approved card of record at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12844_commodity-trend-crude.md`. It compiles with 0 errors / 0 warnings, guardrails pass, and Q02 is already pending.

## Changes

- Converted entry behavior to Donchian stop orders: `QM_BUY_STOP` at the last N-bar high and `QM_SELL_STOP` at the last N-bar low.
- Implemented `use_stop_and_reverse=true` semantics: an opposite Donchian signal closes the open position; same-bar reverse is blocked only when `use_stop_and_reverse=false`.
- Fixed `time_exit_bars=0` so it disables the time exit instead of making the strategy impossible to trade.
- Removed the hardcoded `XTIUSD.DWX` / `PERIOD_D1` no-trade gate and removed the residual `qm_magic_slot_offset != 0` no-trade filter so registered multi-market baseline symbols can run without a rebuild.
- Reordered `OnTick`: kill/friday checks, management, pending cleanup, new-bar equity stream, then news blackout as an entry-only gate.
- Annotated the local EA card copy so the D: approved card remains the card of record.
- Updated the XTIUSD backtest set to the approved-card parameter names, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `qm_news_stale_max_hours=336`.

## Verification

- Compile command: `python C:\QM\repo\tools\strategy_farm\compile_ea.py --ea-label QM5_12844_commodity-trend-crude --force --json`
- Compile result: `COMPILED`, 0 errors, 0 warnings.
- EX5: `C:\QM\repo\framework\EAs\QM5_12844_commodity-trend-crude\QM5_12844_commodity-trend-crude.ex5`
- Compile log: `C:\QM\repo\framework\build\compile\20260702_060247\QM5_12844_commodity-trend-crude.compile.log`
- Guardrail command: `python tools/strategy_farm/validate_build_guardrails.py C:\QM\repo\framework\EAs\QM5_12844_commodity-trend-crude`
- Guardrail result: `PASS`, files_checked=2, findings=[], max_news_stale_hours=336.
- Static checks: no `Strategy_IsXtiD1`, no `_Period` entry gate, no hardcoded `XTIUSD.DWX` source gate, stop-order constants present, `time_exit_bars > 0` gates time-exit execution, news checks occur after `Strategy_ManageOpenPosition()`.

## Queue State

`python tools/strategy_farm/farmctl.py work-items --ea QM5_12844`:

- Q02 XTIUSD.DWX: `pending`, verdict NULL, claimed_by NULL, evidence_path NULL (`78955929-5fa7-46ab-88ba-34a8edfaefed`)

No terminal was started manually, no active backtest was interrupted, and no T_Live/AutoTrading setting was touched.
