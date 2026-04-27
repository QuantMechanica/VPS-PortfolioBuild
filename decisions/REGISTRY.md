# Decisions Registry (DL Index)

Lightweight index of project-level decisions. Each row maps a `DL-NNN` id to its canonical document and originating issue.

Conventions:
- `decisions/DL-NNN_<topic>.md` — numbered ADRs.
- `decisions/YYYY-MM-DD_<topic>.md` — date-prefixed decision docs (also assigned a DL-NNN in the index).
- A DL-NNN may be **External** if it was allocated in conversation / lessons-learned / scratch before a canonical file existed; once materialized, the row is updated with the file path.
- New DL-NNN: take `max(existing) + 1`. Skipped numbers are intentional gaps; do not reuse.

| DL | Date | Title | Canonical document | Originating issue / source |
|---|---|---|---|---|
| DL-001 | 2026-04-27 | CTO Prompt Hard Rules Checklist Adaptation | [`DL-001_cto_prompt_hard_rules_checklist.md`](./DL-001_cto_prompt_hard_rules_checklist.md) | QUA-147 |
| DL-002 | 2026-04-27 | Pipeline Infrastructure Audit | [`DL-002_pipeline_infra_audit.md`](./DL-002_pipeline_infra_audit.md) | QUA-146 |
| DL-003 | 2026-04-27 | V5 Framework Review | [`DL-003_v5_framework_review.md`](./DL-003_v5_framework_review.md) | QUA-149 |
| DL-010 | 2026-04-26 | Auto-CEO / wizard tutorial agents — repurpose, do not delete | External (cited in [`lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md`](../lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md)) | QUA-8 |
| DL-011 | 2026-04-26 | Backlog-driven org chart | External (cited in [`lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md`](../lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md)) | Wave-0 bootstrap |
| DL-012 | 2026-04-26 | Capability routing matrix | External (cited in [`lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md`](../lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md)) | Wave-0 bootstrap |
| DL-013 | 2026-04-26 | Wave-1 hire proposal | External (cited in [`lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md`](../lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md)) | Wave-0 bootstrap |
| DL-014 | 2026-04-26 | Two-layer hire pattern (Paperclip system prompt + V5 first-issue brief) | External (cited in [`lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md`](../lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md)) | Wave-0 bootstrap |
| DL-016 | 2026-04-27 | CTO vacancy → CEO absorbs infra/code sign-off | External (cited in QUA-65/QUA-66 sign-off scratch) | CTO vacancy |
| DL-017 | 2026-04-27 | CEO hire-approval waiver (`requireBoardApprovalForNewAgents=false`) | External (Paperclip company config + QUA-188 narrative reference) | Phase 1 closeout |
| DL-022 | 2026-04-27 | DWX `spec_ok` criterion + import mitigation pattern | External (cited in [`lessons-learned/2026-04-27_dwx_recovery_and_spec_fix.md`](../lessons-learned/2026-04-27_dwx_recovery_and_spec_fix.md)) | QUA-65..70 / DEVOPS-006..010 |
| DL-023 | 2026-04-27 | CEO Autonomy Waiver, broadened scope (v2) — additive to DL-017 | [`2026-04-27_ceo_autonomy_waiver_v2.md`](./2026-04-27_ceo_autonomy_waiver_v2.md) | [QUA-188](https://paperclip.local/QUA/issues/QUA-188) (directive) / [QUA-192](https://paperclip.local/QUA/issues/QUA-192) (recording) |
| DL-024 | 2026-04-27 | CEO scheduled heartbeat enablement (3600s) — under DL-023 authority | [`2026-04-27_ceo_scheduled_heartbeat.md`](./2026-04-27_ceo_scheduled_heartbeat.md) | [QUA-210](https://paperclip.local/QUA/issues/QUA-210) (change) / [QUA-214](https://paperclip.local/QUA/issues/QUA-214) (recording) |
| DL-025 | 2026-04-27 | T6 Deploy Boundary Refinement — deploy of approved EAs/setfiles/templates/profiles under manifest in scope; AutoTrading toggle stays manual OWNER | [`DL-025_t6_deploy_boundary_refinement.md`](./DL-025_t6_deploy_boundary_refinement.md) | [QUA-209](https://paperclip.local/QUA/issues/QUA-209) (parent) / [QUA-226](https://paperclip.local/QUA/issues/QUA-226) (recording) |
| DL-026 | 2026-04-27 | Commit-Hash-In-Close-Out Rule for Coding-Agent `done` Deliverables | [`2026-04-27_commit_hash_in_close_out_rule.md`](./2026-04-27_commit_hash_in_close_out_rule.md) | [QUA-234](/QUA/issues/QUA-234) (ratification) / [QUA-238](/QUA/issues/QUA-238) (recording) |
| DL-027 | 2026-04-27 | BASIS→active diff propagation rule (Wave 1 catch-up included) — every BASIS revision names a propagation path (`hot_reload` / `re_hire` / `config_patch` / `reference_only`); Doc-KM regenerates the diff side-artifact post-revision | [`DL-027_basis_active_diff_propagation_rule.md`](./DL-027_basis_active_diff_propagation_rule.md) | [QUA-235](/QUA/issues/QUA-235) (originating learning-candidate) / [QUA-237](/QUA/issues/QUA-237) (recording) |

## Cross-links

- **DL-017 ↔ DL-023.** DL-023 is additive to DL-017; DL-017 (hires) is now the first item in the DL-023 broadened-authority list. Reverse link from DL-017 lives only in this registry — DL-017 itself is not file-materialized; if/when a canonical doc is filed, that file should backlink to DL-023.
- **QUA-188 ↔ DL-023.** Forward link: QUA-188 → DL-023 (recorded via QUA-192). Reverse link: [`2026-04-27_ceo_autonomy_waiver_v2.md`](./2026-04-27_ceo_autonomy_waiver_v2.md) cites QUA-188 as its source directive.
- **DL-023 ↔ DL-024.** DL-024 is the first concrete operational change recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → heartbeat cadence). DL-024 cites DL-023 as its authority basis.
- **QUA-210 ↔ DL-024.** Forward link: QUA-210 → DL-024 (recorded via QUA-214). Reverse link: [`2026-04-27_ceo_scheduled_heartbeat.md`](./2026-04-27_ceo_scheduled_heartbeat.md) cites QUA-210 as the source change.
- **QUA-209 ↔ DL-025.** Forward link: QUA-209 → DL-025 (recorded via QUA-226). Reverse link: [`DL-025_t6_deploy_boundary_refinement.md`](./DL-025_t6_deploy_boundary_refinement.md) cites QUA-209 as the parent recording task. DL-025 is an OWNER directive on V5 hard rules and is independent of DL-017 / DL-023 (which govern CEO unilateral authority).
- **DL-023 ↔ DL-026.** DL-026 is the second concrete process change recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → agent-vs-agent escalation rules). DL-026 cites DL-023 as its authority basis.
- **QUA-234 ↔ DL-026.** Forward link: QUA-234 → DL-026 (recorded via QUA-238). Reverse link: [`2026-04-27_commit_hash_in_close_out_rule.md`](./2026-04-27_commit_hash_in_close_out_rule.md) cites QUA-234 as the ratification task and QUA-180 as the original P0 fix. The CTO prompt-language patch is tracked separately as [QUA-239](/QUA/issues/QUA-239) (OWNER-gated, out of Doc-KM scope).
- **DL-014 ↔ DL-027.** DL-027 operationalizes the BASIS→active propagation question that DL-014's two-layer hire model raised but did not answer. The rule itself is captured in `lessons-learned/2026-04-27_prompt_basis_activation_diff.md`; DL-027 records it with an authority basis and registry slot.
- **DL-023 ↔ DL-027.** DL-027 is the third concrete process change recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → drift-capture rule). DL-027 cites DL-023 as its authority basis.
- **QUA-235 ↔ DL-027.** Forward link: QUA-235 → DL-027 (recorded via QUA-237). Reverse link: [`DL-027_basis_active_diff_propagation_rule.md`](./DL-027_basis_active_diff_propagation_rule.md) cites QUA-235 as the originating learning-candidate. The Wave 1 catch-up diff side-artifacts shipped under QUA-237 cover DevOps (live agent `0e8f04e5-4019-45b0-951f-ca248cf82849`) and Pipeline-Operator (live agent `46fc11e5-7fc2-43f4-9a34-bde29e5dee3b`).

## Backfilling External entries

External rows are not Doc-KM gaps — they reflect decisions logged in lessons-learned or scratch before a canonical ADR was filed. CEO or the relevant decision owner may at any time materialize a canonical `DL-NNN_<topic>.md` and update the row.
