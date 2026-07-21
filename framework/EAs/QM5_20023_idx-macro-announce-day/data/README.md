# QM5_20023 strategy calendar

This directory is scoped to `QM5_20023_idx-macro-announce-day`. It does not
replace or mutate the shared QM news calendar.

- Runtime file: `QM5_20023_announcement_calendar_20150101_20250404.csv`
- Runtime SHA-256: `411ae4af3dbe261e373705660e28b81e7c5dfc7398f38516e07effff71cd73af`
- Runtime rows: 451 (124 NFP, 123 CPI, 123 PPI, 81 scheduled FOMC decisions)
- Unique event days: 439
- Coverage: 2015-01-09 through 2025-04-04
- Provenance file: `QM5_20023_announcement_calendar_provenance.csv`
- Provenance SHA-256: `5585da3c1eda2ca6bfd08cb972c9fac05b8246d8386674c11d5b2ade4d8ad68b`

The row-level provenance file records the source row(s), correction action,
direct official release/statement URL, and official archive/index URL for every
canonical row. It also retains two excluded source pairs: the Federal Reserve
labels the March 2/3 and March 15, 2020 meetings as unscheduled, so they cannot
be used by this ex-ante scheduled-event strategy. The cancelled March 17-18,
2020 meeting is not fabricated as an event.

Primary sources:

- BLS Employment Situation archive:
  https://www.bls.gov/bls/news-release/empsit.htm
- BLS Consumer Price Index archive:
  https://www.bls.gov/bls/news-release/cpi.htm
- BLS Producer Price Index archive:
  https://www.bls.gov/bls/news-release/ppi.htm
- Federal Reserve historical FOMC materials:
  https://www.federalreserve.gov/monetarypolicy/fomc_historical_year.htm
- Federal Reserve current meeting calendars and statements:
  https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm

Regenerate from the audited shared-calendar hash:

```powershell
& .\framework\EAs\QM5_20023_idx-macro-announce-day\build_strategy_calendar.ps1
```

Add `-VerifyBlsArchiveIndexes` to recheck every BLS date against the three live
archive indexes. That optional verification is intentionally not required for
normal deterministic regeneration.

After review, provision the uniquely named runtime file to MT5 `Common\Files`
with the hash-checking helper. This does not modify a terminal directory or the
shared `news_calendar_2015_2025.csv`:

```powershell
& .\framework\EAs\QM5_20023_idx-macro-announce-day\provision_strategy_calendar.ps1
```
