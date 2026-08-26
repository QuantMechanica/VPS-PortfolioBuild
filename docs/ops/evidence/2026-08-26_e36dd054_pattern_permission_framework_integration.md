# Pattern-Permission framework integration — review artifact

- Router task: `e36dd054-5fc9-41bd-bdd9-f82691aa831e`
- Date: 2026-08-26
- Branch/worktree of record: `agents/board-advisor`, canonical checkout `C:/QM/repo`
- Status: **IMPLEMENTED; STATIC CONTRACTS PASS; GOVERNED RUNTIME ACCEPTANCE PENDING**

## Outcome

`QM_PatternPermission.mqh` is now part of the common framework include graph for new governed builds. `QM_Common.mqh` exposes six zero-default inputs (`opt_pp_buy1..3`, `opt_pp_sell1..3`) and configures a shared directional blacklist profile on the EA's current timeframe at closed shift 1. Both `QM_EntryInternal()` and `QM_BasketOpenPosition()` call the same `QM_EntryPatternAllows()` opinion before order construction.

The all-zero path is deliberately inert: `QM_EntryPatternAllows()` returns before `QM_PatternPermissionEvaluate()`, bar/history access, logging, RNG use, or pattern-cache mutation. Invalid nonzero predicate IDs fail framework initialization. A valid fired buy predicate vetoes only buy-family order types; a valid fired sell predicate vetoes only sell-family order types; invalid history blocks either attempted direction.

The three pre-integration pilot siblings `QM5_41161`, `QM5_41162`, and `QM5_41163` define `QM_PATTERN_PERMISSION_EA_MANAGED` before `QM_Common.mqh`. Their six existing inputs, explicit D1/profile contracts, counters, log vocabulary, and EA-local veto calls remain authoritative; the common gate is disabled for those binaries, avoiding duplicate evaluation or changed census accounting.

## Verification

| Check | Result |
|---|---|
| Pattern predicate + framework wiring static tests | PASS — `34 passed` |
| Default-inert early-return contract | PASS — no evaluator/history/log/RNG/cache reference before `return true` |
| Standard/basket shared-opinion contract | PASS |
| Pilot compatibility contract | PASS — all three retain six inputs and EA-local gates |
| `git diff --check` on scoped files | PASS |
| Governed compile attempt | Correctly refused as `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` while terminal processes were active; no retry/bypass |

Commands:

```powershell
python -m pytest framework/scripts/tests/test_pattern_permission_contract.py tools/strategy_farm/tests/test_pattern_permission_framework_wiring.py -q
pwsh -NoProfile -File framework/scripts/compile_one.ps1 -EAPath framework/templates/EA_Skeleton.mq5 -EALabel QM_pattern_permission_framework_integration -Strict -ReportRoot D:/QM/reports/compile_pattern_permission_framework
```

The second command produced only the refusal receipt at `framework/build/compile/20260826_102355/EA_Skeleton.compile.log`; MetaEditor did not compile and no terminal/tester was started.

## Runtime acceptance boundary

The requested before/after identical-trade-list run and native report Inputs echo are **not claimed** in this artifact. The live factory interlock prohibits an ad-hoc build while T1-T10 are active, and this cycle did not interrupt a backtest, manually start `terminal64.exe`, invent an untracked EA identity, or enqueue a fleet rebuild. Static evidence proves the code path is inert; it does not substitute for the requested native tester comparison.

The reviewer should keep runtime acceptance open until one governed new identity is compiled and run with its unchanged set file, then bind:

1. old/new source, EX5, setfile, report, and trade-list hashes;
2. exact trade-list equality with all six inputs zero/absent;
3. report Inputs-region echo for all six `opt_pp_*` names.

## Rollout and identity contract

- New governed builds that include `QM_Common.mqh` inherit the instrumentation automatically.
- Existing EX5 binaries remain unchanged. No mass rebuild is authorized by this patch.
- An incumbent rebuilt against this include closure becomes a new executable identity from Q02; historical gate evidence does not transfer by filename.
- Altbestand is rebuilt only opportunistically at the next already-authorized governed compile, or under a separate OWNER-authorized cohort decision.
- The patch changes no gate thresholds or verdict logic, no DL-089 selection rule, no news stale ceiling, and no risk setfile values.

## Files of interest

- `framework/include/QM/QM_Common.mqh`
- `framework/include/QM/QM_Entry.mqh`
- `framework/include/QM/QM_BasketOrder.mqh`
- `framework/include/QM/QM_PatternPermission.mqh`
- `tools/strategy_farm/tests/test_pattern_permission_framework_wiring.py`

