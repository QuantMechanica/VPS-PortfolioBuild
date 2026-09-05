# FTMO Stage-Transition & First-Reward Runbook (2026-09)

**Status:** operational runbook (evidence-only authoring; no state changed; no purchase; no MT5 action).
**Author:** Claude (Factory CEO lane), task 7dceadd0, 2026-09-05.
**Scope:** the FTMO **2-Step $100,000 Swing** profile only, as pinned in `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json` (source snapshot `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`). Every rule value below cites its `rule_id` in that rulepack; where a value could not be re-sourced it is marked **UNVERIFIED**, and where no source exists it is marked **MISSING** — never invented.
**Hard boundary:** `deployment_boundary` in the rulepack is explicit — `runtime_integration=NOT_IMPLEMENTED`, `deploy_authorization=OWNER_ONLY`, `factory_action_authorized=false`, `mt5_action_authorized=false`, *"A future runtime integration requires a new reviewed version and explicit OWNER authorization."* This runbook describes what each transition **is** and what evidence is captured; it authorizes nothing.

> **Revision 2026-09-05 (post-review a7866405):**
> - **F7** — replaced the stale `2026-09-05_review_ftmo_positive_evidence_test.md` FAIL / 3-BLOCKER acceptance-test references (§6 precondition 3 and the evidence index) with the current R5 state: independently reviewed `RATIFIABLE_AS_PREDECLARED_TEST` in `2026-09-05_review4_ftmo_positive_evidence_test.md`, plus the R5 seal hash and the delivered probability/correlation contract V1 — all still **PENDING OWNER ratification** (ratification cannot lift NO-BUY today; strict P1 lower-95 ≥ 0.80 and the adequacy/power guards preserved).
> - **F8** — labeled §0 Phase-2's lower-risk verification profile as a **proposed QM choice, not a provider requirement** (the provider rule is only the halved target at identical loss limits).

---

## 0 · Zusammenfassung für OWNER (DE)

Der FTMO-2-Step-Swing-Pfad hat drei Stufen und einen ersten Reward. **Nichts davon passiert automatisch** — jede Stufengrenze ist ein Provider-Ereignis (FTMO wertet dein Konto aus), und jede QM-seitige Handlung an der Grenze ist OWNER-only oder rein beobachtend.

1. **Phase 1 (Challenge):** +10 % / $10.000 Gewinn, Kontostand $110.000, mind. 4 Prague-Tage mit ≥1 eröffneten Position, kein Zeitlimit, bestanden = Stand > Ziel bei **0 offenen Positionen**. Grenzen: Tagesverlust nie unter Prague-Mitternachts-Stand −5 %/$5.000 (Equity inkl. offenem PnL), Max-Verlust statisch $90.000.
2. **Phase 2 (Verification):** +5 % / $5.000, Stand $105.000, sonst identische Verlustgrenzen, halbe Ziel-Schwelle. Ein **niedrigeres QM-Risiko-Profil** für Phase 2 ist eine **vorgeschlagene QM-Wahl, keine Provider-Vorgabe** — die Provider-Regel ist nur das halbierte Ziel bei identischen Verlustgrenzen.
3. **FTMO Account (funded):** nach beiden Phasen; Reward-Split **80 %** (bis 90 % über Scaling Plan/Premium). **Erster Reward** erstattet die $540-Gebühr zu 100 %.

**Was OWNER/legal ist:** Kontoerstellung/Login, Kauf einer bezahlten Challenge (bleibt AUSGESCHLOSSEN — Blanket-Release „alles außer Kauf"), AutoTrading-Schalter, jede Reward/Payout-Anforderung im FTMO-Kundenbereich, jede Vertragsannahme. **Was der AI-Seat tut:** Evidenz an jeder Grenze protokollieren (Equity-Serie, Regel-Konformität, Identität), beobachtend überwachen (`ftmo_trial_pulse.py`), niemals einen Halt/Kill/Order schreiben (die einzige Geld-Kontroll-Autorität ist der Governor-EA `QM5_13206` gegen ein signiertes Manifest).

**Wichtig:** Es gibt heute **keine Laufzeit-Integration** (`deployment_boundary.runtime_integration=NOT_IMPLEMENTED`). Dieser Runbook ist die Landkarte für den Tag, an dem — nach signiertem Pointer, gehobenem/gehaltenem Freeze, ratifiziertem Acceptance-Test und einem defektfreien Free-Trial — eine bezahlte Challenge überhaupt zur OWNER-Entscheidung wird.

---

## 1 · The three stages and the pass/loss rules (pinned rulepack)

All values from `FTMO_2S_100K_SWING_V2.json official_rules`, source `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` (source_ids `ftmo_trading_objectives_official`, `ftmo_economic_terms_official`, `ftmo_news_official`, `ftmo_weekend_official`). Loss-limit tested quantity is **`EQUITY_INCLUDING_OPEN_PNL_SWAPS_COMMISSIONS`** at every stage; breach operator `STRICTLY_BELOW_LIMIT`.

| dimension | Phase 1 (Challenge) | Phase 2 (Verification) | FTMO Account (funded) |
|---|---|---|---|
| profit target | **+10% / $10,000** → balance $110,000 (`ftmo_2s_phase1_profit_target`) | **+5% / $5,000** → balance $105,000 (`ftmo_2s_verification_profit_target`) | none (trading for reward) |
| max daily loss | equity ≥ Prague-midnight balance − 5%/$5,000 (`ftmo_2s_max_daily_loss`) | same | same (applies to funded account) |
| max (overall) loss | static, floor **$90,000** (10% of initial) (`ftmo_2s_maximum_loss`, `STATIC_INITIAL`) | same | same |
| min trading days | **4** CE(S)T days with ≥1 `POSITION_OPENED` (`ftmo_2s_minimum_trading_days`) | 4 | n/a |
| time limit | **none** (`ftmo_2s_no_time_limit`, `maximum_trading_period_days=null`) | none | none |
| pass condition | balance `STRICTLY_GREATER_THAN_TARGET` with `positions_open=0` (`ftmo_2s_pass_condition`) | same | n/a |
| news restriction | **NONE** for Swing (`ftmo_swing_news`, `restricted=false`; RE_CONFIRMED HTTP 200 2026-09-04) | NONE | NONE |
| weekend/overnight | **NONE** for Swing (`ftmo_swing_weekend`, `restricted=false`; RE_CONFIRMED HTTP 200 2026-09-04) | NONE | NONE |
| EA / server limits | EAs allowed; ≤200 simultaneous orders, ≤2000 positions/day, hyperactive above 2000 server req/day (`ftmo_ea_server_limits`) | same | same |
| leverage (Swing) | FX 1:30, metals 1:15, oil 1:15 (`ftmo_swing_leverage`) — **UNVERIFIED** (trading-symbols URL HTTP 404 2026-09-04, `CARRIED_OVER`; corroborated only by `2026-07-30_ftmo_book3_symbol_cost_snapshot.json`) | same | same |

**QM-Regel unabhängig vom Provider:** QM news blackout mandatory; preserve the approved calendar/filter contract in both research and trial (`docs/ops/EDGE_LAB_CHARTER_2026-05-22.md:28`). Die Provider-Ausnahme für Swing ist keine interne Ausnahme; die provisorischen Kostenfelder bleiben bis zur Bestätigung nicht übernommen.

**Prague-midnight anchor (all stages):** the daily-loss limit re-baselines on the CE(S)T midnight balance; `timezone=Europe/Prague`, `reset_local_time=00:00:00`, `limit_basis=MIDNIGHT_BALANCE_MINUS_FIXED_AMOUNT`. QM's optional `qm_ftmo_midnight_entry_window` (`:384-398`, `INTERNAL_QM_POLICY_NOT_PROVIDER_RULE`, `PROPOSED_FOR_CALIBRATION`) blocks new entries 23:50-00:10 Prague around that anchor — **not a provider rule and not enforced today.**

**Replicability constraint (all stages):** `ftmo_replicable_trading_requirement` — no latency/feed exploitation, no server manipulation, no non-replicable risk; strategies must remain replicable in real markets.

---

## 2 · The stage-transition map — trigger, actor, evidence captured

Each transition is a **provider evaluation event** (FTMO decides), followed by a QM-side evidence capture and (where money or contract is involved) an OWNER/legal act. No transition is automated (`deployment_boundary`).

| transition | trigger (provider) | QM-side actor | evidence captured (path) | OWNER / legal act |
|---|---|---|---|---|
| **T0 → Free-Trial / shadow** | account created (demo/Free-Trial) | AI: provision (`ftmo_lane_runner`), monitor (`ftmo_trial_pulse`) | telemetry stream (Part-2 §B.4): M5 equity/min-equity, positions, pending orders, Prague-day boundaries → `D:/QM/mt5/FTMO_STREAM*/` + daily exporter | OWNER creates account + terminal login; OWNER flips `EXPECTED_STATE` PARKED→RUNNING (decision), then AutoTrading (ROT) |
| **Free-Trial → decision-to-buy** | trial completes defect-free, inside prediction bands | AI: score against `ftmo_free_trial_gate` (after acceptance-test ratification) | trial verdict dossier (`operational_defects_allowed=0` check) | **OWNER signs `ftmo_owner_purchase_gate`** — a paid Challenge is a separate signed OWNER decision; **PURCHASE excluded** under the 2026-09-05 blanket release |
| **Buy → Phase 1 active** | FTMO issues Phase-1 credentials | AI: verify identity (`verify_live_deployment_contract`-style SHA/magic/set/news), monitor | deploy/verification record `decisions/YYYY-MM-DD_t_live_<ea>_<symbol>.md` (adapted for FTMO), Q16 11-check pass | OWNER creates/loads the FTMO Phase-1 terminal; OWNER flips AutoTrading (ROT) |
| **Phase 1 → Phase 2** | balance > $110,000, positions_open=0, ≥4 Prague days | AI: capture the passing equity curve + rule-compliance log; re-verify identity for the Phase-2 profile | Phase-1 pass dossier: equity series, min-equity vs daily/overall floors, trading-day count, flat-at-target proof | OWNER acknowledges FTMO's Phase-2 issuance; re-login to Phase-2 credentials; AutoTrading (ROT) |
| **Phase 2 → FTMO Account (funded)** | balance > $105,000, positions_open=0, ≥4 Prague days | AI: capture Phase-2 pass dossier; prepare the funded-account monitor contract | Phase-2 pass dossier (as above) | OWNER accepts the FTMO Account terms (contract, legal); re-login; AutoTrading (ROT) |
| **Funded → first Reward** | reward period completes with net profit | AI: reconcile the reward-eligible P&L; capture the payout evidence | reward reconciliation (net profit, split, fee-refund) | **OWNER requests the payout in the FTMO client area** (legal/financial); OWNER records receipt |

**What the AI seat never does at any transition:** create/purchase an account, accept terms, request a payout, flip AutoTrading, or write a halt/kill/liquidation signal. `ftmo_trial_pulse.py` is a code-level observer only (one-authority tombstone); the sole armed money-control authority is the governor EA `QM5_13206` against an OWNER-signed manifest.

---

## 3 · First reward / payout mechanics (pinned rulepack)

From `FTMO_2S_100K_SWING_V2.json official_rules`, source `ftmo_economic_terms_official`:

- **Evaluation fee** (`ftmo_2s_evaluation_fee`): **$540** list fee, `fee_type=ONE_TIME_REFUNDABLE_AFTER_SUCCESS`. *(Temporary promotions are not treated as durable economics — the $540 list price is the modeled number.)*
- **Fee refund** (`ftmo_2s_fee_refund`): **100%** refund, `trigger=FIRST_REWARD`. The $540 comes back in full with the first Reward after successful completion — this is the sense in which the evaluation is "refundable".
- **Reward split** (`ftmo_2s_reward_split`): base **80%**, rising to **90%** via the Scaling Plan or Premium Programme (`base_percent=80`, `maximum_percent=90`).
- **Scaling plan** (`ftmo_2s_scaling_plan`): **+25% account-balance increase every 4 months** and a **90% reward split** for eligible FTMO Traders (`balance_increase_percent=25`, `minimum_months=4`, `reward_split_percent=90`).

**First-reward sequence (mechanics, not a QM action):** funded account trades → net profit accrues over a reward period → OWNER requests the payout in the FTMO client area → FTMO pays the trader's split (80% base) → the **first** such reward also refunds the $540 fee (100%). Every step here is FTMO-side and OWNER/legal; there is no QM tooling that requests, receives, or accounts for a payout, and none is authorized (`deployment_boundary.factory_action_authorized=false`).

**UNVERIFIED / MISSING at the economics layer:**
- Swing **leverage** 1:30/1:15 is UNVERIFIED (404 on the trading-symbols URL, 2026-09-04) — margin headroom for lot-sizing depends on it (Part 1 §B.2, Part 2 §B.3).
- **Swap** for XAGUSD and the 4 FX candidates is **MISSING** on disk (Part 1 §B.3) — material for D1 multi-day Swing holds.
- Per-reward-period length, minimum-payout thresholds, and the exact reward-request cadence are **MISSING** from the pinned rulepack (it captures split/refund/scaling, not the payout-period calendar) → OWNER client-area confirmation.

---

## 4 · Evidence captured at each transition (schema)

The evidence discipline is the same at every stage: capture the mark-to-market series and rule-compliance proof that a backtest cannot supply (Part 2 §B.4), plus the identity verification (SHA256/magic/set/news) that CLAUDE.md's T_Live workflow mandates.

| stage boundary | mark-to-market evidence | rule-compliance evidence | identity evidence |
|---|---|---|---|
| Free-Trial complete | M5 equity + interval minima, pending-order census, endpoint equity (Prague) | 0 operational defects (rule/governor/identity/execution); inside prediction bands | FTMO-Demo profile identity (`server=FTMO-Demo`), set-file ENV/risk mode, REAL_TICKS model |
| Phase-1 pass | passing equity curve; min-equity vs daily floor (Prague-midnight −5%) and overall floor ($90k) | ≥4 Prague trading days with ≥1 `POSITION_OPENED`; flat-at-target (`positions_open=0`, balance > $110k); no daily/overall breach | per-sleeve SHA256 factory→terminal; magic `ea_id*10000+slot`; set ENV=live/RISK_FIXED=0/RISK_PERCENT; native MT5 news calendar age<336h |
| Phase-2 pass | same, target $105k | ≥4 Prague days; flat-at-target; no breach; Phase-2 (lower-risk) profile respected | re-verify identity for the Phase-2 credentials |
| funded first reward | reward-eligible net P&L reconciliation | replicability (`ftmo_replicable_trading_requirement`); server-request count ≤2000/day | funded-account identity + governor-EA arm state |

All dossiers land under `docs/ops/evidence/` and, for OWNER-signed transitions, `decisions/`. The mark-to-market series is only obtainable from a live demo/funded execution stream (the ABSTAIN reason in `2026-09-05_interval_equity_export.md` and `2026-09-05_ftmo_v4_tail_certification.md`).

---

## 5 · Which actions are OWNER / legal (never AI)

- **Account creation & terminal login** — every FTMO account (demo, Free-Trial, Phase-1, Phase-2, funded). `ftmo_lane_runner` requires a pre-existing `FTMO-Demo` server profile; it does not create accounts.
- **Purchase of a paid Challenge** — `ftmo_owner_purchase_gate` (`owner_signature_required=true`, `automatic_purchase_allowed=false`). **Currently excluded** by the 2026-09-05 blanket release ("Alles, bis auf den Kauf, freigegeben", `decisions/2026-09-02_owner_receipts_ceo_asks.md`).
- **Accepting FTMO Account (funded) terms** — a contract/legal act.
- **Requesting a payout / first Reward** — a financial act in the FTMO client area.
- **AutoTrading toggle** on any FTMO terminal — Hard Rule: OWNER only.
- **Flipping `EXPECTED_STATE` PARKED→RUNNING** — authorizes a live-executing demo; an OWNER decision (the pulse contract is tied to an OWNER decision id, `OWNER-DEC-FTMO-PARK-UNTIL-25-20260825`). The AI implements the code edit only as follow-through of that decision.

**AI-commissionable (read-only / build, under standing authorization):** telemetry capture and monitoring, identity verification, a live-mode FTMO set-generation path (fills Part 2 §B.2 limit 1), T1 swap-export, dossier authoring, drafting the acceptance-test ratification Vorlage.

---

## 6 · Preconditions before any of this is live (dependency chain)

This runbook is dormant until the chain below clears. None of it is a purchase.

1. **Signed deployment pointer** (Part 2 §A.3) — DXZ freeze condition 1. *OWNER.*
2. **Freeze lift or deliberate hold** — all three conditions + written OWNER lift, or an explicit decision to keep the freeze while the pointer stands authenticated (Part 2 §A.1). *OWNER.* **The current signed mint is blocked while the freeze is ACTIVE; this sequence starts only after the separately reviewed ceremony dependency is resolved (Part 2 §A.1).**
3. **Ratified positive-evidence acceptance test** — the `ftmo_free_trial_gate` prediction bands + strict go-criteria set (strict P1 lower-95 ≥ 0.80 with the adequacy/power guards). Exact R5 (`docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`, commit `d9fa021091`, LF SHA-256 `de549514fd75e68adb6f972a39451c89b43d7f7e35961e6e3da197903bfa923d`) was independently reviewed **`RATIFIABLE_AS_PREDECLARED_TEST`** (`2026-09-05_review4_ftmo_positive_evidence_test.md`), and the probability/correlation contract V1 (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md`) is delivered — both **PENDING OWNER ratification** (`no_buy_lift=false`: ratification cannot lift NO-BUY today). *OWNER ratifies.*
4. **Live-mode FTMO set-generation path** — the runner today forbids live risk mode (Part 2 §B.2). *AI build task.*
5. **FTMO demo / Free-Trial account** created + logged in; `EXPECTED_STATE` flipped to RUNNING. *OWNER.*
6. **Defect-free Free-Trial run** captured and scored (`operational_defects_allowed=0`). *AI capture; OWNER-visible verdict.*
7. Only then does a **paid Challenge** become an OWNER decision (`ftmo_owner_purchase_gate`) — and it stays excluded under the current blanket release.

---

## Evidence index

- `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json` — all `rule_id`s cited above; `evaluation_profile.go_criteria` (`ftmo_free_trial_gate`, `ftmo_owner_purchase_gate`); `deployment_boundary` (NOT_IMPLEMENTED / OWNER_ONLY / factory+mt5 not authorized)
- `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` — source snapshot; news/weekend RE_CONFIRMED HTTP 200; trading-symbols URL HTTP 404 → leverage CARRIED_OVER/UNVERIFIED
- `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json` — leverage/swap corroboration (XTI/XAU/USDJPY only)
- `tools/strategy_farm/ftmo_lane_runner.py` — provisioning/runner; FTMO-Demo profile requirement; REAL_TICKS; `NATIVE_SYMBOLS`
- `tools/strategy_farm/ftmo_trial_pulse.py` — observation-only pulse; one-authority tombstone; `EXPECTED_STATE`
- `docs/ops/evidence/2026-09-05_interval_equity_export.md` / `docs/ops/evidence/2026-09-05_ftmo_v4_tail_certification.md` — ABSTAIN: no synchronized intraday minima / endpoint equity / pending-order census
- `docs/ops/evidence/2026-09-05_review4_ftmo_positive_evidence_test.md` — R5 acceptance test reviewed **`RATIFIABLE_AS_PREDECLARED_TEST`** (exact R5 `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`, commit `d9fa021091`, LF SHA-256 `de549514fd75e68adb6f972a39451c89b43d7f7e35961e6e3da197903bfa923d`); OWNER ratification pending
- `docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md` — delivered probability/correlation contract V1 (PENDING OWNER ratification; strict P1 lower-95 ≥ 0.80)
- `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` — Q16 11-check list; deploy/rollback ceremony
- `docs/ops/evidence/2026-09-05_ftmo_readiness_part1.md` / `docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md` — governed attribution + candidate feasibility (Part 1); closure pack + trial design (Part 2)
- `decisions/2026-09-02_owner_receipts_ceo_asks.md` — 2026-09-05 blanket release (purchase excluded)
- `decisions/2026-08-25_owner_hma_requal_ftmo_park_q02_dead16.md` — FTMO PARK-UNTIL-25 decision

*Author: Claude (Factory CEO lane), task 7dceadd0. Evidence-only; no purchase, no MT5 action, no AutoTrading, no runtime integration.*
