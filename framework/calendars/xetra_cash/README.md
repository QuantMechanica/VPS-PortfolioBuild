# Governed Deutsche Börse Xetra cash-session exceptions (2018-2025)

This directory is the provenance- and hash-bound session-calendar dependency
for the Xetra cash-equity venue (`MIC XETR`). It is a setup artifact, not a
strategy signal and not evidence that any EA is profitable.

Only official Deutsche Börse/Xetra primary documents are used:

- one official FWB trading-calendar PDF for every year from 2018 through 2025;
- one official final-trading-session PDF for every covered year.

The annual calendars explicitly apply to Xetra and Börse Frankfurt and prove
the non-trading dates. The final-session notices separately state the Xetra
schedule and prove the shortened year-end session. No German statutory-holiday
rule or third-party market calendar is used.

## Venue and runtime contract

The runtime file is
`data/QM5_XETRA_cash_session_exceptions_20180101_20251231.csv`:

```text
date_berlin,session_type,open_time_berlin,close_time_berlin
```

| Condition | Classification | Xetra interval |
|---|---|---|
| Date is a `FULL_CLOSE` row | Closed | none |
| Date is an `EARLY_CLOSE` row | Early close | `[09:00,14:00)` |
| Unlisted Monday-Friday inside coverage | Normal | `[09:00,17:30)` |
| Saturday/Sunday inside coverage | Closed | none |
| Outside coverage or any load/hash/parse ambiguity | Invalid | fail closed |

All dates and times are local `Europe/Berlin` values. For an early-close row,
`14:00` means the officially announced start of the Xetra closing-auction call,
the year-end counterpart of the card's regular `17:30` cash-session boundary.
The official notices state that price determination is no earlier than 14:05;
some years then have a trade-at-close phase through 14:15. Consumers needing
auction execution phases must model those separately and must not silently
reinterpret this session boundary.

The annual PDFs also cover Börse Frankfurt non-trading dates. This runtime does
**not** model Börse Frankfurt hours: its regular and year-end schedules differ
from Xetra. A Frankfurt strategy therefore needs its own venue-specific runtime.

Coverage is inclusive from 2018-01-01 through 2025-12-31. The table has 66
unique exceptions: 58 `FULL_CLOSE` rows and eight `EARLY_CLOSE` rows. Each
covered year has exactly one officially documented shortened final session.

## Hash-bound artifacts

| Artifact | Rows | SHA-256 |
|---|---:|---|
| Runtime exceptions | 66 | `c6ea69e62bdd309c7253b2db9b09cacb0116ff1001e0ce9cb7ace03bda024ff2` |
| Row provenance | 66 | `0c13afc835591149c96cff1def7c40519fe094cd8f7cf4d45683204774cf38ae` |
| Official source registry | 16 | `11987919c48bdcc68f1a77fecbaaa0058b87c56ec4cf90e5bedd3712717f48db` |
| Manifest | n/a | `5c914c3ce1a9c3a7c2e69c97be0236ec3e2c401e2d8d8a2ee9ec5c29280902f1` |

The provenance CSV maps every runtime row to one source ID. The source registry
records document type, the official archive, direct official PDF URL,
retrieval date, scope, and the SHA-256 of the downloaded PDF bytes. The
manifest binds the three CSV files and freezes venue, timezone, coverage,
normal session, early-close semantics, and fail-closed policy.

## Official primary sources

The official [Deutsche Börse trading-calendar archive](https://www.cashmarket.deutsche-boerse.com/cash-en/trading/trading-calendar-and-trading-hours/trading-calendar)
lists the annual calendars and final-session notices. Older 2018/2019 final
notices remain on the same official document host and are pinned directly.

| Year | Official trading calendar | Official final-session notice | Governed final session |
|---:|---|---|---|
| 2018 | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/154430/366c1c9be4ce7cdb923bbf246db1d1bf/data/trading-calendar-2018.pdf) | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/1406132/5de5c48d372f5e9e8e3e0a0be5f33954/data/Final-trading-session-2018.pdf) | 2018-12-28 14:00 CET |
| 2019 | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/1406548/6de0eba301a5433abb110fa3c96a5778/data/xetra-trading-calendar-2019.pdf) | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/1665540/dc15dce063fb57020665309b969af48f/data/Final-trading-session-2019.pdf) | 2019-12-30 14:00 CET |
| 2020 | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/1665534/112856375187d3e93671aa3d731d09d3/data/xetra-trading-calendar-2020.pdf) | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/2344984/7a707684270bd7eeb2bad7cc278033df/data/Final%20trading%20session%202020.pdf) | 2020-12-30 14:00 CET |
| 2021 | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/2344982/ddbcd31a616628a7ffa09dc709467ec4/data/xetra-trading-calendar-2021.pdf) | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/2833324/1209e3c0d43c27b69f223f70245dcd9a/data/Final%20trading%20session%202021.pdf) | 2021-12-30 14:00 CET |
| 2022 | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/2833162/2f53999770c09ce9c0bee8194c1fe60d/data/xetra-trading-calendar-2022.pdf) | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/3317552/ef392d7e63636f8cbb7bdb2093e8477e/data/Final%20trading%20session%202022.pdf) | 2022-12-30 14:00 CET |
| 2023 | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/3317408/4c8fbfbfeea62fd44600f6fe3f14f84e/data/xetra-trading-calendar-2023.pdf) | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/3735776/e53cb5552fd069e20dc3faaf343c9c2d/data/Final%20trading%20session%202023.pdf) | 2023-12-29 14:00 CET |
| 2024 | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/3559262/98ebe1fde231df56c9f116bc766533b2/data/xetra-trading-calendar-2024.pdf) | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/4064970/4beb98bd98c44f58e1fb68e3f3bb9746/data/Final%20trading%20session%202024.pdf) | 2024-12-30 14:00 CET |
| 2025 | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/4064968/4079a2d5a9fec324905942b807b398ed/data/xetra-trading-calendar-2025.pdf) | [PDF](https://www.cashmarket.deutsche-boerse.com/resource/blob/4580834/14d7f01321cb1d949020067efd2ee174/data/Final%20trading%20session%202025.pdf) | 2025-12-30 14:00 CET |

The PDFs' explicit exception lists are authoritative. For example, only three
weekday full closures occur in 2022, while German Unity Day is a trading day in
2025. The generator deliberately does not normalize years to a generic German
holiday template.

## Rebuild, verify, and provision

Deterministically rebuild the four governed artifacts:

```powershell
framework/calendars/xetra_cash/build_xetra_cash_calendar.ps1
```

Verify all 16 official PDFs, byte-for-byte regeneration, row/source contracts,
provisioner idempotence, conflict refusal, and the `T_Live` refusal guard:

```powershell
framework/calendars/xetra_cash/Test-XetraCashCalendar.ps1 -VerifyOfficialSources
```

Provision only to an explicit non-live MT5 `Common\Files` directory:

```powershell
framework/calendars/xetra_cash/provision_xetra_cash_calendar.ps1 `
  -CommonFilesRoot 'C:\path\to\MetaQuotes\Terminal\Common\Files'
```

The provisioner preflights every source and target before writing, refuses
`T_Live`, refuses paths that do not end in `Common\Files`, never overwrites a
hash conflict, verifies copied bytes, and is idempotent. Creating this package
does not authorize provisioning; no terminal or EA is touched by the build or
test scripts.

## Future consumer contract

EA integration is intentionally outside this change. A future shared loader
must bind the exact runtime filename and SHA-256, log its verdict, and fail
closed on missing, malformed, duplicate, out-of-coverage, or hash-mismatched
data. It must convert `Europe/Berlin` through pinned timezone data rather than
fixed broker hours.

Card-specific behavior must remain explicit:

- `QM5_20033_moc-imom` moves the final-M30 entry to 13:30 and its session exit
  to the governed 14:00 boundary on an `EARLY_CLOSE`; a `FULL_CLOSE` has no
  attempt.
- `QM5_20041_postclose-cont` still needs separate governed broker session,
  daily-break, rollover, and financing metadata. This Xetra calendar does not
  satisfy those dependencies.
- `QM5_20032_macro0830-brk` may use this calendar for its documented German
  early-close guard, but its incomplete issuer-event ledger remains a separate
  blocker.

## Remaining boundaries

- Dates after 2025-12-31 fail closed until a separately sourced and reviewed
  extension is generated.
- Unscheduled intraday technical outages and instrument-specific suspensions
  are not predictable session-calendar exceptions.
- This contract does not govern Eurex, LSE, Börse Frankfurt trading hours,
  broker CFD hours, broker breaks, rollover, or financing.
- `Europe/Berlin` to UTC/broker conversion is a separate pinned dependency.
