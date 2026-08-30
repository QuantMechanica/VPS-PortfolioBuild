# QM5_41011 FX stale-EX5 recovery and CPU-ceiling stop

Date: `2026-08-30`

Branch: `agents/board-advisor`

Outcome: `COMPILE_PASS; ARTIFACT_REPAIRED; Q02 NOT ENQUEUED — CPU CEILING`

## Scope and collision guard

The selected unit is `QM5_41011_tokyo-london-bank-flow-handover`, the highest-ranked
diverse card already claimed from the pending build backlog. It is an approved,
structural, once-per-day-session FX breakout across `EURJPY.DWX`, `GBPJPY.DWX`, and
`USDJPY.DWX`. The approved card has `g0_status: APPROVED`; EA ID 41011 and all three
magic rows are active; the three backtest presets use `RISK_FIXED=1000` and
`RISK_PERCENT=0`; and no Q02 work item existed at claim time.

The existing build task `3245e4d6-da72-4d7e-bfb6-c35abe2cb5f3` was refreshed under
the farm claim key
`manual:codex:agents/board-advisor:QM5_41011:stale-ex5-q02-recovery:2026-08-30T11:15:34.484842+00:00`.
The pre-mutation database backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_41011_stale_ex5_recovery_20260830_111533Z.sqlite`.

## Infrastructure defects and repair

The prior governed compile row `38660d91-9dc6-4e3d-a71e-0f4369dd12a5` recorded a
clean EX5 SHA-256 of
`0e4e8ee2f22a9f38766cefc63e7052b185b88196ceba7e039d8250f513ab5af6`, but the
canonical repository EX5 had reverted to the older SHA-256
`7a9dcbbc0de4f62ae7f8d2b0c46752f704fa005ee319562fda34c404de20e0a3`.
The pending build therefore had no authenticated current binary and no Q02 handoff.

A second deterministic defect was reproduced: governed setfile generation removed
the reviewed explicit `qm_rng_seed`, news temporal/compliance/staleness, Friday-close,
and stress inputs from all three presets. The static EA regression correctly failed
on the missing news bindings.

The repair used the governed append-only compile path only:

- successor compile work item: `0024abc6-5b34-4f4d-8c84-92e13a12755a`;
- exact release through `release_compile_wave.py --work-item-id` after a five-sample
  CPU maximum of `71.3523%`;
- terminal: `T1` through the resident worker and canonical claim/CAS path;
- result: `COMPILE_OK`, build check `PASS`, 0 errors, 0 warnings;
- current MQ5 SHA-256:
  `19eda5c89b952f0e9a0f8f0bdac05387c5bfe14be5332296d3ad1395e0e6d3b7`;
- repaired canonical EX5 SHA-256:
  `3b6d6a604cb1025b175d826b688fd85875bc83809388bfc0f49f706d221cfc36`.

After the worker regenerated the presets, the reviewed explicit framework bindings
were restored without changing strategy mechanics. Final preset SHA-256 values are:

| Symbol | Setfile SHA-256 |
|---|---|
| `EURJPY.DWX` | `273c571c2f0982e7266258277ac2bbb8cce2ab849beb9157072ca801150e0ed0` |
| `GBPJPY.DWX` | `cfc390dd3c6a41bd359a71f5d193292dfb6c44914abfc2324aa80d1bd61569c0` |
| `USDJPY.DWX` | `95cf26926ac449781eb3c815c8b7ac3374959c44521c009f0de8a3852d151f89` |

## Verification

- `test_qm5_41011_rework_static.py`: `7 passed`.
- `validate_spec_doc.py`: `PASS`.
- `build_gate_hardening.py`: no failures or warnings.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero violations.
- `validate_build_guardrails.py --max-news-stale-hours 336`: `PASS` for the MQ5 and
  all three fixed-risk setfiles.
- Governed compile evidence:
  `D:\QM\reports\work_items\0024abc6-5b34-4f4d-8c84-92e13a12755a\QM5_41011\COMPILE_EA\compile_evidence.json`.

## Binding CPU stop

Immediately before the one permitted EURJPY 2024 smoke, the five whole-host CPU
samples were:

```text
90.8305
97.1464
94.4509
75.6861
75.9880
```

The maximum `97.1464%` exceeded the hard `97%` ceiling. The smoke command was not
launched. Per the paced-fleet mission stop condition, `record-build` was not called
and no Q02 work item was enqueued. The build task remains pending for a later
capacity-clear slot to run exactly one M15 smoke and then use the standard
`farmctl record-build` transition, which will choose the liquid `USDJPY.DWX` Q02
canary and defer the other two symbols under the cohort fanout policy.

No strategy source or registry was changed. No manual backtest, `T_Live` path,
AutoTrading setting, portfolio gate, portfolio manifest, or deploy manifest was
touched.
