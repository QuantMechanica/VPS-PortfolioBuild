# QM5_10850 EURUSD H1 stale-binary recovery — compile PASS, Q02 provenance hold

Date: 2026-09-11 UTC
Branch: `agents/board-advisor`
EA: `QM5_10850_tv-bbmr-long`
Cell: `EURUSD.DWX`, `H1`
Router task: `03697cce-a584-4207-9743-163826f4df63`

## Outcome

The previously committed framework repair was compiled through the governed
worker path. Aggregate build check and MetaEditor compilation both passed with
zero failures and zero warnings. A source-fresh canonical EX5 now exists.

Q02 was not enqueued. Both append-only successor routes correctly refused the
historical-to-canonical preset transition because the successful compile did
not carry a hash-bound parameter-change authority artifact. No gate was
bypassed and no backtest process was launched.

No T_Live, AutoTrading, portfolio gate, or deploy manifest was touched.

## Selection and collision control

The first candidate, `QM5_10505_mql5-macd-sar`, was claimed as router task
`b76e30fd-5b82-4f3c-99ef-031973cb647f` after nine multi-symbol Q02 ONINIT
failures. Its decisive tester line was
`EA_MAGIC_NOT_REGISTERED: ea_id=10505 slot=3 magic=105050003`, but governed
compile admission found two active EA identity rows and refused with
`EA_ID_REGISTRY_IDENTITY_INVALID`. The task was marked BLOCKED and no compile
or Q02 row was created. Development did not mutate or waive the identity
registry.

`QM5_10850` was then selected as a nonduplicate continuation of the committed
EURUSD framework repair documented in
`2026-09-10_qm5_10850_eurusd_compile_q02_recovery.md`. At claim time it had no
open compile/backtest row and no current compile successor. The new router task
was scoped to one EURUSD H1 fixed-risk recovery.

## Guard and fixed-risk contract

Before compile enqueue, the binding source audit was run against the exact
committed source:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_10850_tv-bbmr-long/QM5_10850_tv-bbmr-long.mq5
ok=true; predicate=EA_FRAMEWORK_INPUT_PINNED; hit_count=0
```

Source SHA-256:
`6746cdadca2292330e6eab7b21dd052d9939de1ef9c312c4ec726434e13c4c44`.

The EURUSD H1 preset retains:

- `qm_ea_id=10850`
- `qm_magic_slot_offset=4`
- `RISK_FIXED=1000`
- `RISK_PERCENT=0`

Current preset SHA-256:
`cc1b982f203968a178ac756cfdd7a4bcb672b36c5f4f761bd62feed330a95d70`.

## CPU admission

The five-sample admission window before compile averaged `55.252362%` and
peaked at `59.188275%`:

```text
54.272905, 52.201253, 56.981173, 53.618202, 59.188275
```

The fresh window before attempting Q02 admission averaged `74.862071%` and
peaked at `81.456584%`:

```text
73.603988, 76.744130, 81.456584, 70.418452, 72.087200
```

Both average and maximum were strictly below the `97.0%` ceiling.

## Governed compile

- compile work item: `0efbf5c5-6506-48fc-89d6-1bb984453a28`
- source-repair authority:
  `q02_infra_predecessor:133f2023-7786-40ea-ba08-83ccd02a93bd`
- compile-wave backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260911T193224Z_16ac0d15.sqlite`
- worker terminal: `T4`
- work-item status/verdict: `done / COMPILE_OK`
- build check: PASS, zero failures, zero warnings
- MetaEditor: PASS, zero errors, zero warnings
- canonical EX5 SHA-256:
  `6e705a6c65ca432712290baac32591c0ba11706707cb82753824b7cca12ec13f`
- compile evidence:
  `D:\QM\reports\work_items\0efbf5c5-6506-48fc-89d6-1bb984453a28\QM5_10850\COMPILE_EA\compile_evidence.json`
- compile-evidence SHA-256:
  `d83d1e7496c59d190935e782177ef8db3c662560a5fd44fb8d2d673362a80e96`

## Q02 fail-closed handoff

`requalify-q02` recovered the exact historical preset bytes but found a
syntactic parameter diff: the canonical preset makes `qm_ea_id` and four
`strategy_*` defaults explicit and removes obsolete `qm_filter_*` keys that
are not EA inputs. It refused with
`parameter_change_provenance_missing`; `would_enqueue=false`.

`intake-first-q02` also refused because the only untouched first-intake cell it
selected was a legacy H2 preset with no `strategy_*` keys
(`empty_strategy_params`). The exact-row append-only rerun route refused the
changed source binding with
`q02_append_only_rerun_requires_same_exact_source_and_rerun_row`.

Therefore the durable next step is to attach a hash-bound parameter-change
authority artifact to a governed compile lineage (or use another reviewed
canonical route that proves the effective strategy parameters are unchanged),
then append exactly one EURUSD H1 Q02 successor. This record does not authorize
that provenance mutation or any gate bypass.
