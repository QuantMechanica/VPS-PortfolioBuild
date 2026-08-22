# QM5_1425 Build EA Evidence — 2026-08-22

**Task ID:** 77bb60df-1c46-46db-b0d5-3560e2949375 (build_ea, priority 50, agent gemini).  
**EA:** QM5_1425_classical-triple-bottom-reversal-h4.  
**Artifact Path:** C:/QM/repo/docs/ops/evidence/77bb60df_qm5_1425_classical-triple-bottom-reversal-h4_build_ea_2026-08-22.md.  
**Strategy Card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_1425_classical-triple-bottom-reversal-h4.md (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Classical Edwards & Magee / Bulkowski Triple Bottom Reversal (H4).
  - Six structural gates across [60, 200] H4-bar lookback window:
    1. **Three Troughs (T1, T2, T3)**: Williams 3-bar fractal pivot detection, spacing $\in [25, 120]$ bars.
    2. **Equal Depth**: $\max(T_1, T_2, T_3) - \min(T_1, T_2, T_3) \le 0.50 \cdot ATR(14, H4)$.
    3. **Two Intervening Peaks (P12, P23)**: $\min(P_{12}, P_{23}) - \max(T) \ge 1.50 \cdot ATR(14, H4)$, $|P_{12} - P_{23}| \le 0.40 \cdot ATR(14, H4)$.
    4. **Horizontal Neckline**: $\text{neckline} = (P_{12} + P_{23}) / 2.0$, slope $\le 0.05 \cdot ATR/\text{bar}$.
    5. **Prior Downtrend Context**: 40-bar linear regression slope ending at T1 $\le -0.10 \cdot ATR/\text{bar}$.
    6. **No Prior Neckline Break**: No H4 close $> \text{neckline} + 0.30 \cdot ATR$ between T3 and trigger bar.
  - **Trigger**: Closed H4 bar break $\ge \text{neckline} + 0.40 \cdot ATR(14, H4)$.
  - **Exits & Risk**: Measured move TP $= \text{entry} + (\text{neckline} - \text{mean}(T))$, TP1 partial close 50% at 50% measured move with SL to BE, pattern failure exit within 8 bars if close $< \text{neckline} - 0.30 \cdot ATR$, 30-bar time stop. Initial SL at $\min(T) - 0.40 \cdot ATR$ (capped at .0 \cdot ATR$).
  - **Macro Bias**: D1 SMA(50) flat or rising at entry bar.
- **Framework V5 Integration**:
  - Full QM_Common.mqh integration with QM_NewsTemporalMode (QM_NEWS_TEMPORAL_PRE30_POST30), QM_NewsComplianceProfile (QM_NEWS_COMPLIANCE_DXZ), and qm_news_stale_max_hours = 336.
  - Risk parameters: RISK_FIXED = 1000.0, RISK_PERCENT = 0.0.

---

## 2. Registry & Verification Status

- **Registries**:
  - framework/registry/ea_id_registry.csv: registered row 1425,classical-triple-bottom-reversal-h4,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Development,2026-05-19,,,.
  - framework/registry/magic_numbers.csv: registered 14 symbol slots (0..13: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX, SP500.DWX, XAUUSD.DWX, XTIUSD.DWX).
  - framework/include/QM/QM_MagicResolver.mqh: regenerated cleanly (17,761 rows kept, 0 dropped).
- **SPEC Document**:
  - framework/EAs/QM5_1425_classical-triple-bottom-reversal-h4/SPEC.md generated and validated.
- **Build Guardrails & Hardening**:
  - validate_build_guardrails.py framework/EAs/QM5_1425_classical-triple-bottom-reversal-h4: PASS (0 findings across 15 files).
  - build_gate_hardening.py: PASS (0 failures across D3-D10 gates).
- **P2 Setfiles**:
  - Generated all 14 backtest setfiles under framework/EAs/QM5_1425_classical-triple-bottom-reversal-h4/sets/.

---

## 3. Router Handoff

- Build JSON artifact written to D:/QM/strategy_farm/artifacts/builds/77bb60df-1c46-46db-b0d5-3560e2949375.json.
- Task 77bb60df-1c46-46db-b0d5-3560e2949375 updated to REVIEW for mandatory Codex review.
