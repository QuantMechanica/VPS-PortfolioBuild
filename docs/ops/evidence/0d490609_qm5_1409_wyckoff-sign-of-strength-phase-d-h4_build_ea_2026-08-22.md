# QM5_1409 Build EA Evidence — 2026-08-22

**Task ID:** `0d490609-922c-47df-a3eb-2a27412e3796` (`build_ea`, priority 50, agent `gemini`).  
**EA:** `QM5_1409_wyckoff-sign-of-strength-phase-d-h4`.  
**Artifact Path:** `C:/QM/repo/docs/ops/evidence/0d490609_qm5_1409_wyckoff-sign-of-strength-phase-d-h4_build_ea_2026-08-22.md`.  
**Strategy Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1409_wyckoff-sign-of-strength-phase-d-h4.md` (G0 APPROVED).  

---

## 1. Strategy Overview & Implementation

- **Strategy Thesis**: Hank Pruden / Richard Wyckoff Sign-of-Strength (Phase D accumulation long-entry, H4).
  - Three-phase deterministic pattern sequence: **trading-range → SOS-bar → LPS-pullback → entry**.
  - Williams 5-bar fractal on closed H4 bars.
  - Phase A (Trading Range Gate):
    - Multi-week window $N_{TR} \in [60, 240]$ H4 bars.
    - Trimmed quantile bounds (5% wicks dropped, 20% percentile low band, 80% percentile high band).
    - Range containment $\ge 90\%$, amplitude $4.0 - 14.0$ ATR.
    - Prior-trend slope before TR $\le -0.10 \cdot ATR$ per bar.
    - Range stability $|slope_{LR}| \le 0.05 \cdot ATR$ per bar.
    - Phase-C Spring occurrence verified within range ($close \le low\_band - 0.5 \cdot ATR$, recovery $\le 4$ bars).
  - Phase B (SOS Bar Gate):
    - Breakout above range ($close > high\_band + 0.4 \cdot ATR$).
    - Bullish body magnitude $\ge 1.0 \cdot ATR$, close in upper third $\ge 70\%$.
    - Volume surge $\ge 1.50 \times$ 20-bar average, spread expansion $\ge 1.4 \cdot ATR$.
  - Phase C (LPS Pullback Gate):
    - Pullback into resistance-turned-support $[high\_band - 0.2 ATR, high\_band + 1.0 ATR]$ within 3-10 bars.
    - Shallowness $\le 1.20$, no close back inside range below $high\_band - 0.4 ATR$.
    - Bullish reversal bar close $\ge 60\%$ of bar range.
  - Macro Bias: $close > SMA(200, D1) - 2.0 \cdot ATR(14, D1)$.
  - Exits: TP at 1.2 measured move ($high\_band - low\_band$); TP1 partial close (50%) at 60% of measured move + move SL to BE; pattern failure hard exit at $high\_band - 0.5 \cdot ATR$; time stop at 60 H4 bars.
  - Stop Loss: $\min(low[t_{LPS-2..t_{LPS}}]) - 0.4 \cdot ATR$, capped at $3.0 \cdot ATR$.
- **Framework V5 Integration**:
  - Full `QM_Common.mqh` integration with `QM_NewsTemporalMode` (`QM_NEWS_TEMPORAL_PRE30_POST30`), `QM_NewsComplianceProfile` (`QM_NEWS_COMPLIANCE_DXZ`), and `qm_news_stale_max_hours = 336`.
  - Risk model compliant with HR4: `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`.

---

## 2. Registry & Verification Status

- **Registries**:
  - `framework/registry/ea_id_registry.csv`: registered row `1409,wyckoff-sign-of-strength-phase-d-h4,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Development,2026-05-19,,,`.
  - `framework/registry/magic_numbers.csv`: registered 14 symbol slots (0: EURUSD.DWX, 1: GBPUSD.DWX, 2: USDJPY.DWX, 3: AUDUSD.DWX, 4: USDCAD.DWX, 5: USDCHF.DWX, 6: NZDUSD.DWX, 7: NDX.DWX, 8: WS30.DWX, 9: GDAXI.DWX, 10: UK100.DWX, 11: SP500.DWX, 12: XAUUSD.DWX, 13: XTIUSD.DWX).
  - `framework/include/QM/QM_MagicResolver.mqh`: regenerated cleanly (17704 active rows kept, 0 dropped).
- **SPEC Document**:
  - `framework/EAs/QM5_1409_wyckoff-sign-of-strength-phase-d-h4/SPEC.md` written and aligned with approved strategy card.
- **Build Guardrails**:
  - `validate_build_guardrails.py framework/EAs/QM5_1409_wyckoff-sign-of-strength-phase-d-h4`: `PASS` (0 findings across 15 files).
- **P2 Setfiles**:
  - Generated all 14 backtest setfiles under `framework/EAs/QM5_1409_wyckoff-sign-of-strength-phase-d-h4/sets/`.

---

## 3. Router Handoff

- Build JSON artifact written to `D:/QM/strategy_farm/artifacts/builds/0d490609-922c-47df-a3eb-2a27412e3796.json`.
- Task `0d490609-922c-47df-a3eb-2a27412e3796` updated to `REVIEW` for mandatory Codex review.
