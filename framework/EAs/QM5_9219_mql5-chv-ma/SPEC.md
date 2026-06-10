# QM5_9219_mql5-chv-ma — Strategy Spec

**EA ID:** QM5_9219
**Slug:** `mql5-chv-ma`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA computes the Chaikin Volatility indicator (CHV) as the percentage change in the EMA(10) of the daily High-Low range over a 10-bar lookback window. A long position is entered when CHV > 0 (volatility expanding) and the most recent closed-bar close is above SMA(20), indicating upward trend alignment. A short position is entered when CHV < 0 and close is below SMA(20). A volatility regime filter requires ATR(14) >= 0.6 × ATR(100) to avoid entering during dead-range periods. Positions are closed when CHV flips sign, close crosses the SMA(20) in the adverse direction, or after a 48-bar failsafe time stop. Initial stop is ATR(14) × 1.7 from entry; hard take-profit is 2.1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_chv_ema_period` | 10 | 5-30 | EMA period applied to the bar High-Low range for CHV computation |
| `strategy_chv_lookback` | 10 | 5-20 | Bars back for CHV percentage comparison (current EMA vs N-bars-ago EMA) |
| `strategy_ma_period` | 20 | 10-50 | SMA period for trend direction filter |
| `strategy_atr_period` | 14 | 10-21 | ATR period for stop distance sizing |
| `strategy_atr_vol_period` | 100 | 50-200 | ATR period for volatility regime filter baseline |
| `strategy_vol_ratio` | 0.6 | 0.3-0.9 | Minimum ratio ATR(14)/ATR(100) required to enter |
| `strategy_atr_sl_mult` | 1.7 | 1.0-3.0 | ATR multiplier for initial stop distance from entry price |
| `strategy_tp_r_mult` | 2.1 | 1.5-4.0 | Take-profit as a multiple of initial risk (R) |
| `strategy_max_bars_held` | 48 | 24-120 | Failsafe time exit in H1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; CHV and MA respond well to trending FX moves
- `XAUUSD.DWX` — gold/USD; significant directional volatility episodes suit CHV expansion logic
- `NDX.DWX` — Nasdaq 100 index; strong trending character with clear volatility regime shifts

**Explicitly NOT for:**
- Low-liquidity or exotic FX pairs — CHV requires consistent H-L expansion; thin symbols produce noise signals

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~70 |
| Typical hold time | 4–48 hours (H1 bars) |
| Expected drawdown profile | Moderate; ATR-based stop limits per-trade risk; 48-bar time stop prevents runaway holds |
| Regime preference | volatility-expansion, trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Mohamed Abdelmaaboud, "How to build and optimize a volatility-based trading system (Chaikin Volatility - CHV)", MQL5 Articles, 2024-04-25, https://www.mql5.com/en/articles/14775
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9219_mql5-chv-ma.md`

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
| v1 | 2026-06-10 | Initial build from card | 9be59aa5-0867-4291-88b1-d4898e8e6a85 |
