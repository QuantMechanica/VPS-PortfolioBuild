# QM5_11390_midnight-setup-d1-candle-breakout — Strategy Spec

**EA ID:** QM5_11390
**Slug:** `midnight-setup-d1-candle-breakout`
**Source:** `dfd32799-2055-5ef8-b99b-dcbfa51daba0` (Advanced System #1 "Midnight Setup", forex-strategies-revealed.com compilation)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Pure price-action, indicator-free daily breakout straddle. At each new D1 bar
(the broker-time "midnight" boundary, taken from the bar timestamp via
`QM_IsNewBar`/`iTime(_Symbol, PERIOD_D1, 0)` — never a fixed wall-clock), the EA
inspects the prior CLOSED daily candle. If that candle's range
`(High[1] - Low[1])` is at least `strategy_min_range_pips`, it places an OCO
straddle: a BUY STOP at `High[1] + strategy_offset_pips` and a SELL STOP at
`Low[1] - strategy_offset_pips`. Both pendings expire at the end of the current
daily bar (the next midnight). Whichever fills first becomes the trade; the
unfilled peer is cancelled immediately (one-cancels-the-other). The position
carries a fixed `strategy_sl_pips` stop and `strategy_tp_pips` take-profit. One
position per magic per symbol; one straddle attempt per day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_min_range_pips` | 90 | 50-150 | Skip days whose prior D1 candle range is below this |
| `strategy_offset_pips` | 5 | 3-15 | Stop-entry offset placed beyond the prior candle High/Low |
| `strategy_sl_pips` | 50 | 20-80 | Fixed stop-loss distance from entry |
| `strategy_tp_pips` | 100 | 60-200 | Fixed take-profit distance from entry |
| `strategy_spread_pct_of_sl` | 30.0 | 5-100 | Block entry if live spread exceeds this % of the SL distance (fail-open on zero modeled spread) |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — primary; the source ("Midnight Setup") was tested on GBP/USD, a high daily-range major suited to a 90-pip range filter.
- `EURUSD.DWX` — most liquid major; comparable daily-range behaviour, the card's P3 variant.

**Explicitly NOT for:**
- Index / metal CFDs (`NDX.DWX`, `WS30.DWX`, `XAUUSD.DWX`, …) — the fixed pip range/SL/TP thresholds are calibrated to FX-major pip scale and do not transfer to index point scale.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` (prior D1 candle only) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~25 |
| Typical hold time | intraday to ~1 day (SL/TP within the daily bar) |
| Expected drawdown profile | bounded by the fixed 50-pip stop per trade; clustered losses possible in low-range chop |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | low-to-medium (2:1 reward:risk compensates) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dfd32799-2055-5ef8-b99b-dcbfa51daba0`
**Source type:** forum/compilation (anonymous, forex-strategies-revealed.com)
**Pointer:** local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_forex-strategy-7-pdf-free.pdf`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11390_midnight-setup-d1-candle-breakout.md`

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
| v1 | 2026-06-18 | Initial build from card | OCO D1 straddle, reference QM5_10006 |
