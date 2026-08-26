# Paced Fleet Diversity — CPU Ceiling Stop

Date: 2026-08-26 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `NO CLAIM; NO BUILD; NO COMPILE; NO SMOKE; NO Q02 ENQUEUE — BACKTEST CPU CEILING`

## Diversity-first selection and collision guard

The canonical farm database (`D:/QM/strategy_farm/state/farm_state.sqlite`) and
the live approved-card reservoir were read before any claim or EA mutation.
The farm's deterministic `strategy_priority.compute_scores()` ranking was
applied only after excluding cards that already have an EX5, cards without
ready EA/magic registry contracts, and EAs with a pending/active legacy
`build_ea` task.

The highest-ranked remaining diversity candidate was:

| Field | Value |
|---|---|
| EA | `QM5_36005_nnfx-coral-trendlord-woodies-harvester` |
| Farm priority score | `38.64` |
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_36005_nnfx-coral-trendlord-woodies-harvester.md` |
| G0 / R gates | `APPROVED`; R1-R4 `PASS` |
| Instruments | `GBPJPY.DWX`, `EURJPY.DWX`, `AUDNZD.DWX` |
| Timeframe / frequency prior | `D1`; `25` trades/year/symbol |
| Registry state | EA row active; slots `0..2` active; resolver-ready |
| Pipeline state | no Q02 work items |

This is materially more diverse than another index/metal/energy build: it adds
two JPY crosses plus an AUD/NZD cross, and its frequency prior clears the
canonical Q02 floor of five trades/year/symbol.

The candidate is a narrow governed rebuild rather than a greenfield source
rewrite. Source and three backtest setfiles exist, but no current EX5 exists.
The latest independent review task
`ddb87b6b-a6db-4f8d-be8f-337341238a8c` is in `RECYCLE` because the setfile and
evidence build hashes did not bind to the committed MQ5 bytes. The most recent
source rework is commit `b4cd70953`; the next permitted unit is therefore:
regenerate hashes against committed bytes, strict compile/build validation,
then append-only Q02 handoff. Strategy mechanics must remain unchanged.

Collision exclusions recorded in the same DB read:

- `QM5_41011_tokyo-london-bank-flow-handover` already carries a paced-fleet
  claim (`claimed_by=codex:agents/board-advisor`).
- `QM5_9507_carver-breakout` already carries a distinct paced claim
  (`claimed_by=codex-headless-paced`).

No claim was taken for `QM5_36005`; a later agent must repeat the atomic DB
collision check before advancing it.

## Capacity evidence

At `2026-08-26T03:53:57.0252946Z`, five consecutive whole-host CIM processor
samples were:

```text
100.0, 100.0, 100.0, 100.0, 100.0 percent
```

Average and maximum were both `100.0%`.

The immediately following canonical `farmctl.py mt5-slots` census was scanned
at `2026-08-26T03:53:57Z` and found six governed factory terminals running:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T2 | `QM5_10513` | pipeline runner | runner-bound |
| T3 | `QM5_20161` | Q03 | `QM5_20161_XAUUSD_XAGUSD_OLS_D1` |
| T4 | `QM5_12823` | Q07 | `USDJPY.DWX` |
| T6 | `QM5_12708` | Q10_NEWS | `XAUUSD.DWX` |
| T7 | `QM5_12354` | Q10_NEWS | `XAUUSD.DWX` |
| T8 | `QM5_12357` | Q10_NEWS | `GDAXI.DWX` |

The census reported no duplicate terminal workers and no orphaned terminal
processes. `T_Live` and the FTMO terminal appeared only in the read-only
process census and were not accessed or changed.

## Safety and next action

The explicit paced-fleet instruction says to stop when the backtest CPU ceiling
is reached. Accordingly, this run created no farm claim, task transition,
registry row, resolver change, EA/source/binary/setfile change, smoke process,
work item, dispatcher tick, portfolio-gate change, deploy-manifest change,
`T_Live` write, or AutoTrading action.

On the next below-ceiling run, recheck the DB claim state and take
`QM5_36005` only if it remains distinct. Use the standard
`codex_build_ea`/`qm-build-ea-from-card` path, preserve the approved mechanics,
bind every generated setfile to the committed source hash, compile strict, and
enqueue only RISK_FIXED Q02 rows.
