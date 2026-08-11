# QM5_10977 GBPUSD H1 Q02 infrastructure repair

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Farm claim: `543c8404-8439-4337-a9cf-42a6f22baa2c`

Status at readback: one current-artifact Q02 successor pending and unclaimed

## Outcome

The diversity-first approved build backlog had no collision-free, testable
forex, crypto, rates, pair, or non-XNG energy card with all deterministic
registry prerequisites. The viable priority-2 lane was therefore the
previously unevaluated `GBPUSD.DWX` branch of
`QM5_10977_ftmo-bb-sqz`.

The preserved predecessor
`b9fc8a59-c929-4fd8-aff2-6e7747f9b99b` is terminal
`failed / INFRA_FAIL`. The append-only repair created successor
`0689ba5c-9b1f-40d3-8ac6-618814d6f623` at
`2026-08-11T04:12:26+00:00`. Immediate readback found it `pending`, attempt
zero, unclaimed, without a verdict, and the sole open row for this EA.

Normal paced workers own claim, Custom-history privatization, dispatch, and
tester evidence. This session did not manually dispatch or launch a tester.

## Strategy and source boundary

The OWNER-approved Card cites FTMO, *Technical analysis - Bollinger Bands as
a combination of trend and volatility* (2022-10-21). Its R1-R4 gates are PASS.

The H1 rule is a fixed volatility-compression breakout: a 20-bar Bollinger
width in the lowest twentieth percentile of 120 bars arms a breakout for six
bars, with fixed band/ATR stops, 2.5R target, 1.2R break-even trigger, and a
36-bar time exit. The card estimates 36 trades/year/symbol. It uses no ML,
online fitting, grid, martingale, or adaptive PnL mechanics.

The GBPUSD fixed-risk contract remains unchanged:

| Binding | Value |
|---|---|
| EA / slug | `QM5_10977` / `ftmo-bb-sqz` |
| Symbol / timeframe | `GBPUSD.DWX` / H1 |
| Magic slot / magic | `1` / `109770001`, ACTIVE |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Tester model | `4` |
| Approved Card SHA-256 | `108851969ea63112b01df2b905923a163af91341010b06470bb9f0d78663adba` |
| MQ5 SHA-256 | `582dbd20f2a6677978035f9c8f52f59fb18cff451636ddb80d397424541229d4` |
| Repaired EX5 SHA-256 | `a6033a1283427856e6036bced67a9d6ae8629ed7856a409629ea1ecfecf1e8a0` |
| Repaired setfile SHA-256 | `554efa711a7e393c4a3f2d98cc8670512e438cbbb1cf0bcfb10f7e786b88fb0c` |

## Failure diagnosis

The predecessor was bound to T8 and the expected source artifacts. Its
surviving tester configuration specifies the correct expert, `GBPUSD.DWX`,
H1, model 4, 2018-07-02 through 2022-12-31, and the fixed-risk setfile.

The bound terminal log shows the tester starting, followed by repeated
`'GBPUSD.DWX' file opening or reading error [32]` messages. Windows error 32
is a file-sharing violation. The work-item payload records zero progress,
21.59 stalled minutes, `NO_FORWARD_PROGRESS`, and `ACTIVE_TIMEOUT`; no tester
report was produced. This is infrastructure-only evidence and establishes no
economic verdict.

The legacy work-item log had been purged. Its exact database path was restored
with an explicitly labeled evidence-reconstruction receipt derived only from
the surviving payload-bound tester config and T8 log. The restored file and
committed mirror have identical SHA-256
`08e1d8df6ca320da1ed500b7ec0d3983e3f1337a3da5c5c776416a5e499a0671`.
The receipt states that it is not the original worker log.

## Artifact repair and validation

The guarded enqueue detected artifact drift between the historical row and
the current fixed-risk set binding. The unchanged MQ5 source was therefore
strictly recompiled against the current registry and magic resolver. The EX5
transitioned from
`24498aeefbfacf32189486722af640722a7bcd2babceb5722752f468d46ab241` to
`a6033a1283427856e6036bced67a9d6ae8629ed7856a409629ea1ecfecf1e8a0`.

Validation results:

- strict compile: PASS, zero errors, zero warnings;
- focused build check: PASS, zero failures;
- SPEC validation: PASS;
- active EA registry and all four active magic rows verified;
- SQLite `PRAGMA quick_check`: `ok`;
- source MQ5 and all strategy parameters unchanged.

The build checker emitted one lexical advisory for `current_spread <= 0`.
Manual inspection confirmed the function returns `false` in that branch,
which permits `.DWX` zero modeled spread exactly as the SPEC requires; no code
change was made.

## Claim, capacity, and enqueue

The atomic claim rechecked that the source row remained terminal
`failed / INFRA_FAIL`, and that the EA had no open work item, prior economic
GBPUSD verdict, active farm task, or competing agent claim. The pre-claim
SQLite backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10977_q02_claim_20260811T040642Z.sqlite`

The immediate post-enqueue capacity sample found one executing factory
terminal (`T8`), below the binding ceiling of seven. `T_Live` and the unrelated
FTMO terminal were observed but excluded from factory capacity and control.

The supported exact-row enqueue preserved the predecessor and bound the
successor to the repaired EX5, current setfile, expert, symbol, period, MQ5,
and fixed-risk contract. It created exactly one row; repeated calls are
duplicate-guarded by the predecessor ID.

## Safety

- No manual backtest, smoke test, dispatch tick, or pipeline phase was run.
- No Strategy Card or EA source logic changed.
- No `T_Live` path, deploy manifest, AutoTrading state, portfolio gate, or
  live-trading artifact changed.
- Pre-existing unrelated worktree changes were preserved and excluded.

Machine-readable evidence:
`artifacts/qm5_10977_gbpusd_q02_history_lock_repair_20260811T041226Z.json`.
