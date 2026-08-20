# Paced Fleet Diversity Preflight — CPU Ceiling Stop

Date: 2026-08-21 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `NO CLAIM; NO BUILD; NO ENQUEUE — HARD CPU CEILING`

## Diversity-first backlog and collision preflight

The canonical farm database was read before any mutation. The current legacy
`tasks` build backlog contained no genuinely unbuilt, claimable, low-frequency
diversity row:

- the fresh `QM5_1568`, `QM5_9400`, and `QM5_9450` rows fail the farm's own
  body/frontmatter R2-R4 consistency guard;
- `QM5_32007` is excluded by the canonical FX-only high-frequency guard;
- the sole row returned as claimable by `_build_task_claim_guard`,
  `QM5_11483`, already has a compiled EX5 and Q02 history, so treating it as a
  new build would duplicate completed work; and
- `QM5_41078_xauxag-wstreak3-rv` had received card, EA-registry, and magic
  allocation commits immediately before this preflight. It was left untouched
  to avoid colliding with that paced build activity.

The infrastructure frontier was also read without mutation. A suitable
diverse fallback remains `QM5_1229_carver-statevol` on an untested CHF/CAD FX
cross after its historical pre-isolation `BARS_ZERO` Q02 failure, but no claim
was taken because the mandatory capacity gate failed first. The previously
documented `QM5_1229 / EURCHF.DWX` capacity stop was not duplicated.

## Capacity evidence

At `2026-08-20T23:38:25.3977193Z`, five consecutive whole-host CIM processor
samples were:

```text
100.0, 100.0, 100.0, 100.0, 100.0 percent
```

Average and maximum were both 100%, above the governed 97% ceiling.

The immediately preceding canonical `farmctl.py mt5-slots` census was scanned
at `2026-08-21T01:38:08+02:00` and found six governed factory terminals active:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T1 | `QM5_20085` | Q07 | `WS30.DWX` |
| T2 | `QM5_11179` | Q07 | `XAUUSD.DWX` |
| T3 | `QM5_12350` | Q07 | `USDJPY.DWX` |
| T4 | `QM5_20234` | Q03 | `QM5_20234_XAU_XAG_RSJ_D1` |
| T6 | `QM5_10571` | Q07 | `XAUUSD.DWX` |
| T7 | `QM5_10248` | Q07 | `NDX.DWX` |

The census reported no duplicate terminal workers and no orphaned terminal
processes. `T_Live` and the FTMO terminal were observed only by the read-only
census and were not accessed or changed.

## Safety and handoff

No farm claim, work item, registry row, resolver, Strategy Card, EA source,
EX5, setfile, dispatcher tick, smoke test, pipeline runner, terminal process,
portfolio gate, deploy manifest, `T_Live` file, or AutoTrading state was
created or changed.

A later paced agent should repeat the database collision guard and five-sample
CPU check. Only below the governed ceiling should it claim one distinct
diverse EA and perform an append-only Q02 handoff.
