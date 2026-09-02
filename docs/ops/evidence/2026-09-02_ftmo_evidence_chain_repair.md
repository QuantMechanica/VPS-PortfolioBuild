# FTMO evidence-chain repair — 2026-09-02

Task: `b306ca82-56b3-4f31-a75f-4575ca486d1d` (priority 85). Scope is research and monitoring only. No terminal, `T_Live`, AutoTrading, purchase, deployment, or sealed threshold was changed.

## Result

- The legacy portfolio audit engine now reads the frozen `D:/QM/reports/portfolio/dxz_final_20260719/QM/q08_trades` bundle and does not re-filter that sealed population through the mutable farm database.
- The 24-sleeve fingerprint is pinned as `e50e8f891c34f838e576f00c4b4d85e0815bd358c20028ac55dd294369b81759`. The sweep and EV scripts fail closed on either fingerprint or numerical-anchor drift.
- Regeneration reproduced the CEO audit reference: 24 sleeves, 2,028 trading days, 3,004-day span, close/MAE worst days -6.21%/-7.93%; at 0.50x P1=30%, funded=12%, break-even fee $9,306 close / $7,451 overlap-floor.
- The FTMO research rulepack advanced to `FTMO_2S_100K_SWING_V2` and records USD 540 list price, 100% fee refund with first Reward, 80%→90% split, Swing leverage 1:30 FX / 1:15 metals and oil, and +25% per four-month scale-up. Fresh normalized provider snapshot: `docs/ops/evidence/2026-09-02_ftmo_economic_terms_snapshot.json`.
- `QM_FTMO_TrialPulse` `ExecutionTimeLimit` increased from PT5M to PT20M. Its next observed result was `1` (the monitor's documented ALARM exit), not Task Scheduler `267014`; after refreshing `silent_failure_alarms.json`, no execution-time-limit alarm for this task remained. This does not relabel the underlying parked-account observation healthy.

## Verification

- `python tools/strategy_farm/target_rulepacks.py` — both rulepacks PASS; V2 canonical SHA-256 `93735045ca7a473107f1583c9aca011aa5a0fad23cab89a3068453973a707c74`.
- `python tools/strategy_farm/portfolio/audit_intraday_sizing_sweep.py --selftest` — PASS, exact anchors and fingerprint.
- `python tools/strategy_farm/portfolio/audit_ev_funded_account.py --json-out artifacts/audit_ev_funded_account_20260902.json` — completed with pinned self-test.
- `python tools/strategy_farm/silent_failure_monitor.py` — refreshed sidecar; FTMO task time-limit alarm absent.
- Focused rulepack, dossier, execution-bundle, and dashboard tests: 132 passed.

Verdict: **REVIEW — implementation complete; OWNER/Claude close-out required.**
