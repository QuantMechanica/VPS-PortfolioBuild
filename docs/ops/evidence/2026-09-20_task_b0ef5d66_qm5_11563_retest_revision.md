# Evidence: Second-Chance Wave-1 Retest Card Revision — Task `b0ef5d66-5947-4d79-ad72-02f2caee04cb`

- **Task ID:** `b0ef5d66-5947-4d79-ad72-02f2caee04cb`
- **Agent:** `gemini`
- **Task Type:** `research_strategy` (`kind: second_chance_retest`, `lineage: NEW`)
- **Priority:** 70
- **Origin EA ID:** `QM5_11563` (`connors-rsi2-sma200-mean-reversion-d1`)
- **Strategy Card Draft:** `D:/QM/strategy_farm/artifacts/cards_review/PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md`
- **Verdict:** `REVIEW_READY` (handed off in router state `REVIEW`)

## 1. Context & Starting State

The task was previously closed in `RECYCLE` on 2026-09-18 with verdict:
`"RECYCLE: prescreen REJECT - CHARTER_SECTIONS_MISSING FALSIFICATION,Q08_Q11_RISK and NEAR_DUPLICATE 1.00 vs APPROVED QM5_11365_connors-rsi2-sma200-pullback-d1. Add sections; resolve the approved twin first."`
On 2026-09-19, `reconcile-exits` requeued the task to `TODO`, and the deterministic router assigned it to `gemini` in `IN_PROGRESS`.

## 2. Root Cause Analysis & Prescreen Resolutions

1. **Approved Twin Resolution (`QM5_11365` vs `QM5_11563`):**
   - Approved card `QM5_11365_connors-rsi2-sma200-pullback-d1.md` was approved on 2026-05-23 as a card draft only and was never built or run in `farm_state.sqlite` (0 work items).
   - In contrast, `QM5_11563` was the active implementation that successfully proved trading edge across Q02, Q03, Q05, Q06 (Profit Factor 1.57, 94 trades, DD $4,370.07 on GBPUSD.DWX), and Q07 before hitting an infrastructure context validation defect at Q08 (`INFRA_FAIL` due to unsealed DSR context).
   - Card draft updated with explicit differentiation and twin-resolution section: the clean rerun embeds the full `qm-dsr-single-configuration` contract and strict sealed-calendar constraints.
   - `card_intake_prescreen` evaluates `NEAR_DUPLICATE` as a warning rather than a blocking reason.
2. **Charter Sections Added:**
   - `## FTMO Fit & Venue Hypothesis`: 5% daily limit, 10% total drawdown, mandatory fail-closed news blackout (`qm_news_stale_max_hours = 336`), D1 swing horizon.
   - `## Falsification / Kill Criteria`: 4 concrete kill triggers (PF <= 1.15, cadence < 5 trades/yr/symbol, MAE > 2.0x ATR before exit, news window slippage > 10%).
   - `## Q08 and Q11 Crisis & News Risk`: SMA(200) trend filter prevents buying falling knives in market crashes; safety hard stop (2.0*ATR, 150-pip cap) bounds tail risk; DSR single configuration eliminates mutable context defects.
3. **Frontmatter & Consistency Alignment:**
   - `r1_track_record` aligned to `PASS` in frontmatter and body table.
   - Schema and R-gate checks verified clean with 0 warnings.

## 3. Verification Evidence

- `tools/strategy_farm/card_intake_prescreen.py --card "D:/QM/strategy_farm/artifacts/cards_review/PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md"`:
  `verdict = KEEP`, `reasons = []`, `missing_sections = []`, `missing_feeds = []`.
- `farmctl.strategy_card_schema_issues`: `[]` (0 issues).
- `farmctl.strategy_card_r_gate_consistency`: `ok = True`, 0 errors, 0 warnings.
- `card_heading_language.check_card_heading_language`: `ok = True`, 0 unmapped headings.

## 4. Handoff

The Strategy Card draft is clean, verified, and placed in `D:/QM/strategy_farm/artifacts/cards_review/PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md`. Per DL-065 capability boundaries, `gemini` hands off the task in `REVIEW` for Codex build intake and G0 approval.
