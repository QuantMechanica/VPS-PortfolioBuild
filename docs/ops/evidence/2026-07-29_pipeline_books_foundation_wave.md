# Pipeline and Books Foundation Wave — Implementation Evidence

- **Date:** 2026-07-29
- **Baseline:** `b62cf063878fa4ff43bd7e48d74e2c04d2fefa4d`
- **Branch:** `agents/mnt-20260729-implementation`
- **Disposition:** `SOURCE_IMPLEMENTED`; later canonical wiring, migration and outcome
  waves remain gated
- **Runtime authority:** none

## 1. Safety boundary

This wave was implemented and tested in the dedicated integration worktree while the
Factory remained intentionally OFF. No Factory ON/OFF command, Scheduled Task mutation,
production-database apply, MT5 launch, T_Live change, AutoTrading toggle, deployment,
challenge purchase or live-book mutation was performed.

Source support for a targeted operator run while OFF remains a separate, explicit path;
the new admission fence prevents only the autonomous priority worker from accepting a
claim after the OFF interlock has been asserted.

## 2. Implemented source units

| Area | Delivered contract / correction | Authority after this wave |
|---|---|---|
| Audit safety | Weakref identity caches in all three affected FTMO screens; permanent-hazard tasks disabled during OFF; restore authorization max-age/future rejection; exact nonce/bytes/process-start mutation-lock identity; bounded Python interpreter flags; wall-clock reconciliation timestamps | Source safety only; no Factory state transition |
| Work admission | Normal-worker claim serialized with the global mutation lock and rechecks `FACTORY_OFF.flag`; pre-OFF admitted work may finish its bounded claim transaction | No queue run was started |
| Gate identity | Strict versioned Q00..Q13 gate manifest with canonical write names and legacy read aliases | Additive contract; not yet the central runner registry |
| Execution identity | Content-addressed bundle binds Git/card/source/include/EX5/set/effective inputs/toolchain/symbol/history/cost/calendar/rulepack identities; create-new-only artifact writer | Additive contract; no accepted-build wiring yet |
| Governance | Separate immutable source authorization, agent recommendation, OWNER G0 decision and experiment/retry records | Additive contract; no production DB migration |
| Strategy Card V3 | Mechanism, prediction, falsifier, kill criteria, archetype/cluster unit, DoF, trial budget, typed parameter cells, DEV/OOS seals, dependencies and semantic schema/policy hashes | Card authorship is not G0 approval |
| Q08 v3 shadow | Archetype-specific required/diagnostic/N/A policy and deterministic `SUPPORTED` / `CONDITIONAL` / `INSUFFICIENT` / `CONTRADICTED` / `INVALID` aggregation | Shadow-only; Q08 v2 remains unchanged |
| Statistical foundation | Explicit complete calendar axes, zero days, synchronized sleeves, bound capital basis, correct 252/365 Sharpe and deterministic joint moving-block bootstrap | Additive evidence contract; no gate verdict mutation |
| Product policies | Strict `DXZ_BETTER_BOOK_V1` and `FTMO_2S_100K_SWING_V1` research rulepacks, separating official rules, internal guardrails, evidence debt and target eligibility | Research-only; no deploy or purchase authority |
| Residual visibility | Green lane deselects only five exact declared node IDs; external-residual lane executes the original tests unchanged | Failures remain hard and visible until external state is reconciled |

## 3. Independent verification

### Full Python Green Lane

Command:

```powershell
python tools/strategy_farm/test_lanes.py green
```

Result: `2834 passed, 1 skipped, 5 deselected, 34 subtests passed` in 375.81 seconds.
The five deselections are exactly the versioned external-residual node IDs; no marker,
assertion or production test was weakened.

### External residual lane

Command:

```powershell
python tools/strategy_farm/test_lanes.py external-residual
```

Result: exactly `5 failed` in 9.24 seconds, with no additional failure:

1. DXZ10939 real spec binding;
2. DXZ12567 immutable spec binding;
3. DXZ23 registry/calendar structural cleanliness;
4. density-set runtime binding cleanliness; and
5. QM20009 calendar hash/coverage/copy binding.

These failures are mapped to MNT-021/MNT-043/MNT-045 and require amendment or external
state ratification; this wave does not silently rebind them.

### Focused contracts

- Safety integration: `88 passed` for mutation lock, restore intent, Factory quiescence
  and atomic worker claim.
- PowerShell: mutation lock `15 assertions`, process scope `278 assertions`, restore-intent
  contract `PASS`.
- New gate/bundle/governance/rulepack/test-lane/Q08/return-series integration:
  `158 passed, 9 subtests passed`.
- Strategy Card V3 plus governance and Q08-v3: `88 passed, 6 subtests passed`.
- Static verification: `38` changed/new Python files compile, `17` changed/new JSON
  files pass strict duplicate-key and non-finite-value parsing, `9` changed/new
  PowerShell files parse without AST errors, and `git diff --check` is clean.

Focused counts overlap and are evidence of independently repeated combinations; they are
not added to the full-suite total.

### Post-verification read-only safety snapshot

- `FACTORY_OFF.flag`: present, 66 bytes, SHA-256
  `09CC4F83E8D5F384F03BC51306BEFF2CDD165108559A00DBF665097C60B47F1C`.
- `FACTORY_MUTATION.lock`: absent.
- Exact source-derived OFF scope: all `35` managed plus permanently disabled hazard
  tasks present and `Disabled`.
- T_Live: unchanged process PID `5220` at
  `C:\QM\mt5\T_Live\MT5_Base\terminal64.exe`.
- The pre-existing open changes in the canonical `C:\QM\repo` worktree remained outside
  the integration worktree and were not edited, staged or cleaned by this wave.

## 4. Explicit non-claims

- No completed W6 production framework/governor implementation is claimed.
- The new manifest and bundle are not yet wired into the canonical DB/write path.
- Q08 v3 is not promoted and has not re-adjudicated historical evidence.
- No W7 migration has been applied.
- No DXZ challenger or FTMO challenge book has passed its outcome gates.
- No money, deploy, live-trading, Factory-ON or AutoTrading authorization follows from
  these tests.

The authoritative remaining sequence and OWNER/design blockers are in
`docs/ops/MASTER_PIPELINE_BOOKS_IMPLEMENTATION_PLAN_2026-07-29.md`.
