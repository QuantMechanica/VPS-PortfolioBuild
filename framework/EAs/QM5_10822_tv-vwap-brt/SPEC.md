# QM5_10822_tv-vwap-brt - Strategy Spec

**EA ID:** QM5_10822
**Slug:** `tv-vwap-brt`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA builds a broker-day session VWAP from closed intraday bars. A long setup starts when price closes from below to above VWAP, then later retests the VWAP area within an ATR-based buffer while remaining aligned above EMA trend. A short setup mirrors this from above to below VWAP, with retest from below and EMA alignment below price. Entries use market orders on the confirmation candle after the retest, with ATR-based stop-loss and take-profit; the optional signal exit closes if price crosses back through VWAP against the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 50 | 50-200 | EMA trend filter period from the card baseline and P3 sweep set. |
| `strategy_atr_period` | 14 | 14 | ATR period used for retest buffer, stop, and target. |
| `strategy_retest_buffer_atr` | 0.25 | 0.10-0.50 | Distance around VWAP that qualifies as the retest zone, measured in ATR multiples. |
| `strategy_retest_lookback` | 10 | 5-20 | Maximum bars after breakout in which a retest may confirm. |
| `strategy_min_session_bars` | 8 | 8+ | Minimum number of session bars before VWAP signals are valid. |
| `strategy_atr_sl_mult` | 1.5 | 1.2-2.0 | Stop-loss distance in ATR multiples. |
| `strategy_atr_tp_mult` | 2.5 | 2.0-3.0 | Take-profit distance in ATR multiples. |
| `strategy_max_spread_atr_frac` | 0.20 | 0.05-0.50 | No-trade spread guard expressed as a fraction of ATR. |
| `strategy_vwap_exit_enabled` | true | true/false | Enables the optional exit when price crosses VWAP against the position. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with continuous intraday OHLCV for VWAP retests.
- `GBPUSD.DWX` - liquid FX major matching the card's portable DWX FX scope.
- `USDJPY.DWX` - liquid FX major matching the card's portable DWX FX scope.
- `XAUUSD.DWX` - gold port of card-stated `XAUUSD`; matrix symbol carries the `.DWX` suffix.
- `GDAXI.DWX` - available DAX custom symbol used for card-stated `GER40.DWX`.
- `NDX.DWX` - US large-cap index proxy listed directly by the card.
- `WS30.DWX` - US large-cap index proxy listed directly by the card.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - not registered without `.DWX` in research/backtest artifacts.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday; minutes to hours depending on ATR target reach. |
| Expected drawdown profile | Choppy VWAP sessions are the main failure mode; EMA trend, retest buffer, and session age are the primary dampers. |
| Regime preference | Intraday continuation after VWAP breakout and retest. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/zYIRkvHS-VWAP-Breakout-Retest-Trend-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10822_tv-vwap-brt.md`

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
| v1 | 2026-06-05 | Initial build from card | b53d757c-aaee-4a43-8126-e9fe906f9ee2 |
