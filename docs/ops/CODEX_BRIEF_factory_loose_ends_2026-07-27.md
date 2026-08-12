# Codex brief — find and close every loose end in the factory

Date: 2026-07-27
Requested by: OWNER, directly.
Priority: highest standing work item after the currently dispatched tasks.

## OWNER's ask, verbatim

> "Es wirkt immer noch so, als ob wir zahlreiche lose Enden in der Factory haben wo EAs
> stranden, Gates blockieren, Backtests sterben, etc. Gib die Aufgabe an Codex all diese
> losen Enden zu finden und zu lösen, sodass alles in einem Prozess gut und sicher
> durchläuft!"

The goal is **flow**: an EA that enters the factory should either come out the other end
with a verdict, or be retired with a recorded reason. It should never sit somewhere
indefinitely, die silently, or need a human to notice it.

## This is a census FIRST, fixes SECOND

Do not start fixing. **Stage 1 is a complete, quantified census**, committed before any
fix. A ranked census is more valuable than three fixes chosen by whichever loose end you
happened to see first, because it tells us where the volume actually is.

### Stage 1 — the census

Define "stuck" operationally and then count. At minimum cover:

**Work items.** As of 2026-07-27 the DB holds roughly: `pending` 2073 (Q02 2006, Q04 28,
Q03 26, Q07 9, Q05 2, Q08 1), `active` 8, and in `failed`: Q02 ~47042, Q03 ~731, Q04
~144, Q05 ~93, Q08 ~40, plus a legacy `P2` bucket. Answer:

- Is the queue draining or growing? Compute the arrival and completion rates over the
  last 7 and 30 days per phase. If arrivals exceed completions, the queue is a leak and
  everything else is secondary.
- How many `failed` rows are terminal (a real verdict) versus recoverable (infra,
  transient, or a defect since fixed)? The 204 Q08 `INFRA_FAIL` rows were already split
  this way under task `4458d308`: only 2 of 158 with valid set files were transient.
  Do the equivalent for the other phases, especially the ~47k Q02 failures.
- How many rows are `active` or `claimed` with no live process behind them — orphaned
  claims? Note the known hazard that worker PIDs go stale and the only truth is a live
  process scan.
- Are there (EA, symbol) pairs that have been in the pipeline for weeks without reaching
  a terminal verdict, and if so, where do they sit?

**Agent tasks.** The `agent_tasks` state machine is
`BACKLOG -> TODO -> IN_PROGRESS -> REVIEW -> APPROVED -> PIPELINE -> PASSED` with
`FAILED / RECYCLE / OPS_FIX_REQUIRED / BLOCKED` branches. Answer:

- How many tasks are in each state, and how old is the oldest in each? A task that has
  been `IN_PROGRESS` for days is a dead agent, not work in progress.
- Which states have no exit path in practice — that is, states nothing ever leaves?
- Are there task types that never route? **Known instance found 2026-07-27:**
  `pipeline_run` returns `no_available_agent` on every routing attempt. Find every other
  type or capability combination with the same property.

**The gates.** For each of Q02-Q10, answer: what fraction of entries reach a terminal
verdict, what fraction bounce back, and what is the single largest blocker at each
stage? Where a gate has a systematic evidence-production failure rather than a strategy
failure, name it. Known instance: `8.5_neighborhood` produced `artifact_missing` in 94
cases and `8.7_pbo` `insufficient_distinct_configs:got=0` in 81 — those are evidence
defects wearing a strategy verdict.

**Manual interventions.** What currently requires a human, and how often? Every one of
these is a loose end by definition. Today alone: a jammed review queue, a wrongly
diagnosed terminal reservation, a dead task type, and 25 fabricated build rows.

### Stage 2 — ranked fixes

From the census, fix in order of measured volume, not perceived severity. For each fix:
the mechanism, the change, a regression test, and how the class is *detected* in future
so it does not silently return.

## Loose ends already known — use these as seeds, not as the list

All evidenced today. Some are fixed; verify rather than assume, and look for siblings of
each pattern.

| # | Loose end | Status | Where |
|---|---|---|---|
| 1 | `batch_coder.py` inserted tasks at `REVIEW` with a hardcoded `PASS` verdict for files that never existed — 25 rows in one second | fixed `d5d0879a5` | look for **any other writer that sets a state or verdict it did not earn** |
| 2 | `close-review` rejected every task whose artifact field held several `;`-separated paths, making them permanently unapprovable | fixed `d5d0879a5` | look for other single-value assumptions on multi-value fields |
| 3 | The build pump swept hand-authored framework source into `build: pump auto-commit` commits | fixed today | verify the allow-list holds and the lane still commits artifacts |
| 4 | Q08 upstream `INVALID` was flattened to retryable `INFRA_FAIL` | fixed today | check the other phases' boundaries for the same flattening |
| 5 | 70 of 189 Q08 streams lack `entry_time` (legacy schema); backfill judged unsafe | open | are new runs emitting it? if not, the gap is still growing |
| 6 | T5's tester indicator engine returns `BarsCalculated = -1` forever; every T5 FAIL is unattributable | under repair, task `00b6f79c` | do not touch T5 |
| 7 | Terminal reservation is implemented and honoured at claim time (`terminal_worker.py:1056`) but a workflow concluded it did not exist and abandoned a run | discoverability failure | what else exists but is undiscoverable? `disabled_terminals.txt` is read only at spawn and may now be dead config |
| 8 | A task recorded a *directory* as its artifact, so the build-guardrail check validated the entire `framework/EAs` tree and timed out repeatedly | open | is the artifact-path convention enforced anywhere? |
| 9 | Interactive-class scheduled tasks are only ever queued, never run (`0x800710E0`), and the watchdog delegates healing to exactly that class — so every self-heal is a no-op | open, high | this makes the factory unable to heal itself |
| 10 | Every qualifying sleeve carries a latest Q09 `FAIL_PORTFOLIO` | open | is Q09 functioning as a gate, or rejecting everything by construction? |

## What "solved" means

For each loose end you close:

1. The mechanism is named, with `file:line` or a query — not "it seems to be".
2. The fix is minimal and does not change unrelated behaviour.
3. There is a regression test, or an explicit statement of why one is impossible.
4. There is **detection**: a health check, an invariant, or a surfaced counter, so the
   class becomes visible if it returns. `farmctl health` already runs pipeline
   invariants — prefer extending it over building something new.
5. Anything you cannot fix is recorded with what it would take.

## Hard constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- Do NOT interrupt running backtests. **T5 is under repair; T9 is reserved for a joint
  backtest.** Never `C:/QM/mt5/T_Live`. Never reboot, log off, or `tscon`.
- **Do NOT mass-requeue or bulk-mutate work items.** Reclassification and repair are the
  deliverable; requeueing 47,000 rows is a capacity decision and is OWNER's, not yours.
  Report what should be requeued and let it be decided.
- The claim path is throughput-critical and has a silent-skip starvation history. Any
  change there must fail open and must log a declined claim.
- MT5 saturation is the factory's primary throughput metric. A fix that reduces it is a
  regression even if it closes a loose end.
- Commit with explicit pathspecs, in labelled commits — not via the pump.
- Evidence over claims throughout.

## Deliverables

1. `docs/ops/evidence/2026-07-27_factory_loose_ends_census.md` — the quantified census,
   committed **before** any fix, with everything ranked by measured volume.
2. `docs/ops/evidence/2026-07-27_factory_loose_ends_fixes.md` — what you fixed, the
   mechanism, the test, and the detection for each; plus what you deliberately left and
   what it would take.

If the census alone consumes the whole task, that is a good outcome. Deliver it and stop.
