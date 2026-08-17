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
