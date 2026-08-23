# E4 governed rebuild wave, part 2 — hardening repair + compile enqueue

Date: 2026-08-23

Task: `OPS-REBUILD-WAVE-E4-PART2` (router task `640d88e6-5fc4-4abc-aec3-d0787a8e58c6`, priority 90)

Authority: OWNER 2026-08-22 E4 + OWNER 2026-08-23 chat (rebuilt EX5 = new identity from Q02
onward). Prior handoff: `docs/ops/evidence/2026-08-22_rebuild_wave_e4.md`, Claude verdict
`1854fc66`.

## Scope

The remaining two EAs from the E4 wave that were held for post-canary hardening repair:

- `QM5_12989_grimes-nested-pb-v2` — `EA_INDICATOR_BUFFER_UNBOUNDED`.
- `QM5_1567_demark-td-reverse-sequential-h4` — `EA_FRAMEWORK_RAW_SERIES_CALL` (already
  absent on this re-run of `build_gate_hardening.py`; not reproduced) and
  `EA_Q08_MAE_HOOK_MISSING`.

`QM5_10706_tv-mon-ls` and `QM5_10847_tv-inside-gem` are the `COMPILED_CACHED` pair — the
2026-08-22 handoff already established their EX5 postdates their MQ5 with no drift; nothing
to rebuild. Documented here only for completeness: no action taken, no new work item created.

## Diff — hardening only, strategy logic unchanged

### `QM5_12989_grimes-nested-pb-v2.mq5`

`build_gate_hardening.py` flagged `Strategy_EntrySignal`: `atr_values[percentile_index]` is
read after `percentile_index` is clamped into range with plain reassignment (not a
`return`/`break`/`continue` fail-fast), so the static bound-proof checker cannot recognize it
as guarded. The existing clamp already makes the access safe at runtime; the fix adds an
explicit fail-closed `ArraySize` guard immediately before the read, satisfying the checker
without altering the clamped index value or entry predicate in any way:

```diff
    if(percentile_index >= strategy_d1_atr_percentile_lookback)
       percentile_index = strategy_d1_atr_percentile_lookback - 1;

+   if(percentile_index >= ArraySize(atr_values))
+      return false;
    const double current_d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_h4_atr_period, 1);
    if(current_d1_atr <= 0.0 || current_d1_atr < atr_values[percentile_index])
       return false;
```

### `QM5_1567_demark-td-reverse-sequential-h4.mq5`

`OnTick()` did not call `QM_FrameworkTrackOpenPositionMae()` as its first statement (the
current-build MAE-hook contract — same pattern already applied to `QM5_13213` in the prior
handoff and present in already-compliant EAs, e.g.
`QM5_11496_carter-t-ema100-psar-macd64128-m5.mq5:210`). Fix adds the call as the first
statement in `OnTick()`, before the kill-switch check, with no other change:

```diff
 void OnTick()
   {
+   QM_FrameworkTrackOpenPositionMae();
    if(!QM_KillSwitchCheck())
       return;
```

`EA_FRAMEWORK_RAW_SERIES_CALL` was not present in this run's findings for `QM5_1567`
(`failures: []` before this repair beyond the MAE-hook item) — the 2026-08-22 classification
row cites an older `build_evidence.json`; no raw-series call exists in the current source, so
no additional change was made for that class. No strategy logic (entry/exit predicate) line
was touched in either file.

## Verification

`python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label <label>` re-run
per EA after the edit:

- `QM5_12989_grimes-nested-pb-v2`: `EA_INDICATOR_BUFFER_UNBOUNDED` no longer present.
- `QM5_1567_demark-td-reverse-sequential-h4`: `failures: []` (both `EA_Q08_MAE_HOOK_MISSING`
  and `EA_FRAMEWORK_RAW_SERIES_CALL` absent).

`git diff` scoped to the two `.mq5` files shows exactly the two hunks above — no other lines
changed.

## Hashes

| EA | MQ5 before | MQ5 after |
|---|---|---|
| `QM5_12989_grimes-nested-pb-v2` | `4e75310f84fb762576a406c46944ac3df899a72906f7671695c2e5900618df0e` | `0beecb7626056612c05153549529be73bc7bac37f84b1d54b076cbe326d006f3` |
| `QM5_1567_demark-td-reverse-sequential-h4` | `685af902fd614945f15df604810f52b561d6dd3c0d155166b09dde9126da0f27` | `75777f18d320eca28606cf661aa9fc6cf36ce61e08be70b7e1e31e63ef533c81` |

The `QM5_1567` before-hash matches the hash already cited in the 2026-08-22 handoff for this
EA, confirming no source drift occurred between the two handoffs for this file. The
`QM5_12989` before-hash in this run differs from the one cited on 2026-08-22
(`72b3fd6e...`) — the working tree has moved since that snapshot (unrelated commits); the
`EA_INDICATOR_BUFFER_UNBOUNDED` finding was reproduced fresh on the current source before
this repair, so the classification is current, not stale.

## Compile enqueue (canonical `COMPILE_EA` queue — no direct compile)

```text
farmctl.py enqueue-compile QM5_12989_grimes-nested-pb-v2
  -> work_item_id 7022a056-040b-4412-898c-0da7c35389ef, status=pending,
     activation_hold_code=COMPILE_EA_WORKER_ROLLOUT_PENDING

farmctl.py enqueue-compile QM5_1567_demark-td-reverse-sequential-h4
  -> work_item_id 24e3a252-7c15-418c-b614-3a525e32c9f7, status=pending,
     activation_hold_code=COMPILE_EA_WORKER_ROLLOUT_PENDING
```

Both rows are held behind the same `COMPILE_EA_WORKER_ROLLOUT_PENDING` gate already in force
across the fleet (106 active holds of this code at time of writing) and documented as
out-of-scope to bypass in the 2026-08-22 handoff. The hold is **not** released or bypassed
here. The prior `COMPILE_FAIL` rows (`7d21410b-b1cd-4e99-9543-55e8a412fca6` for `QM5_12989`,
`2bb466d0-bbbe-4486-9368-645a127d25af` for `QM5_1567`) are left as-is (append-only); the new
rows above are the live pending attempts against the repaired source.

## Non-actions

No `build_check.ps1 -EALabel` run (no EX5 produced yet — compile is queued and held). No
setfile diff. No Q02 append-only rerun (requires a successfully compiled EX5 first — none
exists). Registry/magic files unchanged for both EAs. Factory was not toggled; no EA was
recompiled outside the governed queue; no verdict row was mutated.

## Next step for the reviewer

After the `COMPILE_EA_WORKER_ROLLOUT_PENDING` hold releases (governed release-on-restart
ceremony, out of this task's scope) and these two rows compile: run scoped
`build_check.ps1 -EALabel` for each, confirm setfile diff is limited to `build_hash`, then
issue one append-only Q02 rerun per EA on its main symbol's last terminal Q02 row
(`--from-work-item-id` + `--append-only-rerun-of` both set to that row id,
`--expected-current-ex5-sha256` equal to the new EX5 hash) — never a bare `--from-work-item-id`
without `--append-only-rerun-of`.
