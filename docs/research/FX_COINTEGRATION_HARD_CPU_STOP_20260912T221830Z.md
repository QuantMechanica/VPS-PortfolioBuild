# FX cointegration fallback Q02 / hard CPU stop

Recorded: 2026-09-12T22:18:30Z (2026-09-13 00:18 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `ac347d06f41142f9417619fa0ca49c64d5324df4`

## Outcome

The frozen 66-pair FX cointegration frontier remains fully mechanized, so a
new scan-derived Card or EA would be duplicate work. The two preferred anchors
are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then Q05
  `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then Q04 `FAIL`.

The mission-authorized existing fallback remains the concrete EURUSD/GBPUSD H1
basket `QM5_12507_pair-coint-z`. Its unique logical Q02 row is already
enqueued, pending, unclaimed, attempt zero, unheld, and `priority_track=true`:

- logical symbol: `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`;
- work item: `547c4fd3-f3fd-4c59-b9dc-654e96521251`;
- canonical claim-order rank: 20 of 2,051 pending claimable rows;
- prior authenticated logical Q01: `PASS` with 632 observed leg trades;
- manifest: `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`.

Appending another Q02 row, re-marking the row, or rewriting its lineage would
not advance the funnel and would violate the duplicate guard.

## PACER guard and risk contract

No generated `.mq5` was written or edited, so the mandatory post-write,
pre-compile boundary was not entered. The existing fallback source was checked
read-only with the binding audit command and returned exit zero, `ok=true`, and
zero `EA_FRAMEWORK_INPUT_PINNED` findings:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
```

The canonical logical setfile remains fixed-risk with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No compile or compile enqueue was
attempted.

## Binding capacity stop

Five whole-host CPU samples taken two seconds apart were 91%, 99%, 100%, 97%,
and 71%. The average was 91.6% and the maximum was 100%. The explicit ceiling
binds when either value is at least 97%, so the maximum triggered the stop.

Immediately before the sample window, the supported slot scan observed five
factory testers on T1, T3, T6, T9, and T10. All ten enabled terminal-worker
daemons were alive. `T_Live` and the external FTMO terminal were observed only
to exclude them and were not controlled.

Per the binding stop, no claim, dispatch tick, tester launch, terminal
reservation, queue mutation, duplicate enqueue, compile, or backtest followed.
The ordinary paced fleet retains ownership of the already-enqueued Q02 row.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  path changed.
- No `T_Live` manifest, terminal, deploy artifact, or AutoTrading state
  changed.
- No Card, EA source or binary, setfile, basket manifest, registry, magic row,
  farm task, work item, priority, hold, claim, or verdict changed.
- Unrelated shared-worktree changes were preserved and excluded from this
  evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_hard_cpu_stop_20260912T221830Z_board_advisor.json`.
