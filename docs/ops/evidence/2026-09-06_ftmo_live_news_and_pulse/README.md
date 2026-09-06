# FTMO M13 live-news enforcement and pulse repair — 2026-09-06

Task: `93c1d29c-05e6-47fb-9edd-4bad35fabda0`
Disposition: implementation complete; leave in `REVIEW` for independent close-out.

## Read-only terminal evidence

Terminal data hash: `81A933A9AFC5DE3C23B15CAB19C63850`. No terminal,
account, chart, preset, or AutoTrading state was changed during this work.

- `config/common.ini` reported `NewsEnable=1`; `config/terminal.ini` reported
  `[CalendarList] Realtime=1`. The visible configuration therefore does not say
  that the calendar is disabled.
- The governor's logger was still unconfigured during its bootstrap attach, so
  its native probe is in `MQL5/Files/QM/QM5_0000_unconfigured.log`, not a
  `QM5_13206` file. At `2026-09-06T19:39:28.390Z` it emitted
  `NEWS_LIVE_CALENDAR_SELFTEST` with `healthy=true`, `window7d_total=216`, and
  next relevant high-impact event `GBP BoE Governor Bailey Speech` at server
  time `2026.09.08 16:15`. A second probe at `19:42:03.421Z` agreed. This is
  direct evidence that the FTMO terminal's native MT5 calendar was populated.
- The active M13 sleeve logs were checked individually for events at or after
  the OWNER activation cutoff `2026-09-06T20:08:00Z`:

  | EA | Fresh native probe | Observation |
  |---|---|---|
  | 10706 | absent | no post-cutoff JSON event; current attach had failed before the symbol-alias repair |
  | 11421 | absent | no post-cutoff JSON event |
  | 11422 | absent | no post-cutoff JSON event |
  | 11910 | absent | no post-cutoff JSON event; current attach had failed before the symbol-alias repair |
  | 13054 | absent | no post-cutoff JSON event |
  | 1537 | absent | clean `INIT_OK` at `20:08:05Z`, but only archive diagnostics were emitted |
  | 20048 | absent | no post-cutoff JSON event |
  | 21505 | absent | no post-cutoff JSON event; current attach had failed before the symbol-alias repair |

  This is an evidence gap per sleeve, not evidence that the calendar is
  disabled. The shared terminal-level governor probe proves population at
  attach time. The framework now invokes `QM_NewsLiveSelfTest(_Symbol)` inside
  live `QM_NewsInit`, before archive reads, so every newly compiled/re-attached
  EA will emit its own probe without waiting for a market tick.

## Decision-path finding

The governor's `QM_NewsInit("D:\\QM\\data\\news_calendar", ...)` argument is
archive initialization for tester data and live diagnostics; it is not the live
authorization source. `NewsAllowsAccount` calls `QM_NewsAllowsTrade2` for each
governed symbol. In non-tester mode that function calls both
`QM_NewsLiveTemporalAllows` and `QM_NewsLiveComplianceAllows`, backed by
`CalendarValueHistory`. If either native query/metadata path is unavailable it
logs `live_calendar_unavailable`, sets the verdict false, and therefore applies
a temporary account-level entry blackout. `QM_NewsAllowsTrade2Fresh` has the
same fail-closed contract. Archive availability cannot produce a live allow.

`tools/strategy_farm/live_news_dependency_check.py` resolves each live-capable
EA's include closure and enforces that contract. `build_check.ps1` reports any
violation as `EA_LIVE_NEWS_ARCHIVE_DEPENDENCY`. The full corpus probe checked
4,006 live-capable EA sources and the one shared news-filter contract with zero
findings.

## Pulse repair and observed result

`ftmo_trial_pulse.py` now reads the last valid, account-bound `SAMPLE` from
`QM/ftmo_trial/<day>/trial_telemetry_raw.jsonl` without loading the whole file.
A fresh record is the primary equity and open-position source; AccountMonitor
and the EA day-close snapshot are explicitly fallbacks. EA `ERROR`/`FATAL`
events are admitted only when `ts_utc >= 2026-09-06T20:08:00Z`, preventing
failed pre-activation attach history from alarming the active book.

Read-only function probe at `2026-09-06T20:35:03Z`:

- source: `ftmo_trial_collector_raw`
- sample timestamp: `2026-09-06T20:35:03Z` (age 0.006 minutes)
- balance/equity: `100000.00 / 100000.00`
- open positions / pending orders: `0 / 0`
- post-activation EA errors: none

## Verification

- `python tools/strategy_farm/live_news_dependency_check.py --repo-root C:/QM/repo`
  — PASS, 4,006 EA sources, one contract, zero findings.
- Focused pytest suite covering live/fresh fail-closed routing, tester
  degradation, calendar bundle/layout, build predicate, collector precedence,
  and activation-window errors — `47 passed`.
- PowerShell AST parse of `framework/scripts/build_check.ps1` — PASS.

Native terminal execution was neither required nor performed. The existing
running M13 terminal was observed read-only, and active factory terminals were
not interrupted.
