# QM5_11015_the5ers-weekly-ny - Strategy Spec

**EA ID:** QM5_11015
**Slug:** the5ers-weekly-ny
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see The5ers blog source record)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a Tuesday or Wednesday New York-session continuation breakout on H1 forex symbols. It builds a broker-week range from Monday open through the current entry day's pre-New-York bars, then enters long when D1 close is above its 20-day SMA, price is above the weekly open, the Asian/London net move is positive by at least 0.5 ATR, and the latest H1 close breaks the range high. It enters short on the mirror condition below the D1 SMA, below weekly open, negative pre-New-York move, and a break below the range low. Exits are the fixed 2.0R target, the initial structure/ATR stop, a close back inside the broken range, a 36-H1-bar time stop, or Friday 18:00 broker calendar exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ny_start_hour | 16 | 0-23 | Broker-hour start of the New York entry window. |
| strategy_ny_end_hour | 22 | 0-23 | Broker-hour end of the New York entry window, exclusive. |
| strategy_sma_period | 20 | 2-200 | D1 SMA period for directional bias. |
| strategy_atr_period | 14 | 2-100 | H1 ATR period for session move, breakout buffer, and stop distance. |
| strategy_session_move_atr | 0.5 | 0.0-5.0 | Required New-York-open versus day-open move in ATR multiples. |
| strategy_breakout_buf_atr | 0.0 | 0.0-2.0 | Breakout buffer beyond the pre-New-York range in ATR multiples. |
| strategy_sl_atr_mult | 1.5 | 0.1-10.0 | ATR cap for initial stop distance. |
| strategy_sl_atr_floor | 1.0 | 0.1-10.0 | Minimum initial stop distance in ATR multiples. |
| strategy_tp_rr | 2.0 | 0.1-10.0 | Take-profit multiple of initial risk. |
| strategy_time_stop_bars | 36 | 1-240 | Maximum H1 bars to hold if SL/TP do not hit. |
| strategy_friday_exit_hour | 18 | 0-23 | Broker-hour Friday calendar exit cutoff. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - USD-major forex pair explicitly listed by the approved card and available in the DWX matrix.
- GBPUSD.DWX - USD-major forex pair explicitly listed by the approved card and available in the DWX matrix.
- USDJPY.DWX - USD-major forex pair explicitly listed by the approved card and available in the DWX matrix.
- AUDUSD.DWX - USD-major forex pair explicitly listed by the approved card and available in the DWX matrix.
- USDCAD.DWX - USD-major forex pair explicitly listed by the approved card and available in the DWX matrix.

**Explicitly NOT for:**
- SP500.DWX - the card is explicitly forex and uses currency-pair news/session assumptions.
- XAUUSD.DWX - not one of the approved target forex symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 close and D1 SMA for directional bias |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Intraday to 36 H1 bars |
| Expected drawdown profile | Moderate breakout drawdown with one trade per symbol per week. |
| Regime preference | Weekly continuation / session breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog interview
**Pointer:** https://the5ers.com/best-trading-strategy/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11015_the5ers-weekly-ny.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | 4599066b-15bf-495e-a992-26ffda405030 |
