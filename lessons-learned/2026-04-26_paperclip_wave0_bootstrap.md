# Paperclip Wave-0 Bootstrap — Lessons Learned

**Date:** 2026-04-26
**Phase gate:** Phase 1 (Paperclip Bootstrap) — landing
**Author:** CEO (this agent)
**Reviewer (pending):** OWNER + Board Advisor (Documentation-KM will own going forward)
**Severity:** P3 (no production impact; setup-quality lessons)

---

## Cadence reminder

Per `docs/ops/PAPERCLIP_OPERATING_SYSTEM.md` § "Process Roadmap" and the
process registry's PR-14 row, lessons-learned entries are written:

- **One per phase gate** — at the closeout of every phase (Phase 0, 1,
  2, …) recording what was kept / changed / discarded.
- **One per incident** — every production incident, even resolved ones,
  with timeline + root-cause + mitigation.
- **One per video episode** — what the episode taught vs. what landed
  on YouTube (script drift, viewer feedback, mid-edit corrections).

Once Documentation-KM is hired, this entry's structure becomes the
template. Until then, CEO drafts and OWNER reviews.

---

## Lesson 1 — Embedded Postgres 18-beta failed; switched to PostgreSQL 17

**Kept:** Decision to embed Postgres rather than rely on a system-level
DB. Embedded keeps the VPS portable and aligns with the "filesystem is
truth" principle.

**Changed:** Pinned to **PostgreSQL 17** (stable). The 18-beta builds
shipped with the prior Paperclip install path failed to start
reproducibly under the Windows Server 2022 environment. No public
incident — the failure was caught during install, not in production.

**Discarded:** The premise that "newer is fine for an embedded runtime
in a single-user VPS deployment." Beta builds are out by default for
infrastructure components going forward.

**Action items propagated:**
- DevOps (Wave 1, pending hire): pin Postgres major version explicitly
  in the install runbook; add a pre-install version check.
- Documentation-KM (Wave 0, pending hire): add a "no-beta-runtime" rule
  to the infrastructure conventions doc.

---

## Lesson 2 — Paperclip auto-onboarding wizard created tutorial agents we had to repurpose

**Kept:** The Paperclip product's wizard is intentional onboarding for
new users; it is doing its job for the general case.

**Changed:** For V5, the wizard's defaults (US equities momentum
narrative, FoundingEngineer + auto-CEO) had to be overridden via DL-010
(repurpose) rather than fought at the product level. CEO agent's `cwd`,
project assignment, default environment, and effective system context
were rebriefed via the QUA-8 issue body — not by replacing
`AGENTS.md` (DL-014 confirmed this two-layer pattern).

**Discarded:** The instinct to delete-and-recreate when a wizard creates
a non-fitting agent. The CEO role is product-enforced (cannot be
deleted); rebriefing through issue body + comments is the supported
path.

**Action items propagated:**
- Wave 1+ hires follow the same two-layer pattern (DL-014): native
  Paperclip role prompt + V5 first-issue brief drawn from
  `paperclip-prompts/<role>.md`. CEO seeds the brief on hire, OWNER
  approves the agent.
- Onboarding cleanup: QUA-1..QUA-7 closed as `cancelled` with a single
  reference to DL-010 (this lessons-learned entry, plus Deliverable F
  of QUA-8, completes that loop).
- Onboarding project archived (separate from the V5 Portfolio Factory
  project).

---

## Lesson 3 — Auto-CEO repurpose decision (DL-010) was the right call

**Kept:** Repurposing the auto-created CEO agent rather than deleting
and recreating. Same agent id (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`),
new context. Per DL-014, the first run after rebrief produced a clean
backlog-driven org chart (DL-011) and capability routing matrix (DL-012)
with no lingering tutorial-context bleed-through.

**Changed:** The hire model going forward — system prompt
(`AGENTS.md`) is OWNER/Paperclip-managed and stable; mission context is
delivered via issue body + comment thread per role. The repo
`paperclip-prompts/*.md` files are **issue-body templates and Wave-0+
hire briefs**, not system-prompt sources. This is locked in DL-014.

**Discarded:** The earlier plan (implicit in pre-DL-014 thinking) of
hand-pasting `paperclip-prompts/ceo.md` into the system prompt slot at
hire. That would have wiped the Paperclip-native operating model
(delegation patterns, skills like `paperclip-create-agent`, confirmation
workflows).

**Action items propagated:**
- All Wave 0/1 hire requests (including the live DL-013 proposal for
  DevOps + Pipeline-Operator) follow the two-layer pattern.
- If a future hire produces output that contradicts the Paperclip-native
  operating model and cannot be corrected via issue comments, only then
  consider prompt-level intervention (the reverse condition in DL-014).

---

## Cross-references

- `governance/decision_log.md` — DL-010, DL-011, DL-012, DL-013, DL-014
- `governance/org_chart.md` — Wave 0 / Wave 1 decision, Capability Routing
- `agents/wave_plan.md` — trigger conditions, readiness check
- `processes/process_registry.md` — PR-14 Lessons-Learned
- `docs/ops/PAPERCLIP_OPERATING_SYSTEM.md` — gate rule, evidence rule
- Paperclip approval `78891637-8f23-4191-959a-ce3e5c9807ca` — Wave 1 hire request
