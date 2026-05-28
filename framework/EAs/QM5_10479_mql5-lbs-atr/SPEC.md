# QM5_10479_mql5-lbs-atr - Strategy Spec

**EA ID:** QM5_10479
**Slug:** `mql5-lbs-atr`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

At each new H1 bar, the EA checks whether broker time is one of three configured setup hours. If so, it reads ATR(14), takes the maximum high and minimum low across bars 0 and 1, then places a buy stop one ATR above the maximum and a sell stop one ATR below the minimum. The stop loss is one ATR from entry and the target is 2R. Unfilled sibling stop orders are cancelled after one side fills, at the next configured setup hour, or by end-of-day expiration; open positions close after 12 H1 bars or during the final broker hour of the day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR lookback used for entry offset and fixed stop distance. |
| `strategy_atr_entry_mult` | 1.0 | 0.1-10.0 | ATR multiple added to the recent high or subtracted from the recent low for pending stop placement. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiple used as the fixed stop-loss distance from entry. |
| `strategy_reward_r` | 2.0 | 0.5-10.0 | Take-profit multiple of initial risk. |
| `strategy_setup_hour_1` | 0 | 0-23 | First broker-hour setup window. |
| `strategy_setup_hour_2` | 8 | 0-23 | Second broker-hour setup window. |
| `strategy_setup_hour_3` | 16 | 0-23 | Third broker-hour setup window. |
| `strategy_max_hold_bars` | 12 | 1-96 | Maximum bars to hold an open position before strategy exit. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional spread cap in points; 0 disables the per-EA cap and leaves framework/broker checks. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `GBPUSD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `USDJPY.DWX` - liquid FX major with DWX OHLC and ATR support.
- `USDCHF.DWX` - liquid FX major with DWX OHLC and ATR support.
- `USDCAD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `AUDUSD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `NZDUSD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `XAUUSD.DWX` - card-stated metal exposure with DWX OHLC and ATR support.
- `XTIUSD.DWX` - card-stated oil exposure with DWX OHLC and ATR support.
- `SP500.DWX` - liquid US large-cap index CFD equivalent, backtest-only custom symbol.
- `NDX.DWX` - liquid Nasdaq 100 index CFD equivalent.
- `WS30.DWX` - liquid Dow 30 index CFD equivalent.
- `GDAXI.DWX` - liquid DAX index CFD equivalent.
- `UK100.DWX` - liquid FTSE 100 index CFD equivalent.

**Explicitly NOT for:**
- Non-DWX symbols - registry and backtest artifacts require canonical `.DWX` symbols.
- Sector ETFs and Russell 2000 proxies - not named by the card and not part of this broad baseline basket.

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
| Trades / year / symbol | `70` |
| Typical hold time | `up to 12 H1 bars or end of trading day` |
| Expected drawdown profile | `breakout strategy with fixed ATR risk and bounded intraday holding period` |
| Regime preference | `volatility-expansion / breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `forum / codebase`
**Pointer:** `https://www.mql5.com/en/code/22884`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10479_mql5-lbs-atr.md`

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
| v1 | 2026-05-28 | Initial build from card | fd85e675-7217-4ab6-a2bf-4706eb387b18 |
