# Retired cards still claimable from cards_approved — registry/pool disagreement

Date: 2026-08-21. Author: Claude (orchestrator, headless cycle). Branch: agents/board-advisor.
Router task: `8c685237-2fed-4d4d-a05d-07eb0576b3c1`.

## Finding

`QM5_41010` and `QM5_38007` are `status=retired` in `framework/registry/ea_id_registry.csv`
(both retired 2026-08-15, MASTER-CENTURY-SUITE-2026-08-15) but their card files still sit in
`D:/QM/strategy_farm/artifacts/cards_approved/`.

Traced `farmctl.py`'s `_detect_unbuilt_cards` — the function the build pump uses to find
approved cards needing an auto-build bridge task. It checked: card filename regex, `.ex5`
existence, an existing auto-build task file, and the R-gate frontmatter fields. **It never read
`ea_id_registry.csv` at all.** `sweep_enqueue_built_eas.py` (a sibling script over the same
card pool) already does this correctly (`registry_status={status}` skip, status must be
`"active"`) — this was the one card-claiming path that didn't.

**Live exposure, not theoretical:** `QM5_41010` already has a `.ex5` (built before retirement),
so the `ex5.exists()` check already excludes it from *this* path today — no current exposure via
the pump, though other claim paths were not audited. `QM5_38007` has **no** `.ex5`, currently
**passes its R-gate** (`r1_track_record=PASS`, `r2_mechanical=PASS`, `r3_data_available=PASS`,
`r4_ml_forbidden=PASS`), and has no existing auto-build task file — it was live-eligible for an
auto-build bridge task on the very next pump cycle before this fix.

**Has any retired card ever actually been claimed?** No. `SELECT id, kind, status FROM tasks
WHERE card_id IN ('QM5_41010','QM5_38007')` returns zero rows for both — this is a defect that
was about to fire, not one that already has, per the direct DB check below.

```
python -c "
import sqlite3
conn = sqlite3.connect(r'D:\QM\strategy_farm\state\farm_state.sqlite')
for eid in ('QM5_41010','QM5_38007'):
    print(eid, conn.execute(
        'SELECT id, kind, status FROM tasks WHERE card_id=?', (eid,)
    ).fetchall())
"
# -> QM5_41010 []
# -> QM5_38007 []
```

## Fix

Added `_ea_registry_status_index` (`farmctl.py`, mtime-cached like the file's existing
`_ea_registry_slug_index` / `_magic_registry_duplicate_errors` helpers) and wired it into
`_detect_unbuilt_cards`: a card is skipped unless its numeric EA ID's registry status is exactly
`"active"`. If the registry CSV is unreadable this call (empty index — a transient infra
condition, not "every card is retired"), the filter is skipped entirely rather than stalling the
whole build pump; this matches how the function already degrades gracefully on other read
failures.

**Explicitly did not move the card files.** Per this ticket's own constraint, card-universe
membership is ROT (per `CLAUDE.md`'s Stehende Vollmacht) — deciding whether a retired card's
file should be archived/deleted from `cards_approved/` is a card-pool-definition decision, not a
reader repair. The registry stays authoritative and the reader now respects it; where the stale
file physically lives is left for an explicit OWNER/Claude card-pool decision.

## Verification

New test `test_unbuilt_scan_skips_retired_registry_ids`
(`tools/strategy_farm/tests/test_auto_build_routing.py`) — confirmed failing before the fix
(`git stash` bisection: retired `QM5_38007` fixture card appeared in `_detect_unbuilt_cards`'s
output), passing after. Also hardened the adjacent pre-existing test
`test_unbuilt_scan_accepts_five_digit_tiered_card` to mock `CANONICAL_REPO_ROOT` into an
isolated temp dir — before this ticket it never touched the registry at all, so leaving it
unmocked would have made it silently depend on the real repo's registry contents for EA
20061 (currently `active`, but not guaranteed to stay that way).

```
python -m pytest tools/strategy_farm/tests/test_auto_build_routing.py -q
33 passed, 12 subtests passed

python -m pytest tools/strategy_farm/tests/ -k "unbuilt or pump or auto_build or detect_unbuilt" -q
48 passed, 3951 deselected, 12 subtests passed
```

No card files, registry rows, or work items were modified. Read-only investigation plus one
reader-side code fix in `farmctl.py`.
