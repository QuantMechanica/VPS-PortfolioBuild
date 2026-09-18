# FTMO official rules snapshot — 2026-09-18 (v1 schema, Standard profile)

Human-readable twin of `docs/ops/evidence/2026-09-18_ftmo_official_rules_snapshot.json`.
The JSON is the binding artifact; this page never overrides it.

| field | value |
|---|---|
| schema | `qm.ftmo-official-rules-snapshot/v1` |
| profile | `FTMO Challenge 2-Step / USD 100000 / Standard` |
| retrieved_at_utc | `2026-09-18T02:37:46Z` |
| freshness window | 7 days — closes `2026-09-25T02:37:46Z` |
| snapshot sha256 | `41624932e16d96d36543a076ad4199cd0c3cba3695c15567235746e99e464785` |
| claims | 30 — 28 RE_CONFIRMED, 2 CARRIED_OVER |
| rule-fact value changes vs 2026-09-04 and 2026-09-15 | **0** |
| builder | `docs/ops/evidence/2026-09-18_ftmo_rules_repin/build_snapshot.py` |
| receipt | `docs/ops/evidence/2026-09-18_ftmo_rules_repin/RECEIPT.md` |

Scope limit: research and Free-Trial / shadow gates only. Not a purchase, deployment,
T_Live or AutoTrading authorization.

## 1. Sources — all seven at HTTP 200

Anonymous HTTPS GET from the VPS, Python urllib, User-Agent `Mozilla/5.0`, no
credentials and no cookies. Raw bodies retained under
`docs/ops/evidence/ftmo_fetch_20260918/`.

| source_id | url | status | bytes | body sha256 (first 16) |
|---|---|---|---|---|
| ftmo_trading_objectives_official | https://ftmo.com/en/trading-objectives/ | 200 | 287644 | `c9cba53c83c62d69` |
| ftmo_economic_terms_official | https://ftmo.com/en/2-step-challenge/ | 200 | 306457 | `81b938784fb93c50` |
| ftmo_2_step_challenge_official | https://ftmo.com/en/2-step-challenge/ | 200 | 306457 | `3232d051a9916746` |
| ftmo_news_official | https://ftmo.com/faq/can-i-trade-news/ | 200 | 315341 | `06f7ba730cd9a877` |
| ftmo_weekend_official | https://ftmo.com/en/faq/do-i-have-to-close-my-positions-overnight-or-before-the-weekend/ | 200 | 310306 | `6858f418ce6bf269` |
| ftmo_ea_official | https://ftmo.com/en/faq/which-instruments-can-i-trade-and-what-strategies-am-i-allowed-to-use/ | 200 | 311481 | `b1ccbebab4e3a14d` |
| ftmo_forbidden_practices_official | https://ftmo.com/en/forbidden-trading-practices/ | 200 | 237921 | `858149fa20db6be0` |

Corroborating bodies retained but not part of the pinned source-id set:

| body | url | status | note |
|---|---|---|---|
| ftmo_scaling_plan_official | https://ftmo.com/en/scaling-plan/ → /en/reward-growth-and-scaling-plan/ | 200 | scaling-plan component (25% / 4 months / 90%) |
| cand_comparison_table | https://ftmo.com/en/comparison-table/ | 200 | 1-Step vs 2-Step objectives table |
| cand_symbols | https://ftmo.com/en/symbols/ | 200 | leverage-silent (negative evidence) |
| cand_account_specs_faq | https://ftmo.com/en/faq/what-are-the-account-specifications/ | 200 | leverage-silent (negative evidence) |

The two GETs of `https://ftmo.com/en/2-step-challenge/` returned bodies of identical
length (306457) but different SHA-256: the page emits per-response varying bytes. The
same behaviour was recorded on 2026-09-04. `Last-Modified` equals the request time on
every page, so it is a dynamic-response artefact and never a content vintage —
`last_modified_is_content_vintage` is `false` on every record.

## 2. Claims

All 30 values are identical to the 2026-09-04 snapshot.

| claim | value | status | confirmed in |
|---|---|---|---|
| phase1_profit_target_percent | `"10"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| verification_profit_target_percent | `"5"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| profit_target_operator | `"STRICTLY_GREATER_THAN_TARGET_WHILE_FLAT"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_daily_loss_percent_of_initial | `"5"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_daily_loss_reset_timezone | `"Europe/Prague"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_daily_loss_reset_local_time | `"00:00:00"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_daily_loss_basis | `"MIDNIGHT_BALANCE_MINUS_FIXED_INITIAL_CAPITAL_AMOUNT"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_daily_loss_breach_operator | `"EQUITY_STRICTLY_BELOW_LIMIT"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_loss_percent_of_initial | `"10"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_loss_model | `"STATIC_INITIAL_CAPITAL"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_loss_breach_operator | `"EQUITY_STRICTLY_BELOW_LIMIT"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| minimum_trading_days_per_phase | `4` | RE_CONFIRMED | ftmo_trading_objectives_official |
| trading_day_qualifier | `"AT_LEAST_ONE_POSITION_OPENED_DURING_PRAGUE_LOCAL_DAY"` | RE_CONFIRMED | ftmo_trading_objectives_official |
| maximum_trading_period_days | `null` | RE_CONFIRMED | ftmo_trading_objectives_official |
| swing_news_restriction_during_evaluation | `false` | RE_CONFIRMED | ftmo_news_official |
| swing_overnight_or_weekend_restriction | `false` | RE_CONFIRMED | ftmo_weekend_official |
| expert_advisors_allowed_subject_to_rules | `true` | RE_CONFIRMED | ftmo_ea_official |
| simultaneous_order_limit | `200` | RE_CONFIRMED | ftmo_ea_official |
| position_limit_per_day | `2000` | RE_CONFIRMED | ftmo_ea_official |
| hyperactive_server_request_threshold_per_day | `2000` | RE_CONFIRMED | ftmo_ea_official |
| real_market_replicability_required | `true` | RE_CONFIRMED | ftmo_ea_official |
| usd_100000_2_step_list_price_usd | `540` | RE_CONFIRMED | ftmo_economic_terms_official |
| evaluation_fee_refund_percent_with_first_reward | `100` | RE_CONFIRMED | ftmo_economic_terms_official |
| base_reward_split_percent | `80` | RE_CONFIRMED | ftmo_economic_terms_official |
| maximum_reward_split_percent | `90` | RE_CONFIRMED | ftmo_economic_terms_official |
| **swing_fx_leverage** | `"1:30"` | **CARRIED_OVER** | — no live source |
| **swing_metals_and_oil_leverage** | `"1:15"` | **CARRIED_OVER** | — no live source |
| account_balance_increase_percent | `25` | RE_CONFIRMED | ftmo_scaling_plan_official |
| minimum_months_between_scaleups | `4` | RE_CONFIRMED | ftmo_scaling_plan_official |
| scaled_reward_split_percent | `90` | RE_CONFIRMED | ftmo_scaling_plan_official |

RE_CONFIRMED means the quoted wording was machine-checked as a literal substring of the
retained body — of the whitespace-normalized rendered text, or of the raw body for the
four economics values that live inside the page's embedded configuration JSON. The
builder raises rather than emit a quote it cannot locate, so no claim in this snapshot
rests on an unverified wording. Per-claim quotes live in
`claim_reconfirmation_2026_09_18` in the JSON.

## 3. The two CARRIED_OVER leverage claims

`https://ftmo.com/en/trading-symbols/` is still HTTP 404, exactly as on 2026-09-04.
Eight further candidate replacements were probed on 2026-09-18; none states a leverage
figure:

| url | status | observation |
|---|---|---|
| /en/trading-symbols/ | 404 | Not Found |
| /en/account-specifications/ | 404 | Not Found |
| /en/faq/what-is-the-leverage-on-ftmo-accounts/ | 404 | Not Found |
| /en/leverage/ | 404 | Not Found |
| /en/faq/what-is-a-swing-ftmo-challenge/ | 404 | Not Found |
| /en/trading-conditions/ | 404 | Not Found (this is the URL that 404'd on 2026-09-15) |
| /en/symbols/ | 200 | no leverage figure in the body |
| /en/comparison-table/ | 200 | no leverage figure in the body |
| /en/faq/what-are-the-account-specifications/ | 200 | answer body is client-rendered; no leverage figure in the served HTML |

No replacement source was invented. Both values are carried over unchanged and are the
snapshot's only unverified rows; they must not be relied on for sizing without a live
official source. See `RECEIPT.md` §4 for what this means for the Standard leverage
figures the 2026-09-15 v2 artifact asserted.

## 4. What changed versus the previous artifacts

Nothing about the rules. The snapshot supersedes two predecessors on evidence quality,
not on facts:

- **2026-09-04** (`c199b8f5…`) — same v1 schema, same 30 claims, identical values.
  Superseded on vintage (14 days old, long past its own 7-day window) and on profile
  label (`Swing` → `Standard`, to match the account the M13 binding targets).
- **2026-09-15** (`5e25827b…`) — a v2-schema artifact the evaluator could not bind:
  nine dropped claims, five of seven source ids, no `claim_provenance`, and its
  trading-conditions source at HTTP 404. Its news / overnight / weekend rows were
  `CARRIED_OVER` *from the rulepack they were meant to certify*. All three are fetched
  evidence here, which closes the circular-provenance defect recorded in
  `docs/ops/evidence/2026-09-18_ftmo_vintage_align/RULE_FACTS_DIFF.md` §4.

## 5. Standard-profile evaluation conditions (descriptive, not part of the pinned claims)

| condition | value | source |
|---|---|---|
| news restriction during Evaluation Process | `false` | ftmo_news_official |
| overnight/weekend restriction during Evaluation Process | `false` | ftmo_weekend_official |
| news restriction on FTMO Account (Standard) | `true` | ftmo_news_official |
| overnight/weekend restriction on FTMO Account (Standard) | `true` | ftmo_weekend_official |
| news window | 2 minutes before to 2 minutes after | ftmo_news_official |

> "While trading during the Evaluation Process, the restriction does not apply regardless
> of the account type (Standard account or Swing)."

This is why the Standard label is a label correction and not a rule change: during the
Evaluation Process — the only phase this factory evaluates — Standard and Swing carry
the same conditions.
