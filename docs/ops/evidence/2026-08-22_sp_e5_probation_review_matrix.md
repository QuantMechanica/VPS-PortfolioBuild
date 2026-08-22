# SP-E5 — MNT-036 probation review matrix

Date: 2026-08-22  
Router task: `f4181f1e-93ef-416f-89ae-c83c0bb7b522`  
Decision deadline: 2026-09-06  
Status: **OWNER-signable template prepared; no live-weight decision applied**

The companion CSV contains exactly the 24 sleeves in the signed and loaded DXZ manifest. Each row carries the current register state, accepted-entry count, last retained event, an evidence-based review lane, and empty OWNER decision/signature fields. Valid OWNER decisions are `CONTINUE`, `REDUCE`, or `REMOVE`.

## Review posture

- `CONTINUE_CANDIDATE` means the sleeve is loaded, registered (or has an explicitly identified intake gap), fresh in the pulse, and has accepted live entries. It is not an automatic Continue decision.
- `REDUCE_OR_REMOVE_REVIEW` flags sparse or silent evidence. It requires current book P&L and DScore before OWNER selection.
- `REMOVE_CANDIDATE` identifies QM5_10440/NDX: the declared ROT-1 dependency is unresolved, Q12 evidence is stale, current Q10 is FAIL, and no kill-switch baseline exists.
- `REMOVE_OR_REQUALIFY` identifies QM5_13128/NDX: the live binary's fixed event table missed the 2026-07-29 FOMC event; promotion remains blocked pending governed requalification.

The matrix deliberately does not fabricate sleeve P&L or DScore. The current pulse/register evidence provides membership, activity, and lineage state but not a valid per-sleeve P&L/DScore cut. OWNER signature must therefore follow a refreshed, reconciled scoring export. The programme target remains positive book P&L and DScore greater than 60.

## Evidence binding

- Book manifest: `D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json`, SHA-256 `8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`.
- Pulse snapshot: `D:/QM/reports/state/live_book_pulse.json`, generated `2026-08-22T06:00:01Z`.
- Membership/register census: `docs/ops/evidence/2026-08-22_live_sleeve_register_reconciliation_33e46600.csv`.
- SP-E4 diagnosis: `docs/ops/evidence/2026-08-22_sp_e4_dead_dxz_sleeves_diagnosis.md`.
- QM5_13128 correction: `docs/ops/evidence/2026-08-22_qm5_13128_missed_fomc_root_cause.md`.

## Verification

The CSV was parsed with Python's strict CSV reader: 24 data rows, 24 unique `ea_symbol` keys, and all OWNER decision/signature cells empty. No T_Live, AutoTrading, manifest, preset, registry, or live weight was changed.
