# QM5_11407 GBPUSD H4 Q05 Append-Only Infrastructure Retry

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Repository head at enqueue: `4e41a1a097b19beee5d435b5da6c40ffc447266b`

Status at readback: one authenticated Q05 successor active on paced worker T5

## Outcome

The frozen 66-pair FX cointegration scan is fully mechanized. The preferred
anchors are not blocked at Q02: `QM5_12532` retains logical-basket Q02 PASS,
Q04 PASS, and Q05 FAIL, while `QM5_12533` retains logical-basket Q02 PASS and
Q04 FAIL. Creating another scan-derived card or basket would duplicate an
existing relationship.

The mission fallback therefore advanced the existing approved FX sleeve
`QM5_11407_carter-tf17-ema18-adx-pullback` on `GBPUSD.DWX` H4. Its Q04 row
`f56b82f6-89b9-457d-8862-b73cd22c74e8` is `PASS_SOFT`; its only prior Q05
row, `543f3ab5-016d-4f52-8ad3-43787ae0c4d6`, is terminal
`done / INFRA_FAIL`. The governed append-only path preserved that row and
created successor `0ea708b1-d1f5-4197-aa4f-6e9aa5a8ebe5`.

Immediate readback found exactly one open Q05 row for the EA/symbol. The
normal paced worker had already claimed it on T5; this session did not invoke
a dispatch tick or launch a tester.

## Why This Fallback Is Eligible

The OWNER-approved card cites Thomas Carter, *20 Trend Following Systems*
(2014), Strategy #17, through its locally preserved source PDF. It is a
deterministic H4 EMA18 pullback with ADX trend-strength confirmation,
stop-order entry, and swing/ATR exits. The card declares 40 trades per year
per symbol, below the governed 100-trade FX cadence cutoff, and has R1-R4 PASS.
It contains no ML, adaptive fitting, grid, martingale, or pyramiding logic.

The GBPUSD preset remains a backtest fixed-risk contract:

| Binding | Value |
|---|---|
| EA / slug | `QM5_11407` / `carter-tf17-ema18-adx-pullback` |
| Symbol / timeframe | `GBPUSD.DWX` / H4 |
| Expected cadence | 40 trades/year/symbol |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Magic slot / magic | 1 / `114070001`, active |
| MQ5 SHA-256 | `18f26338bc5dd9b8a365fbd729a789390542d2772b8983fd0a54da1453ad9701` |
| EX5 SHA-256 | `33f36cfeba3d967641935e9eeba1cb9d2b77f740d7acdfc1b0f647f0f3d7c285` |
| Setfile SHA-256 | `77d3028c3270ffa49c85f72c95f5cebf0c14e74c6873d09d93a0cbd1a2646a70` |

These current hashes exactly match the Q04 preflight bindings. No strategy,
binary, setfile, registry, or magic mutation was needed.

## Preserved Evidence and Retry Basis

The Q04 aggregate completed three real-tick OOS folds and returned
`PASS_SOFT`: net PF values were 1.793, 0.915, and 2.797, with a mean of 1.835.
Its aggregate SHA-256 is
`7c58757444760b4eb0e0e033f04a9228fbbe6d51ae94cd4308e97c54be28b52f`.

The original Q05 aggregate was classified infrastructure-only because the
tester summary carried `BARS_ZERO`, `EMPTY_EXPERT`, `EMPTY_SYMBOL`,
`M0_1970_PERIOD`, and `RUN_STATUS_INVALID`. It predates the governed
custom-history copy-on-claim repair and is not an economic strategy verdict.
Its aggregate SHA-256 is
`c08ce89cd0f97e76e5401c7cba315a2b132ad534a83b9904f1c29017720017d8`.

## Capacity and Enqueue Receipt

The immediate fail-closed capacity sample at
`2026-08-11T16:12:34+00:00` found three executing factory terminals:

```text
T1, T2, T3
```

Three is below the binding seven-terminal ceiling. `T_Live` and the unrelated
FTMO terminal were excluded and not controlled. Before mutation, an online
SQLite backup returned `PRAGMA quick_check=ok`:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11407_q05_append_20260811T161238Z.sqlite`

The supported exact-row command was:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest `
  --ea QM5_11407 --phase Q05 `
  --from-work-item-id f56b82f6-89b9-457d-8862-b73cd22c74e8 `
  --append-only-rerun-of 543f3ab5-016d-4f52-8ad3-43787ae0c4d6 `
  --rerun-reason "Paced-fleet forex fallback: preserve the pre-custom-history Q05 BARS_ZERO/empty-identity infrastructure result and append one authenticated GBPUSD.DWX H4 Stress MEDIUM successor; approved Thomas Carter mechanics and RISK_FIXED contract unchanged." `
  --expected-current-ex5-sha256 33f36cfeba3d967641935e9eeba1cb9d2b77f740d7acdfc1b0f647f0f3d7c285
```

It created one row, requeued zero rows, and skipped zero rows. Post-enqueue
`PRAGMA quick_check` remained `ok`. The predecessor remains terminal and the
successor payload binds the current MQ5, EX5, setfile, expert, H4 period, and
GBPUSD execution identity.

Machine-readable evidence:
`artifacts/qm5_11407_gbpusd_q05_append_only_retry_20260811T161249Z.json`.

## Safety Boundary

- No manual backtest, dispatch tick, terminal reservation, or process control
  was performed.
- No Strategy Card, EA source/binary, setfile, registry, or magic row changed.
- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No `T_Live` file, manifest, process, live setfile, or AutoTrading state
  changed.
- Existing unrelated worktree changes were preserved and excluded.
