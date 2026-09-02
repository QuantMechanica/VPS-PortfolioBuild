# FX cointegration paced CPU-ceiling stop

Recorded: 2026-09-02T23:30:09.8247313Z (2026-09-03 01:30 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `bc8dcb62df8e9656909b45316ba1d917ba2e606e`

## Outcome

The governed 66-pair FX cointegration frontier still offers no eligible
unbuilt relationship. The preferred anchors do not need Q02 repair:
`QM5_12532` and `QM5_12533` have canonical logical-basket Q02 PASS evidence.
The latest committed continuation is the existing structural D1 fallback
`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`; its unique priority-bound
`Q09_NEWS` row received its complete basket payload in commit `7d13829a1f`.

A fresh five-sample capacity window reached 97.697480% CPU against the
mission's 97% hard ceiling. The wake therefore stopped before rereading or
mutating runtime queue state. No Card, EA, manifest, setfile, queue item,
priority mark, claim, dispatch, compile, or backtest was created.

## Non-duplicate selection

The controlling study remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all
66 unordered FX relationships, and the latest complete reconciliation found
all 66 represented. Creating another scan-derived identity would duplicate
governed coverage.

The preferred repair condition is also absent:

| EA | Relationship | Canonical chain |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS, Q04 PASS, then Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS, then Q04 FAIL |

The last durable state for `QM5_12778` is already a single pending,
priority-bound existing-card continuation. Its basket payload is SHA-bound to
the checked-in manifest and includes the traded and conversion histories.
Appending, reprioritizing, manually claiming, or dispatching another row
would be duplicate work and was not attempted.

## Capacity evidence

The five sequential whole-host `Processor(_Total)\\% Processor Time` samples
were `95.419818%`, `97.070645%`, `97.697480%`, `93.856446%`, and
`88.874137%`. Their average was `94.583705%` and their maximum was
`97.697480%`.

The ceiling binds when either the average or maximum is at least 97%; the
maximum therefore required an immediate stop. No compile, tester launch,
terminal reservation, queue mutation, or backtest followed.

## Safety and continuation

No Strategy Card, EA source/binary, setfile, basket manifest, registry, magic
row, runtime queue row, terminal, or AutoTrading state changed. No
portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
`T_Live`-manifest, or live/deploy surface was touched.

On a later paced wake, sample CPU first. Continue only if both average and
maximum are strictly below 97%. Then reread the exact existing `QM5_12778`
row and leave execution to its ordinary paced-worker path; do not create or
reprioritize a duplicate.

Machine-readable companion:
`artifacts/fx_cointegration_paced_cpu_stop_20260902T233009Z_board_advisor.json`.
