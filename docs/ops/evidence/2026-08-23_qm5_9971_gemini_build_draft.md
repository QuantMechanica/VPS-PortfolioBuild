# QM5_9971 Build EA Draft Evidence — 2026-08-23

**Task ID:** 9afcf2a0-2f75-46d5-9707-8a42834eda67 (uild_ea, priority 50, agent gemini).  
**EA ID:** QM5_9971  
**Slug:** andy-dpo-zero-cross-mr-index  
**Strategy Card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_9971_bandy-dpo-zero-cross-mr-index.md (G0 APPROVED).  
**Target Directory:** C:/QM/repo/framework/EAs/QM5_9971_bandy-dpo-zero-cross-mr-index  

---

## 1. Strategy Implementation & Compliance

- **Strategy Thesis**: Howard B. Bandy, *Quantitative Technical Analysis* (2015). Detrended Price Oscillator (DPO) zero-cross mean-reversion with 200-SMA regime gate and opposite-cross/time/ATR exits.
- **Entry Rules**:
  - DPO(20) calculated via lagged-SMA subtraction (-11$ backward lag): dpo = close[t] - sma20[t-11].
  - Long: dpo[1] >= 0 AND dpo[2] < 0 AND close[1] > SMA(200)[1].
  - Short: dpo[1] <= 0 AND dpo[2] > 0 AND close[1] < SMA(200)[1].
  - Crossover significance filter: |dpo[1]| >= 0.1 * ATR(14)[1].
  - Anti-cluster: minimum 5 D1 bars between same-direction entries.
- **Exit Rules**:
  - Primary: Opposite DPO zero-cross on closed bar.
  - Time stop: 15 D1 bars maximum hold.
  - Catastrophic Stop Loss: 2.5 * ATR(14) from entry.
- **Framework Corset**:
  - Full V5 framework wiring with QM_Common.mqh.
  - News gate: qm_news_stale_max_hours = 336, qm_news_temporal = QM_NEWS_TEMPORAL_PRE30_POST30, qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ.
  - One position per magic; 
eq.symbol_slot = qm_magic_slot_offset explicitly wired.

---

## 2. Verification & Guardrails

- uild_gate_hardening.py: **PASS** (0 failures).
- alidate_build_guardrails.py: **PASS** (14/14 files checked, 0 findings).
- alidate_spec_doc.py: **PASS** (SPEC.md generated and fully compliant).
- magic_numbers.csv: 13 symbols registered (slots 0-12: GDAXI, NDX, SP500, UK100, WS30, XAUUSD, EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD).
- QM_MagicResolver.mqh: Regenerated and active.
- Setfiles: All 13 backtest setfiles populated with strategy parameters and matching uild_hash.

---

## 3. Status & Handoff

- MQ5 source, SPEC.md, and all 13 backtest setfiles are drafted and verified.
- Direct ad-hoc compilation is safely refused by include_mirror.py because factory terminals are active.
- Ready for governed compilation and mandatory Codex review.
