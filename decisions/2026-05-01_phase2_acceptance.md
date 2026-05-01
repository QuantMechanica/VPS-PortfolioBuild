# ADR: Phase 2 Acceptance — Step 25 Quality-Tech Review

**Date:** 2026-05-01
**Authority:** DL-034
**Reviewer:** Quality-Tech (agent `c1f90ba8-d637-46d9-8895-ead705bb4933`)
**Directive:** QUA-639 D1
**Issue:** QUA-643

---

## Scope

Step 25 of `framework/V5_FRAMEWORK_DESIGN.md § Implementation Order`:
Quality-Tech review of the full as-shipped V5 framework before any V5 strategy EA is built.

Artifacts reviewed:
- 16 includes: `framework/include/QM/*.mqh` (15 files) + `framework/include/QM_Branding.mqh`
- Subsidiary includes: `framework/include/news_rules/ftmo.mqh`, `framework/include/news_rules/5ers.mqh`
- EA template: `framework/templates/EA_Skeleton.mq5`
- 5 PowerShell scripts: `compile_one.ps1`, `build_check.ps1`, `run_smoke.ps1`, `sync_brand_tokens.ps1`, `brand_report.ps1`
- Smoke fixture: `framework/tests/smoke/QM5_1001_framework_smoke.*`
- Registry: `framework/registry/ea_id_registry.csv`, `framework/registry/magic_numbers.csv`

---

## Verdict: CONDITIONAL PASS — fixes applied in this commit

The framework skeleton (ea_id 1001) and smoke EA compile and run correctly under QM_Common.mqh. Two blocking defects were found that would cause compile errors for any EA that uses `QM_TradeManagement.mqh` via the umbrella include — the canonical path for Phase 3 strategy EAs. Both are fixed in this commit. Phase 3 EA development may proceed after these fixes land.

---

## Findings

### B1 (Blocking — Fixed) — QM_Common.mqh missing QM_TradeManagement.mqh

`framework/include/QM/QM_Common.mqh` does not `#include "QM_TradeManagement.mqh"`. The design specifies QM_Common.mqh as the umbrella include and the 4-module pattern requires TradeManagement for `Strategy_ManageOpenPosition`. Any EA including only `<QM/QM_Common.mqh>` has no access to `QM_TM_*` functions.

**Fix:** Added `#include "QM_TradeManagement.mqh"` to QM_Common.mqh after QM_Exit.mqh.

### B2 (Blocking — Fixed) — QM_TradeManagement.mqh compatibility shim causes redefinition collision

`QM_TradeManagement.mqh` contains compatibility shims for `QM_ExitReason` (9-value enum) and `QM_EntryRequest` (struct), guarded by `#ifndef QM_EXIT_REASON_DEFINED`. However, `QM_Exit.mqh` defines its own canonical `QM_ExitReason` (12-value enum) but never sets the `QM_EXIT_REASON_DEFINED` guard. When both are included (which B1's fix requires), the `#ifndef` passes and MQL5 sees two definitions of `QM_ExitReason` and `QM_ExitReasonToString` → compile error. Similarly `QM_Entry.mqh` and QM_TM's `QM_EntryRequest` shim are incompatible.

**Fix:** Removed the compatibility shims from `QM_TradeManagement.mqh`; added `#include "QM_Entry.mqh"` and `#include "QM_Exit.mqh"` as proper dependencies.

### S1 (Significant — Fixed) — build_check.ps1 does not enforce required input groups

`V5_FRAMEWORK_DESIGN.md` states: *"Build-check enforces presence of `QuantMechanica V5 Framework`, `Risk`, `News`, `Friday Close`, `Strategy` groups in every EA."* `Invoke-ForbiddenScan` only checks ML libraries and WebRequest. No `input group` pattern check exists.

**Fix:** Added `Invoke-InputGroupCheck` gate to `build_check.ps1` that greps each EA `.mq5` in `framework/EAs/` for the five required group labels and fails the build if any are absent.

### S2 (Minor — Fixed) — QM_StopRules.mqh uses angle-bracket include

`#include <QM/QM_OrderTypes.mqh>` in `QM_StopRules.mqh` vs. the relative `"QM_OrderTypes.mqh"` convention used by all other QM/ files.

**Fix:** Changed to `#include "QM_OrderTypes.mqh"`.

### D1 (Data — Fixed) — ea_id_registry.csv: 1003/1004 listed as `active` without .ex5

`framework/registry/ea_id_registry.csv` shows `status=active` for ea_ids 1003 and 1004. No `.ex5` file exists for either EA in `framework/EAs/`. The canonical status for allocated-but-uncompiled EAs is `draft`.

**Fix:** Updated 1003 and 1004 status to `draft`.

---

## Positive Observations

- **Magic schema**: `QM_MagicResolver.mqh` correctly implements `ea_id * 10000 + symbol_slot`, validates range, checks registry, and detects collisions with foreign positions. Logic is sound.
- **Risk sizing**: `QM_RiskSizer.mqh` correctly implements dual RISK_PERCENT / RISK_FIXED mode with portfolio weight, per-trade cap, and broker volume quantization (floor to step). Margin cap logic is appropriate.
- **DST handling**: `QM_DSTAware.mqh` correctly computes US DST boundaries from calendar rules (2nd Sunday March → 07:00 UTC, 1st Sunday November → 06:00 UTC). Ambiguous fall-back hour policy (prefer UTC+2) is documented and defensible.
- **Kill switch**: Three independent paths (daily loss, portfolio DD signal file, manual halt file). Fail-safe on unreadable signal file. Day-key reset on broker day boundary. Adequate.
- **News filter**: SHA256 hash logged at init for audit trail. Staleness check (14-day default). Fail-safe on missing or unreadable CSVs. FTMO and 5ers rules isolated to separate includes. Implementation matches design.
- **Logger**: JSON-line format with all required fields per design. Primary/fallback path logic. Escape-safe. Adequate.
- **Branding**: `QM_Branding.mqh` is byte-accurate against `brand_tokens.json` (BGR byte-order conversion matches V5 spec). `sync_brand_tokens.ps1` generates it correctly.
- **build_check.ps1**: ML library scan, WebRequest scan, magic collision check, set file schema validation, log schema validation, compile gate — all implemented and wired.
- **Smoke fixture**: `QM5_1001_framework_smoke.mq5` + `expected_events.json` covers INIT → SMOKE_INIT_OK → SMOKE_TICK → SMOKE_DEINIT with forbidden-event list. Deterministic regression gate is in place.
- **EA_Skeleton.mq5**: Correct 5-group input structure. All framework hooks wired (OnInit, OnDeinit, OnTick, OnTimer, OnTester). Minimally compilable.

---

## Milestone M0

`paperclip/milestones/milestones.md` does not exist in the repo — M0 closure status cannot be evaluated from this pass. CTO or Doc-KM to create the milestones file if M0 tracking is required.

---

## Required Before P1 Backtest on 1003/1004

All four blocking/significant defects are resolved in this commit. No additional pre-conditions from QT's gate.

---

## DL Entry

**DL-034 / 2026-05-01 / Quality-Tech**
Step 25 Phase 2 acceptance gate: CONDITIONAL PASS. Four fixes applied (B1: QM_Common umbrella missing QM_TradeManagement; B2: QM_TM shim collision with QM_Exit/QM_Entry; S1: build_check input-group enforcement gap; S2: StopRules angle-bracket include). Registry: 1003/1004 set to `draft`. Framework ready for Phase 3 EA development.
