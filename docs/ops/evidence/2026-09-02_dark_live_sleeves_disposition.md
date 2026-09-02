# Dark live sleeves: 12778, 13117, and 12969 — 2026-09-02

Task: `cef343ab-bb9b-49c3-a6a5-5432cfa30c0d`

This was a read-only live-book investigation. No `T_Live` file, terminal,
preset, allocation, or sealed gate was changed.

## Findings

| Sleeve | Observed production evidence | Disposition |
|---|---|---|
| QM5_12778 basket | The deployed preset declares `AUDUSD.DWX`, `EURJPY.DWX`, `EURUSD.DWX`, and `EURAUD.DWX`. All 30 recorded `BASKET_WARMUP` events report `loaded=0, skipped=4`; the latest is 2026-08-23. Its 350 lifecycle rows from 2026-07-13 through 2026-08-23 contain no order or trade event. T_Live has native broker symbols, while this basket asks for `.DWX` aliases. | **REMOVE until rebuilt and requalified.** A replacement must map the four live-native legs, prove their history readiness, and pass an isolated as-live requalification. |
| QM5_13117 basket | The deployed preset declares `EURGBP.DWX`, `AUDJPY.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`. All 29 warmups report `loaded=0, skipped=4`; the latest is 2026-08-23. Its 331 lifecycle rows from 2026-07-19 through 2026-08-23 contain no order or trade event. The research disposition is also `RESEARCH_ONLY_NO_GO`. | **REMOVE.** Re-entry requires a native-symbol rebuild plus isolated requalification and a new governed admission decision. |
| QM5_12969 session sleeve | The deployed preset matches the repository strategy parameters: 02:00 JST entry, 09:55 exit, holiday-volume filter enabled, 120-point stop, zero spread filter. Its 292 lifecycle rows from 2026-07-13 through 2026-08-28 contain eight `FRIDAY_CLOSE` events but no entry, order, deal, or trade event. Q10 produced 331 trades (about 47/year), so seven dark weeks are operationally suspicious rather than adequately explained by low signal frequency. | **REMOVE-or-requalify.** Retention is conditional on the exact deployed binary producing expected entries in a diagnostic run. |

## Follow-up state

Exact-binary non-admission OOS evidence for QM5_12969 is already queued as work
item `acb3592c-3f31-5efe-bc12-344213600f1c`, using deployed EX5 SHA-256
`933d...`. It remains pending behind the census queue, so it is not evidence for
continued live admission today. An as-live plan was not fabricated: that runner
requires a sealed reference or an OWNER-approved discovery override.

The common diagnosis for 12778/13117 is a deterministic live symbol-contract
failure (`.DWX` basket names against native broker symbols), not proof that the
underlying research edge is absent. The safe present-tense decision is still
removal because both sleeves have produced zero executable live evidence.
