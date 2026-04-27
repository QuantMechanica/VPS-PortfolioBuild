# QUA-213 — V5 Process Audit Report (2026-04-27)

Author: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Source issue: [QUA-213](/QUA/issues/QUA-213) — Documentation-KM omnibus #2
Scope: `processes/02-12*.md` quick V5 audit (per QUA-213 § Deliverables #2).

## Audit method

For each file, scan for:

1. References to non-V5 roles (anything outside the `paperclip-prompts/` catalogue or the wave-status table in [`AGENT_SKILL_MATRIX.md`](AGENT_SKILL_MATRIX.md)).
2. Dead `/QUAA/agents/<role>` links — V4 namespace; V5 uses `/QUA/agents/<role>` (single-A prefix is V5 Paperclip company, double-A was V4).
3. Dead `[QUAA-NNN](/QUAA/issues/QUAA-NNN)` issue links — V5 uses `QUA-NNN`.
4. V4-era mechanisms or anchors (e.g. `Company/QUANTMECHANICA_ORG_SPEC_v1.2.md`, `5d3aed1c` routine ID, V4 ZT-cohort policy).

Result classification:

- **OK** — no V4 drift, no rewrite needed.
- **needs role-rename** — V5-compatible structure, but role links / QUAA→QUA renames + V4 anchor removal required.
- **needs full V5 rewrite** — fundamental V4 anchoring (V4-only role as primary owner, V4 mechanism as core flow, or 13-agent assumption baked into the doc).

## Per-file status

| # | File | Status | Notes |
|---|------|--------|-------|
| 02 | [`02-zt-recovery.md`](../../processes/02-zt-recovery.md) | **needs full V5 rewrite** | Strategy-Analyst is **primary owner** but Strategy-Analyst is not a V5 role (folded into Research + Quality-Tech). Anchored in QUAA-129 + V4 `ea_registry.json` flow. R-and-D (Wave 5, deferred) is the signoff gate. ZT cohort threshold (5-symbol baseline) may or may not still apply in V5; needs Research + CTO to redefine. |
| 03 | [`03-v-portfolio-deploy.md`](../../processes/03-v-portfolio-deploy.md) | needs role-rename | Roles are V5-compatible: Pipeline-Operator (Wave 1), Quality-Business (Wave 2), CTO (Wave 0), DevOps (Wave 1), Observability-SRE (Wave 3), Controlling (Wave 3). Replace `/QUAA/` links with `/QUA/`; add wave-interim notes for Quality-Business / Obs-SRE / Controlling. |
| 04 | [`04-incident-response.md`](../../processes/04-incident-response.md) | needs role-rename | Roles V5-compatible: Observability-SRE (Wave 3), Pipeline-Operator (Wave 1), DevOps (Wave 1), CEO (Wave 0), Documentation-KM (Wave 0). R-and-D fix-path is Wave 5 — call out CTO interim. Replace `/QUAA/` links. |
| 05 | [`05-dashboard-refresh.md`](../../processes/05-dashboard-refresh.md) | **needs full V5 rewrite** | Strategy-Analyst is primary owner (not V5 role) and the V4 routine ID `5d3aed1c` is the trigger. The whole V4 mechanism (`project_dashboard.html` + `Processes/processes.html` Windows Scheduled Task `QM_ProcessesHtml_Build`) is obsolete; V5 dashboard model is the Hetzner VPS hourly export job (`export_public_snapshot.ps1`) per `docs/ops/WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md`, owned by DevOps + Controlling + Doc-KM. Needs net-new flow doc. |
| 06 | [`06-issue-triage.md`](../../processes/06-issue-triage.md) | needs role-rename | Almost-V5: drops Strategy-Analyst as a V5 destination (research/strategy work routes to Research instead), replaces `/QUAA/` links, adds R-and-D Wave-5 deferral note. Triage flow itself is sound. |
| 07 | [`07-ceo-cto-dialectic.md`](../../processes/07-ceo-cto-dialectic.md) | needs role-rename | Replace Strategy-Analyst (not V5) and Quality-Tech (Wave 2 placeholder) ad-hoc-advisor references with V5 actors. Replace `/QUAA/` + `QUAA-68/70` links. Flow itself is sound. |
| 08 | [`08-daily-operating-rhythm.md`](../../processes/08-daily-operating-rhythm.md) | **needs full V5 rewrite** | Doc opens with "All 13 active agents have a rhythm entry" — fundamentally V4. V5 has 6 agents today; Wave 2/3/4/5 placeholders are not on a heartbeat. Cadence policy (event-driven default per `decisions/2026-04-27_v5_org_proposal.md` § 3) needs to drive the new doc. |
| 09 | [`09-disaster-recovery.md`](../../processes/09-disaster-recovery.md) | needs role-rename | Roles V5-compatible: Observability-SRE (Wave 3), DevOps (Wave 1), Pipeline-Operator (Wave 1), CEO (Wave 0), Documentation-KM (Wave 0), human board. Replace `/QUAA/` links; add DevOps-covers-Obs-SRE interim note. Flow itself current and useful (Drive-sync loss is a live risk per PC1-00). |
| 10 | [`10-agent-rescope.md`](../../processes/10-agent-rescope.md) | needs role-rename | V5-compatible roles + DL-016/017/023 alignment is good. References QUAA-68/70/132/142 — keep as historical example issues but prefix as "V4 examples". Replace `/QUAA/` agent links with `/QUA/`. Note: `Company/Agents/<role>/system_prompt.md` is **V4 path**; V5 prompt path is `paperclip-prompts/<role>.md` and is OWNER-managed, not Doc-KM-edited. Flow itself is sound but the prompt-edit branch needs a small clarification. |
| 11 | [`11-disk-and-sync.md`](../../processes/11-disk-and-sync.md) | needs role-rename | Roles V5-compatible: Observability-SRE (Wave 3), Pipeline-Operator (Wave 1), DevOps (Wave 1), CTO (Wave 0). Replace `/QUAA/` links + QUAA-142/144/145 references. Add DevOps-covers-Obs-SRE interim. Disk-pressure tiers + Drive-sync sub-flow remain useful in V5 (PC1-00 is live). |
| 12 | [`12-board-escalation.md`](../../processes/12-board-escalation.md) | needs role-rename | V5-compatible structure. Class 4 (ZT recovery > 5 days) cross-references `02-zt-recovery.md` which is in full-V5-rewrite scope — class 4 will need synced edits when 02 is rewritten. Replace `/QUAA/` links + QUAA-129/144/145/177/189 references. LiveOps / Pipeline-Operator handoff (class 5) gates on Wave 4 LiveOps hire. |

## Summary counts

| Status | Count | Files |
|--------|-------|-------|
| OK | 0 | — |
| Needs role-rename | 8 | 03, 04, 06, 07, 09, 10, 11, 12 |
| Needs full V5 rewrite | 3 | 02, 05, 08 |
| **Total audited** | **11** | |

## Dispatch

Per QUA-213 § Acceptance:

- **Full-V5-rewrite (3 files):** open one child issue per file off QUA-213.
  - `processes/02-zt-recovery.md` — V5 ZT/no-trade recovery flow (re-scope owner; CTO + Research + Quality-Tech defined; cohort threshold revisited).
  - `processes/05-dashboard-refresh.md` — V5 dashboard cadence (Hetzner hourly export, DevOps + Controlling + Doc-KM ownership).
  - `processes/08-daily-operating-rhythm.md` — V5 6-agent operating rhythm (event-driven default, wave-conditional cadences).
- **Role-rename (8 files):** open one consolidated child issue (single Doc-KM cleanup pass) covering `/QUAA/` → `/QUA/` link refresh + non-V5 role replacements + Wave-interim annotations. Tracked as a single child rather than eight separate issues to avoid over-fragmentation.
- **01-ea-lifecycle.md V5 refresh** — handled in QUA-213 directly (label-collision fix is the keystone).
- **AGENT_SKILL_MATRIX.md + ORG_SELF_DESIGN_MODEL.md V5 refresh** — handled in QUA-213 directly.

## Learning-candidate observation

Per QUA-213 § Coordination, this audit surfaces a candidate learning to file as a separate `learning-candidate` issue for CEO + Board triage:

> **Lifecycle vs pipeline phase-label collision was the root of confusion at Phase 1 close.** Pipeline phases (G0..P10) and lifecycle phases (G0..P10) shared the same symbol space. Even with the in-doc warning, several Phase 1 conversations had to disambiguate "are you talking about lifecycle G3 backtest or pipeline P3 sweep?" The fix (lifecycle → L0..L10; pipeline keeps G0..P10) is cheap once spotted but cost cycles before it was. **General learning:** when two parallel taxonomies use the same symbol space, even a warning paragraph is not enough — rename one of them so the symbol disambiguates the axis.

This will be filed as a separate issue on Doc-KM's next heartbeat.

## References

- Source issue: [QUA-213](/QUA/issues/QUA-213)
- Refreshed lifecycle: [`processes/01-ea-lifecycle.md`](../../processes/01-ea-lifecycle.md)
- Refreshed skill matrix: [`docs/ops/AGENT_SKILL_MATRIX.md`](AGENT_SKILL_MATRIX.md)
- Refreshed org self-design: [`docs/ops/ORG_SELF_DESIGN_MODEL.md`](ORG_SELF_DESIGN_MODEL.md)
- V5 hire plan: [`decisions/2026-04-27_v5_org_proposal.md`](../../decisions/2026-04-27_v5_org_proposal.md)
- V5 BASIS prompts: [`paperclip-prompts/`](../../paperclip-prompts/)
