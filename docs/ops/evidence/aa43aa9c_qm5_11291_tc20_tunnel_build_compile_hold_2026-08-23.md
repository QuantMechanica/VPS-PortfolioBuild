# QM5_11291 Build Evidence — Strategy Implemented, Governed Compile Held

- Task: `aa43aa9c-27b9-4ee3-b71c-58c1a4abd0f5` (`build_ea`, priority 50, assigned to Codex)
- EA: `QM5_11291_tc20-ema18-28-wma5-12-rsi21-h1`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11291_tc20-ema18-28-wma5-12-rsi21-h1.md`
- Current MQ5 SHA-256: `d03f5e8cb8231072953ce3b5f3055028de1c1196161aa432d039a5722ca1c1c5`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Governed identity

The card declares `g0_status: APPROVED`, `ea_id: QM5_11291`, and slug
`tc20-ema18-28-wma5-12-rsi21-h1`. The active EA registry row matches. Three active
magic rows bind slots 0-2 to EURUSD.DWX, GBPUSD.DWX, and USDJPY.DWX.

## Card implementation

The prior tracked source was an empty strategy skeleton. This task implemented the
approved H1 system:

- EMA(18)/EMA(28) tunnel compression within 0.2 ATR(14);
- WMA(5)/WMA(12) cross through the tunnel with RSI(21) midline confirmation;
- optional card-authorized extra-strong fast/slow WMA cross;
- fixed 50-pip stop and target baseline plus the authorized 2-ATR stop variant;
- opposite-side tunnel cross exit and 20-pip new-entry spread cap;
- cached indicator state refreshed once per closed H1 bar;
- current MAE lifecycle hook, zero-initialized entry request, governed host magic via
  `qm_magic_slot_offset`, central Friday close, and mandatory two-axis news blackout;
- no ML, grid, martingale, external runtime data, or live operation.

Three H1 backtest presets were regenerated with their governed slots. Every preset
contains `RISK_FIXED=1000` and `RISK_PERCENT=0`; source stale-news maximum is 336 hours.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS; 4 files checked, zero findings, stale-news ceiling 336 hours.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero violations.
- `gen_setfile.ps1`: PASS for all three governed symbols.
- `git diff --check`: clean for the EA package.
- The untracked EX5 generated from the former empty skeleton was removed; it is not current-source evidence.

## Compile boundary

Direct strict `build_check.ps1` stopped before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal64 factory processes are active.
No terminal was started, stopped, interrupted, or bypassed.

The sanctioned command
`python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile QM5_11291_tc20-ema18-28-wma5-12-rsi21-h1`
was refused without creating a row: `WORK_ITEMS_EXIST`. The terminal predecessor
`afac9010-dbb3-4888-8077-a268a141215c` is a `COMPILE_FAIL` for the old skeleton
(`EA_Q08_MAE_HOOK_MISSING`, `EA_TRADE_REQUEST_UNINITIALIZED`), not evidence for this
source. Fresh governed compile supersede authorization is required. Smoke was not run,
and no pipeline verdict is claimed.

Short verdict: `SOURCE_READY_COMPILE_HELD: implementation/static gates PASS; strict compile held by live-factory guard and prior work item.`
