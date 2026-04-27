# AGENTS Addendum (QUA-246)

Scope: Pipeline-Operator queueing and load-balancing behavior for factory terminals `T1`-`T5`.

## Mandatory Behavior

1. Never touch `T6` in queue/dispatch logic.
2. Enforce tuple de-dup on `(ea_id, version, symbol, phase, sub_gate_config)`:
   - if tuple already exists in registry, reject dispatch
   - reruns require a changed `sub_gate_config` digest
3. Use queue lifecycle `enqueue -> claim -> running -> ack(final)` with durable writes.
4. Write run evidence for every attempt under:
   - `D:\QM\reports\factory_runs\<ea_id>\<version>\<phase>\<symbol>\<run_key>\`
5. On every heartbeat, report:
   - queue depth
   - claimed/running terminals
   - de-dup rejects
   - final ack statuses

## Canonical Spec

The normative process spec is:

- `processes/15-pipeline-op-load-balancing.md`

If this addendum and process spec diverge, the process spec is authoritative until this file is updated in the same commit.
