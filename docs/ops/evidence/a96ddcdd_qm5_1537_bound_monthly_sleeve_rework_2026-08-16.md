# QM5_1537 bounded monthly-sleeve rework evidence

**Router task:** `a96ddcdd-fc8b-49f7-9e6e-f87964a2522d`  
**EA:** `QM5_1537_aa-vol-sma10`  
**Branch:** `agents/board-advisor`  
**Date:** 2026-08-16  
**Disposition:** REVIEW — implementation and focused verification complete; no pipeline verdict asserted

## Launch guard and classification

Before source mutation, the canonical state database reported seven `done`, 26 `failed`, and 28 `pending` QM5_1537 work items. There were no `claimed` or `running` rows. All 28 pending rows were deferred to `2026-08-25T00:00:00+00:00`, so no FX Q02 series was active and no tester was interrupted. The pre-rework source SHA-256 was the task-bound value `97E76AA58FA00F61360A9F6F251E36D6338474F3DE333351C7A7C3997526A073`.

The zero-trade/time-out investigation classifies the defect as an implementation/data-access defect, not an economic-mechanics defect. The old EA had no `CopyTicks` loop, but every one of 37 concurrent host instances eagerly loaded foreign D1 series and recomputed a 37-symbol monthly rank. In the tester this forced foreign-symbol tick synchronization, produced 45–47 GB footprints, and prevented the intended D1 strategy from reaching a useful economic run. Merely deleting the eager warm-up would leave the same foreign fan-out in the monthly rank and was therefore rejected.

## Bounded implementation

- `tools/build_monthly_sleeve_calendar.py` reads the 37 portable `T_Export` `Daily.hc` caches and emits one deterministic row per host symbol and host-month.
- `tools/verify_monthly_sleeve_equivalence.py` independently implements the legacy in-EA calculation. It was run against the task-bound pre-rework source before mutation.
- `QM5_1537_MonthlySleeveCalendar.mqh` loads the calendar from `FILE_COMMON`, verifies the file hash, recomputes the ranking-contract hash from live inputs and basket order, binds the source-cache bundle, validates row ordering/uniqueness, and fails `OnInit` closed on any identity or contract mismatch.
- The EA no longer calls `CopyClose`, `CopyRates`, `CopyTicks`, `Bars`, or `SymbolSelect` for foreign symbols. Runtime indicator and price access is host-only.
- Ranking economics are unchanged: 270 minimum closed D1 bars; 252 log returns; sample variance denominator 251; `sqrt(252)` annualization; top three; ascending basket-slot tie-break; evaluation on the first host D1 bar of each calendar month.
- `MONTHLY_SLEEVE_STATE` records month, host rank, valid-symbol count, selected flag, and reason. `SLEEVE_REJECTION_SUMMARY` provides compact task-level rejection counters. Missing/out-of-coverage calendar months remain inactive with an explicit reason.
- Spread gating now applies only to new entries; position management and monthly state still advance. This preserves entry economics while preventing an entry-only filter from blocking exits/state maintenance.

## Bound identities and equivalence

| Item | Evidence |
|---|---|
| Schema | `qm1537.monthly_sleeve.v1` |
| Ranking-contract SHA-256 | `314634871498688C3784984B8EA3DF35716996ACBEDC63623396FBC31D188007` |
| D1 input-bundle SHA-256 | `B177F13D49B91B2235D9B2C1013AE46F9F2BD9798D2CBA00922AACD760E41862` |
| Calendar SHA-256 | `401E0D91E2428DAB4ABFF17C1DF651F1C7BC716B7160B71A06D1A3ECA9B5288B` |
| Calendar coverage | 2017-10 through 2026-12; 3,546 host-month rows |
| Independent comparison | 1,986 host-month comparisons, 2018-07 through 2022-12 |
| Equivalence result | PASS; zero rank, valid-count, host-rank, or selected-flag mismatches |

The durable comparison result is `calendar/QM5_1537_equivalence_201807_202212.json`; the complete input-file hashes and contract payload are in `calendar/QM5_1537_monthly_sleeves_v1.manifest.json`.

## Setfiles and staged runtime data

All 37 governed D1 backtest setfiles were regenerated. A registry-aware audit returned:

```text
set_files=37
active_magic_rows=37
failures=0
```

Each set binds its registry slot, all ranking/calendar identities above, `RISK_FIXED=1000`, and `RISK_PERCENT=0`. The verified runtime copy is:

```text
C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM5_1537_monthly_sleeves_v1.csv
SHA-256 401E0D91E2428DAB4ABFF17C1DF651F1C7BC716B7160B71A06D1A3ECA9B5288B
```

`stage_monthly_sleeve_calendar.ps1 -VerifyOnly` returned PASS with 3,546 rows and all three bound hashes exact.

## Focused verification

| Check | Result |
|---|---|
| `pytest .../test_monthly_sleeve_calendar_contract.py -q` | PASS, 4/4 |
| `validate_build_guardrails.py .../QM5_1537_aa-vol-sma10` | PASS, 38 files, zero findings, news maximum 336 hours |
| `compile_ea.py --ea-id 1537 --force --json --fail-on-error` | COMPILED, 0 errors, 0 warnings |
| Final strict compile log | `C:\QM\repo\framework\build\compile\20260816_095756\QM5_1537_aa-vol-sma10.compile.log` |
| Final EX5 SHA-256 | `142A019E773A493DEF0640722EFB9D591D094650B35A69D5DE39F6AF3A048106` |
| `build_check.ps1 -Strict -EALabel QM5_1537_aa-vol-sma10` | PASS, zero failures, three informational vocabulary warnings |
| Build-check report | `D:\QM\reports\framework\21\build_check_20260816_095756.json` |

The three build-check warnings are for the new strategy-specific records `MONTHLY_SLEEVE_STATE`, `SLEEVE_REJECTION_SUMMARY`, and `SLEEVE_CALENDAR_INIT_FAILED`. The global event vocabulary was intentionally not swept from a working tree containing unrelated in-flight EAs; no guardrail or compile failure is hidden by that choice.

## Handoff boundary

No MT5 terminal was started, no active tester was interrupted, and no smoke/backtest/pipeline phase was run from this review task. The 28 deferred QM5_1537 successors remain governed by their existing family stop. Requalification of retired/deferred symbols must use the normal fresh-Q02 pipeline path with the new EX5 identity. This evidence establishes build and equivalence readiness only; it does not establish a trade-capable or economic pipeline verdict.
