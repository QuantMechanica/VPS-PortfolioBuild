---
name: DL-025 — T6 Deploy Boundary Refinement
description: T6 hard rule narrowed — deploy of approved EAs/setfiles/templates/profiles under manifest is in scope; AutoTrading toggle stays manual OWNER
type: decision-log
---

# DL-025 — T6 Deploy Boundary Refinement

Date: 2026-04-27
Source directive: OWNER directive 2026-04-27 ~12:30 local (relayed via Board Advisor)
Recording issue: [QUA-209](/QUA/issues/QUA-209) (parent — boundary refinement) / [QUA-226](/QUA/issues/QUA-226) (this entry's authoring task)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Supersedes: none. Additive to the existing T6 hard rule in `CLAUDE.md` § Hard Boundaries (the rule is narrowed in scope, not replaced).
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This file is a faithful transcription of OWNER's T6 boundary refinement as captured in QUA-209 and applied to `CLAUDE.md` § Hard Boundaries (line 40). Doc-KM is recording, not interpreting. The authoritative narrative remains in QUA-209 and the live `CLAUDE.md` line; if either diverges from this file, the live source wins until a successor DL-NNN entry is filed.
>
> **Numbering note.** The original child issue (QUA-226) instructed "take next free slot = DL-024". DL-024 was filed earlier on 2026-04-27 for CEO Scheduled Heartbeat Enablement (recording issue QUA-214) — Doc-KM applied the registry's `max(existing) + 1` convention and took DL-025 instead. No content change; only the slot number differs from the issue text.

## Decision

OWNER refines the T6 hard rule. Verbatim summary from QUA-209:

1. Agents CAN deploy approved EA binaries (`.ex5`) + set files (`.set`) + templates / profiles to T6 paths **under an OWNER-approved deploy manifest**.
2. Agents CAN attach EA to chart with **AutoTrading OFF** for verification (manifest verification contract per `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md`).
3. AutoTrading toggle stays **manual OWNER**. Agents must verify OFF before AND after T6 placement; abort if ON without OWNER action.
4. Agents do NOT touch T6 broker credentials, account login, or live-account configuration.
5. Agents do NOT run Strategy Tester or optimization on T6.

Read-only inspection of T6 remains permitted at any time (unchanged).

## Why

OWNER directive 2026-04-27 ~12:30 local. Operational reason: LiveOps (Wave 4) cannot yet ship end-to-end. The previous `read-only inspection only` rule blocked all pre-deploy work — including manifest-driven file copies and chart-attach verification — that needs to land before LiveOps comes online. Refining the boundary lets DevOps cover the pre-LiveOps interim without weakening the AutoTrading / live-capital guard, which remains OWNER-manual.

## What changed

`CLAUDE.md` § Hard Boundaries (line 40, replacing the prior `do NOT modify T6_Live except read-only inspection` rule):

> - Do NOT modify `T6_Live` except: (a) read-only inspection at any time, (b) deploy approved EA binaries (`.ex5`) + set files (`.set`) + templates / profiles to T6 file paths under an OWNER-approved deploy manifest, (c) attach EA to chart with **AutoTrading OFF** for verification. Per OWNER 2026-04-27: deploy of ready EAs is in scope; AutoTrading toggle stays manual OWNER.

Lines 41-44 (AutoTrading-OFF verification, no broker creds, no live-config touches, no Strategy Tester / optimization) are unchanged and remain in force as the boundary's load-bearing guards.

## Implications

- **LiveOps role (Wave 4, when hired)** can ship EA placement work end-to-end through the manifest verification contract — *except* the AutoTrading toggle, which stays manual OWNER.
- **DevOps interim** covers pre-LiveOps T6 file-deploy ownership; CEO has updated `processes/03-v-portfolio-deploy.md` to reflect this.
- **Pipeline-Operator** factory-isolation rule (T1-T5 only, no T6 write authority) is unchanged.
- **CTO / Quality-Tech** (when hired) inherit the same refined boundary — no special case.
- **AutoTrading-OFF verification, no broker creds, no live-config, no Strategy Tester on T6** are still hard rules; this DL only narrows the scope of "do not modify", not the surrounding live-capital guards.

## Boundary reminder

Manifest discipline + AutoTrading-OFF verification (before AND after) + screenshot evidence are non-negotiable. Every T6 file-deploy traces to an OWNER-approved manifest. AutoTrading toggle stays manual OWNER and must be verified OFF on both ends of any agent placement; if it flips ON without OWNER action, agents abort and surface immediately. T6 broker creds / account login / live-account config remain OFF LIMITS without exception.

## Cross-links

- **Recording task (parent):** [QUA-209](/QUA/issues/QUA-209) — T6 boundary refinement codifying OWNER 2026-04-27 directive.
- **Authoring task (this entry):** [QUA-226](/QUA/issues/QUA-226) — Doc-KM child of QUA-209.
- **Edited file:** `CLAUDE.md` § Hard Boundaries (line 40, Board Advisor edit landed before this DL was filed).
- **Downstream process update:** [`processes/03-v-portfolio-deploy.md`](../processes/03-v-portfolio-deploy.md) — DevOps interim T6 file-deploy ownership (CEO).
- **Downstream runbook update:** [`docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md`](../docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md) — § "Pre-deploy verification dry-run" reframed from prior "demo-only dry run" wording (DXZ is live-only).
- **Independent context (CEO autonomy):** DL-017 (hire-approval waiver, hires-only) and [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) (CEO autonomy waiver, broadened scope). DL-025 is independent of those — this is an OWNER directive on V5 hard rules, not a CEO unilateral decision.
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-025 row.

— OWNER directive via Board Advisor, 2026-04-27 ~12:30 local. Recorded by Documentation-KM 2026-04-27.
