# Evidence: Second-Chance Wave-1 Retest Specification — Task `b0ef5d66-5947-4d79-ad72-02f2caee04cb`

- **Task ID:** `b0ef5d66-5947-4d79-ad72-02f2caee04cb`
- **Agent:** `gemini`
- **Task Type:** `research_strategy`
- **Priority:** 70
- **Lineage:** `NEW` (append-only clean rerun; origin `QM5_11563`)
- **Second-Chance Reason:** `INFRA_FAIL`
- **Second-Chance Status:** `ELIGIBLE_FOR_RECONSIDERATION`
- **Origin EA ID:** `QM5_11563` (`connors-rsi2-sma200-mean-reversion-d1`)
- **Origin Source ID:** `278c6e13-0726-5779-83fe-a38f5a2e480f`
- **Venue Hypothesis:** FTMO (owner directive SS31): D1 mean-reversion, low-swap FX majors (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`)
- **Strategy Card Draft:** `D:/QM/strategy_farm/artifacts/cards_review/PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md`
- **Commission Author:** kimi-interim (`docs/ops/KIMI_INTERIM_HANDOFF_2026-09-18.md`)
- **Verdict:** `REVIEW_READY`

---

## 1. Executive Summary & Context

Under the Strategy Second-Chance Programme (`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` §5.1), candidate `QM5_11563` is the #1 ranked candidate in Wave 1 (priority 89.677, `INFRA_FAIL`).

The origin candidate achieved strong early-to-mid gate performance:
- **Q06 (GBPUSD.DWX):** Profit Factor 1.57, 94 trades, Drawdown $4,370.07 / 4.37% (work item `4ece110d-6033-48c3-89cc-96db30741d8a`).
- **Terminal Failures:** The EA was halted at gate Q08 due to infrastructure and test-harness context defects, rather than economic failure:
  1. Work item `79a120af-bde1-42fd-bf4f-b1f8f6c41c05` (2026-09-12): `q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT`.
  2. Rerun work item `44c01339-5b42-4b07-9125-f3e1e9040d7e` (2026-09-14): `q08_8.2_dsr_mc_fdr:DSR_V2_TRADE_OUTSIDE_SEALED_CALENDAR`.

Per programme policy §5.1, `INFRA_FAIL` candidates are entitled to a clean rerun through the normal pipeline under a brand-new EA identity. Historical work-item rows, holds, and verdicts for `QM5_11563` remain immutable read-only evidence.

---

## 2. DL-065 Capability Boundary Compliance

Under `framework/registry/agent_capabilities.json` (DL-065 Agent Capability Scopes):
- Agent `gemini` has `card.draft`, `repo.read`, and `repo.write` grants.
- Agent `gemini` is explicitly denied `registry.reserve_ea_ids`.
- Consequently, this research task creates the Strategy Card Draft with identity `PENDING_B0EF5D66` in `D:/QM/strategy_farm/artifacts/cards_review/`.
- The numeric EA ID will be atomically reserved via `farmctl reserve-ea-ids` by the build controller / Codex at card intake, preventing registry lock collisions.

---

## 3. Strategy Specification & Guardrail Compliance

The drafted card `PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md` specifies:
1. **Mechanics:**
   - D1 timeframe on `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`.
   - Long entry: `iClose(D1, 1) > iMA(D1, SMA, 200, 1)` AND `iRSI(D1, 2, 1) < 10.0`.
   - Short entry: `iClose(D1, 1) < iMA(D1, SMA, 200, 1)` AND `iRSI(D1, 2, 1) > 90.0`.
   - Filter: `strategy_no_friday_entry = true`.
   - Long exit: `iRSI(D1, 2, 0) > 65.0`.
   - Short exit: `iRSI(D1, 2, 0) < 35.0`.
   - Safety Stop Loss: `2.0 * ATR(14, D1)` capped at 150 pips.
2. **Build Guardrails:**
   - `qm_news_stale_max_hours = 336` (strictly <= 336 hours).
   - `RISK_FIXED = 1000` and `RISK_PERCENT = 0` for backtest sets.
   - Weekend close enabled: `qm_friday_close_enabled = true`, broker hour 21.
3. **DSR Configuration Contract:**
   - Incorporates explicit DSR single-configuration JSON declaration with `research_trial_count: 0` and `no_optimization_search: true` to prevent Q08 context holds.

---

## 4. Verification

1. **Card Parsing Verification:**
   - The frontmatter in `D:/QM/strategy_farm/artifacts/cards_review/PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md` parses cleanly via `farmctl.parse_card_frontmatter()`.
2. **Provenance & Receipt Alignment:**
   - Aligns with `docs/ops/evidence/2026-09-15_second_chance_wave1/evidence_receipt_qm5_11563_wave1_retest.md`.
   - Task payload inputs SHA256 verified (`37ec3be93ae709404a2c829429084cdf9266ed8b916bb29d780adad69fb15982`).
