# FX cointegration QM5_12507 logical Q02 queue guard

Recorded: 2026-09-09T18:20:20Z (20:20 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `4bf86fd2d48c05b98ff85939a0292e9052643f86`

## Outcome

No new pair was carded or built. The reputable-source frozen 66-pair scan is
already fully mechanized, so another scan-derived identity would duplicate
governed work. The requested anchors need no Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then Q05
  `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then Q04
  `FAIL`.

The selected non-duplicate fallback remains the approved, built EURUSD/GBPUSD
H1 basket `QM5_12507_pair-coint-z`. Its one logical-basket Q02 row,
`547c4fd3-f3fd-4c59-b9dc-654e96521251`, remains pending, unclaimed, at attempt
zero and without a verdict. A canonical priority dry-run returned
`already_priority_track=true`, so no second enqueue and no redundant priority
rewrite was applied.

The package retains its `.ex5`, basket manifest, and logical backtest setfile.
That setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Capacity and PACER guard

The canonical farm had three active rows: Q08 `QM5_36002` on T5 and two
`OPT_CENSUS` rows (`QM5_41322` on T10 and `QM5_41345` on T6). The path-anchored
process snapshot independently found only T5, T6, and T10 factory tester
processes. `T_Live` and the unrelated FTMO terminal were excluded and not
controlled.

Five one-second whole-host CPU samples were `94.150163`, `72.957601`,
`78.524497`, `61.644311`, and `67.108901` percent. Their average was
`74.877095%` and maximum `94.150163%`, below the binding `97%` hard ceiling.
Available physical memory was 28.479 GiB.

No `.mq5` was generated or modified. The existing fallback source was checked
read-only with:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
```

It exited zero with `ok=true` and zero `EA_FRAMEWORK_INPUT_PINNED` findings.
Because the target Q02 identity is already enqueued exactly once and already
priority-tracked, there was no legitimate compile or Q02 enqueue action to
take. Normal workers retain ownership of its eventual claim.

## Safety

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, queue row, priority, hold, claim, verdict, tester, terminal,
portfolio-admission/KPI/Q08-contribution surface, deploy manifest, `T_Live`, or
AutoTrading state changed. Existing unrelated shared-worktree changes were
left untouched and excluded from this commit.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_q02_queue_guard_20260909T182020Z_board_advisor.json`.

