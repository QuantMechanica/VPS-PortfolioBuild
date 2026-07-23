# Governed NYSE Group US cash-session exceptions (2018-2025)

This directory closes the shared holiday/early-close data gap for strategies
that use the New York cash-equity session. It is an immutable exception table,
not a strategy signal and not evidence that any EA is profitable.

The data was transcribed only from official NYSE/ICE releases, then checked
against the official PDFs linked by those releases. The generator pins every
PDF by SHA-256. It includes the two post-calendar full-market closures in the
coverage window:

- 2018-12-05, National Day of Mourning for President George H. W. Bush.
- 2025-01-09, National Day of Mourning for President Jimmy Carter.

## Runtime contract

The runtime file is
`data/QM5_NYSE_US_cash_session_exceptions_20180101_20251231.csv`.
Its schema is:

```text
date_new_york,session_type,open_time_new_york,close_time_new_york
```

Interpret it as follows:

| Condition | Classification | New York cash interval |
|---|---|---|
| Date is a `FULL_CLOSE` row | Closed | none |
| Date is an `EARLY_CLOSE` row | Early close | `[09:30,13:00)` |
| Unlisted Monday-Friday within coverage | Normal | `[09:30,16:00)` |
| Saturday/Sunday within coverage | Closed | none |
| Date outside coverage or parse/hash failure | Invalid | fail closed |

All dates and times are local `America/New_York` values. The consumer remains
responsible for a deterministic DST-aware New York-to-UTC/broker conversion.
It must not interpret these values as UTC or fixed broker hours.

Coverage is inclusive from 2018-01-01 through 2025-12-31. There are 95 unique
exception dates: 77 `FULL_CLOSE` and 18 `EARLY_CLOSE`. Every early close in
this data set is the official 13:00 ET cash-equity close.

## Hash-bound artifacts

| Artifact | Rows | SHA-256 |
|---|---:|---|
| Runtime exceptions | 95 | `c2e87e2f72b5a5fc09ae6632a2ddc47cfa3cfdd98af7deb67a42292bcaf5fd11` |
| Row provenance | 95 | `792a50afd9ea9a3ca2be5daf50d75d7c65130cf9bff424795937e7028a518136` |
| Official source registry | 10 | `cf2cd19b3767f41dd1a9fd9af8cb50fa1b1daa6ce532221b884f21cffee06429` |
| Manifest | n/a | `38cb75a7af6e5648ccf9a2016200cd37db634007d3a51d70d741c88f0fa32b92` |

The normalized provenance file maps every exception date to a source ID. The
source registry records the corresponding ICE release URL, official PDF URL,
publication date, scope, and pinned PDF SHA-256. The manifest binds the three
CSV files and declares the coverage and failure policy.

## Official primary sources

One final official calendar publication is used per covered year. In
particular, 2022 uses the 2021-12-27 publication that added Juneteenth; the
older provisional 2022 calendar is not used.

| Source ID | Governed event(s) | Official ICE release |
|---|---|---|
| `NYSE_2018_CALENDAR` | 2018 scheduled calendar | [2018-2020 calendar, 2017-11-27](https://ir.theice.com/press/news-details/2017/NYSE-Group-Announces-2018-2019-and-2020-Holiday-and-Early-Closings-Calendar/default.aspx) |
| `NYSE_2019_CALENDAR` | 2019 scheduled calendar | [2019-2021 calendar, 2018-12-04](https://ir.theice.com/press/news-details/2018/NYSE-Group-Announces-2019-2020-and-2021-Holiday-and-Early-Closings-Calendar/default.aspx) |
| `NYSE_2020_CALENDAR` | 2020 scheduled calendar | [2020-2022 calendar, 2019-12-09](https://ir.theice.com/press/news-details/2019/NYSE-Group-Announces-2020-2021-and-2022-Holiday-and-Early-Closings-Calendar/default.aspx) |
| `NYSE_2021_CALENDAR` | 2021 scheduled calendar | [2021-2023 calendar, 2020-12-28](https://ir.theice.com/press/news-details/2020/NYSE-Group-Announces-2021-2022-and-2023-Holiday-and-Early-Closings-Calendar/default.aspx) |
| `NYSE_2022_CALENDAR` | 2022 scheduled calendar including Juneteenth | [2022-2024 calendar, 2021-12-27](https://ir.theice.com/press/news-details/2021/NYSE-Group-Announces-2022-2023-and-2024-Holiday-and-Early-Closings-Calendar/default.aspx) |
| `NYSE_2023_CALENDAR` | 2023 scheduled calendar | [2023-2025 calendar, 2022-12-21](https://ir.theice.com/press/news-details/2022/NYSE-Group-Announces-2023-2024-and-2025-Holiday-and-Early-Closings-Calendar/default.aspx) |
| `NYSE_2024_CALENDAR` | 2024 scheduled calendar | [2024-2026 calendar, 2023-11-10](https://ir.theice.com/press/news-details/2023/NYSE-Group-Announces-2024-2025-and-2026-Holiday-and-Early-Closings-Calendar/default.aspx) |
| `NYSE_2025_CALENDAR` | 2025 scheduled calendar | [2025-2027 calendar, 2024-11-08](https://ir.theice.com/press/news-details/2024/NYSE-Group-Announces-2025-2026-and-2027-Holiday-and-Early-Closings-Calendar/default.aspx) |
| `NYSE_2018_BUSH_MOURNING` | 2018-12-05 full closure | [George H. W. Bush notice, 2018-12-01](https://ir.theice.com/press/news-details/2018/New-York-Stock-Exchange-to-Honor-President-George-H-W-Bush/default.aspx) |
| `NYSE_2025_CARTER_MOURNING` | 2025-01-09 full closure | [Jimmy Carter notice, 2024-12-30](https://ir.theice.com/press/news-details/2024/The-New-York-Stock-Exchange-Will-Close-Markets-on-January-9-to-Honor-the-Passing-of-Former-President-Jimmy-Carter-on-National-Day-of-Mourning/default.aspx) |

The temporary physical NYSE floor closure in 2020 is deliberately absent:
NYSE cash equities remained open electronically. Intraday circuit breakers and
symbol-specific halts are also outside a session-calendar contract.

## Rebuild, verify, and provision

Rebuild the checked-in artifacts deterministically:

```powershell
framework/calendars/us_cash/build_nyse_us_cash_calendar.ps1
```

Verify all pinned official PDFs, byte-for-byte regeneration, row contracts,
provisioner idempotence, and the T_Live refusal guard:

```powershell
framework/calendars/us_cash/Test-NyseUsCashCalendar.ps1 -VerifyOfficialSources
```

Provision the runtime, provenance, source registry, and manifest directly into
an MT5 `Common\Files` directory:

```powershell
framework/calendars/us_cash/provision_nyse_us_cash_calendar.ps1 `
  -CommonFilesRoot 'C:\path\to\MetaQuotes\Terminal\Common\Files'
```

The provisioner refuses T_Live paths, never overwrites a mismatched file, and
verifies the copied bytes. Re-running it is idempotent.

## Fleet integration contract

Consumers should share one loader and date classifier. No EA should embed or
generate its own holiday list. Each EA must bind the exact runtime filename and
SHA-256, log the initialization verdict, and fail closed on missing, malformed,
duplicate, out-of-coverage, or hash-mismatched data.

Card-specific effects are intentionally not flattened into one generic rule:

- `QM5_20033_moc-imom`: for US routes, a full close has no attempt and an
  early close moves the final-M30 entry to `cash_close - 30 minutes` and the
  forced exit to the official close. The GDAXI/Xetra route is not covered by
  this US calendar and still needs a separately governed Xetra calendar.
- `QM5_20038_vwap2s-revert`: anchor at 09:30 ET, stop accumulating at the
  classified close, require next-open entry strictly before that close, and
  flatten at 16:00 or 13:00 as classified.
- `QM5_20039_onr-mid-brk`: only an eligible cash date may arm; use the
  classified close for the strict entry deadline and mandatory exit. Holiday
  handling must not be reduced to weekday arithmetic.
- `QM5_20040_b3-relvol-brk`: a full close cannot arm. An early close truncates
  the entry window and supplies the earlier mandatory safety flat required by
  the card; it must not remain hard-coded to 15:55.
- `QM5_20043_tpo-va80-rot`: the prior profile requires a `NORMAL` session and
  exactly thirteen aligned M30 bars. A full or early-close session cannot be
  silently treated as a complete prior RTH profile.
- `QM5_20044_gap-hilo-fade`: both prior and current sessions must classify as
  `NORMAL`; full and early-close dates fail the session eligibility rule. Find
  the previous eligible normal session, not merely the previous weekday.

This calendar repairs a shared setup dependency. It does not prove that an EA
fires, trades, survives governed costs, or has positive DEV/OOS/sealed
performance. Those claims require evidence-bound backtests after integration.

## Remaining coverage gaps

- Dates after 2025-12-31 fail closed until a separately reviewed extension is
  generated and hash-bound.
- The file does not govern Xetra, CME/Globex, commodity, or 24-hour CFD hours.
- New York DST conversion remains a separate pinned runtime dependency.
- Emergency intraday halts are not predictable calendar exceptions and require
  a separate runtime market-status control where a card needs one.
