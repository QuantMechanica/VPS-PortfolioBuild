# Phase Final - Founder Communications & Chief of Staff

Status: **DEFERRED — open todo, scheduled as the LAST phase of building the company.**

This is intentionally the final company-construction milestone. Do not start any implementation work in this doc until every prior phase (Phase 0 foundation, factory online, tester assumptions documented, T6 isolation verified, public dashboard live, demo portfolio MVP, etc.) is closed. When we return to this doc, all the recommendations and constraints below are already captured — start from here.

Owner of the open todo: OWNER (gate decision). Drafting owner when activated: CEO + Documentation-KM, then handed to a new **Chief of Staff** agent.

---

## Why this is last

- The capability depends on Paperclip being online with a real process registry, decision log, risk register, and issue board to summarize. Without that, the daily briefing has nothing to brief on.
- It depends on browser-worker substrate that does not exist yet.
- It is founder-facing: any drift, leakage, or hallucination is highly visible. Stable foundations first.
- It must never bleed into LiveOps / T6 controls. Building it before LiveOps boundaries are proven creates the wrong kind of pressure.

## Trigger to start this phase

All of the following are true:

- Phase 0 is closed (per `PHASE0_EXECUTION_BOARD.md` Acceptance Gate).
- Tester commission / swap / DST / broker-time assumptions are documented and verified.
- T1-T5 factory and T6 isolation proven over time, no cross-contamination incidents.
- Public dashboard hourly snapshot is stable.
- At least one approved EA has lived on T6 demo through a deploy manifest.
- Issue board, decision log, risk register, lessons-learned, and process registry are populated enough that a daily briefing has real content.
- OWNER explicitly says "now build founder-comms".

If any of those are false, this phase stays deferred.

---

## Capability summary (frozen scope when we return)

QuantMechanica must be reachable at `info@quantmechanica.com` via a Gmail mailbox already logged into a Chrome session on the VPS. A dedicated browser-enabled agent (**Chief of Staff**) handles inbound and outbound on that mailbox.

**Daily behaviors:**

1. Once per day, off-peak: review inbound mail via the open Chrome session.
2. For any message from OWNER / the founder: classify impact area (trading-strategy / Paperclip / agents / pipeline / infrastructure / website-dashboard / company-process-governance / none), assess whether it can be integrated, and reply with what was understood, whether it can be integrated, and the action being taken or the blocker.
3. Every day at 05:00 W. Europe local time: send OWNER a summary of the previous day - work done, completed, changed, blockers / risks, recommended next steps.
4. Never act directly on trading state. Founder mail that asks for a live-trading change is escalated to CEO and routed through the existing deploy-manifest gate.
5. Every action leaves traceable local evidence.

**Hard constraints (non-negotiable):**

- No credentials stored, printed, or committed. Reuse the human-logged-in Chrome profile only.
- No automation built before activation is approved.
- Zero authority over T6, AutoTrading, deploy manifests, or factory paths.
- Every browser action produces screenshot + DOM snapshot evidence.
- Outbound restricted to a whitelist (OWNER + the mailbox itself) until proven; per-message OWNER approval required for anything outside the whitelist.

---

## Paperclip placement (when activated)

| Layer | Entity |
|---|---|
| Company | `QuantMechanica V5` (existing) |
| Project | **NEW** `Office & Founder Operations` (peer of `Portfolio Factory V5`, not a child of LiveOps) |
| Milestones | `MC0` Capability Spec → `MC1` Scaffolding → `MC2` Read-Only Triage → `MC3` Draft-Reply (human send) → `MC4` Auto-Reply within whitelist + 05:00 briefing live |
| Routines | `comms.founder_mail_triage` (daily, off-peak), `comms.daily_briefing` (05:00 W. Europe local), `comms.weekly_briefing_retro` (weekly) |

**Boundary rule:** the Office project never depends on, writes into, or is depended on by `Portfolio Factory V5`'s LiveOps tree. Cross-project signal is one-way: factory state → Office (read for briefings); not Office → factory.

---

## Future agent: Chief of Staff (`CoS`)

- **Why dedicated, not a Documentation-KM skill:** needs browser-control capability no other role has; briefing synthesis spans the whole company; clean role boundary makes it easy to disable comms without touching Documentation-KM.
- **Why the name "Chief of Staff":** avoids "EA" (collides with Expert Advisor). "Founder-Liaison" is an acceptable descriptive alias. "Comms-Inbox" is too narrow.
- **Reports-to:** CEO.
- **Coordinates with:** Documentation-KM (lessons-learned, public wording), Controlling (KPI numbers in briefing), Observability-SRE (incidents in briefing).
- **Does not coordinate with:** LiveOps. Founder mail about live trading escalates to CEO.
- **Wave assignment:** new **Wave 6** in `PAPERCLIP_V2_BOOTSTRAP.md` agent expansion order, after R-and-D, with the trigger conditions above.

### Responsibilities (frozen)

| # | Responsibility | Done condition |
|---|---|---|
| 1 | Daily inbox review via reused Chrome session | `episodes/comms/YYYY-MM-DD/inbox_index.md` written |
| 2 | Classify each founder message into the seven impact areas (or `none`) with confidence and rationale | Per-thread classification card stored beside redacted raw |
| 3 | Integration assessment: file issue, draft decision-log entry, or mark blocker; never mutate trading state | Linked issue ID or decision-log ID per actionable message |
| 4 | Reply: state what was understood, whether it can be integrated, action or blocker. Drafts only until `MC4`; whitelist-only sends after | Draft saved + sent record (with diff if OWNER edited) |
| 5 | 05:00 daily briefing email: work done / completed / changed / blockers-risks / next steps, from the day's evidence | Briefing payload (JSON + rendered body) archived in `episodes/comms/YYYY-MM-DD/briefing/` |
| 6 | Escalate, never act, on live-trading requests | Escalation entry in daily triage record |
| 7 | Self-evidence on every browser action | Audit folder reproducible from logs |

---

## Supporting components needed

| Component | Notes |
|---|---|
| Gmail / Chrome session handling | Reuse human-logged-in Chrome profile; no stored passwords or OAuth tokens; halt and notify on session expiry, no re-auth attempts |
| Browser-enabled worker | New agent class with mouse/keyboard/DOM control; runs under a separate Windows user/desktop from T6 to avoid focus or input collisions |
| Logging / evidence | Per-day folder `episodes/comms/YYYY-MM-DD/` with redacted inbound, classification cards, draft, sent record, screenshots, briefing payload. Briefing schema versioned. Reuse public-snapshot redaction skill. |
| Scheduling / routines | OS scheduler in local time (DST handled by OS); registry doc lists owner + evidence path + abort condition |
| Approval boundaries | Read-only by default. Drafts until `MC4`. Whitelist-only sends. Out-of-whitelist requires per-message OWNER approval. Whitelist lives in `.private/`, never echoed in logs. |
| Separation from live trading | Hard wall enforced in role prompt, skill pack, and routine ownership. CoS has zero edge to T6 or factory paths. |
| Failure modes | Defined `ABORT` conditions: session expired, classification confidence below threshold, missing screenshot proof, mailbox state changed mid-action, recipient outside whitelist. On abort: skip, record reason, page OWNER via briefing. Never silently retry. |

---

## Docs to create when this phase activates

```text
docs/ops/COMMUNICATIONS_OPERATING_MODEL.md   (primary system-of-record)
docs/ops/BROWSER_WORKER_ARCHITECTURE.md      (generic substrate; useful beyond Gmail)
docs/ops/ROUTINES_AND_SCHEDULES.md           (registry; seed with website snapshot + comms jobs)
processes/inbound-founder-email-triage.md
processes/daily-founder-briefing.md
skills/comms-inbox.md
skills/browser-gmail.md
skills/email-classification.md
checklists/founder-email-triage.md
checklists/daily-briefing-publish.md
prompts/chief-of-staff.md
schemas/briefing-payload.v1.json
decisions/<date>-chief-of-staff-role.md
risks/<date>-comms-misclassification.md
risks/<date>-comms-outbound-leakage.md
risks/<date>-comms-impersonated-inbound.md
```

Edits required to existing docs at activation time:

- `PAPERCLIP_OPERATING_SYSTEM.md`: add core-management row + two roadmap rows.
- `AGENT_SKILL_MATRIX.md`: add `Chief of Staff` row + skill pack.
- `ORG_SELF_DESIGN_MODEL.md`: add comms as a system function; CoS in capability routing as Claude with browser tooling.
- `PAPERCLIP_V2_BOOTSTRAP.md`: add Wave 6 = `Chief of Staff` with trigger conditions.
- `CLAUDE.md` "Required Local Docs": add `COMMUNICATIONS_OPERATING_MODEL.md`.

---

## Risks to carry forward

| # | Risk | Mitigation when activated |
|---|---|---|
| R1 | Impersonation / spoofed inbound used as a control plane | Treat founder mail as signal, not authorization. Trading actions still require existing manifest gates. Optional: signed mail / co-confirmation channel. |
| R2 | Outbound leakage of credentials, account IDs, broker tickets, VPS internals | Outbound through the redaction skill; whitelist of recipients; drafts-only until `MC4`; versioned briefing schema. |
| R3 | Browser session fragility (logout, security challenge) | Hard halt on unexpected DOM state. No re-auth. Page OWNER on first failure. |
| R4 | Boundary erosion (pressure to "just nudge" T6 because the founder asked) | Boundary in role prompt + skill pack + routines registry. Reviewed at every CoS milestone gate. |
| R5 | Briefing drift / hallucination | Briefing must cite source artifacts (issue IDs, process-registry rows, evidence files). Unverifiable claims omitted, not paraphrased. Weekly retro catches drift. |
| R6 | Premature activation steals review attention from foundation work | Activation gated on the trigger conditions above. Do not start until they all hold. |

---

## When we return to this doc

1. Re-verify the trigger conditions still hold (some may have evolved).
2. Confirm the agent name `Chief of Staff` is still right; rename if the org has shifted.
3. Start with `MC0` (write `COMMUNICATIONS_OPERATING_MODEL.md` and `ROUTINES_AND_SCHEDULES.md`).
4. Do NOT skip read-only triage (`MC2`) and go straight to sending. Each milestone is a OWNER approval.
