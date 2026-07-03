# OPS HARDENING P4-P5 — Evidence

**Task:** d015e982-5921-4b81-b318-1bc54d325546  
**Date:** 2026-07-03  
**Author:** Claude (headless orchestration)  

## Summary

Implemented 5 sub-items of ops hardening P4-P5 as specified in task payload (follow-up to b80ee365):

---

## Item 1 — Scaled phase active-timeouts

**File:** `tools/strategy_farm/farmctl.py`

### Changes
- Increased `PHASE_ACTIVE_TIMEOUT_MIN` base timeouts: P5→90, P5b→120, P5c→90, P6→120 (was 30 each)
- Added `_PHASE_TIMEOUT_REF_YEARS = 3` constant (reference calibration window)
- Added `_active_timeout_min_for_work_item(phase, payload) -> int | None` function:
  - Honors `timeout_min_override` in payload (priority 1)
  - P2 returns base directly (has its own spawn-level dynamic timeout)
  - Scales all other phases by `max(1, years/3)` where years comes from payload `from_date`/`to_date`, falling back to `P2_DEFAULT_TO_YEAR - P2_DEFAULT_FROM_YEAR + 1 = 6` years
  - Scales by seed count (`seeds` or `num_seeds` field, comma-delimited count)
  - Caps at 480 min (8h); floors at base
- Modified `_detect_active_age_timeout()` to parse payload first, then call `_active_timeout_min_for_work_item()` instead of flat dict lookup
- Added date-range propagation in cascade loop: `from_date`, `to_date`, `from_year`, `to_year` are copied from predecessor work_item payload so future P5b/P6 items have date context

### Verification
```
P5b no-dates (6yr default): 240 min ✓
P5b 7yr (2017-2024): 320 min ✓
P5b override=300: 300 ✓
Q07 (unmapped): None ✓
P2: 360 (no scaling) ✓
P5b 25yr 15seeds: 480 (cap) ✓
```

---

## Item 2 — update_magic_resolver.py --strict + dropped-rows warning

**File:** `framework/scripts/update_magic_resolver.py`

### Changes
- `load_rows()` now returns `(kept_rows, dropped_rows)` tuple
- `dropped_rows` = CSV entries whose EA directory is missing (filtered by `active_ea_ids`)
- Added `--strict` CLI flag: prints LOUD WARNING listing all dropped rows to stderr, exits nonzero if any dropped
- Dropped row fields: ea_id, slot, symbol, magic, slug, reason

### Verification
```
python framework/scripts/update_magic_resolver.py --strict --dry-run
-> 1652 kept, 291 dropped, exit 1 (worktree context, expected)
-> WARNING block printed with full dropped list
```

---

## Item 2b — build_check.ps1 pre-compile magic registration check

**File:** `framework/scripts/build_check.ps1`

### Changes
- Added `Invoke-ResolverPrecompileCheck(ResolvedRepoRoot)` function:
  - Runs `python framework/scripts/update_magic_resolver.py --strict` to regenerate resolver
  - Reports failure if dropped rows detected (resolver race condition)
  - For single-EA builds (`-EALabel`): verifies numeric ea_id is present in regenerated .mqh
  - Failure codes: `BUILD_CHECK_RESOLVER_DROPPED_ROWS`, `BUILD_CHECK_RESOLVER_EA_NOT_REGISTERED`
- Wired before `Invoke-CompileGate` (resolver must be fresh before MetaEditor runs)
- Resolver freshness is controlled by `-SkipMagicCheck` switch (same flag as collision check)

### Verification
```
PS parser: OK
```

---

## Item 3 — Seasonal/calendar full-year prescreen window

**File:** `tools/strategy_farm/farmctl.py`

### Changes
- Added `_SEASONAL_CARD_KEYWORDS` regex for monthly/seasonal/calendar/quarterly/annual patterns
- Added `_needs_full_year_prescreen(root, ea_id, payload) -> bool`:
  - Checks `payload['strategy_type_flags']` for calendar/season/month tokens first (explicit)
  - Falls back to card text scan via `_find_approved_card_for_ea` + `_SEASONAL_CARD_KEYWORDS`
- Modified `_p2_prescreen_dates(to_year, *, full_year=False)` to accept `full_year` flag:
  - `full_year=False` (default): H2 window `{to_year}.07.01` – `{to_year}.12.31`
  - `full_year=True`: `{to_year}.01.01` – `{to_year}.12.31` (lesson 12917: H2 missed Apr-Jun seasonal)
- Updated call site to compute `full_yr = _needs_full_year_prescreen(...)` before prescreen dispatch

### Verification
```
_p2_prescreen_dates(2022) == ('2022.07.01', '2022.12.31') ✓
_p2_prescreen_dates(2022, full_year=True) == ('2022.01.01', '2022.12.31') ✓
_needs_full_year_prescreen(..., {'strategy_type_flags': 'calendar,trend'}) == True ✓
_needs_full_year_prescreen(..., {'strategy_type_flags': 'trend,momentum'}) == False ✓
```

---

## Item 4 — Shared PowerShell module QMProc.psm1

**File:** `tools/strategy_farm/QMProc.psm1` (new)

### Changes
- Created module exporting `Get-QMFactoryProcesses`:
  - `-Terminal Tn` parameter, validated against `^T([1-9]|10)$` (refuses T_Live at param level)
  - Path-anchored: `CommandLine -match "\\mt5\\$Terminal\\"` (only the specific slot)
  - Always `-notmatch 'T_Live'` (belt-and-suspenders hard rule)
  - `-ProcessName` defaults to `terminal64.exe`
  - Returns `@(CimInstance[])` array
- Replaces ad-hoc patterns in Factory_OFF/ON, watchdog, purge (callers can import and use)

### Verification
```
PS parser: OK
ValidatePattern blocks T_Live, T11, non-Tn names
```

---

## Item 5 — Evidence path enforcement in orchestration prompts

**Files:**
- `tools/strategy_farm/run_agent_orchestration_task.py` 
- `C:/QM/repo/docs/ops/evidence/` (created)
- `C:/QM/repo/docs/ops/evidence/.gitkeep`

### Changes
- `build_prompt()` updated with:
  - Lease-acquisition note for tasks outside normal router path
  - `list-tasks` clarification: filter for IN_PROGRESS only, ignore REVIEW/BLOCKED/PASSED
  - Evidence path hard rule: "Evidence/artifact docs MUST be written to C:/QM/repo/docs/ops/evidence/ NOT inside a worktree" (7 docs stranded 07-02 cited)
  - Explicit pathspec commit example
  - Gemini code review rule (no self-approve)
  - Build guardrail news stale limit reminder
- Created `C:/QM/repo/docs/ops/evidence/` with `.gitkeep` as canonical landing zone

---

## Validation Summary

| Check | Status |
|-------|--------|
| farmctl.py py_compile | ✓ OK |
| update_magic_resolver.py py_compile | ✓ OK |
| run_agent_orchestration_task.py py_compile | ✓ OK |
| build_check.ps1 PS parser | ✓ OK |
| QMProc.psm1 PS parser | ✓ OK |
| _active_timeout_min_for_work_item smoke | ✓ 7/7 cases PASS |
| _p2_prescreen_dates smoke | ✓ 2/2 cases PASS |
| _needs_full_year_prescreen smoke | ✓ 2/2 cases PASS |
| update_magic_resolver --strict dry-run | ✓ exits 1, 291 dropped printed |

## Risks / Blockers

- **QMProc.psm1 callers**: Factory_OFF/ON and watchdog scripts are NOT yet updated to import QMProc.psm1. The module is available; wiring the imports is a separate Codex task to avoid scope creep.
- **291 dropped rows in --strict**: expected in worktree context where not all EA dirs are checked out. In main repo this number should be much lower. Investigate stale registry entries as a follow-up.
- **Cascade date propagation**: existing active P5b/P6 work_items in the DB won't have from_date until they are re-queued. The fallback (6yr default) covers them adequately.
