# cards_review EA-ID collision repair

Task: `db8529b1-5808-432b-ac10-f18df58b6e08`
Date: 2026-07-02

## Verdict

REVIEW: the reported `cards_review` production ID collisions are resolved. The collision set was assigned canonical registry rows in `C:\QM\repo\framework\registry\ea_id_registry.csv`, card filenames/frontmatter were aligned to those rows, and the router now rejects future research artifacts whose `ea_id` is already present in `cards_review` or `cards_approved`.

## Renumbered Review-Card Block

The corrected reserved block is `QM5_12872` through `QM5_12903`:

- `12872` `eia-xng-stor-drift`
- `12873` `xng-latewinter-decay-short`
- `12874` `xng-inject-slope-short`
- `12875` `xag-q4-industrial-season`
- `12876` `xag-goldlead-mom`
- `12877` `xag-london-fix-rev`
- `12878` `bp-simple-system-32-review`
- `12879` `ftmo-set-up-4-fibs-break-out-v2`
- `12880` `ftmo-set-up-4-fibs-break-out-v3`
- `12881` `ftmo-set-up-4-fibs-break-out-v4`
- `12882` `ftmo-set-up-3-20-ma-v2`
- `12883` `ftmo-set-up-3-20-ma-v3`
- `12884` `ftmo-set-up-3-20-ma-v4`
- `12885` `ftmo-set-up-1-quick-move-v3`
- `12886` `ftmo-set-up-1-quick-move-v4`
- `12887` `ftmo-set-up-1-quick-move-v5`
- `12888` `ftmo-set-up-2-fibs-retracement-v3`
- `12889` `ftmo-set-up-2-fibs-retracement-v4`
- `12890` `ftmo-set-up-2-fibs-retracement-v5`
- `12891` `ftmo-system-overview-v3`
- `12892` `ftmo-system-overview-v4`
- `12893` `xng-12m-carry`
- `12894` `xng-mar-transseason-short`
- `12895` `xng-6m-reversal`
- `12896` `xng-oct-turn-long`
- `12897` `xag-donchian55-trend`
- `12898` `xng-eia-multiday-drift`
- `12899` `xag-goldlead-follow`
- `12900` `xag-xau-filter-trend`
- `12901` `xag-industrial-3m-mom`
- `12902` `xag-vol-regime-donchian`
- `12903` `xag-xau-lag-entry`

## Prevention

Updated both active router copies:

- `C:\QM\worktrees\codex-orchestration-1\tools\strategy_farm\agent_router.py`
- `C:\QM\repo\tools\strategy_farm\agent_router.py`

The `research_strategy -> REVIEW` artifact gate now normalizes card IDs (`QM5_123`, `qm5_123`, and bare `123`) and rejects a card with reason `duplicate_strategy_card_ea_id` if the same numeric ID already exists in either `artifacts/cards_review` or `artifacts/cards_approved`. This runs before the existing strategy-fingerprint duplicate check.

Added regression tests in both router test suites:

- `test_research_review_card_rejects_duplicate_ea_id`

## Verification

- Worktree router tests: `python -m pytest tools/strategy_farm/tests/test_agent_router.py -q` -> 20 passed.
- Canonical repo targeted regression: `python -m pytest C:\QM\repo\tools\strategy_farm\tests\test_agent_router.py::AgentRouterTests::test_research_review_card_rejects_duplicate_ea_id -q` -> 1 passed.
- Canonical repo full router suite: 20 passed, 1 pre-existing unrelated failure in `test_run_once_does_not_replenish_generic_research` (`replenish_directed.created` was empty in the isolated temp-root fixture).
- Repaired range audit: 32 cards from `12872..12903`, registry mappings found, registry mismatches = 0.
- Full `cards_review` filename-ID audit: duplicate production filename IDs = 0.
- Normalized full frontmatter scan has only nonproduction placeholders left: `TBD` and sandbox `99999` support/verification files, not the reported production collision set.

No cards were moved to `cards_approved`, and no build or pipeline phase was started.
