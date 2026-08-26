# Q12 DL-089 Pattern Candidate Declarations — 3-Pair Correction

- Date: 2026-08-26
- Router task: `3979b469-44b4-43de-8a8f-d478b9e8d51b`
- Execution checkout: `C:/QM/repo`
- Execution branch: `agents/board-advisor`
- Verdict: `PASS_FOR_REVIEW_WITH_MEASUREMENT_BLOCKER`

## Outcome

The three original Q12 rows did not evaluate the pattern lever. Their payloads
contained no pattern-search key, `declared_parameter_count=0`, and
`declared_trial_count_increment=0`. The resulting Q12/Q13/Q14 receipts recorded
`NO_FILTER_CHANGE` → `NO_PARAMETER_CHANGE` → `KEEP_INCUMBENT`, with
`measured_candidate_adjudicated=false`.

The original rows and receipts are unchanged. Three new append-only Q12 rows now
carry a complete DL-089 declaration:

- 154 candidates: 77 implemented predicates × BUY/SELL;
- one declared pattern parameter per candidate;
- seven annual repeats per candidate, plus seven baseline cells;
- 1,085 deterministic annual cell identities for 2019–2025;
- four deterministic anchored walk-forward combination cell identities for
  test years 2022–2025;
- `declared_trial_count=154` (annual repeats are not additional trials);
- the frequency metric and fail-closed floor on every candidate;
- a Q12 execution budget of 1,089 backtests per pair, with a serial pair mode
  and an eight-cell priority window;
- the exact, byte-preserved sealed selection-rule block extracted from the
  authority document and pinned by SHA-256.

No Q12 measurement has run. All three declarations correctly report an EA
instrumentation blocker, so `measured_candidate_adjudicated` remains `false`.

## Authority bindings

| Authority | SHA-256 |
|---|---|
| `decisions/DL-089_pattern_filter_wf_census_v3.md` | `6C10D3F4E78F1787C7993466F672740A02D37B30BA1F2073157EF802835794CA` |
| `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md` | `45CFB111C28998B36AE9B0458929C97F036A7D6D833B7B92029FC614D67F8252` |
| Extracted sealed rule block | `4CC2BBD108BF500F33EF5EEE30536C9A4AFE58DC2684116A972C0BFB65F3D383` |
| Active gate manifest | `F71C1EA63F1E847B3670904A6DE25BCB4B337DF9E0A7CFF8EE6405D9C3AA2C83` |

The implementation does not retype or recalibrate the red-zone rule. It calls
the existing `opt_census.sealed_header()` extractor, which refuses any drift in
the exact rule bytes. The structured declaration carries the existing machine
constants (`2/3`, `0.05`, entry-trading-day floor 10, and the four anchored WF
windows) alongside that sealed text.

## Original evidence preserved

| Pair / Q phase | Work item | Receipt SHA-256 |
|---|---|---|
| QM5_10706 / GBPUSD.DWX / Q12 | `48c41285-5849-534d-aeac-836deb9a9cb8` | `B4558D97EE2FAE1B1970B4C00A7CA2F21362218BCF86197C04A664EA531CA260` |
| QM5_10706 / GBPUSD.DWX / Q13 | `e1e86d92-52c6-519b-b628-b865309c42c5` | `D3955F5BC7263F55BA43C58F576C0E37EAFCE35519B57701F956E89A17FC445B` |
| QM5_10706 / GBPUSD.DWX / Q14 | `b5e18759-1377-5af7-9634-9f66bd293d0c` | `5D39D3696F8411FF667AD9171A0C12227D0EE71EA47011F0F75E738062E57212` |
| QM5_11421 / EURUSD.DWX / Q12 | `2a2bf134-9832-51f4-96bd-e2116b8fa1dc` | `A1D887AD30DEDB52E6B07277967E85A0E63A03D5ECF66D68A9645374EE02FEE9` |
| QM5_11421 / EURUSD.DWX / Q13 | `cc00fccc-1bdd-5706-8634-a5b06cc079b0` | `40BAC75CB903879C93C1E85BD3EFB8F2FD270D429B59904E205B46F7745C1F2F` |
| QM5_11421 / EURUSD.DWX / Q14 | `a42f2a71-ed1c-538a-b97a-142a67b907f2` | `D672100B5AA719B4BE9F7B9042570C56134A628047BCCFCEA853706C5631ACEC` |
| QM5_11422 / USDCAD.DWX / Q12 | `09c21c5c-1119-52e7-ac02-8cb3ead754c6` | `34F49430863405277302AFFFCF10872C82BA03B2598340FB8F57F6A450E96722` |
| QM5_11422 / USDCAD.DWX / Q13 | `b1ce8e01-5c2a-5f91-a03d-46a730baf4b9` | `CF6977BD14E785E900C6918E168C24B3B46BAEB206325D33C1F2F2F4304E0830` |
| QM5_11422 / USDCAD.DWX / Q14 | `3078ad67-9a19-56cb-a252-0a112596343a` | `197DE269B326A3FC8D24C5522D8F0BF4EB48303F730E06C525C8A41DD5264C01` |

The three old Q12 rows remain `done/NO_FILTER_CHANGE`; no verdict or timestamp
was touched.

## New append-only Q12 rows

| Pair | Old Q12 | New Q12 | Bound parent | Payload SHA-256 | Declaration SHA-256 |
|---|---|---|---|---|---|
| QM5_10706 / GBPUSD.DWX | `48c41285-5849-534d-aeac-836deb9a9cb8` | `dfca24fa-28df-5f5e-818f-8dcf53611822` | `f06b8243-d3ca-490a-8b47-7c598f4d6d58` | `FE813E7674322BF2636F5C47CDC843AEFC1CBFD624DABA6306A71E288B9EA9AD` | `6DD542A2302EC5EE866C3C12E2509E200B15C6904F1E1D196C5451685C2BC49B` |
| QM5_11421 / EURUSD.DWX | `2a2bf134-9832-51f4-96bd-e2116b8fa1dc` | `d0e53004-659c-563c-8314-c24ad4ab2a68` | `38eddd19-0d07-4686-b1e2-afc4124e9bc8` | `11D4F8302BC0C232009CE5DEEED3B1BEA8B78B6C95034F82BF0F922557EAE01F` | `40DB534EC0C022EB8A5F98CCC5372ABF5189511479B30EF176568D866A5FE7CB` |
| QM5_11422 / USDCAD.DWX | `09c21c5c-1119-52e7-ac02-8cb3ead754c6` | `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` | `6f9400fa-9ca2-4835-9fcf-e1087289f9b1` | `B48392CBD84A3BE798AB59AD3C01EE1BC1FE5EE85099C576B01DC44C7ECC953F` | `40021ABDCEBBF4EB9CF51DC4864242BE34317DE72B1B763D9935A51A2658E233` |

All three new rows are `pending`, have no verdict, use routing revision
`dl089-annual-wf-cells-v1`, and bind the same authenticated parent artifacts as
their preserved predecessor. The two pruned parent reports were revalidated
from their hash-bound gzip siblings; nothing was restored or rewritten.

The common 154-candidate manifest SHA-256 is
`510C9C173FE99D50E79E5BF8DF899BEDBB882199D5D0846C98FEB3D08BB6BF1D`.
Annual-cell and WF-cell hashes are pair-specific because the deterministic cell
keys bind EA and symbol:

| Pair | 1,085 annual cells SHA-256 | 4 WF cells SHA-256 |
|---|---|---|
| QM5_10706 / GBPUSD.DWX | `A27D6D8D35FC2CFC96030265EADACAFF620AFBF5E3067E5B56065E29A14BEF57` | `DF84810838FFA069E1648A8E5C6382931C9BFA09F29D2C97CF1B2968ACE99BF6` |
| QM5_11421 / EURUSD.DWX | `F7728EE2DD84F6266F76901E40C025E77E4BD19341EB15AAA908DD2EFB06CCB0` | `F214936907FEC30713A8F016848DAC9F476F74775FB9459440EA872BCB9984BC` |
| QM5_11422 / USDCAD.DWX | `5E35C1126EF81102122D1780D82EFA82A6A3E2CFBEB51582711A9EC348F40068` | `5AA10D73C7BB9E682D854966CA3D1841CDC5D06F94DB6E887742459DD69855CE` |

## Anchored WF cells

These are the exact deterministic identities later used by
`opt_census_select.py`; the selected combination remains derived only after the
annual matrix is complete.

| Pair | Step / test year | Work item ID |
|---|---|---|
| QM5_10706 / GBPUSD.DWX | 1 / 2022 | `00c89a49-3c53-51ac-b98c-237968a6a89c` |
| QM5_10706 / GBPUSD.DWX | 2 / 2023 | `3c235f36-9049-584e-983b-e844a86a95ec` |
| QM5_10706 / GBPUSD.DWX | 3 / 2024 | `a5b92e9f-7e67-580e-9c28-ea4f3feaf288` |
| QM5_10706 / GBPUSD.DWX | 4 / 2025 | `3abc6829-f40e-508a-bb94-17bb8bd757ac` |
| QM5_11421 / EURUSD.DWX | 1 / 2022 | `e972dfeb-a7f2-58a2-8c4c-482a0bb65ec1` |
| QM5_11421 / EURUSD.DWX | 2 / 2023 | `6a10e1ff-59f0-5611-a4cc-1f03b8f958b1` |
| QM5_11421 / EURUSD.DWX | 3 / 2024 | `727948af-b4f4-5a15-86c0-48e91ee7ef8b` |
| QM5_11421 / EURUSD.DWX | 4 / 2025 | `a4938d29-4f82-587a-870a-0e3edd54003e` |
| QM5_11422 / USDCAD.DWX | 1 / 2022 | `a9121651-da6f-5edc-a75b-a016e2000a54` |
| QM5_11422 / USDCAD.DWX | 2 / 2023 | `2f576048-6229-554e-9f1c-45622ec29305` |
| QM5_11422 / USDCAD.DWX | 3 / 2024 | `eb887675-d6b7-583d-8831-f12703f44136` |
| QM5_11422 / USDCAD.DWX | 4 / 2025 | `50046c12-8b4a-597f-9f45-61821dd0a1fd` |

## Candidate frequency and parameter declaration

Every one of the 154 candidate records declares:

- `declared_parameter_count=1`;
- `annual_measurement_cell_count=7`;
- frequency metric `entry_trading_days`;
- frequency floor 10 per scored year;
- fail-closed exclusion if any scored year breaks that floor.

At sweep level, each pair declares 154 parameters/hypotheses, 154 trials, 1,085
annual cells, four WF cells, and `q12_backtest_budget=1089`. The two later
full-window controls bring the pre-numeric pattern-chain budget to 1,091, exactly
as stated in the plan. Numeric cells are not invented here and must increase the
effective trial ledger before their own measurement.

## Measurement blocker template

All three bound sources and setfiles lack:

```text
opt_pp_buy1, opt_pp_buy2, opt_pp_buy3,
opt_pp_sell1, opt_pp_sell2, opt_pp_sell3
```

All three sources also lack `QM_PatternPermissionEvaluate` wiring. The bound
QM5_10706 Q10 setfile additionally lacks the explicit backtest-environment
header required by `opt_census.py`. Risk values remain compliant on every pair:
`RISK_FIXED=1000`, `RISK_PERCENT=0`; no stale-news maximum above 336 was found.

Therefore the machine blocker is
`PATTERN_FILTER_INSTRUMENTATION_REQUIRED`. Resolution is deliberately separate
from this dispatch correction:

1. Route a governed build of an `_opt` sibling with the six inputs and symmetric
   permission vetoes; do not mutate the binaries bound to these Q12 parents.
2. Compile and clear the sibling's build and Q02 prerequisites with fixed-risk
   backtest sets and the news fail-closed maximum unchanged.
3. Materialize the already-declared matrix through `opt_census.py`, one pair at
   a time, with the eight-cell rolling priority window.
4. Only after all annual and WF cells are measured may the governed evaluator
   emit a receipt with `measured_candidate_adjudicated=true` or a measured
   fail-closed outcome.

No untracked build or measurement task was invented during this cycle.

## Verification

Code commit:
`24b7433c46e9a51d66ccd2e051979d6fc947bf64`
(`fix: declare sealed pattern search in Q12`).

Focused regression command:

```text
python -m pytest -q tools/strategy_farm/tests/test_optimization_fork_driver.py tools/strategy_farm/tests/test_optimization_fork_service.py tools/strategy_farm/tests/test_opt_census.py tools/strategy_farm/tests/test_opt_census_select.py tools/strategy_farm/tests/test_opt_census_dispatch.py
57 passed in 15.99s
```

The tests prove that a future Q11 PASS automatically receives the complete Q12
declaration, that legacy zero-search rows get a distinct append-only successor,
that all annual/WF cell identities are unique and deterministic, and that the
legacy no-change service leaves a declared row pending.

Targeted service dry-run over the three new Q12 IDs returned:

```text
planned=[]
completed=[]
deferred=3
machine_reason=GOVERNED_EVALUATOR_REQUIRED:declared pattern work requires governed selection: pattern_filter_sweep
```

A second targeted apply of the router returned `created=false`,
`idempotent=true` for each new Q12 ID. No terminal was started, no backtest was
interrupted, no Q12/Q13/Q14 verdict was changed, and T_Live was untouched.
