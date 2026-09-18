# FTMO M13 vintage alignment — rule-facts diff 2026-09-04 vs 2026-09-15

Decision: `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917` · generated 2026-09-18 · machine-readable twin: `RULE_FACTS_DIFF.json`

**Verdict: STOP_DO_NOT_ALIGN.** No numeric or boolean fact *value* changes in the six named categories, but the 2026-09-15 artifact is a different **schema generation** (v1 -> v2) that drops nine claims the evaluator consumes and removes field-level provenance entirely. Aligning the constants cannot make `_validate_official_rule_sources` pass; only loosening the exact-equality checks could, which the task forbids and which is ROT-zone gate material.

## 1. Inputs

| artifact | schema | profile | as_of / retrieved | sha256 |
|---|---|---|---|---|
| `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` | `qm.ftmo-official-rules-snapshot/v1` | FTMO Challenge 2-Step / USD 100000 / Swing | 2026-09-04T02:10:47Z | `c199b8f5f528cce5…` |
| `docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json` | `qm.ftmo-official-rules-snapshot/v2` | FTMO Challenge 2-Step / USD 100000 / Standard | 2026-09-15T13:59:31Z | `5e25827b589125e7…` |
| `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json` | target-rulepack/v1 | Standard | as_of 2026-09-15 | — |
| `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json` | target-rulepack/v1 | Swing | as_of 2026-09-04 | — |
| `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json` | m13-standard-demo-binding/v1 | Standard | rulepack.as_of 2026-09-04 | — |

Evaluator constants under test: `OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH = docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`, `OFFICIAL_RULE_SNAPSHOT_SHA256 = c199b8f5f528cce5…`.

## 2. Field-by-field fact diff

The 2026-09-04 column is the claim the evaluator consumes today (`_validate_official_rule_sources.expected_claims`, 31 entries). The 2026-09-15 column is the nearest counterpart in the v2 `fields` block.

| category | consumed claim (2026-09-04) | value 09-04 | locator 09-15 | value 09-15 | verdict |
|---|---|---|---|---|---|
| targets | `phase1_profit_target_percent` | `10` | `fields.targets.phase1_profit_target_pct` | `10` | **IDENTICAL** |
| targets | `verification_profit_target_percent` | `5` | `fields.targets.verification_profit_target_pct` | `5` | **IDENTICAL** |
| targets | `profit_target_operator` | `STRICTLY_GREATER_THAN_TARGET_WHILE_FLAT` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |
| daily_loss | `maximum_daily_loss_percent_of_initial` | `5` | `fields.daily_loss.percent_of_initial` | `5` | **IDENTICAL** |
| daily_loss | `maximum_daily_loss_reset_timezone` | `Europe/Prague` | `fields.daily_loss.timezone` | `Europe/Prague` | **IDENTICAL** |
| daily_loss | `maximum_daily_loss_reset_local_time` | `00:00:00` | `fields.daily_loss.reset_local_time` | `00:00:00` | **IDENTICAL** |
| daily_loss | `maximum_daily_loss_basis` | `MIDNIGHT_BALANCE_MINUS_FIXED_INITIAL_CAPITAL_AMOUNT` | `fields.daily_loss.limit_basis` | `MIDNIGHT_BALANCE_MINUS_FIXED_AMOUNT` | **SEMANTICALLY_EQUAL_LABEL_RECODED** |
| daily_loss | `maximum_daily_loss_breach_operator` | `EQUITY_STRICTLY_BELOW_LIMIT` | `fields.daily_loss.breach_operator` | `STRICTLY_BELOW_LIMIT` | **SEMANTICALLY_EQUAL_LABEL_RECODED** |
| max_loss | `maximum_loss_percent_of_initial` | `10` | `fields.max_loss.percent_of_initial` | `10` | **IDENTICAL** |
| max_loss | `maximum_loss_model` | `STATIC_INITIAL_CAPITAL` | `fields.max_loss.model` | `STATIC_INITIAL` | **SEMANTICALLY_EQUAL_LABEL_RECODED** |
| max_loss | `maximum_loss_breach_operator` | `EQUITY_STRICTLY_BELOW_LIMIT` | `fields.max_loss.breach_operator` | `STRICTLY_BELOW_LIMIT` | **SEMANTICALLY_EQUAL_LABEL_RECODED** |
| trading_days | `minimum_trading_days_per_phase` | `4` | `fields.trading_day_requirement.minimum_trading_days` | `4` | **IDENTICAL_VALUE_TYPE_RECODED** |
| trading_days | `trading_day_qualifier` | `AT_LEAST_ONE_POSITION_OPENED_DURING_PRAGUE_LOCAL_DAY` | `fields.trading_day_requirement.definition` | `Any CE(S)T calendar day 00:00:00-23:59:59 with at least one newly opened position` | **SEMANTICALLY_EQUAL_LABEL_RECODED** |
| deadline | `maximum_trading_period_days` | `null` | `fields.deadline.value` | `NONE` | **IDENTICAL_VALUE_TYPE_RECODED** |
| execution_limits | `expert_advisors_allowed_subject_to_rules` | `True` | `fields.execution_constraints.eas_allowed` | `True` | **IDENTICAL** |
| execution_limits | `simultaneous_order_limit` | `200` | `fields.execution_constraints.max_simultaneous_orders` | `200` | **IDENTICAL_VALUE_TYPE_RECODED** |
| execution_limits | `position_limit_per_day` | `2000` | `fields.execution_constraints.max_positions_per_day_hyperactive_threshold` | `2000` | **IDENTICAL_VALUE_TYPE_RECODED** |
| execution_limits | `hyperactive_server_request_threshold_per_day` | `2000` | `fields.execution_constraints.max_positions_per_day_hyperactive_threshold` | `2000` | **IDENTICAL_VALUE_TYPE_RECODED** |
| execution_limits | `real_market_replicability_required` | `True` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |
| evaluation_conditions | `swing_news_restriction_during_evaluation` | `False` | `fields.news_rule.challenge_phase_restriction` | `False` | **IDENTICAL** |
| evaluation_conditions | `swing_overnight_or_weekend_restriction` | `False` | `fields.weekend_rule.challenge_phase_restriction` | `False` | **IDENTICAL** |
| leverage_profile_scoped | `swing_fx_leverage` | `1:30` | `fields.leverage.fx` | `1:100` | **VALUE_CHANGED** |
| leverage_profile_scoped | `swing_metals_and_oil_leverage` | `1:15` | `fields.leverage.metals` | `1:30` | **VALUE_CHANGED** |
| economics_and_scaling | `usd_100000_2_step_list_price_usd` | `540` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |
| economics_and_scaling | `evaluation_fee_refund_percent_with_first_reward` | `100` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |
| economics_and_scaling | `base_reward_split_percent` | `80` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |
| economics_and_scaling | `maximum_reward_split_percent` | `90` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |
| economics_and_scaling | `account_balance_increase_percent` | `25` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |
| economics_and_scaling | `minimum_months_between_scaleups` | `4` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |
| economics_and_scaling | `scaled_reward_split_percent` | `90` | `<ABSENT>` | `<ABSENT>` | **DROPPED_NO_COUNTERPART** |

### Summary

- **Value changes in the six named categories (targets, daily loss, max loss, trading days, deadline, execution limits): 0 — none.**
- Identical values: 9.
- Label/type re-encoded, semantically equal: 10 (`maximum_daily_loss_basis`, `maximum_daily_loss_breach_operator`, `maximum_loss_model`, `maximum_loss_breach_operator`, `minimum_trading_days_per_phase`, `trading_day_qualifier`, `maximum_trading_period_days`, `simultaneous_order_limit`, `position_limit_per_day`, `hyperactive_server_request_threshold_per_day`). Under exact-equality these are still contract changes, not no-ops.
- **Dropped with no counterpart: 9 (`profit_target_operator`, `real_market_replicability_required`, `usd_100000_2_step_list_price_usd`, `evaluation_fee_refund_percent_with_first_reward`, `base_reward_split_percent`, `maximum_reward_split_percent`, `account_balance_increase_percent`, `minimum_months_between_scaleups`, `scaled_reward_split_percent`).** Two of these — `profit_target_operator` (targets) and `real_market_replicability_required` (execution limits) — sit inside the named categories.
- Profile-scoped value change (expected, pre-declared): `swing_fx_leverage`, `swing_metals_and_oil_leverage` — Swing fx 1:30 / metals+oil 1:15 becomes Standard fx 1:100 / indices 1:50 / metals 1:30.

## 3. Why a constant flip cannot close the binding

`_validate_official_rule_sources()` runs unconditionally for whichever rulepack is selected (Swing by default, Standard via `--m13-demo-binding`) against the single module-pinned snapshot. Re-pinning the constants to the 2026-09-15 file leaves these checks unsatisfied:

| check | fixable by constant flip | detail |
|---|---|---|
| `snapshot.schema == qm.ftmo-official-rules-snapshot/v1` | **no** | 2026-09-15 is 'qm.ftmo-official-rules-snapshot/v2' (schema generation change v1 -> v2) |
| `snapshot.profile == "FTMO Challenge 2-Step / USD 100000 / Swing"` | **no** | 2026-09-15 is 'FTMO Challenge 2-Step / USD 100000 / Standard'; the evaluator hard-codes the Swing profile for BOTH rulepacks |
| `snapshot.freshness_max_age_days == 7` | yes | both are 7 |
| `snapshot age <= 7 days` | n/a | retrieved_at_utc 2026-09-15T13:59:31Z; age 3d at 2026-09-18; window expires 2026-09-22T13:59:31Z |
| `set(snapshot.sources) == EXPECTED_OFFICIAL_SOURCE_IDS` | **no** | v2 carries 5 source ids; 6 of the 7 pinned ids are absent: ftmo_2_step_challenge_official, ftmo_ea_official, ftmo_economic_terms_official, ftmo_forbidden_practices_official, ftmo_news_official, ftmo_weekend_official |
| `every snapshot source http_status == 200` | **no** | ftmo_trading_conditions http_status 404 (news/overnight/weekend page unresolvable on 2026-09-15) |
| `rulepack <-> snapshot url crosswalk` | **no** | rulepack official_sources still names the 7 v1 ids; only ftmo_trading_objectives_official crosswalks |
| `normalized_claims == EXPECTED (31 claims)` | **no** | v2 has no 'normalized_claims' key; facts live under 'fields' with a different shape |
| `claim_provenance == EXPECTED_OFFICIAL_CLAIM_PROVENANCE` | **no** | v2 has no 'claim_provenance' key (field-level provenance is null) |
| `official_sources[*].retrieved_on == "2026-09-04"` | yes | rulepack rows already carry 2026-09-15; a constant flip alone fixes this one |
| `binding rulepack.as_of == rulepack file as_of` | yes | binding says 2026-09-04, rulepack file says 2026-09-15; a config/constant flip fixes this one |

Six of eleven checks are structurally unsatisfiable. They are not vintage strings — they are the shape of the evidence: v2 has no `normalized_claims`, no `claim_provenance`, a different `source_id` universe, and one source that returned HTTP 404.

## 4. Circular provenance in the carried-over rows

Three rule families in the 2026-09-15 snapshot are not fetched evidence:

| field | provenance | carried over from |
|---|---|---|
| `news_rule` | CARRIED_OVER | `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json official_rules` |
| `overnight_rule` | CARRIED_OVER | `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json official_rules` |
| `weekend_rule` | CARRIED_OVER | `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json official_rules` |

The snapshot is meant to be the independent evidence *for* the rulepack, yet these rows are copied *from* that same rulepack. Binding the evaluator to this snapshot would make the news / overnight / weekend facts self-certifying. That is an evidence-integrity property, which the standing authorization places outside Fable-derivable thresholds.

## 5. Observed refusals (reproduced in this worktree)

| call | result |
|---|---|
| `load_binding()` | `Refusal: wrong_rulepack (binding rulepack.as_of 2026-09-04 != rulepack file as_of 2026-09-15)` |
| `_validate_official_rule_sources(STANDARD, 2026-09-04 snapshot)` | `rulepack:official_source_binding_invalid:ftmo_trading_objectives_official` |
| `_validate_official_rule_sources(STANDARD, 2026-09-15 snapshot, constants repinned)` | `rule_snapshot:envelope_invalid` |
| `_validate_official_rule_sources(SWING, 2026-09-04 snapshot)` | `PASS (unchanged baseline)` |
| `_validate_official_rule_sources(SWING, 2026-09-15 snapshot)` | `rule_snapshot:envelope_invalid` |

## 6. Freshness note

Even a hypothetical successful alignment self-expires: the 2026-09-15 snapshot is 3 days old on 2026-09-18 and crosses the (unwidened) 7-day window on **2026-09-22T13:59:31Z**. A durable fix needs a re-fetch, not a re-pin.

