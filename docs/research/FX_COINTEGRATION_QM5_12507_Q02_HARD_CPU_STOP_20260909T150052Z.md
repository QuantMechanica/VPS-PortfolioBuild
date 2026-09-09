# FX cointegration QM5_12507 logical Q02 hard CPU stop

Recorded: 2026-09-09T15:00:52Z (17:00 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b2e5318451ef1fa635f623404014bb45e0333524`

## Outcome

No new pair was carded or built. The bounded 66-pair scan remains fully
mechanized, so another scan-derived identity would duplicate governed work.
The two requested anchors are beyond Q02 rather than blocked by a current
`ONINIT` or `NO_HISTORY` failure:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then Q05
  `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has a terminal Q02 `PASS`, then
  Q04 `FAIL`.

The non-duplicate fallback remains the approved low-frequency EURUSD/GBPUSD H1
basket `QM5_12507_pair-coint-z`. Its single canonical logical-basket Q02 work
item, `547c4fd3-f3fd-4c59-b9dc-654e96521251`, remains pending, unclaimed, at
attempt zero, and without a verdict. No second row was appended or
reprioritized.

The built package still contains its `.ex5` and `basket_manifest.json`. The
logical backtest setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Binding paced-capacity stop

The canonical farm had five active work items, below the seven-active-row
admission limit, and five factory terminals were running at the admission
snapshot (`T2`, `T4`, `T8`, `T9`, and `T10`). `T_Live` and the unrelated FTMO
terminal were observed only to exclude them and were not controlled.

Five one-second whole-host CPU samples were `95.708092%`, `98.242988%`,
`96.196880%`, `97.366182%`, and `99.414087%`. Their average was `97.385646%`
and their maximum was `99.414087%`, above the binding 97% ceiling. Available
physical memory was 41.097 GiB.

Per the mission's explicit resource rule, processing stopped. No source was
generated or edited, no compile or backtest work was enqueued, no work item was
claimed or dispatched, no tester was launched, and no terminal was controlled.

## PACER guard

No generated `.mq5` was written, so the mandatory post-write/pre-compile audit
boundary was not entered. The existing fallback source was nevertheless
checked read-only with:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
```

The command exited zero with `ok=true`, predicate
`EA_FRAMEWORK_INPUT_PINNED`, and zero findings. No compile command or compile
enqueue followed.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, queue row, priority, hold, claim, verdict, portfolio-admission,
portfolio-KPI, Q08-contribution, portfolio gate, deploy manifest, `T_Live`, or
AutoTrading surface changed. Unrelated shared-worktree changes were preserved
and excluded from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_hard_cpu_stop_20260909T150052Z_board_advisor.json`.
