# MNT-026 — dedup false-CLEAN closure and QM5_13108 recheck

Date: 2026-08-21  
Router task: `4f3943b3-88a3-45b4-b790-343050272516`  
Branch: `agents/board-advisor`

## Outcome

The reported premise was real in
`framework/scripts/research_dedup_check.py`: missing registry/card/wiki inputs
returned empty collections, and card decoding used `errors="replace"`. A check
could therefore scan zero or corrupted records and still print `CLEAN`.

Tool version `2.0.0` now fails closed on:

- missing or inaccessible source roots;
- empty CSVs or card/wiki directories;
- UTF-8 decoding errors;
- filesystem, CSV, or read errors.

`CLEAN` is emitted only after all three declared sources are readable and
non-empty. Each JSON result binds the absolute checked root, count, per-source
status, tool version, candidate identity, verdict, and exit code. Exact
duplicates may still produce the safer `DUPLICATE` verdict when another source
is unavailable; the unavailable source remains explicit in the same evidence
and can never turn the result into CLEAN.

The repository card scan is recursive. It now covers both the 625 root cards
and 628 cards under `strategy-seeds/cards/approved` (1,253 total at recheck),
closing the separate omission that previously excluded the durable
QM5_13108-approved card.

## Required negative tests

The focused suite contains explicit checks that each case returns non-zero,
writes `INPUT_ERROR_FAIL_CLOSED`, and never prints `VERDICT: CLEAN`:

1. missing wiki strategies root;
2. empty strategy-card directory;
3. invalid UTF-8 in a discovered card.

A positive fixture additionally proves that CLEAN evidence carries all three
absolute roots, counts `[1, 1, 1]`, and tool version `2.0.0`. A recursive-scan
test pins discovery of a card below the `approved/` subdirectory.

## QM5_13108 read-only recheck

Machine evidence:
`docs/ops/evidence/2026-08-21_mnt026_qm5_13108_dedup_recheck.json`

Command:

```text
python framework/scripts/research_dedup_check.py check --slug xti-mtsm-s2 --strategy-id LIU-MTSM-2021_XTI_S01 --author "Liu, Lu, Wang" --mechanic "30d momentum 5d upper lower partial moments MTSM-S2" --output docs/ops/evidence/2026-08-21_mnt026_qm5_13108_dedup_recheck.json
```

Observed bindings at `2026-08-21T13:57:31+00:00`:

| Source | Checked root | Count | Status |
|---|---|---:|---|
| EA registry | `C:/QM/repo/framework/registry/ea_id_registry.csv` | 4,580 | `OK` |
| repository cards | `C:/QM/repo/strategy-seeds/cards` | 1,253 | `OK` |
| strategy wiki | `G:/My Drive/09 Strategy Wiki/strategies` | unavailable | `ROOT_ACCESS_ERROR` |

Verdict: `DUPLICATE`, exit code 2. The current registry independently matches
both `slug=xti-mtsm-s2` and
`strategy_id=LIU-MTSM-2021_XTI_S01` to EA 13108. The G: access failure is
retained in `error`; it is not converted to a zero-count source.

This is a current-cohort recheck, not a claim that the July pre-allocation
CLEAN can be reconstructed. Under the scheduled-task identity that historical
claim is not revalidated: the current candidate is an exact self-duplicate and
the wiki source is inaccessible. Any future new-ID decision must rerun with
all source bindings `OK` or stop fail-closed.

## Verification

```text
python -m py_compile framework/scripts/research_dedup_check.py framework/scripts/tests/test_research_dedup_check.py

python -m pytest -q framework/scripts/tests/test_research_dedup_check.py tools/strategy_farm/tests/test_governed_magic_allocator.py framework/scripts/tests/test_magic_resolver_binary_search.py framework/scripts/tests/test_magic_resolver_strict_default.py
```

Result: `20 passed in 2.48s`.

No EA ID, magic row, resolver row, strategy card, work item, verdict, factory
state, terminal, T_Live file, or AutoTrading setting was created, modified, or
advanced. This implementation and evidence remain in REVIEW for Claude/OWNER.
