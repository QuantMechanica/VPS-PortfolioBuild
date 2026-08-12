# CODEX BRIEF 2026-08-02 — Q09_NEWS cell executor (the admission-chain blocker)

**Author:** Claude. **Implementer:** Codex (Sol, effort max). **Reviewer:** Claude.
**Authority:** OWNER 2026-08-02 („geh den gesamten Reparaturaufwand an!").
**Predecessor (APPROVED):** `docs/ops/evidence/2026-08-02_11422_repair_tooling.md`
— it built the repair surface and then correctly refused to fake this step.

## The blocker, precisely

Every book-admission chain now runs Q02→Q08 with hash-bound tooling and then
stops. `Q09_NEWS` cannot produce evidence because the execution bridge is
missing, not the contract:

- `q09_news_runner.py plan` already seals calendar, policy arms, five-seed
  cells, setfiles and artifact hashes;
- `q09_news_runner.py collect` already authenticates completed cell receipts
  and can emit `CONFIG_LOCKED` / `REVIEW_REQUIRED` / `INVALID_EVIDENCE`;
- `farmctl.py` invokes only `collect`, and only when the work item's payload
  already carries `q09_run_plan_path`;
- **no production tool writes that payload field or dispatches the plan's cell
  runs.** The only other occurrence in the repo is a unit-test fixture.
- `docs/ops/mnt_page_updates_2026-07-29/MNT-050.md` records this as
  `RUNTIME_DEFERRED` — accurately.

Consequence: enqueueing a `Q09_NEWS` row today mints another `PENDING_RUNNER`
placeholder. Four such placeholders already exist (11422, 13013, 13036, 20048)
and are the reason those candidates have no admissible lineage.

## Build

The missing middle: a production executor that takes a sealed plan, runs its
cells, publishes authenticated receipts, and binds `q09_run_plan_path` into the
work item so the existing `collect` path can adjudicate.

1. **Plan binding.** A supported way to attach a sealed plan to an exact work
   item (payload field, hash-bound to the plan artifact). No free-text paths.
2. **Cell dispatch.** Execute the plan's five-seed policy-arm cells through the
   ordinary factory lane — same terminal reservation, same run_smoke contract,
   same evidence roots. The lane must respect factory capacity; do not invent a
   parallel execution path and do not starve the DXZ backlog.
3. **Receipt publication** in exactly the shape `collect` already authenticates
   — read that code first and conform to it rather than changing it.
4. **Fail-closed everywhere:** a partially executed plan yields
   `REVIEW_REQUIRED` or `INVALID_EVIDENCE`, never a synthesized `CONFIG_LOCKED`.
   A missing or drifted plan hash refuses.
5. **Tests** covering: plan-binding refusal on hash drift, partial-cell
   collection, receipt tampering, capacity refusal, and one end-to-end
   plan→dispatch→collect→`CONFIG_LOCKED` on fixtures.

**Hard constraints:** factory keeps running; no T_Live contact; no Q-verdict
invention; no enqueue of production Q09 rows (Claude does that after review);
explicit-pathspec commits.

## Why this matters beyond the four candidates

`Q09_NEWS` sits in every admission chain. Until it can execute, **no new sleeve
can ever reach Q10** — not these four, not 10440's requalification, not any
future motor. This is the narrowest remaining bottleneck between a passing
strategy and a book slot.

## Deliverable

`docs/ops/evidence/2026-08-02_q09_news_executor.md`: what was built, verbatim
test output, the exact operator command sequence for one candidate, and an
honest statement of anything still deferred. Router task → REVIEW.
