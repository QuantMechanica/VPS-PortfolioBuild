---
title: Incident Response
owner: OWNER
last-updated: 2026-07-22
---

# 04 — Incident Response

This process covers strategy, data, broker, tester, automation, and live-operation
anomalies. OWNER assigns the incident commander when coordination is needed.

## First response

1. Timestamp and preserve logs, reports, hashes, process/task state, and affected
   symbols/accounts before changing anything.
2. Contain only the affected scope. Do not kill unrelated workers or terminals.
3. Never toggle AutoTrading. Any live-capital action requires explicit OWNER
   authority and the live runbook.
4. Classify severity: Sev-0 immediate live-capital risk; Sev-1 material production
   impact; Sev-2 contained degradation; Sev-3 transient/no material impact.
5. Identify root cause from evidence, apply the smallest reversible repair, and
   verify against the original failure signature.

## Exit

Close only when the failure signature no longer reproduces, required evidence is
valid, affected jobs are accurately classified, and remaining risks are recorded.
Infrastructure failures must not be converted into strategy FAIL or PASS labels.

Infrastructure-wide outages continue under [09-disaster-recovery.md](09-disaster-recovery.md).
