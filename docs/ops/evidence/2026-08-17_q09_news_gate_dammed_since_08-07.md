# The Q09_NEWS gate has advanced nothing since 2026-08-07 (2026-08-17)

## Headline

**Q09_NEWS: 0 completions in 24 hours, 8 rows pending, oldest waiting 11 days.** It is the
only gate in the pipeline with a service rate of zero, and **Q10 — the closing
per-(EA, symbol) verdict — sits directly behind it.**

Service rate against queue depth, measured over the last 24h:

| Phase | completions/24h | pending | drain at this rate |
|---|---|---|---|
| Q02 | 165 | 875 | 5.3 days |
| Q03 | 19 | 40 | 2.1 days |
| Q04 | 112 | 78 | **0.7 days** |
| Q05 | 25 | 1 | — |
| Q06 | 16 | 1 | — |
| Q07 | 8 | 1 | — |
| Q08 | 8 | 1 | — |
| **Q09_NEWS** | **0** | **8** | **never** |
| Q09_PORTFOLIO | 2 | 2 | 1.0 days |

Every other gate drains. This one does not.

*(Incidentally this refutes a Q04-starvation suspicion: Q04 is the fastest-draining gate
in the funnel at 0.7 days, not a bottleneck.)*

## The eight rows

All eight carry an active `Q09_AWAITING_SEALED_PLAN` hold, which by design makes a
Q09_NEWS row unclaimable until a sealed run plan is hash-bound (`farmctl.py:1152`).

| Row | EA | Symbol | Waiting since |
|---|---|---|---|
| `1bc0c677` | QM5_11288 | USDJPY.DWX | 2026-08-06 09:04 |
| `4263d6b3` | QM5_20266 | XTIUSD.DWX | 2026-08-08 20:32 |
| `494651b2` | QM5_9641 | WS30.DWX | 2026-08-12 02:10 |
| `cfa98980` | QM5_12855 | XTIUSD.DWX | 2026-08-14 22:12 |
| `db92d69a` | QM5_12849 | XTIUSD.DWX | 2026-08-15 13:13 |
| `3a44e240` | QM5_12708 | XAUUSD.DWX | 2026-08-16 06:14 |
| `8f760c32` | QM5_13054 | XTIUSD.DWX | 2026-08-16 08:15 |
| `c665c1aa` | QM5_1537 | XAGUSD.DWX | 2026-08-16 20:26 |

These are not weak candidates. Each one reached Q09_NEWS by clearing Q08, so each is two
steps from a closing Q10 verdict. For scale: **41 Q10 rows exist in total** (40 PASS, 1
FAIL). Eight held rows is a fifth of the entire Q10 corpus, waiting.

## Why it stopped — the mechanism, not a defect

`bind-q09-plan` is a **hand-operated CLI** (`farmctl.py:22851`, `:23236`). Nothing calls
it: no pump step, no scheduled task, no pipeline promotion. Grepping the whole repo for
callers outside tests returns only the CLI wiring itself and `q09_live_news_backfill.py`,
which builds plans for the *live-book backfill* programme, not for pipeline gate rows.

The ten previously-released rows show the pattern clearly. Every one carries a release
note reading `sealed Q09 run plan bound; ordinary worker claim enabled`, and each was
released **within one to two minutes of its hold being created**, in a continuous run
between 2026-08-04 and 2026-08-07 03:09:50. Somebody was sitting on the queue and binding
each plan as it appeared.

**That work window closed on 2026-08-07 and nothing replaced it.** Every hold created
since has simply stayed on. The gate did not break — it was never automated, and the hand
that operated it moved on.

This is *not* the 08-07 Q09 poison loop (task `0a6f77cb`, priority 95). That fix
(`c298264d6`) shipped and I reviewed it as APPROVED; it concerned the live-book backfill
rows `d03f6148/12567` and `08be2fce/1556`, not the pipeline gate. The timing coincidence
is real but the causes are separate: the poison-loop work is what *occupied* the operator
during that window, and its conclusion is what ended the hand-binding.

## Why this class of stall is dangerous

The hold is fail-closed and correct — an unsealed Q09 run must not execute. But a
fail-closed gate with **no operator and no alarm** is indistinguishable from an empty
queue on every dashboard: `pending` rows look like ordinary backlog, not like a dam. The
gate reported nothing wrong for ten days while the pipeline's exit was shut.

Compare the two neighbours: Q08 has 1 pending and 8/day throughput; Q09_PORTFOLIO has 2
pending and drains in a day. The funnel above Q09_NEWS is healthy and *feeding* it. The
backlog is therefore growing, not static — three of the eight rows arrived in the last 48
hours.

## Correction, same day: the eight rows are unbindable by construction

I flagged binary vintage as a risk for the oldest row and asked that it be checked before
authoring plans. Checked across all eight (task `65cc2c1c`, evidence
`65cc2c1c_q09_sealed_plan_dam_alarm_2026-08-17.md`), **all eight fail it.**

Every current canonical EX5 still equals the SHA-256 sealed in its Q08 aggregate, and every
current MQ5 still equals the Q08 MQ5 SHA-256 — so these are not accidental
current-source-versus-Q08 mismatches. The blocker is conclusive instead: each exact
Q08-tested binary **predates the sealed-calendar-inputs interface** (`f0102fbcf`, 2026-08-03)
and cannot expose `qm_news_calendar_bundle_id`, `qm_news_calendar_expected_sha256` or
`qm_news_calendar_common_relative_path`. A planner can append those names to a generated
setfile, but the tested binary does not expose them, so the report cannot emit calendar
identity and the validator fails closed — correctly.

Spot-checked rather than taken on trust: `QM5_11288`'s Q08 aggregate at
`D:\QM\reports\work_items\c27cab86-…\QM5_11288\Q08\USDJPY_DWX\aggregate.json` contains **no
calendar-related key at all.**

**So the diagnosis above needs splitting.** The *mechanism* half stands: `bind-q09-plan` has
no caller and no schedule, and that is why nothing surfaced for ten days. The *backlog* half
was wrong: **an attentive operator would not have been able to bind these eight either.** Each
needs a source/interface repair, a fresh compile, and pipeline requalification producing a
**new Q08 identity** before any plan can legitimately exist. Rebuilding and then binding the
old Q08 row would contradict the sealed Q08 EX5 identity.

The real Q09 work item is therefore **eight requalifications, not eight bindings** —
materially more expensive than this document first estimated. Correctly, no `bind-q09-plan`
was issued, all eight holds remain active, and none was weakened.

**The absence is now alarmed.** `health.py::chk_q09_sealed_plan_hold_age` (`:3217`, registered
as a blocking check at `:3430`) fails when any pending Q09_NEWS row holds an active
`Q09_AWAITING_SEALED_PLAN` older than six hours — far above the historical one-to-two-minute
binding latency, short enough to fire inside one operator shift. It is live in `health.json`
and currently red: `completions_24h=0; pending=8; 8 Q09_NEWS sealed-plan holds`, with a
fail-closed action hint forbidding release without a validated bound plan. The condition can
no longer look like ordinary backlog, which was the acceptance test.

## What must happen

1. **Bind the eight.** Follow the released rows as the template: a plan directory
   (`run_plan.json` + `input_manifest.json` + `cells/`) under the work item's report root,
   then `bind-q09-plan --work-item-id <id> --plan <path> --plan-file-sha256 <sha>`. The
   sealed-plan discipline stays exactly as it is — this is about supplying the plan, never
   about weakening the gate.
2. **Automate the binding**, or **alarm on the absence of it.** A hand-operated step in
   the middle of an otherwise deterministic pipeline will stall again the moment attention
   moves. If binding cannot be automated because the plan requires judgement, then the
   monitoring must treat "a Q09_NEWS hold older than N hours" as a fault, not as backlog.
3. Note the binary-vintage trap found on 08-07 and recorded in
   `2026-08-07_q09_bundle_pin_snapshot_poison_loop.md`: a row binding an EX5 that predates
   the sealed-input interface (`f0102fbcf`, 08-03) produces reports with no calendar
   identity inputs, and the validator fail-closes — correctly. `QM5_11288` has been waiting
   since 08-06 and is the row most likely to hit this. Check binary vintage before
   assuming a plan will validate.

## Evidence

- Holds and rows: `D:\QM\strategy_farm\state\farm_state.sqlite`, tables `work_items`,
  `work_item_holds` (hold_code `Q09_AWAITING_SEALED_PLAN`)
- Released template: `D:\QM\reports\work_items\e323c2f7-6b8a-466f-9291-73dccfbe181a\q09_plan\`
- Gate predicate: `tools/strategy_farm/farmctl.py:1152-1170`
- Bind CLI: `tools/strategy_farm/farmctl.py:22851`, `:23236`
- Prior Q09 machinery work: `docs/ops/evidence/2026-08-07_q09_bundle_pin_snapshot_poison_loop.md`,
  router task `0a6f77cb`

## Serial execution attempt (router task `635ad39b`, 2026-08-17)

The mandated one-EA-at-a-time recovery began with the oldest row,
QM5_11288 / USDJPY.DWX. No later EA was touched before its new Q08 aggregate,
in accordance with the task's registry-corruption guard.

### QM5_11288 report

- Scoped command: `build_check.ps1 -EALabel
  QM5_11288_tc20-ema6-23-macd3060-stoch-h1`.
- Compile result: PASS, 0 errors, 0 warnings.
- Exactly one final compile was performed. No verification rebuild followed.
- Final EX5 SHA-256:
  `2FF35242EB5D7B2BDF1C76EE997741FAC331408785AA02192F96980A19BC0CBE`.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260817_102619.json`.
- New append-only Q08 row:
  `02196e8f-24f6-4e7f-b7f8-acd872ba6da7`, USDJPY.DWX, bound to exact Q07
  predecessor `124269b0-fcb9-4907-a2f5-1c7f3510bfc6` and historical Q08
  lineage `c27cab86-3761-4d81-8c26-ad69fe4e10c4`.
- Current Q08 state at handoff: `pending`; therefore no aggregate path, Q08
  verdict, calendar-identity values, Q09 plan, plan SHA, or claimability
  assertion exists yet.

The governed `dispatch-tick` returned `mode=idle` with no action because six
tests occupied the CPU ceiling. T2/T6/T7/T9 were free but correctly left idle;
active tests on T1/T3/T4/T5/T8/T10 were not interrupted. The pending Q08 row
remained unclaimed after repeated worker polls.

This is a real serial execution blocker, not permission to batch the remaining
seven rebuilds. QM5_20266, QM5_9641, QM5_12855, QM5_12849, QM5_12708,
QM5_13054 and QM5_1537 remain byte-untouched by this attempt. Their old Q09
holds remain active; none was released or rebound. `q09_sealed_plan_hold_age`
therefore remains red until governed Q08 evidence is available serially and all
eight validated plans are bound.

No pipeline verdict is inferred from the successful compile. The next operator
must first inspect Q08 row `02196e8f-...`; only if its aggregate contains all
three calendar identity inputs may the QM5_11288 Q09 plan be authored and the
serial sequence continue to EA 2.
