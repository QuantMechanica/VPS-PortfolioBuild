# QM5_10912 Diverse-FX Q02 Infrastructure Recovery

## Outcome

`QM5_10912_grimes-failtest` now has a current zero-warning binary, complete canonical fixed-risk setfiles, and two guarded pending Q02 rows on `EURUSD.DWX` and `GBPUSD.DWX`.

The approved H1 strategy is Adam H. Grimes's structural failure test: fade a false break of a recent pivot after price closes back inside the prior range (the Wyckoff spring/upthrust family). The card estimates 25-55 trades per year per symbol, uses no ML, and cites Grimes's *Fundamental Trading Patterns* and *The Failure Test* articles.

## Selection And Claim

No faithful priority-1 build was available. The three pending approved cards reduced to an unavailable lumber proxy, unavailable Treasury/rates instruments, and a high-frequency XAU/NDX scalper. The diverse-instrument recovery path was therefore selected.

- Farm claim: `agent_tasks.id=3deb8431-ea22-4dfb-9c69-e5ae0ccd79a1`.
- Collision guard: no competing active agent task and no pending/active Q02-Q03 row for the EA.
- Card: `g0_status=APPROVED`, R1-R4 all PASS.
- Active magic rows already existed for all five card symbols.

## Diagnosis

The pre-repair database backup contains 60 Q02 rows: 60 `INFRA_FAIL`, zero PASS, and zero strategy/other verdicts. Two were `done`, 58 were `failed`, and none were open. The latest EURUSD and GBPUSD rows ended as `summary_missing_retries_exhausted`; earlier retained runs recorded `ONINIT_FAILED;INCOMPLETE_RUNS`.

Three concrete build defects remained:

1. The checked-in `.ex5` dated `2026-06-21T15:00:04Z` and predated 20 current `framework/include/QM/*.mqh` files.
2. Every backtest setfile omitted `qm_ea_id` and all strategy inputs and recorded `card_defaults_source=not_found`.
3. News gating ran before Friday-close, management, and strategy exits, contrary to the binding entry-only gate order.

## Repair And Validation

The framework order was corrected without changing the approved signal rule. All five declared-symbol setfiles were regenerated from the approved card/EA defaults with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, then their build hashes were synchronized.

| Check | Result |
|---|---|
| SPEC validation | PASS |
| Build guardrails | PASS |
| Symbol scope | `SINGLE_SYMBOL_OK` |
| Strict compile | PASS, 0 errors, 0 warnings |
| Compile log | `C:/QM/repo/framework/build/compile/20260711_041248/QM5_10912_grimes-failtest.compile.log` |
| Build check | PASS, 0 failures, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260711_041306.json` |
| Old `.ex5` SHA256 | `91D72CFFAD0A4E5CF0550AA312AD6A1B4FB94D11F66525CC8ECCFC890050A916` |
| New `.ex5` SHA256 | `7B35351B971508374773FEE8989AF02700074D8A4C7408601C820114D7F9450C` |

## Q02 Handoff

The existing latest terminal rows were reset in place, avoiding duplicate rows and avoiding metal/index queue load:

| Symbol | Work item | State |
|---|---|---|
| `EURUSD.DWX` | `106ffc18-89d5-4126-b14b-2252f838090e` | `pending`, attempt 0, unclaimed |
| `GBPUSD.DWX` | `00e35d9c-680f-4829-9544-088976a79060` | `pending`, attempt 0, unclaimed |

The transaction required exact prior `done / INFRA_FAIL / unclaimed` states, the farm claim, and zero pending/active Q02-Q03 duplicates. Stale report roots were archived before reset. The consistent pre-write database backup is:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_10912_fx_q02_requeue_20260711T041505Z.sqlite`

## Runtime And Safety

`FACTORY_OFF.flag` remains in force, so no manual smoke/backtest was launched and no tester CPU was added. Two `terminal64` processes predated this unit (both started July 8); neither was modified. No `T_Live` file or state, AutoTrading setting, portfolio gate, or T_Live manifest was touched.

Machine-readable evidence: `artifacts/qm5_10912_fx_q02_infra_repair_requeue_20260711.json`.
