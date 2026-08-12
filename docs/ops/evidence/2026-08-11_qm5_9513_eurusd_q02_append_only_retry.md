# QM5_9513 EURUSD D1 Q02 append-only infrastructure retry

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Farm claim: `b227bf83-00c1-44f1-9032-661b5208cb1d`

Status at readback: exactly one current-hash Q02 successor pending and unclaimed

## Outcome

The approved build backlog contained no non-duplicate diversity build with all
pre-allocated ACTIVE registry and magic bindings required by the governed build
path. The apparent low-frequency FX Q03 stalls also already had downstream Q04
evidence, so replaying them would not increase funnel throughput.

The priority-2 recovery therefore advanced the existing approved FX lane
`QM5_9513_lt-breakout-stack` on `EURUSD.DWX` D1. The canonical append-only
enqueue preserved terminal infrastructure row
`d0e72ff8-3f29-4419-b060-11db59cb81c5` and created successor
`67fd19a6-7165-463f-99ca-4e25528d8d6e` at
`2026-08-11T02:48:36+00:00`.

Immediate readback found the successor `pending`, attempt 0, unclaimed, without
a verdict, and the sole open `QM5_9513` / `EURUSD.DWX` / Q02 row. Normal paced
workers own claim, custom-history privatization, dispatch, and terminal
evidence. This action did not manually launch a tester.

## Strategy and source boundary

The OWNER-approved Card cites Robert Carver, *Leveraged Trading*, Harriman
House (2019), ISBN 9780857197214, Chapter 8 and Appendix C, together with the
author's official breakout spreadsheet. Its R1-R4 gates are PASS.

The EA is a structural, closed-D1-bar trend rule. It averages six fixed
rolling-range breakout forecasts (10, 20, 40, 80, 160, and 320 bars), enters
beyond a fixed +/-2 forecast threshold, exits at the zero crossing, and uses a
2.5 ATR emergency stop. It contains no ML, online fitting, grid, or martingale
mechanics. The farm-bound row estimates six trades/year for this exact lane;
execution remains D1-gated.

The EURUSD fixed-risk contract is unchanged:

| Binding | Value |
|---|---|
| EA / slug | `QM5_9513` / `lt-breakout-stack` |
| Symbol / timeframe | `EURUSD.DWX` / D1 |
| Magic slot / magic | `0` / `95130000`, ACTIVE |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Approved Card SHA-256 | `1cad503bdc027734607e84eb5a0e5ad412c9e00e4057e2efc1244c9de54bc823` |
| MQ5 SHA-256 | `fcd5dca87ac3fa196bb22c077fbd92b80f42976e7a5710217baf7e1347d055fe` |
| EX5 SHA-256 | `655b633fead5cc7e1a3809dc7be50d1ca966eaeb603f4ad9d99ecc0b348f7476` |
| Setfile SHA-256 | `fc1ce2c5555fc46b1ccda7a9ac55ec08997db735dd5b6ac738fef8d47fc5e9a2` |

## Failure diagnosis and repair boundary

The preserved predecessor exhausted three cold-cache attempts. All three
authenticated reports were invalid with `NO_HISTORY`, `BARS_ZERO`, empty
expert/symbol fields, and a 1970 period. The summary explicitly records no
OnInit failure and no log bomb. Its bound MQ5, EX5, and setfile hashes exactly
match the current canonical artifacts, ruling out source, binary, or parameter
drift.

The failure predates the governed custom-history copy-on-claim path documented
in `docs/ops/evidence/a83d3b5c_custom_history_copy_on_claim_2026-08-09.md`.
That repair privatizes and verifies the claimed terminal's declared Custom
history before runner spawn and fails closed on missing or mismatched archives.
No strategy-code or setfile mutation is warranted; the bounded repair is one
current-hash successor routed through that post-repair worker path.

## Claim, capacity, and enqueue

The atomic claim rechecked that the source row remained terminal
`failed / INFRA_FAIL`, and that the EA had no open work item, active farm task,
or competing agent claim. The pre-claim SQLite backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_9513_q02_claim_20260811T024647Z.sqlite`

The immediate pre-enqueue sample at `2026-08-11T04:48:10+02:00` found five
executing factory terminals:

```text
T10, T3, T6, T8, T9
```

Five is below the binding ceiling of seven. `T_Live` and the unrelated FTMO
terminal were excluded and not controlled. The supported exact-row command
was:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest `
  --ea QM5_9513 --phase Q02 `
  --from-work-item-id d0e72ff8-3f29-4419-b060-11db59cb81c5 `
  --append-only-rerun-of d0e72ff8-3f29-4419-b060-11db59cb81c5 `
  --rerun-reason "Paced-fleet diversity recovery: preserve infrastructure-only EURUSD.DWX D1 NO_HISTORY evidence and append one current-hash Q02 retry through the governed custom-history copy-on-claim runner; Robert Carver breakout mechanics and RISK_FIXED setfile unchanged." `
  --expected-current-ex5-sha256 655b633fead5cc7e1a3809dc7be50d1ca966eaeb603f4ad9d99ecc0b348f7476
```

Readback returned `PRAGMA quick_check=ok`. Repository HEAD observed after the
enqueue and before this evidence commit was
`141e0f9c640d64f69e801d593db11afa7bcef3ec`.

## Safety

- No manual smoke test, dispatch tick, terminal process control, or pipeline
  phase execution was performed.
- No Strategy Card, EA source/binary, setfile, registry, or magic row changed.
- No `T_Live` path, deploy manifest, AutoTrading state, portfolio gate, or
  live-trading artifact changed.
- Pre-existing unrelated worktree changes were preserved and excluded.

Machine-readable evidence:
`artifacts/qm5_9513_eurusd_q02_append_only_retry_20260811T024836Z.json`.
