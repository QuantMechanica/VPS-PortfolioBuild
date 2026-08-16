# Task 89a4cb33: governed magic allocation and held-build recovery

Date: 2026-08-16

Operator: Codex

Branch: `agents/board-advisor`

Scope: router task `89a4cb33-fdba-47a2-b564-6edd659e4649`

## Verdict

REVIEW. The allocation blocker is cleared for all 19 held EAs. Ninety-one active, card-ordered magic rows were allocated and the resolver was regenerated atomically. Nine recoverable Claude implementation directories were independently reviewed, repaired where needed, packaged, and compiled serially with 0 errors and 0 warnings. The other ten canonical sources are still no-trade skeletons; their existing deterministic build tasks are being returned to BACKLOG for genuine approved-card implementation.

This is build evidence only. No pipeline phase, backtest, live deployment, terminal launch, T_Live change, or AutoTrading change was performed, and no pipeline verdict is asserted.

## Allocation transaction

- Preflight found an approved `g0_status: APPROVED` card, active EA-registry row, canonical source directory, and zero active magic rows for each of the 19 EAs.
- The card symbol order was preserved. Each magic is `ea_id * 10000 + symbol_slot`.
- Registry/resolver commit: `3cc2bd31e` (`registry: allocate magic rows for 19 held EAs`).
- Files in the atomic commit: `framework/registry/magic_numbers.csv` and `framework/include/QM/QM_MagicResolver.mqh` only.
- Generator result at transaction time: 16,071 resolver rows, zero dropped rows; generator-reported SHA-256 `85856A431254379E7E48AC8BC74EB4E634BD41E28827748817F287F393758817`.
- Post-build array audit parsed all four current resolver arrays: 16,071/16,071/16,071/16,071 entries. All 91 target tuples matched the active CSV tuple exactly; target key duplicates: 0; target magic duplicates: 0.

Allocated rows:

| EA | Rows | EA | Rows |
|---|---:|---|---:|
| QM5_11291 | 3 | QM5_20074 | 6 |
| QM5_11292 | 4 | QM5_20075 | 5 |
| QM5_11294 | 5 | QM5_20076 | 7 |
| QM5_11299 | 2 | QM5_20082 | 6 |
| QM5_11300 | 4 | QM5_20085 | 9 |
| QM5_11465 | 5 | QM5_20086 | 7 |
| QM5_11496 | 3 | QM5_20176 | 6 |
| QM5_11516 | 3 | QM5_20177 | 6 |
| QM5_11517 | 2 | QM5_20178 | 6 |
| QM5_11518 | 2 | **Total** | **91** |

## Recovered implementations and Codex review

The canonical files had been replaced by 127-line no-trade skeletons. The nine exact Claude implementation directories were recovered without cherry-pick, merge, registry restoration, or any main/cto_main mutation:

| EA | Source commit |
|---|---|
| QM5_20074 | `979060e835` |
| QM5_20075 | `e33888d3e9` |
| QM5_20076 | `6c03806943` |
| QM5_20082 | `22015488a9` |
| QM5_20085 | `53e207445c` |
| QM5_20086 | `9a6f8347d2` |
| QM5_20176 | `0a841668b2` |
| QM5_20177 | `4de11d1958` |
| QM5_20178 | `37b8f45db4` |

Codex review found and fixed:

- Missing host-slot propagation in QM5_20082, QM5_20085, QM5_20086, and QM5_20176. Each host order request now assigns `req.symbol_slot = qm_magic_slot_offset`.
- QM5_20177 declared `time_symmetry_tolerance` but did not use it, and used a flat ten-bar stand-in for the card's CD-relative time stop. It now measures AB/CD bar symmetry, rejects patterns outside the configured tolerance, records measured CD duration, and derives the time stop from that duration. Its SPEC was corrected with the implementation.
- QM5_20074, QM5_20075, and QM5_20076 historical setfiles lacked canonical EA IDs and/or strategy defaults. All approved strategy defaults were added before build.

The reviewed build cohort is committed as `2bd8f3931` (`build: recover and verify nine held EAs`) using explicit pathspecs for the nine EA directories.

## Focused verification

- `skill_build_ea_guard.py`: PASS for all nine rebuilt EAs (EA row, magic rows, and directory present).
- Build guardrail validator: PASS for all nine directories with `qm_news_stale_max_hours <= 336`.
- Set audit: 58 files checked, 0 errors. Every set has the exact active registry slot, matching `qm_ea_id`, `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and every declared strategy input.
- Comment/string-stripped source audit: 106 strategy inputs checked across the nine EAs, 0 unwired; every EA has at least one exact `req.symbol_slot = qm_magic_slot_offset` assignment.
- Prohibited-mechanics scan: no martingale, grid, ML/neural, T_Live, AutoTrading, or stale-news-ceiling violation found.
- `git diff --check`: PASS for the scoped build.

Serial strict compile evidence:

| EA | Result | Compile log | EX5 SHA-256 |
|---|---|---|---|
| QM5_20074 | 0E/0W | `framework/build/compile/20260816_113558/QM5_20074_trendline-horizontal-sr-retest.compile.log` | `8A6B4EED2F41CB44F1B734FB524127EB9BE0B2CB999106A836F25CBEB6C08A4E` |
| QM5_20075 | 0E/0W | `framework/build/compile/20260816_113642/QM5_20075_camarilla-inner-pivot-fade.compile.log` | `E31E1C92015504E9501B101BC0320C2C62654CAC57D425F50AFCEEB1806C47E5` |
| QM5_20076 | 0E/0W | `framework/build/compile/20260816_113728/QM5_20076_trendline-diagonal-break-retest.compile.log` | `0E7F94BA7F950F960BEEB7DC469FEF66D0DA776FC195722B87A9C42C15CD95FF` |
| QM5_20082 | 0E/0W | `framework/build/compile/20260816_113751/QM5_20082_connors-rsi2-pullback-h4.compile.log` | `857220555CD1734192BBB17EAF3D5A82DBB7B15FB6DB5A935A95CCE64EBFF750` |
| QM5_20085 | 0E/0W | `framework/build/compile/20260816_113852/QM5_20085_lebeau-lucas-momentum-oscillator-h4-r1-recovery.compile.log` | `08B1CDAB60D35D03603700B61DE700A7919FA3A4FDA82F3E74CC4204868B061E` |
| QM5_20086 | 0E/0W | `framework/build/compile/20260816_113924/QM5_20086_connors-multi-day-high-low-h4-r1-recovery.compile.log` | `0F1E896B4AA7DDBAB35E5A705E64D67D6CE6CDC12FA5516DDB717E260BF5C32C` |
| QM5_20176 | 0E/0W | `framework/build/compile/20260816_113951/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.compile.log` | `8F9DAAC1B7818A0F0DAAF3CE497FEA4E025A08C543AA50F7B3BDAED4EB02CE92` |
| QM5_20177 | 0E/0W | `framework/build/compile/20260816_114209/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.compile.log` | `1A2F22D4EDC56AFDBABD403BDA0BC330C0667F7C3E859B9DC3F7C5689D5E1F09` |
| QM5_20178 | 0E/0W | `framework/build/compile/20260816_114129/QM5_20178_hopwood-bermaui-macd-h4-r1-recovery.compile.log` | `1919EED8BB333AEAD0F37CEC4C9E0288D2E2E737C4FFA899FCE9D8BF7E16753F` |

## Ten PRECHECK re-drives

Magic precheck is cleared, but each canonical MQ5 remains a no-trade skeleton and has no recoverable implementation commit. The existing build task—not untracked replacement work—is the correct deterministic unit to re-drive:

| EA | Existing task |
|---|---|
| QM5_11291 | `aa43aa9c-27b9-4ee3-b71c-58c1a4abd0f5` |
| QM5_11292 | `56e67144-da6b-48b8-89ae-ba7048da97a9` |
| QM5_11294 | `a53520bc-d92a-4aa2-b6fb-3e24d974cba8` |
| QM5_11299 | `ea624d92-20db-425b-9deb-840b11c83d40` |
| QM5_11300 | `03dbc26e-174f-4879-bbbc-ac69b07ec692` |
| QM5_11465 | `6def383b-c119-4ec7-a54d-1d790eb362e3` |
| QM5_11496 | `f1331db1-b26e-462f-9710-b9f47f677828` |
| QM5_11516 | `53266c28-bd4a-4400-80da-dd621c2558ff` |
| QM5_11517 | `df68e99a-096b-4875-b408-d64cf204f2b0` |
| QM5_11518 | `d0f1e256-7e79-48ed-ac9b-ecdde5128a35` |

Router confirmation: all 10/10 listed tasks were updated from REVIEW to BACKLOG with this artifact path and a `MAGIC_PRECHECK_CLEARED` verdict. A post-update router read returned `COUNT=10 BACKLOG=10`.
