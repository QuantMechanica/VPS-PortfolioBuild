# CODEX BRIEF 2026-08-02 — FTMO cost-adjusted evaluation path (OWNER-ruled)

**Author:** Claude. **Implementer:** Codex (Sol, effort max). **Reviewer:** Claude.
**Authority:** OWNER ruling 2026-08-02 („die Darwinexzero Backtests sind 'good
enough'!"), recorded in `docs/research/FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md`
§"OWNER evidence-class ruling" — read that section first; its four conditions
are binding and non-negotiable.

**Context:** FTMO serves real ticks only for ~the last week (verified: zero
`.tkc`, per-year `.hcc` M1 only), so venue-native multi-year streams are
unobtainable. OWNER therefore authorizes deciding on Darwinex-executed streams
with FTMO costs imposed — under an explicit, weaker, clearly-labelled evidence
class. This supersedes the wave-1 *execution* campaign; the FTMO demo account
is now used for **cost calibration only**.

**Hard constraints:** no T_Live contact; no AutoTrading; factory keeps running;
FTMO research roots `D:\QM\mt5\FTMO_STREAM1/2` may be used read-only or for
calibration-only runs, never for campaign execution claims; no credentials in
repo/logs; explicit-pathspec commits; no enqueue (Claude enqueues).

## Build

1. **Spread calibration** (`tools/strategy_farm/portfolio/ftmo_spread_calibration.py`):
   per symbol pair (`XAUUSD`↔`XAUUSD.DWX`, `GER40.cash`↔`GDAXI.DWX`), derive the
   FTMO spread distribution from FTMO's own M1 history spread field and the
   Darwinex spread distribution from the corresponding DXZ data, both over the
   same calendar coverage and session buckets. Output a hash-bound calibration
   artifact carrying: per-symbol coverage windows, spread quantiles for both
   venues, the delta distribution, and the **conservative charge** (default:
   upper-quartile-or-worse delta — justify your choice in the artifact). Fail
   closed where either side lacks coverage; never extrapolate across symbols.
   Where FTMO M1 spread data proves unusable, say so and stop — do not guess.
2. **Cost-adjusted stream builder:** extend the existing exporter path (reuse
   `ftmo_daily_net_export.py` machinery where it fits) to emit
   `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` daily rows from the sealed Q08
   full-lifecycle streams: remove Darwinex commission/swap, apply the exact
   FTMO schedule from the pinned snapshot, and charge the calibrated spread
   delta per trade side. Rows must carry the class label, the calibration
   artifact digest, and per-day cost decomposition. The sealed Q08 inputs are
   read-only.
3. **Evaluator wiring:** `ftmo_timebox_eval.py` accepts this class **only** when
   the config explicitly declares it (default stays `REFUSED_DXZ_SPREAD_INHERITANCE`),
   stamps the class into every result, and evaluates a **sensitivity band** over
   the spread charge (at minimum: calibrated-conservative, 1.5×, 2×). Report the
   bootstrap lower bound at each point; the decision number is the most
   pessimistic evaluated point.
4. **Wave-1 re-score:** run the five sealed sleeves and the FUND_SCORE top-N
   grid through the new path; deliver the P1 lower bounds, the binding
   dimension, and the honest gap to 0.80.
5. **Tests:** calibration refusal paths, exact FTMO commission/swap
   substitution against a worked example, class-label propagation, default
   refusal without the explicit declaration, and sensitivity-band monotonicity.

## Handback

Router task → REVIEW with `docs/research/FTMO_COST_ADJUSTED_RESCORE_2026-08-02.md`:
verbatim test output, calibration artifact digests, the re-score table with the
sensitivity band, and a plain statement of what this evidence class can and
cannot support. Do not declare a book ready — that is Claude review + OWNER.
