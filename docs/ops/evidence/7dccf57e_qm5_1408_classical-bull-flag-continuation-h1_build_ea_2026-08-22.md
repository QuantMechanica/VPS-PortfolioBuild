# QM5_1408 Build EA Evidence — 2026-08-22

**Task ID:** `7dccf57e-a995-465f-a9b7-98e7b945a651` (`build_ea`, priority 50, agent `gemini`).  
**EA:** `QM5_1408_classical-bull-flag-continuation-h1`.  
**Artifact Path:** `C:/QM/repo/docs/ops/evidence/7dccf57e_qm5_1408_classical-bull-flag-continuation-h1_build_identity.json`.  
**Strategy Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1408_classical-bull-flag-continuation-h1.md` (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Robert D. Edwards & John Magee Classical Bull-Flag Continuation (H1).
  - Three-phase deterministic pattern sequence: **flagpole → flag-channel → breakout**.
  - Williams 3-bar fractal on closed H1 bars.
  - Phase 1 (Flagpole Gate):
    - Impulse leg $N_{pole} \in [12, 36]$ H1 bars.
    - Cumulative move $\ge 4.0 \cdot ATR(14, H1)$, slope $\ge +0.20 \cdot ATR$ per bar.
    - Pullback bars $\le 35\%$, volume $\ge 1.20 \times$ 60-bar baseline.
  - Phase 2 (Flag Channel Gate):
    - Consolidation window $N_{flag} \in [5, 18]$ H1 bars.
    - Counter-slope in $[-0.10, -0.005] \cdot ATR$ per bar.
    - Parallel channel containment $\ge 80\%$, retracement bound $\le 50\%$ of pole height.
    - Volume contraction $\le 0.80 \times$ pole volume.
  - Phase 3 (Breakout Trigger):
    - Breakout close above upper trendline $+ 0.4 \cdot ATR$.
  - Exits:
    - Full flagpole measured-move TP ($entry + \text{pole\_height}$).
    - TP1 partial close (50%) at 50% of measured move + move SL to BE.
    - Pattern failure exit: hard close if H1 close falls back inside channel within first 6 bars.
    - Time stop: 24 H1 bars.
  - Stop Loss: $lower\_TL(t_{break}) - 0.3 \cdot ATR$, capped at $2.5 \cdot ATR$.
  - Macro Bias Filter: H4 SMA(200) rising and H1 close > H4 SMA(200).
- **Framework V5 Integration**:
  - Full `QM_Common.mqh` integration with `QM_NewsTemporalMode` (`QM_NEWS_TEMPORAL_PRE30_POST30`), `QM_NewsComplianceProfile` (`QM_NEWS_COMPLIANCE_DXZ`), and `qm_news_stale_max_hours = 336`.
  - Risk model compliant with HR4: `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`.

---

## 2. Registry & Verification Status

- **Registries**:
  - `framework/registry/ea_id_registry.csv`: registered row `1408,classical-bull-flag-continuation-h1,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Development,2026-05-19,,,`.
  - `framework/registry/magic_numbers.csv`: registered 14 symbol slots (0: EURUSD.DWX, 1: GBPUSD.DWX, 2: USDJPY.DWX, 3: AUDUSD.DWX, 4: USDCAD.DWX, 5: USDCHF.DWX, 6: NZDUSD.DWX, 7: NDX.DWX, 8: WS30.DWX, 9: GDAXI.DWX, 10: UK100.DWX, 11: SP500.DWX, 12: XAUUSD.DWX, 13: XTIUSD.DWX).
  - `framework/include/QM/QM_MagicResolver.mqh`: regenerated cleanly (17704 active rows kept, 0 dropped).
- **SPEC Document**:
  - `framework/EAs/QM5_1408_classical-bull-flag-continuation-h1/SPEC.md` written and aligned with approved strategy card.
- **Build Guardrails**:
  - `validate_build_guardrails.py framework/EAs/QM5_1408_classical-bull-flag-continuation-h1`: `PASS` (0 findings across 15 files).
- **P2 Setfiles**:
  - Generated all 14 backtest setfiles under `framework/EAs/QM5_1408_classical-bull-flag-continuation-h1/sets/`.

---

## 3. Router Handoff

- Build JSON artifact written to `C:/QM/repo/docs/ops/evidence/7dccf57e_qm5_1408_classical-bull-flag-continuation-h1_build_identity.json` and `D:/QM/strategy_farm/artifacts/builds/7dccf57e-a995-465f-a9b7-98e7b945a651.json`.
- Task `7dccf57e-a995-465f-a9b7-98e7b945a651` updated to `REVIEW` for mandatory Codex review.
