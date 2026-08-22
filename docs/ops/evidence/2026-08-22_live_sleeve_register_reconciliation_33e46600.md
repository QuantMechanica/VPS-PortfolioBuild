# Live-sleeve / manifest / Q12-register reconciliation

- Task: `33e46600-077e-4f81-a674-df83bd0e21b7`
- Snapshot: `D:/QM/reports/state/live_book_pulse.json`, generated
  `2026-08-22T06:00:01Z`
- Scope: read-only; no T_Live, manifest, preset, registry, or database mutation
- Row evidence: `2026-08-22_live_sleeve_register_reconciliation_33e46600.csv`

## Finding

There are not 28 currently loaded sleeves competing with a 24-sleeve manifest.
The pulse's `sleeve_count_from_ea_logs=28` is an inventory of identities found
in retained per-EA log files. The current terminal preset reconciliation is
exactly 24/24:

- `preset_consistency.checked_count=24`
- `ok_count=24`
- `extra_loaded_count=0`
- `missing_loaded_count=0`
- `manifest_reconcile.mismatch_count=0`

The four log identities outside the signed manifest are historical former-live
rows, not evidence of four currently loaded charts:

| EA / symbol | Last log event UTC | Loaded preset now | Root cause |
|---|---|---|---|
| 10476 / USDCAD | 2026-07-19 13:28 | no | Former-live ghost removed when 13117/13301 were admitted. The signed manifest explicitly names 10476 among the three old ghosts. |
| 10692 / NDX | 2026-07-19 13:28 | no | Former-live ghost explicitly named by the signed manifest. |
| 10715 / USDJPY | 2026-07-19 13:28 | no | Former-live ghost explicitly named by the signed manifest; two stale Q12-register rows survive. |
| 10940 / XAUUSD | 2026-07-05 14:13 | no | Magic registry status is `retired`; D2-d S3 replaced it with 12989/XAUUSD. |

Thus the `28 - 24 = 4` delta is retained-log history. It is not a current
manifest/load divergence.

## Real register gaps

The Q12 `portfolio_candidates` register is independently incomplete for three
members of the signed and loaded 24-sleeve book:

| EA / symbol | Manifest | Loaded preset | Magic registry | Accepted live entries in retained log | Q12 register rows | Classification |
|---|---|---|---|---:|---:|---|
| 13301 / GDAXI | yes | yes | active | 6 | 0 | register intake gap |
| 13213 / USDJPY | yes | yes | active | 7 | 0 | register intake gap |
| 12989 / XAUUSD | yes | yes | active | 0 | 0 | register intake gap; attached/emitting but no accepted entry in the retained log |

This confirms the three missing register rows, while refining the source wording:
13301 and 13213 have accepted live entries; 12989 is live-loaded and emitting but
has no accepted entry in the retained pulse evidence. The signed manifest and
the actual loaded preset set agree for all three, so the defect is the Q12
register intake, not T_Live or the manifest.

Two further live sleeves are registered but stale rather than absent:

- 10440 / NDX — `EVIDENCE_STALE`, work item `9799d0aa-...`
- 13128 / NDX — `EVIDENCE_STALE`, work item
  `q09-adhoc-13128-ndx-preFOMC`

The remaining 19 live sleeves have one effective `Q12_REVIEW_READY` row. 11132 /
SP500 also has two historical `DUPLICATE_SUPERSEDED` rows, but its surviving
`Q12_REVIEW_READY` row is unambiguous.

## Complete reconciliation

The companion CSV contains all 28 retained-log identities and, for each row:

- last log event and accepted-entry count;
- signed-manifest membership;
- current 24-preset load membership;
- magic-registry status;
- every matching `portfolio_candidates` state and work-item ID; and
- a discrepancy class and row-specific root cause.

Classification totals:

```text
LIVE_MANIFEST_REGISTERED              19
LIVE_MANIFEST_Q12_EVIDENCE_STALE       2
LIVE_MANIFEST_Q12_REGISTER_MISSING     3
FORMER_LIVE_GHOST_LOG                  3
FORMER_LIVE_RETIRED_LOG                1
total                                  28
```

## Evidence binding and verification

- `live_book_pulse.json` SHA-256:
  `ae00da59d36736e1c1b6cf8096c058d694febf5296497fdb15713df666ef41b1`
- Signed live manifest SHA-256:
  `8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`
- `portfolio_candidates` snapshot: 38 rows
  (`Q12_REVIEW_READY=30`, `EVIDENCE_STALE=6`,
  `DUPLICATE_SUPERSEDED=2`); canonical sorted-row JSON SHA-256:
  `404bed9d31d68e8f20dfcafa584aa883505c796c961cd4b3c2a0cca724048e41`
- The CSV was parsed back with Python's strict CSV reader: 28 data rows, 28
  unique `(ea_id,symbol)` keys, classification totals exactly as above.

No correction is executed here. Any register insertion or evidence-state change
requires a separate OWNER-authorized task. T_Live and AutoTrading were untouched.
