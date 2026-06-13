# QM5_10632_et-vsa-thrust-ndns - Strategy Spec

**EA ID:** QM5_10632
**Slug:** et-vsa-thrust-ndns
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades confirmed Wyckoff/VSA bars on H1 using MT5 tick volume. A completed signal bar is classified as a down-thrust, selling climax, no-supply, up-thrust, buying climax, or no-demand bar from fixed range, wick, close-location, trend, and tick-volume rules. The next completed bar must confirm by closing beyond the signal-bar high for longs or below the signal-bar low for shorts. Exits use 1.8R take profit, a structure-plus-ATR stop, opposite confirmed VSA signal, or a 48-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 1+ | ATR period for range filters and stop buffer. |
| strategy_sma_period | 100 | 1+ | SMA trend filter period for no-supply/no-demand continuation setups. |
| strategy_volume_lookback | 100 | 10+ | Closed bars used for the high-volume percentile test. |
| strategy_volume_percentile | 90.0 | 0-100 | Required signal-bar tick-volume percentile for thrust/climax patterns. |
| strategy_reversal_wick_ratio | 0.50 | 0-1 | Minimum thrust/climax wick share of full bar range. |
| strategy_close_zone_ratio | 0.40 | 0-1 | Close-location zone for top/bottom thrust and climax closes. |
| strategy_dt_max_atr_mult | 1.40 | 0+ | Maximum ATR multiple for down-thrust/up-thrust range qualification. |
| strategy_sc_min_atr_mult | 1.20 | 0+ | Minimum ATR multiple for selling/buying climax range qualification. |
| strategy_no_supply_range_atr_mult | 0.60 | 0+ | Maximum ATR multiple for no-supply/no-demand range. |
| strategy_no_supply_wick_ratio | 0.25 | 0-1 | Minimum opposing wick share for no-supply/no-demand bars. |
| strategy_small_body_max | 0.25 | 0-1 | Maximum body share that qualifies as a small-body candle. |
| strategy_stop_atr_buffer | 0.20 | 0+ | ATR buffer beyond the signal low/high for stop placement. |
| strategy_target_rr | 1.80 | 0+ | Fixed reward-to-risk target. |
| strategy_max_spread_atr_frac | 0.15 | 0+ | Maximum live spread as a fraction of ATR(14,H1). |
| strategy_time_exit_bars | 48 | 1+ | Maximum holding period in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX pair with MT5 tick volume suitable for VSA proxy tests.
- GBPUSD.DWX - liquid FX pair with MT5 tick volume suitable for VSA proxy tests.
- XAUUSD.DWX - liquid metal CFD with high participation and usable tick volume.
- SP500.DWX - S&P 500 custom symbol, valid for backtest-only VSA testing.
- GDAXI.DWX - matrix-valid DAX custom symbol used as the DWX replacement for card-stated GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable S&P variants; use SP500.DWX.

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
| Trades / year / symbol | 24 |
| Typical hold time | Up to 48 H1 bars by time exit; many exits should occur earlier via 1.8R TP, SL, or opposite VSA confirmation. |
| Expected drawdown profile | Event-like reversal and continuation losses bounded by one fixed-risk stop per symbol/magic. |
| Regime preference | Reversal and continuation regimes with enough volatility for confirmed VSA bars. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/wyckoff-volume-spread-analysis-from-theory-to-practical-application.381148/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10632_et-vsa-thrust-ndns.md`

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
| v1 | 2026-06-13 | Initial build from card | 2e390894-6d32-40ab-b251-e34a0b549d3f |
