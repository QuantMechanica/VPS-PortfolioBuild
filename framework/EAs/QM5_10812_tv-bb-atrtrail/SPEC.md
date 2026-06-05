# QM5_10812_tv-bb-atrtrail - Strategy Spec

**EA ID:** QM5_10812
**Slug:** `tv-bb-atrtrail`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades a Bollinger Band breakout in the direction of a simple moving average filter. A long entry fires when the last closed bar crosses above the upper Bollinger Band and closes above SMA(200); a short entry fires when the last closed bar crosses below the lower Bollinger Band and closes below SMA(200). The initial stop is the ATR trailing-stop formula from the card, using closed-bar median price `hl2 +/- 3.0 * ATR(14)`. While a position is open, the EA recalculates that stop from closed bars and only moves the stop in the trade's favour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 2-200 | Bollinger Band moving-average length. |
| `strategy_bb_deviation` | 2.0 | 0.5-5.0 | Bollinger Band standard-deviation multiplier. |
| `strategy_sma_period` | 200 | 2-400 | Trend filter SMA length. |
| `strategy_atr_period` | 14 | 1-100 | ATR length for initial and trailing stop. |
| `strategy_atr_mult` | 3.0 | 0.5-8.0 | ATR multiplier for the median-price trailing stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - listed in the card's R3 portable basket and available in the DWX matrix.
- `GBPUSD.DWX` - listed in the card's R3 portable basket and available in the DWX matrix.
- `USDJPY.DWX` - listed in the card's R3 portable basket and available in the DWX matrix.
- `XAUUSD.DWX` - canonical DWX form of the card's `XAUUSD` basket item.
- `GDAXI.DWX` - DWX-available DAX proxy for the card's unavailable `GER40.DWX` item.
- `NDX.DWX` - listed in the card's R3 portable basket and available in the DWX matrix.
- `WS30.DWX` - listed in the card's R3 portable basket and available in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1`, with card-listed variants `H4` and `D1` also generated as backtest setfiles |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | ATR-trail dependent; expected hours to days on H1/H4/D1 |
| Expected drawdown profile | Whipsaw-sensitive breakout losses bounded by the ATR stop |
| Regime preference | volatility-expansion trend breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView invite-only strategy page
**Pointer:** `https://www.tradingview.com/script/MwlYnQZT/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10812_tv-bb-atrtrail.md`

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
| v1 | 2026-06-05 | Initial build from card | 8ab48374-fdc8-4ca7-a989-ab5a26ed0b77 |
