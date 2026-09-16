# Evidence: Second-Chance Wave-2 Retest Specification — Task `8eaa5bf9-dd37-446a-a60c-17bf0ac28ed1`

- **Task ID:** `8eaa5bf9-dd37-446a-a60c-17bf0ac28ed1`
- **Agent:** `gemini`
- **Task Type:** `research_strategy`
- **Priority:** 70
- **Lineage:** `NEW` (append-only clean rerun; origin `QM5_11855`)
- **Second-Chance Reason:** `SCALPING`
- **Second-Chance Status:** `ELIGIBLE_FOR_RECONSIDERATION`
- **Origin EA ID:** `QM5_11855` (`blade-m5-ema-zone-scalp`)
- **Origin Source ID:** `7f6f2831-ea66-58f6-a7ff-a8c89a44803d`
- **Venue Hypothesis:** FTMO (§31): independent M5 EMA-zone trend scalp, EURUSD, London/NY session windows
- **Strategy Card Draft:** `D:/QM/strategy_farm/artifacts/cards_review/PENDING_8EAA5BF9_blade-m5-ema-zone-scalp.md`
- **Commission Author:** `kimi-interim` (`docs/ops/evidence/2026-09-16_second_chance_wave2/evidence_receipt_second_chance_wave2.md`)
- **Verdict:** `REVIEW_READY`

---

## 1. Executive Summary & Context

Under the Strategy Second-Chance Programme (`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` §5, Wave 2 style-supersession), candidate `QM5_11855` is ranked #2 in the Wave 2 commission batch (priority 79.28, `SCALPING`).

The origin candidate was rejected at G0 on 2026-05-24 under superseded §17 scalping doctrine:
- G0 rejection note: `R2 FAIL: card lacks required expected_trade_frequency / expected_trades_per_year_per_symbol estimate, so G0 cannot validate cadence despite mechanical EMA zone scalp rules.`
- In `farm_state.sqlite`, `work_items` count is 0, `work_item_holds` is 0, and prior agent task count referencing `QM5_11855` was 0.
- Under current doctrine (OWNER directive 3 §14–§18, 2026-09-15), scalping is fully eligible for reconsideration when adhering to bounded risk and platform rules.
- Per programme policy, historical card rows and verdicts remain immutable read-only evidence. This retest establishes a clean append-only NEW lineage.

---

## 2. DL-065 Capability Boundary Compliance

Under `framework/registry/agent_capabilities.json` (DL-065 Agent Capability Scopes):
- Agent `gemini` holds `card.draft`, `repo.read`, and `repo.write` grants.
- Agent `gemini` is explicitly denied `registry.reserve_ea_ids`.
- Accordingly, this research task creates the Strategy Card Draft under pending identity `PENDING_8EAA5BF9` in `D:/QM/strategy_farm/artifacts/cards_review/`.
- The permanent numeric EA ID will be atomically reserved via `farmctl reserve-ea-ids` by the build controller / Codex upon build task creation.

---

## 3. Strategy Specification & Guardrail Compliance

The drafted card `PENDING_8EAA5BF9_blade-m5-ema-zone-scalp.md` specifies:
1. **Mechanical Rules:**
   - M5 timeframe on `EURUSD.DWX`.
   - Trend Filter: `EMA(10) > EMA(21) > EMA(50)` for Long; `EMA(10) < EMA(21) < EMA(50)` for Short.
   - Dynamic Entry Corridor: Retracement into the `EMA(10)`–`EMA(21)` zone reaching at least halfway (`mid_zone = (EMA10 + EMA21) / 2.0`).
   - Session Filter: Restricted to high-liquidity London (07:00–12:00 GMT) and NY (13:00–17:00 GMT) windows.
   - Spread Cap: Maximum 15 points (1.5 pips) on 5-digit broker.
   - Profit Target: Fixed 10 pips.
   - Stop Loss: Hard stop of 5 pips + current spread.
   - Break-Even: Move SL to entry upon reaching +5 pips unrealised floating profit.
2. **Build Guardrails:**
   - `qm_news_stale_max_hours = 336` (strictly <= 336 hours).
   - Backtest sets configured with `RISK_FIXED = 1000` and `RISK_PERCENT = 0`.
   - Weekend flattening enforced: `qm_friday_close_enabled = true`, broker hour 21.
   - Maximum 1 position per magic / symbol (no gridding, martingale, or averaging down).
3. **Cadence Formulation:**
   - Resolves the historical intake deficiency by providing an explicit, realistic cadence model: `expected_trades_per_year_per_symbol: 180`, with conservative range of 150–250 trades/year on `EURUSD.DWX`.

---

## 4. Verification

1. **Card Parsing & Schema Verification:**
   - Frontmatter in `D:/QM/strategy_farm/artifacts/cards_review/PENDING_8EAA5BF9_blade-m5-ema-zone-scalp.md` parsed cleanly via `farmctl.parse_card_frontmatter()`.
   - `farmctl.strategy_card_schema_issues()` returned 0 issues (`[]`).
   - `farmctl.strategy_card_r_gate_consistency()` returned `ok=True`, 0 errors.
   - `card_heading_language.check_card_heading_language()` returned `ok=True`, 0 unmapped headings.
2. **Provenance & Receipt Alignment:**
   - Matches commission record in `docs/ops/evidence/2026-09-16_second_chance_wave2/evidence_receipt_second_chance_wave2.md`.
   - Register inputs SHA256 verified (`37ec3be93ae709404a2c829429084cdf9266ed8b916bb29d780adad69fb15982`).
