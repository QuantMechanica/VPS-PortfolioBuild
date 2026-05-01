---
title: CEO Link Brief — Template
owner: Documentation-KM
last-updated: 2026-05-01
authored-under: QUA-567 (Documentation-KM)
parent-process: processes/19-gmail-link-intake.md
purpose: copy-paste payload that crosses the mailbox -> Paperclip boundary for `info@quantmechanica.com` link triage
phase: Phase 1 (manual; OWNER fills in via Claude Chrome extension) — same template Phase 2 agent will populate if promoted
---

# CEO Link Brief — Template

This is the canonical payload for link triage from `info@quantmechanica.com`. See [`processes/19-gmail-link-intake.md`](../../processes/19-gmail-link-intake.md) for the full design (security boundary, redaction policy, dedupe rules, promotion criteria).

> **Audience:** [CEO](/QUA/agents/ceo). Output of this brief is one of: delegate to Research / CTO / DevOps / Documentation-KM (per [`processes/06-issue-triage.md`](../../processes/06-issue-triage.md)), escalate to OWNER (per `12-board-escalation.md`), or mark `no-action`.
>
> **Boundary reminder:** the brief itself is the only content that crosses into Paperclip / Git / Notion. Raw email body, sender header, and Gmail message-id stay on the mailbox side. Apply the redaction policy in `19-gmail-link-intake.md` § "Redaction policy" before pasting.

## Template (copy below this line)

```markdown
# Link brief — <YYYY-MM-DD HH:MM local> — <one-sentence neutral subject>

**Phase:** Phase 1 (manual bridge) | Phase 2 (Gmail Intake agent)
**Source:** info@quantmechanica.com — <sender category, e.g. "viewer", "vendor (broker)", "OWNER's contact at <public org>", "unknown">
**Triage owner:** CEO

## Link

- **URL (canonical):** <https-url after stripping utm_* / fbclid / resolving lnkd.in-style redirects>
- **Domain on allow-list?** yes / no — review-before-open
- **Attachment present in original mail?** yes (dropped per redaction policy) / no

## Why this link (one short paragraph)

<2-4 sentences. Phase 1: OWNER's "why I forwarded this". Phase 2: agent's extracted ≤200-char context line from the message, with names redacted to roles. State the *claim* the link makes or the *question* it raises — not the email's framing.>

## Suggested triage

- **Impact area:** strategy-research / framework-implementation / pipeline-operations / live-ops (escalate) / governance-process / brand-comms / no-action
- **Suggested owner if delegated:** Research / CTO / Development / DevOps / Pipeline-Operator / Documentation-KM / Quality-Tech / Quality-Business / OWNER
- **Suggested project:** V5 Strategy Research / V5 Framework Implementation / V5 Pipeline Operations / T6 Live Operations (OWNER-gated)
- **Why this owner:** <one sentence — anchor in the relevant process doc; e.g. "fits 13-strategy-research.md DL-029 source-survey workflow">

## Dedupe

- **Prior brief on the same URL?** none / link to prior brief id + date
- **Suppressed +1 senders since prior brief?** N (count only — no sender names)

## Risk flags

- [ ] live-trading / T6 topic — if checked, escalate to CEO + OWNER per `12-board-escalation.md`, do not delegate to a non-OWNER owner
- [ ] off-allow-list domain — review before opening; do not auto-fetch
- [ ] mentions OWNER's brokerage / account / capital — escalate, never auto-action
- [ ] mentions a competitor / journalist / external public party — Documentation-KM brand-review pass before any public response

## CEO decision (filled by CEO at triage)

- **Decision:** delegate / no-action / escalate to OWNER / hold for next batch
- **Downstream issue:** <QUA-NNN if delegated, else "n/a">
- **Decision timestamp:** <YYYY-MM-DD HH:MM>
- **Decision note (one line):** <e.g. "fits open SRC02 source backlog — assigned to Research; will land as child of QUA-XXX">
```

## Worked example (illustrative — not a real link)

```markdown
# Link brief — 2026-05-01 09:14 local — viewer-pointed YouTube video on a Davey-pattern variant

**Phase:** Phase 1 (manual bridge)
**Source:** info@quantmechanica.com — viewer
**Triage owner:** CEO

## Link

- **URL (canonical):** https://www.youtube.com/watch?v=EXAMPLEID
- **Domain on allow-list?** yes
- **Attachment present in original mail?** no

## Why this link

A viewer pointed at a YouTube video that claims a 3-pattern variant of the Davey "5-pattern" momentum setup outperforms the original on EURUSD H1 over a 10-year window. The viewer asks whether QM has tested it. The video looks like a candidate research source — channel publishes regular backtest content — but the claim itself needs G0 evaluation against existing SRC02 cards.

## Suggested triage

- **Impact area:** strategy-research
- **Suggested owner if delegated:** Research (deferred per DL-044) → hold or queue post-P7-resume
- **Suggested project:** V5 Strategy Research
- **Why this owner:** new candidate source for DL-029 source-survey workflow; subject to DL-044 Research pause until first V5 EA reaches Phase 7

## Dedupe

- **Prior brief on the same URL?** none
- **Suppressed +1 senders since prior brief?** 0

## Risk flags

- [ ] live-trading / T6 topic
- [ ] off-allow-list domain
- [ ] mentions OWNER's brokerage / account / capital
- [ ] mentions a competitor / journalist / external public party

## CEO decision (filled by CEO at triage)

- **Decision:** hold for next batch (DL-044 pause; queue for post-P7 resume)
- **Downstream issue:** n/a (parked in research backlog)
- **Decision timestamp:** 2026-05-01 09:30
- **Decision note (one line):** parked behind P7 milestone tracker per DL-044; revisit when first V5 EA reaches P7
```

## Notes for OWNER (Phase 1)

- The Claude Chrome extension can pull the URL + the surrounding sentence; you supply the "why this link" paragraph (it is the cheapest, highest-signal step).
- If you are unsure whether to redact a sender's name or org — redact. CEO can ask for the unredacted detail in a comment if it matters for triage.
- If multiple links land in one email, file one brief per link; they triage independently and dedupe independently.
- If the email's actual *content* (not just a referenced link) is what's interesting (e.g. a long-form personal note from a known counterparty), that is **not a link brief** — that's founder-comms, escalate to CEO and let `PHASE_FINAL_FOUNDER_COMMS.md` Wave-6 path handle it (or, for now, OWNER replies directly).

## Notes for the Phase-2 Gmail Intake agent (when promoted)

- You operate read-only on the `QM/Paperclip-Inbox` label only. You do not read other labels, you do not send mail, you do not archive or delete.
- You auto-redact per the redaction policy table in `processes/19-gmail-link-intake.md`. If a redaction call is ambiguous, default to redacting and flag the ambiguity in the brief's "Why this link" closing line.
- You post one brief per link as a comment on the rolling intake-tracking Paperclip issue (CEO opens this issue at your hire time). You never assign issues to anyone other than CEO.
- You add the `QM/Paperclip-Processed` Gmail label after producing a brief; that is the only mailbox-side write op you perform.
- You do not open the URL in any agent-side browser. The brief contains the URL as text only.
- If the message-id has been seen, dedupe per `processes/19-gmail-link-intake.md` § "Dedupe rules" and post a one-line "+1 sender" entry on the existing brief instead of a new brief.
