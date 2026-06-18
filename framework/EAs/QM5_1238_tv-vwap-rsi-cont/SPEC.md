# QM5_1238_tv-vwap-rsi-cont - Strategy Spec

**EA ID:** QM5_1238
**Slug:** tv-vwap-rsi-cont
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades M15 intraday pullback-continuation signals around the broker-day session VWAP. A long setup requires the last closed M15 bar to close above session VWAP, the prior bar low to touch the VWAP plus 0.15 ATR(14), a bullish closed bar, RSI(14) between 50 and 70, enough session range, and the London 07:00-17:00 window. A short setup mirrors the rule below VWAP with RSI between 30 and 50. Exits are the 1.5R take profit, a close back through session VWAP, a 16-bar time stop, breakeven movement after +1R, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_M15` | M15 expected | Signal and session VWAP timeframe from the card. |
| `strategy_atr_period` | `14` | 2-100 | ATR lookback for VWAP touch band and stop size. |
| `strategy_rsi_period` | `14` | 2-100 | RSI lookback for continuation confirmation. |
| `strategy_vwap_touch_atr` | `0.15` | 0.0-2.0 | ATR fraction added/subtracted around VWAP for the prior-bar pullback touch. |
| `strategy_stop_atr_mult` | `1.20` | 0.1-10.0 | Initial stop distance in ATR multiples. |
| `strategy_tp_r_mult` | `1.50` | 0.1-10.0 | Take-profit distance in initial-risk multiples. |
| `strategy_be_trigger_r` | `1.00` | 0.1-10.0 | Profit in R at which the stop moves to breakeven. |
| `strategy_max_hold_bars` | `16` | 1-500 | Maximum M15 bars to hold before strategy close. |
| `strategy_london_start_hour` | `7` | 0-23 | London local start hour for new entries. |
| `strategy_london_end_hour` | `17` | 1-24 | London local end hour for new entries. |
| `strategy_min_range_h1_atr` | `0.60` | 0.0-10.0 | Minimum session high-low range versus H1 ATR(14). |
| `strategy_spread_days` | `20` | 1-250 | Historical days used for the entry-hour median spread baseline. |
| `strategy_spread_mult` | `2.0` | 0.1-20.0 | Maximum allowed current spread versus entry-hour median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid FX pair with M15 OHLC and tick-volume VWAP support.
- `GBPUSD.DWX` - Card-listed liquid FX pair with M15 OHLC and tick-volume VWAP support.
- `USDJPY.DWX` - Card-listed liquid FX pair with M15 OHLC and tick-volume VWAP support.
- `AUDUSD.DWX` - Card-listed liquid FX pair with M15 OHLC and tick-volume VWAP support.
- `USDCAD.DWX` - Card-listed liquid FX pair with M15 OHLC and tick-volume VWAP support.
- `NZDUSD.DWX` - Card-listed liquid FX pair with M15 OHLC and tick-volume VWAP support.
- `XAUUSD.DWX` - Card-listed metal CFD with M15 OHLC and tick-volume VWAP support.
- `XTIUSD.DWX` - Card-listed oil CFD with M15 OHLC and tick-volume VWAP support.
- `NDX.DWX` - Card-listed Nasdaq index CFD with M15 OHLC and tick-volume VWAP support.
- `WS30.DWX` - Card-listed Dow index CFD with M15 OHLC and tick-volume VWAP support.
- `GDAXI.DWX` - Card-listed DAX index CFD with M15 OHLC and tick-volume VWAP support.
- `UK100.DWX` - Card-listed FTSE index CFD with M15 OHLC and tick-volume VWAP support.

**Explicitly NOT for:**
- Non-DWX symbols - Build and P2 baselines require symbols present in `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1` ATR(14) for minimum session range |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `15` |
| Typical hold time | Intraday, up to 16 M15 bars (about 4 hours) |
| Expected drawdown profile | ATR-bounded single-position intraday risk with one session trade per symbol/magic. |
| Regime preference | Intraday continuation after VWAP pullback. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView popular Pine-scripts catalog
**Pointer:** `https://www.tradingview.com/scripts/?sort=popular`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1238_tv-vwap-rsi-cont.md`

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
| v1 | 2026-06-18 | Initial build from card | 2f23e59b-7aa6-4fae-becb-6fc600a414ee |
