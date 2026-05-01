---
title: Gmail Link Intake (`info@quantmechanica.com`)
owner: Documentation-KM
last-updated: 2026-05-01
authored-under: QUA-567 (Documentation-KM)
parent-directive: DL-043 Phase C — Gmail Intake feasibility (deferred until volume justifies)
companion-template: docs/ops/CEO_LINK_BRIEF_TEMPLATE.md
status: design / Phase 1 active (manual bridge); Phase 2 spec only (not hired)
---

# 19 — Gmail Link Intake (`info@quantmechanica.com`)

How links sent to `info@quantmechanica.com` are extracted, summarized, deduplicated, and presented to [CEO](/QUA/agents/ceo) for delegation, **without** giving any agent unattended write authority over the mailbox.

> **Binding source:** [DL-043](../decisions/REGISTRY.md) Phase C + [QUA-567](/QUA/issues/QUA-567) (this issue). Companion design context: [`docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md`](../docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md) § "Gmail Intake". Distinct from the Wave-6 Chief-of-Staff founder-comms scope frozen in [`docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`](../docs/ops/PHASE_FINAL_FOUNDER_COMMS.md): that role is broader (founder-mail classification, daily 05:00 briefing, browser-based reply drafting); this process is the narrow link-triage strip and stays orthogonal.

> **Headline recommendation (this design):** **Phase 1 — manual, on-demand bridge using the OWNER's existing Chrome+Gmail session and the Claude Chrome extension. Do not hire a Gmail Intake agent.** Hold the Phase 2 (read-only Gmail API + label-polling + heartbeat agent) spec ready but unimplemented; promote only when a measurable volume trigger fires (see § Volume trigger for promotion). This matches DL-043's volume-gated Phase C deferral.

## Scope

This process governs:

- mailbox access methods for `info@quantmechanica.com` (today: human Chrome session; tomorrow: read-only Gmail API)
- security boundary between mailbox content and the Paperclip company surface
- redaction policy applied before any link-brief enters Paperclip / Git / Notion
- the CEO link-brief output format (canonical template at [`docs/ops/CEO_LINK_BRIEF_TEMPLATE.md`](../docs/ops/CEO_LINK_BRIEF_TEMPLATE.md))
- dedupe rules (message id + URL canonicalization)
- promotion criteria from manual bridge → on-demand agent → scheduled agent

Out of scope:

- broader founder-mail comms, classification across all impact areas, daily briefing — those are Chief-of-Staff Wave-6 scope (`PHASE_FINAL_FOUNDER_COMMS.md`)
- any send / reply / archive / delete authority — explicitly forbidden at every phase below
- T6 / live-trading email handling — escalate to CEO, never act
- any direct execution from a link (downloading PDFs, running scrapers) — link-briefs are *handed* to CEO, who delegates downstream owners

## Trigger

Phase 1 (active today):

- OWNER notices a link in `info@quantmechanica.com` that has potential research / pipeline / framework / governance value.
- OWNER is in front of the open Gmail Chrome session and chooses to push it through the bridge (it is *opt-in per email*, not a sweep of the inbox).

Phase 2 (deferred):

- Recurring volume meets the promotion trigger below — at that point CEO opens the hire issue per DL-043 Phase C.

## Actors

| Step | Phase 1 owner | Phase 2 owner (deferred) | Notes |
|------|---------------|--------------------------|-------|
| Notice + open the email | OWNER | OWNER labels the thread `QM/Paperclip-Inbox` | Phase 2 still needs OWNER label to opt-in; no auto-sweep of all mail |
| Extract link + short summary | OWNER, with Claude Chrome extension | Gmail Intake agent (read-only Gmail API, label-only polling) | Extraction never opens any link in the agent's browser context |
| Apply redaction policy | OWNER (review pass) | Gmail Intake agent (auto-pass) + OWNER (sample audit) | See § Redaction policy |
| Write CEO brief | OWNER (paste into Paperclip issue body or `episodes/comms/YYYY-MM-DD/` file) | Gmail Intake agent (post a comment on a CEO triage issue) | Canonical format: [`docs/ops/CEO_LINK_BRIEF_TEMPLATE.md`](../docs/ops/CEO_LINK_BRIEF_TEMPLATE.md) |
| Decide delegation | [CEO](/QUA/agents/ceo) | CEO | Per [`processes/06-issue-triage.md`](06-issue-triage.md) — Research / CTO / DevOps / Documentation-KM / no-action |
| File downstream issue | CEO | CEO | The Gmail Intake agent never opens issues for anyone other than CEO; CEO does the routing |

The Gmail Intake agent (Phase 2) **never** appears as the assignee of a research / build / live issue — it only ever produces the brief that CEO triages.

## Mailbox access — three options compared

| Method | Surface | Auth | Read | Write (send/archive/delete) | Audit trail | Phase |
|---|---|---|---|---|---|---|
| **A. Human Chrome session + Claude extension** (recommended Phase 1) | Browser tab open under OWNER's logged-in Google session | OWNER's existing Google login (no separate credential issued to any agent) | OWNER eyes-on; extension assists with extraction | None — extension cannot send mail; OWNER never grants reply/archive/delete to any agent | Each link-brief filed in Paperclip / Git is the audit trail; mailbox itself is unchanged | Phase 1 |
| **B. Read-only Gmail API (OAuth scope `gmail.readonly` + `gmail.labels`)** with label-only polling on `QM/Paperclip-Inbox` | Headless poll from a Paperclip routine | Dedicated Google OAuth credential, scope = read + label-add only; **no** `gmail.send`, **no** `gmail.modify`, **no** `gmail.compose` | Whitelist of labels (default: `QM/Paperclip-Inbox`); never reads full inbox | Adds an internal `QM/Paperclip-Processed` label after producing a brief; nothing else | API-side Google audit log + Paperclip routine log + Git-committed brief | Phase 2 (deferred) |
| **C. Full Gmail API + send authority** (e.g. for auto-replies) | Same as B but with `gmail.send` and `gmail.modify` | Same OAuth credential, scope expanded | Same | Send replies, move to folders, archive, delete | Same | **Forbidden by this design.** Any need for auto-reply belongs to Wave-6 Chief of Staff (separate role, separate frozen scope), not Gmail Intake. |

**Why A is the recommended Phase-1 surface:**

- Zero new credentials, zero new attack surface. The mailbox is already authenticated under OWNER; no agent gets a Google token.
- OWNER is the human-in-the-loop on every email, so adversarial-link risk (phishing, payload URLs, oversized attachments) is gated by OWNER attention before any agent sees the URL.
- Volume today is anecdotal and per-link, not a queue. A heartbeat agent that polls a near-empty mailbox burns tokens for no throughput — DL-040 sequential-throttle principle.
- Reverses cleanly: if Phase 2 is later approved, the Phase-1 brief format is already canonical, so the agent's first job is just to populate the same template.

**Why B is the only acceptable Phase-2 surface:**

- Read-only OAuth scope keeps the company unable to send mail under the QuantMechanica identity. Public-trust posture matches the "no broad email sending authority" boundary in [QUA-567](/QUA/issues/QUA-567).
- Label-only polling (`QM/Paperclip-Inbox`) keeps the agent out of the rest of the mailbox (founder personal mail, unrelated business mail). OWNER continues to opt-in per thread by adding the label.
- The single write op the agent needs (`QM/Paperclip-Processed` label) is dedupe scaffolding, not communication.

**Why C is forbidden at every phase of *this* process:**

- Send / reply / archive / delete authority over `info@` is a brand-and-legal surface that requires its own role, its own DL, and its own approval gate. Putting it on the Gmail Intake agent would conflate link-triage with founder-comms and re-create the conflated scope DL-043 split into two phases.
- Wave-6 Chief of Staff (frozen scope, `PHASE_FINAL_FOUNDER_COMMS.md`) is the role that earns reply authority — and only after explicit promotion gates (`MC4` whitelist) defined in that doc.

## Security boundary

The mailbox-to-Paperclip transition is the security boundary. Everything below is enforced at the boundary, not relied-upon inside the company surface.

1. **No agent holds a Gmail credential in Phase 1.** Browser session belongs to OWNER. Any agent that needs to act on a link does so via a Paperclip issue created by CEO from the brief — the agent never touches the mailbox.
2. **Phase-2 OAuth scope is read + label-add, never `send` / `modify` / `compose` / `delete`.** The credential is provisioned with these scopes refused at the consent screen; if Google later expands the scope set, the credential is **rotated**, not the consent re-granted.
3. **Label-gated opt-in.** Phase 2 polling reads only threads with the `QM/Paperclip-Inbox` label. Threads without that label are never fetched, even if their subject matches a heuristic. OWNER (or CEO triage in OWNER's absence) is the only entity that adds the label.
4. **Allowed-domain list for the *brief* (not for the *email*).** The CEO brief includes the link only if its domain is on the allow-list (e.g. `youtube.com`, `arxiv.org`, `github.com`, known broker / vendor / publisher domains). Off-list domains pass to CEO as `domain not on allow-list — review-before-open` flag. Allow-list lives in `processes/19-gmail-link-intake.allowed-domains.txt` (added when Phase 2 promoted; until then, OWNER's eye is the allow-list).
5. **No attachment ingestion.** Phase 1 and Phase 2 both ignore email attachments — link-only. If OWNER wants a PDF processed, that is Research's PDF intake path (separate process), not this one.
6. **No execution from a link in either phase.** The brief contains the URL, the short summary, and the "why-OWNER-flagged-it" line. Downloading / scraping / opening the page is CEO's downstream delegation, in a separate Paperclip issue with its own owner and policy.
7. **Brief content is the only thing that crosses into Git / Notion.** Raw email body, sender header, internal Gmail message-id — none of those land in Git. Only the redacted brief does.
8. **OWNER stop-bit.** OWNER can disable Phase 2 polling by removing the OAuth credential at the Google account level, with no agent-side coordination needed. The label `QM/Paperclip-Inbox` becomes inert; no brief is produced.

## Redaction policy

Applied at the boundary — before the brief enters any Paperclip / Git surface.

| Field | Phase 1 (OWNER does it) | Phase 2 (agent auto-redacts; OWNER samples) | Why |
|---|---|---|---|
| Sender email address | Paraphrased to "from a YouTube viewer" / "from a vendor" / "from OWNER's contact at X" — exact address dropped unless it's a public corporate identity | Same; agent uses sender-domain → category map (`gmail.com` → `viewer`, `*.broker-domain.com` → `vendor`) | Mailbox PII stays out of the public-facing repo; protects third parties who emailed expecting privacy |
| Personal names | Replaced with role label ("a viewer", "a Davey-pattern reader") unless the person is a public figure already named in a public-data source | Same | Same |
| Subject line | Paraphrased to one neutral sentence; never quoted verbatim | Same | Subject lines often contain names / context |
| Free-form email body | Not stored; only the OWNER-provided "why this link" line is recorded | Not stored; only the agent-extracted "why this link" line (from sender's first sentence around the link) — and only if it passes a length cap (≤ 200 chars) | Free-form bodies are PII and copyright risk |
| URL | Stored verbatim, **after** canonicalization (strip `utm_*`, `fbclid`, session tokens, redirect wrappers like `lnkd.in` resolved to final URL) | Same | Tracking params leak the recipient identity; canonical form deduplicates the URL across multiple senders |
| Attachments | Dropped, even if the brief mentions "PDF attached" | Dropped | Attachment ingestion is out of scope (see Security § 5) |
| Message-id (internal Gmail) | Not stored in Git | Stored in the agent's local dedupe DB (off-Git, off-Notion) for "have-we-seen-this-thread?" — never published | Dedupe scaffolding, not content |

If the redaction policy can't decide ("is this person public?"), the default is **redact** and ask CEO if the named version is needed.

## Output format — CEO link brief

Canonical template lives at [`docs/ops/CEO_LINK_BRIEF_TEMPLATE.md`](../docs/ops/CEO_LINK_BRIEF_TEMPLATE.md). The brief is the single payload that crosses from mailbox to Paperclip; CEO either delegates it (creates a Paperclip issue with a downstream owner per `processes/06-issue-triage.md`) or marks it `no-action`.

Phase 1: OWNER pastes the rendered brief into either (a) a comment on an existing intake-tracking Paperclip issue, or (b) directly into a new CEO-assigned Paperclip issue. CEO triages on the next heartbeat.

Phase 2: agent posts the rendered brief as a comment on a single rolling intake-tracking Paperclip issue (e.g. "Gmail Intake — open briefs"). CEO triages on heartbeat and promotes accepted briefs into their own issues.

## Dedupe rules

1. **URL key** = canonical URL after stripping tracking params + resolving known redirect wrappers (`lnkd.in`, `bit.ly`, `t.co`, `youtu.be` short → long form, etc.).
2. **Thread key** = Gmail thread id (Phase 2) or OWNER-supplied "is this a follow-up to <prior brief>?" (Phase 1).
3. A new brief is suppressed if **(URL key)** already has an open or recently-closed brief (last 30 days) **and** the new context line adds nothing materially new.
4. If a brief is suppressed, the suppression itself is recorded as a one-liner under the original brief's thread, so CEO sees "+1 sender raised the same link".

## Promotion criteria — when to hire a Gmail Intake agent

Per DL-043 Phase C: **volume-gated, not time-gated.** Promote when **all** of:

- **A.** ≥ 5 manual briefs per week for two consecutive weeks (sustained, not a spike).
- **B.** ≥ 50% of those briefs converted to a real downstream Paperclip issue (i.e. signal-to-noise is high — links are useful, not just spam).
- **C.** OWNER reports the manual bridge as a friction point in a weekly review (subjective check: is the human-in-the-loop the bottleneck, or is it the volume that triggers automation?).

When promoted:

1. CEO opens the hire issue under DL-043 Phase C, model tier = **lightweight** (per company-operating-system § Hiring Gate evidence row).
2. CTO authors `paperclip-prompts/gmail-intake.md` (BASIS source) per DL-027 two-layer hire model.
3. DevOps provisions the read-only Gmail OAuth credential (scope `gmail.readonly` + `gmail.labels`, see § Mailbox access option B).
4. Documentation-KM appends a "Recently added" entry referencing the new agent and updates this file's `status:` field.
5. First retirement-evidence checkpoint at +14 days: did the agent actually reduce OWNER's hands-on triage time? If not, retire and revert to Phase 1.

If promotion criteria are **not** met after 90 days, this process file's `status:` stays "Phase 2 spec only" and the design rests as documented evidence — no further work.

## Recommendation (this design's deliverable)

**No agent today. Do not hire.** Phase 1 (manual, on-demand bridge) is the right surface for current volume. Phase 2 spec (read-only Gmail API + label-polling + lightweight agent) is documented above and ready to implement when the promotion criteria fire — not before. This matches DL-043 Phase C's volume-gating exactly.

## SLA

- **OWNER → CEO triage of a brief:** same-day during active hours (briefs are anecdotal volume, no inbox-zero pressure).
- **CEO triage → downstream issue (or `no-action`):** within 1 CEO heartbeat after the brief lands.
- **Brief-format consistency:** every brief follows the canonical template (template drift is a Documentation-KM ticket, not a CEO triage decision).

## Exits

- **Success:** Brief crosses into Paperclip, CEO either delegates or marks `no-action`, downstream agent (if any) executes its own scoped issue. Brief itself does not retain mailbox PII.
- **Escalation:** Link is from a live-trading topic (broker change, account class, capital exposure) → CEO escalates per `processes/12-board-escalation.md`, never auto-actioned.
- **Kill:** Promotion to Phase 2 declined at the +14-day evidence checkpoint, **or** weekly volume drops below the promotion floor for 30 days → revert to Phase 1, document the kill in this file's `status:` field.

## References

- [QUA-567](/QUA/issues/QUA-567) — this design issue
- [DL-043](../decisions/REGISTRY.md) — Reboot Plan GO (Phased), Phase C deferral
- [`docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md`](../docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md) § "Gmail Intake" — original Phase 1 / Phase 2 framing
- [`docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`](../docs/ops/PHASE_FINAL_FOUNDER_COMMS.md) — Wave-6 Chief-of-Staff founder-comms scope (distinct from this process; cross-reference for boundary clarity)
- [`docs/ops/CEO_LINK_BRIEF_TEMPLATE.md`](../docs/ops/CEO_LINK_BRIEF_TEMPLATE.md) — companion template
- [`processes/06-issue-triage.md`](06-issue-triage.md) — what CEO does with the brief once it lands
- [`processes/18-company-operating-system.md`](18-company-operating-system.md) § Hiring Gate — promotion-time hiring fields
