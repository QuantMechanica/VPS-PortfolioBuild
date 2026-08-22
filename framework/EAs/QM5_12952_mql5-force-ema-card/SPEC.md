# QM5_12952_mql5-force-ema-card - Strategy Spec

**EA ID:** QM5_12952
**Slug:** `mql5-force-ema-card`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card artifact)
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA trades closed H1-bar Force Index momentum filtered by EMA(100) and an ATR volatility threshold. It calculates Force Index(13, EMA, tick volume), EMA(100), and ATR(14) on closed H1 bars.

**Entry Rules:**
- Volatility filter: ATR(14) >= 50% of ATR(100).
- Long entry: H1 close > EMA(100) and Force Index crosses from below zero to above zero (previous Force Index < 0 and current Force Index > 0).
- Short entry: H1 close < EMA(100) and Force Index crosses from above zero to below zero (previous Force Index > 0 and current Force Index < 0).
- Single position per magic.

**Exit Rules:**
- Long exit: Force Index crosses back below zero or close falls below EMA(100).
- Short exit: Force Index crosses back above zero or close rises above EMA(100).
- Failsafe time exit after 36 H1 bars.

**Stops and Targets:**
- Long Stop Loss: entry - ATR(14) * 1.6.
- Short Stop Loss: entry + ATR(14) * 1.6.
- Take Profit: 2.0R (2.0x initial stop risk distance).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_force_period` | 13 | 2-200 | EMA smoothing period for Force Index built from H1 close changes and tick volume. |
| `strategy_ema_period` | 100 | 2-500 | Close-price EMA period used as the trend filter. |
| `strategy_atr_period` | 14 | 2-200 | ATR period used for initial stop placement and volatility filtering. |
| `strategy_atr_filter_period` | 100 | 10-500 | Long-term ATR baseline period for the volatility filter. |
| `strategy_atr_filter_ratio` | 0.50 | 0.0-2.0 | Minimum ratio of ATR(14) / ATR(100) required to enter. |
| `strategy_atr_sl_mult` | 1.6 | 0.1-10.0 | ATR multiple for the initial stop loss. |
| `strategy_rr_target` | 2.0 | 0.1-10.0 | Take-profit distance as an R multiple of initial stop risk. |
| `strategy_max_hold_bars` | 36 | 1-500 | Failsafe maximum holding time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair with DWX tick volume and H1 history.
- `USDJPY.DWX` - liquid major FX pair with DWX tick volume and H1 history.
- `GER40.DWX` - liquid equity index CFD with DWX tick volume and H1 history.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline runs require canonical `.DWX` symbols.
- Symbols without tick volume history - Force Index requires tick volume for the card's signal.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `85` |
| Typical hold time | `hours to 36 H1 bars maximum` |
| Expected drawdown profile | `ATR-bounded trend-following drawdowns from false zero-line crosses` |
| Regime preference | `momentum / trend-following` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/11269`
**Title:** "Learn how to design a trading system by Force Index"
**Author:** Mohamed Abdelmaaboud (2022-08-03)
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12952_mql5-force-ema-card.md`

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
| v1 | 2026-08-22 | Initial complete build from approved card | gemini orchestration |
