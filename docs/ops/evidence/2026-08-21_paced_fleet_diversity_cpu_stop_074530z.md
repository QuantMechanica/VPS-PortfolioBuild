# Paced Fleet Diversity Funnel — Hard CPU Stop

Date: 2026-08-21 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `NO CLAIM; NO BUILD; NO ENQUEUE — HARD CPU CEILING`

## Diversity and collision preflight

The canonical farm database was opened read-only and returned
`quick_check=ok`. Its 37 pending `build_ea` rows produced these results through
the canonical `_build_task_claim_guard`:

| Disposition | Count |
|---|---:|
| Q02 excluded | 3 |
| Active blocked marker | 7 |
| Terminal final failure | 18 |
| Card missing | 2 |
| R1-R4 gate not ready | 5 |
| Mechanically eligible | 2 |

Neither mechanically eligible row is a new diversity build:

- `QM5_11483_williams-l-outside-bar-exhaustion-d1`, task
  `557db8df-51ab-4636-b361-58b314813f0b`, already has MQ5 and EX5 artifacts
  plus 16 completed farm work items through Q07. Its five Q02 rows are PASS,
  so treating the legacy pending row as a new build would duplicate completed
  funnel work.
- `QM5_11657_pp-hs-rev`, task
  `593a9825-a8dc-462f-bdda-c00ddb710d58`, remains the useful diversity
  handoff. It already has a strict build, SPEC, and five H4 fixed-risk
  setfiles, but has no work item because its single smoke and `record-build`
  handoff were deferred at an earlier CPU stop. Its pending task retains that
  prior manual-claim/defer evidence; no new claim was added here.

## Binding capacity evidence

From `2026-08-21T07:45:30.4785165Z` through
`2026-08-21T07:45:39.6043692Z`, five two-second whole-host CIM samples were:

```text
100%, 99%, 98%, 86%, 98%
```

Average CPU was 96.20% and maximum CPU was 100.00%. The governed stop rule is
average **or** maximum at or above 97%; the 100% maximum therefore binds even
though the short-window average dipped below the threshold.

The nearby read-only farm snapshot contained 6 active and 2,239 pending work
items. The active rows were:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T2 | `QM5_20234` | Q03 | `QM5_20234_XAU_XAG_RSJ_D1` |
| T3 | `QM5_10280` | Q07 | `XAUUSD.DWX` |
| T4 | `QM5_12365` | Q07 | `XAUUSD.DWX` |
| T6 | `QM5_11172` | Q07 | `XAUUSD.DWX` |
| T8 | `QM5_10163` | Q06 | `SP500.DWX` |
| T10 | `QM5_9641` | Q06 | `SP500.DWX` |

The `farmctl mt5-slots` census at `2026-08-21T07:45:31Z` observed governed
tester processes on T2, T3, T4, and T6. T8 and T10 had newly active SQLite
claims by the later database read but were absent from that earlier process
snapshot; the two observations are deliberately kept separate rather than
presented as atomic. The census reported no duplicate terminal workers and no
orphaned terminal processes. It observed the T_Live process only as read-only
host metadata; T_Live files, terminal state, and AutoTrading were not accessed
or changed.

This is not a copy of the `07:35:42Z` capacity record. In the intervening
window, the sample average fell from 99.28% to 96.20%, the process snapshot
temporarily contracted from six governed terminals to four, and the farm
active set transitioned to two Q06, one Q03, and three Q07 claims. The maximum
still crossed the hard ceiling, so the mission's explicit stop rule remains
binding.

## Stop boundary and continuation

No farm or agent claim, Strategy Card, EA, registry row, magic resolver,
build check, compile, smoke, Q02 enqueue/re-enqueue, priority mutation,
dispatcher tick, terminal reservation, or process-control action was
performed. No portfolio gate, deploy manifest, T_Live file/state, or
AutoTrading state was touched.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260821T074530Z_board_advisor.json`.

After sustained whole-host CPU stays below 97% with maximum headroom, recheck
ownership of `QM5_11657`, run its one standard smoke, then record-build and
enqueue its existing five-symbol H4 `RISK_FIXED` basket exactly once.
