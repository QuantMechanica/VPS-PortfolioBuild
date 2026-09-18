# RECEIPT — FTMO M13 vintage alignment: STOPPED, not aligned

- **Decision id:** `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`
- **Date:** 2026-09-18
- **Branch / worktree:** `agents/fable-ftmo-vintage-20260918` @ `C:/QM/worktrees/fable-ftmo-vintage-20260918`
  (from `agents/board-advisor` @ `4f92aedd40`)
- **Outcome:** **STOP — the evaluator and the binding were NOT re-pinned to the 2026-09-15 snapshot.**
  This receipt records the proof, the blocking reason, and what an OWNER decision would have to cover.

## 1. What was asked

Align `ftmo_book3_standalone_evaluator.py` and `ftmo_m13_standard_demo.v1.json` to the 2026-09-15
official rule snapshot as one consistent vintage, **provided** a field-by-field diff shows the
2026-09-15 snapshot changes no binding rule FACT the evaluator consumes; otherwise stop and report.

## 2. What was found

### 2.1 The mismatch is real and reproduced

| call (this worktree) | result |
|---|---|
| `tools.strategy_farm.ftmo.trial_setpath.load_binding()` | `Refusal: wrong_rulepack` |
| `_validate_official_rule_sources(STANDARD, 2026-09-04 snapshot)` | `rulepack:official_source_binding_invalid:ftmo_trading_objectives_official` |
| `_validate_official_rule_sources(STANDARD, 2026-09-15 snapshot, constants re-pinned)` | `rule_snapshot:envelope_invalid` |
| `_validate_official_rule_sources(SWING, 2026-09-04 snapshot)` | PASS (unchanged baseline) |

`load_binding()` lives at `tools/strategy_farm/ftmo/trial_setpath.py:112`. It refuses because
`binding.rulepack.as_of` is `2026-09-04` while the rulepack file's own `as_of` is `2026-09-15`.

Vintage constants on the evaluator path (`tools/strategy_farm/portfolio/ftmo_book3_standalone_evaluator.py`):

| line | constant / check | value |
|---|---|---|
| 192–194 | `OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH` | `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` |
| 195–197 | `OFFICIAL_RULE_SNAPSHOT_SHA256` | `c199b8f5…` |
| 779 | deployment-boundary note prose | "…2026-09-04 public provider snapshot" |
| 840 | `contract.get("as_of") != "2026-09-04"` | M13 binding gate |
| 1417 | `row.get("retrieved_on") != "2026-09-04"` | rulepack source vintage gate |
| 1515 | `"as_of": "2026-09-15" if is_standard else "2026-09-04"` | already dual-vintage |
| 2784–2788 | snapshot staging uses the module constants unconditionally | both rulepacks |

Note line 1515: `_official_rules()` was **already** taught the 2026-09-15 Standard vintage by commit
`992c59d1af`, but `_validate_official_rule_sources()` (1373–1494) was not. That asymmetry is the
defect. The rulepack was rebound to the new snapshot; the evidence validator around it was not.

### 2.2 Proof that no consumed fact VALUE changed

Full field-by-field diff: `RULE_FACTS_DIFF.md` + `RULE_FACTS_DIFF.json` (this directory).

| bucket | count | claims |
|---|---|---|
| **Value changes in the six named categories** (targets, daily loss, max loss, trading days, deadline, execution limits) | **0** | — |
| Identical value and type | 9 | phase-1 10% / verification 5% / daily 5% / Prague / 00:00:00 / max loss 10% / EAs allowed / news + weekend evaluation-exempt |
| Semantically equal, label or type re-encoded | 10 | daily-loss basis, both breach operators, max-loss model, minimum trading days (`4` → `"4"`), trading-day qualifier, deadline (`null` → `"NONE"`), 200 / 2000 / 2000 limits (int → string) |
| **Dropped with no counterpart in 2026-09-15** | **9** | `profit_target_operator`, `real_market_replicability_required`, `usd_100000_2_step_list_price_usd`, `evaluation_fee_refund_percent_with_first_reward`, `base_reward_split_percent`, `maximum_reward_split_percent`, `account_balance_increase_percent`, `minimum_months_between_scaleups`, `scaled_reward_split_percent` |
| Profile-scoped change (pre-declared, expected) | 2 | `swing_fx_leverage` 1:30 → Standard 1:100; `swing_metals_and_oil_leverage` 1:15 → metals 1:30 |

So the headline holds: **every economically load-bearing threshold is numerically unchanged.**
10% / 5% / 5% / 10% / 4 days / no deadline / 200 orders / 2000 positions are identical across the two
vintages. Nothing in the FTMO objective model moved.

### 2.3 Why that is nevertheless not sufficient to align

Two of the dropped claims sit **inside** the named categories: `profit_target_operator` (targets) and
`real_market_replicability_required` (execution limits). Under the task's own stop rule — "if any FACT
the evaluator consumes changes, STOP" — a fact that ceases to be evidenced has changed, even though no
number moved.

More decisively, the 2026-09-15 artifact is **not a new vintage of the same document — it is a
different schema generation** (`qm.ftmo-official-rules-snapshot/v1` → `/v2`). Six of the eleven checks
in `_validate_official_rule_sources()` are structurally unsatisfiable by any constant change:

1. `snapshot.schema == ".../v1"` — v2.
2. `snapshot.profile == "… / Swing"` — the file says `… / Standard`, and the evaluator hard-codes the
   Swing profile for **both** rulepacks.
3. `set(snapshot.sources) == EXPECTED_OFFICIAL_SOURCE_IDS` — v2 carries 5 ids; 6 of the 7 pinned ids
   are absent (`ftmo_2_step_challenge_official`, `ftmo_ea_official`, `ftmo_economic_terms_official`,
   `ftmo_forbidden_practices_official`, `ftmo_news_official`, `ftmo_weekend_official`).
4. every source `http_status == 200` — `ftmo_trading_conditions` returned **404**.
5. `normalized_claims == EXPECTED` (31 claims) — v2 has no `normalized_claims` key at all.
6. `claim_provenance == EXPECTED_OFFICIAL_CLAIM_PROVENANCE` — v2 has no `claim_provenance` (null).

Making these pass requires either deleting the checks or writing a second, v2-shaped expected-claims
contract. The first is forbidden by the task and is gate integrity. The second is **authoring new gate
criteria**, which the Stehende Vollmacht puts in the ROT zone (gate thresholds and contract criteria are
never autonomous), and which OWNER-DEC-D3-20260915 §30 explicitly withholds from Fable-derived
thresholds where evidence integrity and provenance are concerned.

### 2.4 An independent, already-committed judgement agrees

`tools/strategy_farm/tests/test_ftmo_binding_pin_line_endings.py` (`_sync_as_of`, lines 106–120,
ticket a5cf99d0, 2026-09-18) documents this exact mismatch and deliberately declines to fix it:

> "picking the winning date is a gate-criterion (ROT) call for the OWNER, not a line-ending repair.
> The label is therefore synced inside the fixture only."

That prior decision stands; nothing found today overturns it.

### 2.5 Two further defects surfaced

- **Circular provenance.** Three rule families in the 2026-09-15 snapshot (`news_rule`,
  `overnight_rule`, `weekend_rule`) carry `provenance: CARRIED_OVER`, `carried_over_from:
  FTMO_2S_100K_STANDARD_V2.json official_rules` — copied **from** the rulepack the snapshot is supposed
  to independently evidence. Binding the evaluator to it would make those facts self-certifying.
- **Self-expiring even if aligned.** The snapshot's `retrieved_at_utc` is `2026-09-15T13:59:31Z`; the
  unwidened 7-day window closes **2026-09-22T13:59:31Z**. A re-pin buys four days. The durable fix is a
  re-fetch, not a re-label.

## 3. What changed in the repo

Evidence only. **No source, config, constant, fixture or test was modified.**

| file | status |
|---|---|
| `docs/ops/evidence/2026-09-18_ftmo_vintage_align/RULE_FACTS_DIFF.md` | added |
| `docs/ops/evidence/2026-09-18_ftmo_vintage_align/RULE_FACTS_DIFF.json` | added |
| `docs/ops/evidence/2026-09-18_ftmo_vintage_align/RECEIPT.md` | added |

`load_binding()` therefore still refuses with `wrong_rulepack`, by design, and the M13 demo binding
remains mutually unsatisfiable until the OWNER decides the questions in §5.

## 4. Test counts

Scope: every `tools/strategy_farm/tests/test_*ftmo*.py` module (127 files), run per-file to avoid the
cross-module `sys.path` bleed described below.

- **4 pre-existing failures, all on the base commit, none introduced here:**
  1. `test_ftmo_no_purchase_guard.py::test_no_transaction_or_payment_tokens_in_package` — the token
     `payment` appears in `first_passage.py`. Unrelated to vintage.
  2. `test_ftmo_trial_setfiles.py::test_generation_static_caps_and_hashes` —
     `TrialSetError: concentration_policy_not_ratified_or_changed`. Unrelated to vintage.
  3. `test_ftmo_trial_setpath.py::test_m13_binding_is_standard_hash_bound_and_governor_coherent` —
     `Refusal: wrong_rulepack`. **This is the defect under investigation.**
  4. `test_ftmo_trial_setpath.py::test_generated_manifest_names_standard_profile_and_internal_overlay` —
     `Refusal: wrong_rulepack`. **Same defect.**
- Everything else passes. `test_ftmo_binding_pin_line_endings.py`: 11/11 pass in isolation.
- Whole-suite run (`-k ftmo`, 1130 selected): `10 failed, 1120 passed, 15 subtests passed`. The six
  extra failures are **test-environment bleed, not code**: `tools/strategy_farm/tests/conftest.py:14`
  can leave `trial_setpath` resolved out of `C:\QM\repo`, whose working tree currently has an
  **uncommitted modification** to `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json`
  (pin `473a1d5e…` vs the committed `9db8fda7…`). They vanish on a clean per-file run. Flagged as a
  separate finding — see §5.

No test was added, because no behaviour changed. A test that pins the 2026-09-15 vintage would encode
the very gate decision that is being deferred.

## 5. Open questions for the OWNER (ROT)

1. **Which vintage governs the M13 Standard binding** — re-fetch a v1-shaped 2026-09-15+ snapshot, or
   ratify the v2 shape and author a v2 expected-claims contract?
2. **Are the nine dropped claims still required as evidenced facts?** If the economics/scaling block
   (fee 540, refund 100%, splits 80/90, scaling 25% / 4 months / 90%) and `profit_target_operator` and
   `real_market_replicability_required` must stay evidenced, the 2026-09-15 snapshot is incomplete and
   must be re-fetched rather than adopted.
3. **Is `CARRIED_OVER` acceptable provenance** for the news / overnight / weekend rows, given it points
   back at the rulepack being validated?
4. **Dirty canonical checkout:** `C:\QM\repo` @ `565de64164` holds an uncommitted edit to
   `FTMO_2S_100K_STANDARD_V2.json`. That file is hash-pinned by the binding. It should be committed or
   reverted before any vintage work lands, or the pin will drift again.

## 6. Recommended next step

Re-fetch the seven official FTMO sources into a **v1-shaped** snapshot dated on or after 2026-09-18,
carrying complete `normalized_claims` and `claim_provenance` for the Standard profile, with the
`ftmo_trading_conditions` 404 resolved to a live URL. Then the alignment is a genuine re-pin: constants,
`binding.rulepack.as_of`, and the `retrieved_on` gate move together, every exact-equality check stays
exactly as strict as it is today, and the 7-day window is not widened. Until then the refusal is the
system working correctly, and it should not be papered over.
