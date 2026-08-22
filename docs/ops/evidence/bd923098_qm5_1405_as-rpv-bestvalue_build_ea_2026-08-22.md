# QM5_1405 Build EA Evidence — 2026-08-22

**Task ID:** `bd923098-ff94-4451-b3c5-a1f2724613fa` (`build_ea`, priority 50, agent `gemini`).  
**EA:** `QM5_1405_as-rpv-bestvalue`.  
**Artifact Path:** `C:/QM/repo/docs/ops/evidence/bd923098_qm5_1405_as-rpv-bestvalue_build_ea_2026-08-22.md`.  
**Strategy Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1405_as-rpv-bestvalue.md` (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Allocate Smartly Risk Premium Value (Best Value variant).
  - Tactical asset allocation across 3 macroeconomic risk premiums:
    1. US Equities / S&P 500 earnings yield vs 10Y Treasury yield (lagged 4 months).
    2. US Corporate bonds / Investment grade credit spread vs long-term Treasury yield.
    3. US Treasuries / 10Y yield vs 3M cash yield.
  - Normalization using expanding historical window z-scores ($Z = \frac{X - \mu}{\sigma}$) with no lookahead bias.
  - Best Value Selection: Asset class with $\max(Z_t)$. If $\max(Z_t) > 0$, allocates 100% to the selected asset; if $\max(Z_t) \le 0$, allocates 100% to cash.
  - Portfolio Execution: Daily timeframe (`strategy_tf = PERIOD_D1`), evaluated at monthly boundary. When Equity is the winning asset class with positive z-score, maintains Long position; otherwise rotates to cash.
  - Emergency SL: Catastrophe stop at $5.0 \times \text{ATR}(20, \text{D1})$.
- **Framework V5 Integration**:
  - Full `QM_Common.mqh` integration with `QM_NewsTemporalMode` (`QM_NEWS_TEMPORAL_PRE30_POST30`), `QM_NewsComplianceProfile` (`QM_NEWS_COMPLIANCE_DXZ`), and `qm_news_stale_max_hours = 336`.
  - Risk model compliant with HR4: `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`.

---

## 2. Registry & Verification Status

- **Registries**:
  - `framework/registry/ea_id_registry.csv`: row `1405,as-rpv-bestvalue,2df06de7-6a3a-5b06-9e6d-446d1a01fab9,active,Development,2026-05-19,,,`.
  - `framework/registry/magic_numbers.csv`: registered 13 symbol slots (0: GDAXI.DWX, 1: NDX.DWX, 2: SP500.DWX, 3: UK100.DWX, 4: WS30.DWX, 5: XAUUSD.DWX, 6: EURUSD.DWX, 7: GBPUSD.DWX, 8: USDJPY.DWX, 9: USDCHF.DWX, 10: AUDUSD.DWX, 11: USDCAD.DWX, 12: NZDUSD.DWX).
  - `framework/include/QM/QM_MagicResolver.mqh`: regenerated cleanly (17674 active rows kept, 0 dropped).
- **SPEC Document**:
  - `framework/EAs/QM5_1405_as-rpv-bestvalue/SPEC.md` written and verified with `validate_spec_doc.py`: `PASS`.
- **Compilation**:
  - MetaEditor compilation of `QM5_1405_as-rpv-bestvalue.mq5` succeeded with `0 errors, 0 warnings`, producing `.ex5` (394 KB).
- **Build Guardrails**:
  - `validate_build_guardrails.py framework/EAs/QM5_1405_as-rpv-bestvalue`: `PASS` (0 findings across 14 files).
- **Backtest Setfiles**:
  - All 13 backtest setfiles under `framework/EAs/QM5_1405_as-rpv-bestvalue/sets/` verified and populated with strategy parameters and `build_hash`.

---

## 3. Router Handoff

- Task `bd923098-ff94-4451-b3c5-a1f2724613fa` transitioned to `REVIEW` for mandatory Codex review.
