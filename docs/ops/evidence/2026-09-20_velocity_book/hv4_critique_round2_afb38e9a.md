# H-V4 cross-vendor critique — round 2 (task afb38e9a)

Router task: `afb38e9a-eb76-4dab-b5e9-54efc87a260e`

Research source: `QM-RESEARCH-2026-0012`, revision 2

Critic: Codex

Bound source SHA-256: `84362c84bffcc748953b32254bd13902226b2671a011c7363ba03d6714881984`

Bound source commit: `9de5d9a43a05a79fc51eddbc251f2964265698bb`

Scope: read-only source audit. This critique is the only task artifact written; no source, seal, card, registry row, factory row, EA, set file, or pipeline state was changed.

## Decision

All twelve round-1 revision points are resolved. The mechanical-spec section at `source.md:102-177` is single-valued enough that two competent builders following it and the explicitly frozen QM5_13213 baseline would implement the same strategy. No further sensitivity run is required for this decision.

| arm | verdict | decision basis |
|---|---|---|
| USDJPY C2 | **APPROVE_BUILD** | The primary arm is frozen as the two-bar :30-aligned range (`source.md:128-130,175-177`), has explicit Q02 retirement/calibration bars (`:226-230`), and has an exact Q05 rule that does not round away the 25.04R harness warning (`:239-245`). Build it as its own frozen arm; this verdict does not establish a Q05 pass or replacement of QM5_13213. |
| USDJPY C3 | **APPROVE_BUILD** | The second arm is frozen as the three-bar range (`source.md:128-130,175-177`), has its own Q02 bars (`:231-232`), and is explicitly the separately built fallback if C2 exceeds 25R in Q05 (`:239-245`). It is not an optimization of C2. |
| EURUSD C3 | **APPROVE_BUILD** | The secondary slot is restricted to EURUSD C3 (`source.md:63-66,175-177`), has its own retirement bars (`:233`), and is explicitly characterized as marginal/secondary rather than family-level proof (`:205-222`). Build and measure it separately; no independent-book claim follows from this verdict. |

`APPROVE_BUILD` is a build-review verdict only. It is not a pipeline verdict, a performance pass, a source seal, or live-use authorization.

## Twelve-point closure audit

| # | status | builder-fixed resolution and source references |
|---:|---|---|
| 1 | **RESOLVED** | Runtime is M30; strategy evaluation is behind `QM_IsNewBar(_Symbol, PERIOD_M30)` while management/exits stay per tick; every :30-aligned H1 grid bar is an explicit shift-1 pair of completed M30 halves; any missing half in the N range bars or 14 ATR bars rejects the day (`source.md:117-127`). |
| 2 | **RESOLVED** | News-gated placement is retried only in `[15:30,16:30)` server, never at/after 16:30; the EA retry opportunities are the M30 bar opens 15:30 and 16:00 because of the framework cache. The minute-resolution harness deviation and strict no-retry bound are disclosed (`source.md:145-154`). |
| 3 | **RESOLVED** | Trail activation uses `abs(open_price - CURRENT SL)` re-read at each evaluation, not latched initial risk; the two completed :30-grid bars define the improving stop (`source.md:155-162`). |
| 4 | **RESOLVED** | Normal and gap/holiday flat behavior is the first available tick at or after 23:00 server, subject to the earlier Friday close; the harness's retrospective pre-gap close is only a disclosed deviation (`source.md:163-169`). |
| 5 | **RESOLVED** | Both pending-send results are retained; a one-send success cancels the survivor and makes the day no-trade; the peer is removed on fill handling or no later than the next tick; there is at most one position and no re-entry per symbol/day (`source.md:134-144`). |
| 6 | **RESOLVED** | Fixed 15:30/23:00 times are explicitly DXZ-only. FTMO must derive the economic times through the governed `QM_SessionClock`, and no FTMO set is admissible until that helper exists and passes stable-season plus DST-divergence tests (`source.md:108-116`). This is an explicit dependency gate, not a free builder choice. |
| 7 | **RESOLVED** | The authoritative Q05 measure is maximal equity drawdown from the Q05 run summary, in USD at RISK_FIXED 1000 with 1R = USD 1,000, compared without rounding to `>25R`. C2's harness 25.04R is disclosed at the bar; a Q05 value above 25R retires C2 and selects the already separate C3 arm (`source.md:239-245`). |
| 8 | **RESOLVED** | The source enumerates 28 existing FX symbols, two metals, and six indices; explains why the three energy symbols were never in this family; and accounts for the 314 cells with trades after JPN225/GDAXI exclusions (`source.md:192-203`). |
| 9 | **RESOLVED** | The 70% rule is explicitly a pre-registered tester build-regression check added after validation was observed, not fresh holdout evidence (`source.md:234-238`). |
| 10 | **RESOLVED** | The approximately +0.02R optimism is restricted to an A3 planning heuristic; the source requires the Q02 tester to establish each arm's actual harness gap (`source.md:37-44`). |
| 11 | **RESOLVED** | The source says the roughly 2x uplift is descriptive, reproduces the dependent paired result, downgrades replacement to a hypothesis, and pre-registers the tester-stream paired bootstrap that alone can support replacement (`source.md:78-88,205-222,253-259`). |
| 12 | **RESOLVED** | The title is suffixed “revision 2,” and the revision table records all prior critic points and their bounded resolutions (`source.md:3,14,288-303`). |

## Builder handoff boundaries

- Freeze three separate set-file arms: USDJPY C2, USDJPY C3, and EURUSD C3. Do not turn N or the anchor into a search at build time (`source.md:128-130,175-177,260-261`).
- Backtest sets must use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The mandatory high-impact news blackout remains fail-closed; `qm_news_stale_max_hours` must not exceed 336.
- DXZ fixed server times are buildable now. Do not admit an FTMO set until the governed `QM_SessionClock` dependency and its specified seasonal/DST tests exist (`source.md:108-116`).
- C2's 25.04R harness figure is a warning at the pre-registered boundary, not a Q05 result. C2 retires only under the exact Q05 report rule; C3 is already frozen so that fallback requires no parameter choice (`source.md:239-245`).
- No arm is established as a replacement for QM5_13213 until criterion 8 passes, and no arm is an additive sleeve before the Q08 dependence panel (`source.md:246-259`).

## Focused verification record

- The routed source hash matches the file and commit named above.
- The source manifest hashes match the files: `research.json` `81e23abd25a2ef626835b90007727a728818c22618c5283a94b4cf73f07f7831`; `lineage.json` `e335665710b9f746a142ca008f681fc980388ba04f4270867aa630c58db4ed25`; `critic_receipt.json` `529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14`; `sweep_extract.json` `247c595106904451c162f5ed6296abe09790d46f01195d26e8b8bde7a1b6e6ea`; `critique_d7ed93cd_extract.json` `4f6a73a6ad3619d4ed8c729c9446ee206246de32ed079f06a8083262a543dd6b`.
- The full sweep hash remains `c9ad5d139e8e77d514d9811806ee5178ef3f4704b5892bb89053d8956d82c6a5`.
- `research.json`, `sweep_extract.json`, and `critique_d7ed93cd_extract.json` parse successfully as JSON.
- `research_source.py verify --id QM-RESEARCH-2026-0012` resolves the same source hash and reports only `LEDGER_STATUS_BAD:draft`; there is no manifest/hash/provenance mismatch. Draft status is expected at this critic stage, and the critic performed no seal.
- The prior focused sensitivities remain bound through the sealed critic extract. No new sensitivity was run because no revision point remained unresolved.

## Required disposition

Return all three arm verdicts as `APPROVE_BUILD` to review. Keep the downstream build ticket blocked from automatic promotion until normal human/close-out handling consumes this critique; do not infer a pipeline phase or live authorization from it.
