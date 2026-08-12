# QM5_20253 WTI R3-q4 Q01 and Q02 CPU-Ceiling Evidence

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: Q01 PASS; target-only Q02 dry run PASS; guarded apply skipped because
the paced-fleet CPU ceiling was binding. A subsequent readback observed one
Q02 item already active on T10.

## Build outcome

`QM5_20253_wti-vr3-mom` is a source-bounded, low-frequency WTI sleeve. It
implements the Mehlitz-Auer R3-q4 memory state: the latest three completed
monthly log returns define the ranking direction, while the 32-return robust
variance ratio uses lags 1-3, VR weights 1.5/1.0/0.5, robust-variance weights
2.25/1.0/0.25, and the fixed two-sided 10% threshold
`1.64485362695147`. Significant persistence follows R3; significant
anti-persistence reverses it; insignificant states remain flat.

This is mechanically distinct from `QM5_13134_energy-vr-mom`, whose WTI
path is R1-q2 with one ranking return, one autocorrelation lag, and one robust
variance term. The governed dedup pass found no exact collision and manual
review resolved that expected source-family neighbor.

## Q01 validation

- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile evidence: `D:/QM/reports/compile/20260806_205827/summary.csv`.
- Framework build check: PASS, 0 failures and 0 warnings.
- Build-check evidence:
  `D:/QM/reports/framework/21/build_check_20260806_205827.json`.
- EA source SHA-256:
  `E67490A66EDF3DCFBED4B509E6B270D44049948E905F71135B670E999825045E`.
- EX5 SHA-256:
  `5891A4E0DCB570185735BD7D8E957DAD034F64A031FC10EB2580DEC756037E1F`.
- Backtest setfile SHA-256:
  `0E7F9FF8387932E22EF30D7A467BCF9D56620FF1055D29DD47090F1F38649339`.
- Backtest risk is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` on `XTIUSD.DWX`, D1.
- EA ID 20253 and slot-0 magic 202530000 are present in the deterministic
  registries and generated resolver.
- No manual backtest was run.

## Guarded Q02 dry run

The canonical no-mutation command was:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20253
```

The evidence file
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, generated at
`2026-08-06T20:51:50Z`, recorded `apply=false`, target `QM5_20253`, and
exactly one priority-track `never_tested` selection:

- symbol: `XTIUSD.DWX`;
- setfile: `QM5_20253_wti-vr3-mom_XTIUSD.DWX_D1_backtest.set`;
- pending rows before dry run: 1,434;
- queue ceiling: 7,000; and
- zero stranded or deferred-promotion selections.

A read-only `farmctl work-items --ea QM5_20253` query returned zero rows,
confirming that the dry run did not insert or duplicate a work item.

## Binding CPU-ceiling stop

At `2026-08-06T20:51:59.7739343Z`, a path-exact process sample found eight
factory terminals, above the binding maximum of seven:

```text
T2, T3, T5, T6, T7, T8, T9, T10
```

Only executable paths matching `D:/QM/mt5/T1..T10/terminal64.exe` counted.
No `T_Live` or other MT5 process counted. Because the sample was over the
ceiling, the enqueue command with `--apply` was not executed.

## Post-stop farm state

A post-commit readback found that the shared farm had subsequently created
exactly one Q02 row at `2026-08-06T20:52:58Z`, after the dry-run/ceiling
snapshot. At observation it was `active`, `claimed_by=T10`, with
`attempt_count=0` and work-item ID
`ec4f0dcd-3ddc-4bcc-b2cd-43e8cd8a93da`. No second row existed.

This agent did not execute the apply command or intervene in the claimed run.
The active row satisfies the requested Q02 enqueue; normal workers own its
execution and verdict. The annual WTI calendar prescreen and the card's
minimum five completed trades per full post-warm-up year remain binding
retirement checks.

For provenance, the guarded commands associated with this target are:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20253
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20253 --apply
```

## Safety

- This agent did not insert, claim, dispatch, or duplicate the Q02 row.
- This agent did not launch, stop, reserve, reap, or control a tester or
  terminal process.
- No live or deployment setfile was created.
- `T_Live`, AutoTrading, the live manifest, and the portfolio gate were not
  touched.
