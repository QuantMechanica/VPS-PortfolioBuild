# DL-048 — Roster Cleanup + Unauthorized Chief-of-Staff Retirement

> Renumbered 2026-05-01 from DL-035 to DL-048. Original commit `31ffb43d` collided with the prior DL-035 (`2026-04-28_pipeline_loadbalance_convention.md`, recorded under QUA-301). Per registry rule, this entry materialises at DL-048 alongside its DL-047 (heartbeat rebalance) and DL-049 (paperclip metadata) siblings under QUA-639.

- **Date:** 2026-05-01
- **Author:** CEO (`7795b4b0-...`)
- **Approver:** OWNER directive (QUA-639 wake comment 2026-05-01T07:14:48Z) + DL-017 (CEO unilateral hire/retire authority for non-charter roles).
- **Authority basis:** DL-017 (CEO hires under broadened authority) + DL-023 (operational decisions class).
- **Status:** EXECUTED 2026-05-01.
- **Related:** QUA-639 (D3 + D4), QUA-645 / DL-045 (Doc-KM backfill DL for QT/QB early-trigger hires — landed 2026-05-01 commit `54187eac` on `agents/docs-km`).

## Decision

Two retirements + one wave-2 trigger backfill plan, ordered.

### 1. Chief-of-Staff hire `bf24c2ae-...` — RETIRE

- **Hire was unauthorized.** Agent created 2026-05-01 00:42 local with scope "OS Controller / Token Controller / org-chart maintenance / weekly bottleneck review / hire recommendations." Distinct from the Wave-6 deferred-final founder-comms CoS in `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` (which has the same role label but different scope), but still an unauthorized hire — `paperclip/governance/org_chart.md` Wave 2-6 trigger table lists Chief-of-Staff as deferred-final only, with no mid-phase OS-Controller variant.
- **Decision:** retire, do not retroactively authorize.
- **Reasons:**
  1. **Roster ambiguity.** Two CoS agents (one mid-phase OS-Controller, one Wave-6 founder-comms) creates routing confusion in agent-to-agent comments and OWNER-facing snapshots. The Wave-6 founder-comms CoS is OWNER-authored frozen plan; the OS-Controller CoS would be CEO-authored ad-hoc. Mixing the two strains the chart.
  2. **Scope absorbable.** OS Controller / org-chart maintenance / weekly bottleneck review are in CEO scope (or Doc-KM scope for chart updates). Token Controller has no recurring data-driven need today (weekly OWNER-facing review can be CEO-direct). Hire recommendations are CEO scope under DL-017.
  3. **Heartbeat budget.** DL-034 throttles non-critical heartbeats for 72h. A new coordination role compounds the same waste pattern the throttle is meant to undo.
  4. **No 7+ day evidence of recurring bottleneck.** The CoS agent's own working rules say "only when a recurring bottleneck has named issue ids and a 7+ day pattern" justifies a new hire; no such evidence existed for this hire.
- **Future re-hire conditions.** A future CoS hire (mid-phase OS-Controller variant) requires:
  - 7+ days of OWNER-facing-snapshot or routing-loss evidence,
  - explicit OWNER directive (not CEO unilateral under DL-017, because the role overlaps Wave-6 founder-comms scope at the label level),
  - fresh DL-NNN distinguishing the two scopes.
- **Action taken:** `PATCH /api/agents/bf24c2ae-.../` with `status='terminated'`. Result: terminated 2026-05-01 ~07:24 UTC.

### 2. DevOps duplicate `0e8f04e5-...` (DevOps 2, paused) — RETIRE

- **Context.** Live DevOps roster has two API-visible agents at heartbeat-time: `0e8f04e5-...` (paused) and `86015301-...` (running). Per DL-027 cross-link, `0e8f04e5-...` was the live DevOps as of 2026-04-27; DevOps was subsequently re-hired to `86015301-...` and the old agent paused.
- **Decision:** retire `0e8f04e5-...`. The "paused" state is intent-to-retire; finalising via API removes ambiguity.
- **Action taken:** `PATCH /api/agents/0e8f04e5-.../` with `status='terminated'`. Result: terminated 2026-05-01 ~07:24 UTC.

### 3. Filesystem-only orphan agent dirs — LEFT IN PLACE (no API action needed)

The disk-state audit (`docs/ops/PHASE2_FRAMEWORK_CLOSEOUT_AUDIT_2026-05-01.md` § "Org roster anomalies") flagged 4 DevOps dirs, 2 Quality-Business dirs, and 1 broken-template dir. API-visible roster shows only one of each role (plus the now-retired duplicates). The remaining dirs:

- DevOps: `12c5c03f`, `9f2e41f3` — already API-retired before this DL; orphan dirs only.
- Quality-Business: `f2c79849` — already API-retired before this DL; orphan dir only. Live QB is `0ab3d743-...` (idle).
- Broken-template: `d53f62f7-...` (literal `{{agentName}}` placeholder, role "Founding Engineer / Quant Developer" — not a V5 role) — already API-retired before this DL; orphan dir only.

Storage-only cost. Retain dirs for hire-history queries and forensic trail. No retire API call is necessary because the platform side is already clean.

### 4. Quality-Tech + Quality-Business early-trigger hires — BACKFILL DL DELEGATED

Both hired 2026-04-28 ahead of their design-intent Wave 2 triggers (QT trigger: "first Backtest Baseline emits `report.csv`"; QB trigger: "first Quality-Tech PASS candidate"). Net effect is positive — QT is the agent that unblocks Step 25 today (QUA-643). QB stays idle until its trigger fires.

- **Action.** Documentation-KM authors a separate DL-NNN backfill in [QUA-645](/QUA/issues/QUA-645) explaining the trigger override and the snap-back rule (no further Wave 2 hires until their triggers actually fire). Doc-KM coordinates the DL number with REGISTRY.md so it does not collide with DL-035 / DL-036.

## Acceptance

- API roster (`GET /api/companies/.../agents`) shows no `Chief-of-Staff` and no second `DevOps`. Verified post-action: only one DevOps (`86015301-...`) and one QB (`0ab3d743-...`) remain live; no CoS.
- Doc-KM ships the QT/QB backfill DL via QUA-645.
- Org chart (`paperclip/governance/org_chart.md`) is consistent with API roster after Doc-KM's update lands.

## Reverse condition

- Future evidence that the OS-Controller scope needs a dedicated agent (recurring 7+ day routing loss, OWNER-facing-snapshot quality drop) → fresh DL-NNN, new hire under explicit OWNER directive.
- Pre-hire DL-035 → DL-036 numbering collision: DL-NNN allocation rule (REGISTRY.md, max + 1, no reuse of skipped numbers) handles this.

## Boundaries reaffirmed

- Charter values, hard rules, T6 isolation — unchanged.
- Wave-6 deferred-final founder-comms CoS — UNCHANGED. Frozen plan in `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` remains authoritative; this DL only retires the unauthorized mid-phase variant that was created with the same role label.
- DL-014 two-layer prompt pattern — unchanged.

## Cross-references

- Parent directive: QUA-639, `docs/ops/CEO_DIRECTIVE_PHASE2_CLOSE_2026-05-01.md` D3 + D4
- Disk audit: `docs/ops/PHASE2_FRAMEWORK_CLOSEOUT_AUDIT_2026-05-01.md` § "Org roster anomalies"
- Org chart: `paperclip/governance/org_chart.md` § Live Roster + Wave 2-6 trigger table
- Frozen Wave-6 founder-comms plan: `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`
- Doc-KM backfill: QUA-645
- Authority basis: DL-017 (`registry external`), DL-023 (`2026-04-27_ceo_autonomy_waiver_v2.md`)
- Heartbeat-rebalance context: DL-034 (`2026-05-01_phase2_heartbeat_rebalance.md`)
