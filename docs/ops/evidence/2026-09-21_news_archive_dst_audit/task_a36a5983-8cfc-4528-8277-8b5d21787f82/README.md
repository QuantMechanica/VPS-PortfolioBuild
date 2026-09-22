# Historical USD fixed-clock news audit

Task: `a36a5983-8cfc-4528-8277-8b5d21787f82`

Disposition: **REVIEW — exact one-hour-early rows confirmed**

## Finding

The immutable Q09 calendar `q09cal-20150101-20260809-0bb19b5bb9790b76`
contains **82 high-impact USD releases stored exactly 60 minutes before their
official fixed Eastern Time release clock**. The affected rows are part of a
2,079-row audit population spanning 36 fixed-clock 08:30 or 10:00 ET event
classes from 2015 through 2025.

The affected set is identical in the sealed Q09 calendar and the current
primary archive. The sealed content hash is
`86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1`;
it was not edited.

Two motivating examples are independently confirmed by the native MT5 export:

| Event | Stored UTC | Correct UTC | Delta |
|---|---:|---:|---:|
| Core CPI m/m, 2024-07-11 | 11:30 | 12:30 | -60 min |
| Advance GDP q/q, 2024-07-25 | 11:30 | 12:30 | -60 min |

The exact affected population is in [affected_rows.csv](affected_rows.csv),
bound to the sealed content hash and original source row number.

## Distribution and classification

| Year | Rows | First stored UTC | Last stored UTC |
|---:|---:|---|---|
| 2021 | 1 | 2021-03-10 12:30 | 2021-03-10 12:30 |
| 2022 | 1 | 2022-03-10 12:30 | 2022-03-10 12:30 |
| 2023 | 39 | 2023-03-23 11:30 | 2023-09-15 13:00 |
| 2024 | 40 | 2024-03-28 13:00 | 2024-09-19 11:30 |
| 2025 | 1 | 2025-03-27 11:30 | 2025-03-27 11:30 |

The 82 rows cover 16 unrelated event names and both 08:30 and 10:00 ET
classes. They cluster in seasonal batches, especially late March through
September 2023 and 2024, while adjacent rows can be correct. The best-supported
classification is therefore a **mixed-source or batch-level DST normalization
defect** that applied an extra daylight offset to a subset of rows. This is an
inference from the pattern; the evidence does not identify a single upstream
code line.

This exact -60-minute class is separate from the previously documented
-16/-17-hour population. The proposed correction does not repair, waive, or
reclassify that larger defect.

## Method

1. Filter the sealed calendar to `USD`, `HIGH`, 2015–2025, and publisher event
   classes with a fixed 08:30 or 10:00 Eastern release clock.
2. Construct the expected local release on each event date with the IANA
   `America/New_York` zone and convert it to UTC. This correctly changes 08:30
   ET between 13:30 UTC in standard time and 12:30 UTC in daylight time (and
   10:00 ET between 15:00 and 14:00 UTC).
3. Select only rows where `stored_utc - expected_utc = -60 minutes`.
4. Join mapped 2018–2025 event names to the native MT5 calendar export as an
   independent row-level control. It confirms 52 of the 82 rows exactly; the
   other 30 belong to event families not mapped in that export and retain the
   official-schedule/time-zone basis.
5. Repeat the fixed-clock check over the active primary/secondary pair and
   inventory every farm work item bound to the sealed content hash in a
   read-only database snapshot.

The current primary archive has the same 82-row affected key set. The secondary
archive has 116 affected `High` rows, with 80 keys intersecting the sealed set
and a 38-key symmetric difference. This is partly an impact-taxonomy/row-
selection difference between sources; the correction proposal deliberately
uses the 82 rows that affected the sealed Q-gate input.

Publisher clock references are the official [BLS release calendar](https://www.bls.gov/schedule/2026/),
[BEA schedule](https://www.bea.gov/news/schedule), [Census economic indicators
calendar](https://www.census.gov/economic-indicators/calendar-listview.html),
[DOL economic data page](https://www.dol.gov/newsroom/economicdata), [ISM report
schedule](https://www.ismworld.org/supply-management-news-and-reports/reports/ism-pmi-reports/),
[NAR schedule](https://www.nar.realtor/press-releases/nar-releases-2026-statistical-news-release-schedule),
[University of Michigan Surveys of Consumers](https://www.sca.isr.umich.edu/),
[Conference Board releases](https://www.conference-board.org/topics/consumer-confidence/press),
[New York Fed Empire State survey](https://www.newyorkfed.org/survey/empire/empiresurvey_overview),
and [Philadelphia Fed Manufacturing survey](https://www.philadelphiafed.org/surveys-and-data/regional-economic-analysis/mbos-2026).
These sources establish the fixed clock class; the audit applies the historical
date-specific IANA offset rather than assuming a constant UTC hour.

The trigger evidence was
`docs/ops/evidence/2026-09-20_velocity_book/qm5_41485_2024_reconciliation.md`
and its JSON/harness companions. The broader native-control outputs are retained
under [native_control](native_control/).

## Sealed verdict impact

There are **143 completed Q09/Q10 work items across 81 EAs** bound to the
defective sealed hash. Of these, **128 rows across 72 EAs** have both USD
exposure and an affected date inside their recorded evidence window.

| Q phase / existing verdict | Hash-bound | Direct USD/window exposure |
|---|---:|---:|
| Q09 / `REVIEW_REQUIRED` | 15 | 13 |
| Q10 / `CONFIG_LOCKED` | 36 | 35 |
| Q10 / `REVIEW_REQUIRED` | 92 | 80 |
| **Total** | **143** | **128** |

The remaining 15 rows are bound to the same content hash but have no direct USD
exposure under the OWNER-bound symbol/currency mapping. Exact row IDs, windows,
symbols, mapping provenance, and evidence paths are in
[sealed_verdict_impact.csv](sealed_verdict_impact.csv).

Existing pipeline verdicts are historical facts and remain immutable. The 128
directly exposed rows require new append-only measurement before any new
adjudication; the other 15 require content-hash replacement review. This audit
does not itself issue a pipeline verdict.

## Versioned correction proposal

[proposed_correction_diff.csv](proposed_correction_diff.csv) specifies exactly
82 changes against the parent hash. Each change adds one hour to `datetime` and
updates only the derived `hour` field; all other event fields are retained.

The resulting canonical candidate is
[proposed_archive/events.csv](proposed_archive/events.csv):

- rows: `48,245` (unchanged);
- SHA-256: `7a3243cf14d3ac6786423a48dd50317eed155d9c5360ba1067c55355f9618522`;
- parent SHA-256: `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1`.

[manifest.proposed.json](proposed_archive/manifest.proposed.json) is explicitly
`PROPOSAL_ONLY_NOT_AUTHORIZED`. It is not a Q09 publication manifest and does
not invent an approval, bundle identity, or OWNER receipt. A valid successor
requires an OWNER receipt with `approved_by`, `approved_at`, `reason`, and
`correction_reason`, publication reason `APPROVED_CORRECTION`, this sealed
parent manifest, and a successful WhatIf plan before publish.

No sealed archive, FILE_COMMON calendar, farm row, live terminal, AutoTrading
setting, or deployed file was changed.

## Reproduction and verification

From the canonical checkout:

```powershell
python docs/ops/evidence/2026-09-21_news_archive_dst_audit/task_a36a5983-8cfc-4528-8277-8b5d21787f82/audit.py
python docs/ops/evidence/2026-09-21_news_archive_dst_audit/task_a36a5983-8cfc-4528-8277-8b5d21787f82/audit.py --verify-only
```

The first command regenerates only this task directory. The second verifies all
recorded artifact hashes, Q09 canonicalization, row counts, the sealed source
hash, and the proposal authorization guard. Machine-readable totals and all
input/output hashes are in [summary.json](summary.json).
