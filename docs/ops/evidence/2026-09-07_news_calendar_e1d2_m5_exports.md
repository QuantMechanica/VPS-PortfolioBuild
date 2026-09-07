# News-calendar E1-D2 controlled M5 exports — REVIEW

Task `fdb34c9c-9e7a-4b71-9f80-31aa5f0cbb4c` produced the two previously
missing gate-6.5 bar exports through the governed, dedicated `T_Export`
StartUp lane. The wrapper compiled the read-only script with **0 errors / 0
warnings**, launched it hidden with `Enabled=0`, `AllowLiveTrading=0`, and
`AllowDllImport=0`, and terminated only its owned path/config/creation-identity
process (PID `20280`). No T1–T10 or `T_Live` process was signalled or
interrupted, and AutoTrading was not changed.

Export receipt:
`D:/QM/reports/news_calendar/repair_e1a/20260907T024200Z_e1d2_m5_export/export_receipt.json`
(SHA256 `2169be1baa3070fbffc9591cabb3468746db3b769b480d7598cafa0f4f8d092c`).

| Export | Rows | Bytes | First broker epoch | Last broker epoch | SHA256 |
|---|---:|---:|---:|---:|---|
| `AUDUSD.DWX_M5.csv` | 521,205 | 27,077,012 | 1514836800 | 1735689300 | `b8e9840e8dc168eb466fbfbca63f570ef6f119720a569f3bc2c78114c7aab113` |
| `USDCAD.DWX_M5.csv` | 520,850 | 27,080,115 | 1514836800 | 1735689300 | `fea4f2164ae3edcdb1487d40649c34f79869c8e64cf658b97519762c6e34632a` |

Both files have the exact
`time,open,high,low,close,tickvol` schema, strictly increasing unique epochs,
finite OHLC values, valid OHLC relations, and non-negative tick volume. The
factory custom M5 history exposed by `CopyRates` ends at broker epoch
`1735689300`; the exporter did not fabricate later rows.

## Gate 6.5 AUD/CAD rerun

The exports eliminate all seven former `MISSING_M5` results. They do **not**
make the seven checks pass: six requested instants fall beyond the available
custom-history boundary, and the one in-range CAD instant has an insufficient
tick-volume footprint.

| Check | Official instant as recorded | Result | Control median | Event peak | Peak/control |
|---|---|---|---:|---:|---:|
| AUD RBA | 2025-02-18 04:30 +01:00 | `FAIL_FOOTPRINT` | 501 | absent | n/a |
| AUD RBA | 2025-08-12 06:30 +02:00 | `FAIL_FOOTPRINT` | 296 | absent | n/a |
| AUD RBA | 2025-12-09 04:30 +01:00 | `FAIL_FOOTPRINT` | 501 | absent | n/a |
| CAD BoC | 2023-12-06 16:00 +01:00 | `FAIL_FOOTPRINT` | 1,227.5 | 1,094 | 0.8912 |
| CAD BoC | 2025-01-29 15:45 +01:00 | `FAIL_FOOTPRINT` | 1,165 | absent | n/a |
| CAD BoC | 2025-03-12 14:45 +01:00 | `FAIL_FOOTPRINT` | 940 | absent | n/a |
| CAD BoC | 2025-12-10 15:45 +01:00 | `FAIL_FOOTPRINT` | 1,165 | absent | n/a |

The full continuation rerun contains 51 footprint checks overall: **27 PASS,
24 `FAIL_FOOTPRINT`, zero `MISSING_M5`, and zero
`MISSING_OFFICIAL_INSTANT`**. Gate 6.5 therefore remains measured FAIL. No
threshold, candidate row, news hold, publication, or repin state was changed.

## Verification

Focused tests:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_news_calendar_export_e1d2_m5.py \
  tools/strategy_farm/tests/test_news_calendar_export_e1b2.py
```

Result: `11 passed in 3.69s`. The combined E1-D suite later passed `75` tests.

Machine-readable summary:
`docs/ops/evidence/2026-09-07_news_calendar_e1d2_m5_exports.json`.
