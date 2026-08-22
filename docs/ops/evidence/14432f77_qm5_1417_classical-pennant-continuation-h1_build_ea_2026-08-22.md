# QM5_1417 Build EA Evidence — 2026-08-22

**Task ID:** 14432f77-9abf-4032-aefc-278a6bdbad34 (build_ea, priority 50, agent gemini).  
**EA:** QM5_1417_classical-pennant-continuation-h1.  
**Artifact Path:** C:/QM/repo/docs/ops/evidence/14432f77_qm5_1417_classical-pennant-continuation-h1_build_ea_2026-08-22.md.  
**Strategy Card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_1417_classical-pennant-continuation-h1.md (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Classical Edwards & Magee Pennant Continuation (H1).
  - Three-phase deterministic pattern detection: flagpole impulse $\rightarrow$ symmetrical converging pennant $\rightarrow$ breakout continuation.
  - Williams-fractal pivot detection on H1.
  - Phase 1 Flagpole: Bullish/bearish impulse leg $[12, 36]$ H1 bars with cumulative move $\ge 4.0 \cdot ATR$, slope $\ge 0.20 \cdot ATR/\text{bar}$, pullback $\le 35\%$, volume surge $\ge 1.20 \times$ prior 60-bar volume.
  - Phase 2 Pennant: Symmetrical converging trendlines over $[5, 15]$ bars, slope symmetry $\le 0.40$, range $\in [1.5, 4.0] \cdot ATR$, apex distance $\in [0.20, 0.80]$, volume contraction $\le 0.75 \times$ flagpole volume.
  - Phase 3 Breakout Trigger: H1 close breaking beyond converging boundary $+ 0.40 \cdot ATR$.
  - Exits & Risk: Measured move TP, TP1 partial close 50% at 50% measured move with SL to BE, pattern failure exit within 5 bars, time stop at 18 H1 bars. Initial SL buffered by .30 \cdot ATR$ (capped at .00 \cdot ATR$).
  - Macro Bias: 200 SMA filter.
- **Framework V5 Integration**:
  - Full QM_Common.mqh integration with QM_NewsTemporalMode (QM_NEWS_TEMPORAL_PRE30_POST30), QM_NewsComplianceProfile (QM_NEWS_COMPLIANCE_DXZ), and qm_news_stale_max_hours = 336.
  - Risk parameters: RISK_FIXED = 1000.0, RISK_PERCENT = 0.0.

---

## 2. Registry & Verification Status

- **Registries**:
  - ramework/registry/ea_id_registry.csv: registered row 1417,classical-pennant-continuation-h1,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Development,2026-05-19,,,.
  - ramework/registry/magic_numbers.csv: registered 14 symbol slots (0..13: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX, SP500.DWX, XAUUSD.DWX, XTIUSD.DWX).
  - ramework/include/QM/QM_MagicResolver.mqh: regenerated cleanly (17,761 rows kept, 0 dropped).
- **SPEC Document**:
  - ramework/EAs/QM5_1417_classical-pennant-continuation-h1/SPEC.md generated and validated.
- **Build Guardrails**:
  - alidate_build_guardrails.py framework/EAs/QM5_1417_classical-pennant-continuation-h1: PASS (0 findings across 15 files).
- **P2 Setfiles**:
  - Generated all 14 backtest setfiles under ramework/EAs/QM5_1417_classical-pennant-continuation-h1/sets/.

---

## 3. Router Handoff

- Build JSON artifact written to D:/QM/strategy_farm/artifacts/builds/14432f77-9abf-4032-aefc-278a6bdbad34.json.
- Task 14432f77-9abf-4032-aefc-278a6bdbad34 updated to REVIEW for mandatory Codex review.
