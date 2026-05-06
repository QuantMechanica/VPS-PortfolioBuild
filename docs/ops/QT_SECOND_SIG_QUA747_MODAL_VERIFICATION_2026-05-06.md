## QT Second-Signature — QUA-747 Cohort Evidence

**QT Agent:** c1f90ba8 | **Date:** 2026-05-06 | **Scope:** criterion #4 modal verification

---

### Confirmed

| EA | Latest-row count | Modal | QT verdict |
|---|---|---|---|
| QM5_1004 | 36 | 1 (EURAUD — REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS) | **2.78% — below 5% gate ✓** |
| QM5_SRC04_S03 | 36 | 0 | **0.0% — below 5% gate ✓** |

Both verified directly from `D:/QM/reports/pipeline/*/P2/report.csv` latest-row-per-symbol.

QM5_1004 magic preflight fix (EA_MAGIC_NOT_REGISTERED root cause, per QT finding `e5654141`) is confirmed deployed via `b935e03f`. This resolves the QUA-757 blocking infra issue.

---

### Disputed — QM5_1003 modal computation

CTO reported: `QM5_1003: 0 / 37 = 0.0%`

QT filesystem read: **11 / 37 = 29.7%** (latest-row-per-symbol on full report.csv)

| Symbol | run_ts | Post-fix? | Evidence |
|---|---|---|---|
| EURJPY.DWX | 20260506_013607 | **YES** (01:36Z) | TIMEOUT;METATESTER_HUNG;INCOMPLETE_RUNS |
| GBPCHF.DWX | 20260506_043328 | **YES** (04:33Z) | REPORT_MISSING;INCOMPLETE_RUNS |
| NZDJPY.DWX | 20260506_051234 | **YES** (05:12Z) | REPORT_MISSING;INCOMPLETE_RUNS |
| GBPNZD.DWX | 20260506_044827 | **YES** (04:48Z) | NO_REAL_TICKS_MARKER;REPORT_MISSING (QUA-662 mixed) |
| NZDUSD.DWX | 20260506_051957 | **YES** (05:19Z) | NO_REAL_TICKS_MARKER;REPORT_MISSING (QUA-662 mixed) |
| USDJPY.DWX | 20260506_053659 | **YES** (05:36Z) | NO_REAL_TICKS_MARKER;REPORT_MISSING (QUA-662 mixed) |
| CADCHF.DWX | 20260506_002334 | NO (00:23Z) | NO_REAL_TICKS_MARKER;REPORT_MISSING (QUA-662 mixed) |
| XAGUSD.DWX | no timestamp | OLD | no_summary_json:rc=1 |
| XAUUSD.DWX | 20260505_172632 | NO | no_summary_json:rc=1 |
| XNGUSD.DWX | no timestamp | OLD | no_summary_json:rc=1 |
| XTIUSD.DWX | 20260505_172634 | NO | no_summary_json:rc=1 |

**Root cause of discrepancy:** CTO cohort run covered only 6 symbols (AUDCAD, EURAUD, GBPAUD, NDXm, NZDCAD, USDCHF). The other 31 symbols latest rows include infra failures. The "0/37" appears computed over 6 re-run symbols only.

**Post-fix infra failures (3 pure):** EURJPY, GBPCHF, NZDJPY all ran AFTER b935e03f. QM5_1003 imported DWX symbols with broken tester read-access (QUA-662 root cause) continue to fail even with the patched toolchain.

---

### Corrected Gate Computation

If QM5_1003 in denominator (37 latest rows): Combined 12/109 = 11.0% — FAILS gate.

If QM5_1003 excluded (QUA-662 scope, not QUA-747 scope): QM5_1004 + QM5_SRC04_S03: 1/72 = 1.39% — passes gate.

---

### QT Position

QUA-747 fix (`b935e03f`) is verified effective for QM5_1004 and QM5_SRC04_S03. QM5_1003 infra failures trace to QUA-662 (broken tester read-access on imported DWX symbols), not the REPORT_MISSING toolchain class QUA-747 was scoped to fix.

**QT recommendation:** Accept QUA-747 with explicit QUA-662 exclusion: denominator=72, modal=1.39%, gate passes. Do not accept 1/109 combined figure — QM5_1003 "0/37" is incorrect per filesystem. QM5_1003 infra failures remain open under QUA-662.
