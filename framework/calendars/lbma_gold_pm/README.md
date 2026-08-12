# Governed LBMA Gold Price PM schedule (verified subset 2020-2025)

This directory provides a deterministic, provenance-bound schedule layer for
the 15:00 London LBMA Gold Price PM auction. It exists for consumers such as
`QM5_20037_lbma-pm-brk`; it is not a trading signal and it is not evidence that
that EA is profitable.

The result is deliberately `PARTIAL_BLOCKED`, not complete. ICE Benchmark
Administration currently serves hashable official annual Gold holiday PDFs for
2020 through 2025. The official 2018 and 2019 PDF URLs return HTTP 404 as of
2026-07-22. Search-index text is not accepted as a pinned primary document, so
those two years are omitted rather than reconstructed. ICE's error policy also
describes possible `No Publication` outcomes but is not a date-level historical
cancellation ledger. Those gaps are machine-readable in
`data/QM5_LBMA_Gold_PM_schedule_gaps.csv`. Missing 2018/2019 schedule coverage
remains fail closed; the absence of an after-the-fact occurrence ledger is
recorded as a Q02/promotion evidence gap and does not by itself invalidate an
officially scheduled 2020-2025 row.

## Runtime contract

The runtime file is
`data/QM5_LBMA_Gold_PM_schedule_20200101_20251231.csv`. It has exactly one row
for every London civil date from 2020-01-01 through 2025-12-31:

```text
date_london,pm_auction_status,auction_start_london,auction_start_utc,london_utc_offset_minutes
```

The status values are:

| Status | Meaning |
|---|---|
| `SCHEDULED_PM_AUCTION` | Official regular 15:00 London PM auction date after applying that year's official IBA Gold holiday calendar. |
| `NO_PM_AUCTION_HOLIDAY` | The official annual calendar marks the PM auction closed. This includes Christmas/New Year's Eve PM-only closures and one-off UK holidays. |
| `NO_PM_AUCTION_WEEKEND` | Not a London business day; no auction time is populated. |

There are 2,192 rows: 1,503 scheduled PM auctions, 63 official weekday PM
no-auction dates, and 626 weekend dates. Non-auction rows have blank auction
times. A scheduled row always has `15:00:00` London and an explicit UTC instant.

A consumer must:

1. Bind the runtime and manifest SHA-256 values before accepting a row.
2. Require exactly one row for the London civil date.
3. Trade only `SCHEDULED_PM_AUCTION` rows.
4. Fail closed before 2020-01-01, after 2025-12-31, on any parse/hash/duplicate
   error, or when separate official status evidence positively reports a
   cancellation or `No Publication` condition. A missing historical occurrence
   ledger is logged as an evidence gap; it does not override a verified
   `SCHEDULED_PM_AUCTION` row.
5. Log London civil time, the supplied UTC instant, broker time, status, source
   IDs, and hashes. Do not recalculate eligibility from weekday arithmetic.

This schedule describes official planned auction status. It does not prove
that an auction actually completed or that a benchmark was published on a
particular day.

## London time and DST

The card-authorized IANA source is `tzdata2026c`. The transition file
`data/QM5_Europe_London_transitions_20180101_20251231.csv` pins all 16
`Europe/London` GMT/BST transitions covering the requested 2018-2025 interval.
The generator does not use the host OS timezone database. It applies the pinned
transition matrix directly, so 15:00 London is 15:00 UTC in GMT and 14:00 UTC
in BST. At 15:00 there is no ambiguous or nonexistent local-time edge.

The transition file covering 2018-2019 does not close the missing annual
auction-calendar gap for those years; it only proves the clock mapping.

## Official sources and hashes

The annual PDFs identify the morning and afternoon auction status separately.
Every listed annual holiday is a PM no-auction date. Christmas Eve and New
Year's Eve (or the preceding business day) are correctly PM-only closures even
when the morning auction is unaffected.

| Source | Official URL | SHA-256 |
|---|---|---|
| 2020 IBA Gold calendar | [ICE PDF](https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2020.pdf) | `a91bd02d018b7add5a4401be01843d496145ce269a2d55983dd9f3c0dfba6056` |
| 2021 IBA Gold calendar | [ICE PDF](https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2021.pdf) | `c6eaa601ae788ba2ea9658d3fe40afb714b1c7aec8bcc8186a4a6edb99e2213d` |
| 2022 IBA Gold calendar | [ICE PDF](https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2022.pdf) | `995dc0239c40d726def923590067a4f19615ddfa32fa19f1cb5c5d23f12815fe` |
| 2023 IBA Gold calendar | [ICE PDF](https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2023.pdf) | `f0e3da337c665d9033852d992447841a08ee1015d7abce3f4151be644269fc4c` |
| 2024 IBA Gold calendar | [ICE PDF](https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2024.pdf) | `94c205c28462b036924059bb2118d27c74a0a0983307fb91035bee8074a2c6ef` |
| 2025 IBA Gold calendar | [ICE PDF](https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2025.pdf) | `4f5ab78dcc514cbc7b7f318e5b7558fd968711d209a41428e74236f782bc16ff` |
| Precious Metals methodology | [ICE PDF](https://www.ice.com/publicdocs/Precious_Metals_Methodology_ESG_Annex.pdf) | `64a0ec801e11c2942a81c78242a2b4bac7943fc56e7121e46e4b8f53c308df03` |
| Precious Metals error policy | [ICE PDF](https://www.ice.com/publicdocs/Precious_Metals_Error_Policy.pdf) | `4042e22871a78dadd4fdeb2ed462f4fd778ff33bc96f1dbd87c3f1b1b7c8767d` |
| IANA tzdata 2026c | [IANA archive](https://data.iana.org/time-zones/releases/tzdata2026c.tar.gz) | `e4a178a4477f3d0ea77cc31828ff72aa38feff8d61aa13e7e99e142e9d902be4` |

The current IBA methodology sets the expected Gold auctions at 10:30 and 15:00
London time and links to annual non-publication calendars. The error policy
states that two gold auctions operate on each London business day and explains
how an auction error may ultimately become `No Publication`; it is included to
prevent a planned calendar from being misrepresented as proof of completion.

Notable official exception rows include the 2022 Platinum Jubilee bank holiday,
the 2022 State Funeral of Queen Elizabeth II, and the 2023 Coronation bank
holiday.

## Hash-bound artifacts

| Artifact | Rows | SHA-256 |
|---|---:|---|
| Runtime schedule | 2,192 | `b71f6a2fc04565a3d7aed997b8876b7ba8b5d0b913383b4340814e56db527d94` |
| Row provenance | 2,192 | `f2507db2327e0a8ba3407a3076c6a379f7ecf36726c505bce7501bb856d96b16` |
| Source registry | 9 | `4f3076944d906b1a67dc9890f883f375ea19e354af7db8a0b8d312118a5ad8de` |
| Europe/London transitions | 16 | `d0e5aba84b707c02f5c045efd56bed816f7d413e3f337cb255047e501570340c` |
| Declared gaps | 3 | `7a59deac3306a78ac3747ac2ccec93d04c2b38e6c695145a0bbc4347451289a3` |
| Manifest | n/a | `556eb64fd1da3277568fc4ae5d84400a9780d15e60c11d18e6cc4d0530f8da21` |

The provenance file maps every runtime date to its official annual/methodology
source and the pinned IANA clock source. The manifest binds all data artifacts
and records the partial coverage and cancellation policies.

`QM_LbmaGoldPmCalendar.mqh` also embeds the same sixteen transition instants.
The static integration test reconciles that compiled table against the
hash-bound transition CSV. It is an exit-only restart fallback for an existing
position; it cannot make a date eligible when any external package artifact is
missing or hash-invalid. Fallback use is emitted as `EXIT_CLOCK_FALLBACK`.

## Rebuild and verify

Rebuild the checked-in artifacts deterministically:

```powershell
framework/calendars/lbma_gold_pm/build_lbma_gold_pm_schedule.ps1
```

Verify all nine source downloads and hashes, byte-for-byte regeneration,
calendar/DST contracts, provisioner idempotence, mismatch refusal, and the
`T_Live` refusal guard:

```powershell
framework/calendars/lbma_gold_pm/Test-LbmaGoldPmSchedule.ps1 -VerifyOfficialSources
```

Provision all six artifacts into a non-live MT5 `Common\Files` directory:

```powershell
framework/calendars/lbma_gold_pm/provision_lbma_gold_pm_schedule.ps1 `
  -CommonFilesRoot 'C:\path\to\MetaQuotes\Terminal\Common\Files'
```

The provisioner refuses any path containing `T_Live`, never overwrites a
mismatched file, and verifies copied bytes. Re-running it is idempotent.

## Remaining blockers for QM5_20037

- 2018 and 2019 have no byte-retrievable, hash-pinnable LBMA/IBA annual source.
  They must stay outside runtime coverage until an acceptable primary document
  is obtained.
- The annual calendars prove planned status, not date-level auction completion.
  A historical official cancellation/`No Publication` ledger was not located;
  this remains a Q02/promotion evidence gap rather than a blanket technical
  block on the verified planned schedule.
- The package is integrated into `QM5_20037_lbma-pm-brk`, but no compiler,
  tester provisioning, or terminal run was used in this change. Compile and
  real-backtest evidence, trade capability, and economic merit remain separate
  evidence tasks.
