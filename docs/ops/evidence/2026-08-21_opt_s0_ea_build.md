# OPT-S0 DL-089 EA build evidence — 2026-08-21

## Scope

- Router task: `68f6d518-a28d-4198-ba86-1f06e29212f5`
- Priority: 88
- Decision: DL-089
- Parent: `QM5_21501_balke-gmt3-range-breakout-ppcensus`
- Allocated identity: `QM5_41097_balke-gmt3-range-breakout-opt`
- Branch: `agents/board-advisor`

This artifact records the research build only. It is not a pipeline verdict and
does not authorize T_Live or AutoTrading.

## Implementation

The new EA retains the parent's A1-fixed, side-effect-free straddle mechanics.
Its phase-1 profile is constructed from exactly six integer inputs:

- `opt_pp_buy1`, `opt_pp_buy2`, `opt_pp_buy3`
- `opt_pp_sell1`, `opt_pp_sell2`, `opt_pp_sell3`

Zero leaves a profile slot empty. Negative or unimplemented predicate IDs fail
closed in `OnInit`. The all-zero profile is the baseline.

The following phase-2 inputs are present but deliberately inert in this pilot:

- `opt_stop_distance_range_mult=1.0`
- `opt_take_profit_r_multiple=0.0`
- `opt_range_window_hours=3`

They preserve the concrete parent behavior: one-range stop distance, no fixed
take-profit, and a three-hour range. They are declarations only and have no
mechanical use site.

> **SUPERSEDED by the Review R1 repair (2026-08-22), see section below.** These
> three inert inputs were **removed**: an input with no mechanical use site
> violates the wired-input rule (QM5_1355) and cannot carry an S5 trial. DL-089
> stage S5 optimizes the parent's already-wired numeric levers instead
> (`opt_param_grid.json`).

The backtest setfile fixes `RISK_FIXED=1000` and `RISK_PERCENT=0`. The source
keeps `qm_news_stale_max_hours=336` and the mandatory DXZ news compliance mode.

## Registries

- EA registry: one active row for EA 41097 and strategy ID
  `6e967762-b26d-59a3-b076-35c17f2e7c36`.
- Magic registry: one active `USDJPY.DWX` slot-0 row, magic `410970000`.
- Resolver regenerated from the canonical magic registry: 17,599 rows, zero
  dropped, registry SHA prefix `03B83CBFFD1DB572`.

## Verification

Passed checks:

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS, no findings, stale-news ceiling 336.
- Static contract assertion: PASS for six declarations, six profile-builder use
  sites, absence of the old single-predicate inputs, declaration-only phase-2
  placeholders, fixed-risk setfile, and unique EA/magic registry rows.
- Magic resolver focused tests: 8 passed.
- Resolver dry-run: 17,599 rows kept, zero dropped.
- Enqueued source SHA matches current source SHA:
  `dc3840c1e99f4d96e2deca2495b1689277af37edcf06249189fb934b5d21ddd2`.

## Outstanding governed gates

Compilation and `build_check` do not yet have a PASS. An ad-hoc compile was
correctly refused with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because T1-T10
terminal processes were active; no terminal was interrupted. The governed
compile row is:

- work item `d646713d-c8ba-41ef-98f4-9b544780e714`
- state `pending`
- activation hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- `no_gate_verdict=true`

The required pattern fixture is also not green:

- work item `83b89730-bb86-4c18-955a-efefe3039cc5`
- state `failed`, verdict `INFRA_FAIL`
- reason `ea_dir_missing`

Consequently no OPT_CENSUS setfile matrix or run rows were created. Review must
retain the build until the governed compiler reports 0 errors / 0 warnings,
`build_check` is PASS, setfiles are hash-bound, and the fixture harness is PASS.

## Review verdict

`SOURCE_READY_COMPILE_PENDING`: implementation and static governance checks are
ready for review; compile/build acceptance remains explicitly unmet under a
governed infrastructure hold. No pipeline or profitability claim is made.

---

# Review R1 repair — 2026-08-22 (Claude)

Review R1 held the build for a wired-input defect and stale identity text. The
repair below is scoped to `framework/EAs/QM5_41097_balke-gmt3-range-breakout-opt/`
plus this evidence doc. No pipeline verdict, T_Live, or AutoTrading is authorized.

## R1.1 — removed the three invented inert inputs (QM5_1355)

`opt_stop_distance_range_mult`, `opt_take_profit_r_multiple`, and
`opt_range_window_hours` had **zero mechanical use sites** — declarations only.
An input with no use site violates the wired-input rule (QM5_1355), and "no
mechanical effect" directly defeats the DL-089 stage-S5 requirement that the
numeric optimization act on real levers. They were removed from:

- the `.mq5` (former `input group "Optimization Phase 2 (Inert)"` block),
- the base setfile
  `sets/QM5_41097_balke-gmt3-range-breakout-opt_USDJPY.DWX_H1_backtest.set`,
- `SPEC.md` §2 (and the now-inconsistent §5 sentence),
- `docs/strategy_card.md`.

A grep of the whole EA directory confirms none of the three names, the inert
group, or their setfile lines remain.

## R1.2 — created `opt_param_grid.json` (schema `qm.opt-param-grid.v1`)

S5 optimizes the parent's **already-wired** strategy inputs — no new numeric
knobs. Each lever's `parent_value` was verified against the actual `.mq5`
defaults (lines 74-82, identical to parent `QM5_13213` SPEC §2 and census
instrument `QM5_21501`):

| Lever | Parent (verified) | Candidate ladder | n |
|---|---:|---|---:|
| `strategy_max_range_atr_mult` | 2.5 | 1.5, 2.0, 2.5, 3.0, 3.5 | 5 |
| `strategy_trail_trigger_r` | 1.0 | 0.5, 0.75, 1.0, 1.25, 1.5 | 5 |
| `strategy_range_end_hour` | 6 | 5, 6, 7, 8 | 4 |

Every ladder includes the parent value as the mandatory control cell and stays
within DL-088 `AI_PARAM` (≤ 5 candidates, one lever per trial, parent as
control). Candidates are drawn from the card's own economic reasoning (ATR
range-admission band + hard SL cap; swing-trail trigger; range-width / placement
hour) and bracket the parent so a return_to_maxdd plateau median can be taken
(DL-088 §3). There is **no take-profit lever** — the parent has no TP mechanic
and `req.tp` is fixed at `0.0`. The file carries the sealed selection rule
(consistency ≥ 2/3, ≥ +5 % relative on return_to_maxdd, anchored WF, activity
floor fail-closed) verbatim from DL-089 / plan v3.

`python -c json.load` parses the file; all three parent values are present in
their candidate lists.

## R1.3 — fixed stale header text in the `.mq5`

- Band comment `21001-21499 / 21500+ census` and title `CENSUS INSTRUMENT`
  rewritten to state the real identity: **QM5_41097 is the DL-089 optimization
  instrument (`_opt`); parent QM5_13213; inherits the A1-fixed straddle via the
  census instrument QM5_21501.**
- Cell count `1,386` → `1,085` (155 arms × 7 years, per SPEC §8 / card).
- `P3 census (plan v2 …)` phrasing updated to DL-089 v3; the "no trial without a
  lawful subject" (plan v2 A5) citation is retained as still-valid under v3.

`validate_build_guardrails.py` on the repaired EA dir: **PASS**, 0 findings,
stale-news ceiling 336 (`files_checked=2`).

## R1.4 — compile investigation (guard) and why it stays PARTIAL

**Why `--ea-id 20096 --force` passed but `--ea-id 41097` refused.** The refusal
is *not* EA-specific and is not about 41097's include set. `compile_ea.py`
invokes `compile_one.ps1` with **no** `-CompileWorkItemId`; that calls
`include_mirror.py mirror` without a work-item id; `validate_compile_contract`
then raises on the single rule

```
if running and not work_item_id:  ->  LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
```

`running` is a point-in-time snapshot of live `terminal64.exe` processes, which
are **transient per backtest**. 20096 was compiled during a lull (zero live
terminals → `running` empty → guard passes → include mirror + compile proceed);
41097 hit a moment with at least one live terminal → refused. The include set is
irrelevant to the refusal: the mirror copies the *whole* `framework/include`
tree (EA-independent), and both pattern includes
(`QM_PatternPermission.mqh`, `QM_PatternPermissionStraddle.mqh`) already exist
under `framework/include/QM/`.

Live re-confirmation during this repair (read-only guard, nothing touched):

```
python tools/strategy_farm/include_mirror.py guard
-> {"failure_class":"LIVE_FACTORY_AD_HOC_COMPILE_REFUSED", "ok":false, ...}  (exit 2)
```

**The sanctioned governed route is already enqueued — but is now stale.**
`farmctl compile-status QM5_41097_…` shows the governed row:

```
work_item_id = d646713d-c8ba-41ef-98f4-9b544780e714
status       = pending
activation_hold = COMPILE_EA_WORKER_ROLLOUT_PENDING   (release_on_restart)
compiled=false  build_check_result=null  ex5_sha256=null
```

That row activates only through the governed worker **release-on-restart**
ceremony (an orchestrator/OWNER factory action, outside this agent's mandate;
`Never touch factory processes/scheduled tasks`). Two additional facts make a
plain re-enqueue insufficient:

1. **Source-SHA staleness.** The worker rechecks the source at claim time
   (`compile_work_items.py:715` → `SOURCE_CHANGED_AFTER_ENQUEUE`). The row bound
   the *pre-repair* source; the R1 edits changed it:
   - enqueued payload `mq5_sha256` = `dc3840c1…5d21ddd2` (from the OPT-S0 record)
   - current source `mq5_sha256`   = `f89e35b4e4f06ea566d70fe333c3da6bf1715014b1416a402ae7bc3ac51e158c`
   On release, `d646713d` will therefore refuse `SOURCE_CHANGED_AFTER_ENQUEUE`
   (fail-closed — it will never compile the wrong bytes).
2. **Idempotency block.** While `d646713d` is pending it counts as an open
   compile row (`compile_work_items.py:76`), so `farmctl enqueue-compile
   QM5_41097_…` returns `OPEN_COMPILE_EA_EXISTS` / `idempotent_open` and creates
   no fresh row. `open_compile` excludes failed rows, so once `d646713d` reaches
   a terminal state the re-enqueue self-clears.

**Status: PARTIAL.** No compile / `build_check` PASS was obtained (factory live →
ad-hoc fail-closed; governed row held and now SHA-stale). Nothing was compiled,
mirrored, restarted, or dequeued by this agent.

### Exact commands for the orchestrator's next idle window

Preferred (governed, single clean pass) — supersede the stale row, bind the
repaired source, then activate through the existing release-on-restart ceremony:

```
# 1. retire the SHA-stale pending row d646713d (sanctioned supersede/cancel path),
#    OR let it fail SOURCE_CHANGED_AFTER_ENQUEUE on the next rollout and re-enqueue after.
# 2. bind the repaired source (SHA f89e35b4…):
python tools/strategy_farm/farmctl.py enqueue-compile QM5_41097_balke-gmt3-range-breakout-opt
# 3. activate via the governed COMPILE_EA worker release-on-restart ceremony.
#    The terminal worker then compiles 41097 on a quiescent T1-T10 slot and runs
#    build_check.ps1 -EALabel automatically. Expect 0 errors / 0 warnings.
```

Ad-hoc fallback (ONLY in a genuine idle window with zero live `terminal64.exe`;
the guard enforces this itself and refuses otherwise):

```
python tools/strategy_farm/compile_ea.py --ea-id 41097 --force        # expect 0/0
pwsh -NoProfile -File framework/scripts/build_check.ps1 `
     -EALabel QM5_41097_balke-gmt3-range-breakout-opt -SkipCompile
```

Attach the `compile_one` log / `result.json` and the `build_check` output once a
sanctioned window produces them; only then does R1 move from PARTIAL to closed.

## Files changed (R1)

- `framework/EAs/QM5_41097_balke-gmt3-range-breakout-opt/QM5_41097_balke-gmt3-range-breakout-opt.mq5`
- `framework/EAs/QM5_41097_balke-gmt3-range-breakout-opt/sets/QM5_41097_balke-gmt3-range-breakout-opt_USDJPY.DWX_H1_backtest.set`
- `framework/EAs/QM5_41097_balke-gmt3-range-breakout-opt/SPEC.md`
- `framework/EAs/QM5_41097_balke-gmt3-range-breakout-opt/docs/strategy_card.md`
- `framework/EAs/QM5_41097_balke-gmt3-range-breakout-opt/opt_param_grid.json` (new)
- `docs/ops/evidence/2026-08-21_opt_s0_ea_build.md` (this file)

## Review verdict (R1)

`SOURCE_REPAIRED_COMPILE_PENDING`: the R1 wired-input and identity defects are
fixed and statically clean; compile / `build_check` acceptance remains unmet
under the live-factory governed hold and now also requires a re-enqueue to bind
the repaired source SHA. No pipeline or profitability claim is made.
