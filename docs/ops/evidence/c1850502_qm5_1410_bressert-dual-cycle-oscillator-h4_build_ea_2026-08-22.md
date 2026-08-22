# QM5_1410 Build EA Evidence — 2026-08-22

**Task ID:** c1850502-ac54-4fc4-b397-5e54e87d1eb6 (uild_ea, priority 50, agent gemini).  
**EA:** QM5_1410_bressert-dual-cycle-oscillator-h4.  
**Artifact Path:** C:/QM/repo/docs/ops/evidence/c1850502_qm5_1410_bressert-dual-cycle-oscillator-h4_build_ea_2026-08-22.md.  
**Strategy Card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_1410_bressert-dual-cycle-oscillator-h4.md (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Walter Bressert Dual-Cycle Oscillator (DSS, H4).
  - Double-Smoothed Stochastic (DSS) calculations:
    - Short-cycle DSS ({short}=8, m_{short}=3$) capturing the 3-5 day H4 cycle.
    - Intermediate-cycle DSS ({long}=21, m_{long}=7$) capturing the 12-21 day H4 cycle.
  - TimingBand thresholds: Oversold $\le 30$, Overbought $\ge 70$, Midline $= 50$.
  - Long Entry Setup:
    1. Short-cycle setup: {short} \le 30$ for at least 2 of prior 3 closed bars.
    2. Short-cycle bullish cross: {short}[1] > DSS_{short}[2]$ and {short}[2] \le DSS_{short}[3]$.
    3. Intermediate-cycle alignment: {long}[1] \le 50$ and {long}[1] > DSS_{long}[4]$.
    4. Price momentum: [1] > close[4]$.
    5. Macro-bias gate: [1] > SMA(50, D1)$.
  - Short Entry Setup:
    1. Short-cycle setup: {short} \ge 70$ for at least 2 of prior 3 closed bars.
    2. Short-cycle bearish cross: {short}[1] < DSS_{short}[2]$ and {short}[2] \ge DSS_{short}[3]$.
    3. Intermediate-cycle alignment: {long}[1] \ge 50$ and {long}[1] < DSS_{long}[4]$.
    4. Price momentum: [1] < close[4]$.
    5. Macro-bias gate: [1] < SMA(50, D1)$.
  - Exits & Risk:
    - Initial SL at .50 \cdot ATR(14, H4)$.
    - TP1 at .50 \cdot ATR(14, H4)$ with 50% partial exit and SL moved to BE.
    - TP2 oscillator exit: close remaining 50% when {short} \ge 70$ (Long) / $\le 30$ (Short).
    - Pattern-failure exit: hard close if both cycles turn against position in loss.
    - Time stop: 30 H4 bars.
- **Framework V5 Integration**:
  - Full QM_Common.mqh integration with QM_NewsTemporalMode (QM_NEWS_TEMPORAL_PRE30_POST30), QM_NewsComplianceProfile (QM_NEWS_COMPLIANCE_DXZ), and qm_news_stale_max_hours = 336.
  - Risk parameters: RISK_FIXED = 1000.0, RISK_PERCENT = 0.0.

---

## 2. Registry & Verification Status

- **Registries**:
  - ramework/registry/ea_id_registry.csv: updated row 1410,bressert-dual-cycle-oscillator-h4,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Development,2026-05-19,,,.
  - ramework/registry/magic_numbers.csv: registered 14 symbol slots (0..13: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX, SP500.DWX, XAUUSD.DWX, XTIUSD.DWX).
  - ramework/include/QM/QM_MagicResolver.mqh: regenerated cleanly (17732 rows kept, 0 dropped).
- **SPEC Document**:
  - ramework/EAs/QM5_1410_bressert-dual-cycle-oscillator-h4/SPEC.md generated and validated.
- **Build Guardrails**:
  - alidate_build_guardrails.py framework/EAs/QM5_1410_bressert-dual-cycle-oscillator-h4: PASS (0 findings across 15 files).
- **P2 Setfiles**:
  - Generated all 14 backtest setfiles under ramework/EAs/QM5_1410_bressert-dual-cycle-oscillator-h4/sets/.

---

## 3. Router Handoff

- Build JSON artifact written to D:/QM/strategy_farm/artifacts/builds/c1850502-ac54-4fc4-b397-5e54e87d1eb6.json.
- Task c1850502-ac54-4fc4-b397-5e54e87d1eb6 updated to REVIEW for mandatory Codex review.
