# rb-book-guard evidence — 2026-08-23

## Outcome

Implemented proposal ticket 6 as a fail-closed, read-only authorization check.
DXZ/FTMO book analysis, manifest construction, candidate synchronization, and
T_Live copy-plan processing now raise `BookBuildRefused` unless the active
manifest's terminal per-EA requalification gate has at least 25 contiguous-valid
`(EA, Symbol)` pairs and a compatible, non-future OWNER order artifact is valid.

No gate threshold/window/criterion, verdict row, backtest queue, factory state,
T_Live path, or AutoTrading state was changed.

## What changed

- `tools/strategy_farm/book_build_guard.py:40-224`
  - Adds `GuardResult` and `BookBuildRefused`.
  - Opens the state DB through `rebaseline_census.open_ro()` and reuses
    `build_pairs()` / `summarise_pair()` for `highest_contiguous_valid_gate`
    (`book_build_guard.py:72-84`); no qualification logic or writable DB
    connection is duplicated.
  - Counts canonical `(EA, Symbol)` rows and normalized distinct EAs, and reuses
    `portfolio.concentration_tail.family_fingerprints()` for the repository's
    existing slug-family definition (`book_build_guard.py:87-110`).
  - Validates `YYYY-MM-DD_owner_book_order_<dxz|ftmo|both>.md`, exact
    `OWNER-ORDER: BOOK_BUILD <venue> <date>` content, compatible venue, and a
    non-future date (`book_build_guard.py:116-170`).
  - Implements the public check/raise APIs and read-only `--status` JSON CLI
    (`book_build_guard.py:173-244`).
- `tools/strategy_farm/gate_manifest.py:129-149`
  - Adds the loader accessor `terminal_requalification_gate`, resolved by the
    stable sealed head-to-head evidence-role stem rather than Q16/Q14 literals.
- `tools/strategy_farm/rebaseline_census.py:74-88`
  - Treats the existing successful v3 and proposed v4 terminal requalification
    outcomes (`PROMOTE_CHALLENGER`, `CHALLENGER_PROMOTED`, `KEEP_INCUMBENT`, and
    historical `ADMIT_BOTH`) as contiguous-valid PASS-class evidence. `FAIL`
    and all existing economic/infra classifications are unchanged.
- Guarded entry points, before downstream reads/writes:
  - `tools/strategy_farm/deploy_tlive_book.py:129`
  - `tools/strategy_farm/portfolio/portfolio_periodic_report.py:92`
  - `tools/strategy_farm/portfolio/build_book_dxz.py:262`
  - `tools/strategy_farm/portfolio/build_book_ftmo.py:612`
  - `tools/strategy_farm/agent_router.py:2447-2468`
  - `farmctl.py` contained no `>=5` Q10/Q11 book trigger; the static regression
    test confirms no such trigger is present in `farmctl.py` or
    `agent_router.py`.
- Tests:
  - `tools/strategy_farm/tests/test_book_build_guard.py:57-274` covers sub-25,
    missing/invalid/wrong-venue/future orders, valid pass, DXZ/FTMO independence,
    `both`, exception behavior, census delegation, v3/v4 accessor behavior,
    guard-before-work ordering, and the no-bypass grep guard.
  - `tools/strategy_farm/tests/test_rebaseline_census.py:46-162` covers all
    successful terminal outcomes through the full contiguous chain.
  - Existing touched tests inject an authorized guard fixture so their original
    report, sync, risk-freeze, and copy semantics remain isolated.

## Verification

Focused and touched-module suite:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_rebaseline_census.py \
  tools/strategy_farm/tests/test_book_build_guard.py \
  tools/strategy_farm/tests/test_dual_book_builders.py \
  tools/strategy_farm/tests/test_portfolio_periodic_report.py \
  tools/strategy_farm/tests/test_gate_manifest.py \
  tools/strategy_farm/tests/test_risk_freeze_prevention.py \
  tools/strategy_farm/tests/test_agent_router.py::AgentRouterTests::test_sync_q11_candidates_mirrors_p8_pass_work_items

80 passed, 2 skipped in 2.39s
```

Syntax and whitespace:

```text
python -m py_compile <all touched Python modules>
PASS

git diff --check
PASS (only repository line-ending conversion warnings)
```

Read-only production status (`D:/QM/strategy_farm/state/farm_state.sqlite`, opened
by the guard through the census `mode=ro` URI):

```text
python tools/strategy_farm/book_build_guard.py --status --venue dxz \
  --db-path D:/QM/strategy_farm/state/farm_state.sqlite --order-dir decisions

allowed=false
qualified_pairs=0
distinct_eas=0
strategy_families=0
order_artifact=null
reasons=["qualified_pairs_below_minimum: 0 < 25",
         "owner_order_missing: venue=dxz order_dir=decisions"]
python_exit=2
```

The FTMO status command independently returned the same zero counts with
`owner_order_missing: venue=ftmo` and exit 2.

Supplemental broad legacy-router run:

```text
python -m pytest -q tools/strategy_farm/tests/test_agent_router.py
30 failed, 2 passed in 10.59s
```

All failures are caused by the pre-existing canonical-router writer-generation
interlock when the legacy suite is run from this linked worktree
(`checkout=C:\QM\worktrees\rb-book-guard`, canonical=`C:\QM\repo`), including
`sqlite3.IntegrityError: agent task enqueue requires canonical router generation`.
The one touched sync test passes in the focused suite above. The interlock was
not bypassed or changed for this ticket.

## Risks and open points

- Production is intentionally blocked today: zero pairs reach the active
  terminal requalification gate and neither venue has an OWNER order artifact.
- A `<both>` order authorizes either individual venue; a venue-specific order
  authorizes only that venue. Calling the guard for `both` requires a `<both>`
  artifact.
- Family reporting uses the already-established active-registry slug stem
  fallback. Missing or ambiguous family metadata refuses the guard rather than
  reporting a guessed count.
- The v4 draft remains read-inert. When its loader is activated, the accessor
  resolves Q14 from the same evidence role; the guard contains no Q14/Q16
  qualification literal.

## Rollback

Revert the rb-book-guard commit. This removes the new guard/accessor/outcome
classification, restores the prior entry functions and CLI arguments, and
restores the affected test fixtures. No database, queue, verdict, factory,
T_Live, or external artifact rollback is required because this change made no
such mutations.
