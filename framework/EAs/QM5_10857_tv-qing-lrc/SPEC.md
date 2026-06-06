# QM5_10857_tv-qing-lrc - Strategy Spec

**EA ID:** QM5_10857
**Slug:** tv-qing-lrc
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades long-only mean reversion into a bullish linear regression channel. On each closed H1 or H4 bar it builds a linear regression channel, confirms the channel upper band remains above EMA(20), rejects narrow channels and three-bar negative EMA slope, then buys when the signal bar touches the lower channel. The target is the channel upper band; the stop is the lower of recent pivot support and 1.5 ATR below entry. The EA exits early when the lower channel crosses below EMA(20), or after 20 bars if neither stop nor target has been reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lrc_length` | 100 | 10-300 | Bars used for the linear regression channel. |
| `strategy_channel_deviation` | 2.0 | >0 | Standard-deviation multiplier for upper and lower channel bands. |
| `strategy_pivot_lookback` | 5 | 1-20 | Bars on each side used to identify recent pivot support. |
| `strategy_atr_period` | 14 | >0 | ATR period for stop sizing and filter distances. |
| `strategy_stop_atr_mult` | 1.5 | >0 | ATR multiple for the initial stop candidate. |
| `strategy_support_atr_buffer` | 0.25 | >=0 | Maximum distance from recent pivot support for support-qualified entries. |
| `strategy_min_width_atr_mult` | 0.75 | >0 | Minimum channel width expressed as ATR multiple. |
| `strategy_time_exit_bars` | 20 | >0 | Maximum bars to hold before discretionary time exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major from the card's R3 P2 basket.
- `GBPUSD.DWX` - liquid FX major from the card's R3 P2 basket.
- `XAUUSD.DWX` - gold exposure matching the source's "Gold Chances" framing.
- `NDX.DWX` - liquid index CFD from the card's R3 P2 basket.
- `GDAXI.DWX` - DAX exposure; used as the available DWX matrix port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX registration uses `GDAXI.DWX`.
- `SP500.DWX` - mentioned only as a possible later test path, not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1, H4 |
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
