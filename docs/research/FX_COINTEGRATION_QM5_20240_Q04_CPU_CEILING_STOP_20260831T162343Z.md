# QM5_20240 FX cointegration Q04 CPU-ceiling stop

Date: 2026-08-31 UTC (`2026-08-31T16:23:43.1047783Z`); 18:23
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `e73ea92d83f4893cf8ca2e301c9f7fbb32e1c74f`

Status: the frozen 66-pair frontier remains fully mechanized, the exact
rank-59 USDCHF/GBPJPY fallback remains priority-bound at Q04, and the explicit
97% backtest CPU ceiling is now binding. No Card, EA, queue row, payload,
verdict, tester, terminal, or portfolio object was created or changed.

## Non-duplicate selection

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3 scan
tested all 66 relationships. The committed sign-aware coverage receipt still
accounts for all 66, and the latest approved-card census has 123 matching
cointegration/coint EA identities and directories with zero unbuilt IDs.

The deterministic Card-extraction and EA-build skill gates therefore remain
closed: there is no OWNER-approved, non-duplicate, unbuilt scan pair to card
or implement. Both preferred anchors are already beyond Q02:

| EA | Pair | Current chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker.

## Existing forex fallback state

The concrete fallback remains frozen-scan rank 59,
`QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. It is the unchanged structural,
fixed-beta, learned-model-free, low-frequency D1 basket. The logical backtest
contract remains `RISK_FIXED=1000` and `RISK_PERCENT=0`; the scan economics
remain adverse and authorize only one-shot falsification without a beta refit
or rescue filter.

Its canonical lineage is unchanged:

| Phase | Work item | State |
|---|---|---|
| Q02 | `24154a28-be35-469e-a5be-58881e29733c` | done / PASS |
| Q03 | `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` | done / PASS |
| Q04 | `85e98029-14f6-4f73-a991-b814d4f3c151` | pending, priority-bound, unclaimed, attempt 0 |

The exact Q04 payload hash remains
`855dcffd54c7e28ec66576fbc43b5ce419011b59ce45338191ab9571c30aa14b`.
The canonical selector currently places it at rank 1,386 of 8,614 pending
eligible rows. There is still exactly one intended identity; no duplicate row
or phase verdict was introduced.

## Binding capacity stop

The mandatory five-sample whole-host CPU window was:

```text
99.707354%, 99.615017%, 99.709278%, 99.805354%, 99.902761%
```

Average CPU was `99.747953%` and maximum CPU was `99.902761%`. Both exceed
the explicit `97%` ceiling, so the mission stopped before any queue mutation,
claim, dispatch tick, tester launch, reservation, compile, or backtest.

The serialized multisymbol lane was also legitimately occupied by
`QM5_20294` Q03 work item
`9437109a-799b-4f29-a501-89e6b4a3809c` on T8. Its terminal log had progressed
to 36% at `2026-08-31T16:18:55Z`; it was not treated as stuck and was not
controlled. Starting or forcing `QM5_20240` alongside it would violate both
the CPU stop and basket pacing.

## Safety and resume contract

- No portfolio-admission, portfolio-KPI, or Q08-contribution surface changed.
- No `T_Live` manifest or terminal, AutoTrading state, live setfile, or deploy
  artifact changed.
- No Card, EA source, EX5, basket manifest, setfile, registry, or magic row
  changed.
- Pre-existing unrelated worktree changes were preserved and left unstaged.

After a fresh five-sample CPU window is strictly below 97% and the active
multisymbol lane is clear, let the resident paced worker claim the exact
priority-bound Q04 row. Do not enqueue a duplicate or manually force a second
basket.

Machine-readable evidence is
`artifacts/qm5_20240_q04_cpu_ceiling_stop_20260831T162343Z_board_advisor.json`.
