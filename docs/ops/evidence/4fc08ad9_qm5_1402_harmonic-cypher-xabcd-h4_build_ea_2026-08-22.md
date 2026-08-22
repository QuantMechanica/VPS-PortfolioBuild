# QM5_1402 Build EA Evidence — 2026-08-22

**Task ID:** `4fc08ad9-c107-4176-8a47-94290a7bf979` (`build_ea`, priority 50, agent `gemini`).  
**EA:** `QM5_1402_harmonic-cypher-xabcd-h4`.  
**Artifact Path:** `C:/QM/repo/docs/ops/evidence/4fc08ad9_qm5_1402_harmonic-cypher-xabcd-h4_build_ea_2026-08-22.md`.  
**Strategy Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1402_harmonic-cypher-xabcd-h4.md` (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Scott M. Carney / Darren Oglesbee Harmonic Cypher Pattern (XABCD, H4).
  - Williams-fractal alternating 5-pivot detection (X-A-B-C-D) on closed H4 bars.
  - Closed-form Fibonacci ratio checks with ±3% tolerance:
    - AB / XA ∈ [0.382, 0.618]
    - BC / AB ∈ [1.272, 1.414]
    - BC / XA ∈ [1.130, 1.414] (cross-check)
    - CD / XC = 0.786 ± 3% (D-completion zone)
    - Invalidation: D must not exceed X.
  - Entry Trigger: Rejection bar closing back inside C-X range with bar touch on D-cluster.
  - Macro-bias: H4 Close > SMA(200, H4) for Long; H4 Close < SMA(200, H4) for Short.
  - Exits: TP1 at 38.2% CD retracement (50% partial exit + move SL to BE); TP2 at 61.8% CD retracement (final exit).
  - Stop Loss: Low(X) - 0.5 * ATR(14) [Long] / High(X) + 0.5 * ATR(14) [Short], capped at 2.5 * ATR(14).
- **Framework V5 Integration**:
  - Full `QM_Common.mqh` integration with `QM_NewsTemporalMode` (`QM_NEWS_TEMPORAL_PRE30_POST30`), `QM_NewsComplianceProfile` (`QM_NEWS_COMPLIANCE_DXZ`), and `qm_news_stale_max_hours = 336`.
  - Risk model compliant with HR4: `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`.

---

## 2. Registry & Verification Status

- **Registries**:
  - `framework/registry/ea_id_registry.csv`: updated row `1402,harmonic-cypher-xabcd-h4,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Development,2026-05-19,,,`.
  - `framework/registry/magic_numbers.csv`: registered 13 symbol slots (0: EURUSD.DWX, 1: GBPUSD.DWX, 2: USDJPY.DWX, 3: AUDUSD.DWX, 4: USDCAD.DWX, 5: USDCHF.DWX, 6: NZDUSD.DWX, 7: NDX.DWX, 8: WS30.DWX, 9: GDAXI.DWX, 10: UK100.DWX, 11: SP500.DWX, 12: XAUUSD.DWX).
  - `framework/include/QM/QM_MagicResolver.mqh`: regenerated cleanly (17661 active rows kept, 0 dropped).
- **SPEC Document**:
  - `framework/EAs/QM5_1402_harmonic-cypher-xabcd-h4/SPEC.md` written and aligned with approved strategy card.
- **Build Guardrails**:
  - `validate_build_guardrails.py framework/EAs/QM5_1402_harmonic-cypher-xabcd-h4`: `PASS` (0 findings across 14 files).
- **P2 Setfiles**:
  - Generated all 13 backtest setfiles under `framework/EAs/QM5_1402_harmonic-cypher-xabcd-h4/sets/`.

---

## 3. Router Handoff

- Build JSON artifact written to `D:/QM/strategy_farm/artifacts/builds/4fc08ad9-c107-4176-8a47-94290a7bf979.json`.
- Task `4fc08ad9-c107-4176-8a47-94290a7bf979` updated to `REVIEW` for mandatory Codex review.
