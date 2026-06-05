# QM5_10081_gh-victor-rsi — Strategy Spec

**EA ID:** QM5_10081
**Slug:** `gh-victor-rsi`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

A mean-reversion reversal that trades RSI/price divergence on the H1 close.
The EA computes RSI(14) on close and scans the last 100 closed candles for two
local price extremes and their matching RSI extremes. It goes long when the more
recent price swing low is *below* the older swing low while the more recent RSI
swing low is *above* the older one (a bullish divergence), both RSI lows sit
below 30, and the latest closed candle is bullish (close > open). It goes short
on the mirror condition: a higher price swing high paired with a lower RSI swing
high, both RSI highs above 70, and the latest closed candle bearish. There is no
fixed take-profit; the initial stop is placed 1% from entry and then trailed as a
1% percent-trailing stop that only ratchets in the trade's favour. Only one
position per symbol/magic is allowed, and the EA will not re-enter if it already
opened a position on the prior closed bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `inp_rsi_period` | 14 | 2-50 | RSI period, applied to close. |
| `inp_rsi_oversold` | 30.0 | 5-45 | Both RSI local-lows must be below this for a long. |
| `inp_rsi_overbought` | 70.0 | 55-95 | Both RSI local-highs must be above this for a short. |
| `inp_div_lookback_max` | 100 | 30-300 | Closed-candle search window for divergence pivots. |
| `inp_pivot_strength` | 2 | 1-5 | Bars on each side that define a local extreme. |
| `inp_pivot_min_gap` | 5 | 2-50 | Minimum bar separation between the two compared pivots. |
| `inp_sl_percent` | 1.0 | 0.2-5.0 | Initial stop distance, percent of entry price. |
| `inp_trail_percent` | 1.0 | 0.2-5.0 | Percent trailing-stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean RSI swings, card primary symbol.
- `GBPUSD.DWX` — liquid major with frequent reversal swings well-suited to divergence.
- `USDJPY.DWX` — liquid major; mean-reversion behaviour around RSI extremes.
- `XAUUSD.DWX` — gold; strong impulsive swings that produce pronounced RSI divergences.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — card targets FX majors + metals; not validated here.

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
| Trades / year / symbol | `~30` |
| Typical hold time | `hours to a few days (trailed exit)` |
| Expected drawdown profile | `moderate; reversal entries with a 1% trailing stop` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** `forum` (GitHub repository)
**Pointer:** Victor Algo, "Divergence Rsi de LeTraderSmart" — https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Divergence%20Rsi%20de%20LeTraderSmart/Expert/DivergenceRsi.mq5
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10081_gh-victor-rsi.md`

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
| v1 | 2026-06-05 | Initial build from card (in-place rebuild, DL-069) | b0bd92e3-e584-4fe1-9a44-a1de9195f2ba |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
