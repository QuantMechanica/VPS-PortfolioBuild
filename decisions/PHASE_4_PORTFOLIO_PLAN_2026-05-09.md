---
name: Phase 4 — V5 Portfolio Build Plan
description: CEO plan for Phase 4 (V5 Portfolio Build): EA selection criteria, magic-number scheme, risk allocation, T6 demo sequence prior to LiveOps. Written 2026-05-09 per OWNER directive on QUA-1062. Phase 4 starts when Phase 3 closes (≥1 EA with full P0..P8 + DL-054 PASS + QB G1 verdict).
type: phase-plan
authority: CEO (DL-053 operating contract). OWNER acceptance pending via QUA-1062 → in_review.
date: 2026-05-09
related: QUA-1062 (parent ask), QUA-1066 (CTO P4 Monte Carlo runner readiness), QUA-1067 (Pipeline-Op next-candidate P3 queue), QUA-1068 (Doc-KM episode-pack template), QUA-902 (Phase 3 critical-path P3 FAIL triage), DL-054 (anti-theater PASS criteria), DL-029 (strategy-research workflow)
phase_map_ref: paperclip/governance/PHASE_STATE.md (Phase 4 = "V5 Portfolio Build", closure = "5+ EAs through P0..P8 + first basket")
---

## 1. Scope and trigger

Phase 4 begins **the moment Phase 3 closes** — i.e. when at least one EA has a full P0..P8 chain with a DL-054 PASS at every gate plus a QB G1 verdict on its strategy card. Phase 4 closes when **5+ EAs are simultaneously P0..P8-clean and one production basket is assembled** that meets the gate set in §3.

This plan is forward-looking. It defines **how** the basket gets picked, **how** magic numbers are allocated, **how** risk is split, and **how** the basket is demoed on T6 prior to Phase 5 (Live Deployment). It does **not** preselect specific EAs by id — the actual basket is whichever EAs first satisfy §3 in the order they reach P8.

## 2. Pool of candidates (as of 2026-05-09)

13 EAs are registered in `framework/registry/ea_id_registry.csv`. Lane assignments derive from the strategy cards in `strategy-seeds/cards/` and the source family:

| ea_id | slug                        | strategy_id | lane             | source family |
|-------|-----------------------------|-------------|------------------|---------------|
| 1001  | breakout-atr                | TBD         | Trend / Breakout | proto         |
| 1002  | davey-eu-night              | SRC01_S01   | Session-MR       | Davey         |
| 1003  | davey-baseline-3bar         | SRC01_S03   | Trend / Breakout | Davey         |
| 1004  | davey-es-breakout           | SRC01_S04   | Trend / Breakout | Davey         |
| 1017  | chan-pairs-stat-arb         | SRC02_S01   | Stat-Arb / MR    | Chan          |
| 1009  | lien-fade-double-zeros      | SRC04_S03   | Mean-Reversion   | Lien          |
| 1010  | lien-waiting-deal           | SRC04_S04   | Pullback         | Lien          |
| 1011  | lien-inside-day-breakout    | SRC04_S05   | Trend / Breakout | Lien          |
| 1012  | lien-fader                  | SRC04_S06   | Mean-Reversion   | Lien          |
| 1013  | lien-20day-breakout         | SRC04_S07   | Trend / Breakout | Lien          |
| 1014  | lien-channels               | SRC04_S08   | Channel / MR     | Lien          |
| 1015  | lien-perfect-order          | SRC04_S09   | Trend / MA-stack | Lien          |
| 1016  | lien-carry-trade            | SRC04_S11   | Carry            | Lien          |

Lane buckets used downstream:
- **Trend** = Trend/Breakout, MA-stack: 1001, 1003, 1004, 1011, 1013, 1015 (6)
- **MR**    = Mean-Reversion, Channel, Stat-Arb, Session-MR: 1002, 1009, 1012, 1014, 1017 (5)
- **Other** = Pullback (1010), Carry (1016) (2)

`strategy-seeds/cards/` holds 24+ G0-stage cards that have not yet been promoted into the EA registry. They become candidates only after they are taken to G0 PASS → P0 EA scaffold per DL-029. The basket therefore draws from a pool that grows as Research advances cards through G0/G1.

## 3. Selection criteria (binding gate for inclusion in the first basket)

An EA is **eligible for the first basket** iff every condition holds. There are **no waivers**.

1. **DL-054 PASS at every pipeline gate it has run**: P2, P3, P3.5, P4, P5 (and any P6/P7/P8 active by then). DL-054 means strict NO_REPORT < 5%, no INVALID modal dominance, no phantom-PASS, evidence rooted in real `report.csv`/`summary.json`. See `decisions/DL-054_anti_theater_pass_criteria.md`.
2. **At least one full out-of-sample window has been evaluated** (P5 stability) without modal failure.
3. **Trade-count floor**: ≥ 30 trades in the in-sample baseline window per traded symbol; rejected EAs that PASS only via low-trade-count luck.
4. **QB G1 verdict = PASS** on the underlying strategy card.
5. **Quality-Tech sign-off** on the EA's first sub-gate calibration (DL-053 phase-3 closure criterion carry-over).

Lane-diversity gate for the **basket** (applies on top of per-EA eligibility):

6. **Minimum 3 distinct lanes** in the first basket of 5 EAs (Trend / MR / Other). No lane > 40% of basket weight.
7. **Pairwise correlation of monthly returns ≤ 0.5** between any two EAs in the basket, computed on the longest common in-sample window. EAs running on disjoint symbol sets get a free pass on this rule (pairwise corr undefined → treated as 0 for inclusion).

Tie-break order if more than 5 EAs satisfy 1–7 simultaneously: (a) higher P5 PF, (b) lower P5 max-drawdown-percent, (c) earlier P8 completion timestamp.

This is intentionally strict — the goal of Phase 4 is **not** "5 EAs running" but "5 EAs that demonstrably do not collapse in correlation under stress". DL-054's anti-theater rules are the load-bearing wall here.

## 4. Magic-number strategy

Per memory `feedback_magic_numbers_canonical_scheme.md` and `framework/registry/magic_numbers.csv`: the canonical formula is

    magic = ea_id * 10000 + slot

where `slot` ∈ [0, 9999] is a per-EA portfolio slot index. Slot 0 is the canonical baseline; slots 1..N are reserved for variants (different symbol clusters, different timeframe, different parameter regimes).

Phase 4 binding rules:

- **One slot per (ea_id, magic_purpose) pair.** A purpose is one of: `baseline`, `symbol-cluster-X`, `tf-variant-X`, `regime-X`. Reusing a slot across purposes is forbidden.
- **First-basket convention:** every EA in the first basket runs at **slot 0** (baseline) only. Variant slots (1..N) are reserved for Phase 4 successor baskets.
- **Registry append-only:** every (ea_id, slot, purpose, deploy_target) tuple is logged in `framework/registry/magic_numbers.csv` before the EA is launched on T6. Pipeline-Op owns this registry; CEO ratifies.
- **Magic-number collisions are R-046-class.** A duplicate active magic across deployed EAs is a Class-2 escalation per `processes/12-board-escalation.md`.
- **Capacity:** 10000 slots × 10 EAs in registry = 100k unique magics within Phase 4's expected envelope. No risk of namespace pressure for at least the next 12 months.

Cross-link: `framework/registry/REGISTRY.md` documents the scheme; this plan is the binding policy for Phase 4 application.

## 5. Risk allocation

Phase 4 ships a **V0 (equal-weight) allocator** and documents the path to V1 (vol-targeted).

### V0 — equal-risk-per-slot (Phase 4 default)

Each EA in the basket gets `1/N` of the basket risk budget. With N = 5 → 20% per EA. The allocator unit is **risk-per-trade** at the EA level, not capital — i.e. each EA sizes its lots so that one stop loss on its canonical setup costs 1/N of the basket's per-trade risk envelope.

Concretely, with a basket per-trade risk envelope of `R` (set by CEO in deploy manifest, capped by T6 broker rules):

    risk_per_trade(EA_i) = R / N
    lots(EA_i, symbol) = risk_per_trade(EA_i) / (stop_distance_pips × pip_value(symbol))

This gives **equal expected-loss-per-trade** across EAs, which is the right invariant when correlations are unknown or estimated noisily on short Phase-3 windows. It deliberately **does not** scale by realized PF or expectancy — that opens a late-stage overfit door we want closed for the demo.

### V0 sizing parameters (basket-level defaults)

- `R` (basket risk per simultaneous-open trade) = **0.5%** of demo equity. With N = 5 simultaneous opens, basket exposure peaks at 2.5% — comfortably inside FTMO/5ers/DXZ blackouts and broker-of-record rules. CEO can dial this down per deploy manifest; never up without OWNER ratification.
- `max_concurrent_open_trades_per_ea` = 1 for the first basket. Multi-open is a Phase-4-V1 enhancement.
- `max_basket_concurrent_open` = N (one per EA). Net basket gross exposure capped at 5 × R = 2.5%.

### V1 — vol-targeted (Phase 4 successor; not blocking the first basket)

Once 8+ weeks of demo data exist with stable per-EA vols, the allocator switches to:

    weight(EA_i) = (1 / sigma_i) / sum(1 / sigma_j)

with `sigma_i` = trailing 60-day daily-PnL stdev of the EA's slot-0 line. V1 keeps the same `R` envelope but reweights toward steadier sleeves. **Not in scope for the first basket.** Documented here so the engineering plan does not have to retro-fit it.

### Hard caps (binding for V0 and V1)

- Basket gross exposure ≤ 25% of equity. (T6 demo accounts are not capital-constrained at our test sizes; this cap is a behavioral guard, not a margin guard.)
- Per-EA daily PnL drawdown trip = -2 × R basket-units → CEO-flag, halt that EA's slot, post to T6 watch issue.
- Basket-level daily PnL drawdown trip = -2.5 × R basket-units → halt full basket, OWNER notification.
- `framework/registry/token_budget.json` cap structure mirrors here; deploy manifest declares both.

## 6. T6 demo sequence (binding pre-LiveOps gate)

Phase 4 closes only when the first basket has cleared a 4-step T6 demo sequence in this exact order. **Each step must produce signed evidence in `evidence/t6_demo/<step>_<basket_id>.md` before the next step begins.**

| Step | Scope                                          | Duration | Pass criterion                                                                                              | Owner       |
|------|------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------|-------------|
| D0   | Single-EA / single-symbol / 1 lot (smoke)      | 24h      | 0 magic collisions; 0 connection drops > 5min; ≥ 1 trade fired; report.csv produced; DL-054 modal == clean | Pipeline-Op |
| D1   | Single-EA / full-card-symbols / V0 lots        | 72h      | NO_REPORT < 5%; per-EA daily PnL inside expected band (P5 sigma × ±2); no R-046 violations                  | Pipeline-Op |
| D2   | Full basket / 1 lot per EA / open-and-close    | 7 days   | All 5 EAs trade ≥ once; pairwise correlation of daily PnL ≤ 0.5; basket gross exposure cap respected        | CTO + PO    |
| D3   | Full basket / V0 sizing / open-and-close       | 7 days   | DL-054 PASS at basket level; no halt-trips; no manual interventions; episode-pack (QUA-1068) emitted clean  | CTO + PO    |

After D3 PASS:

- CEO writes acceptance memo (next-day decisions/ entry).
- OWNER reviews + ratifies.
- Phase 4 closes, Phase 5 (Live Deployment on T6) opens with the same basket as the seed live sleeve.

If any step FAILS:

- Step rolls back to its predecessor.
- A blocker issue is filed against the responsible owner.
- Demo timer restarts at the failing step (no skip-ahead, no waiver).

## 7. Phase 4 dependencies and dispatched lanes (status 2026-05-09)

Three non-blocking parallel lanes were dispatched 2026-05-09 from QUA-1062. Each is a Phase-4-prep deliverable; all are non-critical-path relative to Phase 3 closure (QM5_1003 P3 FAIL triage, QUA-902).

- **QUA-1066 — CTO `241ccf3c`** — P4 Monte Carlo runner readiness. Acceptance: `framework/scripts/p4_montecarlo.py` runs end-to-end on a P3-PASS EA, emits a `report.csv` with N_trials, modal NO_REPORT < 5%, DL-054-compliant fields. Required before any EA can clear P4 in this plan's §3.1 PASS gate.
- **QUA-1067 — Pipeline-Op `46fc11e5`** — Next-candidate P3 queue. Acceptance: top-3 forward-compatible cards staged at P3 entry behind QM5_1003. Required so the Phase-3-to-4 funnel does not stall on a single-EA waterfall. (Lane B already shipped queue commit `d3a7c80` 2026-05-09.)
- **QUA-1068 — Doc-KM `8c85f83f`** — Episode-pack template. Acceptance: rendering template + first dry-run output for a Phase-3-PASS EA, ready to drop into D3 of the demo sequence. Phase 6 (Public Dashboard) consumes the same artifact.

Phase 3 critical path is **unchanged** by this plan. The plan describes what happens *after* Phase 3 closes; it does not pull anyone off the QM5_1003 P3 FAIL triage.

## 8. Open questions (carry to OWNER review on QUA-1062)

1. **Demo equity size for D0..D3.** Need a number to pin into `R = 0.5% × equity`. CEO recommendation: **$10k notional demo** to keep V0 lot sizes meaningful but inside FTMO/5ers blackouts. OWNER override welcome.
2. **Broker-of-record for the demo.** Current default is the same broker-of-record as Phase 3 P-runs (DWX-suffixed symbols). Confirm before D0.
3. **Episode-pack publication cadence.** D3 emits one pack per day per EA (5/day at basket scale); confirm Phase 6 dashboard ingests at this rate without throttling Anthropic-Subscription-Week budget (ratified Subscription Guardian thresholds: 80/90/95).

## 9. Acceptance for this plan

Acceptance gates per OWNER ask (QUA-1062 wake comment 2026-05-09T09:11Z):

- [x] Plan committed to `decisions/PHASE_4_PORTFOLIO_PLAN_2026-05-09.md` (this file).
- [x] Subscription Guardian spec ratified — QUA-1062 comment `68ed82b4` (2026-05-09T09:15Z), cross-ref on QUA-1032 comment `12424fe3`.
- [x] QUA-1062 status PATCHed → `in_review` for OWNER acceptance.
- [ ] OWNER review + ratification.

When OWNER accepts, this becomes the binding Phase 4 contract. Until then it is a CEO proposal in_review.
