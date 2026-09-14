# Execution record — OWNER-DEC-Q08-SWEEP-ARM-CONTEXT-20260914 (receipt 9e6ddd6b, task 67dfadf6)

OWNER 2026-09-14 ~17:3xZ (chat): "Weg 1, das Winsweep-Ledger als DSR-Suchhistorie plus die Prescreen-Skip-Regel in
einem Codex-Ticket". Transcribed as a YES receipt (way 1) by the Orchestrator.

## Step 1 — commission (done 17:4xZ)

Codex ticket **8def3323** (ops_issue, priority 84, pinned `decision_bound_agent: codex`, model tier terra, reasoning
high, Codex budget line applies). Payload: `docs/ops/evidence/2026-09-14_q08_context_repair/codex_ticket_sweep_arm_context.json`.

Scope handed to Codex, verbatim from the card's way 1:

- `dsr_cohort` accepts the sealed window-sweep ledger (`qm.window-sweep.v1`, authenticated exactly like
  `config_sweep.authenticate_ledger` / `window_sweep.authenticate_ledger`) as the search history of a sweep-arm candidate;
  every arm (winners, losers, controls) is a trial; same peer-metric code, no new formula.
- Prescreen-skipped census years (hold `PRESCREEN_SKIPPED` with skip authority in the sealed manifest) count as zero-trade
  measurements; the arm stays a trial; other non-terminal cells still raise `INCOMPLETE_TRIAL`.
- Offline replay on QM5_41115 / QM5_41158 (XTIUSD) and on the class-C rows 21507 / 20266; ablation-set EAs 10163 / 10932
  documented (ledger present → same treatment, absent → stay INVALID, never a single-configuration declaration).
- No gate threshold, DSR/FDR formula, keep/control fraction, candidate-universe or verdict change; append-only; tests;
  workers reloaded afterwards by the orchestrator (staggered, idle-aware).

## Step 2 — after the ticket lands (pending Codex)

Review the branch (REVIEW is the orchestrator's duty), reload the workers (chunk pattern), then append-only Q08 reruns
for the 9 sweep-arm rows and the class-C rows (21ef5ce0 already rerun as 510bac30 once the .gz fix landed; 21507 / 20266
after the skip rule), 12115 derived card or retire. This record is updated with the results.

## Acceptance (card) — status

- Codex ticket with exact acceptance criteria → **done** (8def3323).
- dsr_cohort assembles a sealed window-sweep cohort for 41115/41158 → pending Codex.
- prescreen-skipped years counted as declared → pending Codex.
- no gate threshold change → holds by construction (ticket hard limits).
- reruns claimed with a sealed context → after the ticket.
