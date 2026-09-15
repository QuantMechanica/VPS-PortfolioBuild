# Mission Control / Cockpit / Morning Briefing / OWNER Counter — Implementation Audit

Task: `mission_control_briefing` (Directive §3, §60, §62, §68D). Read-only.
Report authored 2026-09-15. Evidence paths are absolute or repo-relative from `C:/QM/repo`.

## Headline

1. The **primary Mission Control surface is `render_cockpit_v2.py`** (data model `mission_control_v2_data.build_contract`), which writes `D:\QM\strategy_farm\dashboards\cockpit.html` + `cockpit_v2.html`; it is driven by legacy `render_cockpit.py` (task `QM_StrategyFarm_Cockpit_2min`, every 2 min) which also emits the Advanced/legacy `cockpit_advanced.html`. The "Way to 25" goal is live on **three** surfaces today: cockpit v2 section "Weg zu 25", morning-brief section 3 "WEG ZU 25", and the shared compute in `path_to_25.py` — all keyed on a hardcoded `/25`.
2. There is **no Book Evolution, FTMO Challenge Readiness, or Research section anywhere yet**; the only FTMO-flavoured widget is `_render_q09_ftmo_recommendation` (a Q09-admission census, not a book/demo view). The data those §60/§62 sections need already exists as JSON read-models (`live_book_pulse.json`, `ftmo_trial_pulse.json`, `live_risk_freeze.json`, `live_sleeve_drift.json`) plus a large `tools/strategy_farm/portfolio/` engine — but none is wired into the v2 contract.
3. The "Entscheidungsschlange" is the **Owner Decision Queue**: feed `D:\QM\reports\state\owner_decisions.json` (`owner_decision_store.py`, seed `config/owner_decisions.v2.bootstrap.json`), loopback intake `owner_decision_service.py`, rendered by `_render_owner_decisions` (OPEN/DEFERRED only; DECIDED archived to Vault). Phase D can add sections without touching that machinery.

## Findings

### F1 — Primary cockpit renderer and output paths
- `tools/strategy_farm/render_cockpit_v2.py` is the **primary** Mission Control page ("MC-v2 primär seit OWNER-Abnahme 2026-08-21"). `render()` at line 1744 assembles the body in this order (line 1768-1778): `_render_control_strip`, `_render_owner_todos`, `_render_risk_freeze`, `_render_path_to_25`, `_render_q09_ftmo_recommendation`, `_render_owner_decisions`, `_render_progress`, `_render_terminals`, `_render_queue`.
- Output paths: `OUTPUT_PATH = D:\QM\strategy_farm\dashboards\cockpit.html`, `ALIAS_PATH = …\cockpit_v2.html` (render_cockpit_v2.py:82-83). Also writes `cockpit_stamp.json` (5 s self-refresh poller) and `linear_frontier.html` (operator drill-down).
- The renderer makes "zero data decisions": it imports `build_contract` from `mission_control_v2_data` and binds fields verbatim (render_cockpit_v2.py:1-27, 46-63). Design spec cited: `docs/ops/MISSION_CONTROL_V2_RENDER_SPEC.md`.
- Evidence: `tools/strategy_farm/render_cockpit_v2.py:82`, `:1744-1820`.

### F2 — Legacy cockpit and the actual scheduled task
- `tools/strategy_farm/render_cockpit.py` (5393 lines) writes `COCKPIT = …\cockpit_advanced.html` ("legacy layout -> Advanced", render_cockpit.py:96) and then **invokes `render_cockpit_v2.main([])`** in-process (render_cockpit.py:4291-4318, with one retry and non-zero surfacing on failure).
- The scheduled task **`QM_StrategyFarm_Cockpit_2min`** runs `pythonw.exe "C:\QM\repo\tools\strategy_farm\render_cockpit.py"` (verified via `schtasks /query /tn QM_StrategyFarm_Cockpit_2min /xml`). So one 2-min task produces both the Advanced page and the primary MC-v2 page.
- Evidence: `render_cockpit.py:96`, `:4291-4318`; `schtasks` XML for `QM_StrategyFarm_Cockpit_2min`.

### F3 — Data model and its sources
- `tools/strategy_farm/mission_control_v2_data.py::build_contract` (line 1291) is the single data authority. Sources:
  - `farm_state.sqlite` via `_connect_ro` (line 326) → `build_terminals`, `build_progress`, `build_queue`, `build_q09_autoseal_holds`, `q09_ftmo_recommendation.collect`, `build_owner_decisions`, `build_control_strip`.
  - `operator_surfaces.build_operator_snapshot(db)` → provides the **`path_to_25`** sub-model (build_contract line 1323-1326).
  - `risk_freeze.diff_against_baseline` → `build_risk_freeze` (line 1260), reads `D:\QM\reports\state\live_risk_freeze.json` (RISK_FREEZE_STATE line 87).
  - `_load_live_observability` (line 1247) reads `D:\QM\reports\state\live_book_pulse.json` (LIVE_BOOK_PULSE_STATE line 86).
  - OWNER decisions feed `D:\QM\reports\state\owner_decisions.json` (OWNER_DECISIONS_FILE line 93), health `…\health.json` (line 90).
- Returned contract keys (line 1328-1343): `schema_version, generated_at, source_db, live_observability, risk_freeze, control_strip, queue, q09_autoseal_holds, q09_ftmo_recommendation, progress, terminals, owner_decisions, operator_surface, path_to_25`.
- Evidence: `tools/strategy_farm/mission_control_v2_data.py:84-93, 326, 1247-1343`.

### F4 — The OWNER counter ("Way to 25") is a first-class widget on all three surfaces
- Compute: `tools/strategy_farm/path_to_25.py::path_to_25_metrics(DB)` (line 670) returns a dict with `qualified_pairs, distinct_eas, families, eta_days` (and `eta_to_25`), `frontier_histogram`, `news_gate`, `opt_fork` (Q12/Q13/Q14 pending/done + `terminal_verdicts`), `backfill`, `committed_work`, `reservoir`, `completion_rates`, `counting_definition` (sealed by an OWNER decision, `path_to_25.py:617`), `pair_progress`. The `>=25` semantic is baked in ("Für den >=25-Trigger zählt …", path_to_25.py:617).
- Cockpit v2: `_render_path_to_25` (render_cockpit_v2.py:880) → section title **"Weg zu 25"**, headline `<qualified_pairs>/25` (line 995), "ETA zu 25", "Q09-Reservoir", "Frontier", "Committed", Q10/Opt-Fork/rates tables, pair table.
- Morning brief: `render_path_to_25_section` (morning_brief.py:1278) → **"Weg zu 25"** with `/25` (morning_brief.py:1307); also `render_text` section "WEG ZU 25" (morning_brief.py:1614). Fed by `path_to_25()` (morning_brief.py:980) which calls the same `path_to_25_metrics`.
- Directive conflict: §3 orders "Way to 25" removed as a business target from Mission Control, Morning Briefing and current dashboards; §60 orders the cockpit section replaced by Book Evolution; candidate counts may remain as diagnostics only. Historical records must be marked superseded, not deleted (§3).
- Evidence: `path_to_25.py:617, 670, 882`; `render_cockpit_v2.py:880-1064`; `morning_brief.py:980, 1278-1327, 1614`.

### F5 — Morning briefing (06:00 mail) implementation
- `tools/strategy_farm/morning_brief.py` is the single daily 06:00 mail. Task **`QM_MorningBriefing_Vault`** runs `python …\morning_brief.py` (schtasks XML confirmed). It renders a paper-light inline-CSS HTML digest, sends exactly ONE mail via the gmail_alarm SMTP path (creds in `.private/secrets/`), and archives to the Drive Vault. `--dry-run` renders without send/vault-write.
- Seven sections (morning_brief.py:12-27): 1 LIVE-BUCH·Nachtbilanz (DXZ Final-24 + FTMO status line), 2 FRONTIER·Kandidaten, **3 WEG ZU 25**, 4 FACTORY-AMPEL, 5 OWNER-ENTSCHEIDUNGEN, 6 QUOTA (Woche), 7 OPS-HEARTBEATS.
- FTMO/DXZ state used by section 1: `FTMO_PULSE_STATE = …\ftmo_trial_pulse.json` (line 112), `DDGUARD_STATE = …\live_book_dd_guard_state.json` (line 113); watchdog lamps track `T_LIVE`(=DXZ) and `FTMO` sessions.
- `notion_morning_brief.py` is an **opt-in marketing copy** (scrubbed) that publishes `D:/QM/strategy_farm/dashboards/morning_brief.md` to Notion; dry-run never opens network. Not the canonical surface.
- Evidence: `morning_brief.py:1-38, 88, 112-113, 1330-1388, 1738`; `notion_morning_brief.py:1-18`.

### F6 — Heartbeat snapshot
- `tools/strategy_farm/heartbeat_snapshot.py` (task **`QM_Orchestrator_Heartbeat_15min`**) is a read-only 15-min digest. Writes `D:\QM\reports\state\heartbeat.md` + `heartbeat_state.json` + `heartbeat_events.jsonl` and mirrors to Vault `G:/…/08 Current State/Heartbeat.md` (heartbeat_snapshot.py:365-370). It reuses `operator_surfaces.build_operator_snapshot` (same source as path_to_25) and reads quota state. It is a FLAGS-only surface, not a place the §60 book sections belong (but its measurements can feed a weekly digest).
- Evidence: `heartbeat_snapshot.py:40-46, 365-370`; schtasks XML.

### F7 — Owner Decision Queue ("Entscheidungsschlange") mechanism
- Store: `tools/strategy_farm/owner_decision_store.py` — feed `D:\QM\reports\state\owner_decisions.json` (DEFAULT_FEED line 35), receipts `owner_decision_receipts.jsonl` (line 36), bootstrap seed `config/owner_decisions.v2.bootstrap.json` (line 37). Each item is validated (`_validate_item` line 107) and carries a `decision_card_sha256` binding (line 86-102). `render_vault_queue`/`render_vault_decided` produce the Vault mirror pages.
- Card production: cards are authored by session tools under `tools/strategy_farm/session_tools/*card*.py` (e.g. `dsr_declaration_card_0906.py`, `counter_path_calendar_card_0907.py`) and by the bootstrap seed; they are appended to the feed with a signed card hash.
- Intake/handoff: `owner_decision_service.py` is a **loopback-only HTTP intake** (token + HMAC) that records an immutable receipt and hands off exactly one governed Claude router task; `owner_decision_execution.py` tracks that execution with an SLA. Execution never touches factory/T_Live/AutoTrading (render_cockpit_v2.py:697-700).
- Data model: `build_owner_decisions` (mission_control_v2_data.py:865) loads the feed (line 889), validates it, keeps `open_items`, and attaches `executions`, `router_health`, `intake` (endpoint/token). Renderer `_render_owner_decisions` (render_cockpit_v2.py:471) shows only OPEN/DEFERRED (line 475-478); DECIDED are archived to the Vault (comment line 613-614). Section title "**Owner Decision Queue**"; the standing OWNER rule (a YES/NO receipt reserves exactly one Claude task) is enforced in the boundary note.
- Evidence: `owner_decision_store.py:35-37, 86-138, 243-330`; `owner_decision_service.py:1-2`; `owner_decision_execution.py`; `mission_control_v2_data.py:865-960`; `render_cockpit_v2.py:471-724`.

### F8 — §60 / §62 sections do NOT exist yet; the data does
- Grep for `book.?evolution|challenge.?readiness|dxz.?section|ftmo.?section|readiness` across `render_cockpit_v2.py` and `mission_control_v2_data.py` returns **nothing**. The only FTMO widget is `_render_q09_ftmo_recommendation` (render_cockpit_v2.py:783) — a Q09-admission census (`portfolio/ftmo_q09_admission.py`), explicitly "keine … Challenge- oder Deployment-Autorität".
- Available data read-models (all under `D:\QM\reports\state\`, all refreshed 2026-09-15 14:xx):
  - **DXZ live book**: `live_book_pulse.json` (keys incl. `book_manifest, effective_state, expected_state, ea_logs, magic_registry, live_presets, terminal_journals, verdict, heartbeat`), `live_sleeve_drift.json`, `live_risk_freeze.json`, `live_deployment_pointer.json`, `live_book_dd_guard_state.json`.
  - **FTMO demo**: `ftmo_trial_pulse.json` (keys incl. `verdict, expected_state, qualified_pairs, expected_state_review_trigger*, equity, day_pnl, total_dd_pct, day_loss_pct, open_positions, magics_seen/expected_magics, alarms, warns, health_contract`).
  - **Portfolio engine** (`tools/strategy_farm/portfolio/`): `dxz_next_book_trigger.py` (emits `trigger_class` BETTER/MATERIAL_BUT_REVIEW/NO_MATERIAL_GAIN + `owner_review_unlocked`, JSON to stdout), `build_book_dxz.py`, `build_book_ftmo.py`, `ftmo_book_readiness.py` (`build_readiness` → JSON with blockers + `qualification_state`), `ftmo_probability_contract.py`, `validate_ftmo_readiness_part1.py`, `marginal_contribution_eval.py`, `fund_score.py`, `portfolio_correlation.py`, `concentration_tail.py`.
- These are point-in-time producers; most print JSON to stdout rather than persisting a stable read-model file, so Phase D needs a small persistence step (see Recommended actions).
- Evidence: `ls D:/QM/reports/state`; `portfolio/dxz_next_book_trigger.py:119-131, 150-158`; `portfolio/ftmo_book_readiness.py:79-158, 162-195`.

## Drift table

| Topic | Doc/Vault/code says | Runtime / directive says | Path |
|---|---|---|---|
| "Way to 25" as goal | Cockpit v2 section "Weg zu 25" + `/25`; morning-brief §3 "WEG ZU 25" + `/25`; `path_to_25.py` sealed `>=25` counting | §3/§60: abolished as business target; remove from Mission Control + Morning Briefing + dashboards; keep as diagnostic only; mark history superseded | `render_cockpit_v2.py:880-999`; `morning_brief.py:1278-1327`; `path_to_25.py:617` |
| 25-candidate book trigger | `dxz_next_book_trigger.py` / Q15 guard predicated on candidate pool; `ftmo_trial_pulse.json` `expected_state_review_trigger_qualified_pairs` gates FTMO review | §4: fixed `>=25` trigger superseded; evaluate any valid pool | `portfolio/dxz_next_book_trigger.py`; `D:/QM/reports/state/ftmo_trial_pulse.json` |
| FTMO on the cockpit | Only `_render_q09_ftmo_recommendation` (Q09 admission census) | §60/§62: full FTMO section + living Challenge Readiness metric required | `render_cockpit_v2.py:783-811` |
| Book Evolution view | No DXZ/FTMO/Research/Factory book section exists | §60: this must become the new primary view replacing "Way to 25" | grep miss in `render_cockpit_v2.py` |
| Portfolio state persistence | Portfolio engine mostly prints JSON to stdout ad hoc | §58/§68E: continuous portfolio evaluation must be an operational read-model MC can bind | `portfolio/*.py` (no stable state file) |

## Open questions strictly requiring OWNER

None. §3/§4/§60/§62 are already-decided policy the directive orders implemented without re-approval (§68B: "Do NOT ask OWNER to reapprove decisions already explicit here"). The only judgement calls (exact widget layout, which portfolio metrics to surface first) are GELB/skeleton-level design, not RED.

## Recommended actions — Phase D implementation plan

### D0. Producers → stable read-models (prerequisite; belongs to Phase E but blocks D)
Persist deterministic JSON so the cockpit binds verbatim (never computes):
- `D:\QM\reports\state\book_evolution_dxz.json` — written by a thin wrapper around `portfolio/dxz_next_book_trigger.py` + `portfolio/marginal_contribution_eval.py` + `portfolio/portfolio_correlation.py`, joined with `live_book_pulse.json` / `live_sleeve_drift.json` / `live_risk_freeze.json`.
- `D:\QM\reports\state\book_evolution_ftmo.json` and `D:\QM\reports\state\ftmo_challenge_readiness.json` — from `portfolio/ftmo_book_readiness.py::build_readiness`, `portfolio/ftmo_probability_contract.py`, `portfolio/validate_ftmo_readiness_part1.py`, `ftmo_trial_pulse.json`.
- `D:\QM\reports\state\research_state.json` — from the Kimi ledgers/preregistration store (audited separately) + `agent_tasks` research rows.
- Refresh via a new task or fold into an existing 5-15 min task; each file carries a `meta{source, source_as_of, staleness}` block matching `_section_meta_schema()` (`mission_control_v2_data.py:1349`).

### D1. Data model — `mission_control_v2_data.py`
- Add loaders `_load_book_evolution()`, `_load_ftmo_readiness()`, `_load_research_state()` (fail-soft like `_load_live_observability`, `mission_control_v2_data.py:1247`).
- In `build_contract` (line 1291-1343) add contract keys `book_evolution`, `ftmo_challenge_readiness`, `research_state`; keep `path_to_25` but **reclassify it as a Factory diagnostic** (do not delete — §3 keep history). Extend `CONTRACT_SCHEMA` (line 1363) and its validator/tests.

### D2. Renderer — `render_cockpit_v2.py`
- Add `_render_book_evolution(contract)` (DXZ + FTMO + Research + Factory sub-blocks per §60) and `_render_ftmo_challenge_readiness(contract)` (multi-dimensional per §62 — never one number).
- Update `render()` body order (line 1768-1778): put Book Evolution first after the control strip, then FTMO Readiness; **remove `_render_path_to_25` from the primary flow** and either drop it or fold its counts into the Factory sub-block as a labelled diagnostic. Keep `_render_owner_decisions`, `_render_risk_freeze`, `_render_terminals`, `_render_queue`.
- Reuse existing CSS tokens only (no new colours; the file's hard rendering discipline, render_cockpit_v2.py:11-27).

### D3. Morning briefing — `morning_brief.py`
- Replace section 3 `render_path_to_25_section` ("WEG ZU 25", line 1278/1327) and the text mirror (line 1614) with a **Book Evolution + FTMO Readiness** summary bound to the same new read-models; keep section-1 DXZ/FTMO pulse lines. Update the module docstring section list (line 12-27) and `render_text`.

### D4. History / supersession (§3, §65)
- Mark superseded in Vault: `08 Current State/Current Objective.md`, `Current Operating State.md`, and any "Way to 25" page; add a decision cross-link to `decisions/2026-09-15_owner_continuous_book_evolution.md`. Do not delete `path_to_25.py` or its tests — annotate as diagnostic. (Vault writes are out of scope for this read-only audit; noted for the implementing phase.)

### D5. Tests
- Extend `tools/strategy_farm/tests/test_mission_control_v2_data.py` and `test_render_cockpit_v2.py`: new sections render, missing read-model degrades gracefully, "25" no longer appears as a goal headline (§70), owner-decision machinery unchanged.

## Proposed read-model JSON contract (field names) for Phase D

Add to `qm.mission_control.v2`. Every top block carries `meta{source, source_as_of, age_seconds, staleness, degraded_reason}` (existing `_section_meta_schema`).

```
book_evolution:
  dxz:
    meta{...}
    live_book: { sleeve_count, sleeves[ {ea_id, symbol, family, risk_percent, since_utc, probation:bool} ],
                 total_risk_percent, deploy_pointer_sha256 }
    performance: { equity, equity_source, equity_as_of_utc, delta_prev_close,
                   return_mtd, max_dd_pct, current_dd_pct }
    portfolio_estimate: { expected_return, expected_vol, sharpe, effective_bets }
    challengers[ { ea_id, symbol, family, expected_marginal_value, marginal_sharpe,
                   displaces_incumbent, correlation_to_book, confidence } ]
    proposed_change: { action(KEEP|ADD_SLEEVE|REMOVE_SLEEVE|REPLACE_SLEEVE|CHANGE_RISK_WEIGHT|
                       PLACE_ON_PROBATION|PROMOTE|RETIRE|CONTINUE_OBSERVATION|NO_VALID_CHANGE),
                       rationale, expected_benefit, main_risk, materiality:bool, confidence }
    next_recomposition_utc
    fable_recommendation
    owner_action{ required:bool, decision_id }        # links to owner_decisions feed
  ftmo:
    meta{...}
    account_type, demo_cycle_id, demo_start_utc, validation_day_count,
    intended_challenge_book[ {ea_id, symbol, weight} ],
    demo_performance: { equity, day_pnl, total_dd_pct, day_loss_pct, target_progress_pct },
    daily_loss_behaviour{...}, challengers[...], strongest_blocker,
    next_recomposition_utc,
    recommendation(NOT_READY|CONTINUE_DEMO|RECOMPOSE|READY_FOR_OWNER_REVIEW|BUY_100K_2STEP_RECOMMENDED)
  research:
    meta{...}
    active_programmes[ {id, provider, topic, state} ],
    kimi_campaigns[...], new_hypotheses[...], under_criticism[...],
    preregistered_experiments[...], mechanized_candidates[...],
    top_failed_lesson
  factory:
    meta{...}
    useful_frontier_histogram{ Qxx: count }, bottlenecks[...], resource_constraints[...],
    infra_problems[...], compute_utilization,
    candidate_counts_diagnostic{ qualified_pairs, distinct_eas, families }   # NOT a goal (§60)

ftmo_challenge_readiness:
  meta{...}
  two_week_demo_equivalence_pct, demo_stability,
  first_passage: { p_pass, p_pass_le_30d, p_pass_le_60d, median_days },
  daily_loss_survival, max_loss_survival, expected_time_days, uncertainty,
  cost_fidelity, density, concentration, rule_compliance{...}, runtime_readiness,
  strongest_failure_mode,
  overall(NOT_READY|CONTINUE_DEMO|RECOMPOSE|READY_FOR_OWNER_REVIEW|BUY_RECOMMENDED),
  fable_purchase_rationale        # "why is this one paid Challenge worth buying now"
```

`path_to_25` stays in the contract for backward compatibility but is surfaced only inside `book_evolution.factory.candidate_counts_diagnostic` (never as a `/25` goal headline).
