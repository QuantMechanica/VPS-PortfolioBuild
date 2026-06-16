# QM5_10715_tv-asian-box - Strategy Spec

**EA ID:** QM5_10715
**Slug:** tv-asian-box
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA builds a fixed Asian-session high/low box in the source timezone, default UTC+7. After the Asian session ends, it places a buy stop above the Asian high and a sell stop below the Asian low. It allows one trade per session day; when one side has filled, the opposite pending order is cancelled. Open positions are force-closed at the configured end-of-day time, and unfilled pending orders are cancelled at that same cutoff.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M15` | `PERIOD_M5` or `PERIOD_M15` | Base bar size used to build and trade the Asian box. |
| `strategy_source_utc_offset_hours` | `7` | `-12` to `14` | Fixed source timezone offset used for session boundaries. |
| `strategy_asian_start_hour` | `0` | `0` to `23` | Asian session start hour in source timezone. |
| `strategy_asian_start_min` | `0` | `0` to `59` | Asian session start minute in source timezone. |
| `strategy_asian_end_hour` | `6` | `0` to `23` | Asian session end hour in source timezone. |
| `strategy_asian_end_min` | `0` | `0` to `59` | Asian session end minute in source timezone. |
| `strategy_eod_close_hour` | `23` | `0` to `23` | Forced flat cutoff hour in source timezone. |
| `strategy_eod_close_min` | `55` | `0` to `59` | Forced flat cutoff minute in source timezone. |
| `strategy_atr_period` | `14` | `1` and above | Daily ATR period for range filter, stop distance, and optional target. |
| `strategy_fx_metal_sl_atr_mult` | `0.50` | `> 0` | Daily ATR stop multiplier for FX and metal symbols. |
| `strategy_index_sl_atr_mult` | `0.35` | `> 0` | Daily ATR stop multiplier for index symbols. |
| `strategy_min_range_atr_mult` | `0.20` | `>= 0` | Minimum Asian box size as a fraction of Daily ATR. |
| `strategy_max_range_atr_mult` | `1.50` | `> min` | Maximum Asian box size as a fraction of Daily ATR. |
| `strategy_max_spread_stop_frac` | `0.12` | `>= 0` | Maximum spread as a fraction of planned stop distance. |
| `strategy_entry_buffer_points` | `2.0` | `>= 0` | Stop-entry buffer beyond the Asian high/low in points. |
| `strategy_use_atr_tp` | `false` | `true/false` | Enables the optional ATR target variant for later sweeps. |
| `strategy_tp_atr_mult` | `1.50` | `> 0` | Daily ATR target multiplier when ATR TP is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-stated liquid FX target for Asian-session breakout behaviour.
- `GBPUSD.DWX` - card-stated liquid FX target for Asian-session breakout behaviour.
- `USDJPY.DWX` - card-stated liquid FX target with direct Asian-session relevance.
- `XAUUSD.DWX` - card-stated metal target with active overnight liquidity.
- `GDAXI.DWX` - DWX matrix equivalent for the card's `GER40.DWX` DAX exposure.
- `NDX.DWX` - card-stated US index CFD target.

**Explicitly NOT for:**
- Symbols not present in `framework/registry/dwx_symbol_matrix.csv` - build rules forbid phantom broker symbols.
- `GER40.DWX` - not present in the DWX matrix; mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | Daily ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `130` |
| Typical hold time | Intraday; flat by configured end of day |
| Expected drawdown profile | Breakout losses are capped by ATR stops; no overnight exposure |
| Regime preference | Volatility-expansion breakout after the Asian range |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `Asian Box Breakout Strategy`, author handle `waranyutrkm`, https://www.tradingview.com/script/P1hYfpeB-Asian-Box-Breakout-Strategy/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10715_tv-asian-box.md`

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
| v1 | 2026-05-31 | Initial build from card | 86e50e56-14a2-4b3f-9216-cbab6eb28a87 |
