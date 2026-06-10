# QM5_9455_gk-ce-zlsma — Strategy Spec

**EA ID:** QM5_9455
**Slug:** `gk-ce-zlsma`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Author of this spec:** Development
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed M15 bar, the EA computes a Chandelier Exit (CE) trailing stop and a Zero-Lag SMA (ZLSMA) over 50 bars. A long entry fires when the CE direction just flipped from bearish to bullish (CE_B signal) AND the Heikin Ashi close (simple average of O+H+L+C) is above the ZLSMA. A short entry fires symmetrically when the CE flips to bearish AND the HA close is below the ZLSMA. Positions are closed when the HA close crosses back through the ZLSMA on a non-negative profit, or after 96 M15 bars (24 hours) as a time stop. Stop loss is placed 650 points beyond the CE level at signal time; no take-profit target; no grid or multiple open positions.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ce_atr_period` | 1 | 1–20 | ATR period for Chandelier Exit trailing stop calculation |
| `strategy_ce_atr_mult` | 0.75 | 0.1–5.0 | ATR multiplier applied to CE trailing stop width |
| `strategy_zl_period` | 50 | 10–100 | Linear-regression period for ZLSMA computation |
| `strategy_sl_extra_pips` | 650 | 100–2000 | Additional points below/above CE level placed as stop loss |
| `strategy_time_exit_bars` | 96 | 12–480 | Maximum bars a position may remain open (96 × M15 = 24 h) |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` — AUD/USD Forex; liquid, trending FX pair suitable for CE/ZLSMA trend-follow
- `EURUSD.DWX` — EUR/USD Forex; primary liquid FX pair; strong trend characteristics
- `GBPUSD.DWX` — GBP/USD Forex; volatile trending FX pair; within card target basket
- `XAUUSD.DWX` — Gold/USD commodity CFD; strong trending properties; within card target basket

**Explicitly NOT for:**
- Index CFDs — card specifies FX + XAUUSD only; CE_ATRPeriod=1 calibrated for FX volatility profiles

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 (card estimate: 80–160) |
| Typical hold time | 1–96 M15 bars (15 min to 24 h) |
| Expected drawdown profile | Moderate intraday; SL = CE level − 650 pts bounds single-trade risk |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub public EA repository
**Pointer:** Geraked/Rabist, `geraked/metatrader5`, CEZLSMA Expert Advisor, GitHub, commit d3eb29c382acf715727d5cd6a0414151e821fc2d
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9455_gk-ce-zlsma.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 7a13ee23-37e2-4622-a547-a63ed9e67d99 |
