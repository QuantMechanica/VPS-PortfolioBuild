# QM5_12844 card-of-record alignment

Task: `49a19ccb-ba4c-4dac-92d6-6bde1e5776f9`

EA: `QM5_12844_commodity-trend-crude`

Card of record:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12844_commodity-trend-crude.md`

## Result

Accepted the live corrected EA source in `C:/QM/repo/framework/EAs/QM5_12844_commodity-trend-crude/` as aligned to the OWNER-approved card and forced a fresh compile.

Verified alignment points:

- Entry path uses `QM_BUY_STOP` / `QM_SELL_STOP` pending stop orders at Donchian extremes.
- `use_stop_and_reverse=true` does not stamp `g_last_no_reverse_bar_time`, so same-bar reverse re-entry is not blocked after an opposite-signal close.
- `time_exit_bars=0` is disabled because the time-exit branch only runs when `time_exit_bars > 0`.
- No `_Symbol == XTIUSD.DWX` or `_Period == PERIOD_D1` no-trade gate remains in the EA source.
- Open-position management runs before news entry gating in `OnTick`; news can block new entries but does not skip exits/trailing.
- The divergent strategy-seeds card is annotated as superseded and points to the farm approved-card path.

## Verification

Build guardrails:

```text
python C:/QM/repo/tools/strategy_farm/validate_build_guardrails.py C:/QM/repo/framework/EAs/QM5_12844_commodity-trend-crude
verdict: PASS
findings: none
max_news_stale_hours: 336
```

Compile:

```text
python tools/strategy_farm/compile_ea.py --ea-label QM5_12844_commodity-trend-crude --force --json --fail-on-error
verdict: COMPILED
errors: 0
warnings: 0
ex5: C:/QM/repo/framework/EAs/QM5_12844_commodity-trend-crude/QM5_12844_commodity-trend-crude.ex5
compile log: C:/QM/repo/framework/build/compile/20260702_060547/QM5_12844_commodity-trend-crude.compile.log
```

Setfile guardrail spot-check:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `qm_news_stale_max_hours=336`
- `card_defaults_source=D:\QM\strategy_farm\artifacts\cards_approved\QM5_12844_commodity-trend-crude.md`

## Queue update

Existing non-active Q02 work item was reset to fresh pending without touching active backtests:

- `78955929-5fa7-46ab-88ba-34a8edfaefed`
- symbol: `XTIUSD.DWX`
- phase: `Q02`
- status: `pending`
- attempt_count: `0`

The work item payload now records this task id, the card-of-record path, and the compile result path.
