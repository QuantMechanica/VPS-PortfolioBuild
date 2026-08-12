# QM5_20030 strategy calendar

The runtime calendar contains only officially attributable EIA Weekly
Petroleum Status Report releases for 2018-2025 whose exact time is provable
from the EIA contract: an issue present in the official archive on Wednesday,
combined with EIA's official standard release time of 10:30
`America/New_York`.

- Runtime file: `QM5_20030_eia_calendar_20180110_20251231.csv`
- Runtime SHA-256: `b273dd88d27e38fe78ec85e426e0f1c8c8ef07dae2f7e1e102ba96f492c33e04`
- Eligible EIA rows: 352 (44 in 2022)
- Runtime coverage: 2018-01-10 through 2025-12-31
- Provenance file: `QM5_20030_eia_calendar_provenance.csv`
- Provenance SHA-256: `834540437f24e9818f8a1fc1b596f211c9d22154a20a9e3527e99ff9532f58c7`
- Excluded shifted releases: 64; the archive proves their dates but not their
  historical exact release times, so they remain ineligible.
- API status: data gap. API's official historical schedules prove publication
  dates but describe the time only as approximately 16:30 New York. The card
  explicitly forbids inferring that timestamp, so no API row is fabricated.

The shared QM calendar was inspected but cannot be used as the exact-time
source for this card: historical rows include known date/time shifts. This is
the same correction pattern used by QM5_20023: create a strategy-scoped,
immutable schedule from issuer evidence, strip actual/forecast values, pin the
runtime hash, then provision it through `FILE_COMMON`.

Regenerate and provision with:

```powershell
& .\framework\EAs\QM5_20030_eia-cad\build_strategy_calendar.ps1
& .\framework\EAs\QM5_20030_eia-cad\provision_strategy_calendar.ps1
```
