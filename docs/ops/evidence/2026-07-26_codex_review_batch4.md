# Codex focused closure review — batch 4

Date: 2026-07-26  
Branch: `agents/board-advisor`  
Review object: working tree at HEAD `887a7b0a1e443f6242de3818de17e8f9e31f493f`  
Mode: source review, named pytest suites, filesystem inspection, synthetic temporary DB/filesystem probes, and SQLite `mode=ro` queries only. No real requeue/apply/canary, pipeline phase, MT5 action, `T_Live` access, or git mutation was performed.

## Verdicts

| # | Item | Verdict | Closure result |
|---:|---|---|---|
| 1 | Basket-magic bypasses | **CHANGES-REQUIRED** | The three exact batch-3 probes now reject, basket successes require a non-empty leg set, plain-symbol round-3 behavior is unchanged, and all ten backfills qualify. One empty-normalization hole remains: declared `traded_symbols=[]` is treated as absent and can fall through to a valid derivation, contrary to the stated “declared-but-blank rejects, no fall-through” contract. |
| 2 | Requeue partial-revert journal state | **APPROVE** | Partial revert remains actionable, repeated still-drifted reverts remain non-zero/partial, and a later exact-post-apply row completes cleanly. Pre-apply crash recovery and unarchive-failure abort remain intact. |
| 3 | `health.py` ratified contract | **CHANGES-REQUIRED** | Every batch-3 table case has the ratified result and the live snapshot has old/new parity. However, a valid top-level JSON object with a list/dict-valued `build_task_id` raises `TypeError` in the new helper, regressing the health check from non-match to crash. The new tests also omit a dedicated compact-`ea_review` case from the divergent table. |

## 1. Basket-magic closure

The control flow now classifies `BASKET_SYMBOL_RE` before the direct match. A basket can return success only after `_basket_required_legs` returns a non-empty list; both the declared-leg and derived-leg success paths satisfy that narrow invariant. The plain branch remains the same round-3 truth table: success iff the normalized candidate symbol is in the EA's active set.

Synthetic results:

| Probe | Result |
|---|---|
| Active logical registry row, no authoritative legs | reject: `active_magic_unknown_legs:QM5_9001_A_B_D1:traded_symbols_undeclared` |
| `traded_symbols=["  "]` plus an otherwise valid derivation | reject with the same unknown-legs blocker; no fall-through |
| `basket_symbols == conversion_symbols` | reject with the same unknown-legs blocker |
| Non-empty declared traded set, all rows active | qualify |
| Non-empty `basket_symbols - conversion_symbols`, all rows active | qualify |
| **Declared `traded_symbols=[]` plus a valid non-empty derivation** | **qualifies `(True, None)`** |

The last row is still an empty normalized declared set. At `ftmo_qualification.py:125-126`, the `and traded` guard prevents the declared branch from running, so line 131 falls through to derivation. Distinguish key absence from a declared empty/invalid value and add a probe containing both `traded_symbols=[]` and otherwise-valid derivation fields.

Filesystem/registry verification passed for all ten backfills: 1058, 12712, 12772, 12778, 12781, 12831, 12864, 13059, 13076, and 13117. Each manifest has one EA directory, a non-empty normalized `traded_symbols`, exact set equality with that EA's active rows in `framework/registry/magic_numbers.csv`, and `_active_magic_registered(...) == (True, None)`.

## 2. Requeue closure and canary

Source inspection confirms that only `state == "reverted"` early-outs (`requeue_stranded_infra.py:813`) and journal state becomes `reverted` only when `skipped` is empty; otherwise it remains `partially_reverted` (line 918).

The batch-3 two-row probe and additional reruns produced:

| Step | Exit | Restored | Journal | Remaining row/archive state |
|---|---:|---:|---|---|
| First revert with `wi600` active/claimed | 1 | 1 | `partially_reverted` | `wi500` restored; `wi600` and its archive untouched |
| Immediate rerun while `wi600` is still drifted | 1 | 0 | `partially_reverted` | unchanged; no false success |
| Restore `wi600` to exact journalled post-apply state and rerun | 0 | 1 | `reverted` | original root restored; archive removed |

An independent pre-apply classification probe restored the archived root, left the already-pre-apply DB row untouched, returned 0, and marked the journal `reverted`. The named suite's injected unarchive-failure test also passed: it aborts before DB restore, preserves the post-apply row/archive, and returns non-zero.

**Canary statement:** the requeue tool is now technically cleared for the requested canary-50 only during a verified **Factory-OFF/quiescent** window (factory, workers, and pump stopped). This is not permission to execute it Factory-ON and no canary was run in this review.

## 3. `health.py` ratified-contract closure

The batch-3 table reproduced under the ratified semantics:

| Payload case | Old SQL | Ratified helper |
|---|---:|---:|
| Canonical Codex PASS, no EA review | 1 | 1 |
| Malformed Codex JSON containing the legacy substrings | 1 | 0 |
| Codex review missing `build_task_id` | 0 | 0 |
| Canonical pending/failed `ea_review` coverage | 0 | 0 |
| Malformed `ea_review` containing the legacy ID substring | 0 | 1 |
| Compact Codex JSON | 0 | 1 |
| Compact `ea_review` JSON | 1 | 0 |
| Lower-case `"verdict": "pass"` | 1 | 0 |
| Nested, not top-level, `build_task_id` | 1 | 0 |

`chk_claude_review_starved` fetches the three task kinds and calls `_count_starved_builds` directly (`health.py:822`). The working-tree diff in `health.py` is confined to the two ratified helpers and this starvation check; no unrelated health check changed.

One new structural regression remains. Both of these valid JSON-object shapes raise `TypeError: unhashable type: 'list'` at lines 803/807 rather than being ignored as a non-matching task ID:

```json
{"build_task_id": ["b1"], "verdict": "PASS"}
```

The same occurs with an object-valued ID. Ratify and enforce a non-empty string `build_task_id` before inserting it into either set, and pin both Codex and EA-review cases. Also add the missing explicit compact-`ea_review` test; the independent probe currently returns the correct ratified result.

Live read-only comparison used one transaction on:

```text
file:///D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro
```

It contained 6,123 relevant rows. Old SQL and the ratified helper both returned `n_starved=5`; done Codex reviews and all EA reviews had zero JSON parse failures and zero non-string `build_task_id` values. Calling `chk_claude_review_starved` itself returned `status=OK`, `value=5`, `threshold=5`. The count moved from batch 3's 4 because the live DB moved; parity on the same snapshot holds.

## Pytest

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_qualification.py tools/strategy_farm/tests/test_requeue_stranded_infra.py tools/strategy_farm/tests/test_health_starvation.py -q
...........................................                              [100%]
43 passed in 2.52s
```

## Not independently verified

- No requeue apply, revert, or canary touched the real farm DB or report roots. Revert behavior was exercised only in synthetic temporary DB/filesystem fixtures.
- No process-kill or power-loss test was performed; the Windows directory-entry durability caveat from batch 3 remains.
- Factory-OFF/quiescent state was not established because no canary was executed.
- The ten backfills were rechecked against manifests, registry rows, and the qualification helper; their source-level order-call derivations were not retraced in this closure round.
- The live farm DB was observed in one moving, read-only snapshot only. No DB write was attempted.
- No compile, backtest, pipeline phase, MT5 terminal, deployment, AutoTrading, or `C:\QM\mt5\T_Live` inspection was performed.
