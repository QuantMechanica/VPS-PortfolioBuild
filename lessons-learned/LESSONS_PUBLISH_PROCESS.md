# Lessons-Learned Publish Process

**Owner:** Documentation-KM  
**Established:** 2026-05-15 (QUA-1602)  
**Authority:** DL-027 (Documentation-KM owns lessons-learned)

---

## When to publish a lesson MD

A lesson MD must be published into `lessons-learned/` after any of the following events.
**All three trigger classes are mandatory** — they do not require a separate role approval to create the
entry (Documentation-KM is autonomous here per DL-027), but significant entries should be
flagged as `learning-candidate` records for OWNER review before being promoted to the
Learnings Archive.

### 1. Gate review produces a notable finding

**Scope:** G0 source approval, P2 baseline, P3 sweep, P3.5 CSR, P4 walk-forward, P5 stress,
P5b noise, P5c crisis, P6 multi-seed, P7 statistical, P8 news, P9 portfolio, P9b readiness, P10 shadow.

**Trigger:** Gate closes (PASS, FAIL, or VOID) AND at least one of:
- A **runner/spec mismatch** is discovered (gate is in the spec but not the runner)
- An EA is declared **pipeline-VOID** or **phantom state** is found
- A **FAIL verdict** produces reusable insight (not just "this EA doesn't work")
- A **process deviation** is caught that affected the gate outcome

**File naming:** `YYYY-MM-DD_<phase>_<slug>.md`  
Example: `2026-05-09_p2_runner_gate_gap.md`

**Lesson format (required):**
```
# <Title>

**Gate:** <phase/gate label>
**Issue:** <QUA-NNNN>
**Date:** YYYY-MM-DD
**Author:** <agent or role>

## Finding
<What was discovered>

## Why it happened
<Root cause — spec, code, process gap>

## Impact
<What ran wrong / what risk existed>

## Corrective
<What was fixed, what process or code change closes this>

## Going-forward rule
<Single statement that can be checked in future gate reviews>

## Cross-references
<DL-NNN, QUA-NNN, docs/ops/... paths>
```

### 2. Incident closes (post-mortem complete)

**Scope:** Any P0/P1 incident that triggered `04-incident-response.md`. Also covers:
- Agent pathology events (recursive wake, quota collapse, churn-loop)
- Data pipeline failures (phantom PASS, zombie dispatch_state, symbol mismatch)
- Live-system incidents (T6 anomalies — OWNER gates these separately)

**Trigger:** Incident is closed in the active local controller and a post-mortem exists in `docs/ops/`.

**Process (`04-incident-response.md` Step Q):**
1. Read the post-mortem doc (authored by Observability-SRE or incident owner)
2. Extract the durable learnings into a lesson MD
3. Post to `lessons-learned/` with a cross-reference back to the post-mortem doc path
4. Add the entry to `lessons-learned/README.md`
5. If the learning is general enough to affect the Learnings Archive → open `learning-candidate` issue

**File naming:** `YYYY-MM-DD_<incident-slug>.md`  
Example: `2026-05-01_codex_outage_phantom_pass_class.md`

### 3. Episode is published (OWNER sign-off obtained)

**Scope:** Any YouTube episode where the "What I Learned" section from the episode pack
(`episodes/EP{nn}/show_notes.md`) contains a reusable lesson.

**Trigger:** OWNER confirms publish (`HOW_TO_PUBLISH.md` Step 8). Documentation-KM reads the
"What I Learned" section and decides if it merits a standalone lesson MD.

**Criteria for standalone lesson MD (any one sufficient):**
- Learning changes how a future agent/episode should approach the same problem
- Learning contradicts or refines an existing Learnings Archive entry
- Learning is about process, tooling, or framework (not just "this EA failed")

**File naming:** `YYYY-MM-DD_ep<nn>_<slug>.md`  
Example: `2026-04-27_ep04_verify-vendor-compatibility-practically.md`

---

## What does NOT need a lesson MD

- Routine FAIL or INVALID results with no novel insight (the EA just doesn't work; the gate
  spec is working as expected)
- Evidence files for a gate that are already in `docs/ops/` and don't add a process learning
- Investigation findings that are fully captured in an existing lesson MD (add a cross-ref instead)

---

## Promoting to the Learnings Archive

A lesson MD in `lessons-learned/` is an **operational log**. The Learnings Archive
(`docs/notion-mirror/learnings_archive.md`) is the **curated, board-reviewed canonical list**.

To promote a lesson to the archive:
1. Open a `learning-candidate` issue tagged with the relevant lesson file
2. OWNER reviews and decides format: L-K-xx (Keep), L-C-xx (Changed), L-D-xx (Discarded)
3. Documentation-KM adds the entry to `docs/notion-mirror/learnings_archive.md` and the
   Notion source after board approval

Documentation-KM does **not** add to the Learnings Archive unilaterally.

---

## README maintenance

After every lesson MD is created:
- Add one bullet to `lessons-learned/README.md` under "Recent entries"
- Include: filename, one-line summary of the learning, issue reference if applicable
- Keep only the 10–15 most recent in the "Recent entries" section; older entries remain in git

---

## Cross-references

- `processes/04-incident-response.md` — Step Q (Doc-KM archive trigger for incidents)
- `docs/episodes/HOW_TO_PUBLISH.md` — Step 8 (post-publish trigger for episodes)
- `docs/notion-mirror/learnings_archive.md` — the curated archive (Notion-canonical)
- `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` — historical V4 basis
- DL-027 — Documentation-KM ownership of lessons-learned
