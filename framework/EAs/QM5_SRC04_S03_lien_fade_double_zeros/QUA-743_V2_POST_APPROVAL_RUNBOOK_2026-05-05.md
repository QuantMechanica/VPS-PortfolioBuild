## QUA-743 v2 Post-Approval Runbook

Use this only after:
- R-and-D verdict = `acknowledged`
- CEO dispatch approved

### 1) Create v2 lineage (no v1 overwrite)

1. Allocate new EA id per registry process.
2. Copy v1 EA folder to a new v2 folder name.
3. Preserve linkage back to `SRC04_S03` and `QUA-743`.

### 2) Apply single-axis change

In v2 `.mq5`:
- change `order_expiration_minutes` default from `60` to `240`

No other strategy or framework logic changes in this revision.

### 3) Compile and capture evidence

Run compile pipeline for v2 and store:
- `.ex5`
- compile log with `0 errors, 0 warnings`

### 4) CTO DL-036 review gate (v2)

Generate fresh v2 review artifacts:
- review input JSON
- checklist markdown
- pass/fail memo with line references

### 5) P2 mini-cohort smoke first

Run 5-symbol M15 cohort with 2 runs each (same slice used for ZT diagnosis):
- `EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, AUDUSD.DWX`

Expected success criterion for recovery gate:
- ZT cohort count drops below 5 (ideally below 3) before full baseline expansion.

### 6) Full P2 baseline

If mini-cohort improves:
- dispatch full baseline matrix
- publish report CSV + result JSON
- update ZT comparison artifact (`v1_vs_v2`)

### 7) Escalation rules

- If v2 still returns cohort `>=5` ZT:
  - re-enter ZT recovery chain for next hypothesis iteration (v3 path)
- Do not silently abandon or overwrite v1 trail.
