# QM5_10465_mql5-rsi-cloud - Strategy Spec

**EA ID:** QM5_10465
**Slug:** `mql5-rsi-cloud`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades a dual-RSI cloud reversal on H1 closed bars. A long signal occurs when both fast and slow RSI values were below the DOWN level on the prior closed bar and both leave that zone above the level on the most recent closed bar. A short signal occurs when both RSI values were above the UP level and both leave that zone below the level. Open trades close on the opposite qualifying RSI-cloud signal, while the broker protective stop is 1.5 x ATR(14) and the take-profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 only for baseline | Closed-bar timeframe for RSI signals. |
| `strategy_fast_rsi_period` | `5` | `2-100` | Fast RSI line in the dual cloud. |
| `strategy_slow_rsi_period` | `14` | `2-100` | Slow RSI line in the dual cloud. |
| `strategy_down_level` | `30.0` | `1.0-49.0` | Oversold zone threshold; both RSI lines must leave upward for long entry. |
| `strategy_up_level` | `70.0` | `51.0-99.0` | Overbought zone threshold; both RSI lines must leave downward for short entry. |
| `strategy_atr_period` | `14` | `2-100` | ATR period used for the fixed protective stop. |
| `strategy_atr_sl_mult` | `1.5` | `0.1-10.0` | ATR multiplier for stop distance. |
| `strategy_tp_r_mult` | `2.0` | `0.1-10.0` | Take-profit multiple of initial risk. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid USD major with full OHLC history for RSI testing.
- `GBPUSD.DWX` - liquid USD major with full OHLC history for RSI testing.
- `USDJPY.DWX` - liquid USD major with full OHLC history for RSI testing.
- `USDCHF.DWX` - liquid USD major with full OHLC history for RSI testing.
- `USDCAD.DWX` - liquid USD major with full OHLC history for RSI testing.
- `AUDUSD.DWX` - liquid USD major with full OHLC history for RSI testing.
- `NZDUSD.DWX` - liquid USD major with full OHLC history for RSI testing.
- `XAUUSD.DWX` - card explicitly includes XAUUSD as a portable baseline market.
- `SP500.DWX` - available S&P 500 custom symbol for index-CFD backtests.
- `NDX.DWX` - available Nasdaq 100 index CFD.
- `WS30.DWX` - available Dow 30 index CFD.
- `GDAXI.DWX` - available DAX index CFD.
- `UK100.DWX` - available FTSE 100 index CFD.

**Explicitly NOT for:**
- `SPX500.DWX` - not a canonical DWX matrix symbol.
- `SPY.DWX` - not a canonical DWX matrix symbol.
- `ES.DWX` - not a canonical DWX matrix symbol.
- `XAGUSD.DWX` - not named by the card's baseline universe.
- `XTIUSD.DWX` - not named by the card's baseline universe.
- `XNGUSD.DWX` - not named by the card's baseline universe.

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
| Trades / year / symbol | `70` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `mean-reversion oscillator losses can cluster in persistent trends` |
| Regime preference | `mean-revert / oscillator-reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/39497`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10465_mql5-rsi-cloud.md`

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
| v1 | 2026-05-28 | Initial build from card | d0bb125d-4c89-4660-9bc3-955c4bc5f3bb |
