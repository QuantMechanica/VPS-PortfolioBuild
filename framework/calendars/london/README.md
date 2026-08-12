# London calendar bundle

This directory contains three deliberately separate calendar contracts. They
share the `Europe/London` date label, but they do **not** describe the same
market.

| Contract | Verified coverage | Meaning |
| --- | --- | --- |
| England and Wales public holidays | 2018-01-01 through 2025-12-31 | Jurisdictional public/bank-holiday dates only |
| LSE cash-session exceptions | 2018-01-01 through 2025-12-31 | Official London Stock Exchange full closes and scheduled 12:30 London early closes |
| WMR 16:00 London spot service | 2025-01-01 through 2025-12-31 only | Official WMR service alterations that affect or qualify the 16:00 spot fix |

Every contract is exception-based and fails closed outside its stated
coverage. The bundle does not ship timezone rules; a consumer must separately
pin an IANA `Europe/London` timezone-data version.

## Why the contracts must stay separate

An England and Wales holiday is not proof that an FX symbol is closed. An LSE
half day is not an FX half day. A UK holiday is also not proof that the WMR
16:00 fix is absent.

The official WMR methodology monitors holidays in the UK, USA, Germany and
Japan. Closing rates can still be produced when at least two centres are open.
The 2025 service schedule is concrete evidence: 26 May 2025 is a UK/USA
holiday, yet the 16:00 London spot fix remains available. Therefore no
consumer may derive WMR availability from either the jurisdictional or LSE
file.

The mandatory mappings for the density cards are:

- `QM5_20031_asia-fx-fade`: the jurisdictional file is contextual evidence
  only. The card's "abnormal opening conditions" still require a governed
  broker-session calendar and observed route data. Do not reject every public
  holiday merely because it appears in this bundle.
- `QM5_20034_wmr-postfix`: consume the WMR service contract, not the LSE or
  jurisdictional contract. The 2018-2024 WMR service-calendar gap means that
  the prescribed full study remains blocked/fail-closed until immutable
  official schedules or an equivalently authoritative historical publication
  record are acquired.
- `QM5_20041_postclose-cont` on `UK100.DWX`: consume the LSE cash-session
  contract. A normal cash session is 08:00-16:30 London; an `EARLY_CLOSE` row
  changes the official close to 12:30; a `FULL_CLOSE` row provides no cash
  anchors. Broker break/rollover/financing metadata remains a separate card
  dependency.
- `QM5_20045_london-box`: its 03:00-06:00 box is fixed UTC and must never be
  moved by this bundle. The jurisdictional file may support a trading-day
  audit, but route-specific broker sessions and the governed news calendar
  still determine actual FX eligibility. The LSE file is not a GBPUSD or
  EURGBP calendar.

## Files

Runtime files contain only the fields an EA needs for a deterministic lookup.
Each has a separate row-provenance file.

- `data/QM5_GOVUK_England_Wales_public_holidays_20180101_20251231.csv`
- `data/QM5_GOVUK_England_Wales_public_holidays_provenance.csv`
- `data/QM5_LSE_cash_session_exceptions_20180101_20251231.csv`
- `data/QM5_LSE_cash_session_exceptions_provenance.csv`
- `data/QM5_WMR_1600_London_service_exceptions_20250101_20251231.csv`
- `data/QM5_WMR_1600_London_service_exceptions_provenance.csv`
- `data/QM5_London_calendar_sources.csv`
- `data/QM5_London_calendar_manifest.json`

The manifest binds every runtime and provenance file by SHA-256 and exposes the
non-substitution rules in machine-readable form. Provenance rows bind each
exception to source IDs; the source registry pins official-document bytes.

## Source construction

The holiday layer uses the commit-pinned official `alphagov/calendars` data for
2018 and the official GOV.UK bank-holiday JSON snapshot for 2019-2025. The
underlying Banking and Financial Dealings Act and the 2018 proclamation in The
London Gazette are pinned as legal provenance.

The LSE layer applies the Exchange's official rule that it recognises the
Public and Bank Holidays of England and Wales. Notice N16/22 separately pins
the 19 September 2022 State Funeral closure. The official SETS trading-cycle
document defines regular trading as 08:00-16:30 London and early-close trading
as 08:00-12:30 on the final trading day before Christmas and the final trading
day of the calendar year. The generator resolves those two dates against the
verified full-close set for every year; it does not maintain a hand-entered
half-day list.

The WMR layer uses the official WMR methodology and the official August 2025
service-alteration schedule. The current byte-pinnable schedule begins in 2025.
The earlier Refinitiv document URL now serves the same 2025-2030 bytes, so it
does not provide immutable 2018-2024 evidence. Cached search snippets are not
accepted as runtime provenance. No dates are extrapolated into that gap.

## Build and verification

The shared runtime loader is
`framework/include/QM/QM_LondonCalendars.mqh`. It opens only MT5 Common Files,
verifies the pinned bundle-manifest SHA-256, then independently verifies and
parses the selected jurisdictional, LSE cash-session, or WMR runtime file. The
LSE API classifies normal, full-close, early-close, and out-of-coverage dates;
it resolves 08:00–16:30 London or 08:00–12:30 London into UTC only after the
hash-bound calendar verdict. Its enums keep `PUBLIC_OR_BANK_HOLIDAY`, LSE cash
status, WMR `NO_1600_FIX`, and `OUT_OF_COVERAGE` distinct; it does not expose an
API that converts a jurisdictional or LSE date into an FX closure.

Regenerate into the checked-in `data` directory:

```powershell
& .\framework\calendars\london\build_london_calendars.ps1
```

Also re-download every official source and verify its pinned SHA-256:

```powershell
& .\framework\calendars\london\build_london_calendars.ps1 -VerifyOfficialSources
```

Run the deterministic artifact and provisioner contract tests:

```powershell
& .\framework\calendars\london\Test-LondonCalendars.ps1
```

`provision_london_calendars.ps1` copies the eight manifest-bound files to an
MT5 Common Files directory. It validates hashes before and after copying, is
idempotent, refuses a drive root, and refuses any path containing `T_Live`.
Provisioning a calendar does not authorize an EA build, a pipeline phase or
live use.

## Known limits

- WMR 16:00 historical service coverage for 2018-2024 is unresolved and must
  remain fail-closed.
- The LSE file describes scheduled cash-session exceptions plus the explicitly
  sourced State Funeral closure. It is not an intraday outage or per-security
  halt feed.
- The holiday file does not prove an FX closure or abnormal broker opening.
- No broker symbol-session, daily-break, rollover, financing, news or timezone
  database is embedded in this bundle.
