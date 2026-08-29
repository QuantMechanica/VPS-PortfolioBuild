# WTI First-Half-of-Month Short Source Approval - Amendment 1

Date: 2026-08-29

Decision: `APPROVED_SOURCE_AMENDMENT` for one narrow pre-card correction to
`decisions/2026-08-29_wti_first_half_month_short_source_approval.md`.

## Correction

Framework Friday close is `OFF` for this identity. The original approval's
statement that Friday close was ON is superseded; every other source, signal,
risk, lifecycle, falsification, CPU, and safety boundary remains unchanged.

## Reason

The approved information object is the WTI calendar interval from the first
genuine broker-month D1 boundary through the first subsequent D1 session dated
16 or later. A mandatory Friday flatten would terminate almost every package
inside its first week, changing the card into a month-opening/first-Friday
trade and preventing Q02 from testing the approved days-1-through-15 carrier.
Disabling Friday close preserves the exact source-defined holding interval.
The frozen broker hard stop, framework kill switch, malformed-exposure repair,
and 20-calendar-day stale guard remain authoritative.

## Scope

This amendment is effective before card extraction and permits only the same
branch-only non-live card/build, strict Q01, and paced Q02 enqueue. It does not
authorize a manual backtest, terminal control, `T_Live`, AutoTrading, a live
or deploy manifest, portfolio-gate work, portfolio admission, or a correlation
waiver.
