# QM5_9350_brooks-failed-ttr-h4 - Strategy Spec

**EA ID:** QM5_9350
**Slug:** brooks-failed-ttr-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

The EA trades failed breakouts from a tight H4 trading range. A range locks when the last 20 closed H4 bars have a Donchian width no larger than 1.5 ATR(14), at least 14 small candle bodies, and no bar outside the compression envelope. If price breaks beyond the locked range by 0.2 ATR and then closes back inside within 8 H4 bars, the EA enters against the failed breakout. The stop is beyond the failed-breakout extreme by 0.3 ATR, the target is the opposite side of the original range plus 1.0 ATR, and positions close after 30 H4 bars if neither stop nor target fires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_donchian_period` | 20 | 10-80 | Closed H4 bars used to define the tight trading range. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for range, breakout, stop and target distances. |
| `strategy_min_small_bodies` | 14 | 1-20 | Minimum number of compressed candle bodies inside the range window. |
| `strategy_range_atr_mult` | 1.5 | 0.5-4.0 | Maximum Donchian range width as a multiple of ATR. |
| `strategy_body_atr_mult` | 0.4 | 0.1-2.0 | Maximum candle-body size counted as a small body. |
| `strategy_envelope_atr_mult` | 0.1 | 0.0-1.0 | Extra envelope allowance around the Donchian range. |
| `strategy_breakout_atr_mult` | 0.2 | 0.0-2.0 | Minimum close beyond the range to mark the initial breakout. |
| `strategy_failure_inside_atr` | 0.5 | 0.0-3.0 | Minimum penetration back inside the range for the failure trigger. |
| `strategy_stop_buffer_atr` | 0.3 | 0.0-3.0 | Stop buffer beyond the breakout extreme. |
| `strategy_target_extension_atr` | 1.0 | 0.0-5.0 | Target extension beyond the opposite side of the range. |
| `strategy_max_spread_atr_mult` | 0.20 | 0.0-1.0 | Maximum non-zero spread as a share of ATR. |
| `strategy_breakout_window_bars` | 20 | 1-60 | Bars allowed after range lock for the first breakout. |
| `strategy_failure_window_bars` | 8 | 1-20 | Bars allowed after breakout for the failure trigger. |
| `strategy_time_stop_bars` | 30 | 1-120 | Maximum H4 bars to hold before market exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with continuous H4 price-action structure.
- `GBPUSD.DWX` - liquid FX major with enough H4 breakout/reversal events.
- `USDJPY.DWX` - liquid FX major with distinct rate/risk sensitivity.
- `AUDUSD.DWX` - liquid FX major with commodity/risk sensitivity.
- `USDCAD.DWX` - liquid FX major with oil-linked macro behavior.
- `USDCHF.DWX` - liquid FX major with defensive-flow behavior.
- `NZDUSD.DWX` - liquid FX major and additional commodity-currency exposure.
- `XAUUSD.DWX` - liquid metal CFD where failed range breaks are common.
- `XTIUSD.DWX` - oil CFD, adding energy exposure beyond the current XNG focus.
- `SP500.DWX` - broad US index backtest-only proxy.
- `NDX.DWX` - liquid US index CFD and live-routable SP500 companion.
- `WS30.DWX` - liquid US index CFD and live-routable SP500 companion.
- `GDAXI.DWX` - European index diversification.
- `UK100.DWX` - UK index diversification.

**Explicitly NOT for:**
- `FRA40.DWX` - named in the card but absent from `dwx_symbol_matrix.csv`.
- `JP225.DWX` - named in the card but absent from `dwx_symbol_matrix.csv`.
- Non-DWX symbols - the build and backtest contract requires `.DWX` research symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework H4 setfile path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Several H4 bars to roughly five trading days |
| Expected drawdown profile | Medium, because failed breakouts can cluster during strong continuation regimes |
| Regime preference | Mean-reversion after failed volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum and book lineage
**Pointer:** ForexFactory Brooks thread cluster plus Al Brooks Wiley 2009/2012 price-action publications; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9350_brooks-failed-ttr-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9350_brooks-failed-ttr-h4.md`

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
| v1 | 2026-07-02 | Initial build from card | b2437fc8-38ec-4313-9984-554e3e3ddb37 |
