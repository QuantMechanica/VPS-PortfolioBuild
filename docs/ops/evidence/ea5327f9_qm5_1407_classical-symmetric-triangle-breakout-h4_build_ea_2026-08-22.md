# QM5_1407 Build EA Evidence — 2026-08-22

**Task ID:** `ea5327f9-2e58-4f02-b542-3861c7432401` (`build_ea`, priority 50, agent `gemini`).  
**EA:** `QM5_1407_classical-symmetric-triangle-breakout-h4`.  
**Artifact Path:** `C:/QM/repo/docs/ops/evidence/ea5327f9_qm5_1407_classical-symmetric-triangle-breakout-h4_build_ea_2026-08-22.md`.  
**Strategy Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1407_classical-symmetric-triangle-breakout-h4.md` (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Robert D. Edwards & John Magee, *Technical Analysis of Stock Trends* (10th ed.), Ch. 8: Symmetric Triangle Consolidation and Apex Theorem on H4.
  - Williams 5-bar fractal alternating pivot detection on closed H4 bars.
  - Bounded structural lookback window $N \in [25, 80]$ H4 bars.
  - Linear regression slopes for supply line ($\ge 3$ descending highs, slope in $[-2.0, -0.3] \times \text{ATR}/50$) and demand line ($\ge 3$ ascending lows, slope in $[+0.3, +2.0] \times \text{ATR}/50$).
  - Bilateral slope symmetry ratio $\le 0.40$.
  - Volatility amplitude floor $\ge 3.0 \times \text{ATR}(14, \text{H4})$.
  - Apex convergence distance $\le 30\%$ of pattern duration beyond pattern edge.
  - Invalidation check: No bar close in pattern window violates envelope ($\pm 0.20 \times \text{ATR}$).
  - Bias-neutral breakout entry on new H4 bar:
    - BUY when $Close[1] > \text{supply\_line} + 0.50 \times \text{ATR}$.
    - SELL when $Close[1] < \text{demand\_line} - 0.50 \times \text{ATR}$.
  - Exits & Management:
    - Full TP: measured move equal to triangle height ($H_{max} - L_{min}$).
    - TP1: 50% partial exit at 50% measured move + move SL to break-even.
    - Initial SL: opposite triangle boundary $\pm 0.30 \times \text{ATR}$, capped at $3.0 \times \text{ATR}$.
    - Pattern failure exit: hard close if bar close returns inside triangle boundaries.
    - Time stop: 36 H4 bars.
- **Framework V5 Integration**:
  - Full `QM_Common.mqh` integration with `QM_NewsTemporalMode` (`QM_NEWS_TEMPORAL_PRE30_POST30`), `QM_NewsComplianceProfile` (`QM_NEWS_COMPLIANCE_DXZ`), and `qm_news_stale_max_hours = 336`.
  - Risk model compliant with HR4: `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`.

---

## 2. Registry & Verification Status

- **Registries**:
  - `framework/registry/ea_id_registry.csv`: registered row `1407,classical-symmetric-triangle-breakout-h4,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Development,2026-05-19,,,`.
  - `framework/registry/magic_numbers.csv`: registered 13 symbol slots (0: GDAXI.DWX, 1: NDX.DWX, 2: SP500.DWX, 3: UK100.DWX, 4: WS30.DWX, 5: XAUUSD.DWX, 6: EURUSD.DWX, 7: GBPUSD.DWX, 8: USDJPY.DWX, 9: USDCHF.DWX, 10: AUDUSD.DWX, 11: USDCAD.DWX, 12: NZDUSD.DWX).
  - `framework/include/QM/QM_MagicResolver.mqh`: regenerated cleanly (17674 active rows kept, 0 dropped).
- **SPEC Document**:
  - `framework/EAs/QM5_1407_classical-symmetric-triangle-breakout-h4/SPEC.md` written and verified with `validate_spec_doc.py`: `PASS`.
- **Compilation**:
  - MetaEditor compilation of `QM5_1407_classical-symmetric-triangle-breakout-h4.mq5` succeeded with `0 errors, 0 warnings`, producing `.ex5` (406 KB).
- **Build Guardrails**:
  - `validate_build_guardrails.py framework/EAs/QM5_1407_classical-symmetric-triangle-breakout-h4`: `PASS` (0 findings across 14 files).
- **Backtest Setfiles**:
  - Generated all 13 backtest setfiles under `framework/EAs/QM5_1407_classical-symmetric-triangle-breakout-h4/sets/`.

---

## 3. Router Handoff

- Task `ea5327f9-2e58-4f02-b542-3861c7432401` transitioned to `REVIEW` for mandatory Codex review.
