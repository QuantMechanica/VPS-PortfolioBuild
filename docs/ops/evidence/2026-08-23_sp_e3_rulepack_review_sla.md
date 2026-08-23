# SP-E3 — Provider-versioned rulepack review-SLA

Date: 2026-08-23

Router task: `65bb719f-75d5-4e73-a21b-69daeaaf8976` (`SP-E3`)

## Verdict

IMPLEMENTED. `target_rulepacks.py` already gave both existing rulepacks
(`DXZ_BETTER_BOOK_V1`, `FTMO_2S_100K_SWING_V1`) the "Quelle/Abrufdatum" half
of the acceptance criterion — every `official_rules` entry cites
`source_ids` into a versioned `official_sources` array with `url` +
`retrieved_on`. What was missing was the "Review-SLA... regelmaessig
pruefen" half: nothing tracked whether those sources had been re-checked
since `retrieved_on`, and nothing would notice if they went stale.

## Why a separate tracker instead of a schema field

`target_rulepacks.py`'s schema is a hard-bounded, hash-sensitive contract:
`_require_exact_keys` enforces the root key set exactly, `canonical_json_bytes`
computes a `QM_CANONICAL_JSON_V1` SHA-256 over the whole payload, and
`write_rulepack`'s own docstring states "Callers must allocate a new `_V<n>`
identity for revisions." Adding a required `review_sla` field there would
force both existing, already-referenced rulepack files
(`ftmo_book3_standalone_evaluator.py`, `target_outcome_dossier.py`, and
others resolve them by `rulepack_id`) through a version bump for a purely
operational concern, and would change their canonical hash. Per the
Specification Density Principle, the rulepack schema is a hard-bounded
constraint, not something to silently redefine mid-cycle for a housekeeping
addition.

Instead, `tools/strategy_farm/rulepack_review_sla.py` adds an **additive**
tracker: a small JSON state file
(`tools/strategy_farm/config/target_rulepack_review_sla.json`) mapping each
`rulepack_id` to `{interval_days, last_reviewed_on, next_review_due_on,
last_check_result, note}`. It never touches the rulepack files, their
schema, or their hash. `status()` cross-references
`target_rulepacks.list_rulepack_ids()` against the tracker and reports any
rulepack with **no** entry as immediately overdue (`days_overdue: null`) —
fail-closed, so a newly added rulepack can never silently skip review.
`record_review()` requires an explicit `checked_on` date, a `result`
(`CONFIRMED_UNCHANGED` / `DISCREPANCY_FOUND`), and a non-empty `note`
describing what was actually compared — there is no automatic "mark
reviewed" path that could fabricate a check that didn't happen.

## Real review performed this pass (not synthetic)

Both production rulepacks' primary official source was re-fetched live and
compared against the encoded `official_rules` parameters:

**FTMO** (`https://ftmo.com/en/trading-objectives/`, fetched 2026-08-23):
Phase-1 profit target 10%, Verification profit target 5%, Maximum Daily Loss
5%, Maximum Loss 10%, Minimum Trading Days 4 — all match
`ftmo_2s_phase1_profit_target` / `ftmo_2s_verification_profit_target` /
`ftmo_2s_max_daily_loss` / `ftmo_2s_maximum_loss` /
`ftmo_2s_minimum_trading_days` exactly. No discrepancy.

**Darwinex Zero** (`https://www.darwinexzero.com/docs/en/risk-engine`,
fetched 2026-08-23): Target VaR range 3.25%-6.5%, D-Leverage caps
16.25 / 13 / 9.75 for under-30m / 30-60m / over-60m position durations — all
match `dxz_darwin_target_var` and `dxz_dleverage_duration_caps` exactly. No
discrepancy.

Both checks are recorded via `record_review(..., result="CONFIRMED_UNCHANGED")`,
`interval_days=90`, `next_review_due_on=2026-11-21`.

**Not covered this pass**: the remaining 5 FTMO sources (news, weekend,
EA/instrument, forbidden-practices FAQ pages) and the remaining 2 DXZ sources
(Darwinia program, Silver/Gold rating) were not re-fetched — the tracker's
`note` field says so explicitly for both entries rather than implying a full
re-verification. Re-checking those, and deciding whether they need their own
finer-grained SLA entries per source rather than one per rulepack, is
follow-up work.

## Focused verification

```text
python -m py_compile tools/strategy_farm/rulepack_review_sla.py tools/strategy_farm/tests/test_rulepack_review_sla.py
COMPILE_OK

python -m pytest tools/strategy_farm/tests/test_rulepack_review_sla.py tools/strategy_farm/tests/test_target_rulepacks.py -q -p no:cacheprovider
19 passed in 1.52s

python tools/strategy_farm/rulepack_review_sla.py status --as-of-today 2026-08-23
DXZ_BETTER_BOOK_V1 OK due=2026-11-21 result=CONFIRMED_UNCHANGED
FTMO_2S_100K_SWING_V1 OK due=2026-11-21 result=CONFIRMED_UNCHANGED
exit=0
```

One new test, `test_real_rulepacks_are_tracked_and_currently_confirmed`, pins
this: it fails if either production rulepack ever has no tracker entry or
goes overdue, so a future `target_rulepacks.py` change that adds a new
rulepack (or a stale review) shows up as a test failure rather than silence.

No calendar seed, MetaTrader compiler, terminal, T_Live, AutoTrading,
pipeline verdict, or work item was touched. The two existing rulepack JSON
files and their schema are unmodified.

## Changed files

- `tools/strategy_farm/rulepack_review_sla.py` (new)
- `tools/strategy_farm/tests/test_rulepack_review_sla.py` (new)
- `tools/strategy_farm/config/target_rulepack_review_sla.json` (new, generated by `record` above)

This artifact remains in REVIEW for Codex/OWNER close-out.
