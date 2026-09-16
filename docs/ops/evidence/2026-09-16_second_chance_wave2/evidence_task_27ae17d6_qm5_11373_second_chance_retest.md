# Evidence: Second-Chance Wave-2 Retest Specification — Task `27ae17d6-beb8-416c-9c25-fade17603fe9`

- **Task ID:** `27ae17d6-beb8-416c-9c25-fade17603fe9`
- **Agent:** `gemini`
- **Task Type:** `research_strategy`
- **Priority:** 70
- **Lineage:** `NEW` (append-only clean rerun; origin `QM5_11373`)
- **Second-Chance Reason:** `MULTI_POSITION`
- **Second-Chance Status:** `ELIGIBLE_FOR_RECONSIDERATION`
- **Origin EA ID:** `QM5_11373` (`100pips-daily-range-bracket-usdjpy`)
- **Origin Source ID:** `e1222215-8e37-5add-90ba-87c1801691bf`
- **Venue Hypothesis:** FTMO (§31) Asian-session daily-range density + DXZ (§32) diversification: H1 set-and-forget daily-range bracket, USDJPY
- **Strategy Card Draft:** `D:/QM/strategy_farm/artifacts/cards_review/PENDING_27AE17D6_100pips-daily-range-bracket-usdjpy.md`
- **Commission Author:** `kimi-interim` (`docs/ops/evidence/2026-09-16_second_chance_wave2/evidence_receipt_second_chance_wave2.md`)
- **Verdict:** `REVIEW_READY`

---

## 1. Executive Summary & Context

Under the Strategy Second-Chance Programme (`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` §5, Wave 2 style-supersession), candidate `QM5_11373` was commissioned for second-chance retest under task `27ae17d6-beb8-416c-9c25-fade17603fe9` (priority 70, `MULTI_POSITION`).

The origin candidate was rejected at G0 on 2026-05-23 under superseded §17/§20 multi-position doctrine:
- G0 rejection note: `R4 FAIL: card requires three simultaneous same-side pending orders/positions for tiered TPs without explicit per-slot magic allocation, conflicting with HR14 one-position-per-magic; R1/R2/R3 otherwise pass.`
- In `farm_state.sqlite`, `work_items` count is 0, `work_item_holds` is 0, and prior agent task count referencing `QM5_11373` was 0.
- Under current doctrine (Strategy Second-Chance Programme §5.1, Wave 2), multi-position tiered take profits are fully eligible when implemented with explicit per-slot magic allocation satisfying HR14 (one position per magic number).
- Per programme policy, historical card rows and verdicts remain immutable read-only evidence. This retest establishes a clean append-only NEW lineage.

---

## 2. DL-065 Capability Boundary Compliance

Under `framework/registry/agent_capabilities.json` (DL-065 Agent Capability Scopes):
- Agent `gemini` holds `card.draft`, `repo.read`, and `repo.write` grants.
- Agent `gemini` is explicitly denied `registry.reserve_ea_ids`.
- Accordingly, this research task creates the Strategy Card Draft under pending identity `PENDING_27AE17D6` in `D:/QM/strategy_farm/artifacts/cards_review/`.
- The permanent numeric EA ID will be atomically reserved via `farmctl reserve-ea-ids` by the build controller / Codex upon build task creation.

---

## 3. Strategy Specification & Guardrail Compliance

The drafted card `PENDING_27AE17D6_100pips-daily-range-bracket-usdjpy.md` specifies:
1. **Mechanical Rules:**
   - H1 timeframe on `USDJPY.DWX` (extension candidates: `GBPJPY.DWX`, `EURJPY.DWX`).
   - Daily 24-hour range measured from 18:00 EST to 18:00 EST (~22:00/23:00 broker time, NY close).
   - Range filters: Skip placement if 24h range > 150 pips or < 30 pips; skip Monday placement.
   - Bracket placement at 19:00 EST (Asian session open): Buy Stop at `Daily_High + 7 pips`, Sell Stop at `Daily_Low - 7 pips`.
   - OCO logic: Any filled buy order cancels all sell pending orders; any filled sell order cancels all buy pending orders.
   - Order expiration: Cancel untriggered pending orders after 8 hours (03:00 EST / 07:00 broker time).
2. **Multi-Slot Magic Allocation Architecture (Resolving HR14):**
   - Directly resolves the historical G0 blocker by partitioning the 3 tiered TP legs into explicit per-slot magic numbers:
     - `Slot 1 (Tier 1)`: `MAGIC_BASE + 1` (TP +15 pips, SL -25 pips, R:R = 0.6)
     - `Slot 2 (Tier 2)`: `MAGIC_BASE + 2` (TP +35 pips, SL -25 pips, R:R = 1.4)
     - `Slot 3 (Tier 3)`: `MAGIC_BASE + 3` (TP +50 pips, SL -25 pips, R:R = 2.0)
   - Each magic number manages strictly at most 1 position at any time, satisfying HR14 (one position per magic number).
3. **Build Guardrails:**
   - `qm_news_stale_max_hours = 336` (strictly <= 336 hours).
   - Backtest sets configured with `RISK_FIXED = 1000` total ($333.33 allocated risk per slot) and `RISK_PERCENT = 0`.
   - Weekend flattening enforced: `qm_friday_close_enabled = true`, broker hour 21.
   - Zero martingale, zero grid, zero pyramiding.
4. **Cadence Formulation:**
   - `expected_trades_per_year_per_symbol: 200` with 150–220 expected breakout triggers/year on `USDJPY.DWX`.

---

## 4. Verification

1. **Card Parsing & Schema Verification:**
   - Frontmatter in `D:/QM/strategy_farm/artifacts/cards_review/PENDING_27AE17D6_100pips-daily-range-bracket-usdjpy.md` parsed cleanly via `farmctl.parse_card_frontmatter()`.
   - `farmctl.strategy_card_schema_issues()` returned 0 issues (`[]`).
   - `card_heading_language.check_card_heading_language()` returned `ok=True`, 0 unmapped headings.
   - `second_chance_funnel.py` verified progression from `commissioned` to `new-lineage-card` stage (4/4 candidates now at `new-lineage-card`).
2. **Provenance & Receipt Alignment:**
   - Matches commission record in `docs/ops/evidence/2026-09-16_second_chance_wave2/evidence_receipt_second_chance_wave2.md`.
   - Register inputs SHA256 verified (`37ec3be93ae709404a2c829429084cdf9266ed8b916bb29d780adad69fb15982`).
