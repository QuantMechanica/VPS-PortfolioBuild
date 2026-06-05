# QM5_10790_tv-bb-trend — Strategy Spec

**EA ID:** QM5_10790
**Slug:** `tv-bb-trend`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

A volatility-band breakout trend follower. On each closed bar the EA reads
Bollinger Bands (length 7, std-dev multiplier 1.5). It goes LONG when the
previous bar opened below the upper band and the current (just-closed) bar
closes above the upper band — i.e. price breaks out of the upper band — with no
open position. It goes SHORT symmetrically when the previous bar opened above
the lower band and the current bar closes below the lower band. The position is
closed when price returns to the Bollinger middle line (the source-pure exit).
A V5 safety stop is placed at 1.5 × ATR(14) from the entry, since the source
strategy carries no native stop. An optional moving-average side filter is
available but disabled by default for the source-pure baseline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 7 | 5-50 | Bollinger Band period (source example length 7). |
| `strategy_bb_deviation` | 1.5 | 1.0-3.0 | Bollinger std-dev multiplier (source 1.5). |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the safety stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.5-4.0 | Stop distance multiple: SL = entry ± ATR × mult. |
| `strategy_ema_filter_period` | 0 | 0-300 | Optional MA side filter; 0 = off (source-pure baseline). |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

Portable across the card's R3 P2 basket of liquid FX, metals, and indices.

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; clean Bollinger expansion behaviour.
- `GBPUSD.DWX` — major with frequent volatility breakouts.
- `USDJPY.DWX` — trending major, suits band-breakout continuation.
- `XAUUSD.DWX` — gold; strong volatility-expansion trends.
- `GDAXI.DWX` — DAX 40 index; card listed "GER40" → canonical DWX name is `GDAXI.DWX`.
- `NDX.DWX` — Nasdaq 100; trending US large-cap index (live-tradable).
- `WS30.DWX` — Dow 30; trending US large-cap index (live-tradable).

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker does not route orders); not in card R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~60 |
| Typical hold time | hours to a few days (band-expansion ride) |
| Expected drawdown profile | moderate; breakout strategy with ATR safety stop |
| Regime preference | volatility-expansion / trend |
| Win rate target (qualitative) | low-to-medium (trend-follower) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView open-source strategy script)
**Pointer:** `https://www.tradingview.com/script/qs3ZzUi2/` — "BT-Bollinger Bands - Trend Following", author `Credsonb`, published 2022-09-22
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10790_tv-bb-trend.md`

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
| v1 | 2026-06-05 | Initial build from card | 2ba17bfd-d829-46e0-a0e9-1e1d2d33305f |
