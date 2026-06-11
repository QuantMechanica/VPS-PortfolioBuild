# QM5_9926_ff-riverband-sop-m5 - Strategy Spec

**EA ID:** QM5_9926
**Slug:** ff-riverband-sop-m5
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M5 reversal entries around completed H1/H4 support and resistance levels during the first 180 minutes after the Tokyo, London, and New York session opens. A long signal requires price to be near an HTF support level, sweep below it by at least 0.20 ATR(14), close back above the level in discount, and then close above the prior five completed M5 highs; shorts mirror the same rules at resistance in premium. Stops are placed beyond the sweep extreme plus 0.30 ATR, signals with stops wider than 2.20 ATR are skipped, take profit is the nearest opposite H1/H4 key level or 1.8R, SL moves to breakeven after +1R, and remaining positions close on time stop or opposite signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period for sweep thresholds, stop buffer, and volatility filter. |
| strategy_atr_percentile_lookback | 60 | 20-240 | Closed M5 ATR sample count for the volatility percentile filter. |
| strategy_atr_percentile_min | 20.0 | 0-100 | Minimum ATR percentile; current ATR must be above this percentile. |
| strategy_level_proximity_atr | 0.35 | 0.05-2.0 | Maximum distance from close to HTF key level in ATR units. |
| strategy_sweep_depth_atr | 0.20 | 0.05-2.0 | Required sweep distance beyond the key level in ATR units. |
| strategy_sweep_window_bars | 6 | 1-24 | M5 bars allowed between sweep and close-back/BOS confirmation. |
| strategy_bos_lookback_bars | 5 | 2-20 | Completed M5 bars used for break-of-structure high/low. |
| strategy_sl_buffer_atr | 0.30 | 0.05-2.0 | Extra stop buffer beyond the sweep extreme in ATR units. |
| strategy_max_stop_atr | 2.20 | 0.5-10.0 | Maximum allowed initial stop distance in ATR units. |
| strategy_take_profit_r | 1.80 | 0.5-10.0 | R-multiple cap for take profit when no closer opposite level exists. |
| strategy_time_stop_bars | 36 | 1-288 | Maximum holding time in M5 bars. |
| strategy_session_window_minutes | 180 | 15-360 | Minutes after each configured session open when entries are allowed. |
| strategy_tokyo_open_hour | 0 | 0-23 | Broker-hour for the Tokyo session open. |
| strategy_london_open_hour | 8 | 0-23 | Broker-hour for the London session open. |
| strategy_newyork_open_hour | 13 | 0-23 | Broker-hour for the New York session open. |
| strategy_max_spread_points | 0 | 0-10000 | Optional spread ceiling; 0 disables the extra spread gate. |
| strategy_be_buffer_points | 0 | 0-1000 | Break-even SL buffer in points after price reaches +1R. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 primary FX basket member with native DWX data.
- GBPUSD.DWX - card R3 primary FX basket member with native DWX data.
- USDJPY.DWX - card R3 primary FX basket member with native DWX data.
- XAUUSD.DWX - card R3 primary metals basket member with native DWX data.

**Explicitly NOT for:**
- SP500.DWX - not part of the card R3 basket.
- NDX.DWX - not part of the card R3 basket.
- WS30.DWX - not part of the card R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 prior high/low, H4 prior high/low, H1 5-left/5-right swing highs/lows |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default skeleton entry gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Minutes to 3 hours, capped at 36 M5 bars |
| Expected drawdown profile | Tight ATR-capped sweep reversals with one active position per magic-symbol |
| Regime preference | Session liquidity-sweep reversal around HTF support/resistance |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** ForexFactory thread "Waiting at the Riverband" by Inthebox
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9926_ff-riverband-sop-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | c3f69ce9-6f22-401c-82f5-2bd97756a50e |
