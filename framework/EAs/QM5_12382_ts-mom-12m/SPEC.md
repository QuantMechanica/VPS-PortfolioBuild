# QM5_12382_ts-mom-12m - Strategy Spec

**EA ID:** QM5_12382
**Slug:** `ts-mom-12m`
**Source:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

On the first tradable D1 bar of each calendar month, the EA compares the most recent closed D1 close with the close 252 D1 bars earlier. A positive 12-month return opens or keeps a long position; a negative 12-month return opens or keeps a short position. The signal is ignored when 60-day annualized volatility cannot be computed. Existing positions are reviewed monthly and closed when the sign reverses or the volatility calculation becomes invalid; the fixed-risk emergency stop remains active on every tick, including news windows.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 126-252 | D1 bars used for the 12-month momentum return. |
| `strategy_vol_lookback_d1` | 60 | 40-90 | D1 one-day returns used for realized volatility. |
| `strategy_spread_lookback_d1` | 60 | >=1 | D1 bars used for the median spread entry filter. |
| `strategy_atr_period_d1` | 20 | 10-50 | ATR period used for the emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 2.0-4.0 | ATR multiple for the emergency stop. |
| `strategy_min_warmup_bars` | 260 | >=260 | Minimum D1 history required before signals are valid. |
| `strategy_portfolio_stop_r` | 6.0 | >=0 | Per-symbol Q01 emergency stop threshold in fixed-risk R units. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major from the card's multi-asset time-series momentum universe.
- `GBPUSD.DWX` - FX major from the card's multi-asset time-series momentum universe.
- `USDJPY.DWX` - FX major from the card's multi-asset time-series momentum universe.
- `USDCHF.DWX` - FX major from the card's multi-asset time-series momentum universe.
- `USDCAD.DWX` - FX major from the card's multi-asset time-series momentum universe.
- `XAUUSD.DWX` - Metal CFD from the card's commodity sleeve.
- `XAGUSD.DWX` - Metal CFD from the card's commodity sleeve.
- `XTIUSD.DWX` - Oil CFD from the card's commodity sleeve.
- `SP500.DWX` - S&P 500 custom symbol, valid for backtest per DWX matrix.
- `NDX.DWX` - Nasdaq 100 index CFD from the card's index sleeve.
- `WS30.DWX` - Dow 30 index CFD from the card's index sleeve.
- `GDAXI.DWX` - Canonical DWX DAX symbol used in place of card-stated `GER40.DWX`.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use `.DWX` symbols.
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | about one month or longer while momentum sign persists |
| Expected drawdown profile | Whipsaw losses in trendless or correlated reversal regimes |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623`
**Source type:** public implementation
**Pointer:** `https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/time-series-momentum-effect.py`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12382_ts-mom-12m.md`

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
| v1 | 2026-06-18 | Initial build from card | 325477c2-b3fe-4ae8-b628-725238c2d90f |
| v2 | 2026-07-10 | Q02 infrastructure recovery | Current resolver rebuild; framework calendar cadence; news-safe risk and monthly exits |
