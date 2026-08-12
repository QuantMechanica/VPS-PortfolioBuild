---
title: Dashboard Refresh
owner: OWNER
last-updated: 2026-07-22
---

# 05 — Dashboard Refresh

Dashboards are read-only projections of deterministic local state. They do not own
routing, scheduling, approvals, or phase verdicts.

## Inputs

- strategy-farm state and artifacts;
- version-bound phase reports;
- canonical registries;
- current infrastructure health outputs.

## Rules

1. Generate through the committed snapshot/render scripts.
2. Stamp generation time and source freshness.
3. Preserve the last valid view when an input is stale, while displaying a clear
   stale/error marker.
4. Do not infer PASS from missing data, expected metrics, card prose, or old issue
   snapshots.
5. Publish only fields allowed by the public snapshot contract.

Manual refresh is operational only and grants no decision authority. OWNER may
pause publication during maintenance.
