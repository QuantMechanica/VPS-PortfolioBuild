# QM5_10537_mql5-kolier-x2 - Strategy Spec

**EA ID:** QM5_10537
**Slug:** `mql5-kolier-x2`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades a two-timeframe Kolier-style SuperTrend rule. On each closed fast bar, it reads a slow SuperTrend direction and a fast SuperTrend direction built from ATR bands. It opens long when the slow trend is bullish and the fast trend flips from bearish to bullish; it opens short when the slow trend is bearish and the fast trend flips from bullish to bearish. It exits an open position when either the fast or slow SuperTrend turns against the position, with an ATR-derived hard stop and 2R take profit always attached at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_timeframe` | `PERIOD_M30` | M15-M30-H1 sweep | Signal timeframe for fast SuperTrend color changes. |
| `strategy_slow_timeframe` | `PERIOD_H6` | H4-H6-D1 sweep | Higher timeframe SuperTrend direction filter. |
| `strategy_atr_period` | `10` | 10-20 | ATR period used in both SuperTrend bands and the hard stop. |
| `strategy_atr_multiplier` | `3.0` | 2.0-4.0 | ATR multiplier used in both SuperTrend bands and the hard stop. |
| `strategy_take_profit_rr` | `2.0` | 1.0-3.0 | Take-profit distance as a multiple of initial stop risk. |
| `strategy_supertrend_bars` | `120` | 40-300 | Closed-bar history used to stabilize the SuperTrend state. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX major forex pair from the card basket.
- `GBPUSD.DWX` - liquid DWX major forex pair from the card basket.
- `XAUUSD.DWX` - DWX gold symbol from the card basket.
- `GDAXI.DWX` - DWX DAX proxy used for the card's `GER40.DWX` exposure because `GER40.DWX` is not in the matrix.

**Explicitly NOT for:**
- Non-DWX symbols - the build and magic registry are scoped to canonical DWX custom symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | Fast `M30`, slow `H6`; card sweeps fast M15/M30/H1 and slow H4/H6/D1 downstream. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Hours to several days, depending on SuperTrend flips and fixed SL/TP resolution. |
| Expected drawdown profile | Trend-following losses cluster in sideways regimes and are capped by the ATR stop. |
| Regime preference | Trend |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/18160`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10537_mql5-kolier-x2.md`

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
| v1 | 2026-05-29 | Initial build from card | c6443f12-fd89-4475-8d08-f5e5f211a562 |
