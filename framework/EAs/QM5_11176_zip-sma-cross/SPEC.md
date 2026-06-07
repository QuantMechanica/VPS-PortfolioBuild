# QM5_11176_zip-sma-cross - Strategy Spec

**EA ID:** QM5_11176
**Slug:** `zip-sma-cross`
**Source:** `260fe030-5ad9-5466-91f8-61ef5e23f334` (see `strategy-seeds/sources/260fe030-5ad9-5466-91f8-61ef5e23f334/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades a long/flat D1 trend-following rule from the Zipline dual moving average example. On each completed D1 bar it computes SMA(close, 100) and SMA(close, 300); if the fast SMA is above the slow SMA and no position is open, it enters long on the next bar. It exits to flat when the fast SMA falls below the slow SMA, or when the emergency 180-D1-bar time stop is reached. The safety stop is 3.0 * ATR(20, D1) from the entry price, with no take-profit, trailing, break-even, partial close, pyramiding, or short side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 100 | 50-150 | Fast SMA period from the card parameter grid. |
| `strategy_slow_sma_period` | 300 | 200-300 | Slow SMA period from the card parameter grid; must be greater than the fast SMA period. |
| `strategy_atr_period` | 20 | 20 | D1 ATR period used for the V5 safety stop. |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR multiple for the safety stop distance. |
| `strategy_time_stop_bars` | 180 | 120-260 | Maximum D1 bars to hold before emergency close. |
| `strategy_slope_lookback` | 0 | 0, 10, 20 | Optional P3 long-SMA positive-slope filter; 0 keeps the P2 baseline off. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card primary S&P 500 proxy; available as backtest-only custom symbol.
- `NDX.DWX` - card US large-cap index basket member.
- `WS30.DWX` - card US large-cap index basket member.
- `GDAXI.DWX` - canonical available DWX DAX proxy for card-stated `GER40.DWX`.
- `EURUSD.DWX` - card FX basket member with canonical DWX suffix.
- `GBPUSD.DWX` - card FX basket member with canonical DWX suffix.
- `XAUUSD.DWX` - canonical available DWX gold symbol for card-stated bare `XAUUSD`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - not a canonical backtest symbol name; use `XAUUSD.DWX`.

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
| Trades / year / symbol | `4` |
| Typical hold time | `days to 180 D1 bars, depending on the SMA exit` |
| Expected drawdown profile | `slow long-only trend-following drawdowns after trend reversals` |
| Regime preference | `trend-following` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `260fe030-5ad9-5466-91f8-61ef5e23f334`
**Source type:** archived GitHub repository
**Pointer:** `https://github.com/quantopian/zipline/blob/master/zipline/examples/dual_moving_average.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11176_zip-sma-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | 2e4af3aa-b9ed-43ea-8f90-1a687134a5c6 |
