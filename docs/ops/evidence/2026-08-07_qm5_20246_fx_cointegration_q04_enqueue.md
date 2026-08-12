# QM5_20246 USDJPY/EURGBP FX Cointegration Q04 Enqueue

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: advance one existing low-frequency, structural FX cointegration basket
after confirming that the frozen 66-pair frontier contains no unbuilt
relationship. No tester dispatch, live action, or portfolio-gate action was
performed.

## Outcome

`QM5_20246_usdjpy-eurgbp` now has exactly one pending Q04 walk-forward work
item behind its current logical-basket Q02 PASS:

- logical symbol: `QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1`;
- traded legs: `USDJPY.DWX` and `EURGBP.DWX`;
- Q02 PASS predecessor: `d8619249-7764-4d80-a714-6b7922b73b4b`;
- Q04 work item: `1a269ff4-cbef-429b-afa4-47a3cc692916`;
- verification state: `pending`, unclaimed, attempt 0; and
- same-EA phase inventory: one Q02 PASS and one Q04 pending row.

The supported cascade path created one row and reported no skipped or requeued
rows:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm `
  enqueue-backtest --ea QM5_20246 --phase Q04
```

Normal paced workers own any later claim and execution.

## Selection and Duplicate Guard

The current frozen-scan reconciliation in
`docs/research/FX_COINTEGRATION_FRONTIER_Q02_CPU_CEILING_STOP_2026-08-07.md`
shows that all 66 relationships are already mechanized. Creating a new Card,
EA ID, magic allocation, basket, or manifest would therefore duplicate the
governed frontier.

The preferred anchors do not have Q02 setup blockers:

- `QM5_12532` has logical Q02 PASS and Q04 PASS, followed by Q05 FAIL; and
- `QM5_12533` has logical Q02 PASS, followed by Q04 FAIL.

The first documented existing-card fallback, `QM5_11646`, had already advanced
while the paced fleet was working: all five FX symbols now have Q02 PASS and
all five later have Q04 FAIL. `QM5_11755` was considered next, but the
deterministic target-only selector refused its deferred rows with
`requeue_excluded_q02`; that control was not bypassed.

`QM5_20246` was selected instead because it is an existing D1 market-neutral
FX basket from the same frozen scan, has a current terminal Q02 PASS, and had
no Q04 row. Advancing it is the mission's existing-card fallback and does not
repeat a Card, build, Q02 row, or Q04 row.

## Source, Structure, and Risk Preflight

The approved Card cites the OWNER-ratified Tier-A extraction of Ernest P.
Chan, *Quantitative Trading* (Wiley, 2009), preserved at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Pair selection
comes from the frozen Darwinex D1 66-pair scan. The strategy is a fixed-beta,
two-leg residual reversion package with no learned model, online refit, grid,
martingale, pyramiding, or banned indicator.

The logical setfile remains a backtest-only fixed-risk preset:

- `environment=backtest`;
- `RISK_FIXED=1000`;
- `RISK_PERCENT=0`; and
- `PORTFOLIO_WEIGHT=1`.

The basket manifest declares `USDJPY.DWX` as host, `EURGBP.DWX` as the second
traded leg, and `GBPUSD.DWX` plus `EURUSD.DWX` as conversion-history-only
dependencies.

| Artifact | SHA256 |
|---|---|
| MQ5 | `4ee9db9b746599413e00af5f01583252bd8ec9b8440d0509ca25207ea483ec6a` |
| EX5 | `f2384173fdd41e914b48b3098467c9b02a7648494f937f5f027f4e8b45aa6eab` |
| Basket manifest | `63b4084a8522588bb3c3629b12430b4b27efd133472ea24dc5adafff250a66f5` |
| Logical backtest setfile | `94923d6a78f9e2abbc66b4c8b268fb5b5cb9cbdc50c4a24f6c5b1aa7b5bb7cbb` |

No strategy or build artifact changed in this action.

## Q02 Lineage

The current Q02 evidence is:

`D:/QM/reports/work_items/d8619249-7764-4d80-a714-6b7922b73b4b/QM5_20246/20260807_013638/summary.json`

It records one deterministic Model-4 run over 2018-07-02 through 2022-12-31,
136 trades, PF 1.11, net profit 1,610.27, and drawdown 5,814.91 (5.43%). The
run returned `PASS`, `reason_classes=[OK]`, no ONINIT failure, no history fault,
no log bomb, and stable source/deployed binary and setfile hashes.

These Q02 measurements authorize only the next deterministic gate; they are
not a portfolio-admission or live-performance claim.

## Capacity and Safety

The immediate pre-enqueue path-anchored sample at
`2026-08-07T04:51:53+02:00` found five running factory terminals:

```text
T2, T4, T8, T9, T10
```

Five is below the binding seven-terminal paced-fleet ceiling. The enqueue
command did not invoke a pump or dispatch tick, reserve a terminal, launch a
tester, or control an MT5 process.

`T_Live`, AutoTrading, deploy manifests, and live setfiles were not touched.
No `portfolio_admission`, portfolio KPI, Q08-contribution, or T_Live manifest
path was read for mutation or changed.

Machine-readable evidence:
`artifacts/qm5_20246_fx_cointegration_q04_enqueue_20260807.json`.
