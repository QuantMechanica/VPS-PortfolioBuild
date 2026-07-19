# News CSV column-alignment fix — 2026-07-19

`QM_NewsLoadCsv` previously assumed the headerless layout
`date,time,currency,impact`. Neither production calendar uses that layout:

- `news_calendar_2015_2025.csv` uses
  `datetime,currency,event_name,impact,...`.
- `forex_factory_calendar_clean.csv` uses
  `Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,...`.

The tester therefore loaded rows but assigned event names or EET timestamps as
currencies. The secondary calendar also collapsed event times to midnight and
classified all impacts as `UNKNOWN`. The CSV-backed news filter was effectively
inert even though initialization reported a non-zero row count.

The loader now resolves `DateTime_UTC`/`datetime`, `Currency`, and `Impact` from
the header and parses the UTC timestamp directly. A malformed recognized header
is rejected; the old four-column mapping remains only for genuinely headerless
legacy input.

## Evidence-regime boundary

Pre-fix tester evidence that claimed active CSV news gating belongs to the old,
effectively unfiltered regime. Post-fix backtests genuinely apply the configured
news blackout and are therefore a conservative new evidence regime: trade count,
timing, and verdicts may differ and must not be compared as like-for-like results.

Live trade routing is unchanged. Outside the tester, the framework continues to
use MetaTrader's native economic calendar rather than these CSV files.
