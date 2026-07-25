# Gate-repair programme — implementation plan

Source: `docs/ops/evidence/2026-07-25_gate_funnel_autopsy.md` (13-agent audit + 3 adversarial
verifications) and the Codex cross-model challenge of the same.

Scope of this plan: **Track A (infrastructure) and Track B (evidence defects) only.** Track C
changes what passes a gate and is an OWNER decision; it is listed at the end as options, not
scheduled.

Assignment rule in force (OWNER 2026-07-25): coding work to Sonnet, larger programs to Codex
(gpt-5.6-sol, `model_reasoning_effort=max`) or Opus 5. **Claude-built is reviewed by Codex;
Codex-built is reviewed by Claude.** Nobody reviews their own work.

Factory is OFF for the duration of the build. Requeues are staged for after Factory ON.

---

## REVISION 2026-07-25, after the Codex cross-model challenge

`docs/ops/evidence/2026-07-25_codex_challenge_gate_autopsy.md` (headless `gpt-5.6-sol`,
`model_reasoning_effort=max`, read-only) attacked the audit this plan derives from. Five corrections
change the work, and three new packages are added. **The plan below is amended, not appended to —
read this section first.**

### Corrections that change the work

1. **The factory was NOT off during the audit.** Nine `terminal_worker.py` processes started
   2026-07-25T05:40:26Z; the pump was committing throughout. My retest of the eight Q10 INVALIDs
   launched at 05:40:22Z — **four seconds before** the workers came up. The "concurrency was the
   cause" conclusion is therefore not cleanly measured: five of eight recovered *despite*
   contention, not because of its absence. The original 21:55–22:52Z revalidation did have
   exclusive terminals (those workers did not yet exist). Factory has since been taken down
   properly for this build (OWNER decision 2026-07-25).

2. **The Q07 headline is smaller and its wording was wrong.** `variance_pct=0.00` means *equal PFs
   parsed to two decimals*, not byte-identical runs. The 12-sleeve / 5.2305 / 53.6 % figure is an
   **ever-PASS** join. On latest-Q07-PASS evidence it is **11 sleeves / 4.925520 / 50.5182 %**; on
   latest-overall-state, 10 sleeves / 4.867771 / 49.93 %. The finding stands; the number to quote
   is **50.52 %**.

3. **The Q10 ingester is bookkeeping, not density.** All 20 orphans are already in the live DXZ
   book. `ftmo_qualification.py` gates the FTMO challenge track only — its own docstring says it
   keeps the two contracts separate. WP-2 keeps its priority for evidence integrity and the FTMO
   objective, but it must not be described as a density lever.

4. **The stuck-pair model is wrong in a way that matters.** "Has any downstream row" is not proof
   of recovery, because the Q04-early probe runs *in parallel* with Q03. Corrected counts:
   ~2 245 stuck Q02 pairs, ~3 281 all-gate (not 3 301). A phase-dependency graph is needed, not a
   numeric `phase > current` test.

5. **"Zero surviving artifacts" for the `summary_missing` class is false.** 535 report roots,
   516 logs, 75 work-item IDs with summaries and 104 with `report.htm` survive. The canary before
   R-5 stays mandatory, but it is now possible to audit a real sample first rather than relying
   solely on the 73.8 % recovery inference. **Do that before the canary.**

### New work packages (inserted, see full specs after WP-7)

- **WP-9 — Q07 basket bypass.** `QM_BasketOrder.mqh` calls `QM_TradeContextSend` directly with no
  stress-rejection and no RNG. Verified: `grep -n "stress_reject|qm_stress|RNG|rng|MathRand"` on
  that header returns nothing, while `QM_Entry.mqh:264-269` holds the only
  `QM_RandBoolTagged("entry_reject", …)` hook. 174 active-source EAs call `QM_BasketOpenPosition`.
  For every one of them Q06's 10 % rejection is a no-op and Q07 cannot certify multiseed robustness
  — structurally, not through the injector defect. **This is a framework fix and it outranks the
  Q07 requeue.**

- **WP-10 — Q07 evidence laundering.** `_recover_existing_seed_results` authenticates a seed by the
  seeded set filename in `tester.ini` and never compares it to the effective report input. QM5_10569's
  post-fix PASS of 2026-07-15 is assembled from five 2026-07-07 reports that all ran effective seed
  42. **Until this is fixed, requeuing Q07 can re-launder pre-fix evidence into a fresh PASS** —
  which would make R-1/R-2 worthless. **Blocks R-1.**

- **WP-11 — Q10 KS baseline parser + gross/net.** 2 380 of 6 569 closing deals are mis-parsed;
  24 of 27 current PASS baselines are affected; the baseline is built from gross history while the
  live kill-switch feeds net. Self-history replay diverges in 17 of 27 cases and in 8 of the 11
  plausibly-armed live sleeves. This is worse than the missing-file finding because it corrupts
  baselines that **load successfully**.

### Escalated to OWNER, live-safety, outside this plan

**11 live sleeves (4.7193 risk) run binaries that predate both kill-switch path-repair waves.**
For those the distribution-baseline path and the manual/portfolio halt-file path are expected to
still be the unresolvable drive-letter forms. The internal 3 % daily-loss halt remains, but two
external safety channels plus the distribution channel cannot be presumed armed. This is a
provenance inference from EX5 mtimes, not a decompilation. Combined with WP-11 it means the KS
kill-switch should not be counted on for the current book.

---

## REVISION 2, 2026-07-25 — Codex review REJECTED this plan

`docs/ops/evidence/2026-07-25_codex_review_wp2346.md`. The rejection is correct on all three counts
and the plan is rewritten below rather than patched.

### WP-1 was specified against the wrong identity key — WITHDRAWN AS WRITTEN

`work_items` is explicitly a per-**(EA, symbol, phase, setfile)** table (schema comment near
`farmctl.py:683`). My spec proposed a partial unique index on `(ea_id, symbol, phase)` only. That
would have collapsed legitimate Q03 grids, ablations and every other per-setfile variant — it would
have made later work cheaper by silently discarding real work.

Independently re-measured (read-only, `mode=ro`):

| measurement | result |
|---|---:|
| open groups with >1 row per (ea, symbol, phase) | 35 groups / 105 rows |
| open groups with >1 row per (ea, symbol, phase, **setfile**) | **0** |
| QM5_10042 / AUDUSD / Q04 rows | 387 |
| QM5_10042 / AUDUSD / Q04 **distinct setfiles** | **387** |

**There is no dispatch-duplication defect.** The 386-row example in the original plan was
misdiagnosed: it is 387 distinct setfiles fed by 387 distinct Q03 setfiles. That may be an
unwanted grid→Q04 fan-out *policy*, which belongs at the promotion step that creates it — not
behind a uniqueness constraint that hides it.

The "~9 600 wasted backtest launches" claim in the original synthesis therefore does not survive,
and with it the argument for scheduling WP-1 first. **WP-1 is replaced by WP-1b.**

### WP-1b — grid→Q04 fan-out policy audit (replaces WP-1)  ·  Codex  ·  review: Claude

Establish whether promoting every Q03 plateau-grid setfile into its own Q04 work item is intended.
387 Q04 runs for one (EA, symbol) is either a deliberate walk-forward sweep or a policy accident
that consumed thousands of backtests. **Measure first, decide second, change nothing until the
answer is known.** If it is an accident, fix it at the promotion policy with an explicit cap and a
recorded rationale — never with a uniqueness constraint.

Deliverable is an evidence document plus a recommendation, not a schema change.

### Missing specifications — now written

The REVISION above named WP-9/10/11 but never specified them; the review matrix ended at WP-7. All
three are now built and specified in their own evidence sections; the review matrix below covers
them.

### The staged-requeue gates were inconsistent — corrected

The prose said R-1 is blocked on WP-9 and WP-10 while the table still gated it on WP-1 alone. R-1
now requires, all of them:

1. WP-9 and WP-10 reviewed and deployed;
2. the affected basket EAs **recompiled**, with EX5 provenance bound to the fixed framework header
   (the WP-9 fix is inert until the binaries are rebuilt);
3. old Q07 recovery artifacts quarantined or rejected by WP-10's effective-seed check;
4. **a sealed cohort definition.** "12 book sleeves" is the stale ever-PASS join. Latest-PASS gives
   11; latest-overall-state gives 10. The cohort must be fixed in writing before the requeue, not
   chosen afterwards from whichever number looks best.

### Revised ordering

WP-9 → WP-10 → WP-3 → WP-4 → WP-2 → WP-6 → WP-11 → WP-5 → WP-7 → WP-1b.

WP-3 and WP-4 move ahead of WP-2 and WP-6 because they are the two the review approved outright.
WP-1b moves last: it is now an audit, not a prerequisite.

---

## Work packages

### WP-1 — Dispatch dedup  ·  Codex (SOL MAX)  ·  review: Claude

**Problem.** Work items are created without checking for an existing open item on the same
(ea_id, symbol, phase). Q04 rows inflate 2.75x, Q02 ~5.3x; one EA-symbol pair
(QM5_10042/AUDUSD) spawned 386 separate `attempt_count=0` rows. Roughly 9 600 backtest launches
were spent re-running pairs that already had an open item.

**Change.** In `tools/strategy_farm/farmctl.py`, at the work-item creation path: refuse a new row
when a `pending` or `active` row exists for the same (ea_id, symbol, phase); increment
`attempt_count` on the existing row instead. Must be race-safe — creation happens from multiple
worker processes, so the guard belongs in the same transaction as the insert, ideally backed by a
partial unique index on (ea_id, symbol, phase) WHERE status IN ('pending','active').

**Why Codex.** Touches the concurrency-critical claim path that every worker uses, and the fix is
a schema + transaction change, not a script. This is the one WP where a subtle mistake stops the
whole factory.

**Acceptance.** Existing tests green; a new test proves two concurrent creates for the same triple
yield one row with `attempt_count=2`; no change to the semantics of legitimate re-runs after a
terminal verdict.

**Do this first.** Every requeue below is cheaper once the queue stops multiplying.

---

### WP-2 — Phase-aggregate → DB ingester  ·  Sonnet  ·  review: Codex

**Problem.** `q10_confirmation.py` writes `aggregate.json` plus a Q13 KS baseline and never writes
to sqlite; only a queued `terminal_worker` dispatch creates the `work_items` row. The overnight
revalidation ran out-of-band with the factory OFF, leaving **20 Q10 PASS pairs on disk and in no
database**, which `ftmo_qualification.py` (`STRICT_PHASES` includes Q10) then rejects as
`q10_pass_missing`.

**Change.** New `tools/strategy_farm/ingest_phase_aggregates.py`:

- Walk `D:/QM/reports/pipeline/QM5_*/<PHASE>/*/aggregate.json` for a given phase (start with Q10;
  the same code must serve Q04 once WP-7 lands, so parameterise the phase).
- Upsert one `work_items` row and one `ea_metrics` row per (ea_id, symbol, phase).
- **Idempotency key: `generated_at_utc`.** Never clobber a row written by `terminal_worker`; never
  double-insert on re-run. If a DB row exists with a newer or equal `generated_at_utc`, skip.
- **`INVALID` ingests as `INVALID`, not `FAIL`.** The infra/strategy split is the whole point of
  the audit; collapsing it here would destroy the distinction the rest of the programme depends on.
- `--dry-run` prints the plan and writes nothing. Default is dry-run; writing requires `--apply`.

Then re-run `ftmo_qualification` and record the delta.

**Acceptance.** Dry-run reports exactly 20 net-new Q10 PASS rows and 3 INVALID; a second `--apply`
run is a no-op; a `terminal_worker`-written row is never modified.

---

### WP-3 — Unify `verdict_reason`  ·  Sonnet  ·  review: Codex

**Problem.** The single largest Q02 failure class, `summary_missing_retries_exhausted`
(~43 737 rows), stores its reason under `payload.final_failure` while `verdict_reason` is NULL for
~43 430 rows. Any survey reading `verdict_reason` — including the first two passes of tonight's own
analysis — is blind to it. Q08 collapses its real sub-gate reason
(`neighborhood_artifact_missing` / `pbo_insufficient_distinct_configs`) to a generic
`phase_runner_invalid_report`. Q03 leaves 502 rows with NULL reason and 682 with no evidence path.

**Change.**
1. At write time: whenever a terminal verdict is recorded, ensure `verdict_reason` is populated —
   falling back to `final_failure`, then `prior_failure`, then `transient_infra_signature`.
2. Preserve the dominant Q08 sub-gate detail instead of collapsing it.
3. One-shot backfill script that fills NULL `verdict_reason` from the sibling keys. **Backfill must
   be reversible**: write the pre-state to a JSON snapshot in `D:/QM/reports/state/` first.

**Acceptance.** After backfill, NULL `verdict_reason` on rows with a terminal verdict drops to near
zero; the reason histogram for Q02 shows `summary_missing_retries_exhausted` as the top class; the
snapshot allows an exact revert.

---

### WP-4 — `ACTIVE_TIMEOUT` is infrastructure, not a strategy verdict  ·  Sonnet  ·  review: Codex

**Problem.** The reaper hardcodes `SET verdict='FAIL'` (`farmctl.py:4338`) when it kills a
long-running item. That is a harness kill wearing a strategy rejection's clothes. It occurs at Q02
(242 rows), Q03 (11) and Q06 (1); it inflates the apparent strategy-rejection rate and freezes
~29 Q02 pairs at a fake terminal FAIL that no requeue will ever pick up. The same applies to
`trades == 0` graded as strategy FAIL at Q06 — that is INVALID/retry-owed.

**Change.** Map `ACTIVE_TIMEOUT` to `INFRA_FAIL` at the reaper; backfill the 254 historical rows,
with the same snapshot-before-write rule as WP-3.

**Acceptance.** No row carries `verdict='FAIL'` with reason `ACTIVE_TIMEOUT`; the ~29 frozen pairs
become requeue-eligible; snapshot allows revert.

---

### WP-5 — Shared cold-cache retry helper  ·  Codex (SOL MAX)  ·  review: Claude

**Problem.** `run_with_launch_fault_retry` in `_phase_utils` retries **only** `0xC0000142`. A run
that dies on the cold-cache signature (`BARS_ZERO`, `M0_1970_PERIOD`, `NO_HISTORY`,
`INCOMPLETE_RUNS`, `history synchronization error`) exits 1 and goes terminal at attempt 0. This
class leaks at every gate — it is what produced tonight's eight Q10 INVALIDs, five of which passed
on a plain retry at lower concurrency.

**Change.** Generalise the helper to retry the cold-cache signature class with backoff, capped
attempts, and a log line naming the signature. Every gate runner adopts it. **Do not re-import
`.DWX` history** — that is a standing rule and the wrong fix for this class.

**Why Codex.** Cross-cutting change to the shared runner path used by all nine gates; the failure
mode of getting it wrong is silent infinite retry.

**Acceptance.** A simulated BARS_ZERO run retries and succeeds; a genuine strategy FAIL is not
retried; retry count is bounded and logged.

---

### WP-6 — Q09 sleeve-stream export repair  ·  Sonnet  ·  review: Codex

**Problem.** `load_streams` reads `sleeve_streams/QM/q08_trades/*.jsonl`; the *stream file* gates
the trade count, not the backtest. Five pairs with `q08_trade_count` of 296/92/92/78/60 are stamped
`NEED_MORE_DATA` because their stream holds < 20. Known repairable: 11421 EURUSD/AUDUSD already
progressed NEED_MORE_DATA → FAIL → PASS after a stream fix.

**Change.** When `q08_trade_count >= 20` but the loaded stream has < 20 entries, re-export the
stream from the Q08 evidence before evaluating, and log the repair. Do not silently pass a sleeve
whose stream genuinely cannot be rebuilt — that stays `NEED_MORE_DATA`.

**Acceptance.** The five known pairs re-export and receive a real admission verdict (pass or fail —
either is a correct outcome); a pair with no recoverable Q08 evidence still returns
`NEED_MORE_DATA`.

---

### WP-7 — Q04 durable evidence + fold hardening  ·  Codex (SOL MAX)  ·  review: Claude

**Problem.** `0 %` of Q04 `aggregate.json` survive on disk: the runner writes into a volatile
work-item directory that is later purged, so ~8 000 Q04 verdicts cannot be re-audited, and the same
churn generates 140 `stream_and_selfreport_missing` INFRA verdicts. Separately, 981 Q04 pairs never
got a verdict (`incomplete_fold` 577, `EMPTY_EXPERT`/`M0_1970` ~289).

**Change.** Point Q04 at the durable `--report-root`, exclude aggregates from the purge, assert the
`.ex5` resolved and OOS history is warm before each fold, and always write a deterministic
`summary.json` even on a failed fold.

**Why Codex.** Largest single runner, interacts with the purge job and the report-root convention
shared with WP-2.

**Acceptance.** A Q04 run leaves a readable `aggregate.json` in the durable root that survives a
purge cycle; a deliberately broken fold still yields a `summary.json` with a classifiable reason.

---

### WP-8 — Docstring corrections  ·  folded into WP-5's review  ·  no separate agent

`q06_stress_harsh.py` and `q10_confirmation.py` both still document `DD < 15%`; the enforced
constant is 25.0 (`decisions/2026-07-15_...`, amended 2026-07-25 for Q10). Zero risk, but a stale
docstring is exactly how the Q06 auditor reached a wrong conclusion in this very audit.

---

## Staged after Factory ON (not part of the build)

| # | action | pairs | gate on |
|---|---|---:|---|
| R-1 | Requeue 12 book sleeves with `variance_pct=0.00` at Q07 | 12 | WP-1 |
| R-2 | Requeue remaining zero-variance Q07 pairs | 63 | R-1 clean |
| R-3 | Warm requeue cold-cache INVALIDs: Q05 41, Q07 17, Q08 13, Q06 5, Q10 3 | 79 | WP-5 |
| R-4 | Q04 unmeasured pairs | 981 | WP-7 |
| R-5 | Q02 stuck pairs — **canary 50 first**, watch the summary_missing rate | ~2 246 | R-4 clean |

R-5 is explicitly gated on a canary. The "transient" classification of the 43 737-row
`summary_missing` class rests entirely on a 73.8 % pair-level recovery rate, because every log for
those rows is purged. That is the weakest evidence in the whole programme and it must not be
released at full scale on inference alone.

---

## Track C — OWNER decisions, not scheduled

- **C1 Q09 thresholds.** DL-083 line 51: *"Admission itself remains an OWNER gate; this DL
  calibrates the recommendation engine only."* Porting 0.15/0.40/0.020 into
  `portfolio_admission.py` (live: 0.30 / 1e-3) is a **new** decision, not wiring. ~8 pairs.
- **C2 Q08 8.5/8.7 INVALID block.** ~17 sleeves. Enforced by a code comment citing an
  "OWNER 2026-07-17" ruling; the only 07-17 decision file governs neighborhood **FAIL**, not
  unevaluable **INVALID**. Options: waive to PASS / waive to Q09 portfolio track / wire Q03 to
  publish the grid. Also `DL077_MIN_QUALITY_PASSES = 1` vs DL-077's proposed 4, under a decision
  still marked PROPOSED.
- **C3 Q03.** Wire the plateau runner, or ratify trade-floor-only and retire the orphan.
- **C4** Q07 `variance_pct == 0.00` → INVALID rather than PASS; KS-baseline missing → fatal at
  OnInit under `ENV=live`; Q02 gate ordering if Q02 is ever to screen profitability.

---

## Review matrix

| WP | built by | reviewed by |
|---|---|---|
| WP-1 dispatch dedup | Codex | Claude |
| WP-2 aggregate ingester | Sonnet | Codex |
| WP-3 verdict_reason | Sonnet | Codex |
| WP-4 ACTIVE_TIMEOUT | Sonnet | Codex |
| WP-5 cold-cache retry | Codex | Claude |
| WP-6 Q09 stream repair | Sonnet | Codex |
| WP-7 Q04 durable evidence | Codex | Claude |

## Standing constraints for every WP

- Never write into `C:\QM\mt5\T_Live`. Never enable AutoTrading. Never run `Factory_OFF`/`ON`.
- No backtests during the build; the factory stays OFF until every WP is reviewed.
- Every DB mutation is preceded by a snapshot and is reversible.
- Commit with explicit pathspecs only (`git commit <paths>`), never `-a`.
- Work on `agents/board-advisor`; do not touch `main`.

---

## WP-9 — basket stress-rejection bypass  ·  Opus  ·  review: Codex  ·  BUILT

**File:** `framework/include/QM/QM_BasketOrder.mqh`.

`QM_Entry.mqh:264-269` holds the framework's only stochastic stress-rejection hook.
`QM_BasketOpenPosition` called `QM_TradeContextSend` directly with no RNG and no rejection check, so
for every basket EA Q06's seeded 10 % rejection was a no-op and Q07 could not diverge across seeds.
174 active-source EAs take that path.

Implemented per-leg, mirroring the helper's existing per-leg false-return contract, which the
reference caller already rolls back — so it nets to all-or-nothing at the basket level. Effective
per-basket rejection is `1-(1-p)^legs` (~19 % for two legs at p=0.10): stricter than the
single-order path, never weaker. Tag `"entry_reject"` reused, because the seed drives divergence and
the tag only salts the chain; this is the same semantic decision, so it belongs in the same
sub-stream. Placed after kill-switch and news so a stress rejection can never mask a safety one, and
before any broker round-trip.

**Invalidates:** 15 basket Q06 PASS pairs and 13 basket Q07 PASS pairs (11 of the 13 carry
`variance_pct=0.00`). **Two are live book sleeves — QM5_12778/AUDUSD and QM5_13117/EURGBP, together
0.9104 of 9.75 = 9.34 % of book risk.** Their Q06 HARSH and Q07 multiseed certifications were
produced under a no-op stress.

**Inert until the 174 basket EAs are recompiled.** Do that atomically (build+commit together).

**Related, latent, not fixed here:** `QM_TM_Grid.mqh` bypasses the same hook and, per its own header,
also the news and kill-switch checks — but `QM_GridOpenNextLevel` has **zero callers** in the repo.
A landmine for future grid EAs, not current exposure. Also unhooked: a confirmed list of EAs using
raw `OrderSend` or `CTrade` directly — none is in the book.

## WP-10 — Q07 effective-seed authentication  ·  Sonnet  ·  review: Codex  ·  BUILT

**File:** `framework/scripts/q07_multiseed.py`.

`_recover_existing_seed_results` authenticated a recovered run by the seeded setfile **filename** in
`tester.ini`, never against the seed the report was actually produced with. The effective seed is
authoritative in the `report.htm` inputs table (`qm_rng_seed=<N>`); `summary.json` has no seed field
at all, and the `tester.ini` label is exactly what lies.

Proven on the real archive for QM5_10569: five runs labelled 42/17/99/7/2026, **every report shows
`qm_rng_seed=42`**. Under the old code all five laundered into an instant PASS. Under the fix only
the genuine 42 recovers; the other four are rejected and must be re-run.

**Blast radius:** 3 confirmed unsafe Q07 PASSes (10569/XAUUSD, 11267/XAUUSD, 12781 basket) — **none
in the book.** But 15 of 24 book sleeves have a Q07 PASS row whose aggregate is purged, so their
provenance is *unverifiable*, not clean. Only a requeue re-establishes it.

`1224d518b` is a real repair of the writer (`_write_seeded_setfile` silently no-op'd whenever
`qm_magic_slot_offset != 0`) but left the reader trusting the filename. This closes it.

## WP-11 — KS baseline parser + gross/net  ·  Sonnet  ·  review: Codex  ·  BUILT

**File:** `framework/scripts/gen_q10_baseline.py`.

The live kill-switch feeds **net = profit + swap + commission** (`QM_Common.mqh:805-808`, fed at
`:835`). The generator stored the **gross profit column** — the wrong quantity, independent of the
parser bug — and read it by positional regex rather than by named column.

Now resolves the deals-table header by name with en/de/fr aliases, sums the three named columns,
fails loud on an unparseable report instead of writing a short baseline, and adds `--verify` and
`--audit` read-only modes plus `--out-dir` so nothing writes into the live sandbox.

**Audit of all 27 existing baselines:** 27/27 change. 24/27 carry positional corruption,
**2 380 of 6 569 closing deals mis-parsed**. **17/27 self-diverge** — they would flag their own
correctly-parsed source history as KS-divergent, a false-kill signature.

**Book impact:** 20/24 sleeves have a baseline, 4 have none. **8 sleeves are post-path-fix,
baseline-present and self-divergent = ~2.32 % of book risk with active false-kill exposure.**
Five more self-diverge but run pre-path-fix binaries whose KS path is dormant. Net: 16/24 dormant,
8/24 false-kill-prone — **no sleeve has reliable KS protection.**

Not a capital-safety emergency: the load path is fail-open, the independent 3 % daily-loss halt is
unaffected, and a false kill costs opportunity, not drawdown. But leaving it is the worst option —
no protection *and* false-kill risk.

Corrected NET baselines staged at `D:/QM/reports/state/q10_baselines_regen_wp11_20260725/`, audit
table alongside. **Live directory untouched — writing into the live kill path is OWNER-gated.**

---

## Review matrix (final)

| WP | built by | reviewed by | status |
|---|---|---|---|
| WP-1b fan-out audit | Codex | Claude | not started — replaces the withdrawn WP-1 |
| WP-2 aggregate ingester | Sonnet | Codex | CHANGES-REQUIRED, fixes in flight |
| WP-3 verdict_reason | Sonnet | Codex | **APPROVED** |
| WP-4 ACTIVE_TIMEOUT | Sonnet | Codex | **APPROVED** |
| WP-5 cold-cache retry | Codex | Claude | not started |
| WP-6 Q09 stream repair | Sonnet | Codex | CHANGES-REQUIRED, fixes in flight |
| WP-7 Q04 durable evidence | Codex | Claude | not started |
| WP-9 basket bypass | Opus | Codex | built, review pending |
| WP-10 Q07 seed auth | Sonnet | Codex | built, review pending |
| WP-11 KS baseline | Sonnet | Codex | built, review pending |

## Apply order

Both approved packages apply only after **real quiescence** — verified by process scan for workers,
pump and orphaned phase runners — and a **full DB backup**, with row counts re-taken immediately
before the snapshot. WP-3 then WP-4. Everything else waits on its review.

**Operational finding, recorded because it bit this run:** `Factory_OFF.ps1` kills worker daemons,
`run_smoke` wrappers, `terminal64` and `metatester64`, but **not the phase-runner python processes**.
Two orphaned `q07_multiseed.py` survived the shutdown and kept spawning fresh `run_smoke` →
`terminal64`, which is why the script's own final check reported terminals still running and why
they reappeared after being killed. Quiescence must be verified by process scan, never assumed from
the script's exit. The script should reap phase runners.
