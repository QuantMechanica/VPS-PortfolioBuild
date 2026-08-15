# QM5_1257 GBPUSD/USDJPY zero-trade repair and Q02 refresh

Date: 2026-08-15  
Branch: `agents/board-advisor`  
Outcome: strict build and compile PASS; the existing exact Q02 work item was refreshed in place and released pending. No Q02 PASS is claimed.

## Selection and duplicate guard

`docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md` records all 66 relationships in the scan as already mechanized. Creating another card would therefore duplicate the frontier. The two original anchors from `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, QM5_12532 and QM5_12533, have durable Q02 PASS evidence and are blocked at later gates rather than ONINIT or NO_HISTORY.

The mission's fallback was used: advance the existing OWNER-approved `QM5_1257_lemishko-fx-cointpair` card for the frozen rank-58 relationship GBPUSD.DWX/USDJPY.DWX. The approved card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1257_lemishko-fx-cointpair.md` and cites Lemishko, Landi, and Caicedo-Llano (2024), SSRN. This is the same monthly Engle-Granger/OLS H1 strategy lineage; no thresholds, pair choice, or economics changed.

## Bound failure evidence

The evidence-bound run is `D:/QM/reports/work_items/d4cd660c-c81a-41d3-8a4c-ad21d3319816/QM5_1257/20260815_082908/summary.json` (SHA-256 `76fcd6351b98f8cc16250a5fd7e3bc2fb47e6b868cd9ce4619102c5f64bc1526`). The 2018-07-02 through 2022-12-31 run exited normally with a valid report, real-tick marker, no ONINIT failure, and zero trades. Its 1,411 captured events contained INIT/INIT_OK and recurring housekeeping events but no pair-entry events. The first failed layer is therefore entry implementation, not setup, history, or report validity.

## Same-lineage implementation repair

The repair in commit `751cb391d8f388f5b61641ba3299011cdf9a09ed` makes these card-conformance corrections:

- Half-life now accepts a negative mean-reverting lambda, derives `phi = 1 + lambda`, requires `0 < phi < 1`, and uses `-log(2) / log(phi)`.
- Bid/ask friction is expressed as relative cost before comparison with the log-residual spread. Zero-spread `.DWX` ticks remain valid.
- Negative-beta hedge directions are mapped correctly.
- The host and companion legs resolve registered magic slots 8 and 29 independently.
- Pair entry is atomic: a partial second-leg failure closes the first leg and records a registered rollback event.
- Monthly qualification PASS and FAIL outcomes are latched once per month with bounded registered diagnostics.

The validator mechanically restamped 44 preset headers. Commit `82a1bf44319a26fee1dbe5eb8463c7986f0304e6` restores every preset to its pre-repair content. The net repository delta for the EA is only the MQ5, compiled EX5, and focused regression test; basket manifest and setfile semantics are unchanged.

## Validation

| Check | Result | Evidence |
| --- | --- | --- |
| Strict build check | PASS, 0 failures, 0 warnings | `D:/QM/reports/framework/21/build_check_20260815_115834.json` |
| Strict MetaEditor compile | PASS, 0 errors, 0 warnings | `D:/QM/reports/compile/20260815_115849/summary.csv`; `C:/QM/repo/framework/build/compile/20260815_115849/QM5_1257_lemishko-fx-cointpair.compile.log` |
| Build guardrails | PASS, 45 files, no findings | `validate_build_guardrails.py` |
| Basket symbol scope | BASKET_OK, 0 violations | GBPUSD.DWX and USDJPY.DWX manifest scope |
| Focused regression suite | 45 passed in 1.89s | `tools/strategy_farm/tests/test_fx_basket_manifests.py` |

Artifact bindings after restoration:

- MQ5: `7885452d1f3289bd928fa5b6e78718c6c6e96044381b0c02968a0a69729e74f2`
- EX5: `673c446100d6871ce426f5b9a5799530d8ef2fd73990599a7ca1afc74d26f207`
- RISK_FIXED logical setfile: `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`
- Basket manifest: `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`

The logical backtest preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, H1.

## Q02 queue mutation

An online SQLite backup was completed first at `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1257_q02_refresh_20260815T121051Z.sqlite` (SHA-256 `637738583eeef32dbba07fda7a844daccea55c50e7e8a1723e8131f9c6774bc6`, `quick_check=ok`).

At `2026-08-15T12:14:09.463931+00:00`, a single `BEGIN IMMEDIATE` transaction compare-and-swapped work item `d4cd660c-c81a-41d3-8a4c-ad21d3319816`, replaced its stale MQ5/EX5 bindings, removed prior runtime/staging fields, preserved attempt count 2 and history, appended transition-ledger sequence 1844, and released the repair hold. Exactly one open row exists for the logical Q02 identity. Post-state was `pending`, unclaimed, payload SHA-256 `3adee718bbb1377bebc67ba4e774321ae790c853e7de8825b58dd3075dd4d04b`. No duplicate row was enqueued.

Five CPU samples averaged 47.2% and peaked at 54.8%, below the 97% ceiling. Free RAM was only 1.19 GiB, below the 12 GiB two-leg basket admission floor. Accordingly, this session started no tester; the paced worker resource guard owns execution after headroom recovers.

## Zero-trades recovery status

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gap |
| --- | --- | --- | --- | --- | --- | --- | --- |
| QM5_1257 GBPUSD/USDJPY | `20260815_082908`, valid Q02 report | Entry implementation rejected valid mean reversion and mixed price/log cost units; hedge/magic/atomicity defects also present | Same-lineage card-conformance repair | PASS, 0/0 | Pending refreshed Q02 | Pending refreshed Q02 | Paced Q02 must prove entry events and nonzero trades; downstream gates remain untouched |

## Safety boundary

No card, registry, basket manifest, portfolio-admission gate, `_kpi`, `_q08_contribution`, T_Live manifest, or deploy artifact was changed. AutoTrading was not toggled. This work does not authorize live use and does not assert strategy success.

Machine-readable companion: `artifacts/qm5_1257_gbpusd_usdjpy_zero_trade_repair_q02_refresh_20260815T121409Z_board_advisor.json`.
