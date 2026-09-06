# QM5_41369 XTI/XNG Leader Persistence — Build and Compile Hold

## Outcome

`QM5_41369_xtixng-cs-leadpersist-cont` is a committed, non-live V5 basket
source build. The approved card, active identity, two magic rows, resolver
entries, EA source, three fixed-risk backtest presets, basket manifest,
strategy spec, and deterministic reference model are present. The governed
Q01 compile was enqueued, but remains pending under the existing
`COMPILE_EA_WORKER_ROLLOUT_PENDING` activation hold. Q02 was therefore not
enqueued.

## Structural Edge

At the first valid D1 bar of a new Monday-anchored broker week, reconstruct
the final synchronized XTI/XNG closes of the three immediately preceding
weeks. Each week must contain three to five synchronized sessions. When both
individual legs have the same strict sign in each of the two completed return
intervals and the same relative leader persists across both, buy the newest
winner and sell the loser as one equal-notional, aggregate-fixed-risk package.
Exit in the next broker week.

This is distinct from one-week common-shock continuation `QM5_41367`, the
leader-switch fade in `QM5_41368`, opposite-sign decoupling siblings
`QM5_41365`/`QM5_41366`, and the single-symbol two-day XNG oscillator in
`QM5_12567`.

## Build Evidence

- Source approval: commit `fb3c819685`.
- Approved card/G0: commits `f944d136a3` and `ca41afb666`.
- Magic allocation and resolver: commit `8e3c299787`.
- EA source/build artifacts: commit `a61043136a`.
- Hardened reference fixture: commit `e37769928a`.
- MQ5 SHA-256:
  `732702883032eca55718f1046cd2a8428a570b2c93264001a0ecc00c5378a94c`.
- Approved-card SHA-256:
  `e78ec32dbbf7530c155d405d7779e826028fd07ef20bf31d89656ace79e6615e`.
- Card schema/ML lint: PASS.
- Reference tests: 7/7 PASS.
- Build-skill preflight: card/identity/magic/directory PASS.
- Backtest presets: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

The binding PACER source audit was executed again immediately before compile
enqueue. It returned exit zero, `ok=true`, `hit_count=0`, and no
`EA_FRAMEWORK_INPUT_PINNED` findings. The guard pins only `strategy_*`,
`qm_ea_id`, `qm_magic_slot_offset`, the fixed-risk mode, and the permitted
stress finiteness/range checks.

## Governed Queue State

- Q01 work item: `c283f5a0-9b7d-4c51-bb9d-9f4bd93dd4d7`.
- State at handoff: `pending`.
- Activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`.
- No compile verdict, EX5, or build-check receipt exists yet.
- Canonical first-Q02 dry run returned
  `compile_work_item_not_done_compile_ok`; it created no row.

Do not bypass the rollout hold. After an authorized release and exact
`COMPILE_OK`, take a fresh five-sample whole-host CPU window. Only when both
average and maximum are strictly below 97%, apply:

```powershell
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id c283f5a0-9b7d-4c51-bb9d-9f4bd93dd4d7 --apply
```

## Safety Boundary

No manual tester run, priority boost, terminal restart, hold release,
portfolio-gate edit, deploy/live manifest, `T_Live`, AutoTrading, or live use
was performed.
