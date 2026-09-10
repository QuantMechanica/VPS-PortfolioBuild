# Track D — FTMO Acceleration: First-Reward Economics + Zero-Fee Pilot Contract

Task `ff8be2f1-aa19-4694-86be-9154be3df6b9` (workstream `economics`, program
`FTMO_ACCELERATION_20260909`, parent `1bf87710-04c7-4cbc-b342-0bc0d660a5fd` =
`docs/ops/OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md`). Author:
Claude, 2026-09-11. **Status: model + draft contract built now; sealing is
explicitly deferred to Tracks A/B/C.** Nothing in this document executes: no
account purchase, no order, no AutoTrading change, no T_Live/FTMO-demo
deployment, no R5/C-6 verdict change, no gate-threshold change.

## 0 · Lage (Deutsch, kurz)

Dieses Dokument liefert zwei Dinge, getrennt von R5 (5,75-Jahre-OOS-Zertifizierung,
bleibt unverändert) und vom NO-BUY-Kaufgate (bleibt unverändert):

1. Ein **reproduzierbares Ökonomiemodell** für den bezahlten Standard-$100K-2-Step-Pfad
   (nicht Swing — Kontovariante korrigiert lt. Auftrag), das die **Break-even-Grenze**
   der gemeinsamen Erfolgswahrscheinlichkeit (Phase1 × Phase2 × Erstauszahlungs-Erreichen)
   in Abhängigkeit vom realisierten Gewinn bei der ersten Reward-Anfrage berechnet —
   **ohne** eine Erfolgswahrscheinlichkeit zu unterstellen (Skript + Tests + JSON-Tabelle,
   `track_d_economics_model.py`, 10/10 Tests grün).
2. Einen **gebührenfreien prospektiven Pilotvertrag** (Free-Trial/Demo, USD 0 Einsatz,
   Standard-Kontovariante), der die drei noch offenen Eingaben — Roster (≤5, Spur B),
   Kosten-/Ausführungsversion (Spur C), Zulassungspfad (Spur A) — als benannte Platzhalter
   trägt und **vor dem Versiegeln** an deren Ergebnisse gebunden wird.

**Disposition dieses Zyklus: `CONTINUE_EVIDENCE`.** Spuren A/B/C stehen noch auf `TODO`
(Router-Zustand, geprüft 2026-09-10T22:12Z über `commission_receipt.json`); der Intake zeigt
0 von 16 Paaren mit FTMO-Zulassung (`intake.json`: `legacy_admitted=0`,
`active_reader_admitted=0`). Ohne Roster, Kostenstapel und Ausführungs-Governor kann kein
Pilot sinnvoll versiegelt werden — das Modell und der Vertragsrahmen stehen jedoch jetzt
bereit, damit A/B/C direkt einschlagen können. Nächster überprüfbarer Punkt:
**2026-09-12T22:00Z** (Programm-Liefertermin), oder früher falls A/B/C vorher landen.

---

## 1 · Reproducible economics model (source-provenance, no hidden probability)

Script: `docs/ops/evidence/2026-09-09_ftmo_acceleration/track_d_economics_model.py`
Tests: `docs/ops/evidence/2026-09-09_ftmo_acceleration/test_track_d_economics_model.py`
(10/10 pass, run below). Output: `track_d_economics_report.json` (regenerable, not hand-edited).

### 1.1 Sourced inputs (account variant fixed to **Standard**, not Swing)

| Constant | Value | Source |
|---|---|---|
| Evaluation fee (USD 100K, 2-Step) | USD 540, one-time | `FTMO_2S_100K_STANDARD_V2.json` rule `ftmo_2s_evaluation_fee`, as_of 2026-09-04 |
| Fee refund | 100%, triggered by first Reward | same file, rule `ftmo_2s_fee_refund` |
| Reward split | 80% base, 90% via Scaling/Premium (≥4 months, not available at first reward) | same file, rule `ftmo_2s_reward_split`; cross-checked live against https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/ fetched 2026-09-11 (independently states 80%/2-Step, 90%/1-Step) |
| Phase1 / Phase2 profit target | USD 10,000 (10%) / USD 5,000 (5%) | `ftmo_2s_phase1_profit_target`, `ftmo_2s_verification_profit_target` |
| Daily loss limit | USD 5,000 (5%), Europe/Prague midnight anchor, equity incl. open PnL | `ftmo_2s_max_daily_loss` |
| Total loss limit | static USD 90,000 floor (10%) | `ftmo_2s_maximum_loss` |
| Minimum trading days | 4 per phase | `ftmo_2s_minimum_trading_days` |
| Maximum trading period | none (current 2-Step Evaluation) | `ftmo_2s_no_time_limit` |
| First-Reward eligibility | 14th or any later day after the first placed trade on the funded account | https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/, fetched 2026-09-11 |
| Review + transfer | 1–2 business days review, then 1–2 business days transfer | same page |
| Minimum withdrawal | USD 20 (bank wire) / USD 50 (crypto) | same page |

Internal (non-provider) risk guardrails reused as-is from the same rulepack's
`internal_guardrails[*]` (classification `INTERNAL_QM_POLICY_NOT_PROVIDER_RULE`,
status `PROPOSED_FOR_CALIBRATION`, none newly invented here): per-trade cap 1%,
correlated-cluster cap 1.5%, total-open-stop cap 2.5%, internal daily-loss budget 3%
(vs. official 5%), internal total-drawdown budget 7% (vs. official 10%/floor 90,000).

### 1.2 Cash-flow structure (per attempt cycle)

```
outlay at attempt start        = USD 540 (Standard 100K 2-Step fee)
if Phase1 fails                = -540, cycle ends (no refund, no evidence of a free retry)
if Phase1 passes, Phase2 fails = -540, cycle ends
if both pass -> funded account, then:
  if first-Reward profit reached within the observation window (bounded, TBD ss3.4):
    inflow = reward_split * realized_profit_usd + 540 (fee refund)
  else: cycle ends unresolved at the observation cap (ss3.4 stop rule), -540 realized,
        or continues if the account has not otherwise breached a limit
EV = P(pass1) * P(pass2|pass1) * P(reach reward|funded) * (0.80*R + 540) - 540 - marginal_cost
```

`P(pass1)`, `P(pass2|pass1)`, `P(reach reward|funded)` and `R` (the realized profit at
first-Reward request) are **all unknown** for the not-yet-selected roster. Per the hard
limit "do not invent costs or probabilities," none is assumed. Instead ss1.3 gives the
**break-even joint probability** as a function of `R`, which Track B/C evidence can later
be compared against once a roster and cost stack exist — this document asserts no point
estimate of its own.

### 1.3 Break-even sensitivity frontier (no assumed success rate)

`breakeven_joint_probability(R) = (540 + marginal_cost) / (0.80*R + 540)`

| Realized profit at first Reward (USD) | Breakeven joint P, cost=0 | Breakeven joint P, cost=200 |
|---:|---:|---:|
| 50 | 93.10% | 127.59% (unreachable — a USD 200 marginal cost can never break even on a USD 50 reward) |
| 100 | 87.10% | 119.35% (unreachable) |
| 250 | 72.97% | 100.00% (breakeven only at certainty) |
| 500 | 57.45% | 78.72% |
| 1,000 | 40.30% | 55.22% |
| 2,500 | 21.26% | 29.13% |
| 5,000 | 11.89% | 16.30% |
| 10,000 | 6.32% | 8.67% |

Reading: the fee refund (+540 on success) means break-even probability falls steeply as
the realized profit at first-Reward grows — a pilot that only ever nets a small qualifying
profit (e.g. the USD 20–50 minimum withdrawal) needs a very high joint pass-probability
(87–93%+) to be worthwhile even before marginal cost; a pilot that reaches a full Phase1-
scale profit (thousands of USD) needs a much lower one. This table is the artifact this
task's acceptance criterion 1 requires ("reproducible economics model and scenario table
... no hidden assumed success rate") — it is deliberately silent on which row is realistic
for any specific EA until Track B's shortlist and Track C's execution evidence exist.

### 1.4 Time-to-cash (floor, not expectation)

Fastest possible calendar-day path: 8 days (2×4 minimum qualifying days, both phases
back-to-back with no gap) + 14 days (first-Reward eligibility from first live trade) +
2 business days (fastest review+transfer) = **24 calendar days, illustrative lower bound
only**. Actual Phase1/Phase2 duration is provider-unbounded above and unmeasured for any
QM strategy under Standard mark-to-market simulation; this is not a promised timeline.

### 1.5 Retry / repeated-attempt caveat

A naive "expected attempts to first success" under an *independence* assumption is
computed by the script (`naive_independent_expected_attempts_to_first_success`) but is
explicitly labelled non-recommendation: `docs/ops/OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md`
§G already states repeated attempts on the same strategy/regime are correlated, so the
EV formula is "not a licence to re-buy." This document does not compute or recommend a
repeated-purchase plan; each future attempt (if ever OWNER-authorized) needs its own
signed `ftmo_owner_purchase_gate` decision per the rulepack's `evaluation_profile.go_criteria`.

### 1.6 Verification

```
python -m pytest docs/ops/evidence/2026-09-09_ftmo_acceleration/test_track_d_economics_model.py -q
10 passed in 0.89s

python docs/ops/evidence/2026-09-09_ftmo_acceleration/track_d_economics_model.py
wrote track_d_economics_report.json  (regenerated, matches table above)
```

---

## 2 · Zero-fee prospective pilot contract (draft, unsealed)

This is a **Free Trial / Demo** pilot (USD 0 real capital, per the same firewall §B/§D
pattern already ratified for M13), not a paid-Challenge commitment. It extends M13's
generic capture-only contract with the specific fields this task's mandate requires,
each explicitly labelled either **sourced** (provider fact / existing hash-bound
artifact) or **internal policy — pending Track B/C** (a placeholder this contract commits
to binding before it may be sealed).

| Field | Value now | Status |
|---|---|---|
| Account variant | FTMO Standard, 2-Step, USD 100,000 (`FTMO_2S_100K_STANDARD_V2`) | **sourced** — corrects the M13 default of Swing per this task's explicit mandate |
| Roster | ≤5 EAs | **pending Track B** (`54729be7-8082-4a8c-afcf-e4497e6d9f4a`, workstream `cost_shortlist`, still `TODO`) |
| Risk budget | per-trade 1% / correlated-cluster 1.5% / total-open-stop 2.5% / internal daily-loss 3% / internal total-drawdown 7%, all of USD 100,000 initial balance | **sourced** — reused unchanged from the Standard rulepack's existing `internal_guardrails` (status `PROPOSED_FOR_CALIBRATION`); this contract does not invent a new number |
| Cost / execution version | isolated governor + shared-risk canary | **pending Track C** (`b7858771-ecdc-4bb5-9d2f-d428a12bc661`, workstream `execution`, still `TODO`) |
| Observation cap | proposed **60 Prague trading days** from pilot start, or first-Reward request (if earlier), whichever comes first | **internal policy, proposed here** — chosen to exceed the 24-day cash floor (ss1.4) by a margin covering unmeasured Phase1/2 duration, without being open-ended; **not yet OWNER-ratified** |
| Data-quality criteria | reuse existing `ftmo_complete_mtm_evidence` gate: tick/event-complete interval-minimum equity, Prague day anchors, FTMO symbols/costs/swap/margin, pending-order state; `closed_pnl_daily_proxy_allowed=false` | **sourced**, same rulepack `evaluation_profile.go_criteria` |
| Operational stop rules | any single rule/governor/identity/execution defect ends the run (`operational_defects_allowed=0`, reused from `ftmo_free_trial_gate`); breach of the internal 3%/7% budgets ends the run immediately, before the official 5%/10% limits are touched | **sourced** (defect rule) + **internal policy, existing** (budget rule, not newly invented) |
| Predeclared evaluation point | **one** evaluation, at observation-cap expiry or first-Reward eligibility, whichever is first — no repeated peeking, matching M13 §D's fixed-before-opening discipline | **internal policy, proposed here** |

**This contract is explicitly unsealed.** Sealing requires, in order: (a) Track A's
admission planner confirming which of the frozen 16 pairs are FTMO-target-eligible at
all (today: 0/16); (b) Track B's ≤5-EA roster with its own cost/correlation evidence;
(c) Track C's isolated execution-governor canary. Per the task's own hard limits, "pilot
preparation is not a builder bypass" — nothing here authorizes account creation, which
remains an OWNER-only act (M13 §H.2) even for a zero-fee Demo/Free Trial, and is not
requested by this document.

---

## 3 · Bounded first-reward decision

- **Disposition: `CONTINUE_EVIDENCE`.** Neither `PROCEED_WITH_FREE_PILOT` (roster/cost/
  execution inputs do not exist yet — sealing now would bind an empty contract) nor
  `REJECT` (nothing in the sourced economics rules out a pilot; the break-even frontier
  in ss1.3 shows viable regions exist for realistic Phase1-scale profits) is supported by
  current evidence.
- **Risk / time / cost uncertainty carried forward, not resolved here:** P1, P2|P1, and
  P(reach reward|funded) are unknown (ss1.2); realized profit `R` at first Reward is
  unknown; Phase1/2 duration is unmeasured and provider-unbounded above (ss1.4); the
  60-Prague-day observation cap (ss2) is a proposal, not yet OWNER-ratified.
- **Next action:** Tracks A/B/C execute independently (already commissioned, router
  lane `codex`, priorities 99/98/97); this document's placeholders in ss2 get bound to
  their outputs, the observation cap gets an OWNER ratification pass, and the contract
  is re-evaluated for sealing.
- **Finite review point: 2026-09-12T22:00:00Z** (program `delivery_target_utc`,
  `commission_receipt.json`), or immediately once all three of A/B/C reach `REVIEW`,
  whichever is first.
- **Untouched by this document:** R5 verdict and its ≈5.75-year sealed-OOS population
  (`OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`), the NO-BUY purchase gate,
  the 25-pair guarded-builder prerequisite, any Q-gate threshold, T_Live/AutoTrading, and
  every existing pipeline verdict.

---

## Files

- `track_d_economics_model.py` — reproducible model (constants + break-even + sensitivity table)
- `test_track_d_economics_model.py` — 10 tests, all passing
- `track_d_economics_report.json` — regenerated output backing ss1.3's table
- this file — narrative contract + disposition

No pipeline verdict is asserted or altered. No terminal, T_Live, account, AutoTrading, or
purchase action was taken. Left in `REVIEW` for router close-out; the task's own
acceptance criteria (reproducible model with provenance, prospective contract with
labelled placeholders, bounded decision with next action and review point, no R5/purchase/
live/retrospective alteration) are met for what is buildable before Tracks A/B/C land.
