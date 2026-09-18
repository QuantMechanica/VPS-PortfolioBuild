# FTMO official-rules re-pin — 2026-09-18

Governed re-pin of the official-rules snapshot, both target rulepacks, the M13 Standard
demo binding and the standalone evaluator constants onto a **real re-fetch** of the seven
official FTMO sources. Predecessor analysis:
`docs/ops/evidence/2026-09-18_ftmo_vintage_align/RULE_FACTS_DIFF.md` (verdict
STOP_DO_NOT_ALIGN — the 2026-09-15 v2 artifact was structurally unbindable).

**No evaluator check was loosened.** Every check in `_validate_official_rule_sources()`
and `load_binding()` remains exact equality. What changed is the evidence it points at.

## 1. Headline

| | |
|---|---|
| New snapshot | `docs/ops/evidence/2026-09-18_ftmo_official_rules_snapshot.json` |
| sha256 | `41624932e16d96d36543a076ad4199cd0c3cba3695c15567235746e99e464785` |
| schema | `qm.ftmo-official-rules-snapshot/v1` (unchanged generation) |
| profile | `FTMO Challenge 2-Step / USD 100000 / Standard` (was `… / Swing`) |
| retrieved_at_utc | `2026-09-18T02:37:46Z` |
| sources at HTTP 200 | **7 of 7** (was 5 of 7 with one 404 on 2026-09-15) |
| claims | 30 — 28 RE_CONFIRMED, 2 CARRIED_OVER |
| **rule-fact value changes** | **0** |
| `load_binding()` | **PASS** (was `Refusal: wrong_rulepack`) |

## 2. Fact diff — every numeric/boolean rule FACT is unchanged

Values compared across all three vintages. The 2026-09-15 column reads the nearest
counterpart in that artifact's `fields` block (see RULE_FACTS_DIFF.md for the locator
map); `—` means the v2 artifact dropped the row entirely.

| fact | 2026-09-04 | 2026-09-15 | **2026-09-18** | verdict |
|---|---|---|---|---|
| Phase 1 profit target % | 10 | 10 | **10** | UNCHANGED |
| Verification profit target % | 5 | 5 | **5** | UNCHANGED |
| Profit-target operator | strict-above, flat | — | **strict-above, flat** | UNCHANGED |
| Max daily loss % of initial | 5 | 5 | **5** | UNCHANGED |
| Daily reset timezone | Europe/Prague | Europe/Prague | **Europe/Prague** | UNCHANGED |
| Daily reset local time | 00:00:00 | 00:00:00 | **00:00:00** | UNCHANGED |
| Daily loss basis | midnight balance − fixed initial-capital amount | same (recoded) | **midnight balance − fixed initial-capital amount** | UNCHANGED |
| Daily loss breach operator | equity strictly below | same (recoded) | **equity strictly below** | UNCHANGED |
| Max loss % of initial | 10 | 10 | **10** | UNCHANGED |
| Max loss model | static on initial capital | same (recoded) | **static on initial capital** | UNCHANGED |
| Max loss breach operator | equity strictly below | same (recoded) | **equity strictly below** | UNCHANGED |
| Minimum trading days / phase | 4 | 4 | **4** | UNCHANGED |
| Trading-day qualifier | ≥1 position opened in the Prague local day | same (recoded) | **≥1 position opened in the Prague local day** | UNCHANGED |
| Maximum trading period | none (`null`) | NONE | **none (`null`)** | UNCHANGED |
| News restriction during evaluation | false | false | **false** | UNCHANGED |
| Overnight/weekend restriction during evaluation | false | false | **false** | UNCHANGED |
| EAs allowed subject to rules | true | true | **true** | UNCHANGED |
| Simultaneous order limit | 200 | 200 | **200** | UNCHANGED |
| Positions per day | 2000 | 2000 | **2000** | UNCHANGED |
| Hyperactive server-request threshold / day | 2000 | 2000 | **2000** | UNCHANGED |
| Real-market replicability required | true | — | **true** | UNCHANGED |
| USD 100000 2-Step list price | 540 | — | **540** | UNCHANGED |
| Fee refund % with first reward | 100 | — | **100** | UNCHANGED |
| Base reward split % | 80 | — | **80** | UNCHANGED |
| Maximum reward split % | 90 | — | **90** | UNCHANGED |
| Account balance increase % | 25 | — | **25** | UNCHANGED |
| Minimum months between scale-ups | 4 | — | **4** | UNCHANGED |
| Scaled reward split % | 90 | — | **90** | UNCHANGED |
| Swing FX leverage | 1:30 (CARRIED_OVER) | 1:100 (labelled Standard) | **1:30 (CARRIED_OVER)** | see §4 |
| Swing metals & oil leverage | 1:15 (CARRIED_OVER) | 1:30 (labelled Standard) | **1:15 (CARRIED_OVER)** | see §4 |

**Facts that differ: none.** All 30 `normalized_claims` values in the 2026-09-18 snapshot
are identical to 2026-09-04; machine-verified:

```
claims identical to 09-04: True
provenance == EXPECTED   : True
source ids == EXPECTED   : True
all http 200             : True
RE_CONFIRMED 28 / CARRIED_OVER 2
```

### Selected official quotes (2026-09-18, 2-Step tab)

> "The Profit Target is calculated as a percentage of your Initial Simulated Capital:
> 10% for the FTMO Challenge / 5% for the Verification"

> "the Maximum Daily Loss Amount, which is 5% of the Initial Simulated Capital."

> "The Maximum Loss rule establishes a **static** limit (the Maximum Loss Limit) … The
> Maximum Loss Limit is calculated as the difference between: the Initial Simulated
> Capital and the Maximum Loss Amount, which is 10% of the Initial Simulated Capital."

> "The Minimum Trading Days rule requires the trader to achieve at least 4 Trading Days.
> A Trading Day is defined as any day – measured from 00:00:00 to 23:59:59 CE(S)T –
> during which at least one position is opened."

> "Trading Period — Unlimited" (comparison table) / "No time limit" (objectives page)

> "platform servers have 200 orders at a time and 2000 max positions per day limitation"

Note for readers scanning the objectives page: it renders a **1-Step** tab first, whose
Max Daily Loss is 3% and whose Max Loss is end-of-day trailing. That is a different
product. The 2-Step tab — and the comparison table row "Max Loss type: Static" — carry
the facts above.

## 3. What was re-pinned

| artifact | field | from | to |
|---|---|---|---|
| `target_rulepacks/FTMO_2S_100K_STANDARD_V2.json` | `as_of` | 2026-09-15 | 2026-09-18 |
| | `official_sources[7].retrieved_on` | 2026-09-15 | 2026-09-18 |
| | `official_sources[7].retrieved_at_utc` | 2026-09-15T13:59:31Z | 2026-09-18T02:37:46Z |
| | `official_sources[7].snapshot_path` / `_sha256` | 2026-09-15 file | 2026-09-18 file / `41624932…` |
| | `rule_snapshot_binding.bound_*` | 2026-09-15 | 2026-09-18 |
| `target_rulepacks/FTMO_2S_100K_SWING_V2.json` | same five fields | 2026-09-04 | 2026-09-18 |
| `config/ftmo_m13_standard_demo.v1.json` | `rulepack.as_of` | 2026-09-04 | 2026-09-18 |
| | `rulepack.file_sha256`, `evaluator.rulepack_file_sha256` | `9db8fda7…` | `448e4b91…` |
| | `rulepack.canonical_sha256`, `evaluator.rulepack_canonical_sha256` | `857e2d4b…` | `9fe21a1d…` |
| `portfolio/ftmo_book3_standalone_evaluator.py` | `OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH` | 2026-09-04 file | 2026-09-18 file |
| | `OFFICIAL_RULE_SNAPSHOT_SHA256` | `c199b8f5…` | `41624932…` |
| | `DEFAULT_RULEPACK_SHA256` (Swing file) | `298ef128…` | `0b4b4498…` |
| | snapshot `profile` constant | `… / Swing` | `… / Standard` |
| | `official_sources[*].retrieved_on` constant | 2026-09-04 | 2026-09-18 |
| | `_official_rules` header `as_of` | 2026-09-15 / 2026-09-04 | 2026-09-18 (both) |
| | M13 binding `contract.as_of` | 2026-09-04 | 2026-09-18 |
| `prepare_ftmo_book3_q02.py` (6×), `isolated_work_item_runner.py` (1×) | snapshot path literal | 2026-09-04 file | 2026-09-18 file |
| `config/pipeline_books_program_status.v1.json` | Swing rulepack file/canonical sha | `298ef128…` / `7e0b21d3…` | `0b4b4498…` / `068a2eea…` |

Both rulepacks moved, not just the Standard one: `_validate_official_rule_sources()`
runs against whichever rulepack is selected and cross-walks it to the single
module-pinned snapshot, so leaving Swing on the 2026-09-04 pointer would have broken the
default path. The four downstream path literals and the program-status pins are
consequences of those two file changes, each verified below.

### Profile-constant receipt line

The evaluator hard-coded `"FTMO Challenge 2-Step / USD 100000 / Swing"` for **both**
rulepacks. That was wrong for the account it is bound to: the M13 demo account (login
1514536732, server FTMO-Demo) is a `STANDARD_2STEP_100K_FREE_TRIAL` account, and
`resolve_m13_standard_rulepack()` selects the Standard rulepack. The constant is now
`"… / Standard"`. This is a **label** correction: the 2026-09-18 news and weekend pages
state the restrictions "do not apply during the Evaluation Process" "regardless of the
account type (Standard account or Swing)", and all 30 claim values are unchanged. The
check remains exact equality — a Swing-labelled snapshot is now refused
(`rule_snapshot:envelope_invalid`), as verified in §5.

## 4. The only fact that could not be re-confirmed: leverage

`https://ftmo.com/en/trading-symbols/` is still HTTP 404, as on 2026-09-04. Eight further
candidates were probed on 2026-09-18 — `/en/account-specifications/`,
`/en/faq/what-is-the-leverage-on-ftmo-accounts/`, `/en/leverage/`,
`/en/faq/what-is-a-swing-ftmo-challenge/`, `/en/trading-conditions/` (the URL that 404'd
on 2026-09-15) all returned 404; `/en/symbols/`, `/en/comparison-table/` and
`/en/faq/what-are-the-account-specifications/` returned 200 with **no leverage figure
anywhere in the served body**. The tokens `1:30`, `1:15`, `1:100` and `1:50` are absent
from every retained 2026-09-18 body.

Consequence, stated plainly:

- The two claims stay `swing_fx_leverage = "1:30"` and
  `swing_metals_and_oil_leverage = "1:15"`, **CARRIED_OVER and unverified since
  2026-09-02**. They are Swing-scoped by key name and their values did not change.
- The 2026-09-15 v2 artifact asserted Standard leverage `fx 1:100` / `metals 1:30`.
  **That assertion has no live official source on 2026-09-18** and is therefore *not*
  admitted into this snapshot's claims. Admitting it would have meant changing a pinned
  rule-fact value on evidence that does not exist — the opposite of a governed re-pin.
- The one Standard leverage figure that *is* evidenced is account-bound, not
  provider-published: `observed_leverage: "1:100"` in the M13 binding, sourced from
  `docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md`. The Standard rulepack
  already records this distinction ("The observed M13 1:100 leverage is account-bound
  evidence, not a claim derived from the public provider snapshot"). That note remains
  correct and is now consistent with the snapshot.

Neither leverage value may be relied on for sizing without a live official source.

## 5. Verification

All run in this worktree against the committed artifacts.

```
=== load_binding ===
PASS  rulepack FTMO_2S_100K_STANDARD_V2 as_of 2026-09-18

=== _validate_official_rule_sources(STANDARD) PASS  age=1047s
    _official_rules(STANDARD) PASS
=== _validate_official_rule_sources(SWING)    PASS  age=1047s
    _official_rules(SWING) PASS
```

Negative controls — every one still refuses, i.e. nothing was weakened:

| tamper | refusal |
|---|---|
| `simultaneous_order_limit` 200 → 201 | `rule_snapshot:normalized_claims_invalid` |
| `claim_provenance` row repointed | `rule_snapshot:claim_provenance_invalid` |
| profile → `… / Swing` | `rule_snapshot:envelope_invalid` |
| one source `http_status` → 404 | `rule_snapshot:source_crosswalk_invalid:…` |
| schema → `…/v2` | `rule_snapshot:envelope_invalid` |
| rulepack `snapshot_sha256` → zeros | `rulepack:official_source_binding_invalid:…` |
| rulepack `retrieved_on` → 2026-09-04 | `rulepack:official_source_vintage_invalid` |
| feed the old 2026-09-15 v2 snapshot | `rule_snapshot:envelope_invalid` |
| feed the old 2026-09-04 v1 snapshot | `rule_snapshot:envelope_invalid` |
| clock advanced 8 days | `rule_snapshot:stale` |

### Test suites

`python -m pytest tools/strategy_farm/tests/ framework/tests/ -k ftmo -q -p no:randomly`

| | baseline (branch point) | after |
|---|---|---|
| passed | 1127 | 1127 |
| failed | 5 | 5 |

The five failures are the same five names before and after. Two of them are the defect
this re-pin fixes:

- `test_ftmo_trial_setpath.py::test_m13_binding_is_standard_hash_bound_and_governor_coherent`
- `test_ftmo_trial_setpath.py::test_generated_manifest_names_standard_profile_and_internal_overlay`

Both **pass in isolation in this worktree** (`20 passed`). In a full-suite run they still
fail because pytest has by then imported the *canonical* `C:/QM/repo` copy of
`tools/strategy_farm/ftmo/trial_setpath.py` — the traceback shows
`path = WindowsPath('C:/QM/repo/tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json')`
— and that checkout is unchanged by this branch. This is the known worktree-vs-canonical
import hazard, not a regression; the two tests go green once this branch lands on `main`.

The other three are unrelated pre-existing failures, unchanged in name and message:
`test_ftmo_no_purchase_guard.py::test_no_transaction_or_payment_tokens_in_package`,
`test_ftmo_trial_setfiles.py::test_generation_static_caps_and_hashes`
(`concentration_policy_not_ratified_or_changed`),
`test_live_uptime_watchdog_static.py::test_ftmo_recovery_verifies_approved_profile_presets_and_binaries_before_launch`
(`binary_sha=` count 8 vs 5).

Consequential sweep
(`-k "rulepack or snapshot or isolated_work or book3 or binding"`): 6 failed / 711 passed
at the branch point, 6 failed / 711 passed after — same six names. `prepare_ftmo_book3_q02`
39/39, `pipeline_books`/dashboard 66/66.

Test fixtures updated alongside the constants (fixture data, never a check):

- `test_ftmo_book3_standalone_evaluator.py`: `RULE_SNAPSHOT_FRESH_NOW` 2026-09-05 →
  2026-09-19, and the future-timestamp fixture 2026-09-06 → 2026-09-20, so the fake clock
  still straddles the new snapshot's retrieval instant.
- `test_ftmo_rules_snapshot.py`: the "newest snapshot on disk" assertion 2026-09-15 →
  2026-09-18.
- `test_prepare_ftmo_book3_q02.py`: synthetic-repo fixture path (3×).
- `test_target_rulepacks.py` / `test_target_outcome_dossier.py`: expected `as_of` and the
  Swing canonical-hash pin.

## 6. Authority boundary

Unchanged and untouched. `authority_boundary` in the M13 binding still reads
`install_authorized: false`, `attachment_authorized: false`,
`autotrading_authorized: false`, `purchase_authorized: false`,
`owner_signature_required: true`. This snapshot is research / Free-Trial / shadow-gate
evidence only. Purchase, AutoTrading, deployment, gate thresholds and book construction
remain OWNER-only (ROT). The snapshot's own freshness window closes
**2026-09-25T02:37:46Z**; any paid-Challenge decision after that needs a re-fetch, not a
re-pin.

## 7. Reproduce

```
python docs/ops/evidence/2026-09-18_ftmo_rules_repin/build_snapshot.py
```

Rebuilds the snapshot from the retained bodies under
`docs/ops/evidence/ftmo_fetch_20260918/` and re-verifies every claim quote as a literal
substring; it aborts rather than emit a wording the evidence does not contain.
