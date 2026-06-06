# QM5_10924_grimes-mac-spike - Strategy Spec

**EA ID:** QM5_10924
**Slug:** grimes-mac-spike
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates D1 closed bars. It buys when the latest close has a volatility-adjusted return spike of at least +2.0 standard deviations, closes above the highest close of the prior 20 bars, and the prior 10 bars contain at least five closes inside a 1.5 ATR(20) range. It sells on the mirrored downside setup. The stop is placed beyond the consolidation low or high by 0.25 ATR(20), the target is 2R, the stop moves to breakeven after 1R, and the trade exits after 20 D1 bars or on an opposite MAC spike of at least 1.5 standard deviations.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_return_std_period | 20 | 5-60 | Number of prior D1 return samples used for MAC-spike standard deviation. |
| strategy_mac_entry_threshold | 2.0 | 1.0-4.0 | Minimum signed MAC spike for entry. |
| strategy_mac_exit_threshold | 1.5 | 0.5-3.0 | Opposite signed MAC spike needed for early exit. |
| strategy_breakout_lookback | 20 | 5-80 | Prior closed bars used for highest/lowest close breakout. |
| strategy_consolidation_lookback | 10 | 5-40 | Prior closed bars inspected for consolidation. |
| strategy_consolidation_min_closes | 5 | 2-20 | Minimum closes that must fit inside the ATR range. |
| strategy_consolidation_atr_mult | 1.5 | 0.5-4.0 | ATR multiple defining the consolidation close range. |
| strategy_atr_period | 20 | 5-60 | ATR period for consolidation, stop buffer, and stop-distance checks. |
| strategy_stop_atr_buffer | 0.25 | 0.0-2.0 | ATR buffer beyond the consolidation high or low. |
| strategy_max_stop_atr_mult | 4.0 | 1.0-8.0 | Maximum allowed stop distance in ATR units. |
| strategy_ema_period | 20 | 5-80 | EMA used for terminal-overshoot filter. |
| strategy_max_ema_atr_distance | 3.5 | 1.0-8.0 | Maximum close-to-EMA distance in ATR units. |
| strategy_tp_rr | 2.0 | 0.5-5.0 | Reward-to-risk target multiple. |
| strategy_be_trigger_rr | 1.0 | 0.5-3.0 | Reward-to-risk threshold for breakeven stop move. |
| strategy_max_hold_bars | 20 | 1-80 | Maximum D1 bars to hold a trade. |
| strategy_spread_stop_fraction | 0.10 | 0.0-0.5 | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - Card primary S&P 500 index target; valid backtest-only custom symbol.
- NDX.DWX - US large-cap growth index exposure from the card basket.
- GDAXI.DWX - Matrix-verified DAX custom symbol used for the card's GER40.DWX intent.
- XAUUSD.DWX - Liquid metals target from the card basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in dwx_symbol_matrix.csv; GDAXI.DWX is the verified DAX equivalent.
- SPX500.DWX - Not a canonical DWX custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) through the V5 framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Up to 20 D1 bars |
| Expected drawdown profile | Breakout strategy with infrequent volatility-expansion losses capped by structure stop. |
| Regime preference | Volatility-expansion breakout after consolidation |
| Win rate target (qualitative) | Medium |

Expected trade frequency from card: Large volatility-adjusted close plus consolidation breakout; conservative estimate 4-12 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes blog articles cited in the approved card.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10924_grimes-mac-spike.md`

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
| v1 | 2026-06-06 | Initial build from card | f7bb6f65-e022-46ca-9e3e-ac6a92580acd |
