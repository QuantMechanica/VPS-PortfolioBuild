# DXZ23 Card/EA/Preset/Report Lineage Audit — 2026-07-16

## Verdict

This is a read-only, non-qualification audit of the 23 sleeves in the frozen
DarwinexZero audit manifest. It does not approve a variant, repair a Strategy
Card, qualify an EA, authorize deployment, or change AutoTrading.

The final primary classifications are:

- `EVIDENCE_MISSING`: 2
- `PREDECLARED_VARIANT_UNPROVEN`: 6
- `UNKNOWN_PRESET_KEYS`: 13
- `SOURCE_DEFAULT`: 2

Primary precedence is fail-closed and preserves material findings:
`EVIDENCE_MISSING` > `PREDECLARED_VARIANT_UNPROVEN` >
`UNKNOWN_PRESET_KEYS` > `SOURCE_DEFAULT`. Independent classification flags
remain present in the JSON report. Therefore the ubiquitous legacy preset keys
do not hide a real strategy or news-policy override.

The six unproven variants consist of five sleeves with 19 total `strategy_*`
overrides plus `12778|AUDUSD.DWX`, whose preset and report use news temporal and
compliance values `0/0` while the current source defaults are `3/1`.

## Immutable evidence chain

- Explicit source specification:
  `C:\QM\repo\docs\ops\evidence\dxz23_lineage_audit_explicit_spec_20260716.json`
  — SHA-256 `ade0b48f28937f7dc7bc7c53d90aa714819ef669b279c18146856e1e11f7fd5e`
- Bound input manifest:
  `D:\QM\reports\portfolio\dxz23_lineage_audit_20260716_v2\input_manifest.json`
  — file SHA-256 `0913fd2294f4c1db621439e6cf80675432277a5299235542c0e1677acf82401a`
  — canonical binding SHA-256
  `0544d32cb3de7a6d9a16a5f0b25a97794fb274e72730ac713a46eba57c113705`
- Final report:
  `D:\QM\reports\portfolio\dxz23_lineage_audit_20260716_v2\report.json`
  — file SHA-256 `41b540a2bfd78969494ecb03580e2ff0f7965694a717e267149717cabed6a3dd`
  — canonical report-content SHA-256
  `5521e6f1b7cd5d562f3e8fef0aa581298ccb31a92b4655b6679dc6b2ce440855`
- Audit implementation:
  `C:\QM\repo\tools\strategy_farm\dxz_lineage_audit.py`
  — SHA-256 `51486229ade8ae2590e742c003f7f841778db5e9eeb72dd4e408375e3934aac5`
- Frozen DXZ23 source manifest:
  `D:\QM\reports\portfolio\dxz23_audit_requal_input_20260715T221618Z\source_manifest_AUDIT_REQUAL_INPUT.json`
  — SHA-256 `ee47e67f8c9a006452ca39672f8165668381fa78e90999e05a249ac810868ac7`

The earlier directory `dxz23_lineage_audit_20260716` is retained as immutable
historical output but is superseded. The `_v2` directory is authoritative; it
uses the corrected primary-classification precedence above.

## Material findings

The expected strategy variants were reproduced exactly and were confirmed by
the effective values in their MT5 reports:

| Sleeve | Overrides | Source default -> preset/report |
|---|---:|---|
| `10440:NDX.DWX` | 3 | entry ATR offset `0.10 -> 0.07`; stop min `0.50 -> 0.65`; stop max `2.50 -> 3.25` |
| `10513:XAUUSD.DWX` | 4 | ATR `14 -> 18`; Tenkan `9 -> 6`; Kijun `26 -> 18`; Senkou B `52 -> 68` |
| `11132:SP500.DWX` | 5 | cumulative entry `35 -> 38`; RSI exit `65 -> 66`; SMA `200 -> 165`; ATR `14 -> 12`; ATR SL `2.5 -> 2.0` |
| `11165:AUDCAD.DWX` | 6 | long RSI `25 -> 24.615966`; short RSI `75 -> 80.913201`; exit RSI `50 -> 58.962981`; SMA `200 -> 250`; max hold `60 -> 67`; stop percent `1.0 -> 1.004025` |
| `12567:XNGUSD.DWX` | 1 | cumulative entry `35 -> 30` |

There are no report-effective mismatches among the 22 available reports.
Typed normalization also prevented the two known false positives:

- `12989|XAUUSD.DWX`: source `false`, preset `0`, report `false` — equal.
- `13128|NDX.DWX`: source `PERIOD_H1`, preset/report `16385` — equal.

Missing `strategy_*` keys in a preset resolve to the MQL5 input default and are
recorded separately; they are not evidence failures. This applies notably to
`10919`, `11708`, and `1556`.

Twenty-one sleeves contain the same 11 `qm_filter_*` preset keys without a
matching input declaration in the EA or its recursively bound QM include
closure. Those keys also do not appear as effective inputs in the MT5 reports.
They are classified as unknown/ineffective legacy preset keys, not silently
treated as active filters.

Two evidence gaps remain:

- `10911|GDAXI.DWX`: no native report exists at the explicitly bound run path.
- `12989|XAUUSD.DWX`: no APPROVED Strategy Card exists at the approved-card
  path. Its source, preset, receipt, and report are present, but the absent Card
  keeps the sleeve fail-closed.

## 23-sleeve matrix

`Missing defaults` is informational: it counts source `strategy_*` inputs not
present in the preset and therefore resolved to their source defaults.

| EA | Symbol | Primary classification | Strategy overrides | Unknown preset keys | Missing defaults | Report verified | Evidence gap |
|---:|---|---|---:|---:|---:|---|---|
| 10403 | XAUUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 10 | yes | — |
| 10440 | NDX.DWX | `PREDECLARED_VARIANT_UNPROVEN` | 3 | 11 | 0 | yes | — |
| 10476 | USDCAD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 0 | yes | — |
| 10513 | XAUUSD.DWX | `PREDECLARED_VARIANT_UNPROVEN` | 4 | 11 | 7 | yes | — |
| 10692 | NDX.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 0 | yes | — |
| 10715 | USDJPY.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 0 | yes | — |
| 10911 | GDAXI.DWX | `EVIDENCE_MISSING` | 0 | 11 | 0 | no | `report:FILE_MISSING` |
| 10919 | XTIUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 18 | yes | — |
| 10939 | GBPUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 0 | yes | — |
| 11132 | SP500.DWX | `PREDECLARED_VARIANT_UNPROVEN` | 5 | 11 | 0 | yes | — |
| 11165 | AUDCAD.DWX | `PREDECLARED_VARIANT_UNPROVEN` | 6 | 11 | 2 | yes | — |
| 11165 | EURUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 9 | yes | — |
| 11421 | AUDUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 0 | yes | — |
| 11421 | EURUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 0 | yes | — |
| 11708 | EURUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 5 | yes | — |
| 12567 | XAUUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 0 | yes | — |
| 12567 | XNGUSD.DWX | `PREDECLARED_VARIANT_UNPROVEN` | 1 | 11 | 0 | yes | — |
| 12778 | AUDUSD.DWX | `PREDECLARED_VARIANT_UNPROVEN` | 0 | 11 | 0 | yes | news policy `3/1 -> 0/0` |
| 12969 | USDJPY.DWX | `SOURCE_DEFAULT` | 0 | 0 | 0 | yes | — |
| 12989 | XAUUSD.DWX | `EVIDENCE_MISSING` | 0 | 11 | 16 | yes | `card:FILE_MISSING` |
| 13128 | NDX.DWX | `SOURCE_DEFAULT` | 0 | 0 | 0 | yes | — |
| 1556 | XAUUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 6 | yes | — |
| 10706 | GBPUSD.DWX | `UNKNOWN_PRESET_KEYS` | 0 | 11 | 0 | yes | — |

## Reproduction

The audit performs no implicit `latest` discovery. Both commands consume only
explicit paths, and output creation refuses to overwrite a different existing
artifact.

```powershell
python C:\QM\repo\tools\strategy_farm\dxz_lineage_audit.py bind `
  --spec C:\QM\repo\docs\ops\evidence\dxz23_lineage_audit_explicit_spec_20260716.json `
  --output D:\QM\reports\portfolio\dxz23_lineage_audit_20260716_v2\input_manifest.json

python C:\QM\repo\tools\strategy_farm\dxz_lineage_audit.py audit `
  --input-manifest D:\QM\reports\portfolio\dxz23_lineage_audit_20260716_v2\input_manifest.json `
  --output D:\QM\reports\portfolio\dxz23_lineage_audit_20260716_v2\report.json `
  --as-of-utc 2026-07-16T12:45:00Z
```

No APPROVED Card, EA, preset, report, T_Live file, MT5 terminal, deployment
state, or AutoTrading state was modified by this audit.
