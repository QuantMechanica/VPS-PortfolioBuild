# DB Historical Test Census -- Pipeline Rebaseline

Generated: 2026-08-23T12:09:17 | DB: `D:/QM/strategy_farm/state/farm_state.sqlite` | limit: None

Read-only census of every `(ea_id, symbol)` pair against the strictly-linear v3 gate chain (`Q02..Q10` main, `Q14,Q15,Q16` optimization fork). A gate counts **valid** only with a `done` row carrying an economic PASS-class verdict AND every earlier gate valid. Thresholds are unchanged (ROT); this classifies existing evidence only.

- **Total (ea_id, symbol) pairs:** 14513
- **Distinct finer keys** (ea_id, symbol, build_hash, setfile_hash) with hash evidence: 4498 (4979 hash-key x gate rows)
- **Pairs valid >= Q08:** 26
- **Pairs valid >= Q10:** 3
- **Pairs valid >= Q16:** 0

### Pairs per macro phase

| key | pairs |
|---|---:|
| 1_STRATEGIEBEWEIS | 14502 |
| 2_OPTIMIERUNG | 10 |
| 0_NONE | 1 |

### Pairs per highest contiguous valid gate

| key | pairs |
|---|---:|
| NONE | 7531 |
| Q02 | 5154 |
| Q03 | 1456 |
| Q04 | 126 |
| Q05 | 17 |
| Q06 | 59 |
| Q07 | 144 |
| Q08 | 21 |
| Q09 | 2 |
| Q10 | 3 |

### Pairs per disposition

| key | pairs |
|---|---:|
| REUSABLE | 5424 |
| ECONOMIC_FAIL | 7460 |
| INVALID | 1409 |
| STALE | 85 |
| MISSING | 123 |
| NOT_APPLICABLE | 12 |

### Pairs per earliest missing prerequisite

| key | pairs |
|---|---:|
| Q02 | 7531 |
| Q03 | 5154 |
| Q04 | 1456 |
| Q05 | 126 |
| Q06 | 17 |
| Q07 | 59 |
| Q08 | 144 |
| Q09 | 21 |
| Q10 | 2 |
| Q14 | 3 |

### Pairs per highest observed gate (any status)

| key | pairs |
|---|---:|
| Q02 | 7596 |
| Q03 | 14 |
| Q04 | 6229 |
| Q05 | 333 |
| Q06 | 38 |
| Q07 | 71 |
| Q08 | 106 |
| Q09 | 89 |
| Q10 | 26 |
| Q14 | 9 |
| Q15 | 1 |
| NONE | 1 |

### INFRA vs economic split

| bucket | pairs |
|---|---:|
| frontier blocked by INFRA_FAIL | 1335 |
| ECONOMIC_FAIL disposition | 7460 |
| INVALID disposition (infra/invalid, no valid gate) | 1409 |
| non-reusable pairs total | 9089 |

**Disposition legend:** `REUSABLE` = has contiguous valid evidence reusable under the new contract (frontier is a continuable rerun); `RENUMBER_ONLY` = reusable but valid evidence sits under legacy P* keys needing only renumbering; `ECONOMIC_FAIL` = frontier gate rejected on economic merit (dead on merit); `INVALID` = frontier is INFRA/INVALID with no valid gate below (rerun, not a strategy verdict); `STALE` = superseded build; `MISSING` = no evidence at frontier; `NOT_APPLICABLE` = structurally not testable/tradeable (e.g. non-DWX symbol).

_Evidence: pair CSV and finer CSV under `D:/QM/reports/rebaseline/census_2026-08-23.csv` / `D:/QM/reports/rebaseline/census_finer_2026-08-23.csv`; JSON summary `D:/QM/reports/rebaseline/census_2026-08-23.json`._
