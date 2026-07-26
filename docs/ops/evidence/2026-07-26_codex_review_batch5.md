# Codex micro-closure review — batch 5

Date: 2026-07-26  
Branch: `agents/board-advisor`  
Review object: working tree at HEAD `e81eb0041f976da9299bb3586c447a981a1f15da`  
Mode: source review, synthetic temporary probes, named pytest suites, and SQLite `mode=ro` inspection only.

## Verdicts

| Item | Verdict | Result |
|---|---|---|
| Declared `traded_symbols` authority | **APPROVE** | Key presence is authoritative; empty, blank, and non-list declarations reject without derivation fall-through. |
| Non-string `build_task_id` safety | **APPROVE** | Both review paths ignore non-empty-string violations without crashing; live old/new parity holds. |

## Fix 1 probes

The batch-4 six-row table now returns:

| Probe | Result |
|---|---|
| Active logical registry row, no authoritative legs | reject: unknown legs |
| `traded_symbols=["  "]` plus valid derivation | reject: unknown legs |
| `basket_symbols == conversion_symbols` | reject: unknown legs |
| Non-empty declared `traded_symbols`, all legs active | qualify: `(True, None)` |
| Non-empty derivation with no declared key, all legs active | qualify: `(True, None)` |
| Declared `traded_symbols=[]` plus valid derivation | reject: unknown legs |

Invariant confirmed: baskets qualify only through a non-empty declared `traded_symbols`, or a non-empty `basket_symbols - conversion_symbols` derivation when the declared key is absent. Source inspection confirms the declared-key branch always returns and cannot fall through.

All ten backfilled manifests (1058, 12712, 12772, 12778, 12781, 12831, 12864, 13059, 13076, 13117) still have non-empty normalized declarations exactly equal to their active magic-registry rows; each returned `(True, None)`.

## Fix 2 probes

List-, dict-, null-, and empty-string-valued `build_task_id` payloads were exercised on both `codex_review` and `ea_review`. No case raised; invalid Codex IDs did not qualify a build, and invalid EA-review IDs did not cover one. Source inspection confirms the non-empty-string guard precedes both set insertions.

One transaction on `file:///D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` contained 6,124 relevant rows: legacy SQL `n_starved=4`, ratified helper `n_starved=4`. `chk_claude_review_starved` returned cleanly with `status=OK`, `value=4`, `threshold=5`.

## Pytest

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_qualification.py tools/strategy_farm/tests/test_requeue_stranded_infra.py tools/strategy_farm/tests/test_health_starvation.py -q
...............................................                          [100%]
47 passed in 2.63s
```

Not verified: no real requeue/apply/canary, DB write, `T_Live` inspection, backfill source-derivation retrace, or git mutation was performed.

Both items are **APPROVE**. The full batch-2/3/4 chain is closed and the commit series may proceed.
