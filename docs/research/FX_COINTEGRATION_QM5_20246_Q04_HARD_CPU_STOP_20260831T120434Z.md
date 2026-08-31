# QM5_20246 FX cointegration Q04 hard CPU stop

Date: 2026-08-31 UTC (`2026-08-31T12:04:34Z`); 14:04 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `e575277c4dfe50b431387fdd9c30120f67b527d1`

Status: stopped at the explicit backtest CPU ceiling. The frozen 66-pair FX
cointegration scan remains fully mechanized, the preferred anchors remain
past Q02, and the one dependency-complete existing fallback remains a unique
pending Q04 row. No Card, EA, work item, queue state, tester, terminal, or
portfolio object was created or changed.

## Governed frontier result

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all
66 FX relationships. The current approved-card census has 121
cointegration/coint identities, 121 matching EA directories, and zero unbuilt
approved identities. Creating another scan-derived Card, EA, manifest, magic
allocation, or Q02 row would duplicate governed work.

The requested anchor repair remains inapplicable:

| EA | Pair | Canonical chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The
Strategy Card extraction and EA-build gates therefore remained closed, and
the existing-forex fallback applied.

## Existing forex fallback

The concrete fallback remains frozen-scan rank 60,
`QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1`. Its approved implementation is a
structural, fixed-beta, learned-model-free D1 basket trading `USDJPY.DWX` and
`EURGBP.DWX`. The sealed backtest setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Its canonical chain is Q02 PASS, Q03 PASS, and one existing Q04 work item:
`1a269ff4-cbef-429b-afa4-47a3cc692916`. That row remains pending,
priority-bound, unclaimed, attempt zero, and without a verdict. This wake did
not enqueue a duplicate, alter its payload, claim it, or run a dispatch tick.

## Serialized-lane progress

The single multisymbol lane is still owned by `QM5_20224` Q07 work item
`b38e2753-1d57-45d9-8562-3cafc0e105a0` on T9. Since the preceding handoff,
its seed-42 run completed a deterministic PASS at `2026-08-31T11:17:28Z`:
185 trades, PF `1.08`, drawdown `3.12%` (`3251.45`), and net profit
`1366.29`, with no OnInit failure. Its authenticated summary SHA-256 is
`a5c21b7c29c0f8ee22828f9cfec17ca89b025ad0246d1b267aeef238d3aa1a1b`.
The next seed had started and had a tester configuration but no summary at
the observation boundary, so Q07 correctly remained active.

## Binding CPU stop

Five fresh one-second whole-host CPU readings were `94.256158%`,
`99.225430%`, `93.755925%`, `91.702450%`, and `91.811218%`. Average CPU was
`94.150236%` and maximum CPU was `99.225430%`. The admission contract requires
both measures to remain strictly below the `97%` hard ceiling; the maximum
therefore binds.

Per the mission stop condition, no pipeline, queue, tester, worker, or
terminal action followed the sample. The active Q07 basket was not
interrupted.

## Scope and continuation

The portfolio gate and its `portfolio_admission`, `_kpi`, and
`_q08_contribution` surfaces, the T_Live manifest and terminal, AutoTrading,
and all live/deploy manifests were untouched. Concurrent unrelated worktree
changes were preserved.

Machine-readable evidence is
`artifacts/qm5_20246_q04_hard_cpu_stop_20260831T120434Z_board_advisor.json`.

On the next paced wake, first require terminal state for `QM5_20224` Q07 and
an empty multisymbol lane, then take a fresh five-sample CPU window. Only if
both average and maximum are strictly below 97% may the resident worker claim
the existing `QM5_20246` Q04 row. Never enqueue a duplicate.
