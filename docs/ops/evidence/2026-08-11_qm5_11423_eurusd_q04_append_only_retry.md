# QM5_11423 EURUSD Q04 Append-Only Retry

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: advance one existing reputable-source, low-frequency structural FX
card after the frozen 66-pair cointegration scan was confirmed exhausted. No
tester dispatch, live action, or portfolio-gate action was performed.

## Outcome

`QM5_11423_williams-naked-close-stop-entry-d1` now has exactly one pending
append-only Q04 walk-forward retry for `EURUSD.DWX`:

- current Q02 PASS: `f9869e77-3351-4f50-808b-ee09dc482c90`;
- later same-binary Q03 PASS: `ef6393d8-a9c1-4044-bf3f-057a6670501a`;
- preserved Q04 infrastructure row:
  `63bdb912-fa81-4e5a-917d-6340571f0adf`;
- new Q04 retry: `4e7ab520-68b5-4e4b-a641-252b29310492`; and
- verification state: `pending`, unclaimed, attempt count 0.

The guarded enqueue created one row, requeued zero rows, and skipped zero
rows:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm `
  enqueue-backtest --ea QM5_11423 --phase Q04 `
  --from-work-item-id ef6393d8-a9c1-4044-bf3f-057a6670501a `
  --append-only-rerun-of 63bdb912-fa81-4e5a-917d-6340571f0adf `
  --rerun-reason "OWNER 2026-08-11 forex-book fallback: preserve terminal Q04 NO_HISTORY evidence and retry exact current-binary EURUSD D1 sleeve after later same-binary Q03 PASS proved 2024 history and fresh sub-ceiling capacity sample." `
  --expected-current-ex5-sha256 b199066285dc43c3d869fd0f7dd3eb82bb7fd88faf24113ffafedaf78270e1ef
```

Normal paced workers own any later claim and execution.

## Frontier and Fallback Selection

The governed frozen scan is already mechanized through all 66 ranked
relationships. The two requested anchors are not Q02 setup repairs:

- `QM5_12532` has logical-basket Q02 PASS and Q04 PASS, followed by Q05
  FAIL; and
- `QM5_12533` has logical-basket Q02 PASS, followed by Q04 FAIL.

Creating another pair Card, EA allocation, setfile, or manifest would
duplicate an existing relationship. A logical-manifest reconciliation also
found no unused pure-FX basket that was safe to queue: the valid D1 FX8
fallback `QM5_10717` is governed by a dedicated-free-T9/T10 serial recovery
contract, while both terminals were reserved or occupied; the other unused
logical manifests are incomplete legacy packages or duplicate already-built
pairs.

`QM5_11423` was therefore selected under the mission's existing-forex-card
fallback. Its approved Card cites Larry Williams' *Inner Circle Workshop
Trading Method*. It has G0 `APPROVED`, R1-R4 `PASS`, no indicators, no ML,
and deterministic closed-D1 OHLC rules: a naked-close reversal pattern,
day-only stop entry, signal-bar stop, and fixed 2R target. The EURUSD preset
is a backtest preset with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Current-Binary and Evidence Binding

The source, binary, and preset still match the exact bindings used by the
successful Q02 and Q03 runs:

| Artifact | SHA-256 |
|---|---|
| Approved Card | `57fa9ac7a31501a91b12143ee7c322892ac322dc0f7c6a697e96ee1bce64074c` |
| MQ5 | `28ddd1fd89bf558c9124521692fc4ecb3ecc4338405b55c84db9b794e12f85a5` |
| EX5 | `b199066285dc43c3d869fd0f7dd3eb82bb7fd88faf24113ffafedaf78270e1ef` |
| EURUSD backtest setfile | `c5778cf118fcb43dd9ad6f7f98ddb8f404960e8f170212c8781e725817648dcc` |
| Q02 summary | `956a4a60f88fdc700b17cd1e323512781cb003f77f2b94714263ed781e3c3ba2` |
| Q03 summary | `fdfdda10720e60167fa6c8695a6541bc5593728a27014cc99b75273fd0fbdb38` |
| Preserved Q04 aggregate | `f52009279dbc2db3c98a6d28bc9253b819a6e5989ec4cffff8d4951e99f2a393` |

The Q03 run completed after the Q04 infrastructure row and proved the same
binary and preset could read EURUSD 2024 history deterministically: two valid
runs, 18 trades each, with identical reports. The preserved Q04 aggregate is
not a strategy verdict. Folds F1 (2023) and F2 (2024) ended `NO_HISTORY` with
zero bars and empty report identity, while F3 (2025) completed with 12 report
trades and PF 1.78. A complete rerun may still produce a genuine strategy
failure; this enqueue makes no performance or certification claim.

Evidence paths:

- Q02:
  `D:/QM/reports/work_items/f9869e77-3351-4f50-808b-ee09dc482c90/QM5_11423/20260807_085743/summary.json`
- Q03:
  `D:/QM/reports/work_items/ef6393d8-a9c1-4044-bf3f-057a6670501a/QM5_11423/20260807_124946/summary.json`
- preserved Q04:
  `D:/QM/reports/pipeline/QM5_11423/Q04/EURUSD.DWX__63bdb912-fa81-4e5a-917d-6340571f0adf/aggregate.json`

## Capacity, Duplicate Guard, and Safety

The immediate pre-enqueue `farmctl mt5-slots` sample at
`2026-08-11T16:16:08+02:00` found two running factory terminals, `T3` and
`T10`, below the binding seven-terminal ceiling. `T_Live` and the external
FTMO process were excluded from the factory count and were not controlled.

Immediate readback found exactly one pending/active row for the same
EA/phase/symbol/setfile and exactly one row citing the preserved Q04 item
through `append_only_rerun_of_work_item`. No dispatch tick, tester, terminal
reservation, terminal process, or backtest was started manually.

No Card, EA source, binary, setfile, registry, portfolio-admission path,
portfolio KPI, Q08-contribution path, deploy manifest, live setfile,
`T_Live` file, or AutoTrading state was changed. Existing unrelated worktree
changes were left untouched.
