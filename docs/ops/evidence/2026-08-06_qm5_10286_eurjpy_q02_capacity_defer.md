# QM5_10286 EURJPY Q02 infrastructure-recovery handoff

Date: 2026-08-06
Router task: `0035013b-f66a-445a-bb6c-14466f88c63f`
Source work item: `3ccc88e6-c17b-4317-993d-93d8dc8ae9f7`
EA / symbol: `QM5_10286_cinar-supertrend` / `EURJPY.DWX`
Disposition: `VERIFIED_BINDINGS_Q02_REENQUEUE_DEFERRED_CAPACITY`

## Scope and finding

The router requested verification of the row-bound artifacts followed by an
append-only Q02 enqueue only when CPU and terminal capacity were below the
factory ceiling. The source result is infrastructure-only, not an economic
pipeline verdict: its retained `summary.json` reports three invalid attempts
with `BARS_ZERO` / `INCOMPLETE_RUNS`, while `oninit_failure_detected=false`,
`log_bomb_detected=false`, and `news_calendar.status=OK` with the sanctioned
336-hour maximum.

The current canonical MQ5, EX5, and EURJPY backtest setfile exactly match the
expected hashes bound into the failed row:

| Artifact | SHA256 |
|---|---|
| MQ5 | `c526193c85700bd696ed1c234164ac344eb8a1b141c1777d2a3c67791c2d09ca` |
| EX5 | `f895bcd791a74c73e5f572f80cab82f5f1cea6658e7cad3ee6c56ac8d71aafd4` |
| EURJPY setfile | `4de5518d1d8f4fda0a49b34883c30b55db3fbf16992495a7f3e3ea5232947ad3` |

The setfile retains the required backtest contract:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `qm_filter_news_enabled=1`
- `qm_filter_news_mode=3`

No source, binary, setfile, history, live configuration, portfolio gate, or
existing work-item row was changed.

## Capacity decision

At `2026-08-06T09:11:18Z`, `farmctl.py mt5-slots` showed governed tester
activity on T1 through T9. A simultaneous host sample reported 91% CPU. The
database snapshot contained ten active phase rows: two Q02, one Q04, six
Q09_NEWS, and one Q09_PORTFOLIO. The terminal workers were alive on T1-T10,
and no orphan terminal process or duplicate worker was reported.

This is above the task's permitted enqueue boundary. Consequently no
append-only replacement Q02 row was created and no tester was launched or
interrupted. The prior `failed/INFRA_FAIL` source row remains immutable. A
future deterministic router task may enqueue one new bound EURJPY Q02 row
after both CPU and terminal occupancy are below the ceiling.

## Focused verification

- Retained summary identity: expert, symbol, D1 period, 2018-07-02 through
  2022-12-31, EX5, MQ5, and setfile bindings present and internally consistent.
- Current file hashes: exact match to all three expected row bindings.
- Risk/news setfile checks: fixed-risk and mandatory news filter preserved.
- Queue check: no pending or active `QM5_10286` / `EURJPY.DWX` Q02 replacement
  was present at inspection time.
- Safety: no T_Live or AutoTrading action, no manual `terminal64.exe` start, no
  history reimport, no queue mutation, and no active backtest interruption.

This document records an operational capacity deferment only. It does not
claim a Q-phase PASS or other pipeline verdict.
