# QM5_10693_tv-smp-gma-bos - Strategy Spec

**EA ID:** QM5_10693
**Slug:** tv-smp-gma-bos
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades closed-bar breakouts through the most recent confirmed symmetric swing pivot. A long signal requires the last closed bar to close above the latest confirmed pivot high, close above the double-smoothed Gaussian moving average, and have the smoothed GMA rising; shorts mirror the rule below the latest confirmed pivot low with falling GMA. Entries are market orders on the next tick after the closed-bar signal. Exits are the fixed stop loss and take profit from the card, plus the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_gma_length | 30 | 20-60 tested | Gaussian moving-average length from the source defaults and P3 test set. |
| strategy_pivot_length | 20 | 10-30 tested | Symmetric pivot-high/low confirmation length. |
| strategy_pivot_scan_bars | 240 | 60-500 practical | Maximum closed bars searched for the latest confirmed pivot. |
| strategy_stop_percent | 1.0 | 0.5-1.5 tested | Source percent stop before ATR cap. |
| strategy_take_percent | 3.0 | 2.0-5.0 tested | Fixed percent take profit from the P2 default. |
| strategy_atr_period | 14 | 7-30 practical | ATR period used only to cap oversized percent stops. |
| strategy_atr_stop_cap_mult | 2.5 | 1.0-4.0 practical | Maximum stop distance as ATR multiple. |
| strategy_gma_slope_filter | true | true / false | Requires the smoothed GMA slope to agree with the trade direction. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX symbol with OHLC support for pivots and GMA.
- USDJPY.DWX - card-listed liquid FX symbol with OHLC support for pivots and GMA.
- XAUUSD.DWX - canonical DWX form of the card's XAUUSD metal target.
- GDAXI.DWX - matrix-listed DAX symbol used as the canonical port of card-stated GER40.DWX.
- NDX.DWX - card-listed Nasdaq 100 index target.
- WS30.DWX - card-listed Dow 30 index target.

**Explicitly NOT for:**
- GER40.DWX - not present in the DWX symbol matrix; GDAXI.DWX is used instead.
- XAUUSD - missing the required DWX suffix in backtest/registry context; XAUUSD.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Not specified in frontmatter; expected to be intraday to multi-day from 1% SL / 3% TP breakout logic. |
| Expected drawdown profile | Moderate; main risk is pivot lag and heterogeneous symbol volatility. |
| Regime preference | Trend continuation / breakout. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `SMPivot Gaussian Trend Strategy [Js.K]`, author `Jasonkasei`, cited in `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10693_tv-smp-gma-bos.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10693_tv-smp-gma-bos.md`

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
| v1 | 2026-05-31 | Initial build from card | 6084d9f3-187e-4118-b694-eb2acac46e02 |
