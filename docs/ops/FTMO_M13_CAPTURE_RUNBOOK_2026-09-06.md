# FTMO M13 Capture-Only Trial Runbook (2026-09-06)

Decision: **OWNER-DEC-M13-ECONOMIC-TRIAL-20260906 = YES (Option B)**. Receipt `c575c17a-b55e-4cd3-9770-b9d6bf287f9d`, 2026-09-06 06:17Z.
Contract: `docs/ops/OWNER_VORLAGE_2026-09-06_m13_economic_test_contract.md` (Option B). Design basis: `docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md` §B. C-6 input: `docs/ops/FTMO_C6_ESTIMATOR_METHOD_2026-09-05.md`. Gate reference: `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json`.

This runbook operationalizes a **capture-only** demo trial. It does not authorize a purchase, a live-trading change, an AutoTrading toggle, a T_Live write, or any scoring. Nothing here widens the R5 or C-6 population.

---

## 1 · Purpose and firewall

**Purpose.** Record the one evidence class no backtest produces: real M5 equity (including open PnL, swaps, commissions), open positions, and pending orders under live fills at the Europe/Prague-midnight anchor (`ftmo_readiness_part2.md` §B.0). It answers an **operational execution-fidelity** question only — never the long-run edge or pass-rate question.

**Firewall (pre-registered, binding).**
- **Capture-only.** Telemetry is recorded; **no scoring, no prediction-band evaluation** is performed. Success is a *data-capture* verdict, not an edge verdict.
- **Ineligible as confirmation.** Capture-only exploratory data may inform a NEW preregistration but is **never** eligible as confirmation under that revised plan; a post-hoc scored rehearsal is never laundered into confirmation (`ftmo_readiness_part2.md` §B.6 firewall).
- **Separate from R5.** No trial day enters the R5 sealed-OOS population; short spans and extra seeds do not widen it (R5 R-4). This trial is **not** R5 evidence.
- **Separate from C-6.** The trace feeds only the C-6 **exact-guard INPUT** (M5/Prague path). A handful of Prague-days sits far below the C-6 floors (36/23/9); C-6 stays `LOW_SAMPLE`/INERT and is **not** activated here.
- **USD 0, no purchase.** Free Trial / demo only. NO-BUY stands; `ftmo_owner_purchase_gate` is untouched.

## 2 · Preconditions (owner / AI split)

All preconditions MUST be MET before the capture window opens. None is executed by this document.

**SOP:** after every FTMO demo attach/detach, EA rebuild, or preset change, rerun
`verify_ftmo_demo_instrumentation_contract.ps1` and re-pin the verifier in the
same reviewed commit; a mismatch remains fail-closed.

**OWNER (login-gated / ROT):**
1. Create the FTMO **Free Trial demo** (2-Step $100K **Swing**, MT5). Store credentials **only** in the private record (`.private/`); never in the repo.
2. Confirm client-area terms: Swing leverage, current symbol list, margin, swap, and triple-swap weekday (provisional Sep-5 figures stay provisional until confirmed).
3. Set the **duration cap** — default proposal **10 Prague trading days** — long enough to exercise a restart, one midnight crossing, and the entry-window; not open-ended.
4. Enable AutoTrading on the **demo** terminal (OWNER-only) so the sleeves execute. The read-only collector never trades.
5. After the AI preconditions are accepted, flip `EXPECTED_STATE` **PARKED → RUNNING** in `tools/strategy_farm/ftmo_trial_pulse.py` (OWNER decision authorizing a live-executing demo; the AI implements the code edit). Current state is PARKED under `OWNER-DEC-FTMO-PARK-UNTIL-25-20260825`.

**AI (commissionable; commission as router tickets — not executed here):**
6. **Live-mode set-path generator** (Codex ticket): produce `ENV=live / RISK_FIXED=0 / RISK_PERCENT` sets from the future FTMO-specific reviewed manifest. Closes `ftmo_readiness_part2.md` §B.2 limit 1 (the runner's guardrail forbids live-mode sets today).
7. **Collector acceptance + installation** (Codex ticket): review/accept `framework/monitor/QM_FTMO_TrialTelemetry.mq5` + `tools/strategy_farm/portfolio/ftmo_trial_telemetry.py`, install under approval into the demo terminal, and bind acceptance evidence. Closes §B.2 limit 3.
8. **News-blackout binding**: QM mandatory news blackout binds in every trial set (`EDGE_LAB_CHARTER_2026-05-22.md:28`). The FTMO Swing provider exemption is kept in its own column and does **not** repeal the QM blackout.
9. **Terminal provisioning plan**: a **separate, non-T_Live** terminal directory for the demo (never `C:/QM/mt5/T_Live`). The collector requires an `FTMO-Demo` server profile; verify the directory is not T_Live before any install.

## 3 · Capture procedure (step by step)

1. **Confirm preconditions.** All of §2 MET; sets carry `ENV=live / RISK_FIXED=0 / RISK_PERCENT` + QM blackout; collector accepted + installed; account identity guards set (`InpExpectedLogin`, `InpExpectedServer`, explicit `InpTrialId`).
2. **Choose sleeves/symbols.** A small subset of the 8 sealed FTMO candidates on covered lanes — XAUUSD, GER40.cash, GBPUSD, EURUSD, USDCAD, NZDUSD, USOIL.cash (evaluator XTIUSD), XAGUSD — bounded by the FTMO manifest. Pick enough sleeves to produce multi-symbol occupancy and at least one position held across a Prague midnight; capture-only does not require the full roster.
3. **Arm telemetry.** Run `QM_FTMO_TrialTelemetry.mq5` (read-only, 1s timer) alongside the sleeves. It appends `qm.ftmo-trial-telemetry.raw/v1` SAMPLE rows (balance, equity, per-position and per-pending census, `prague_day_key`, `session_id`, `sequence`, `reconciliation_complete`) to `<MT5 Files>/QM/ftmo_trial/trial_telemetry_raw.jsonl`.
4. **File landing.** For each capture day copy the raw jsonl to `D:/QM/reports/ftmo_trial/<date>/trial_telemetry_raw.jsonl` and compact it:
   `python tools/strategy_farm/portfolio/ftmo_trial_telemetry.py --input D:/QM/reports/ftmo_trial/<date>/trial_telemetry_raw.jsonl --output D:/QM/reports/ftmo_trial/<date>/trial_telemetry_m5.json`
   The report (`qm.ftmo-trial-telemetry.m5/v1`) carries `m5_rows[].interval_min_equity`, `days[]` (Prague anchor, `daily_floor`, `minimum_equity`, `daily_loss_breached`), `continuity` (gap list), and `ingestion` (`restart_count`).
5. **Daily pulse (read-only).** `ftmo_trial_pulse.py` (`QM_FTMO_TrialPulse`, 30 min) observes only — it never starts/stops a process or closes a position. After the OWNER flip it must read `RUNNING` and stay OK/WARN (exit 0).
6. **Restart drill.** Mid-session, restart the demo terminal. Verify: a new `session_id`, `ingestion.restart_count ≥ 1`, the continuity gap at the boundary carries `restart_boundary=true`, and open-position/pending state is recovered post-restart.
7. **Prague-midnight crossing drill.** Hold a position across 00:00 Europe/Prague. Verify: `prague_day_key` increments, a new `days[]` row appears with `anchor_lag_seconds ≤ maximum_sample_gap_seconds`, and the daily floor re-baselines to the new anchor balance.
8. **Entry-window guardrail check.** During 23:50–00:10 Europe/Prague confirm **no new entries** open (`positions_by_magic` unchanged across the window while existing positions keep managing). This calibrates `qm_ftmo_midnight_entry_window` (`PROPOSED_FOR_CALIBRATION`).
9. **Close the window** at the duration cap (or an OWNER stop). Flip `EXPECTED_STATE` back to PARKED. Compact the full window and write the trial record (§5).

## 4 · Stop rules and "0 operational defects"

**Stop rules.** Any single **rule / governor / identity / execution** defect ends the run. The duration cap bounds the window. A demo hit of the FTMO daily (5%) or total (static 10% floor) rule is a **data point**, not a monetary loss and not a defect (demo, USD 0 at risk).

**"0 operational defects"** — the capture-only success definition. The run is a success iff, across the window:
- **Data continuity:** the compacted report yields a **gap-free** Prague-day-keyed M5 interval-minimum series with per-interval position/pending census; `continuity.status = PASS` except at **drilled** restart boundaries, which are expected and annotated (`restart_boundary=true`), not defects.
- **Validation:** `ftmo_trial_telemetry.py` ingests the stream without a `TelemetryError` (no schema/event mismatch, no `prague_day_key` mismatch, no unreconciled inventory, no sequence regression, no identity race).
- **Identity:** account login/server bind (`InpExpectedLogin`/`InpExpectedServer` match; `reconciliation_complete=true` on every row).
- **Governor:** the pulse never raises an un-drilled ALARM after the RUNNING flip.
- **Drills:** all three drills (§3.6–3.8) pass.
- **Execution:** no telemetry append failure, no unrecovered terminal crash, no QM-blackout or entry-window violation observed.

Any of these failing = an operational defect = stop. This is a *capture* verdict only; hitting or missing the profit target is irrelevant here.

## 5 · Evidence outputs and trial record template

**Artifact paths (per capture date):**
- Raw stream: `D:/QM/reports/ftmo_trial/<date>/trial_telemetry_raw.jsonl`
- Compacted report: `D:/QM/reports/ftmo_trial/<date>/trial_telemetry_m5.json` (`qm.ftmo-trial-telemetry.m5/v1`)
- Pulse observations: `D:/QM/reports/ftmo_trial/<date>/pulse/` (read-only)
- Collector acceptance evidence: bound by the AI acceptance ticket (§2.7)
- Trial record: `docs/ops/evidence/YYYY-MM-DD_ftmo_m13_trial_capture_only.md`
- Evidence skeleton (this trial): `docs/ops/evidence/2026-09-06_ftmo_m13_trial_capture_only/README.md`

**Trial record template (fill at window close):**
```
# FTMO M13 Capture-Only Trial Record — <date>
Decision: OWNER-DEC-M13-ECONOMIC-TRIAL-20260906 (Option B) · Receipt c575c17a-…
Mode: CAPTURE-ONLY (ineligible as confirmation; not R5, not C-6, no purchase)
Window: <first Prague day> .. <last Prague day> (cap: <N> Prague trading days)
Sleeves/symbols: <list>
Artifacts: raw=<path> · m5=<path> · pulse=<path>
Continuity: <PASS | FAIL_GAPS> (drilled restart boundaries: <n>)
Drills: restart=<PASS/FAIL> · midnight-crossing=<PASS/FAIL> · entry-window=<PASS/FAIL>
Identity: login/server bound=<yes/no> · reconciliation=<all true?>
Pulse: un-drilled ALARM=<none/…>
Operational defects: <0 | list>
Verdict: <CAPTURE_SUCCESS | STOPPED:<reason>>
C-6 exact-guard input handed off: <path | n/a> (LOW_SAMPLE, non-lifting)
Firewall reaffirmed: not scored; ineligible as confirmation; NO-BUY intact
```

## 6 · Out of scope (explicit)

- **Scoring / prediction-band evaluation** — that is the for-record path (Option C), which requires a ratified scoring contract first. Not done here.
- **For-record confirmation** — this data can never be converted into confirmation.
- **Purchase** of any paid Challenge — EXCLUDED (NO-BUY; `ftmo_owner_purchase_gate`).
- **Live trading / AutoTrading toggle / T_Live write** — none authorized by this runbook; the demo terminal is a separate, non-T_Live directory.
- **R5 population widening** and **C-6 floor crediting** — neither.
- **Promoting provisional cost/margin/swap figures** into `venue_cost_model.json` — stays provisional until OWNER client-area confirmation.
- **DXZ deploy-pointer signing / risk-freeze lift** — a separate DXZ act, out of this FTMO scope.
