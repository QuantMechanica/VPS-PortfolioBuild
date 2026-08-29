# QM5_20224 FX cointegration Q03 priority handoff

Date: 2026-08-29 UTC (`2026-08-29T14:07:49Z`); 16:07 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `096ff0ce6408b07a34d74bc0674264c3346a98a1`

Status: the existing EURUSD/EURJPY logical basket was advanced in place at
Q03. No Card, EA, setfile, manifest, queue row, verdict, tester, terminal, or
portfolio-gate object was created or changed.

## Outcome

The governed 66-pair source frontier contains no unbuilt relationship left to
mechanize, so the mission fallback applies. The unique existing Q03 row for
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`, work item
`3c74eb04-7e19-4aa0-8dcf-3f004faaa946`, now carries
`priority_track=true` with reason
`board_advisor_fx_fallback_rank46_q03`.

The exact-ID payload CAS preserved the row's pending, unclaimed, attempt-zero,
unverdict state and its original `updated_at`. Canonical pending rank improved
from 4,572 to 1,917 while the pending population remained 5,309. Audit event
`380417` records the mutation. Exactly one matching open Q03 row remains; no
duplicate was enqueued and Q04 was not advanced out of order.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3 hard
criterion selected only two relationships from the original scan:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current logical-basket Q02 `ONINIT` or `NO_HISTORY`
blocker. Historical invalid per-leg attempts do not supersede their later
canonical Q02 PASS rows.

The committed sign-aware coverage artifact
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships with zero uncovered. The immediately
preceding fresh census found 119 approved Cards containing `cointegration` or
`coint`, 119 unique EA IDs, and a matching EA directory for every Card. There
is no approved unbuilt FX cointegration Card. Drafting a new Card or EA would
therefore duplicate governed coverage or weaken the reputable-source bar.

Ranks 40 through 45 now have terminal later-gate verdicts. Rank 46 is the
highest-ranked nonterminal relationship with an exact pending successor, so
`QM5_20224` is the valid existing-forex fallback.

## Selected existing sleeve

`QM5_20224` trades `EURUSD.DWX` and `EURJPY.DWX` on D1 with frozen beta
`-0.236324029`; `USDJPY.DWX` is conversion-history-only. The negative beta
makes a long residual package long-long and a short residual package
short-short. "Market-neutral" is limited to the fitted residual, not zero
currency, carry, or macro exposure.

The OWNER-approved Card explicitly records adverse frontier evidence: DEV net
Sharpe `0.473267`, OOS net Sharpe `-0.118543`, OOS return `-1.026394%`, 17 OOS
state changes, and a `137.788`-D1-bar half-life. This is a one-shot pipeline
falsification, not permission to refit, add a filter, or rescue a failed gate.

The source/build package remains sealed:

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Card schema/ML lint passed with no ML hits. The logical backtest setfile keeps
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The Card and EA
remain structural, fixed-beta, low-frequency, deterministic, and free of ML,
adaptive refit, banned indicators, grid, martingale, or portfolio feedback.

Sealed lineage:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: PASS with no `OnInit` failure,
  116 trades, PF `1.26`, 2.83% drawdown, and net profit `2967.29`.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending,
  `priority_track=true` after this handoff.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and deliberately not
  advanced before its Q03 dependency.

## Guarded queue mutation

The mutation changed only `payload_json.priority_track`, its reason, and a
bounded handoff provenance object. It used the exact work-item ID and complete
payload preimage plus pending/unclaimed/attempt-zero predicates. The row had no
active hold, supersede relation, or poison-pill quarantine. Its `updated_at`
was preserved, the pending population did not change, and the unique-open-row
guard remained one.

The reversible preimage/postimage journal is
`D:/QM/reports/state/qm5_20224_q03_priority_20260829T140749Z.journal.json`
(SHA-256
`a50f166cf749ac50c401319d1f4cd315d3a6908dfa9185bbabf353ebf0dc34d6`,
state `COMMITTED`). The global factory mutation lock was acquired without a
wait and released normally. The journal's revert guard permits restoration
only while the current payload still matches the recorded postimage and the
row remains pending, unclaimed, and at attempt zero.

## Capacity and paced-fleet boundary

The five apply-time CPU samples were `84.989428%`, `80.817824%`, `78.615459%`,
`83.595436%`, and `80.773360%`. Average CPU was `81.758301%` and maximum CPU
was `84.989428%`, both below the explicit 97% ceiling.

A legitimate multisymbol Q04 row was active on T5 at apply time:
`QM5_20294_XAU_XAG_LOWMAX_D1`, work item
`a34ee5cd-39b0-4655-9b02-1bf8e389f440`. It was not reclaimed, reprioritized,
or otherwise changed. No manual dispatch, tester, reservation, worker, or
terminal action was started; `QM5_20224` remained pending after verification,
leaving the existing basket-lane serialization intact for the deterministic
paced worker.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, live/deploy manifest, or Q08 state
was touched. No Card, EA, source, EX5, setfile, basket manifest, registry,
magic row, resolver, queue row, claim, status, or verdict was created or
changed. Unrelated shared-worktree changes were preserved and excluded from
this handoff.

Machine-readable evidence:
`artifacts/qm5_20224_q03_priority_20260829T140749Z_board_advisor.json`.

## Continuation condition

Allow the deterministic paced worker to claim the existing exact Q03 row only
after the active multisymbol lane clears. Do not enqueue another Q02/Q03 row,
manually dispatch a terminal, or bypass Q03 by prioritizing Q04.
