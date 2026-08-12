# QM5_20195 NZDUSD/EURGBP FX Cointegration Q04 Append-Only Retry

Date: 2026-08-10 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: advance one existing low-frequency structural FX basket after confirming
that the frozen 66-pair scan has no unbuilt relationship. No tester dispatch,
live action, or portfolio-gate action was performed.

## Outcome

`QM5_20195_nzd-eurgbp-coint` now has exactly one pending append-only Q04
walk-forward retry behind its current-binary logical Q02 PASS:

- logical symbol: `QM5_20195_NZDUSD_EURGBP_COINTEGRATION_D1`;
- traded legs: `NZDUSD.DWX` and `EURGBP.DWX`;
- conversion-history-only symbols: `GBPUSD.DWX` and `EURUSD.DWX`;
- current Q02 PASS predecessor: `5b51938b-04ab-47fa-9cf9-a833d7498984`;
- preserved terminal Q04 infrastructure row:
  `9a95577b-9872-4757-8966-3af71a463224`;
- new Q04 retry: `b14b5edf-ffdd-4439-a2ed-dc4930d65029`; and
- verification state: `pending`, unclaimed, attempt count 0.

The guarded cascade created one row, requeued zero rows, and skipped zero rows:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm `
  enqueue-backtest --ea QM5_20195 --phase Q04 `
  --from-work-item-id 5b51938b-04ab-47fa-9cf9-a833d7498984 `
  --append-only-rerun-of 9a95577b-9872-4757-8966-3af71a463224 `
  --rerun-reason "OWNER 2026-08-10 forex-book fallback: preserve terminal Q04 INFRA_FAIL evidence and retry exact current-binary NZDUSD/EURGBP logical basket after fresh sub-ceiling capacity sample." `
  --expected-current-ex5-sha256 909c1622e913fa77129aad70ece7529d7a073b9c421791c743ed86775a0b6cf6
```

Normal paced workers own any later claim and execution.

## Selection and Duplicate Guard

The current frontier reconciliation in
`docs/research/FX_COINTEGRATION_FRONTIER_Q02_CPU_CEILING_STOP_2026-08-07.md`
shows that all 66 relationships in the frozen scan are already mechanized.
Rank 65 is an explicit pair slot in `QM5_1156`, and rank 66 is the dedicated
`QM5_12803` basket. Creating another Card, EA ID, magic allocation, setfile, or
basket manifest would duplicate governed work.

The preferred anchors are not Q02-blocked:

- `QM5_12532` has logical Q02 PASS and Q04 PASS, followed by Q05 FAIL; and
- `QM5_12533` has logical Q02 PASS, followed by Q04 FAIL.

`QM5_20195` was selected as the existing-card fallback because it is a
dedicated D1 FX cointegration basket with current-binary Q02 PASS and only an
infrastructure-invalid Q04 result. The original Q04 evidence is immutable;
the new row cites it through `append_only_rerun_of_work_item`. One older Q03
row remains pending and was not changed. No Card, build, Q02 row, or terminal
strategy verdict was duplicated.

## Source, Structure, and Risk Preflight

The approved Card has `status: APPROVED` and `g0_status: APPROVED`. It cites
the OWNER-ratified Tier-A extraction of Ernest P. Chan, *Quantitative Trading*
(Wiley, 2009), preserved at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Pair selection
is the frozen Darwinex D1 scan's rank-12 NZDUSD/EURGBP row; Chan does not make
a performance claim for this relationship.

The strategy remains a fixed-beta, closed-D1 residual-reversion package with
no learned model, online refit, banned indicator, grid, martingale, pyramiding,
or rescue parameter change. The logical backtest setfile remains:

- `RISK_FIXED=1000`;
- `RISK_PERCENT=0`;
- `PORTFOLIO_WEIGHT=1`; and
- `environment=backtest`, timeframe D1.

| Artifact | SHA-256 |
|---|---|
| MQ5 | `23ce5192a6faf318345ca6ae5561a206c4cd15a6d24e7ccdf5cbfb4e41d74496` |
| EX5 | `909c1622e913fa77129aad70ece7529d7a073b9c421791c743ed86775a0b6cf6` |
| Basket manifest | `a51f1083ee914d4c032da40233aedaa64118998f917e17f0966f365de1799c29` |
| Logical backtest setfile | `585f398945b2aa596b1a68994c02eaba1a829d90fbd95a3f55ca6b87ba7d99a9` |

The pending payload binds the same MQ5, EX5, setfile, expert
`QM\\QM5_20195_nzd-eurgbp-coint`, host `NZDUSD.DWX`, and D1 period.

## Q02 and Preserved Q04 Evidence

The exact Q02 predecessor evidence is:

`D:/QM/reports/work_items/5b51938b-04ab-47fa-9cf9-a833d7498984/QM5_20195/20260802_170921/summary.json`

It records a current-binary Model-4 PASS over 2018-07-02 through 2022-12-31:
72 trades, PF 1.18, net profit 1,631.76, drawdown 3,551.82, `reason_classes`
`[OK]`, and stable execution bindings. Its SHA-256 is
`ebaaf115c4743f1eb588411f40785f45eacd6b0c99bd9d8f5136dc6a938506e3`.

The preserved Q04 aggregate is:

`D:/QM/reports/pipeline/QM5_20195/Q04/QM5_20195_NZDUSD_EURGBP_COINTEGRATION_D1__9a95577b-9872-4757-8966-3af71a463224/aggregate.json`

Folds F1 and F2 were invalid with `BARS_ZERO`, empty report identity, and
incomplete runs. F3 executed normally with 8 trades and net PF approximately
0.752. The aggregate therefore ended `INFRA_FAIL`, not as a complete Q04
strategy verdict. Its SHA-256 remains
`36d6dfd05e111e29326e7507912deb664cfd8482af18888173467f9bae1dfab9`.
The retry changes no strategy mechanics and may still produce a genuine
strategy failure when all folds complete.

## Capacity and Safety

The immediate pre-enqueue `farmctl mt5-slots` sample at
`2026-08-10T13:08:29+02:00` found five running factory terminals:

```text
T3, T4, T5, T8, T10
```

Five is below the binding seven-terminal paced-fleet ceiling. `T_Live` and the
external FTMO terminal were observed separately and excluded. The enqueue did
not invoke a pump or dispatch tick, reserve a terminal, launch a tester, or
control any process.

At verification, the same-EA inventory contained three preserved Q02 PASS
rows, one untouched Q03 pending row, one preserved Q04 `INFRA_FAIL`, and one
new Q04 pending row. `T_Live`, AutoTrading, deploy manifests, live setfiles,
portfolio admission, portfolio KPI, and Q08-contribution paths were not
changed.

Machine-readable evidence:
`artifacts/qm5_20195_fx_cointegration_q04_append_only_retry_20260810.json`.
