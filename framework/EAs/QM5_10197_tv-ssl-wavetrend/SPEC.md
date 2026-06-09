# QM5_10197_tv-ssl-wavetrend — Strategy Spec

**EA ID:** QM5_10197
**Slug:** `tv-ssl-wavetrend`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades H1 closed-bar trend and momentum confluence from the TradingView SSL + WaveTrend strategy. A long entry requires a bullish SSL Hybrid baseline, an SSL channel cross up, a WaveTrend cross up, acceptable candle height, and a candle fully inside the Keltner channel; shorts use the mirrored bearish conditions. Entries are market orders with a 1.5 ATR(14) stop and a 2.0R take-profit, while discretionary exits are disabled so positions close by bracket or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ssl_period` | 10 | >=2 | SSL channel SMA period for high/low channel lines. |
| `strategy_baseline_ema` | 60 | >=2 | EMA baseline used as the bullish/bearish SSL Hybrid proxy. |
| `strategy_wt_channel_len` | 10 | >=1 | WaveTrend ESA/channel length. |
| `strategy_wt_average_len` | 21 | >=1 | WaveTrend TCI average length. |
| `strategy_wt_signal_len` | 4 | >=1 | WaveTrend signal-line smoothing length. |
| `strategy_keltner_ema` | 20 | >=1 | Keltner midline EMA period. |
| `strategy_keltner_atr_mult` | 1.5 | >0 | ATR multiplier for Keltner upper/lower envelope. |
| `strategy_atr_period` | 14 | >=1 | ATR period for stop distance and candle-height filter. |
| `strategy_atr_sl_mult` | 1.5 | >0 | Stop distance as a multiple of ATR. |
| `strategy_rr` | 2.0 | >0 | Reward:risk multiplier for take-profit. |
| `strategy_max_candle_atr` | 1.5 | >0 | Maximum entry candle range measured in ATR. |
| `strategy_ema_sr_period` | 200 | >=2 | EMA support/resistance check used to reject blocked targets. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed FX major with matrix coverage.
- `GBPUSD.DWX` — card-listed FX major with matrix coverage.
- `XAUUSD.DWX` — card-listed gold CFD with matrix coverage.
- `GDAXI.DWX` — matrix-available DAX proxy for the card's unavailable `DAX.DWX` target.

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 65 |
| Typical hold time | hours to days, bounded by SL/TP bracket and Friday close |
| Expected drawdown profile | bounded by one-position fixed-risk ATR bracket |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `SSL + Wave Trend Strategy`, author `kevinmck100`, published 2022-09-11, https://www.tradingview.com/script/J0urw1QI-SSL-Wave-Trend-Strategy/
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_10197_tv-ssl-wavetrend.md`

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
| v1 | 2026-06-09 | Initial build from card | ccbe01b1-7e4c-4486-9721-97d868d49aa3 |
