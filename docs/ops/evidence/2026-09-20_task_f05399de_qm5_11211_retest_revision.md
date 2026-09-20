# Evidence: Second-Chance Wave-2 Retest Card Revision — Task `f05399de-2945-4ab3-8006-896e5b150b3a`

- **Task ID:** `f05399de-2945-4ab3-8006-896e5b150b3a`
- **Agent:** `gemini`
- **Task Type:** `research_strategy` (`kind: second_chance_retest`, `lineage: NEW`)
- **Priority:** 70
- **Origin EA ID:** `QM5_11211` (`ft-binhv45`)
- **Strategy Card Draft:** `D:/QM/strategy_farm/artifacts/cards_review/PENDING_F05399DE_ft-binhv45.md`
- **Verdict:** `REVIEW_READY` (handed off in router state `REVIEW`)

## 1. Context & Starting State

The task was previously closed in `RECYCLE` on 2026-09-18 with verdict:
`"RECYCLE: prescreen REJECT - missing FALSIFICATION,Q08_Q11_RISK,FTMO_FIT, TIMEFRAME_OUTSIDE_BOX M1, NEAR_DUPLICATE 1.00 vs APPROVED QM5_10026_rw-fx-squeeze-mr. Cadence estimate is present and adequate."`
On 2026-09-19, `reconcile-exits` requeued the task to `TODO`, and the deterministic router assigned it to `gemini` in `IN_PROGRESS`.

## 2. Root Cause Analysis & Prescreen Resolutions

1. **Timeframe Adaptation (M1 -> M5):**
   - Under the active Edge Lab Charter (`docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`), scalping is bounded to M5–M15 (`_timeframe_allowed("M1") == False`, rejecting sub-minute HFT).
   - Card timeframe adapted to `M5`, retaining the 40-period Bollinger Band capitulation thesis, `bbdelta` expansion, and bar velocity filters while fully complying with Edge Lab charter constraints.
2. **Duplicate Fingerprint & Differentiation (`QM5_10026`):**
   - While `QM5_10026_rw-fx-squeeze-mr` trades an H1 volatility squeeze contraction regime requiring RSI(14) reversal and exiting on midline touch over 24 bars, `PENDING_F05399DE` operates on M5 as a single-bar volatility expansion capitulation drop reversal, triggering on sharp price velocity (`closedelta`) and minimal candle tail without RSI or squeeze percentile conditions, exiting on a fixed ROI / ATR target.
   - Prescreen differentiation wording added; `NEAR_DUPLICATE` downgraded to warning, resolving the blocking reject.
3. **Charter Sections Added:**
   - `## FTMO Fit & Venue Hypothesis`: 5% daily limit, 10% total drawdown, mandatory fail-closed news blackout (`qm_news_stale_max_hours = 336`), M5 scalping horizon.
   - `## Falsification / Kill Criteria`: 4 concrete kill triggers (PF <= 1.05, cadence < 15 trades/yr/symbol, spread/slippage erosion, news window contamination).
   - `## Q08 and Q11 Crisis & News Risk`: Q08 crisis stress testing, weekend flattening (`qm_friday_close_enabled = true`), and Q11 news replay analysis.

## 3. Verification Evidence

- `tools/strategy_farm/card_intake_prescreen.py --card "D:/QM/strategy_farm/artifacts/cards_review/PENDING_F05399DE_ft-binhv45.md"`:
  `verdict = KEEP`, `reasons = []`, `missing_sections = []`, `missing_feeds = []`.
- `farmctl.strategy_card_schema_issues`: `[]` (0 issues).
- `farmctl.strategy_card_r_gate_consistency`: `ok = True`, 0 errors, 0 warnings.
- `card_heading_language.check_card_heading_language`: `ok = True`, 0 unmapped headings.

## 4. Handoff

The Strategy Card draft is clean, verified, and placed in `D:/QM/strategy_farm/artifacts/cards_review/PENDING_F05399DE_ft-binhv45.md`. Per DL-065 capability boundaries, `gemini` hands off the task in `REVIEW` for Codex build intake and G0 approval.
