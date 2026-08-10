# QM5_1196 AUDUSD D1 Q02 Append-Only Infrastructure Retry

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Repository head at enqueue: `14ec6f8720f97697e8728b0e2bf12858c59f5761`

Status: one current-hash Q02 successor is pending and unclaimed

## Outcome

The frozen 66-pair FX cointegration frontier is already fully mechanized, and
the two preferred anchors are beyond Q02:

- `QM5_12532` has logical-basket Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS, followed by Q04 FAIL.

Creating another scan-derived card or basket would duplicate governed work.
The mission fallback therefore advanced the existing approved, low-frequency
FX card `QM5_1196_qp-fx-meanrev-linear` on `AUDUSD.DWX` D1.

The canonical append-only enqueue created exactly one Q02 row:

- source infrastructure row: `bc25ee6c-2922-4df3-bf88-d5e15eaa4c72`;
- new work item: `24a5a5d1-15af-4b4a-b6bf-195036aba1fa`;
- state at readback: `pending`, attempt 0, unclaimed, no verdict; and
- exact open-row count for `QM5_1196` / `AUDUSD.DWX` / Q02: one.

Normal paced workers own claim, dispatch, execution, and terminal evidence.
No tester was launched by this action.

## Strategy and identity boundary

The local approved card cites Sona Beluska's named-author Quantpedia article,
"How to Build Mean Reversion Strategies in Currencies." The implementation is
a deterministic monthly relative-return signal with linear exposure, ATR
emergency stops, and no ML, online fitting, grid, or martingale mechanics.

`QM5_1196` is not a logical multi-leg tester row. Each EA instance opens and
manages positions only on `_Symbol`; the other five currencies are read-only
history dependencies used to compute the cross-sectional signal. The AUDUSD
setfile therefore remains the correct single-symbol Q02 identity rather than a
synthetic logical-basket row.

The deterministic bindings at enqueue were:

| Binding | Value |
|---|---|
| EA registry | `1196,qp-fx-meanrev-linear,...,active` |
| AUDUSD slot / magic | `3` / `11960003`, active |
| EX5 SHA-256 | `f0ea458c155624c547eeb738f37bd8e3af5afd7a4585680eaf22f6e1135dc703` |
| MQ5 SHA-256 | `2dcdd2868e2bb5a2be9e02bb30a4e940bff063e6b845b87291f54e33bbfa7825` |
| Setfile SHA-256 | `59a81facbec11453556b22b6202219c2ea678050865545de45974b426c8eeadf` |
| Card-copy SHA-256 | `a3b578192e10ed9f6b84d38a1a8bd122727ff1b916c521d91cfb283e98da599d` |
| Risk contract | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=0.1667` |

The preserved predecessor is terminal `INFRA_FAIL`, not a strategy verdict.
Its row-bound summary reports `BARS_ZERO` and `INCOMPLETE_RUNS` on all three
attempts, with no ONINIT failure, while binding the same EX5, MQ5, and setfile
hashes. This retry follows the governed custom-history fleet repair recorded in
`docs/ops/evidence/2026-08-10_ramp10_serialization_gate_statonly_fix.md`; no
strategy code or parameter changed.

## Capacity gate and enqueue

The immediate fail-closed sample at `2026-08-11T00:39:25+02:00` found four
executing factory terminals:

```text
T1, T3, T6, T10
```

Four is below the binding ceiling of seven. `T_Live` and the unrelated FTMO
terminal were excluded and not controlled. The supported exact-row command was:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest `
  --ea QM5_1196 --phase Q02 `
  --from-work-item-id bc25ee6c-2922-4df3-bf88-d5e15eaa4c72 `
  --append-only-rerun-of bc25ee6c-2922-4df3-bf88-d5e15eaa4c72 `
  --rerun-reason "OWNER 2026-08-11 forex-book fallback: preserve infrastructure-only AUDUSD D1 BARS_ZERO/INCOMPLETE_RUNS evidence and append one current-hash Q02 retry after the governed custom-history fleet repair; no strategy mechanics changed." `
  --expected-current-ex5-sha256 f0ea458c155624c547eeb738f37bd8e3af5afd7a4585680eaf22f6e1135dc703
```

Readback found 14 historical exact rows, exactly one open row (the new
successor), and `PRAGMA quick_check=ok`.

## Safety

- No manual tester, pump, dispatch tick, terminal reservation, or process
  control was performed.
- No Strategy Card, EA source/binary, setfile, registry, or magic row changed.
- No `T_Live` file, manifest, process, AutoTrading state, live setfile, or
  deployment artifact changed.
- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- Pre-existing unrelated worktree changes were preserved and excluded.

Machine-readable evidence:
`artifacts/qm5_1196_audusd_q02_append_only_retry_20260811T003925+0200.json`.
