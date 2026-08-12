# Decision: C1 — port DL-083 thresholds into the Q09 hard admission gate, stricter-of-two correlation

- Date: 2026-07-26
- Status: accepted (OWNER: „Punkt 11: ja, neu adjudizieren!", midday chat)
- Closes: C1 from the gate-funnel autopsy (Track C, `docs/ops/evidence/2026-07-25_gate_funnel_autopsy.md`
  §C1) — the decision DL-083 line 51 deliberately deferred.

## The rule

`portfolio_admission.py`'s hard gate replaces the legacy single threshold (max full-sample
Pearson 0.30) with the DL-083 numbers on a **stricter-of-two correlation basis**:

1. Compute candidate-vs-book correlation on (a) the full joint sample and (b) the
   high-volatility regime (top-quartile book-composite rolling-vol days; minimum regime
   sample required, else regime basis = UNKNOWN and recorded — full-sample then binds alone
   with the UNKNOWN flagged in the verdict reason).
2. `corr_eff = max(a, b_known)`. Gate: `corr_eff >= 0.40` → REJECT;
   `corr_eff < 0.15` with positive marginal contribution → ADMIT (strong zone);
   otherwise ΔSharpe >= 0.020 decides (ADMIT/REJECT).
3. Reason strings name the binding basis (`corr_full`, `corr_regime`, `regime_unknown`)
   so evidence consumers can always distinguish.

## Re-adjudication

The ~8 (EA, symbol) pairs whose historical Q09 outcome flips under the new rule (autopsy
estimate) are re-adjudicated through the NORMAL chain (fresh Q09_PORTFOLIO runs) after the
gate change merges — no verdict is edited in place, no admission is granted by this record.

## Sequencing

Claude-built → Codex review (bilateral rule); the patch is staged and merges in the
2026-07-26 Factory-OFF window with the other reviewed gate work. Exact regime definition
parameters (rolling window, quartile, minimum regime days) are documented in the
implementation and bound to this record; material changes need a new dated decision.
