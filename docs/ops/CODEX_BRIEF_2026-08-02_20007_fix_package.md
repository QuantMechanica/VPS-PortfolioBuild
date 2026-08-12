# CODEX BRIEF 2026-08-02 — QM5_20007 Q02 fix package (P0 defects)

**Author:** Claude (from the reviewed diagnosis
`docs/ops/evidence/2026-08-02_20007_q02_infra_diagnosis_DRAFT.md` — cite it for
every file:line anchor). **Implementer:** Codex (Sol, effort max) via the router
lane. **Reviewer:** Claude (close-review; builder ≠ approver). OWNER authorized
implementation 2026-08-02 ("bring 1 und 2 zur Umsetzung, via Codex, du reviewst").

**Hard constraints:** factory is RUNNING — no Factory_OFF/ON, no terminal
start/stop, no T_Live contact, no requeue of any 20007 row (canaries come after
review), no farm-DB mutation beyond what your build/test tooling normally does.
Work on `agents/board-advisor`, explicit pathspec commits only.

## Scope — three P0 defects from the diagnosis

1. **Runner watchdog + stale-tail classifier (GDAXI killer).** The 60-second
   outer watchdog plus the unscoped stale-tail classification discards or
   mislabels completed GDAXI report handoffs, so finished runs die as
   INFRA_FAIL with attempt_count=0. Fix per the diagnosis recommendation:
   the report-handoff wait must span the retry cadence (no 60 s hard ceiling
   on a live handoff), and stale-tail classification must be scoped to the
   CURRENT run's artifacts (never classify a run by a previous run's tail).
   Add regression tests reproducing both failure shapes (fixture logs/report
   trees; no MT5 needed).
2. **QM5_20007 per-tick stop-modify log-bomb (NDX killer).** The EA emits a
   normalized no-op/invalid-stop modification loop every tick on full-window
   runs. Patch the EA source: only issue a stop modification when the
   normalized target differs from the current stop by at least one point AND
   the target is broker-valid; throttle any remaining rejection logging
   (bounded, e.g. once per bar per reason). Follow the existing framework
   idiom for stop hygiene (compare with how other EAs guard SL modifies).
   Rebuild via the standard build lane so the registry/resolver flow stays
   intact; NO manual compile shortcuts.
3. **T3 account/profile fault — PREPARATION ONLY.** The diagnosis found T3's
   missing account/profile configuration (T3 log 2026-08-01 lines ~1310-1369).
   Do NOT touch the running T3. Deliver an exact repair plan (files, expected
   contents, verification commands) executable in the next stopped-state
   window, plus a detection probe that the hourly health lane could run
   read-only.

## Out of scope

Requeues of the failed 20007 rows, the P1 canaries (Claude schedules them
after close-review), history reimports (explicitly rejected by the
diagnosis), and any change to the [32]-handle contention behavior beyond
observation notes.

## Deliverables

`docs/ops/evidence/2026-08-02_20007_fix_package.md` with: changed files +
commits (explicit pathspecs), verbatim test output (new regression tests plus
the touched suites), the EA diff rationale bound to diagnosis anchors, the T3
repair plan, and the recommended canary commands for the follow-up. Set the
router task to REVIEW with that artifact path.
