# QM5_9727 Build EA Evidence — 2026-08-23

**Task ID:** \d820be5a-675c-411f-b761-6c09aad2b811\ (\uild_ea\, priority 50, agent \gemini\).  
**EA:** \QM5_9727_bandy-atr-ratio-compression-breakout-trend\.  
**Artifact Path:** \C:/QM/repo/docs/ops/evidence/d820be5a_qm5_9727_bandy-atr-ratio-compression-breakout-trend_build_ea_2026-08-23.md\.  
**Strategy Card:** \ramework/EAs/QM5_9727_bandy-atr-ratio-compression-breakout-trend/docs/strategy_card.md\ (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Howard Bandy ATR-Ratio Compression Breakout Trend (D1 timeframe, long/short).
  - Volatility-regime compression construct: ATR(5)/ATR(20) ratio on daily bars.
  - Compression flag: \compressed = (ratio <= 0.65)\ on prior or current closed bar.
  - Breakout mechanics:
    - Long entry: closed bar close > 20-bar Donchian channel high (highest high of 20 closed bars prior to bar 1).
    - Short entry: closed bar close < 20-bar Donchian channel low (lowest low of 20 closed bars prior to bar 1).
  - Exits:
    - Ratcheting trailing stop: .5 * ATR(14)\ trailing stop adjusted on daily new-bar cadence.
    - Hard time stop: 45 trading days max hold via \QM_TM_HeldPeriods\.
    - Reverse on opposite channel breakout signal.
- **Framework V5 Integration**:
  - Full \QM_Common.mqh\ integration with \QM_NewsTemporalMode\ (\QM_NEWS_TEMPORAL_PRE30_POST30\), \QM_NewsComplianceProfile\ (\QM_NEWS_COMPLIANCE_DXZ\), and \qm_news_stale_max_hours = 336\.
  - Risk model compliant with HR4: \RISK_FIXED = 1000.0\, \RISK_PERCENT = 0.0\.

---

## 2. Registry & Verification Status

- **Registries**:
  - \ramework/registry/magic_numbers.csv\: registered 13 symbol slots (0: GDAXI.DWX, 1: NDX.DWX, 2: SP500.DWX, 3: UK100.DWX, 4: WS30.DWX, 5: XAUUSD.DWX, 6: EURUSD.DWX, 7: GBPUSD.DWX, 8: USDJPY.DWX, 9: USDCHF.DWX, 10: AUDUSD.DWX, 11: USDCAD.DWX, 12: NZDUSD.DWX).
  - \ramework/include/QM/QM_MagicResolver.mqh\: updated and verified with active registry rows.
- **SPEC Document**:
  - \ramework/EAs/QM5_9727_bandy-atr-ratio-compression-breakout-trend/SPEC.md\ created and aligned with approved strategy card.
- **Build Guardrails**:
  - \alidate_build_guardrails.py framework/EAs/QM5_9727_bandy-atr-ratio-compression-breakout-trend\: \PASS\ (0 findings across 14 files).
- **P2 Setfiles**:
  - 13 backtest setfiles validated under \ramework/EAs/QM5_9727_bandy-atr-ratio-compression-breakout-trend/sets/\.

---

## 3. Router Handoff

- Build JSON artifact written to \D:/QM/strategy_farm/artifacts/builds/d820be5a-675c-411f-b761-6c09aad2b811.json\.
- Task \d820be5a-675c-411f-b761-6c09aad2b811\ transitioned to \REVIEW\ for mandatory Codex review.
