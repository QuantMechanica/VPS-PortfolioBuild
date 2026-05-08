# Per-agent skill audit + one-skill-per-agent migration plan

**Parent:** QUA-696 (OWNER ask 2026-05-01: "one skill per agent — Research → YouTube watcher / PDF reader / research-mgmt as separate sub-agents")
**Authority basis:** OWNER directive on QUA-696 + DL-056 § "Agent roster hygiene" + DL-056 § "Hard constraints" (recommend only, CEO acts).

## Deliverable

A single document at `docs/ops/CHIEF_OF_STAFF_SKILL_AUDIT_2026-05-XX.md` containing:

### Section 1 — Current state audit

For each live agent in the API roster (`GET /api/companies/03d4dcc8-.../agents` cross-referenced with filesystem `paperclip/data/instances/.../agents/<uuid>/instructions/AGENTS.md`):

| Agent | UUID | Role | Model | Skills loaded today | Inferred skill count | Token spend (last 7d) |
|---|---|---|---|---|---|---|

Where "skills loaded" = the union of:
- Skills referenced in the system prompt (look for "Skill" tool capability or skill names in the prompt)
- Capabilities visible from the tool surface (Bash, Edit, browser, MT5, etc.)
- Domain responsibilities listed in the AGENTS.md (e.g. for Research: extracting from PDFs, watching YouTube, summarizing papers, drafting Strategy Cards)

### Section 2 — Skill atomization proposal

For each agent that has >1 skill: propose a sub-tree. Concrete example OWNER named:

```
Research-Lead (parent — strategy-card authoring + research-queue mgmt)
├── Research-PDF-Reader   (one skill: PDF → structured extract)
├── Research-YouTube-Watcher (one skill: video → transcript → structured extract)
└── Research-Web-Crawler  (one skill: web article → structured extract)
```

Apply same pattern to other multi-skill agents (Documentation-KM, DevOps, etc.) where token cost or context bloat justifies it.

### Section 3 — Token-burn impact projection

Per-agent: estimated burn-rate delta if migrated to one-skill-per-agent. Format: "Research-Lead today consumes X tokens/heartbeat at Y kCtx; split into 4 sub-agents would shift baseline to Z tokens/heartbeat at W kCtx (delta = ...)."

This is the CoS's core analytical contribution. Without numbers the proposal is just architecture cosplay.

### Section 4 — Migration plan

- **Phase 1:** sub-agents that are currently bottlenecks (highest burn, longest context, most-frequent waker).
- **Phase 2:** sub-agents whose absence would cause routing confusion (e.g. PDF reader without research-mgmt parent makes no sense).
- **Phase 3:** the long tail.
Each phase: explicit hire list with prompt sketches, reports-to chain, model recommendation per sub-agent, expected token-burn delta.

### Section 5 — Risks + tradeoffs

Things to NOT shy away from: more agents = more inter-agent comments = more wakes = more burn at the routing layer. Smaller contexts ≠ universally cheaper. State this explicitly with numbers; do not theatre-mode it away.

### Section 6 — Recommended decision (per DL-056 output tone)

`accept / reject / defer-with-reason` for each phase. CoS recommends; CEO acts.

## Process gate (binding)

Before any new agent gets hired:

1. CoS posts the document above as a comment on this issue.
2. CEO reviews + creates `request_confirmation` to OWNER on this issue with `idempotencyKey: confirmation:{thisIssueId}:plan:v1`.
3. OWNER accepts → CEO executes Phase 1 hires using `paperclip-create-agent` skill.
4. CoS does **not** auto-spawn agents (per DL-056 hard constraint § "no direct API agent-create or agent-retire").

## Acceptance

- Document exists at the path above and is referenced by SHA in a comment on this issue.
- Token-burn deltas are real numbers, not "TBD" or "see below."
- OWNER has explicitly accepted at least Phase 1 of the migration via `request_confirmation` accept.

## Out of scope

- T6 / live deploy (DL-056 hard constraint).
- Org-chart edits (DL-056 hard constraint — Doc-KM owns).
- Any existing agent retirement (DL-056 hard constraint — recommend only).
- Re-naming or re-scoping the founder-comms CoS (Wave-6, DEFERRED per DL-052).

## ETA target

Plan document: 2026-05-04 EOD W. Europe local. OWNER ratification: 2026-05-05.
