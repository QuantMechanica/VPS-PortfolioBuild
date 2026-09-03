# FX market-neutral frontier guarded stop — 2026-09-03 01:22:36Z

## Outcome

No EA, registry, queue, portfolio-gate, live manifest, terminal, or AutoTrading
state was changed.

The two requested repair anchors are already resolved by canonical logical-basket
Q02 PASS rows. The completed 66-pair cointegration census is still fully
represented, so it was not repeated. A narrow reconciliation of the research
frontier and approved-card inventory found no additional low-frequency,
market-neutral FX relationship that can lawfully be built without either
duplicating an existing lineage or making an unratified data/architecture
decision.

## Anchor preflight

Read-only `farmctl work-items` queries against
`D:/QM/strategy_farm/state/farm_state.sqlite` returned:

| EA | Logical Q02 row | Current state | Downstream state |
|---|---|---|---|
| `QM5_12532` | `e4890d77-b865-4a48-b946-315faefca920` | `done / PASS` | Q04 PASS, then Q05 FAIL |
| `QM5_12533` | `76cb11ee-7e9d-4d75-be9d-626c205bca62` | `done / PASS` | Q04 FAIL |

Historical ONINIT, NO_HISTORY, launch-fault, and per-leg rows remain in the
append-only ledger, but they do not supersede the later logical-basket PASS
rows. Neither anchor has a pending or active repair row.

## One additional compliant sleeve audited

`QM5_20292_fx-carry-unwind` is the only existing approved sleeve found in the
narrow frontier that satisfies the substantive request: reputable Tier-A FX
source, symmetric two-leg package, D1/weekly cadence, expected 4–12 packages per
year, logical basket manifest, and fixed-risk preset.

Its current package is already complete and identity-bound:

| Artifact | SHA-256 |
|---|---|
| Approved Strategy Card | `3e004d64182dac8325e5032bb8e33beb804842d4fd908f3cfae5620692c09c39` |
| Basket manifest | `60d7bea45d6a700f95c32ace8535c76b62fad616abb19bfa46ac53b4320c4d23` |
| MQ5 | `845f638d46b66968705f6ee4226d28fd078f699f96425551b0536f4c39481199` |
| EX5 | `614d5b7adb051a4d1a51acbbd78b733ad8ccfcb6fa56aa78835de471a4eb9e6c` |
| Logical D1 setfile | `8a1cee7c2c76d9dfde076227459bcec07b12138c8ff03bf8c637be95d6ce3d8d` |

The preset explicitly binds `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The latest logical Q02 row,
`257d153d-a880-4431-8661-e4d736676ecb`, is terminal
`done / ZERO_TRADES`. Its authenticated run covered 2018-07-02 through
2022-12-31 on real ticks, used the hashes above, initialized successfully,
loaded all six traded and seven signal histories, and produced exactly **0
trades**. The report SHA-256 is
`f2433d8f941397cd2736fcc16bb8435a0ae1067b3f997a7f25871672530e7462`.

This is not an ONINIT or NO_HISTORY defect. The source requires a comparable
broker-swap rank and deliberately fails closed when swap metadata is absent,
zero, or incomparable. The canonical venue-cost model still records historical
swap inputs as unresolved for every symbol, and the multicurrency research
survey explicitly rejects reading a current swap snapshot retroactively as a
historical carry series. Substituting static rates, momentum, or invented swaps
would cross the approved card boundary. A duplicate Q02 rerun of the same
binary/data contract therefore has no evidentiary value.

## Beyond-scan frontier reconciliation

- The 66-pair scan remains exhausted: 66 relationships are represented by 123
  approved cointegration identities/directories. No second scan was run.
- The recommended `MC-01 FX8 XSMOM 6/1` family is not a clean new identity.
  Research requires MC-R0 lineage reconciliation and OWNER/QB choices for
  logical-basket architecture, frequency counting, windows, and canonical
  construction; nearby implementations already exist as `QM5_10717` and
  `QM5_1111`.
- `QM5_40002` was already classified as a duplicate of the D1 FX momentum
  family (`QM5_1111` / `QM5_10717`).
- FX carry remains blocked on certified point-in-time historical swap/rate
  inputs; FX value remains blocked on point-in-time REER; the month-end FX card
  is killed as specified; `QM5_37001` and `QM5_34008` have unresolved card
  mechanics and also exceed the requested low-frequency boundary.
- The already-built White–Okunev FX7 cross-sectional package (`QM5_1224`) has a
  terminal logical Q02 FAIL, so a no-change rerun would improperly requalify an
  economic result.

## Existing non-duplicate Q02 handoffs

The current-binary logical rows below were already priority-bound before this
audit and remain pending/unclaimed. Creating another row would be a duplicate:

| EA | Work item | Logical symbol | Fixed risk |
|---|---|---|---:|
| `QM5_10717` | `65319749-3c0b-4636-9131-305c34100a08` | `FX8_BASKET_D1` | USD 1,000 |
| `QM5_10718` | `31f12573-d903-4386-a857-cad2b445d63a` | `QM5_10718_FX8_BASKET_D1` | USD 500 |
| `QM5_12507` | `547c4fd3-f3fd-4c59-b9dc-654e96521251` | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` | preset-bound |
| `QM5_12512` | `acbad967-bf94-4565-9e51-db193de01bf9` | `QM5_12512_FX_PAIRS_THRESHOLD_H1` | preset-bound |

At 2026-09-03 01:22:57Z all ten factory worker processes were present; five MT5
lanes were actively reserved, with no duplicate workers or orphaned terminal
processes. Manual dispatch while factory automation is running is prohibited by
the operating rules, so the ordinary worker remains the correct executor.

## Capacity check

Five whole-host CPU samples at 2026-09-03 01:22:36Z were 96.0981%, 92.8826%,
96.2137%, 83.3067%, and 79.8077% (average 89.6618%, maximum 96.2137%). Both
measures were strictly below the 97% hard ceiling, but the margin was only 0.7863
percentage points. No additional MT5 load was started.

## Resume contract

1. Let an ordinary worker claim one of the already-priority-bound logical Q02
   rows when a governed lane and the CPU/RAM hysteresis permit it; do not enqueue
   or manually claim a duplicate.
2. To mechanize a genuinely new FX relationship, first ratify the MC-R0 choices
   in `docs/research/MULTICURRENCY_STRATEGY_SURVEY_2026-07-15.md`, preferably by
   selecting the existing `QM5_10717` lineage rather than allocating another EA
   ID.
3. Resume `QM5_20292` only after a certified point-in-time historical carry
   input exists and the card/data contract is versioned accordingly; otherwise
   retain the honest zero-trade result.

Open portfolio/factory context remains in
`docs/ops/OPEN_ITEMS_STATUS.md`. This receipt does not change any portfolio
admission, KPI, Q08-contribution, T_Live, or AutoTrading surface.
