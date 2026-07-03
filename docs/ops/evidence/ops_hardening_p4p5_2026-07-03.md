# OPS HARDENING P4-P5 — Evidence

**Task**: d015e982  
**Date**: 2026-07-03  
**Branch**: agents/claude-orchestration-1  
**Implemented by**: Claude (claude-sonnet-4-6)

---

## Sub-item 1: Scaled phase timeouts

**File**: `tools/strategy_farm/farmctl.py`

Added `_active_timeout_min_for_work_item(phase, payload_json) -> int | None` function
immediately before `_detect_active_age_timeout`. The function:

- Loads base timeout from `PHASE_ACTIVE_TIMEOUT_MIN`
- Parses `from_date`/`to_date` (format `YYYY.MM.DD`) or bare `from_year`/`to_year`
  from payload; computes `date_range_years = (to_date - from_date).days / 365.25`
- `scale_factor = max(1.0, date_range_years / 7.0)`  (7 years = base)
- For P7 (Q07): `seed_factor = max(1.0, sqrt(n_seeds / 5.0))` using `q07_n_seeds`
- For P5/P5b/P5c/P6/P7: `asset_factor = 1.5` if `strategy_type in {commodity, index}`
  or `symbol in {XAUUSD.DWX, XAU.DWX, XAGUSD.DWX, XAG.DWX}`
- `computed = int(base * scale_factor * seed_factor * asset_factor)`, capped at `base * 3.0`
- `payload.timeout_min` honoured as a floor (max of formula and override)
- All date/parse failures fall back to flat base timeout

`_detect_active_age_timeout` now calls `_active_timeout_min_for_work_item` instead of
`PHASE_ACTIVE_TIMEOUT_MIN.get(phase)` directly.

**Trigger**: Q07 multi-seed XAU EA timed out at 120 min on 2026-07-03 (full-range run).

---

## Sub-item 2: Loud resolver drops in update_magic_resolver.py

**File**: `framework/scripts/update_magic_resolver.py`

Changes:
1. `load_rows()` now returns `(rows, dropped)` tuple. `dropped` is a
   `list[tuple[int, str]]` of `(ea_id, slug)` for rows filtered because their
   EA dir is missing from `framework/EAs/`. Retired rows and parse-error rows
   are NOT counted as dropped.
2. `slug` field added to each row dict (used only for drop reporting; does not
   affect `render_mqh` which reads only `ea_id`, `slot`, `symbol`, `magic`).
3. When `dropped` is non-empty, a WARNING is always printed to stderr listing
   all dropped `(ea_id, slug)` pairs — regardless of `--strict`.
4. `--strict` CLI flag added: when set, exits nonzero if any rows were dropped.

`compile_ea.py` integration was noted as deferred: `compile_ea.py` is not tracked
in the agents/claude-orchestration-1 worktree and does not call
`update_magic_resolver.py`, so resolver-verification post-compile requires a separate
integration task against the canonical repo checkout.

---

## Sub-item 3: Seasonal full-year prescreen

**File**: `tools/strategy_farm/farmctl.py`

`_p2_prescreen_dates(to_year)` extended to:
```python
def _p2_prescreen_dates(to_year: int, payload: dict | None = None) -> tuple[str, str]:
```

When `payload.strategy_type_flags` contains any of `"calendar"`, `"season"`, or
`"month"` (case-insensitive), the function returns a full-year window
`{to_year}.01.01` to `{to_year}.12.31` instead of the default H2-only window.
Rationale: H2-only prescreen misses April–June seasonal peaks.

Caller at line ~1851 updated to `_p2_prescreen_dates(to_year, payload=item_payload)`.

---

## Sub-item 4: Shared PowerShell module QMProc.psm1

**File**: `tools/strategy_farm/QMProc.psm1` (new)

Created module exporting `Get-QMFactoryProcesses`:
- Takes optional `-Terminal T1..T10`; if omitted, returns all factory terminals
- Explicitly rejects `-Terminal T_Live` with `Write-Error`
- Filters `Win32_Process Name='terminal64.exe'` to `D:\QM\mt5\*` and
  `-notmatch T_Live` as defense-in-depth (double guard)
- Adds computed `Terminal` property from path regex `\\(T\d+)\\`

PS parse check confirmed: `Get-Command -Module QMProc` returns `Get-QMFactoryProcesses`.

`Factory_OFF.ps1` uses ad-hoc `Get-CimInstance -notmatch 'T_Live'` filters at lines
75-93. Integration with QMProc.psm1 deferred to future refactoring to avoid
breaking existing script in this PR (noted in module header comment).

---

## Sub-item 5: Evidence path enforcement in orchestration prompts

**Files**:
- `tools/strategy_farm/prompts/claude_review_ea.md`
- `tools/strategy_farm/prompts/claude_research_source.md`

Added `## Evidence Path Rule` section to each template before the output contract /
required output files section. The rule states:

> Evidence docs MUST be written to `C:/QM/repo/docs/ops/evidence/` (canonical
> checkout, not a worktree path). Worktree-stranded evidence docs become
> inaccessible after worktree reset or agent-branch cleanup.

Root cause: 7 evidence docs were stranded in worktrees on 2026-07-02 after agent
branch cleanup. Runtime-injected `{{verdict_path}}` and card/source-notes paths
are correct as-is and unchanged.

---

## Verification

- `python -m py_compile tools/strategy_farm/farmctl.py` — PASS
- `python -m py_compile framework/scripts/update_magic_resolver.py` — PASS
- `Import-Module QMProc.psm1 -Force; Get-Command -Module QMProc` — exports `Get-QMFactoryProcesses` v0.0
