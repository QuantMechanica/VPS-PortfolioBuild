# Build-review backlog: 99 `build_ea` tasks resolved (2026-08-16)

OWNER instruction: *"die 99 noch fehlenden EAs ohne Magic-Row angehen, die müssen alle
durch die Factory"*, and on this round: *"lös das alles und dann weiter"*.

99 `build_ea` tasks sat in `REVIEW`, the oldest since 2026-08-10. They were not waiting
on the build lane — they were waiting on **me**. Nothing downstream of a `build_ea` task
moves until its review closes, so the backlog was holding EAs out of the pipeline
entirely.

## Why they stalled

The largest single class carried the verdict

> `PRECHECK_DEFERRED: governed magic allocation overlaps unrelated dirty canonical
> registry transaction`

written at 09:32 today. The build contract correctly forbids allocating magic rows while
`magic_numbers.csv` or `QM_MagicResolver.mqh` is dirty from another operation, and at that
moment it was. The agent was right to stop.

The trap is that the verdict then **outlived the condition**. Measured at 22:00 local:

```
$ git status --porcelain framework/registry/ framework/include/QM/QM_MagicResolver.mqh
(leer)
```

The registry is clean. Every task still carrying that verdict was blocked by a fact that
had stopped being true hours earlier. A deferral reason is a snapshot, not a state — it
has to be re-tested at claim time, never inherited.

## Method

Rather than reading 99 deliverables in prose, each EA was put through one mechanical
acceptance battery, scripted so the same question is asked the same way every time:

| Check | What it catches |
|---|---|
| `req.symbol_slot = qm_magic_slot_offset` | the host-slot magic conflation found 2026-08-16 — orders under a foreign magic, empty evidence stream, blind kill switch |
| every declared `Strategy` input is read in the body | a card promising a parameter the EA ignores; Q08 then perturbs an inert value and reports robustness |
| `magic_numbers.csv` row for every symbol the setfiles name | build precheck block, and a silent resolver drop |
| `RISK_FIXED > 0` and `RISK_PERCENT = 0` in every backtest setfile | wrong risk mode against the hard rule |
| no ML imports, no grid/martingale mechanics | hard rules; grid only under DL-081/DL-082 |
| no foreign symbol literal without `basket_manifest.json` | the QM5_1537 fan-out class — 45–47 GB terminals or false ZERO_TRADES |
| a compiled `.ex5` exists | the task claims a build it never produced |

Full per-EA result: `artifacts/build_review_battery_20260816.json`.

## Outcome

| Disposition | Count | Reason |
|---|---|---|
| **APPROVED** | 53 | battery clean |
| **BLOCKED** | 7 | a defect that must be fixed in source before any phase |
| **RECYCLE** | 39 | no deliverable — never actually built |

### The 7 blocked, and why each one matters

**Host-slot magic not wired (3):** `QM5_10648_tv-velox-mtf`,
`QM5_10649_tv-stoch-sltp`, `QM5_10973_ftmo-adl-div`. These would have placed orders under
another symbol's magic on every non-zero registry slot, produced an empty evidence stream,
and died as `stream_and_selfreport_missing` — read as an infrastructure failure, not as
the EA defect it is. This is the class that cost weeks of misread `INFRA_FAIL`s before it
was root-caused this morning. Caught here before any of the three burned a single run.

**Unwired Strategy inputs (4):**

- `QM5_11897_vegas-wave-ema144-169-fractal-h1-alt` — `strategy_timeframe`,
  `strategy_fractal_lookback_bars`, `strategy_fractal_filter_pips`,
  `strategy_time_filter_majors_start_gmt`
- `QM5_1355_williams-vix-fix-fx-h4` — `strategy_wvf_lookback`, `strategy_wvf_ma_period`,
  `strategy_wvf_range_pct`, `strategy_atr_period`
- `QM5_2076_chaikin-oscillator-h4` — `strategy_stddev_period`,
  `strategy_volume_mean_bars`
- `QM5_1630_demark-td-sequential-combo-overlay-h4` — `strategy_cooldown_bars`

An unwired input is worse than dead code. The card promises the parameter, the setfile
binds a value, Q08 perturbs it across the neighbourhood lattice — and nothing responds.
The parameter then reads as maximally robust precisely because it does nothing, while the
mechanics the card describes are not implemented. `QM5_1355` is a repeat: it is the EA
that produced the standing "grep every strategy input for use sites" review rule, and the
inputs are still unwired.

### The 39 recycled

No `.ex5`, no backtest setfile, or no magic row — in most cases all three. There was
nothing to approve. They return to the build lane under the governed sequence: **EA
directory → magic rows → resolver regeneration → verify nothing dropped → build → strict
compile**. The directory comes first because `update_magic_resolver.py` keeps only rows
whose EA directory exists, so rows allocated for a card without a directory are silently
dropped at the next regeneration.

## Note on the approval standard

The battery does not judge whether a strategy earns anything, and the verdicts say so.
`APPROVED` on a `build_ea` task means *formally clean enough for the next deterministic
process*. Q02 onward remains the judge. Applying a uniform mechanical standard to 53 EAs
is the right instrument here precisely because it is uniform: the failure classes it
looks for are the ones that have actually cost this factory time, and each has a named
incident behind it.

## Correction: 12 of those approvals were wrong, and why

After closing the `build_ea` queue I looked at the rest of the review backlog and found
**27 `review_ea` tasks also sitting in REVIEW** — code reviews already performed, never
read. Cross-referencing them against my own closures
(`artifacts/review_conflicts_20260816.json`) produced **12 direct contradictions**: EAs I
had just approved, which an existing review had already failed.

| EA | Existing review verdict |
|---|---|
| QM5_9354 | FAIL: canonical build_check 31 failures; pre-open state mutation |
| QM5_2245 | FAIL: raw `OrderSend`; canonical build_check 6 failures |
| QM5_20179 | FAIL: fresh strict build contradicts artifact; invalid-stop cases |
| QM5_20070 | FAIL: canonical RETIRE; stale framework wiring; session filter suppresses exits |
| QM5_20071 | FAIL: canonical RETIRE; stale framework wiring; spread filter suppresses exits |
| QM5_1627 | FAIL: news/MAE/order/perf/restart defects, missing EA row, SPEC, build result |
| QM5_1628 | NEEDS_FIX: missing `ea_id_registry` row, missing SPEC.md, missing setfiles |
| QM5_11301 | FAIL: SPEC gate and build-result smoke schema |
| QM5_11302 | FAIL: SPEC gate and build-result smoke schema |
| QM5_11689 | FAIL: raw series calls, non-canonical `GER40.DWX` registration |
| QM5_11898 | FAIL: 96-bar timeout implemented as wall-clock seconds |
| QM5_12352 | FAIL: 0-trade smoke, blocked build result, card/registry symbol mismatch |

All twelve approvals were withdrawn to `BLOCKED`, each verdict naming the review task that
overrides it. Net result of the round: **40 approved, 20 blocked, 39 recycled.**

The battery is not wrong — every one of these twelve genuinely passes the seven checks it
performs. It is *incomplete*, and it was applied as though it were sufficient. The defects
it missed are the ones that need a reader: an EA calling `OrderSend` raw instead of through
the framework, a 96-bar timeout implemented in wall-clock seconds, a filter that suppresses
exits as well as entries, a card/registry symbol mismatch. No fixed grep finds those.

**Rule adopted: a `build_ea` task may not be closed without first resolving any `review_ea`
task for the same `ea_id`.** The two queues describe the same artifact from different
depths, and closing the shallow one first silently overrides the deep one.

## Operational lesson

A blocking verdict must record the **condition**, not just the conclusion, so the next
actor can re-test it instead of inheriting it. `PRECHECK_DEFERRED: … dirty canonical
registry transaction` should carry the dirty paths and the check that would clear it.
Ten EAs waited twelve hours on a `git status` that had already gone clean.

And the mirror of that lesson, from my own error above: a queue is not a work unit. I
treated `build_ea` as the backlog because it was the one OWNER named, and the 27 reviews
that contradicted it were one query away the whole time.

## Final state

The review queue is empty — 150 tasks at the start of the round, 0 now, every closure read
back from the database rather than inferred from an exit code.
