# QM5_10300_cinar-vwap - Strategy Spec

**EA ID:** QM5_10300
**Slug:** `cinar-vwap`
**Source:** `1b906e79-c619-5a61-90db-ee19ac95a19f` (see `artifacts/cards_approved/QM5_10300_cinar-vwap.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA computes a 14-period VWAP from closed D1 close prices and MT5 tick-volume. It opens long when VWAP is above the latest closed close and opens short when VWAP is below the latest closed close. If the opposite position is already open, the EA closes it and opens the new direction on the same closed-bar evaluation. A catastrophic stop is placed at 2.0 * ATR(14), with no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for VWAP and ATR signal reads. |
| `strategy_vwap_period` | `14` | `2+` | Number of closed bars used in the VWAP calculation. |
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
- `NDX.DWX` - card-listed Nasdaq 100 index CFD with OHLC and tick-volume history.
- `NZDCAD.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `NZDCHF.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `NZDJPY.DWX` - matrix-covered FX cross with OHLC and tick-volume history.
- `NZDUSD.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `SP500.DWX` - matrix-covered S&P 500 custom symbol; backtest-only per DWX discipline.
- `UK100.DWX` - matrix-covered FTSE 100 index CFD with OHLC and tick-volume history.
- `USDCAD.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `USDCHF.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `USDJPY.DWX` - matrix-covered major FX pair with OHLC and tick-volume history.
- `WS30.DWX` - card-listed Dow 30 index CFD with OHLC and tick-volume history.
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
| Trades / year / symbol | `45` |
| Typical hold time | not specified in card frontmatter; expected to last until the opposite VWAP/close relation or ATR stop |
| Expected drawdown profile | not specified in card frontmatter; catastrophic stop is 2.0 * ATR(14) |
| Regime preference | mean-reversion to a volume-weighted average price |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository
**Pointer:** `https://github.com/cinar/indicator/blob/master/strategy/volume/weighted_average_price_strategy.go` and `https://github.com/cinar/indicator/blob/master/volume/vwap.go`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10300_cinar-vwap.md`

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
| v1 | 2026-06-12 | Initial build from card | f323729a-acf2-4f4a-ad71-747b4b94f159 |
