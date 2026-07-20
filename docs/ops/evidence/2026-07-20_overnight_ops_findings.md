# Overnight ops findings — 2026-07-20 late

Context: OWNER overnight directive ("finish what you can, dispatch headless Codex,
keep the pipeline moving"). Findings from the priority-Q02 pulse after Codex's
H-A backfill ranked 20004/20006/20010/4006 at 2/3/4/6 of 3,519.

## 1. Priority-Q02 outcomes (evidence: farm_state.sqlite work_items + ea_metrics)

- **20010/XAUUSD Q02 PASS** 17:28 UTC (PF 1.04, 206 trades, DD 2.94%) — advanced.
- **20006/SP500 Q02 FAIL with 0 trades** — draft-defect class (entry gating never
  fired), NOT an edge verdict. Route to re-draft; once the H-C `DRAFT_DEFECT`
  verdict machinery is merged this class auto-routes. FTMO density-motor
  candidate — re-draft this week.
- **20004 GDAXI+NDX failed with `summary_missing_retries_exhausted`** — setup
  class (Hard Rule 7), no strategy verdict. Tester ran ~45s, exited without a
  latched report (T9 log: `some error after pass finished ... 0:00:00.000`).
  **Requeued via staged recovery** (rows ec31f192/90c4751d → pending,
  `requeue_reason=summary_missing_staged_recovery`, priority_track retained).
- 4006/EURUSD had already been auto-requeued (failed 16:46 → pending 16:52).

## 2. Zero-duration retry noise is a STANDING pattern, not a new outage

Counts of `some error after pass finished ... in 0:00:00.000` per terminal log:
T2 79→157, T3 97→150, T7 102→179, T8 27→17, T9 153→263 (2026-07-19 → 07-20).
Present at scale on the (successful) go-live day too; the funnel demonstrably
moved all day (Q02 15→16 PASS, Q03 362→367). Treat as the known first-attempt/
retry class. **Outlier worth watching: T9 logged ~205k `'EURUSD' file opening
or reading error [32]` (sharing violation) lines today** (others 0.6k-5.9k) —
raw-symbol history sync fighting locked files. If T9 keeps eating retries
tomorrow, park it via disabled_terminals.txt and inspect in the Saturday OFF
window; do NOT mutate bases\Custom in-place (shared store).

## 3. HARDENING FLAG (OWNER-visible): factory terminals log into the LIVE account

T9's terminal log shows `'4000090541': authorized on Darwinex-Live ...
trading has been enabled - hedging mode` + live positions/orders synchronized —
on a FACTORY tester terminal. This is long-standing (every tester spawn), the
strategy tester itself cannot trade the account, and no chart EAs run on
factory terminals — but account-level isolation is weaker than directory-level
T_Live isolation suggests. **Proposed fix (Saturday OFF window, OWNER ack):
switch T1-T10 terminal logins to the account's INVESTOR (read-only) password**
— testers keep the symbol universe/spreads, trading capability disappears.
Do not change terminal configs mid-run.

## 4. Dispatches running overnight

- Codex #2 (gpt-5.6-sol, effort max, detached): re-key of the six remaining
  registry-only duplicate ea_ids (1492/9197/9198/11277/11427/11857) + independent
  re-review of the KS foreign-config fix 6f2393373. Log:
  `D:\QM\reports\state\codex_dispatch_20260720\run_night.log`.
- Claude agents: Codex-bundle merge-review (H-A/H-C/H-D), FTMO Phase-1
  Monte-Carlo harness (candidate-book pass-speed for the 26.07 decision).

KS fix itself: commit 6f2393373 (RestoreState outcome enum, init preserves
foreign-config state, regression test 8/8, strict include-graph compile 0/0).
