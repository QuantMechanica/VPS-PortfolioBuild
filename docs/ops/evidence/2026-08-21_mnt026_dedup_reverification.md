# MNT-026 — independent re-verification (dedup fail-closed + QM5_13108)

Date: 2026-08-21
Router task: `4f3943b3` (QM-TODO-20260821-026)
Branch: `agents/board-advisor`

## Why this note exists

The full MNT-026 deliverable was implemented and committed earlier the same day
by a prior run of this router task:

- commit `e45a42e08` — *fix(governance): make research dedup fail closed (MNT-026)*
  (author QuantMechanica Codex, 2026-08-21 13:59:31 +0200; branch-only, not on `main`).

That commit added the fail-closed rewrite, the three required negative tests, the
QM5_13108 recheck JSON, and the primary evidence note. This session re-verified
that deliverable end-to-end rather than re-authoring it. Primary evidence remains:

- `docs/ops/evidence/2026-08-21_mnt026_dedup_fail_closed.md`
- `docs/ops/evidence/2026-08-21_mnt026_qm5_13108_dedup_recheck.json`

## What was re-verified this session

### 1. The three fail-closed scenarios can never return CLEAN

`framework/scripts/research_dedup_check.py` (tool version `2.0.0`) refuses `CLEAN`
whenever a declared source is bad. The refusal is structural in `cmd_check`: a
`DedupInputError` from any source is captured into `source_errors`, and the CLEAN
branch is reached only when `source_errors` is empty *and* no duplicate/fuzzy hit
was found. On a bad source the terminal verdict is `INPUT_ERROR_FAIL_CLOSED`
(exit 1) — or the safer `DUPLICATE`/`FUZZY_MATCH` if a match was still found in a
readable source.

Pinned by `framework/scripts/tests/test_research_dedup_check.py`:

- `test_missing_root_fails_closed_never_clean` — missing wiki root → `MISSING_ROOT`,
  verdict `INPUT_ERROR_FAIL_CLOSED`, rc 1, `count=None`, no `VERDICT: CLEAN` in stdout.
- `test_empty_directory_fails_closed_never_clean` — empty card directory → `EMPTY_ROOT`,
  verdict `INPUT_ERROR_FAIL_CLOSED`, rc 1, `count=0`, no `VERDICT: CLEAN`.
- `test_encoding_error_fails_closed_never_clean` — invalid UTF-8 in a discovered card →
  `ENCODING_ERROR`, verdict `INPUT_ERROR_FAIL_CLOSED`, rc 1, no `VERDICT: CLEAN`.

Test run this session:

```text
python -m pytest framework/scripts/tests/test_research_dedup_check.py -x -q
7 passed in 0.29s
```

### 2. Live QM5_13108 recheck reproduces DUPLICATE, fail-closed

Read-only re-run (evidence written to scratchpad to avoid mutating the committed
artifact):

```text
python framework/scripts/research_dedup_check.py check \
  --slug xti-mtsm-s2 --strategy-id LIU-MTSM-2021_XTI_S01 \
  --author "Liu, Lu, Wang" \
  --mechanic "30d momentum 5d upper lower partial moments MTSM-S2" \
  --output <scratchpad>/mnt026_recheck_live.json
```

Observed:

| Source | Checked root | Count | Status |
|---|---|---:|---|
| EA registry | `C:/QM/repo/framework/registry/ea_id_registry.csv` | 4,580 | `OK` |
| repository cards | `C:/QM/repo/strategy-seeds/cards` | 1,253 | `OK` |
| strategy wiki | `G:/My Drive/09 Strategy Wiki/strategies` | unavailable | `MISSING_ROOT` |

Verdict `DUPLICATE`, exit code 2 — the registry independently matches both
`slug=xti-mtsm-s2` and `strategy_id=LIU-MTSM-2021_XTI_S01` to EA 13108. The wiki
source was unavailable this session (`MISSING_ROOT`; the committed artifact recorded
`ROOT_ACCESS_ERROR` at 13:57 — G: mounted-but-erroring then, unmounted now). In
both cases the unavailable source stays explicit in the evidence and never converts
to a zero-count that could produce CLEAN. Fail-closed behaviour is stable across
both drive states.

## Scope / non-mutation

Read-only re-verification only. No registry, magic row, resolver, strategy card,
work item, verdict, factory state, terminal, `.set` file, T_Live file, or AutoTrading
setting was created, modified, or advanced. The committed QM5_13108 recheck artifact
was not overwritten; the live re-run wrote to the session scratchpad.

## Rollback

This note is additive documentation only; deleting the file is a complete rollback.
The underlying deliverable (commit `e45a42e08`) is unchanged by this session.
