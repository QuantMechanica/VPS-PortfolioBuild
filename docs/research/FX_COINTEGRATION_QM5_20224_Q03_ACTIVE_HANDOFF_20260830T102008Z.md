# QM5_20224 FX cointegration Q03 active handoff

Date: 2026-08-30 UTC (`2026-08-30T10:20:08Z`); 12:20 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `493e719292814500a326241e7da06e8190865551`

Status: the unique existing forex fallback has advanced from pending to an
active governed Q03 run on T10. The same work-item identity is making forward
progress; no duplicate Card, EA, queue row, dispatch, tester, or phase was
created.

## Governed frontier resolution

The reputable-source result remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 scan
tested all 66 relationships and selected only two pairs under the published
criterion (positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four
OOS trades):

| EA | Pair | Canonical state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The
committed sign-aware coverage receipt accounts for all 66 relationships, and
the latest committed census has no approved FX-cointegration Card without a
matching EA directory. The Strategy Card extraction and EA-build gates
therefore remain closed against duplicate or weaker-source work.

## Existing forex fallback advanced

The serialized predecessor, `QM5_20294` Q05 work item
`c56df942-e7aa-4c7d-b855-402de608352f`, reached canonical `done / PASS` at
`2026-08-30T10:04:14Z`. The resident governed worker then claimed the exact
already-pending rank-46 successor:

| Field | Value |
|---|---|
| EA | `QM5_20224` |
| Pair | `EURUSD.DWX` / `EURJPY.DWX` |
| Logical symbol | `QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1` |
| Phase / row | Q03 / `3c74eb04-7e19-4aa0-8dcf-3f004faaa946` |
| State | active, attempt zero, claimed by T10 |
| Claim update | `2026-08-30T10:09:24Z` |
| Tester interval | 2018-07-02 through 2022-12-31, D1 |
| Downstream | Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e` remains pending |

The package is unchanged and remains a structural, fixed-beta D1 basket. Its
logical backtest setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; `USDJPY.DWX` is conversion-history-only. There is no
adaptive refit, machine learning, banned indicator, grid, martingale, or
portfolio feedback.

## Live forward-progress evidence

The governed T10 terminal and metatester were present under exact factory
paths. Two bounded checkpoints prove that the run is not stuck at
initialization or history loading:

| Sample UTC | Last simulated event | EA log bytes | Tester CPU seconds |
|---|---:|---:|---:|
| 10:18:58 | 2020-03-13 21:00 | 266,492 | 419.984 |
| 10:20:08 | 2020-06-08 00:05 | 296,459 | 486.922 |

The later event was an accepted `EURJPY.DWX` basket order with MT5 retcode
`10009`. Simulated time, log size, and tester CPU all advanced. The historical
`ONINIT`/`NO_HISTORY` failure class therefore does not describe this active
run.

## Capacity and pacing

Five fresh one-second whole-host CPU readings were `67.207503%`,
`76.623529%`, `75.588420%`, `85.165216%`, and `75.991097%`. Average CPU was
`76.115153%` and maximum CPU was `85.165216%`; neither reached the explicit
97% ceiling.

At the observation boundary the farm had seven active rows, six exact-path
factory terminals (T1, T3, T6, T7, T9, and T10), six active reservations,
all ten terminal workers, no duplicate worker, and no orphaned factory
terminal. T_Live and the unrelated FTMO terminal were observed only to
exclude them and were not controlled.

Capacity does not authorize a second basket run: QM5_20224 itself now owns the
single serialized lane. Q04 must remain pending until Q03 reaches a canonical
PASS verdict.

## Non-duplicate delta and safety

Relative to the preceding `2026-08-30T09:16:30Z` CPU-stop receipt, the
predecessor changed from active to `done / PASS`, the same QM5_20224 Q03 row
changed from pending to active, and the maximum CPU reading fell from
`99.023541%` to `85.165216%`. No new relationship, work item, payload,
priority, claim, status, verdict, reservation, worker, terminal, compile,
smoke test, or backtest was created or changed by this handoff.

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading, and live/deploy manifests
were untouched. Unrelated shared-worktree changes were preserved.

Machine-readable evidence is in
`artifacts/qm5_20224_q03_active_handoff_20260830T102008Z_board_advisor.json`.

On the next paced wake, reconcile this exact row and take a fresh CPU sample.
Do not mutate or run Q04 before Q03 PASS. A terminal economic or cadence
failure retires this exact sleeve rather than authorizing parameter rescue.
