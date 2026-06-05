# QM5_10573_mql5-extrem-n - Strategy Spec

**EA ID:** QM5_10573
**Slug:** `mql5-extrem-n`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

Closed-bar Extrem_N line-flip system. The Extrem_N indicator plots a green
(bullish) or red (bearish) line whose colour flips when a freshly closed bar
establishes a new N-bar price extreme. This build mechanises that colour as a
persistent N-bar extreme-channel regime: the line turns green when the last
closed bar's close breaks above the prior N-bar high, and red when it breaks
below the prior N-bar low; otherwise the previous colour persists. Go long when
the line is green and flat, go short when the line is red and flat (one position
per symbol/magic). Close on the opposite line flip (green↔red), on the ATR hard
stop / 1.5R target, on Friday close, on the news gate, or on the V5 kill-switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_extrem_n` | `12` | 5-60 | Extrem_N extreme-channel lookback (closed bars). Green flip = close > prior N-bar high; red flip = close < prior N-bar low. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | 0.5-5.0 | Hard stop distance = ATR(period) × mult (card P2 baseline 2.0). |
| `strategy_tp_r_mult` | `1.5` | 0.5-5.0 | Take-profit distance in multiples of initial risk (card P2 baseline 1.5R). |
| `strategy_min_atr_points` | `0.0` | 0.0+ | Optional volatility floor; block entry when ATR(period) < this many points. 0 = disabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - approved card basket FX major; portable OHLC-derived extreme channel.
- `GBPUSD.DWX` - approved card basket FX major; portable OHLC-derived extreme channel.
- `USDJPY.DWX` - approved card basket FX major; portable OHLC-derived extreme channel.
- `XAUUSD.DWX` - approved card basket metal; portable OHLC-derived extreme channel.

**Explicitly NOT for:**
- Non-DWX symbols - not registered in the QM5 magic registry for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H6` (card period; source test EURUSD H6 2015) |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 28 |
| Typical hold time | Days; closed-bar H6 line-flip turnover, moderate-to-low |
| Expected drawdown profile | ATR 2.0 stop with 1.5R target constrains per-trade loss |
| Regime preference | trend / breakout (extreme-channel reversal) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** forum (MQL5 CodeBase)
**Pointer:** Exp_Extrem_N, Nikolay Kositsin, MQL5 CodeBase, published 2016-04-13, updated 2016-11-22, https://www.mql5.com/en/code/14890
**R1-R4 verdict (Q00):** all PASS; see `artifacts/cards_approved/QM5_10573_mql5-extrem-n.md`

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
| v1 | 2026-06-04 | Initial build from card | 336e5aa0-ddc5-438c-b58c-9ae33f4789ca |
| v2 | 2026-06-05 | Rebuild in place: replaced generic no-source rebuild scaffold with clean per-card Extrem_N extreme-channel mechanisation (framework corset, QM_Sig_Range_Breakout) | 336e5aa0-ddc5-438c-b58c-9ae33f4789ca |
