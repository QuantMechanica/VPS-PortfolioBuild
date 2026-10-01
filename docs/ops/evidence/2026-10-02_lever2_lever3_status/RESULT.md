# Status check — P80_LEVER_SYNTHESIS_2026-09-26.md §4-5, levers #2 and #3 (2026-10-02)

Task `103b4212-574f-4aeb-973f-b1492da6f244`. Read-only investigation against the canonical
checkout (`C:/QM/repo`, git log + working tree) and the live farm DB
(`D:/QM/strategy_farm/state/farm_state.sqlite`, opened read-only / `PRAGMA query_only=1`
every time). No gate thresholds, Q08 criteria or book composition touched. `QM5_41484`
not touched. No mutation was executed by this task — see §3 for why.

## 0. Answer

1. **Lever #2 (41470 → V3 book marginal, 5×40k both cost arms): DONE**, 2026-09-26. Action
   recorded: `SHADOW_BOOK` at 0.15625%. Nothing left to execute.
2. **Lever #3, hold-release half (13 `COVERED` EAs): DONE**, 2026-09-26. 13 rows across 10
   EAs released; `QM5_41484` confirmed still held, as instructed. Nothing left to execute.
3. **Lever #3, `requalify-q02` half (49 `BLOCKED_AT_IDENTITY` EAs): materially stalled.**
   Of the 49 EAs, **1** (`QM5_13137`) is now unblocked and mid-chain (fresh `COMPILE_OK` →
   Q02 PASS → Q03 PASS → Q04 pending, landed 2026-09-28, after a first attempt failed on an
   unrelated infra bug). **48 of 49 are unchanged since 2026-09-26.** The remaining
   GRÜN-authorized continuation (registering more EAs against the already-landed, already-
   used `legacy_first_governed_compile` mechanism under the existing
   `FABLE-DEC-P80-LEVER-20260926` decision) requires committing a registry edit + an
   evidence doc to the **canonical** `C:/QM/repo` checkout, which this task's own launch
   constraints forbid from this worktree session (see §3.3). It was not executed here for
   that reason, not because it is ROT.

## 1. Lever #2 — QM5_41470 V3 book marginal (5×40k, both cost arms)

**Status: DONE.**

- Commit `e2a928c1fb` — "research(ftmo): 41470 resolution book-marginal (5x40k, both cost
  arms) + SHADOW/QUEUE decision input".
- Full run and numbers:
  `docs/ftmo/p80_lever_synthesis_2026-09-26/resolution_41470/RESULT.md`.
- Admission test (`ΔP80 < 0 AND ΔLCB ≥ 0`) **passes cleanly in the normal cost arm** at both
  weights (0.15625% / 0.3125%) and both timing variants (actual / ≥52w-shifted):
  ΔP80 −35 to −80 bd, ΔLCB +0.00 to +0.02 across all 5 paired seeds × 40,000 paths.
- **Fails the literal both-cost-arms bar only because P80 is structurally unreached under
  the stress arm for the book with or without 41470** (stress `P_EVER` 0.76–0.79, below the
  0.80 floor `governor_ladder.quantile_day()` requires, independent of path count — confirmed
  at 2× the synthesis doc's paths). Stress ΔLCB is resolved **positive** (+0.01 to +0.02) in
  every stress cell; only the ΔP80 leg is undefined there.
- Per the OWNER-specified action rule (pass both arms → `QUEUE_FOR_NEXT_DEMO`; pass normal
  only → `SHADOW_BOOK`; else `HOLD`): action is **`SHADOW_BOOK`** at 0.15625%, not
  `QUEUE_FOR_NEXT_DEMO`. `DEMO_RESET_COST_USD = 0` — Sunday gen-2 roster untouched.
- Recorded durably in `docs/ftmo/FTMO_BOOK_CURRENT.md` (grep-verified present, §2 row
  `41470_RESOLUTION (2026-09-26, 5x40k, decision 3 of FABLE-DEC-P80-LEVER-20260926)` plus the
  full per-weight/timing/cost-arm table and the §"41470 addendum").
- §6 falsifier #2 ("resolution run gives ΔP80 > −20 bd or ΔLCB < 0") **does not fire** —
  every normal-arm cell clears it by 15–60 bd of margin.

**Nothing left to execute for lever #2.**

## 2. Lever #3, part A — release the 15 stale pre-flag Q08 holds on 13 `COVERED` EAs (except `QM5_41484`)

**Status: DONE.**

- Commit `5ab9154996` — "ops(8b692228): Q08 near-zero-cost unblocks executed (hold
  releases, re-anchors, receipt, setfile carry-over) - receipts".
- Full receipts:
  `docs/ops/evidence/task_8b692228/Q08_CLAIM_TIME_CENSUS_FLAGGED/UNBLOCK_EXECUTION_2026-09-26.md`.
- Target set: all 16 `COVERED` rows in the flagged census except `QM5_41484` = 15 rows / 12
  EAs. 2 rows (`QM5_10269`, `QM5_41472`) already had no active hold. **13 rows across 10
  EAs** (`QM5_10122`, `QM5_10134`, `QM5_12358`, `QM5_12366`, `QM5_12549`, `QM5_1615`,
  `QM5_1910` ×2, `QM5_41394` ×2, `QM5_9579` ×2, `QM5_9908`) released via
  `farmctl release-hold`, each with an explicit release-note and `ledger_seq` (5085–5097).
- `QM5_41484` verified **still held** on `VELOCITY_LINEAGE_RETIRED_20260920` — confirmed
  independently in this task, read-only, against the live DB (see §2.1).
- Final state (verified in the 09-26 receipt, read-only re-sweep): **15 of 16 `COVERED` rows
  claimable** by the next real worker scan; only `QM5_41484` remains deliberately held.

### 2.1 Independent re-verification (this task, 2026-10-02, read-only)

Re-queried the live DB directly for `QM5_41484`'s hold state:

```
work_item_holds WHERE ea_id='QM5_41484' AND hold_code='VELOCITY_LINEAGE_RETIRED_20260920'
-> active=1 (unchanged since 2026-09-26)
```

No drift. **Nothing left to execute for lever #3, part A.**

## 3. Lever #3, part B — `requalify-q02` for the 49 `BLOCKED_AT_IDENTITY` EAs

**Status: 1 of 49 unblocked and in flight; 48 of 49 unchanged since 2026-09-26.**

### 3.1 What the 49-EA cohort actually is

Source: `docs/ops/evidence/task_8b692228/Q08_CLAIM_TIME_CENSUS_FLAGGED/census.json`
(91 pending Q08 rows, re-run with both v2 flags verified exported). Classification
breakdown of the 67 `BLOCKED_AT_IDENTITY` rows / 49 EAs, by `flagged_leaf_reason`:

| Leaf reason | Rows | Has an existing remedy? |
|---|---:|---|
| `q08_legacy_qualifier_v2_refused` | 34 (29 EAs) | **Yes** — `legacy_first_governed_compile` mechanism (code-landed, 16/16 tests) |
| `q08_current_build_compile_provenance_unavailable` | 23 | No — out of this mechanism's scope |
| `q08_predecessor_setfile_identity_mismatch` | 5 (3 EAs) | No — exact governed replacement-setfile path not supplied by any census (confirmed NOT_RUN 2026-09-26, unchanged) |
| `q08_current_execution_binding_refused` | 4 | No — different hold class (`Q08_PROMOTION_BINDING_REFUSED`), out of this mandate |
| `q08_compile_include_closure_unbound` | 1 | No |

**Only the 29-EA `q08_legacy_qualifier_v2_refused` class is actually reachable by
`requalify-q02`-style remediation today** — and only after a prior fresh `COMPILE_OK`,
which is what `legacy_first_governed_compile` supplies. `requalify-q02` itself
(`farmctl.py requalify-q02 --old-work-item-id ... --expected-current-ex5-sha256 ...`)
requires that fresh ex5 to already exist; it cannot run first. The other 20 EAs (23+3+... /
leaf reasons above) have **no existing governed command** that resolves them — new
engineering, not a dispatch.

### 3.2 What was actually run (2026-09-26, wave-3 pilot) and what happened to it since

- Commit `86900f5b07` — "ops(8b692228): legacy FGC wave-3 pilot executed - supersedes,
  compiles, requalify-q02 (receipts)". Full log:
  `docs/ops/evidence/task_8b692228/LEGACY_FIRST_GOVERNED_COMPILE/wave3_pilot/EXECUTION_RECEIPTS_2026-09-26.md`.
- 5 EAs attempted: `QM5_13137` (the only one actually in the reachable 29-EA class and
  genuinely `ELIGIBLE` at enqueue-time), plus `QM5_12849`, `QM5_12855`, `QM5_11660`,
  `QM5_9641` (all 4 are in fact in the **unreachable** `q08_current_build_compile_
  provenance_unavailable` class — refused `q08_rows_without_bound_q07_identity`, exactly as
  predicted, zero DB mutation).
- `QM5_13137` enqueued successfully (`ok:true`) but then failed at worker claim-time
  (`CANDIDATE_RECHECK_REFUSED`) because worker `T1` was running a stale in-memory copy of
  `compile_work_items.py` — a factory-infra defect unrelated to the identity gap, newly
  discovered by that run.
- **Result that day: 0 of 5 reached `COMPILE_OK`.** No `work_item_supersedes` record and no
  `requalify-q02` call were made for any of the 5 (correctly — doing so without a real
  compile would have written false evidence; the report flags this explicitly).

**Re-verified directly against the live DB by this task (read-only, 2026-10-02):**

```
QM5_13137 work_items (created_at order):
  2026-09-26T16:21:17Z  COMPILE_EA  COMPILE_FAIL   (the T1 stale-module failure above)
  2026-09-28T00:50:18Z  COMPILE_EA  COMPILE_FAIL   (retry, still failed)
  2026-09-28T01:23:30Z  COMPILE_EA  COMPILE_OK     <- succeeded once T1 reloaded the module
  2026-09-28T01:30:26Z  Q02         pending
  2026-09-28T01:54:47Z  Q02         PASS
  2026-09-28T03:12:14Z  Q03         PASS
  2026-09-28T03:12:10Z  Q04         pending        <- current state, still in flight
```

So `QM5_13137` **was** carried through requalification after the infra bug cleared — by a
later session, not by the 09-26 pilot itself and not by this task. Its original 2 pending
Q08 rows (`15f2ecb0…`, `f8cb2092…`) are still `status='pending'` (re-verified read-only,
2026-10-02) — unsuperseded, because superseding them is only correct once the fresh chain
actually reaches Q08 again (per the pilot's own stated rule), which it has not yet.

**No other EA from the 49-EA cohort shows any activity after 2026-09-26.** I separately
found three *different* EAs (`QM5_12358`, `QM5_12366`, `QM5_10122`) that went through the
same `legacy_first_governed_compile` → fresh-Q02 path between 2026-09-28 and 2026-09-30 and
are now also sitting at `Q04 pending` — but a direct membership check against
`census.json`'s 49-EA list confirms **none of the three is in this cohort**. Their wave
registry entries (`tools/strategy_farm/config/legacy_first_governed_compile_waves.v1.json`)
cite a different census (`2026-09-26_astra_takeover/q08_completeness_independent_review/
LEGACY_RECOVERY_CENSUS_20260928.json`) and a different decision authority
(`decisions/2026-09-26_owner_astra_ftmo_takeover.md` /
`decisions/2026-09-26_owner_research_first_demo_deferred.md`). That is adjacent,
separately-OWNER-authorized parallel work, not this lever — noted here only so it is not
mistaken for progress on the 49.

**Net for the named 49-EA cohort: 1 unblocked and in flight (`QM5_13137`), 48 unchanged.**

### 3.3 Why no further dispatch was executed in this cycle

The remaining 28 EAs of the reachable 29-EA class (`q08_legacy_qualifier_v2_refused` minus
`QM5_13137`) are a legitimate GRÜN continuation in principle: the mechanism is code-landed
and test-covered (`tools/strategy_farm/tests/test_legacy_first_governed_compile.py`,
16/16 passing per `docs/ops/evidence/task_8b692228/LEGACY_FIRST_GOVERNED_COMPILE/RESULT.md`),
and the exact same existing, ratified decision
(`decisions/2026-09-26_fable_p80_lever_breadth_over_new_waves.md`) that authorized the first
5-EA pilot covers extending it — no new decision is implied.

But registering one more EA requires: (a) a per-EA evidence document (mirroring
`wave3_pilot/QM5_13137_breadth-tue.md`) and (b) an edit to
`tools/strategy_farm/config/legacy_first_governed_compile_waves.v1.json` — both of which
must be **committed to the canonical `C:/QM/repo` checkout** for the registry's
mtime-reload/fail-closed loader to see them from the real factory workers. This task's own
launch instructions are explicit and repeated: *"NEVER modify, patch or write files under
C:/QM/repo… EDIT AND COMMIT ONLY INSIDE YOUR OWN WORKING DIRECTORY"* — a worktree evidence
commit here would not reach the canonical registry the live workers read, and a direct edit
to the canonical checkout from this session is exactly the resource-collision class that
instruction exists to prevent (a prior incident broke a governed enqueue with a `SyntaxError`
this way). So the remaining 28-EA extension is correctly GRÜN in substance but is not
something this worktree-bound session can land — it needs a session actually running from
`C:/QM/repo` canonical (the same posture `5ab9154996`/`86900f5b07`/the Astra-authority
entries all ran from).

**The other 20 EAs (leaf reasons without any existing remedy — §3.1) are not GRÜN at all:**
closing their gap needs new engineering (a setfile-path recovery tool, a provenance-recovery
path, or a promotion-binding review), which is design/engineering work, not "operate an
existing tool with unchanged criteria." Treated as ROT pending a scoped ticket, per the
Stehende-Vollmacht default (uncertain → ROT).

## 4. Before/after count (the task's own ask)

| | 2026-09-26 (synthesis + first unblock receipt) | 2026-10-02 (this check) |
|---|---|---|
| `COVERED` Q08 rows claimable (of 16) | 15/16 (13 released + 2 already clear) | 15/16 — unchanged, re-verified |
| `QM5_41484` | held (deliberate) | **still held** — re-verified |
| `BLOCKED_AT_IDENTITY` EAs (of 49) | 49 blocked | **48 blocked, 1 (`QM5_13137`) unblocked and at Q04-pending** |
| 41470 book-marginal | not yet resolved at 40k paths | **resolved**, `SHADOW_BOOK` |

## 5. Recommended next step

1. Hand the 28-EA wave extension (§3.3) to the next session that runs from canonical
   `C:/QM/repo` — reuse `decisions/2026-09-26_fable_p80_lever_breadth_over_new_waves.md` as
   `decision_reference`, same shape as the 5 existing wave-3-pilot entries. This is bounded,
   already-reviewed, already-precedented work.
2. Do not conflate the Astra-authority EAs (`QM5_12358`, `QM5_12366`, `QM5_10122`) with this
   cohort in future status checks — they are a different census and a different decision.
3. The 20 EAs with no existing remedy (§3.1) need a scoped ticket before any further
   `requalify-q02`-style work is attempted on them.
