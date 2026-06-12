# QM5_10302_narang-price-revert - Strategy Spec

**EA ID:** QM5_10302
**Slug:** narang-price-revert
**Source:** 0f051e46-12b2-51f3-aad5-d6d8bd3e9b35 (see `strategy-seeds/sources/0f051e46-12b2-51f3-aad5-d6d8bd3e9b35/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades H1 mean reversion when the last completed bar closes far from its 48-bar simple moving average. A long signal requires the close to be at least 1.5 ATR(24) below the SMA and to reject the low of the bar; a short signal requires the close to be at least 1.5 ATR(24) above the SMA and to reject the high. Entries are skipped when the 96-bar SMA has moved too far over the prior 24 bars, when ATR is below its 20th percentile proxy over the prior 500 H1 bars, on the first H1 bar after the weekend open, or within two H1 bars of available high-impact news. Positions close when a completed H1 bar reaches the 48-bar SMA, after 24 H1 bars, or when the close moves 2.5 ATR beyond the SMA against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_mean_lookback` | 48 | 24-96 | SMA lookback used for deviation and mean-reversion exit. |
| `strategy_atr_period` | 24 | 14-48 | ATR lookback used for deviation, stop distance, and volatility filter. |
| `strategy_deviation_threshold` | 1.5 | 1.25-2.00 | Required absolute close-to-SMA deviation in ATR units. |
| `strategy_long_reject_frac` | 0.35 | 0.0-1.0 | Long rejection-bar threshold measured from low to close. |
| `strategy_short_reject_frac` | 0.65 | 0.0-1.0 | Short rejection-bar threshold measured from low to close. |
| `strategy_slope_lookback` | 96 | 48-144 | SMA lookback for the trend-neutralization slope filter. |
| `strategy_slope_bars` | 24 | 12-48 | Number of H1 bars over which SMA slope is measured. |
| `strategy_slope_atr_mult` | 0.75 | 0.50-1.00 | Maximum absolute SMA movement over the slope window, in ATR units. |
| `strategy_stop_atr_mult` | 1.25 | 1.0-1.75 | Initial stop-loss distance in ATR units. |
| `strategy_time_stop_bars` | 24 | 1-72 | Maximum holding time in H1 bars. |
| `strategy_emergency_atr_mult` | 2.5 | 1.0-4.0 | Emergency close threshold beyond the SMA against the position. |
| `strategy_atr_percentile_lookback` | 500 | 100-1000 | Number of prior H1 ATR samples used for the low-volatility gate. |
| `strategy_atr_percentile_rank` | 20.0 | 0-100 | Percentile rank below which entries are skipped. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap; zero leaves the card without an added spread filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX FX symbol with H1 OHLC, SMA, and ATR support.
- `GBPUSD.DWX` - card-listed DWX FX symbol with H1 OHLC, SMA, and ATR support.
- `USDJPY.DWX` - card-listed DWX FX symbol with H1 OHLC, SMA, and ATR support.
- `XAUUSD.DWX` - card-listed DWX metal symbol with H1 OHLC, SMA, and ATR support.
- `GDAXI.DWX` - DWX matrix DAX custom symbol used as the available port for card-listed `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-listed name is not present in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Up to 24 H1 bars |
| Expected drawdown profile | Left-tail risk during persistent trends or volatility expansions; controlled by slope filter, emergency exit, and fixed ATR stop. |
| Regime preference | Mean-reversion after H1 price deviation from the moving mean |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0f051e46-12b2-51f3-aad5-d6d8bd3e9b35
**Source type:** book
**Pointer:** Rishi K. Narang, Inside the Black Box, 3rd ed.; Wiley URL and O'Reilly chapter preview cited in the approved card.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10302_narang-price-revert.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | e0a7809e-6da0-44b7-ac4e-217c3d8a3e4f |
