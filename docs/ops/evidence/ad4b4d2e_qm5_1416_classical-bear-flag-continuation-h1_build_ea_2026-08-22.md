# QM5_1416 Build EA Evidence — 2026-08-22

**Task ID:** d4b4d2e-3fb7-48ea-a424-09d85a616e34 (uild_ea, priority 50, agent gemini).  
**EA:** QM5_1416_classical-bear-flag-continuation-h1.  
**Artifact Path:** C:/QM/repo/docs/ops/evidence/ad4b4d2e_qm5_1416_classical-bear-flag-continuation-h1_build_ea_2026-08-22.md.  
**Strategy Card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_1416_classical-bear-flag-continuation-h1.md (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Classical Edwards & Magee Bear Flag Continuation (H1).
  - Three-phase deterministic pattern detection: **flagpole down → flag-channel up → breakdown**.
  - Williams-fractal 3-bar pivot detection on H1.
  - Phase 1 Flagpole: Bearish impulse leg {pole} \in [12, 36]$ H1 bars with cumulative move $\ge 4.0 \cdot ATR$, slope $\le -0.20 \cdot ATR/	ext{bar}$, pullback bars $\le 35\%$, volume surge $\ge 1.20	imes$ prior 60-bar volume.
  - Phase 2 Flag Channel: Consolidation window {flag} \in [5, 18]$ H1 bars, counter-slope $\in [+0.005, +0.10] \cdot ATR/	ext{bar}$, containment $\ge 80\%$, max retracement $\le 50\%$ of flagpole height, volume contraction $\le 0.80	imes$ flagpole volume.
  - Phase 3 Breakdown Trigger: H1 close $\le lower\_TL(t) - 0.40 \cdot ATR$.
  - Exits & Risk: Initial SL at \_TL(t_{break}) + 0.30 \cdot ATR$ (capped at .50 \cdot ATR$), TP at measured move  - pole\_height$, partial close 50% at 50% measured move with SL to BE, pattern failure exit within 6 bars, time stop at 24 H1 bars.
  - Macro Bias: H4 SMA(200) falling AND H1 close < H4 SMA(200).
- **Framework V5 Integration**:
  - Full QM_Common.mqh integration with QM_NewsTemporalMode (QM_NEWS_TEMPORAL_PRE30_POST30), QM_NewsComplianceProfile (QM_NEWS_COMPLIANCE_DXZ), and qm_news_stale_max_hours = 336.
  - Risk parameters: RISK_FIXED = 1000.0, RISK_PERCENT = 0.0.

---

## 2. Registry & Verification Status

- **Registries**:
  - ramework/registry/ea_id_registry.csv: updated row 1416,classical-bear-flag-continuation-h1,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Development,2026-05-19,,,.
  - ramework/registry/magic_numbers.csv: registered 14 symbol slots (0..13: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX, SP500.DWX, XAUUSD.DWX, XTIUSD.DWX).
  - ramework/include/QM/QM_MagicResolver.mqh: regenerated cleanly (17732 rows kept, 0 dropped).
- **SPEC Document**:
  - ramework/EAs/QM5_1416_classical-bear-flag-continuation-h1/SPEC.md generated and validated.
- **Build Guardrails**:
  - alidate_build_guardrails.py framework/EAs/QM5_1416_classical-bear-flag-continuation-h1: PASS (0 findings across 15 files).
- **P2 Setfiles**:
  - Generated all 14 backtest setfiles under ramework/EAs/QM5_1416_classical-bear-flag-continuation-h1/sets/.

---

## 3. Router Handoff

- Build JSON artifact written to D:/QM/strategy_farm/artifacts/builds/ad4b4d2e-3fb7-48ea-a424-09d85a616e34.json.
- Task d4b4d2e-3fb7-48ea-a424-09d85a616e34 updated to REVIEW for mandatory Codex review.
