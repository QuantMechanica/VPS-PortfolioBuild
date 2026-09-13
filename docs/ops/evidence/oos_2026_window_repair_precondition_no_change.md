# OOS-2026 window repair — precondition unmet (tasks 1721f3a1 / 49a8c88b)

This is the canonical, non-timestamped evidence artifact for the recurring
orchestration-cycle recheck of tasks `1721f3a1-a129-405a-9749-bab08fe695d3`
("OOS-2026 confirmation window repair") and `49a8c88b-a8bb-4d54-8072-793a5a0336fb`
("DEC E4: apply the OOS-2026 window repair"). Both share the identical blocker.
Per the no-change dedupe protocol, this file is written once per distinct
blocker-state hash and reused across cycles that observe the same state —
no new timestamped file per cycle.

## Blocker (stable fact, re-verified 2026-09-13)

`D:/QM/data/news_calendar/news_calendar_2015_2025.csv` carries **zero rows**
between 2025-04-07 (last row before the gap) and 2026-07-20 (first row after
the gap). The OOS-2026 campaign window (2026-01-01 to 2026-04-06) falls
entirely inside this gap. Task acceptance requires "once the calendar backfill
covers 2026-01..04" — that backfill has not landed. Identical finding as
2026-09-05, 2026-09-07 (E1-D full-scope seal `NOT_READY_FAIL_CLOSED`), and
four consecutive 2026-09-12 rechecks (10:19Z / 10:35Z / 11:05Z / 11:18Z).

`repair-oos-window --apply` (`wf_1e969f7f`) is correctly withheld: applying it
now would produce successor rows measured against a window with zero real
news-calendar coverage — the exact outcome the 2026-09-05 OWNER Vorlage
flagged as unacceptable. No action taken; both tasks correctly stay
`IN_PROGRESS`.

## Machine-readable state

See the reserved dedupe marker for the exact canonical JSON bound to this
artifact: `D:/QM/strategy_farm/state/orchestration_no_change/claude/<task_id>/<state_sha256>.json`.

## Recompute

```
python -c "
import pandas as pd
df = pd.read_csv(r'D:/QM/data/news_calendar/news_calendar_2015_2025.csv', usecols=['datetime'])
df['datetime'] = pd.to_datetime(df['datetime'])
print('rows_in_oos2026_window', len(df[(df['datetime']>='2026-01-01')&(df['datetime']<'2026-04-07')]))
print('max_before_2026', df[df['datetime']<'2026-01-01']['datetime'].max())
print('min_after_2026', df[df['datetime']>='2026-01-01']['datetime'].min())
"
```

Unsticking either task requires scheduling the 2026 Q1 news-calendar backfill
— a prioritization decision outside a single orchestration cycle's authority.
