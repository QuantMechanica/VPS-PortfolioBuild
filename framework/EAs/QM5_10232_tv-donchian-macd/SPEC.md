# QM5_10232_tv-donchian-macd — Strategy Spec

**EA ID:** QM5_10232
**Slug:** `tv-donchian-macd`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (TradingView, LordRobrecht "Trend Following with Donchian Channels and MACD")
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

Trend-following breakout with a MACD trend filter. On each closed bar the EA
builds a 50-bar Donchian channel from the prior 50 closed bars (the highest
high and lowest low, excluding the most recent bar). It goes long when the last
closed bar makes a new 50-bar high, the MACD line is above its signal line, and
both the MACD line and signal line are above zero. It goes short when the last
closed bar makes a new 50-bar low, the MACD line is below its signal line, and
both lines are below zero. The initial stop is placed 4 ATRs from the entry
price; the position is then exited only by a 4-ATR trailing stop. One position
per magic number is enforced by the framework, so a reverse can only fire after
the opposite Donchian+MACD setup completes — no simultaneous long and short.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_period` | 50 | 10-200 | Donchian breakout lookback in bars |
| `strategy_macd_fast` | 12 | 2-50 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 3-100 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 2-50 | MACD signal EMA period |
| `strategy_atr_period` | 14 | 5-50 | ATR period for initial + trailing stop |
| `strategy_atr_mult` | 4.0 | 1.0-10.0 | Stop distance in ATRs (source = 4) |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, news,
> Friday-close, stress, seed) are documented in `V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — card-recommended; strong sustained trends suit Donchian breakouts.
- `GDAXI.DWX` — DAX 40, the available DWX equivalent of the card's "GER40"; trending index.
- `NDX.DWX` — Nasdaq 100, card-recommended; momentum-driven index trends.
- `GBPJPY.DWX` — card-recommended; high-volatility yen cross with strong directional moves.
- `EURJPY.DWX` — card-recommended; trending yen cross.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker does not route live); not in the card's recommended set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` (card also requests H4 with the same 50-bar length) |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~30` |
| Typical hold time | `days to weeks (trend ride on D1/H4)` |
| Expected drawdown profile | `low win-rate, fat-tailed winners; choppy regimes bleed via stopped breakouts` |
| Regime preference | `trend / breakout` |
| Win rate target (qualitative) | `low` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `forum` (TradingView Pine script)
**Pointer:** `https://www.tradingview.com/script/bGjB7COd-Trend-Following-with-Donchian-Channels-and-MACD/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10232_tv-donchian-macd.md`

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
| v1 | 2026-06-05 | Initial build from card | bc416466-631f-4f3f-a952-f1284f9e3e30 |
