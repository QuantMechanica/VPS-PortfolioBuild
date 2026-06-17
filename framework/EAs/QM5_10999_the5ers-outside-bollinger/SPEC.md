# QM5_10999_the5ers-outside-bollinger — Strategy Spec

**EA ID:** QM5_10999
**Slug:** `the5ers-outside-bollinger`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (The5ers blog — "Forex Trading Strategy Outside Bollinger Bands")
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Mean-reversion against the Bollinger Bands (period 20, deviation 2.0, close).
On each closed H1 bar the EA measures the candle body `[min(open,close), max(open,close)]`.
A LONG fires at the next H1 open when the entire body of the last closed bar lies
below the lower band (`body_high < lower_band`) with a minimal reversal confirmation
(`close>open` OR `close>prior close`); a SHORT fires when the entire body lies above
the upper band (`body_low > upper_band`) with the inverse confirmation. The stop is
placed beyond the signal bar's extreme by `0.5 × ATR(14)` (long: `low - 0.5·ATR`;
short: `high + 0.5·ATR`). A hard take-profit sits at 1.5R; the primary exit closes the
position when a closed bar reaches/crosses the Bollinger middle band (SMA20); a time
stop closes after 18 closed H1 bars. Two filters suppress weak setups: skip when the
current BB bandwidth `(upper-lower)/middle` ranks in the bottom 10th percentile of the
last 240 bars (squeeze, fake-signal prone), and skip when the signal candle's range
exceeds `3.0 × ATR(14)` (news-shock continuation). One position per magic; no pyramiding.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10-50 | Bollinger Band period |
| `strategy_bb_deviation` | 2.0 | 1.5-3.0 | Bollinger Band standard deviations |
| `strategy_atr_period` | 14 | 7-30 | ATR period (stop distance + range filter) |
| `strategy_sl_atr_mult` | 0.5 | 0.2-2.0 | Stop placed beyond bar extreme by mult×ATR |
| `strategy_tp_rr` | 1.5 | 0.5-3.0 | Secondary hard take-profit in R-multiples |
| `strategy_use_color_confirm` | true | true/false | Require candle-color OR close>prior-close reversal confirm |
| `strategy_time_stop_bars` | 18 | 6-48 | Close after N closed H1 bars |
| `strategy_bandwidth_lookback` | 240 | 60-480 | Bars for bandwidth percentile sample |
| `strategy_bandwidth_pctile` | 10.0 | 0-50 | Skip if bandwidth below this percentile |
| `strategy_range_atr_cap` | 3.0 | 1.5-6.0 | Skip if signal-candle range > cap×ATR |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid FX major; tight bands, clean mean-reversion to SMA20.
- `GBPUSD.DWX` — liquid major with frequent band over-extensions.
- `USDJPY.DWX` — liquid major; JPY pip scaling handled via QM pip-correct stop rules.
- `AUDUSD.DWX` — liquid commodity major with range-bound mean-reversion behaviour.
- `EURJPY.DWX` — liquid cross; volatility gives clean outside-body reversal signals.

**Explicitly NOT for:**
- Index / metal CFDs (NDX/WS30/XAUUSD.DWX) — source is explicitly forex-oriented; index gap/trend dynamics differ from FX band mean-reversion.

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
| Trades / year / symbol | `~55` |
| Typical hold time | `hours (a few to ~18 H1 bars)` |
| Expected drawdown profile | `moderate; mean-reversion against extension, capped by ATR stop` |
| Regime preference | `mean-revert (range/oscillating bands)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** `forum` (broker/prop-firm blog article)
**Pointer:** `https://the5ers.com/outside-bolinger-bands/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10999_the5ers-outside-bollinger.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
