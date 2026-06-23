# QM5_11227_ft-rsmooth - Strategy Spec

**EA ID:** QM5_11227
**Slug:** ft-rsmooth
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades long-only M1 pullback reversals. It requires MFI below 22, FastD below 30, ADX above 32, a FastK cross above FastD, and price above a resampled M5 SMA50 before entering at the next bar. It exits on the source overbought signal: prior bar open above EMA5(high), FastD above 79, FastK above 70, and CCI20 above 183. The stop is ATR(14) times 1.0, capped so it is not worse than 10% below entry, and the take profit is a 2% price target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_resample_tf | PERIOD_M5 | M1-H1 practical | Higher timeframe used for the SMA trend gate |
| strategy_resample_sma_period | 50 | 10-200 | SMA period on the resampled timeframe |
| strategy_stoch_k_period | 5 | 3-20 | Fast Stochastic K period |
| strategy_stoch_d_period | 3 | 2-10 | Fast Stochastic D period |
| strategy_stoch_slowing | 3 | 1-10 | Fast Stochastic slowing |
| strategy_mfi_period | 14 | 5-50 | MFI period using tick volume |
| strategy_buy_mfi | 22.0 | 18-25 | Entry requires MFI below this threshold |
| strategy_buy_fastd | 30.0 | 20-40 | Entry requires FastD below this threshold |
| strategy_adx_period | 14 | 5-50 | ADX period |
| strategy_buy_adx | 32.0 | 25-40 | Entry requires ADX above this threshold |
| strategy_ema_exit_period | 5 | 2-20 | EMA(high) exit gate period |
| strategy_cci_period | 20 | 10-50 | CCI exit period |
| strategy_sell_fastd | 79.0 | 70-90 | Exit requires FastD above this threshold |
| strategy_sell_fastk | 70.0 | 65-80 | Exit requires FastK above this threshold |
| strategy_sell_cci | 183.0 | 150-200 | Exit requires CCI above this threshold |
| strategy_atr_period | 14 | 5-50 | ATR stop period |
| strategy_sl_atr_mult | 1.0 | 0.5-3.0 | ATR stop multiplier |
| strategy_roi_target_pct | 2.0 | 0.5-5.0 | Source ROI target as percent above entry |
| strategy_disaster_stop_pct | 10.0 | 3.0-10.0 | Maximum source disaster loss cap |
| strategy_spread_pct_of_stop | 4.0 | 1.0-10.0 | Maximum spread as a percent of planned stop distance |
| strategy_warmup_bars | 260 | 260-1000 | Minimum M1 bars before trading |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major FX pair from the card's primary P2 basket.
- GBPUSD.DWX - Major FX pair from the card's primary P2 basket.
- USDJPY.DWX - Major FX pair from the card's primary P2 basket.
- XAUUSD.DWX - Liquid metal symbol from the card's primary P2 basket.

**Explicitly NOT for:**
- Index-only baskets - The card's R3 portability statement is FX/metals, not equity indices.
- Symbols outside dwx_symbol_matrix.csv - The build registers only symbols verified in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | M5 SMA50 trend gate |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 220 |
| Typical hold time | Intraday scalp, minutes to hours |
| Expected drawdown profile | High risk scalp profile with many small signals and fixed per-trade risk |
| Regime preference | Scalp-reversal inside a reinforced trend filter |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** ReinforcedSmoothScalp.py in freqtrade-strategies, commit dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4
**R1-R4 verdict (Q00):** all PASS per artifacts/cards_approved/QM5_11227_ft-rsmooth.md

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
| v1 | 2026-06-23 | Initial build from card | 26ea19af-d5a1-4acd-9071-8cb14274cdf0 |
