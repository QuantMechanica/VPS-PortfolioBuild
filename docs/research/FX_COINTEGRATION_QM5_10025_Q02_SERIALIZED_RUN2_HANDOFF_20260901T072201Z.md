# FX basket fleet — QM5_10025 Q02 serialized run-2 handoff

Date: 2026-09-01 UTC (`2026-09-01T07:22:01Z`); 09:22 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `1658c7fe54a5e9d19161ab51e5110917c2e4f0ae`

Status: the governed 66-pair frontier still has no eligible unbuilt identity,
the preferred anchors remain past Q02, and the selected existing FX basket is
queued exactly once. Whole-host CPU is below the 97 percent ceiling, but a
healthy second run of the existing T8 multisymbol predecessor still owns the
single serialized basket lane. No queue, tester, terminal, strategy, or
portfolio state was mutated.

## Frontier and anchor decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
reputable-source scan. Its acceptance rule selected only two of 66
relationships. The latest complete census in
`docs/research/FX_COINTEGRATION_QM5_20240_Q04_RETIREMENT_20260831T233713Z.md`
records all 66 relationships covered, 123 approved cointegration/coint
identities, 123 matching EA directories, and no approved unbuilt identity.
Creating another scan-derived Card or EA would therefore duplicate governed
coverage or relax the published source criterion.

The preferred anchors have no current Q02 setup repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The Strategy Card extraction and EA-build gates stayed closed. The autonomous
pipeline-phase skill does not run Q02 and was not invoked.

## Exact existing-card fallback

The selected fallback remains `QM5_10025_rw-fx-broad-pairs`, a built H4
market-neutral FX sleeve. Each real FX host chooses one foreign partner at the
monthly formation event, freezes the OLS beta for that month, and trades one
two-leg beta-weighted spread. It is structural and contains no ML, grid,
martingale, or adaptive intramonth refit.

The USDJPY-host Q02 row remains ready and non-duplicated:

| Field | Value |
| --- | --- |
| Work item | `050dd2ea-e9d0-475f-b5ad-40c2206867ff` |
| Host / timeframe | `USDJPY.DWX` / H4 |
| State | pending, unclaimed, attempt 0 |
| Open exact rows | 1 |
| `priority_track` | `true` |
| Priority reason | `board_advisor_fx_existing_market_neutral_q02_after_exhausted_66_pair_frontier` |
| Payload SHA-256 | `bca99985bb4989d96c0537c81640333870793f2958843797d5357fb6c319a2f8` |

SQLite `PRAGMA quick_check` returned `ok`. The basket work-item regression
suite passed 18/18 tests. The EA directory is worktree-clean, and the MQ5,
EX5, manifest, and USDJPY backtest setfile hashes remain unchanged. The
setfile remains sealed at `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The legacy runtime approved Card has `g0_status: APPROVED`, no ML tokens, and
the Robot Wealth source citation, but the current schema lint reports only
three missing canonical headings: `Hypothesis`, `Rules`, and `Risk`. The card
was not rewritten or re-approved in this handoff because that would cross the
Card-governance boundary; its already-governed build and pending Q02 row were
left intact.

## Capacity and serialized-lane health

Five final one-second whole-host CPU samples were `86.147881%`, `65.448207%`,
`72.670404%`, `70.049124%`, and `64.268700%`. Average CPU was `71.716863%`
and maximum CPU was `86.147881%`, both strictly below the 97 percent ceiling.

T8 still owns `QM5_20233_XAU_XAG_SKEW_RANK_D1` Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427`. Its first test run completed far
enough to start `raw/run_02`; the current terminal process began at
`2026-09-01T06:32:31Z`, remained responsive, and accumulated 1.0625 CPU
seconds during a five-second liveness sample. The T8 tester log advanced to
simulated `2019.06.05 15:25:16`. Supported slot reconciliation found no
duplicate worker or orphaned tester process.

The active farm snapshot contained nine rows: seven OPT_CENSUS, one Q03, and
one Q10_NEWS. The resident worker's atomic admission contract serializes
multisymbol jobs fleet-wide, so claiming or manually dispatching QM5_10025
while the healthy T8 predecessor runs would create a forbidden concurrent
basket test.

## Non-duplicate delta and resume contract

Compared with the preceding receipt at `2026-09-01T06:19:52Z`, T8 moved from
the earlier test into a live second run, its simulated clock reached June
2019, the active farm set grew from six to nine rows, and average/maximum CPU
fell from `89.704523%`/`90.821294%` to
`71.716863%`/`86.147881%`. This is new state evidence; no duplicate queue row
or repeated priority mutation was created.

After the T8 item reaches a canonical terminal state and no other
multisymbol row is active, take a fresh five-sample CPU window. Only when both
average and maximum remain strictly below 97 percent should a resident worker
claim the unique prioritized QM5_10025 Q02 row. Do not enqueue a duplicate or
manually start a second basket tester.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, Q08 state, T_Live manifest or terminal, AutoTrading
state, live setfile, or deploy manifest was touched. Pre-existing unrelated
worktree changes were preserved and excluded from this handoff.

Machine-readable evidence is
`artifacts/fx_cointegration_qm5_10025_q02_serialized_run2_handoff_20260901T072201Z_board_advisor.json`.

