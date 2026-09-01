# QM5_10309 EURUSD/GBPUSD cointegration Q04 append-only retry

**Recorded:** 2026-09-01 19:02:56 UTC

**Branch:** `agents/board-advisor`

**Outcome:** one exact logical-basket Q04 successor queued; no pipeline verdict claimed

## Selection

The governed 66-pair scan has no unbuilt survivor left to mechanize. Its only
two positive-beta survivors are already built and past Q02:

- `QM5_12532` AUDUSD/NZDUSD: Q02 `PASS`, Q04 `PASS`, Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY: Q02 `PASS`, Q04 `FAIL`.

The cross-ledger duplicate guard also establishes that all five strict
sign-aware qualifiers are built with terminal Q02 evidence. Creating another
scan-derived card would duplicate governed work, so the mission fallback was
used.

The selected existing card is `QM5_10309`, a concrete EURUSD/GBPUSD logical
basket. It is suitable for this fallback because:

- the approved card cites Hanson and Hall's SSRN paper at
  `https://ssrn.com/abstract=2147012` and records R1-R4 `PASS`;
- the mechanics are structural, deterministic OLS/cointegration residual
  reversion with no ML or banned indicator;
- the expected cadence is 12 packages per year, despite its M15 observation
  grid; and
- `basket_manifest.json` binds the one logical sleeve to GBPUSD as tester host
  plus EURUSD as the foreign leg. Physical single-symbol rows are explicitly
  invalid evidence for this strategy.

## Existing funnel state

The canonical logical Q02 predecessor
`ad8765e4-20ba-4178-b339-9b6c7f7c8bc1` remains `done/PASS`. Its recorded
report has aged out, but the farm row and lineage remain canonical.

The only prior logical Q04 row,
`13ccb8fb-6d23-4ba1-851b-52ad8dd77d00`, remains `done/INFRA_FAIL` with reason:

```text
F1:invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,INCOMPLETE_RUNS,M0_1970_PERIOD,RUN_STATUS_INVALID
```

Its recorded aggregate does not exist and its retained work-item tree contains
zero files. This is an infrastructure result without usable economic evidence,
not a Q04 strategy rejection. Before this action there was no open logical Q04
row and no append-only descendant of that source.

## Identity and risk preflight

`validate_symbol_scope.py --ea QM5_10309_cointeg-hft-pairs` returned
`BASKET_OK` with zero violations. The exact current execution identity is:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `63f6d5ffe3c85597f6297e2e8cdf28df3367f51e1569cb2570e05dcdb3dd7c64` |
| EX5 | `6525626a9564a96dd091f4c03ac61490fb67c62a294d712fb78c32cb78720654` |
| Logical backtest setfile | `fd6dd79e7b5d3710f9f72842e7eda28543281ea6641c8f9f94b0a0e9be71bdf2` |
| Basket manifest | `e13f5101b23a434f172e37dee64a1a8569848953e8b9887da6e75a1e9e8f8f7d` |

The logical backtest setfile binds `GBPUSD.DWX` / M15 / magic slot 1 and uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The skip-compile build check correctly refused ad-hoc operation while the live
factory owned active terminal processes. No compile or binary replacement was
needed: the enqueue guard authenticated the current EX5 hash above.

## Admission and queue action

Immediately before enqueue, the five-sample whole-host CPU window was
`[35.358289, 29.082385, 37.897002, 36.073899, 30.475987]` percent: average
`33.777512%`, peak `37.897002%`, against the explicit `97%` ceiling. The ceiling
was not hit.

The canonical enqueue path created exactly one row:

| Field | Value |
|---|---|
| New work item | `84b97968-d2a2-4099-9576-3d90f00dadcf` |
| EA / logical symbol | `QM5_10309` / `QM5_10309_EURUSD_GBPUSD_COINTEG_FX` |
| Phase / contract | Q04 / v4 |
| State at post-check | `pending`, unclaimed, verdict unset, attempt 0 |
| PASS predecessor | `ad8765e4-20ba-4178-b339-9b6c7f7c8bc1` |
| Preserved rerun source | `13ccb8fb-6d23-4ba1-851b-52ad8dd77d00` |
| Fold budget | 3 folds, 25,200 seconds each; outer timeout 1,275 minutes |
| New payload SHA-256 | `2150eaf788c399f2b54cb326bcab755504b81d9af0995126941ace83cd8c6779` |

Post-check found exactly two logical Q04 rows: the preserved terminal
infrastructure result and this one append-only successor. The new payload binds
the current MQ5, EX5, setfile, basket manifest, host/timeframe, both basket
symbols, Q02 predecessor, and exact rerun source. No physical-leg Q04 row was
reused or changed.

The governed priority-track controller is deliberately Q02-only and bound to a
separate OWNER registry. It cannot annotate this Q04 row, so no direct SQLite
priority edit was performed. The row remains owned by normal paced-fleet claim
ordering; no dispatch tick or manual tester was launched.

## Operational and safety notes

An attempted online SQLite backup made no timely progress and was stopped
before enqueue. Its partial 64,798,720-byte output was retained and renamed
with the suffix `.incomplete_aborted`; it was not represented as restorable.
A fresh pre-existing full 734,773,248-byte backup from 18:37 UTC was available.

- No strategy mechanics, card, EA source, binary, setfile, manifest, registry,
  or magic allocation changed.
- No `T_Live` process or manifest was controlled, and AutoTrading was not
  toggled.
- No portfolio admission, portfolio KPI, Q08 contribution, portfolio gate, or
  deploy artifact was touched.
- The separately observed `T_Live` and FTMO terminals were excluded from all
  factory control.
- This is queue-admission evidence only. Q04 remains pending and no economic or
  pipeline PASS is inferred.

Machine receipt:
`artifacts/qm5_10309_fx_cointegration_q04_append_only_retry_20260901.json`
(SHA-256
`0fcf32dd30399d5e41643f6422dda0f1a753413eb6fc5b308b447a8d7e94c753`).
