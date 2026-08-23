# QM5_9965 Build EA Draft Evidence — 2026-08-23

**Task ID:** 2321b9ed-3a30-4690-a15a-babe2188ae6f (uild_ea, priority 50, agent gemini).  
**EA ID:** QM5_9965  
**Slug:** andy-index-gap-and-go-continuation  
**Strategy Card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_9965_bandy-index-gap-and-go-continuation.md (G0 APPROVED).  
**Target Directory:** C:/QM/repo/framework/EAs/QM5_9965_bandy-index-gap-and-go-continuation  

---

## 1. Strategy Implementation & Compliance

- **Strategy Thesis**: Howard B. Bandy, *Quantitative Technical Analysis* (2015). Opening gap-and-go continuation on D1 index series with same-direction close commitment and 200-SMA regime.
- **Entry Rules**:
  - Gap: open[1] - close[2] evaluated at next bar open after gap bar closes.
  - Gap significance: |gap| >= 0.5 * ATR(14)[2] (shift=2 ATR avoids lookahead on gap bar).
  - Long: gap > 0 AND close[1] > open[1] (bullish commitment) AND close[1] > SMA(200)[1].
  - Short: gap < 0 AND close[1] < open[1] (bearish commitment) AND close[1] < SMA(200)[1].
  - Anti-cluster: minimum 2 D1 bars between same-direction entries.
- **Exit Rules**:
  - Primary: Opposite-direction bar close (BUY exits on close < open; SELL exits on close > open).
  - Time stop: 5 D1 trading days maximum hold.
  - Catastrophic Stop Loss: 1.5 * ATR(14) from entry.
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
