# QM5_11312_tc20-h1-10-ema14-high-low-psar - Strategy Spec

**EA ID:** QM5_11312
**Slug:** `tc20-h1-10-ema14-high-low-psar`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades the H1 close relative to a two-line EMA channel. A long entry is allowed when the last closed bar closes above EMA(14) applied to High and Parabolic SAR(0.02, 0.2) is below that candle. A short entry is allowed when the last closed bar closes below EMA(14) applied to Low and Parabolic SAR is above that candle. Positions use an ATR(14) x 1.5 stop, an 80-pip fixed take profit, and close on a reverse channel cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 14 | 2-200 | EMA period for the High/Low channel |
| `strategy_sar_step` | 0.02 | 0.001-0.2 | Parabolic SAR acceleration step |
| `strategy_sar_max` | 0.2 | 0.01-1.0 | Parabolic SAR maximum acceleration |
| `strategy_sl_atr_period` | 14 | 2-200 | ATR period used for stop distance |
| `strategy_sl_atr_mult` | 1.5 | 0.1-10.0 | ATR multiple for stop distance |
| `strategy_tp_pips` | 80 | 1-500 | Fixed take-profit distance in pips |
| `strategy_spread_cap_pips` | 20 | 1-100 | Maximum allowed nonzero modeled spread in pips |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary forex pair named by the card.
- `GBPUSD.DWX` - card P2 basket forex pair with H1 DWX coverage.
- `USDJPY.DWX` - card P2 basket forex pair with H1 DWX coverage.

**Explicitly NOT for:**
- `SP500.DWX` - index exposure is outside the card's forex-only universe.
- `XAUUSD.DWX` - metal exposure is outside the card's forex-only universe.

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
| Trades / year / symbol | `100` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | trend-following stop-and-target losses during range-bound chop |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book / local PDF`
**Pointer:** `Thomas Carter, 20 Forex Trading Strategies (1 Hour Time Frame), Forex Trading Strategy #10, local PDF: C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\376863900-20-Forex-Trading-Strategies-Collection.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11312_tc20-h1-10-ema14-high-low-psar.md`

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
| v1 | 2026-06-20 | Initial build from card | e5092419-124e-42d0-ab18-ee20a5f15542 |
