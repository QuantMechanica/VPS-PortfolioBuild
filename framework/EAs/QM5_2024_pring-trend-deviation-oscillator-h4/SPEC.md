# QM5_2024_pring-trend-deviation-oscillator-h4 - Strategy Spec

**EA ID:** QM5_2024
**Slug:** pring-trend-deviation-oscillator-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA measures how far the H4 close is from a 65-period SMA as a percent deviation, then builds a 200-bar mean and standard-deviation envelope around that TDO series. It fades a deep extreme only after the previous closed bar was beyond the extreme envelope and the latest closed bar re-enters the 2 SD band with a close-in-half reversal candle. Shorts exit when TDO reverts back to its mean or fails beyond the upper band by another 0.5 SD; longs use the mirror rule. Initial risk is set outside the reversal bar by 2.5 ATR(20), with ATR trailing after a 1.5 ATR favorable move and a 30 H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_long_ma_period` | 65 | 2+ | SMA period used as the long-term trend in the TDO formula. |
| `strategy_stat_period` | 200 | 2+ | Rolling TDO sample used for mean and standard deviation. |
| `strategy_band_sd_mult` | 2.0 | positive | Standard-deviation multiplier for the inside-band trigger. |
| `strategy_extreme_sd_mult` | 2.5 | positive | Minimum prior-bar extreme magnitude before an entry can arm. |
| `strategy_rearm_sd_mult` | 0.5 | positive | Neutral-zone distance from TDO mean required to re-arm a new cycle. |
| `strategy_min_tdo_sd_pct` | 0.5 | positive | Minimum rolling TDO standard deviation percentage for valid envelopes. |
| `strategy_d1_ema_period` | 50 | 2+ | D1 EMA used to tighten trailing when regime conflicts with the fade. |
| `strategy_atr_period` | 20 | 1+ | ATR period for initial stop and trailing logic. |
| `strategy_initial_stop_atr_mult` | 2.5 | positive | ATR multiple beyond the reversal bar high or low for initial SL. |
| `strategy_trail_atr_mult` | 2.5 | positive | Default ATR trailing multiplier after favorable movement. |
| `strategy_conflict_trail_atr_mult` | 1.5 | positive | Tighter ATR trail when D1 EMA conflicts with the position. |
| `strategy_trail_trigger_atr_mult` | 1.5 | positive | Favorable ATR move required before trailing starts. |
| `strategy_time_stop_bars` | 30 | 1+ | Maximum holding time in H4 bars. |
| `strategy_spread_atr_mult` | 0.30 | positive | Blocks entry only when live spread is wider than this ATR fraction. |
| `strategy_warmup_bars` | 280 | 267+ | Minimum H4 history required for TDO and D1-equivalent warmup. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 price-only Pring example, valid backtest-only custom symbol.
- `NDX.DWX` - US large-cap index basket member with price-only H4 data.
- `WS30.DWX` - Dow index basket member matching Pring DJIA examples.
- `GDAXI.DWX` - DAX index extension for global major-index coverage.
- `UK100.DWX` - FTSE index extension for global major-index coverage.
- `EURUSD.DWX` - liquid FX major; TDO uses only close and SMA arithmetic.
- `GBPUSD.DWX` - liquid FX major; TDO uses only close and SMA arithmetic.
- `USDJPY.DWX` - liquid FX major; TDO uses only close and SMA arithmetic.
- `XAUUSD.DWX` - gold commodity future proxy referenced by the card.
- `XTIUSD.DWX` - crude-oil commodity future proxy referenced by the card.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable or non-canonical S&P 500 symbols; use `SP500.DWX`.
- Non-DWX broker symbols - research and backtest artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(50) for conflict-trail tightening |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 30 H4 bars, approximately 5 trading days |
| Expected drawdown profile | Mean-reversion fade risk controlled by 2.5 ATR initial SL and ATR trailing |
| Regime preference | Mean-reversion at statistically extreme price-vs-trend deviations |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** book, S&C article, and forum-source lineage
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_2024_pring-trend-deviation-oscillator-h4.md`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_2024_pring-trend-deviation-oscillator-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | 91ee1bc3-812b-463b-8cca-23261e2f0f70 |
