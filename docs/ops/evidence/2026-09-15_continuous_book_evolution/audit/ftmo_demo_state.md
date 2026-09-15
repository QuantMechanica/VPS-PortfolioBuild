# FTMO Demo State — Phase A audit (read-only)

Directive §11–§17, §62, §63, §68F. Auditor: read-only board-advisor. Date 2026-09-15.
Source directive: `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md`.

## Headline

1. One FTMO demo terminal is live now (PID 10836, `C:\Program Files\FTMO Global Markets MT5 Terminal`, account **1514536732** on **FTMO-Demo**, a 2-Step / 100k **Standard** Free-Trial, 1:100). It runs 8 DXZ-derived trading sleeves at RISK_PERCENT 0.3125 / RISK_FIXED 0 plus an account-governor EA and a telemetry EA; AutoTrading is effectively ON (equity 99,811.51, one pending order, 8 magics active), and the trial pulse verdict is WARN (only benign kill-switch-marker gaps). This is the **explorative "M13" capture, not a frozen intended-challenge portfolio**.
2. The planned **FTMO demo book v2** (Book-Sprint F4 / decision F3 = the 28-sleeve DXZ v2 roster remapped onto FTMO broker symbols, sha-bound, no rebuild, no qualification claim) exists only as a **read-only admission census (24 ADMIT / 4 EXCLUDE)**; its ticket **42a437a4** is IN_PROGRESS under a RECYCLE→merge after a duplicate-session collision and has not been deployed.
3. The freshest official FTMO rule snapshot is **11 days old (2026-09-04, its own max age is 7)**, is labelled **Swing while the demo account is Standard**, and is missing two §63 fields (instrument/symbol restriction list — the page 404'd; and provider leverage for the intended profile — swing values carried-over/unverified). The honest bottleneck TODAY is **evidence/definition, not compute**: no rule-faithful representative 2-week demo of a frozen challenge book has been run, and FTMO_FITNESS (first-passage / breach probability) has not been computed for any admitted pool.

## Findings

### 1. The FTMO demo terminal, what runs on it, since when, AutoTrading, history access

**1.1 Terminal + account.** Non-portable FTMO install at `C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe`, data dir `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850`. Running now as PID 10836 (evidence: `Get-Process terminal64`, session 1). Login **1514536732**, server **FTMO-Demo**, profile `Default` (evidence: `…/81A933…/config/common.ini` → `Login=1514536732`, `Server=FTMO-Demo`, `ProfileLast=Default`, `NewsEnable=1`). Account is a Free-Trial **2-Step / USD 100,000 / account type "FTMO" (Standard, NOT Swing)**, leverage **1:100** confirmed by read-only IPC (evidence: `docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md`).

**1.2 What runs (profile `Default`, 11 charts).** Parsed from `…/81A933…/MQL5/Profiles/Charts/Default/chart*.chr` (UTF-16), each `expertmode=1`, `RISK_FIXED=0`:

| chart | symbol | EA | ea_id | slot | magic (ea*10000+slot) | RISK_PERCENT |
|---|---|---|---|---|---|---|
| 01 | EURUSD | QM5_13206_ftmo-account-governor | 13206 | – | – | (risk manager) |
| 02 | GBPUSD | QM5_10706_tv-mon-ls | 10706 | 1 | 107060001 | 0.3125 |
| 03 | EURUSD | QM5_11421_ohlc-daily-squeeze-reversal-d1 | 11421 | 0 | 114210000 | 0.3125 |
| 04 | USDCAD | QM5_11422_williams-18ma-outside-bar-entry-d1 | 11422 | 4 | 114220004 | 0.3125 |
| 05 | NZDUSD | QM5_11910_larry-williams-18ma-2outside-bars-d1 | 11910 | 6 | 119100006 | 0.3125 |
| 06 | USOIL.cash | QM5_13054_brent-tom-mom | 13054 | 0 | 130540000 | 0.3125 |
| 07 | USOIL.cash | QM5_20048_wti-preholiday | 20048 | 0 | 200480000 | 0.3125 |
| 08 | XAGUSD | QM5_1537_aa-vol-sma10 | 1537 | 1 | 15370001 | 0.3125 |
| 09 | XAGUSD | QM5_21505_xag-weekly-lowvol-momentum | 21505 | 0 | 215050000 | 0.3125 |
| 10 | EURUSD | QM_FTMO_TrialTelemetry | – | – | – | (telemetry) |
| 11 | EURUSD | (none) | – | – | – | empty |

So: **8 trading sleeves + 1 account-governor + 1 telemetry**. Aggregate nominal risk ≈ 8×0.3125 = 2.5%. The 8 magics equal the FTMO governor's allowed set exactly (evidence: `roster_ftmo_demo_v2.json → governor_allowed_magics` = 15370001,107060001,114210000,114220004,119100006,130540000,200480000,215050000). Binaries in `…/81A933…/MQL5/Experts/QM_FTMO/`. All sleeves are DXZ-derived D1/weekly swing/momentum — **none purpose-built for FTMO** (relevant to §16–§19).

**1.3 Since when.** FTMO terminal first started manually 2026-07-05; OWNER ratified state RUNNING on 2026-08-06 (bounded, review expires **2026-09-30**) (evidence: `tools/strategy_farm/FTMO_ON.ps1` header). The current M13 Standard Free-Trial instrumentation profile was installed ~**2026-09-06** (evidence: telemetry dir `…/MQL5/Files/QM/ftmo_trial/2026-09-06`; account terms doc 2026-09-06; chart files last written 2026-09-11 21:45). The 14-day trial window per FTMO runs from the first trade, then FTMO deactivates the account (evidence: account terms doc).

**1.4 AutoTrading is effectively ON now.** `D:/QM/reports/state/ftmo_trial_pulse.json` (checked_at 2026-09-15T12:19:54Z, file mtime 14:22 local): `effective_state=RUNNING`, `expected_state=RUNNING`, `expected_state_condition=ok`, `equity=99811.51` (down from 100k start → `total_dd_pct≈0.19`), `day_pnl=0.0`, `open_positions=0`, `pending_orders=1`, `magics_seen=8/8`, `verdict=WARN`, `alarms=[]`, `warns=[ks_day_anchor_missing:0/8, ks_book_tag_missing:0/8]`. The pulse asserts AutoTrading state matches the baked RUNNING state (evidence: `ftmo_trial_pulse.py` docstring check 1). Equity below start + a resting pending order + 8 active magics confirm trading has occurred. **AutoTrading toggling remains OWNER-only** (HR: T_Live/AutoTrading = OWNER); no AI seat may flip it.

**1.5 How demo trade history is read (read-only).**
- Per-magic EA logs `…/81A933…/MQL5/Files/QM/QM5_<id>_ea-<id>.log` (EQUITY_SNAPSHOT, MONTHLY_SLEEVE_STATE events).
- Trial telemetry dir `…/MQL5/Files/QM/ftmo_trial/YYYY-MM-DD` + `ftmo_trial_collector` (equity_source `ftmo_trial_collector_raw`).
- Health monitor `tools/strategy_farm/ftmo_trial_pulse.py` (task `QM_FTMO_TrialPulse`, 30 min) → `D:/QM/reports/state/ftmo_trial_pulse.json`.
- Read-only MT5 Python IPC against the already-running process (no start/attach/trade).
- Price (not trade) history: `D:/QM/mt5/FTMO_STREAM1|2/Bases/FTMO-Demo/ticks/<symbol>`.

### 2. Planned FTMO demo book v2 and its status

**Definition (Book-Sprint F4, decision F3):** FTMO demo book v2 = the **DXZ v2 roster (28 sleeves)** remapped onto FTMO broker symbol names, **same sha-bound binaries, no rebuild, no qualification claim**; a burn-in deployment on the demo terminal (account 1514536732). Evidence: `docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/README.md`; tool `tools/strategy_farm/ftmo_demo_v2_census.py`; roster `…/roster_ftmo_demo_v2.json`.

**Census result:** 28 sleeves → **24 ADMIT / 4 EXCLUDE**. Excludes are evidence-bound (e.g. ea 11132 SP500.DWX → `ftmo_symbol=UNVERIFIED`). Symbol sources: alias registry `FTMO_TRIAL`, native capture 2026-09-06, ftmo ticks dir 1514536732, or unverified. Symbol remaps include WS30.DWX→US30.cash, NDX.DWX→US100.cash, GDAXI.DWX→GER40.cash, XTIUSD.DWX→USOIL.cash. `magic_collision=false` for all; governor input deltas are **PROPOSAL ONLY, applied nowhere**.

**Status: NOT deployed; ticket stalled.** `agent_tasks` (read-only): task **42a437a4-9674-47ce-9ca9-80eba8a2bc91** (ops_issue, prio 78, agent claude) state **IN_PROGRESS**, verdict `RECYCLE → merge instruction (orchestrator 2026-09-15 10:4xZ). Two sessions worked this ticket (COLLISION.md, --max-sessions 3 race)`, artifact `…/slot1_census_v2/README_slot1.md`; due Wed **2026-09-17 18:00Z**. Companion task **3e0c8b83-90d7-45b5-8780-fcf3460e44d6** (session-pin fix, prio 74) also IN_PROGRESS. So the v2 book exists as a merged census draft; deployment/profile-copy plan is downstream and unbuilt.

### 3. FTMO rule snapshot in the repo — freshness and §63 gaps

**Freshest snapshot:** `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`, `retrieved_at_utc=2026-09-04T02:10:47Z`, `freshness_max_age_days=7`, raw bodies retained under `docs/ops/evidence/ftmo_fetch_20260904/`, 8 official pages fetched, 28/30 claims re-confirmed. Prior snapshots: 2026-07-29, 2026-08-23, 2026-09-02. Bound into rulepacks `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_{STANDARD,SWING}_V2.json` (snapshot sha256 `c199b8f5…d2905`), lifecycle `RESEARCH_CONTRACT_ONLY`, `deployment_boundary=NOT_IMPLEMENTED`.

**Fields §63 requires that ARE present** (from `normalized_claims` / STANDARD_V2 `official_rules`): account type (2-Step), account size (100k), targets (P1 10% / Verification 5%, strictly-greater-while-flat), daily loss (5% of initial, Prague midnight balance − fixed amount, equity incl. open PnL/swap/commission, strictly-below), max loss (10% static from initial, strictly-below), trading-day requirement (≥4 Prague days with ≥1 position opened), news rule (Standard funded restriction; **exempt during Evaluation**; ±2 min around targeted releases), overnight/weekend rule (Standard funded; exempt during Evaluation; close before weekend / >2h break), EA + server limits (200 simultaneous orders, 2000 positions/day hyperactive threshold), replicability requirement, economics (540 fee, 100% refund w/ first reward, 80→90% split, 25%/4-month scaling).

**Fields §63 requires that are MISSING or not decision-grade:**
- **Instrument / symbol restrictions:** GAP. `https://ftmo.com/en/trading-symbols/` returned **HTTP 404 with no body** on 2026-09-04 (evidence: snapshot `dead_sources_2026_09_04`, `retrieval_method`). No official tradable-instrument / restriction list captured.
- **Leverage for the intended profile:** weak. Only Swing leverages are in the snapshot (fx 1:30, metals/oil 1:15) and both are `CARRIED_OVER` + **unverified as of 2026-09-04** (`claim_reconfirmation_summary.carried_over_claims`, `scope_limit`). No official **Standard-account** provider leverage. The only Standard figure is the **observed demo-account 1:100** (account-bound evidence, explicitly "not a provider rule", `2026-09-06_ftmo_demo_account_terms.md`).
- **Freshness:** the snapshot is **11 days old** on 2026-09-15, exceeding its own 7-day `freshness_max_age_days` and the rulepack go-criterion `ftmo_rule_snapshot_fresh (maximum_age_days:7)`. §63 "do not rely indefinitely on an old rule snapshot" is currently breached for any purchase decision.

### 4. FTMO evaluation tooling (paths + required inputs)

- **FUND_SCORE:** `tools/strategy_farm/portfolio/fund_score.py` (wraps `challenge_book_60d.py`); surface `farmctl.py fund-score --ea .. --symbol ..`; cache `D:/QM/strategy_farm/artifacts/portfolio/fund_scores.json`; screening-only, `gate_override_allowed:false`. Inputs: per-sleeve trade/daily streams → med60, worst-day, wDD-p90. Doc `docs/ops/evidence/2026-07-27_fund_score_gate.md`.
- **First-passage:** `tools/strategy_farm/portfolio/challenge_firstpassage.py` (+ `ftmo_p1_mc.py`, `challenge_two_phase.py`, `prop_challenge_sim.py`, `prop_challenge_optimizer.py`, `challenge_as_deployed.py`). Two-barrier model: P(+10% balance before −5% any day / −10% total, **no deadline** — FTMO removed the max period). Inputs: per-sleeve return/equity streams, **native FTMO costs** (spread/commission/swap/margin), Prague day anchors, **intratrade mark-to-market equity**. Doc `docs/ops/evidence/2026-07-27_ftmo_first_passage_measurement.md`.
- **Density:** `tools/strategy_farm/portfolio/ftmo_density_compare.py`, `ftmo_density_speed_at_budget.py`; trade-density / activity-criterion inputs (entry-day counts). Related: `analyze_ftmo_costs.py`, `ftmo_c6_estimator.py`.
- **Admission gate (Q10 FTMO recommendation):** `tools/strategy_farm/portfolio/ftmo_q09_admission.py` (fail-closed: needs a 7×1 FTMO-targeted matrix or a complete 7×4 matrix containing a viable FTMO config; a DXZ-scoped lock returns `FTMO_Q09_SCOPE_NOT_FTMO`); presentation projector `q09_ftmo_recommendation.py`; census harness `ftmo_admission_census.py`.
- **Rules engine / contracts:** `portfolio/ftmo_rules_engine.py`, `ftmo_rule_contract.py`, `ftmo_probability_contract.py`; rulepacks under `config/target_rulepacks/`.
- **Readiness:** `portfolio/ftmo_book_readiness.py`, `validate_ftmo_readiness_part1.py`.
- Go-criteria thresholds (rulepack STANDARD_V2 `evaluation_profile.go_criteria`): Phase-1 pass ≥80% point / ≥70% lower-95; Phase-2 conditional ≥85%; joint ≥65%; breach upper-95 ≤10%; ≥1 defect-free Free-Trial/shadow run; **OWNER signature required, no automatic purchase**.

### 5. The honest FTMO bottleneck TODAY (not the August answer)

**Primary — evidence + definition (not compute):** there is **no frozen "intended challenge portfolio" that has completed a representative, rule-faithful 2-week demo** (directive §12). What runs now is 8 DXZ-derived M13 sleeves at 0.3125% each, which the acceleration doc itself calls **explorative** ("Der laufende M13-Capture bleibt explorativ"). No **FTMO_FITNESS** (first-passage pass probability, breach probability, joint two-phase probability) has been computed against the go-criteria for any admitted pool. The tooling in Finding 4 exists but has never produced a decision-grade dossier for a specific frozen book.

**Secondary — economic:** on the 2026-09-09 intake, **0 of 16** contiguous Q14 pairs passed FTMO's own admission gate (12 had DXZ-scoped evidence without FTMO scope, 3 missing, 1 not CONFIG_LOCKED) (evidence: `docs/ops/FTMO_ACCELERATION_2026-09-09.md`, `evidence/2026-09-09_ftmo_acceleration/intake.json`). Zero admissions is a **symptom of missing FTMO-scoped evidence**, not proof of zero edge. The directive now permits scalping / trailing / FTMO-specific strategies (§16–§19), yet the demo book contains **none purpose-built for first-passage** — the genuine economic gap.

**Operational (fixable, not the root):** the v2-book census path is stalled on a duplicate-session RECYCLE (ticket 42a437a4); the rule snapshot is stale (11 d); the snapshot profile (Swing) does not match the account (Standard).

**Not the bottleneck:** terminal uptime (running, WARN only), and MT5 compute. The August "cost-admission triage / 0 FTMO admissions" framing is a symptom; the root today is that FTMO fitness is **undefined and uncomputed for a frozen book**, and no representative sealed demo cycle exists.

## Drift table

| Topic | Doc/vault says | Runtime says | Path |
|---|---|---|---|
| FTMO demo account | `FTMO_ON.ps1` header: account **1514165262**, profile Default | login **1514536732** (FTMO-Demo) | `tools/strategy_farm/FTMO_ON.ps1` L59 vs `…/81A933…/config/common.ini`, `ftmo_trial_pulse.json` |
| AutoTrading | account terms 2026-09-06: "AutoTrading **OFF**" (at install) | effective_state RUNNING, equity 99,811.51 (moved), 1 pending order, 8 magics → **ON now** (OWNER-enabled since) | `docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md` vs `D:/QM/reports/state/ftmo_trial_pulse.json` |
| Rule-snapshot profile | snapshot top-level `profile = "Swing"` | demo account = **Standard** ("FTMO", not Swing) | `2026-09-04_ftmo_official_rules_snapshot.json` vs `2026-09-06_ftmo_demo_account_terms.md` |
| Rule-snapshot freshness | snapshot `freshness_max_age_days=7`; go-criterion max 7 d | **11 days** old on 2026-09-15 → stale for purchase | `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` |
| Instrument restrictions | §63 requires a bound instrument-restriction list | trading-symbols page **404, no body** captured 2026-09-04 | snapshot `dead_sources_2026_09_04` |
| Provider leverage | §63 requires bound leverage | swing values carried-over/**unverified**; no Standard provider leverage; only observed demo 1:100 | snapshot `claim_reconfirmation_summary`, `scope_limit` |
| FTMO state approval | `FTMO_ON.ps1`: RUNNING approval **review expires 2026-09-30** | still RUNNING; review window closes in 15 days | `tools/strategy_farm/FTMO_ON.ps1` |

## Open questions strictly requiring OWNER

None new that block Phase B–H reconnaissance. (Purchase, AutoTrading, and account provisioning are already OWNER-only by directive §64 and the Hard Rules; the two-week validation start date on a frozen book is a Fable decision under §12, not an OWNER gate.)

## Recommended actions for the implementing phases (Phase F and adjacent)

1. **Refresh + hash-bind the FTMO rule snapshot for the Standard profile** and repair the two gaps: re-fetch `trading-symbols` (or the current instrument-restriction source) and source official Standard-account leverage. New file `docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json`; rebind `config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json` (bump `as_of`, snapshot sha, `go_criteria.ftmo_rule_snapshot_fresh`).
2. **Define and freeze one intended challenge portfolio** (§12/§57). Decide: promote the demo-book-v2 24-ADMIT roster, or a smaller purpose-built FTMO subset. Land it in `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` (durable output §69) with the frozen roster + risk + execution policy.
3. **Compute FTMO_FITNESS for that frozen book** using existing tooling — `portfolio/challenge_firstpassage.py` + `challenge_two_phase.py` + `fund_score.py` + `ftmo_density_compare.py` — against STANDARD_V2 go-criteria; write the dossier under `docs/ops/FTMO_CHALLENGE_READINESS.md` (§62/§69).
4. **Unblock the v2 census ticket 42a437a4** (merge slot-1 v2 + slot-3 reconciliation per the RECYCLE instruction) and land the companion session-pin fix 3e0c8b83; then produce the profile/copy deploy plan (still OWNER-gated, no AutoTrading).
5. **Start the mandatory representative 2-week demo (§12)** on the frozen book once fitness is decision-grade; instrument sleeve-level metrics per §16 into `ftmo_trial_pulse.py` / the telemetry collector.
6. **Commission Kimi FTMO-gap research (§47, Phase F/G):** what mechanical edge (scalping / short-hold / low-swap / high-density) the current all-DXZ book is missing — the secondary-economic gap identified above.
7. **Fix stale metadata:** correct `FTMO_ON.ps1` account comment (1514165262→1514536732) and reconcile the AutoTrading-state note in `2026-09-06_ftmo_demo_account_terms.md`; refresh the RUNNING-state review before 2026-09-30.
