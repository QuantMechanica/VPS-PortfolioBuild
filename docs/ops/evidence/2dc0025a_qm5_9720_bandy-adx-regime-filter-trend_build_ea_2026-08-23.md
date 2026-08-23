# QM5_9720 Build EA Evidence — 2026-08-23

**Task ID:** dc0025a-7b2d-472c-ac65-58c806c5a768\ (\uild_ea\, priority 50, agent \gemini\).  
**EA:** \QM5_9720_bandy-adx-regime-filter-trend\.  
**Artifact Path:** \C:/QM/repo/docs/ops/evidence/2dc0025a_qm5_9720_bandy-adx-regime-filter-trend_build_ea_2026-08-23.md\.  
**Strategy Card:** \ramework/EAs/QM5_9720_bandy-adx-regime-filter-trend/docs/strategy_card.md\ (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Howard Bandy ADX-Regime-Filter Trend (D1 timeframe, long/short).
  - Trend substrate: SMA(20) and SMA(50) moving average crossover on daily bars.
  - Regime filter: Wilder ADX(14) >= 25.0 trend-strength gate on closed bar 1.
  - Entry mechanics:
    - Long entry: fast SMA(20) crosses above slow SMA(50) on closed bar 1 AND ADX(14) >= 25.0.
    - Short entry: fast SMA(20) crosses below slow SMA(50) on closed bar 1 AND ADX(14) >= 25.0.
  - Exits:
    - Ratcheting trailing stop: .5 * ATR(14)\ trailing stop adjusted on daily new-bar cadence.
    - Hard time stop: 60 trading days max hold via \QM_TM_HeldPeriods\.
    - Reverse on opposite crossover + ADX gate.
- **Framework V5 Integration**:
  - Full \QM_Common.mqh\ integration with \QM_NewsTemporalMode\ (\QM_NEWS_TEMPORAL_PRE30_POST30\), \QM_NewsComplianceProfile\ (\QM_NEWS_COMPLIANCE_DXZ\), and \qm_news_stale_max_hours = 336\.
  - Risk model compliant with HR4: \RISK_FIXED = 1000.0\, \RISK_PERCENT = 0.0\.

---

## 2. Registry & Verification Status

- **Registries**:
  - \ramework/registry/magic_numbers.csv\: registered 13 symbol slots (0: GDAXI.DWX, 1: NDX.DWX, 2: SP500.DWX, 3: UK100.DWX, 4: WS30.DWX, 5: XAUUSD.DWX, 6: EURUSD.DWX, 7: GBPUSD.DWX, 8: USDJPY.DWX, 9: USDCHF.DWX, 10: AUDUSD.DWX, 11: USDCAD.DWX, 12: NZDUSD.DWX).
  - \ramework/include/QM/QM_MagicResolver.mqh\: updated and verified with active registry rows.
- **SPEC Document**:
  - \ramework/EAs/QM5_9720_bandy-adx-regime-filter-trend/SPEC.md\ created and aligned with approved strategy card.
- **Build Guardrails**:
  - \alidate_build_guardrails.py framework/EAs/QM5_9720_bandy-adx-regime-filter-trend\: \PASS\ (0 findings across 14 files).
- **P2 Setfiles**:
  - 13 backtest setfiles validated under \ramework/EAs/QM5_9720_bandy-adx-regime-filter-trend/sets/\.

---

## 3. Router Handoff

- Build JSON artifact written to \D:/QM/strategy_farm/artifacts/builds/2dc0025a-7b2d-472c-ac65-58c806c5a768.json\.
- Task dc0025a-7b2d-472c-ac65-58c806c5a768\ transitioned to \REVIEW\ for mandatory Codex review.
