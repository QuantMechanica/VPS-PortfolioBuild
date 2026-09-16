# Evidence: Second-Chance Wave-2 Retest Specification — Task `f05399de-2945-4ab3-8006-896e5b150b3a`

- **Task ID:** `f05399de-2945-4ab3-8006-896e5b150b3a`
- **Agent:** `gemini`
- **Task Type:** `research_strategy`
- **Priority:** 70
- **Lineage:** `NEW` (append-only clean rerun; origin `QM5_11211`)
- **Second-Chance Reason:** `SCALPING`
- **Second-Chance Status:** `ELIGIBLE_FOR_RECONSIDERATION`
- **Origin EA ID:** `QM5_11211` (`ft-binhv45`)
- **Origin Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
- **Venue Hypothesis:** FTMO (§31): M1 Bollinger capitulation scalp, EURUSD/GBPUSD/USDJPY/XAUUSD, low-swap majors + metal
- **Strategy Card Draft:** `D:/QM/strategy_farm/artifacts/cards_review/PENDING_F05399DE_ft-binhv45.md`
- **Commission Author:** `kimi-interim` (`docs/ops/evidence/2026-09-16_second_chance_wave2/evidence_receipt_second_chance_wave2.md`)
- **Verdict:** `REVIEW_READY`

---

## 1. Executive Summary & Context

Under the Strategy Second-Chance Programme (`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` §5, Wave 2 style-supersession), candidate `QM5_11211` is ranked #1 in the Wave 2 commission batch (priority 79.28, `SCALPING`).

The origin candidate was rejected at G0 on 2026-05-23 under superseded §17 scalping doctrine:
- G0 rejection note: `R2 fail: M1 entry requires closedelta > close*17/1000 (about 1.7% one-minute move), implausible to support >=2 trades/year/symbol on DWX FX/XAU despite inflated 120/year claim.`
- In `farm_state.sqlite`, `work_items` count is 0, `work_item_holds` is 0, and prior agent task count referencing `QM5_11211` was 0.
- Under current doctrine (OWNER directive 3 §14–§18, 2026-09-15), scalping is fully eligible for reconsideration when adhering to bounded risk and platform rules.
- Per programme policy, historical card rows and verdicts remain immutable read-only evidence. This retest establishes a clean append-only NEW lineage.

---

## 2. DL-065 Capability Boundary Compliance

Under `framework/registry/agent_capabilities.json` (DL-065 Agent Capability Scopes):
- Agent `gemini` holds `card.draft`, `repo.read`, and `repo.write` grants.
- Agent `gemini` is explicitly denied `registry.reserve_ea_ids`.
- Accordingly, this research task creates the Strategy Card Draft under pending identity `PENDING_F05399DE` in `D:/QM/strategy_farm/artifacts/cards_review/`.
- The permanent numeric EA ID will be atomically reserved via `farmctl reserve-ea-ids` by the build controller / Codex upon build task creation.

---

## 3. Strategy Specification & Guardrail Compliance

The drafted card `PENDING_F05399DE_ft-binhv45.md` specifies:
1. **Mechanical Rules:**
   - M1 timeframe on `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`.
   - Bollinger Bands(40, 2) on M1 close.
   - Long entry trigger: lower band breach (`Close[1] < lower[1]`), negative bar close, band expansion (`bbdelta > Close * 7/1000`), bar velocity (`closedelta > Close * threshold`), and small lower tail (`tail < bbdelta * 25/1000`).
   - Long-only capitulation thesis (source has no sell signal).
   - Profit target: +1.25% (or +1.5 * ATR(14, M1)).
   - Stop Loss: Safety stop Min(1.5 * ATR(14, M1), 5% price stop).
   - Spread cap: Spread <= 6% of planned stop distance.
2. **Build Guardrails:**
   - `qm_news_stale_max_hours = 336` (strictly <= 336 hours).
   - Backtest sets configured with `RISK_FIXED = 1000` and `RISK_PERCENT = 0`.
   - Weekend flattening enforced: `qm_friday_close_enabled = true`, broker hour 21.
   - Maximum 1 position per magic / symbol (no gridding, martingale, or averaging down).
3. **Cadence & Volatility Calibration:**
   - Resolves the historical cadence note: the source crypto default of 17 per mille (1.7% in 1 minute) is retained as baseline, but parameter sweep range `[3, 7, 17]` is specified so that on FX majors and Gold, realistic volatility spikes (3–7 per mille) generate expected cadence of 30–80 trades/year/symbol.

---

## 4. Verification

1. **Card Parsing & Schema Verification:**
   - Frontmatter in `D:/QM/strategy_farm/artifacts/cards_review/PENDING_F05399DE_ft-binhv45.md` parsed cleanly via `farmctl.parse_card_frontmatter()`.
   - `farmctl.strategy_card_schema_issues()` returned 0 issues (`[]`).
   - `farmctl.strategy_card_r_gate_consistency()` returned `ok=True`, 0 errors.
   - `card_heading_language.check_card_heading_language()` returned `ok=True`, 0 unmapped headings.
2. **Provenance & Receipt Alignment:**
   - Matches commission record in `docs/ops/evidence/2026-09-16_second_chance_wave2/evidence_receipt_second_chance_wave2.md`.
   - Register inputs SHA256 verified (`37ec3be93ae709404a2c829429084cdf9266ed8b916bb29d780adad69fb15982`).
