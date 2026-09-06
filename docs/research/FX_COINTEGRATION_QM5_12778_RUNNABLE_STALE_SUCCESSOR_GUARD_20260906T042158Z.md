# QM5_12778 runnable FX continuation and stale-successor guard

Recorded: 2026-09-06T04:21:58Z (06:21 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `78c96e3413c47b803370d77ed0a9e78c963ce50f`

## Outcome

The frozen 66-pair FX cointegration frontier has no unbuilt relationship to
mechanize. A current manifest-to-ledger census found 56 low-frequency D1
two-traded-leg pure-FX basket manifests; every logical identity already has a
Q02 row. The two preferred anchors remain beyond Q02, so neither needs an
ONINIT or NO_HISTORY repair.

The selected existing continuation is the D1 AUDUSD/EURJPY cointegration
basket `QM5_12778`. Its unique Q09_NEWS work item remains pending, unclaimed,
priority-bound, runnable, and free of active holds. It was 161st of 9,145 rows
in the canonical eligible claim order at observation time. The resident paced
workers retain dispatch ownership; no duplicate row or manual tester was
started.

## Anchor and frontier reconciliation

- `QM5_12532` AUDUSD/NZDUSD: logical Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: logical Q02 PASS, then Q04 FAIL.
- Exact current D1 two-leg pure-FX manifest census: 56 identities, zero without
  a logical Q02 row, zero with an open Q02 row.
- The wider durable sign-aware reconciliation remains 123 approved identities
  with 123 matching EA directories. A new scan-derived Card or EA would be a
  duplicate.

## Selected continuation

- EA: `QM5_12778_edgelab-audusd-eurjpy-cointegration`
- Traded pair: `AUDUSD.DWX` / `EURJPY.DWX`
- Logical symbol: `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`
- Cadence: D1, approximately 4-8 logical packages per year
- Work item: `24acc5d4-3e34-526e-a7a8-12640a2e759f`
- Phase/state: Q09_NEWS, pending, unclaimed, attempt 0, no verdict
- Queue state: `priority_track=true`, `RUNNABLE_BOUND`, one open identical row
- Holds: zero active; the prior `NEWS_CALENDAR_TIMESTAMP_DEFECT` hold remains
  correctly released
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`

The sealed package hashes are unchanged from the post-release qualification:

| Artifact | SHA-256 |
| --- | --- |
| Approved Card | `5878c99d9cef732642f99961556dd8bd049e14b42292b61aa72a047b4558134a` |
| MQ5 | `132a501d94685f013cc62a8b3c2de111d0a8b1e616a8656d2c61b061a754c146` |
| EX5 | `2a105cfbb364142c96c552136bb450162c142845665ce3366d0c045248c17a01` |
| Basket manifest | `0ce25d17ebe7c3664e4acdb6c1d302b28b1f40710301189cc633e44f25854d57` |
| Logical backtest setfile | `0e7949276927c8c5355c413c631e7b67f684e757892de59fa2cff5521836c8e9` |

## Stale-successor guard

Six other unprioritized pending rows surfaced in the narrow D1 pure-FX basket
census. None is a valid fallback because a later terminal economic verdict
already closes its chain:

| EA | Pending row | Later terminal evidence | Decision |
| --- | --- | --- | --- |
| `QM5_1017` | Q04 / EURUSD | logical-basket Q02 FAIL | do not revive |
| `QM5_20197` | Q03 / EURJPY-EURGBP | Q04 FAIL | do not revive |
| `QM5_20201` | Q03 / GBPJPY-EURGBP | Q04 FAIL | do not revive |
| `QM5_20207` | Q03 / USDCAD-AUDUSD | Q04 FAIL | do not revive |
| `QM5_20211` | Q03 / GBPJPY-EURAUD | Q05 FAIL | do not revive |
| `QM5_20250` | Q04 / USDCHF-AUDJPY | Q03 FAIL | do not revive |

No priority mark was applied to these stale rows. Doing so would not advance a
live hypothesis; it would reanimate already-falsified lineages and consume
tester capacity without evidentiary value.

## Capacity and safety

Five one-second whole-host CPU samples were 90.056%, 92.890%, 94.437%,
84.389%, and 85.361% (average 89.426%, maximum 94.437%). The 97% hard ceiling
did not bind. Six factory terminals (`T1`, `T4`, `T6`, `T7`, `T8`, and `T10`)
were running; all ten resident terminal workers were singular, with no orphaned
factory terminal process. The farm database quick check returned `ok`.

No Card, EA, registry, magic row, setfile, manifest, queue row, priority,
hold, verdict, tester, terminal, portfolio-admission, portfolio-KPI,
Q08-contribution, portfolio-gate, T_Live, deploy, or AutoTrading state was
changed.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12778_runnable_stale_successor_guard_20260906T042158Z_board_advisor.json`.

## Resume contract

Let the ordinary paced worker consume the unique QM5_12778 Q09_NEWS row under
the existing claim order. Do not append or manually dispatch a duplicate. Do
not prioritize any of the six stale successor rows unless a separate governed
reconciliation first proves that its later terminal verdict is invalid.
