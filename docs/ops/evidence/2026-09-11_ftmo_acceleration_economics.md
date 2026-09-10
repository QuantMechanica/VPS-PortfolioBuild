# FTMO acceleration D — first-reward economics model and prospective pilot contract

Task `ff8be2f1-aa19-4694-86be-9154be3df6b9` (program `FTMO_ACCELERATION_20260909`, workstream
`economics`, priority 96). Status: **model and draft contract built; NOT SEALED.** Nothing in
this document executes: no purchase, no account creation, no AutoTrading/T_Live change, no R5
verdict alteration, no gate-threshold change. Authority: `decisions/2026-09-09_ftmo_acceleration_delegated.md`
(AGENT-DEC-FTMO-ACCELERATION-20260909). Author: Claude, single orchestration pass, 2026-09-11.

## 0 · Firewall — this is not R5, not M13, not a purchase

Three separate instruments, restated from `OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md`
§B so this document cannot be misread as certifying an edge:

| Instrument | Claims | Status | Relation to this document |
|---|---|---|---|
| **R5 acceptance test** | true long-run P1 pass-rate ≥ 0.80, sealed OOS | RATIFIED, needs ≈2,100 sealed days (≈5.75y) | Untouched. This document does not shorten, waive, or substitute for R5. |
| **M13 capture-only trial** | operational execution-fidelity only (demo, USD 0) | RUNNING (`OWNER-DEC-M13-ECONOMIC-TRIAL-20260906`, review_trigger 17/25 qualified pairs) | Feeds execution-fidelity evidence only; ineligible as edge confirmation. |
| **This document (Track D)** | cash-flow model + break-even frontier + a bounded **paid**-challenge decision procedure, for use only after A/B/C evidence exists | DRAFT, unsealed | Uses the *existing* rulepack purchase gates (§4) as the actual decision rule; invents no new probability. |

## 1 · Sourced official terms (Standard account, USD 100,000, 2-Step)

Fixed account variant per the delegated correction: **Standard**, not Swing (Track B confirmed
native account terms "Standard, 1:100, not Swing"; M13's own demo is the same variant —
`docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md`).

| Term | Value | Source | Retrieved |
|---|---|---|---|
| Evaluation fee (Phase 1 purchase) | **USD 540**, one-time | `ftmo_2s_evaluation_fee`, `FTMO_2S_100K_STANDARD_V2.json` (official snapshot `2026-09-04_ftmo_official_rules_snapshot.json`, sha256 `c199b8f5…`) | 2026-09-04; reconfirmed 2026-09-11 via `ftmo.com/en/2-step-challenge/` (fee page text truncated but "Refundable Fee after success" confirmed) and independent aggregator cross-check |
| Fee refund | **100%**, triggered on **first Reward** | `ftmo_2s_fee_refund` | same |
| Reward split | Base **80%**, up to **90%** via Scaling Plan (25% balance step every ≥4 months) — Scaling is irrelevant to the *first* reward | `ftmo_2s_reward_split`, `ftmo_2s_scaling_plan` | same |
| Phase 1 target / Phase 2 target | 10% / 5% of initial balance, no time limit, ≥4 trading days each | `ftmo_2s_phase1_profit_target`, `ftmo_2s_verification_profit_target`, `ftmo_2s_minimum_trading_days` | same |
| Daily / total loss limit | 5% (equity, Prague midnight anchor) / 10% (static) | `ftmo_2s_max_daily_loss`, `ftmo_2s_maximum_loss` | same |
| First reward eligibility | Requestable **on day 14 or any later day after the first placed trade** on the funded account; all positions/pending orders must be flat at request | `ftmo.com/en/faq/how-do-i-withdraw-my-profits/` | fetched live 2026-09-11 |
| Reward review + payout | ≈1–2 business days review + ≈1–2 business days payout after approval (≈2–4 business days total) | same FAQ | fetched live 2026-09-11 |
| Standard-account news/weekend rules | Apply on the **funded** account (not during Evaluation): 2-min pre/post blackout on targeted news; close before weekend / market breaks >2h | `ftmo_standard_news`, `ftmo_standard_weekend` | 2026-09-04 |

The `ftmo_rule_snapshot_fresh` go-criterion caps snapshot age at 7 days before a purchase
decision; the 2026-09-04 snapshot is 7 days old today (2026-09-11) and was spot-checked live
today with no material discrepancy found (fee, refund, split, day-14 rule all match). A fresh
full API pull is still required immediately before any actual purchase, per that criterion —
this spot check does not substitute for it.

## 2 · Cash-flow model (first reward only, no invented probability)

Definitions — `F`=540 (fee, paid upfront regardless of outcome), `Pjoint` = P(pass Phase 1) ×
P(pass Phase 2 | passed Phase 1) (unmeasured for any current candidate — see §5), `Reward` =
80% × (profit accumulated on the funded account by the first reward request, itself unmeasured
and market-dependent), `C` = marginal trading cost (commission + swap + spread) incurred during
the evaluation attempt and the ≥14-day funded hold before the first request, borne **regardless**
of pass/fail:

```
EV = -F·(1 - Pjoint) + Pjoint·(Reward - C_funded) - C_eval
   = Pjoint·(Reward + F - C_funded) - F - C_eval          [C = C_eval + C_funded]
Break-even:  Pjoint* = (F + C) / (Reward + F)
```

This is the same structure as the illustrative `EV = q·R − (1−q)·F − C` in
`OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md` §1 (break-even 540/2,140=25.2% at
R=1,600, C=0), extended to separate P1/P2, name the refund explicitly, and add a cost term.

**Repeat-attempt note (unchanged from the M13 Vorlage, restated because it is easy to miss):**
attempts are **not** independent — same strategy, same regime — so buying N attempts does not
average toward the point estimate the way N independent coin flips would. A failed attempt
updates the belief about the strategy, it does not just cost `F` and reset the odds.

## 3 · Break-even sensitivity frontier (probabilities and cost left as a grid — none invented)

Reward scenarios are **illustrative bands on the funded account's profit at first request**, not
a forecast: Conservative 1% (`R=800`), Base 2% (`R=1,600`, matches the M13 Vorlage's illustrative
figure), Optimistic 4% (`R=3,200`) of the $100,000 initial balance, at the 80% base split.
Cost tiers are illustrative bounds pending Track B's still-open realized-cost closure (§5):
`C=0` (idealized), `C=200`, `C=600` (order-of-magnitude ceiling suggested by the per-sleeve
commission+swap lines in `2026-09-05_ftmo_current_pool_cost_snapshot.md`, not a derived forecast
for any specific candidate at $100k sizing).

| Required joint pass probability `Pjoint*` | C=0 | C=200 | C=600 |
|---|---:|---:|---:|
| R=800 (1%, conservative) | 40.3% | 55.2% | 85.1% |
| R=1,600 (2%, base) | 25.2% | 34.6% | 53.3% |
| R=3,200 (4%, optimistic) | 14.4% | 19.8% | 30.5% |

Reading: at the base reward/cost assumption the pilot is EV-positive once the true joint pass
probability exceeds ≈25–35%; at the conservative/high-cost corner it needs ≈85%. No cell in this
table is a claim that any current candidate's actual `Pjoint` sits above or below the line —
that number does not exist yet for any of the 16 intake pairs (§5).

## 4 · The purchase decision already has numeric gates — this document does not invent new ones

`FTMO_2S_100K_STANDARD_V2.json` already carries the OWNER-relevant purchase go-criteria:

| Criterion | Threshold |
|---|---|
| `ftmo_phase1_probability_gate` | P1 point estimate ≥80%, lower 95% bound ≥70% |
| `ftmo_two_phase_probability_gate` | P2\|1 ≥85%, **joint ≥65%** |
| `ftmo_breach_probability_gate` | upper 95% bound on rule-breach ≤10% |
| `ftmo_free_trial_gate` | ≥1 defect-free exact-profile run inside preregistered bands |
| `ftmo_owner_purchase_gate` | separate signed OWNER decision, no automatic purchase |

The existing **65% joint-pass gate is already more conservative than break-even** in every
scenario except the conservative-reward/high-cost corner (85.1% > 65%). Practical reading: if a
candidate ever clears the existing evidence gates, it clears break-even economics with margin
under all but the worst assumed reward/cost combination; the binding constraint is therefore
**evidence completeness**, not model economics. This document does not lower, waive, or
duplicate these thresholds — it only shows they are the correct decision rule once a `Pjoint`
estimate exists.

## 5 · Where the roster actually stands (A/B/C, read-only synthesis)

| Track | State | Result |
|---|---|---|
| A — admission/qualification (`83ffadd6`) | APPROVED (partial) | **0/16** pairs admitted (12 scope-not-FTMO, 3 evidence-missing, 1 not-config-locked); **16/16** include closures fail validation against the current tree (stale binaries) — no candidate has an executable native FTMO-target plan yet. |
| B — cost/shortlist (`54729be7`) | APPROVED (partial) | **Zero-pair roster.** 7/16 pairs have exposed cost streams, 9 unscored. 1537/XAGUSD excluded (negative before spread). Four investigation candidates only (10706/GBPUSD, 11421/EURUSD, 11422/USDCAD, 13054/XTIUSD) — explicitly *not* an accepted shortlist. Missing native lot/tick/margin specs for those four block real cost closure. |
| C — execution canary (`b7858771`) | APPROVED (partial) | Isolated 11421 governor/manifest built (evidence-only, no terminal/AutoTrading); native M01–M12 negative-test proof still open behind three named blockers (binding contract, isolated account driver, retry race). |

None of the three inputs this document was told to integrate before sealing are complete. Per
the commissioning contract this **does not block building the model** (§§1–4 above), but it does
block sealing a contract or making a `PROCEED` claim.

## 6 · Time-to-first-reward (dependency chain, no invented duration)

```
attempt start → Phase 1 (10%, ≥4 trading days, no cap)
             → Phase 2 (5%, ≥4 trading days, no cap)
             → funded, first trade on funded account
             → ≥14 calendar days hold
             → reward request → ≈1-2 business days review → ≈1-2 business days payout
```

Floor ≈ 4+4+14+2 ≈ **24 calendar days** only if both targets are hit on the minimum trading-day
count, which is not a realistic median. Evaluation phases have no maximum period, so there is no
corresponding statistical ceiling to state; actual time-to-payout is strategy- and market-path
dependent and is not estimated here. This is distinct from the M13 **demo** trial's own 14-day
window (which starts the account's forced deactivation clock, not a reward clock).

## 7 · Prospective pilot contract (draft, exact numbers, all labelled)

| Dimension | Value | Label |
|---|---|---|
| Account | FTMO 2-Step, USD 100,000, **Standard** | Fixed per delegated correction |
| Roster | ≤5 candidates; **currently 0 accepted** (blocked on Track B closure) | Internal policy pending evidence |
| Risk budget | Reuse existing `FTMO_2S_100K_STANDARD_V2.json` guardrails: 1%/trade, 1.5%/correlated cluster, 2.5% total open stop, 3% daily-loss budget @ p99.9 (2pt buffer to official 5%), 7% total-DD budget (3pt buffer to official 10%) | Internal QM policy, not a provider rule — already ratified in the rulepack, not newly invented here |
| Execution/cost version | Bind to Track C's 11421 canary manifest (commit `5d6164a0ed`) once its M01–M12 native proof closes; no other roster member has an execution path yet | Internal policy, contingent |
| Observation cap | One Free-Trial/native-plan pass per candidate config before any purchase (`ftmo_free_trial_gate`, 0 defects) | Existing rulepack gate |
| Data-quality criteria | `ftmo_complete_mtm_evidence` (intratrade equity required, no closed-PnL proxy), `ftmo_execution_fidelity_closed` (0 unadjudicated mismatches) | Existing rulepack gates |
| Operational stop rules | Midnight entry-window block (23:50–00:10 Prague), correlated-cluster and total-stop caps above, Standard-account Friday-flat/news rules on the funded account | Existing internal + provider rules |
| Purchase gate | `ftmo_phase1_probability_gate`, `ftmo_two_phase_probability_gate`, `ftmo_breach_probability_gate`, `ftmo_owner_purchase_gate` (§4) | Existing rulepack gates — unchanged |
| Predeclared evaluation point | Once ≥1 roster member has closure + native cost + execution readiness, run Track A's narrow FTMO V3 native plan (16 runs/candidate before reuse) to produce actual P1/P2 point estimates + 95% bounds, then compare once against §4's existing thresholds. That single comparison is the OWNER purchase decision point — not this document, not a re-estimate after the fact. | Fixed procedure |

**Nothing above is sealed.** Sealing requires at minimum a nonempty Track B roster and a closed
Track A include-closure for at least one member of it; both are open today.

## 8 · Disposition

**CONTINUE_EVIDENCE.** Not `PROCEED_WITH_FREE_PILOT`: zero candidates are currently FTMO-news-
admitted (Track A) and zero are on an accepted cost roster (Track B), so there is nothing to
pilot today. Not `REJECT`: nothing in §§2–4 shows the pilot economics are unfavorable — at the
base reward/cost assumption break-even sits at 25–35% joint pass probability, comfortably below
the existing 65% purchase gate, so the blocker is evidentiary, not economic.

**Concrete next steps (executable, not this document's authority to run):**
1. Track A: rebuild/rebind the 16 stale include closures so at least one candidate has an
   executable native FTMO-target plan.
2. Track B: acquire the four missing native lot/tick/margin specification receipts
   (GBPUSD, EURUSD, USDCAD, USOIL.cash) via the existing collector; rerun `compare.py` for a
   nonzero roster attempt.
3. Track C: close the three named M01–M12 native blockers for the 11421 canary.
4. Only after 1–3 produce a nonempty roster with closure+cost+execution readiness: run the
   native FTMO V3 plan, compute actual P1/P2/joint/breach estimates, and compare once against
   §4 — that comparison, not a new document, is the OWNER purchase decision point.

**Review point (finite):** re-open this memo when any of A/B/C's state changes (roster becomes
non-zero, a closure rebinds, or the canary's native proof closes), or by **2026-09-15T00:00:00Z**
(72h), whichever comes first — do not let this become an unbounded recurring re-check.

## 9 · Compliance with hard limits

External spend: USD 0 (no purchase, no account action). No AutoTrading/T_Live/deployment change.
No R5 verdict, threshold, or population change — §0 firewall restated. No sealed holdout opened.
No existing running task interrupted or duplicated (A/B/C read-only synthesis only). No invented
cost or probability: §3's grid is explicitly labelled illustrative: bands, not point estimates;
§7's numbers are either existing ratified rulepack values or explicitly labelled "internal policy
pending evidence."
