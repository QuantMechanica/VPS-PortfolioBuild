# QM5_10297_cinar-mfi - Strategy Spec

**EA ID:** QM5_10297
**Slug:** `cinar-mfi`
**Source:** `1b906e79-c619-5a61-90db-ee19ac95a19f` (see `artifacts/cards_approved/QM5_10297_cinar-mfi.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA computes Money Flow Index over the last 14 closed D1 bars using high, low, close, and MT5 tick volume. It opens long when MFI(14) is at or below 20 and opens short when MFI(14) is at or above 80. If an opposite position is already open, the EA closes it and opens the new direction on the same closed-bar evaluation. When MFI is between 20 and 80, it holds the current position unless the ATR stop or framework Friday close exits it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for MFI and ATR signal reads. |
| `strategy_mfi_period` | `14` | `1+` | Closed-bar Money Flow Index lookback. |
| `strategy_long_threshold` | `20.0` | `< strategy_short_threshold` | MFI level at or below which a long reversal signal is active. |
| `strategy_short_threshold` | `80.0` | `> strategy_long_threshold` | MFI level at or above which a short reversal signal is active. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.0` | `>0` | ATR multiple used to place the catastrophic stop. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `AUDCHF.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `AUDJPY.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `AUDNZD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `AUDUSD.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `CADCHF.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `CADJPY.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `CHFJPY.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `EURAUD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `EURCAD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `EURCHF.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `EURGBP.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `EURJPY.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `EURNZD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `EURUSD.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `GBPAUD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `GBPCAD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `GBPCHF.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `GBPJPY.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `GBPNZD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `GBPUSD.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `GDAXI.DWX` - canonical DWX DAX symbol matching the card's DAX preference.
- `NDX.DWX` - matrix-covered Nasdaq 100 index CFD with tick-volume history.
- `NZDCAD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `NZDCHF.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `NZDJPY.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `NZDUSD.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `SP500.DWX` - matrix-covered S&P 500 custom symbol; backtest-only per DWX discipline.
- `UK100.DWX` - matrix-covered FTSE 100 index CFD with tick-volume history.
- `USDCAD.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `USDCHF.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `USDJPY.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `WS30.DWX` - matrix-covered Dow 30 index CFD with tick-volume history.
- `XAGUSD.DWX` - matrix-covered metal symbol with OHLC and tick-volume history.
- `XAUUSD.DWX` - card-listed gold symbol with tick-volume history.
- `XNGUSD.DWX` - matrix-covered energy symbol with OHLC and tick-volume history.
- `XTIUSD.DWX` - matrix-covered energy symbol with OHLC and tick-volume history.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - the broker/tester data contract is not available.
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the canonical DAX registration target.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `20` |
| Typical hold time | not specified in card frontmatter; expected to last until the opposite MFI threshold or ATR stop |
| Expected drawdown profile | not specified in card frontmatter; catastrophic stop is 2.0 * ATR(14) |
| Regime preference | mean-reversion / volume-confirmed oscillator threshold |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository
**Pointer:** `https://github.com/cinar/indicator/blob/master/strategy/volume/money_flow_index_strategy.go` and `https://github.com/cinar/indicator/blob/master/volume/mfi.go`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10297_cinar-mfi.md`

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
| v1 | 2026-06-12 | Initial build from card | 97eaa1f1-ea65-49f4-a7f4-12844f09b63b |

