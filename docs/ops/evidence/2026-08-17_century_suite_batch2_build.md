# Century Suite batch 2 build and QM5_31003 dependency remediation

- Router task: `d4fb0821-3c6e-42be-8f8f-4e07d0460499`
- Operator: Codex
- UTC work window: 2026-08-16 23:12–23:36
- Branch/worktree: `agents/board-advisor`, `C:\QM\repo`
- Verdict: `BATCH2_BUILD_PASS_10_OF_77; QM5_31003_WITHHELD_MULTI_SYMBOL_DATA_GAP`

## Scope and cumulative progress

The deterministic worklist is `artifacts/century_clean_buildable.json` (77 rows).
The first five rows were already delivered in batch 1 at commit `05e8ef8b9`.
This batch built rows 6–10, so cumulative progress is **10/77 built** and **67/77
not yet built**.

| EA | Hosts / timeframe | Registry slots and magic | Source SHA-256 | EX5 SHA-256 |
|---|---|---|---|---|
| `QM5_31004_xauusd-vwap-liquidity-sweep-scalp` | XAUUSD.DWX / M5 | 0=`310040000` | `ae45ce333b3190e17625c1c2446824b90f79322d3f06168fa2fd257c3d035b2d` | `08bec73b4cb91cee2021c34504687e739c09af2dbffdb638d960371e83f95fcd` |
| `QM5_31005_japanstrike-tokyo-liquidity-breakout` | USDJPY.DWX, GBPJPY.DWX / M15 | 0=`310050000`, 1=`310050001` | `a49b330a1444d47515572ab69daa64e852c04a2af8bf0f36fea39ae18de5759d` | `ca8bd9f3d88e085d92aac1cc0fad99a99e280702b2be8f850a12e532320d94d4` |
| `QM5_31006_night-forex-bot-asian-stochastic-scalper` | USDCAD.DWX, AUDUSD.DWX, EURCHF.DWX / M15 | 0=`310060000`, 1=`310060001`, 2=`310060002` | `ecb340396bff7ca83169f975b950e4ff03b8b722e4bbd8fc693b79fb6ca8c23c` | `4631fd7c3bc4074aed117b4885fd51b0d4780ee2e4ba74daeeb67ed1c5a822b3` |
| `QM5_31007_forex-trend-hunter-triple-ema` | EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX / H1 | 0=`310070000`, 1=`310070001`, 2=`310070002` | `771a65cda36e02f288294aab4783cd02f76c36231969d8f0a02f86697fe2c2fd` | `9461ccf278a0ea3acb9e0420cc5463809446f4e65d2c982db77708b9fc10acaa` |
| `QM5_32001_nq-micro-momentum-apex-scalper` | NDX.DWX / M1 | 0=`320010000` | `cc8b387a4139ee914129ab41b446cbef982c47867e53a66dfb95beaef92d19c1` | `322e9ad5c5f16abcda220dc837309173d903667b5e4c5b1c2dbf8b770b3730d5` |

All ten registry rows were allocated after the EA directories existed, at
`2026-08-16T23:12:59Z`, with owner `Codex` and status `active`. The canonical
resolver dry run retained 16,107 rows, dropped zero, and produced registry hash
`75498D73419ACA43A7FD2F54CC6CEC602D7255000F1662E9C859EE1DDA36DF8C`.

Each `docs/strategy_card.md` is a byte-identical copy of its approved runtime
card. Card SHA-256 values, in table order, are:

- `133fb5d8455a3f4860c68fdaf8b464fd5523fc4a1022d47d870d3df711e1f502`
- `24634ff7895dd6cc39ed48e4001be8c00dd3c323b891f0e0096ba1976f3b8204`
- `ba9763e2504ab5e6ac31066d518141bf3b7e0f7889e0a02626d52606e21e7715`
- `00732700da48a875c4feab80bc241340ced31c8f89b194ff19bb46d938e71e20`
- `cfd6b9ecb59f3101ed594519ba7678b0a3a9ddb8985dd9aefaefc8f58abd2894`

## Implementation review notes

- 31004 reconstructs bounded current-session M5 VWAP and deviation, requires a
  two-deviation liquidity sweep plus RSI reversal, places the stop $1.50 beyond
  the signal-bar extreme, and admits the VWAP target only when it is at least
  2.2R away.
- 31005 reconstructs the configurable 22:00–00:00 UTC Tokyo box, admits the
  00:05–03:00 UTC two-pip closed-bar break, stops at the box midpoint, and uses
  2R.
- 31006 applies the approved 21:30–23:30 UTC M15 stochastic/Bollinger reversal
  with a one-ATR stop and one-ATR target.
- 31007 implements the H1 21/55/200 EMA trend/pullback gate, EMA-200 initial
  stop, 3.8R target, and monotonic three-ATR chandelier management.
- 32001 implements NDX M1 two-times-volume momentum with 9/21 EMA direction,
  15 price-point stop, 20 price-point target, and +1 price-point lock after a
  10-point favorable move.

Every declared input has at least one runtime reference in addition to its
declaration. No quoted `.DWX` dependency occurs in these five sources, and every
symbol-bearing first argument audited by `validate_symbol_scope.py` is
`_Symbol`; all five verdicts are `SINGLE_SYMBOL_OK`.

## Focused verification

| EA | Compile summary | Strict build report | Result |
|---|---|---|---|
| 31004 | `D:\QM\reports\compile\20260816_232210\summary.csv` | `D:\QM\reports\framework\21\build_check_20260816_232210.json` | PASS, 0 errors, 0 warnings; strict PASS, no findings |
| 31005 | `D:\QM\reports\compile\20260816_232247\summary.csv` | `D:\QM\reports\framework\21\build_check_20260816_232247.json` | PASS, 0 errors, 0 warnings; strict PASS, no findings |
| 31006 | `D:\QM\reports\compile\20260816_232326\summary.csv` | `D:\QM\reports\framework\21\build_check_20260816_232326.json` | PASS, 0 errors, 0 warnings; strict PASS, no findings |
| 31007 | `D:\QM\reports\compile\20260816_232404\summary.csv` | `D:\QM\reports\framework\21\build_check_20260816_232404.json` | PASS, 0 errors, 0 warnings; strict PASS, no findings |
| 32001 | `D:\QM\reports\compile\20260816_232441\summary.csv` | `D:\QM\reports\framework\21\build_check_20260816_232441.json` | PASS, 0 errors, 0 warnings; strict PASS, no findings |

Additional checks:

- `validate_build_guardrails.py --max-news-stale-hours 336`: aggregate PASS,
  zero findings across all five EA directories.
- `validate_spec_doc.py`: 5 PASS, 0 FAIL.
- Ten generated backtest sets: every file has `RISK_FIXED=1000` and
  `RISK_PERCENT=0`.
- `pytest tools/strategy_farm/tests/test_validate_symbol_scope.py -q`: 3 passed.
- `git diff --check` on authored source, registry, resolver, validator, tests,
  and this evidence: clean. The five byte-identical approved-card copies retain
  their upstream whitespace-only lines; changing them would break card hash
  identity.

No Q phase was enqueued or run. These are build results, not pipeline verdicts.

## QM5_31003 dependency finding and fail-closed disposition

QM5_31003 cannot enter the pipeline in its current form. The source initializes
`g_strength_pairs[28]` at lines 97–106 and calls
`CopyClose(g_strength_pairs[i], PERIOD_M15, 1, 97, closes)` at line 136. Its
three declared hosts are not a declaration of the other 25 runtime data
dependencies, and there is no `basket_manifest.json`.

The prior symbol validator inspected literal first arguments only, so the array
indirection incorrectly produced `SINGLE_SYMBOL_OK`. This batch extends
`tools/strategy_farm/validate_symbol_scope.py` to resolve simple static string
scalar/array initializers and bind an indexed first argument to each possible
symbol. It also preserves computed, unresolved expressions in the diagnostic
note rather than guessing. Three focused regression tests cover undeclared
arrays, manifest gaps, and unresolved computed arguments.

After the change, QM5_31003 returns:

```
MULTI_SYMBOL_LEAK_NOT_DECLARED  n_violations=28
L136 CopyClose(g_strength_pairs[i])
```

The preferred remediation is an offline, hash-bound daily G8 strength series,
not 28 live tester dependencies. A read-only cache inventory found usable M15
`.hc` and exported M15 CSV material for only **17/28** pairs. The missing 11 are
`CADJPY.DWX`, `CHFJPY.DWX`, `EURCAD.DWX`, `EURCHF.DWX`, `EURNZD.DWX`,
`GBPAUD.DWX`, `GBPCAD.DWX`, `GBPCHF.DWX`, `GBPNZD.DWX`, `NZDCHF.DWX`, and
`NZDJPY.DWX`. Raw annual `.hcc` archives exist for the missing pairs, but those
terminal-owned archives are not a governed, directly readable interchange
format and no complete exported M15 series exists in `T_Export\MQL5\Files`.

Therefore no offline artifact can be built reproducibly from the materialized
inputs in this task. Codex did not start a terminal, did not add a manifest as a
paper workaround, did not run a footprint canary, and did not enqueue Q02. The
next deterministic remediation task must authorize the existing governed
T_Export path to materialize all 28 M15 series (or provide an equivalent
versioned export), after which the offline precompute can be hash-bound and the
EA can be refactored to `_Symbol`-only runtime access.

## Review disposition

Review the five EA implementations, ten registry allocations, regenerated
resolver, and dynamic-array validator change. Accept the five builds only if
their card interpretations above are correct. Keep QM5_31003 withheld until the
complete offline input set and a reproducible derived artifact exist.
