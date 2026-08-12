# Decision: FTMO trial deferred until the book is promising; current-rate swap scenario recorded

- Date: 2026-07-26 (afternoon chat)
- Status: accepted (OWNER: „Demo Challenge starten wir dort erst, wenn das Buch
  aussichtsreicher ist" — supersedes the midday „9: ja heute Abend"). Claude concurs.

## FTMO trial deferral

The sealed density model shows the current FTMO-eligible book times out (~0 % P(pass
Phase 1 in 30 d); mean 30-day ending ≈ $99.8k on $100k — it starves, it does not breach).
A trial now burns a month to prove the known. **Trigger to start the trial:** the
admitted joint-book replay under the ratified B1 contract reaches **P(pass Phase 1 by
30 d) ≥ 0.5** (objective O1) — expected via the density-motor pipeline (20007 repair,
9936 rescue, greenfield motors; planning minimum ≈ 7 reference sleeves) — AND the 13206
governor's MQL parity/terminal phase is closed so the trial runs protected from day 1
(the dead trial's lesson: −2.0 % halt vs the −10 % that killed it). D5 (min trading
days) resolves when the account is created. The FTMO terminal stays OFF meanwhile.

## Current-rate swap scenario (OWNER-run capture, first real numbers)

Source: OWNER executed QM_SwapCapture on the LIVE Darwinex terminal
(`swap_capture_4000090541.csv`, 2026-07-26 11:09Z, server Darwinex-Live; 15/15 book
symbols; AUDJPY basket leg not in the script list → UNKNOWN). Engine: the Codex-approved
replacement-basis swap_scenario.py. Results
(`D:/QM/reports/ultracode_20260726/wsd3/current_rate_scenario_20260726.json`):

- **FINAL24b at today's rates: ΔNet −$9,430 over the 8y window on the 16 reconciled
  sleeves → ΔSharpe −0.251** (2.344 → ~2.09), annual forward drag ≈ **−$1,224/yr**
  (~1.2 %/yr of notional ≈ one month's expected return). FINAL23: −$9,089 / −0.217 /
  −$1,184/yr.
- Dominated by gold long swap (−58.6 pts/night: 12567/XAU −309, 1556 −253, 10403 −570
  raw $/yr) and XTIUSD (−254/yr at cap weight, percent-annual mode).
- Historical KPIs were NOT wrong — the streams carry the historical swap (+$305 embedded,
  USDJPY carry positive). The finding is a REGIME shift: today's rates are far worse for
  this gold-heavy book than the historical average.
- Honest bounds: 8 sleeves UNKNOWN (incl. positive-carry 13213/USDJPY), profit-ccy
  conversions approximate (±2 %), and a current-rate scenario applies today's daily-
  changing rate to historical exposure — a deployment-cost stress, never a forecast.

**Consequences:** (1) strengthens the deployment deferral — the staged FINAL22's
effective forward expectation is ~1 %/yr lower than headline; (2) swap-aware composition
becomes a REQUIRED lens for the next book (gold-long overnight concentration is the cost
center); (3) venue_cost_model.json adoption of the captured rates + the per-side sleeve
swap analysis go into the next reviewed gate batch; (4) re-run the capture (script stays
on T_Live) whenever a book decision is near — rates change daily.
