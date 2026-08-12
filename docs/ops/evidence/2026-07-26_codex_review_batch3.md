# Codex independent review — batch 3

Date: 2026-07-26  
Branch: `agents/board-advisor`  
Mode: source review, permitted tests, filesystem inspection, synthetic temporary-file tests, and SQLite `mode=ro` queries only. No farm apply/canary, compile, MT5 terminal, backtest, `C:\QM\mt5\T_Live`, or git mutation was performed.

The factory moved HEAD during the review from `b7516bf862a642b342a1ed36e62d48230cbf46ce` to `887a7b0a1e443f6242de3818de17e8f9e31f493f`. The intervening factory commits touched public-data snapshots and unrelated Q06 setfiles, not the reviewed files. The final working tree, not either commit boundary, is the review object.

## Verdicts

| # | Item | Verdict | Finding |
|---:|---|---|---|
| 1 | Basket-magic fail-closed repair | **CHANGES-REQUIRED** | The exact batch-2 missing-second-leg counterexample now rejects, the unsafe host-plus-consistency fallback is gone, and the ten backfills match active registry rows. However, an active row for the logical `QM5_<id>_...` symbol still returns success before basket classification, bypassing both authoritative-leg paths. Empty normalized/derived leg sets also pass. The implementation therefore still has qualification paths other than non-empty authoritative `traded_symbols` or non-empty complete `basket_symbols - conversion_symbols`. |
| 2 | Requeue crash-safety repair | **CHANGES-REQUIRED** | All four batch-2 archival defects are materially repaired, but partial revert is not safely rerunnable: if one row is restored and another is refused for drift, the journal is nevertheless marked `reverted`. A later `--revert` returns exit 0 without restoring the formerly drifted row or its archive. |
| 3 | FINAL23 OPTION-B generator and staged artifacts | **APPROVE** | A clean-room re-solve reproduces the FINAL24b base and all claimed FINAL23 weights/KPIs. All 23 preset risks and hashes match, the two declared copies are byte-identical to FINAL24b, XNGUSD is absent, and 12567/XAUUSD is correctly retained at cap. |
| 4 | `health.py` in-memory starvation check | **CHANGES-REQUIRED** | The current farm snapshot happens to produce the same count, but the rewrite is not semantically equivalent to the old SQL. Malformed, compact, nested, and case-varied payloads produce different answers. Missing IDs and any-status `ea_review` coverage behave as claimed for canonical JSON. |

## 1. Basket-magic repair

### What is fixed

- The batch-2 structural counterexample is now covered directly by `test_basket_without_authoritative_legs_second_leg_removed_is_rejected`: host active, genuinely traded second-leg registry row absent, no inactive contradiction, and neither authoritative key declared. It rejects with `active_magic_unknown_legs:...:traded_symbols_undeclared`.
- The host-plus-registry-consistency fallback has been removed. `_basket_required_legs` now selects declared `traded_symbols`, or derives `basket_symbols - conversion_symbols`; absent both, it returns `None` and the caller rejects.
- The neighboring qualification rails were not weakened. `STRICT_PHASES` remains Q02/Q03/Q04/Q05/Q06/Q07/Q08/Q10; every latest verdict must be the literal `PASS`; phase evidence and the linked intraday stream must not predate the binary; the default minimum remains 50 trades; and plain symbols retain exact active `(ea_id, symbol)` lookup behavior.

### Remaining fail-open paths

The implementation does not satisfy the requested “only two basket qualification paths” invariant:

1. `ftmo_qualification.py:165-166` returns success whenever the candidate symbol itself is in the active registry set. Basket detection is later at line 169. A synthetic logical basket with an active registry row for `QM5_9001_A_B_D1`, no `traded_symbols`, and no `conversion_symbols` returned:

   ```text
   active_logical_row_no_authoritative_legs (True, None)
   ```

   A logical registry row is not evidence that every real broker leg has an active magic row. Classify basket symbols before the direct-match return; preserve the direct path only for plain symbols.

2. The helper checks that the raw lists are non-empty, but not that normalization/derivation produces a non-empty traded set. Both synthetic malformed cases returned success with an empty active registry:

   ```text
   traded_symbols=["  "]                         -> (True, None)
   basket_symbols=["A.DWX"], conversion_symbols=["A.DWX"] -> (True, None)
   ```

   Require at least one non-empty normalized required leg, and reject an empty `basket_symbols - conversion_symbols` result.

These are structural bypasses, even though the current registry has no active logical-symbol rows and the ten real backfills are well formed. The repair has narrowed, but not closed, the fail-closed defect.

### Backfill verification

All ten written `traded_symbols` sets exactly equal their EA's active rows in `framework/registry/magic_numbers.csv`: 1058, 12712, 12772, 12778, 12781, 12831, 12864, 13059, 13076, and 13117.

Independent source spot-checks covered five:

- **1058:** `ResolvePairForSymbol` maps EURUSD/GBPUSD to slots 0/1 and AUDUSD/NZDUSD to slots 2/3; `OpenPair` sends both configured legs through `QM_BasketOpenPosition`. Manifest and active registry therefore correctly contain all four.
- **12712:** only `g_leg_eurgbp` and `g_leg_euraud` are passed to `Strategy_OpenLeg`; manifest and active rows contain exactly EURGBP/EURAUD.
- **12778:** only `g_leg_audusd` and `g_leg_eurjpy` are opened; EURUSD/EURAUD are warmup/conversion symbols. Manifest and active rows contain exactly AUDUSD/EURJPY.
- **12831:** XTI is opened as the host request and AUDUSD through `Strategy_OpenBasketLeg`; both are declared and active.
- **13117:** only EURGBP/AUDJPY are passed to `Strategy_OpenLeg`; GBPUSD/USDJPY are conversion/warmup scope. Manifest and active rows contain exactly EURGBP/AUDJPY.

Targeted test:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_qualification.py -q
..............                                                           [100%]
14 passed in 0.67s
```

## 2. Requeue crash-safety repair

### Batch-2 defects

The four requested repairs are present:

- **Fatal archive failure with compensation:** `_apply` writes no row flips until all archive renames succeed. Any rename `OSError` is fatal; completed moves are renamed back in reverse order, and the SQLite transaction rolls back.
- **Durable pre-move journal:** the complete per-row `archive_src -> archive_dst` map plus exact pre-apply and expected post-apply row states is assembled before movement. `_write_journal` writes a same-directory temporary file, flushes and `fsync`s it, then atomically replaces the journal before the first report-root move and before DB commit.
- **Filesystem-first revert:** under `BEGIN IMMEDIATE`, revert classifies rows, restores eligible report roots before issuing an UPDATE, and compensates already completed unarchives if any unarchive fails. It rolls back and returns non-zero without restoring DB rows; failures are surfaced rather than swallowed.
- **Exact drift guard:** `_state_matches` compares all journalled mutable fields: status, verdict, attempt count, evidence path, claimant, byte-exact payload JSON, and updated timestamp. Exact pre-apply state is additionally accepted for crash/idempotence recovery.

The attempt-count floor (`>=12`), exact `LOG_BOMB` marker checks, transaction-local second eligibility pass, setfile-grain sibling queries, stale-payload cleanup, and pending flip shape are preserved.

### New blocking recovery defect

`_revert` records drifted rows in `skipped`, but line 913 unconditionally sets the whole journal to `state="reverted"`. Line 813 then makes every later invocation return exit 0 immediately.

A two-row synthetic run demonstrated the consequence:

1. Apply two rows.
2. Drift `wi600` to active/claimed.
3. Revert restores `wi500` and refuses `wi600`, returning exit 1.
4. The journal is nevertheless `reverted`.
5. Put `wi600` back into the exact journalled post-apply state and rerun revert.

Observed:

```text
first revert:  restored=1, skipped_drifted=[wi600], exit_code=1
journal state: reverted
second revert: restored=0, skipped_drifted=[], exit_code=0
wi600:         status=pending, verdict=NULL
archive:       still exists
original root: absent
```

Thus a rerun is a no-op, but not an idempotent completion/recovery operation; worse, it reports clean success while one journal entry remains unreverted. Mark the journal `reverted` only when no entries were refused. A partial state should retain actionable entries so a later run can accept exact pre-apply rows as already restored and process formerly drifted rows once they again match the expected post-apply state.

### Residual windows and canary decision

- The Windows directory-entry durability caveat is real. File `fsync` covers journal contents, but `os.replace` does not explicitly flush the parent directory, and report-root directory renames are not explicitly flushed. A sudden power loss can therefore still expose metadata-ordering uncertainty. On NTFS this is a limited practical residual, not an ACID guarantee.
- The stated crash window between revert unarchive and DB commit is recoverable in the clean/no-drift case. On rerun, an already restored source root is treated as complete; the still-post-apply row is then restored. A crash after DB commit but before journal marking is also recovered through the exact pre-apply branch.
- Those residuals are acceptable for a limited, manually verified canary only with the factory, workers, and pump quiescent. They do not justify Factory-ON execution.

**Canary decision:** the batch-2 **Factory-OFF-only** restriction stands, but no canary should run yet. Repair and test the partial-revert journal state first; then canary 50 only during a Factory-OFF/quiescent window.

Targeted test:

```text
python -m pytest tools/strategy_farm/tests/test_requeue_stranded_infra.py -q
................                                                         [100%]
16 passed in 1.46s
```

The passing suite does not exercise “partial drift refusal, then a second revert.”

## 3. FINAL23 OPTION-B

### Evidence and independent solve

Both cited 12567/XNGUSD aggregates exist and are dated 2026-07-18 and 2026-07-25. Both say `FAIL_HARD` with the same load-bearing sub-gates: seasonal 9/12, edge decay 41.52% (`PF 1.7642 -> 1.0318`, hard threshold 40%), and low-volatility regime P&L `-231.40`; neighborhood, chopping block, and MC-shuffle DD are PASS.

I independently parsed the 24 input JSONL streams, applied the commission registry, aggregated UTC daily net-of-cost P&L, aligned the union calendar, and implemented population-daily-vol inverse weighting plus cap redistribution without calling the generator's solve or KPI helpers.

Base FINAL24b reproduction:

- 24 sleeves, 2,011 union days, 2017-10-09 through 2025-12-30.
- Sharpe `2.3439999867`, exactly the base manifest value.
- Maximum unrounded weight error versus the six-decimal manifest: `4.329685783e-7` (reported as `4.3e-7`).
- Unrounded weight sum `11.999999999999998`.

FINAL23 re-solve:

- 23 sleeves, 2,010 union days.
- Sharpe `2.2953235301`.
- Faithful constant-SC MaxDD `3.9871151045%`, emitted as `3.9871%`.
- Running-peak MaxDD `3.054895624%`.
- Net-of-cost profit `96969.5579379802`.
- Unrounded weight sum `11.999999999999996`.
- At cap: `10919/XTIUSD`, `12567/XAUUSD`, and `13128/NDX`.
- Maximum unrounded error versus emitted six-decimal FINAL23 weights: `4.952920636e-7`.

The emitted rounded weights sum to `11.999999`, exactly `-0.000001` from 12.0 and within the requested ±`1e-6` rail.

### Presets and staging report

- Exactly 23 `.set` files are staged, with one manifest sleeve per file after resolving basket `host_symbol` headers.
- Every `RISK_PERCENT` exactly equals its manifest sleeve value; decimal sum is `11.999999`.
- All 23 actual SHA-256 values match the staging report (21 entries under `staged`, two under `verbatim_copies`).
- `04_XTIUSD_H4_QM5_10919_grimes-overshoot.set` is byte-identical to FINAL24b, SHA-256 `3440912e6d25410608b3652840cf97d9ea6603fcc3584a45d71b31c2b4aa900e`.
- `14_NDX_H1_QM5_13128_pre-fomc-drift-ndx.set` is byte-identical to FINAL24b, SHA-256 `f937b00ae0d1ccac0530421f46bba9e79c040d140959d764948cf9a5773d64a2`.
- Both copied sleeves are at 1.0 in FINAL24b and FINAL23. With no risk or composition-specific setfile delta, reusing the already reviewed bytes is sound.
- No staged filename or resolved symbol is XNGUSD. `20_XAUUSD_D1_QM5_12567_cum-rsi2-commodity.set` remains present with `RISK_PERCENT=1`, correctly retaining the different sleeve of EA 12567.

The artifact remains `DRAFT`, `STAGE_ONLY`, with `manual_approval_required=true`; approval here is technical approval of OPTION B, not an OWNER composition choice or deployment authorization.

## 4. `health.py` starvation rewrite

`json` is imported, `_connect` sets `sqlite3.Row`, and the rewrite keeps all `ea_review` statuses in its coverage set. Canonical JSON with a missing `build_task_id` is ignored by both implementations. Canonical `ea_review` rows with `pending` or `failed` status cover a build in both.

It is nevertheless not semantically equivalent. The old SQL applies two raw SQLite `LIKE` predicates; the rewrite uses a case-sensitive raw verdict substring, then valid-JSON parsing and a top-level `.get("build_task_id")`. Synthetic results (`1` means the build is counted as starved) were:

| Payload case | Old SQL | New in-memory |
|---|---:|---:|
| canonical codex PASS, no EA review | 1 | 1 |
| malformed codex JSON containing both exact substrings | 1 | 0 |
| codex review missing `build_task_id` | 0 | 0 |
| canonical pending/failed `ea_review` coverage | 0 | 0 |
| malformed `ea_review` containing the exact ID substring | 0 | 1 |
| compact codex build ID (`"build_task_id":"b1"`) with spaced PASS | 0 | 1 |
| compact `ea_review` build ID | 1 | 0 |
| lower-case `"verdict": "pass"` | 1 | 0 |
| valid JSON with nested, not top-level, `build_task_id` | 1 | 0 |

SQLite `LIKE` is ASCII case-insensitive on this connection (`'pass' LIKE 'PASS' == 1`), whereas Python substring matching is case-sensitive. Malformed payloads are the clearest requested divergence: old SQL can count their matching text; the new parser drops them.

A single read-only production snapshot (`file:///D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`) had 6,119 relevant task rows. Old SQL and the new algorithm both returned `n_starved=4`; there were no parse failures among done Codex reviews or EA reviews in that snapshot. Equality on current canonical data does not establish semantic equivalence.

Either preserve the legacy raw-match contract in a one-pass resolver and add parity tests, or explicitly ratify a new valid/top-level JSON contract and test/migrate malformed and formatting variants. As submitted under an equivalence claim, this item requires changes.

## Test summary

```text
tools/strategy_farm/tests/test_ftmo_qualification.py
14 passed in 0.67s

tools/strategy_farm/tests/test_requeue_stranded_infra.py
16 passed in 1.46s
```

Total named suites: **30 passed**.

## Not independently verified

- No requeue apply, revert, or canary touched the real farm DB or real report roots. Crash behavior was assessed from source and synthetic temporary DB/filesystem tests; no power-loss or process-kill test was performed.
- No compile, MT5 terminal, backtest, pipeline phase, or `C:\QM\mt5\T_Live` access was performed.
- The FINAL23 generator was not executed because doing so would overwrite the review artifacts. Its inputs and outputs were read, and its arithmetic was independently reconstructed.
- No deployment, chart closure, AutoTrading action, or OWNER KEEP/DROP decision was performed or inferred.
- The sealed stream bundle's external approval/provenance was not re-established; base-manifest reproduction and the files presently under the declared sealed path were verified.
- Five backfilled EAs were source-spot-checked. All ten manifest/active-registry set equalities were verified, but the other five source-derived leg claims were not independently traced through their `.mq5` order calls.
- The claim that the health check has run continuously without production errors since morning was not independently established. One moving, read-only DB snapshot was compared.
