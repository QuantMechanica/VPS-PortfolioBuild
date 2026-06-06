# QM5_10857_tv-qing-lrc - Strategy Spec

**EA ID:** QM5_10857
**Slug:** tv-qing-lrc
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades long-only mean reversion into a bullish linear regression channel (LRC). Once per closed bar it fits a least-squares linear regression of close over the last `lrc_length` bars and forms channel bands at +/- `lrc_dev` times the residual standard deviation. A long is allowed only when the bullish bias holds (the LRC upper band sits above EMA(`ema_period`)), the channel is wide enough (width >= `width_atr_min` * ATR), and the EMA slope is not negative for three consecutive bars. It buys when the most recent closed bar's low touches or pierces the lower LRC band. The take-profit is the LRC upper band; the stop is the lower of the recent pivot support and entry minus `atr_sl_mult` * ATR(`atr_len`). The position exits early when the LRC lower band crosses below the EMA (trend weakness), or after `time_exit_bars` bars if neither stop nor target is hit. A V5 spread guard skips entries whose spread exceeds `spread_stop_frac` of the stop distance, and same-bar re-entry after a weakness exit is suppressed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `lrc_length` | 100 | 50-150 | Bars used for the linear regression channel fit. |
| `lrc_dev` | 2.0 | 1.5-2.5 | Std-dev multiplier for the upper/lower channel bands. |
| `ema_period` | 20 | >0 | Trend-filter EMA period (bias + weakness-cross exit). |
| `atr_len` | 14 | >0 | ATR period for stop sizing and width filter. |
| `atr_sl_mult` | 1.5 | 1.0-2.0 | ATR multiple for the entry-minus-ATR stop candidate. |
| `pivot_lookback` | 5 | 3-10 | Window for the recent swing-low pivot support. |
| `time_exit_bars` | 20 | 12-30 | Maximum bars held before the discretionary time exit. |
| `width_atr_min` | 0.75 | >0 | Minimum channel width as an ATR multiple. |
| `spread_stop_frac` | 0.15 | >0 | Skip if spread > this fraction of the stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major from the card's R3 P2 basket.
- `GBPUSD.DWX` - liquid FX major from the card's R3 P2 basket.
- `XAUUSD.DWX` - gold exposure matching the source's "Gold Chances" framing.
- `NDX.DWX` - liquid index CFD from the card's R3 P2 basket.
- `GDAXI.DWX` - DAX exposure; the available DWX-matrix port for the card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX registration uses `GDAXI.DWX`.
- `SP500.DWX` - mentioned only as a possible later test path, not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 (card baseline H1/H4; smoke + P2 baseline on H1) |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Intraday to multi-day, capped at 20 bars |
| Expected drawdown profile | Moderate; main risk is repeated lower-channel buys during a real trend break |
| Regime preference | Trend-filtered mean reversion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/ZDhizQgu-Qing-LRC-S-R-EMA-Trend-Cross-Logic/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10857_tv-qing-lrc.md`

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
| v1 | 2026-06-06 | Initial build from card | d6f0893a-558f-4310-828c-61504e6a07e8 |
