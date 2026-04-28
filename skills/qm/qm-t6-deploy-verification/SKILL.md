---
name: qm-t6-deploy-verification
description: Use when LiveOps (or DevOps interim) is verifying an approved EA deploy on T6 under an OWNER-signed deploy manifest. Don't use without an OWNER-signed manifest. This skill is read-only verification with AutoTrading OFF — agents NEVER toggle AutoTrading.
owner: LiveOps (DevOps interim)
reviewer: OWNER
last-updated: 2026-04-27
basis: docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md (verbatim verification contract)
---

# qm-t6-deploy-verification

Procedure for verifying that an approved EA has been correctly placed on the live T6 terminal under an OWNER-signed deploy manifest. **Read-only, AutoTrading-OFF discipline.** Agents never toggle AutoTrading.

## When to use

- An OWNER-signed deploy manifest exists in `deploy-manifests/` for a specific (ea_id, symbol, timeframe)
- LiveOps has copied `.ex5` + `.set` + template to T6 paths
- The EA is loaded on a T6 chart (or being loaded right now)
- The EA has cleared P9b Operational Readiness and is at P10 Live Burn-In OR a subsequent live placement

## When NOT to use

- No OWNER-signed manifest — abort, file confirmation request to OWNER
- T1-T5 placements — those are factory terminals; T6 is the only live terminal
- V4-legacy `SM_XXX` EA — never deploy V4 EAs on T6 per QUA-145 stand-down
- Demo / dry-run separate from live — DarwinexZero is **live-only** (no demo account)

## DarwinexZero operating model

DarwinexZero is **live-only** — no demo account, monthly subscription. Treat with full live-money discipline. P10 Live Burn-In is the first live exposure (minimum lot, KS-test kill-switch).

The "pre-deploy verification dry-run" in the runbook is **not** a separate gate — it is the verification protocol applied during a P10 deploy with AutoTrading OFF. The EA must be a real V5 EA that has cleared upstream phases. Optional non-trading smoke EA may be deployed first as an extra confidence cushion (allowed but not required).

## Verification Contract (mandatory)

No placement is considered complete until **all** of these are verified:

```text
[ ] T6 terminal is the active target (not T1-T5)
[ ] Symbol matches the manifest
[ ] Timeframe matches the manifest
[ ] EA name on chart matches manifest
[ ] Setfile timestamp matches manifest
[ ] Setfile hash matches manifest
[ ] Magic number visible in inputs or log
[ ] AutoTrading state OFF before chart placement
[ ] AutoTrading state OFF after chart placement
[ ] Experts log has no load errors
[ ] Journal log has no trade-context or authorization errors
[ ] Screenshot proof archived
```

Any failure → abort per § Abort Conditions below. The manifest does **not** promote until the failure is resolved.

## Procedure

### 1. Manifest validation

```text
- Manifest file:       deploy-manifests/<DEPLOY-YYYY-MM-DD-NNN>.yaml
- approved_by:         OWNER
- approved_at:         non-null timestamp
- environment:         live_burn_in OR live_full
- terminal:            T6
```

If `approved_at` is null → manifest not yet OWNER-signed → abort, do not proceed.

### 2. Compute setfile hash

```powershell
Get-FileHash -Algorithm SHA256 -Path <setfile_path>
```

Compare to `setfile_hash` in the manifest. If absent from the manifest, file an issue against LiveOps to add it; do not proceed without a manifest hash.

### 3. AutoTrading-OFF check (BEFORE)

Before opening the chart on T6: confirm AutoTrading button state is OFF in the T6 terminal. Capture screenshot.

If AutoTrading is ON before placement → abort. Investigate before continuing — agents do not toggle AutoTrading; OWNER does.

### 4. Place EA on chart

LiveOps applies template/profile or uses Level 2/3 automation per the runbook. The agent's role is to verify, not to drag.

### 5. AutoTrading-OFF check (AFTER)

Re-check AutoTrading state immediately after attaching the EA to the chart. Must still be OFF.

If AutoTrading is ON after placement → abort. AutoTrading turning on before approval is one of the runbook's hard abort conditions.

### 6. Verify each contract item

Walk the verification contract list (§ above) one item at a time. For each:

- Capture evidence (screenshot of chart, log line, hash output)
- Compare to manifest exactly
- Mark `[X]` only on match

### 7. Log scan

Read `Experts` and `Journal` logs at the deploy timestamp window:

```text
Experts log path: <T6 install root>/MQL5/Logs/<YYYYMMDD>.log
Journal log path: <T6 install root>/Logs/<YYYYMMDD>.log
```

Scan for:
- Load errors (`failed`, `error`, `cannot`)
- Trade-context errors (`trade context busy`, `not allowed`)
- Authorization errors (`Account check failed`, `Server connect failed`)

Any match → abort.

### 8. Archive evidence

Write to `D:\QM\reports\ops\liveops_dryrun_<ts>\` (per the runbook):

```text
liveops_dryrun_2026-04-27T1530Z/
  manifest.yaml                # copy of the deploy manifest as-of verification
  experts_log_excerpt.txt      # tail of Experts log around placement
  journal_log_excerpt.txt      # tail of Journal log around placement
  chart_screenshot.png         # full T6 window
  ea_inputs_screenshot.png     # EA properties dialog with magic + setfile visible
  autotrading_off_before.png   # AutoTrading button OFF, pre-placement
  autotrading_off_after.png    # AutoTrading button OFF, post-placement
  hash_check.txt               # setfile SHA256 + manifest hash (must match)
  verification_contract.md     # the 12-item checklist with evidence pointers
```

### 9. Report PASS / FAIL

PASS = all 12 contract items match + evidence archived.
FAIL = any abort condition triggered.

Post the verification report (or abort report) to the parent Paperclip issue. **OWNER toggles AutoTrading ON manually** after receiving and reviewing a PASS report. Agents never toggle.

## Abort Conditions (any one → abort)

```text
- Any chart opens on the wrong terminal (not T6)
- Wrong symbol or timeframe detected
- Setfile hash does not match manifest
- Magic number collision exists
- T6 AutoTrading turns on before approval
- T1-T5 load causes T6 degradation (alarmed by Observability-SRE)
- Darwinex connection unstable
- UI automation cannot prove exact chart/EA/setfile state
```

On abort: stop, archive partial evidence, file an issue assigned to LiveOps lead with abort reason, **do not retry until root cause is fixed**.

## Boundary

- **T6 is OFF LIMITS to factory work** — never run Strategy Tester, never optimize, never use as a research target.
- Pipeline-Operator has no write authority over T6.
- This skill is **read-only verification + AutoTrading-OFF discipline**. It does NOT toggle AutoTrading — that is an OWNER-only action.
- Position-size expansion past P10 minimum-lot requires a **separate** OWNER-signed manifest per increment.

## References

- `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md` — full runbook (verbatim source of this verification contract)
- `CLAUDE.md` § Hard Boundaries — T6 OFF LIMITS rule
- `references/manifest_template.yaml` — example deploy manifest shape
- `decisions/2026-04-26_dxz_live_only_and_p10_live_burn_in.md` — DXZ live-only architecture decision
- `decisions/DL-025_t6_deploy_boundary_refinement.md` (referenced in runbook line 147) — T6 deploy boundary refinement
