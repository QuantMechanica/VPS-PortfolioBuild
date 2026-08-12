# Codex brief — repair QM5_20181 before the satellites are measured

Date: 2026-07-27
Priority: high. OWNER: "Der Verbund EA muss aber repariert werden!"
Timing: a workflow is currently running the step-1 measurement (two full backtests,
hours of tester time). This repair must land BEFORE its step-2 agent starts, so that
step 2 measures a repaired EA instead of stopping at a known defect.

## The EA and its known defects

`framework/EAs/QM5_20181_ftmo-joint-multisym-timer/` — the hybrid joint EA (runner
9936 on OnTick, satellites on OnTimer). Committed today (54efb0c66-adjacent). The
adversarial review (`docs/ops/evidence/2026-07-27_multisymbol_ea_adversarial_review.md`)
confirmed these, in severity order:

**F3 (CONFIRMED, the load-bearing one): enabling a satellite flips the framework into
basket mode and may perturb the runner.** Step 1 runs `basket_mode=false`
(`...mq5:222`); the EA's own header warns that warming a second symbol "would flip the
framework to basket ownership (QM_Common.mqh:414-431) and perturb the runner's
context". Magic selection is basket-flag-independent (`QM_Common.mqh:405-412`), which
helps, but every other basket-gated behaviour is unverified. The repair requirement:
**the runner's code path must be provably invariant to satellite enablement.** Whatever
basket machinery the satellites need must not alter slot-0's warmup, bar detection,
news context, sizing or order path. If full invariance is impossible, the fallback is
isolation by construction — e.g. satellites use their own guard/warmup context and the
runner never enters basket ownership — and you must state which framework behaviours
remain basket-gated and why they cannot reach slot 0.

**F4 (NOT ESTABLISHED): the entire non-host machinery is declared but unexercised.**
`QM_SymbolGuardInit`, `QM_BasketWarmupHistory`, the symbol-aware order path, per-sleeve
news `symbol_slot`, per-symbol `QM_IsNewBar` — none of it runs in the shipped scaffold
(`basket_mode=false`, `g_sat_count==0`). The satellite path for **10145:XAUUSD** must be
COMPLETED, not sketched: its entry/exit logic bound faithfully from the gated
`QM5_10145_tsm-meanret` EA (TIMER-SAFE per the exit-cadence recon — no trailing, exits
read closed D1 bars), its own magic, its own state, `symbol_slot` set, once-per-bar
idempotence on the timer (a double-fire must not double-trade: guard on bar time per
symbol, persisted across restart).

**F2 (tooling): `compare_joint_replay.py` lacks the mismatch categories** the
diagnosis had to reconstruct by hand. Extend it to classify: same-entry/same-volume/
shifted-exit, different-entry, extra, missing — with counts. The step-2/3 agents and
every future fidelity gate will use this.

**The 13301 decision — resolve it by measurement path, not hope.** 13301:GDAXI is
TIMER-RISKY (per-tick +1R trailing, structurally like 9936). Its OnTimer reproduction
will likely NOT reach 1.0. Before step 3 burns terminal hours: check the 35
Q09-passing sets in `docs/ops/evidence/2026-07-27_runner_satellite_composition.md` for
an alternative third member that is TIMER-SAFE (verify its exit cadence from source the
way the recon did). If one exists with comparable OOS FUND_SCORE, recommend the swap
and wire it as the satellite-2 candidate instead; if none exists, say so and 13301's
gate failing becomes an accepted, documented outcome rather than a surprise.

## Constraints

- COLLISION AWARENESS: a running workflow owns the step measurements and may read this
  EA at any time. Commit early and often with explicit pathspecs so its agents pull
  repaired source. Do not edit `farmctl.py`/`terminal_worker.py` (reaper fix in flight).
- Do NOT run any backtest — the workflow owns the terminals and the measurement. Your
  deliverable is the repaired, compiling EA plus tooling; the workflow proves fidelity.
- Compile 0/0 on the canonical path after every change. Serial.
- Do NOT modify the gated QM5_9936 / QM5_10145 / QM5_13301 EAs — they are sources of
  truth to bind FROM.
- BACKTEST-ONLY guards in 20181 must remain intact (refuses non-tester, RISK_PERCENT>0,
  wrong chart).
- Evidence over claims; explicit pathspecs; NOT ESTABLISHED over inference.

## Deliverable

`docs/ops/evidence/2026-07-27_20181_repair.md`: what was repaired per finding, the
runner-invariance argument with file:line, the 10145 binding provenance, the comparator
extension, the 13301-alternative answer, and compile results.
