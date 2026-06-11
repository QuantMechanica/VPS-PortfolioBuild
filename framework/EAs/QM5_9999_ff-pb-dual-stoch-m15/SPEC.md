# QM5_9999_ff-pb-dual-stoch-m15 - Strategy Spec

**EA ID:** QM5_9999
**Slug:** ff-pb-dual-stoch-m15
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the ForexFactory PB dual stochastic pullback system on completed M15 bars. A long entry is opened at the first tick of the new bar when the green stochastic K(72,1,1) is above the red stochastic K(285,1,246), the green line is above 24, and the two previous closed candles are bearish. A short entry is opened when the green line is below the red line, the green line is below 76, and the two previous closed candles are bullish.

Long positions close when the green stochastic is below the red stochastic and the two previous closed candles are bullish. Short positions close when the green stochastic is above the red stochastic and the two previous closed candles are bearish. A 96-bar M15 safety time stop also closes any position that does not receive an opposite signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | M15 expected | Signal timeframe from the card. |
| `strategy_green_k` | 72 | 1+ | Fast/green stochastic K period. |
| `strategy_green_d` | 1 | 1+ | Green stochastic D period, ignored by the signal. |
| `strategy_green_slowing` | 1 | 1+ | Green stochastic slowing. |
| `strategy_red_k` | 285 | 1+ | Slow/red stochastic K period. |
| `strategy_red_d` | 1 | 1+ | Red stochastic D period, ignored by the signal. |
| `strategy_red_slowing` | 246 | 1+ | Red stochastic slowing. |
| `strategy_long_level` | 24.0 | 0-100 | Long gate: green stochastic must be above this level. |
| `strategy_short_level` | 76.0 | 0-100 | Short gate: green stochastic must be below this level. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the protective stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | Protective stop distance in ATR multiples. |
| `strategy_max_atr_period` | 100 | 1+ | ATR period used for the maximum stop-distance filter. |
| `strategy_max_stop_atr_mult` | 3.0 | >0 | Skip entries when the stop distance exceeds this ATR(100) multiple. |
| `strategy_time_stop_bars` | 96 | 0+ | Safety exit after this many M15 bars; 0 disables. |
| `strategy_median_spread_points` | 15 | 0+ | Fixed median-spread proxy in points for the card's 2x spread cap. |
| `strategy_spread_median_mult` | 2.0 | >0 | Spread cap multiplier applied to the median-spread proxy. |
| `strategy_friday_entry_cutoff_hours` | 2 | 0+ | Blocks new entries this many hours before Friday close. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source-optimized pair and primary card target.
- `GBPUSD.DWX` - liquid DWX FX major listed in the card's P2 basket.
- `USDJPY.DWX` - liquid DWX FX major listed in the card's P2 basket.
- `AUDUSD.DWX` - liquid DWX FX major listed in the card's P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 pipeline uses `.DWX` research and backtest symbols.
- Indices, metals, and energy CFDs - the approved card is an FX M15 stochastic pullback strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 240 |
| Typical hold time | M15 pullback trades; capped at 96 M15 bars, approximately 24 hours. |
| Expected drawdown profile | Fixed-risk intraday FX sleeve with ATR protective stops and no preset TP. |
| Regime preference | Pullback-continuation in directional stochastic regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** Radu_C, "PB dual stochastic system", ForexFactory, 2011, https://www.forexfactory.com/thread/297661-pb-dual-stochastic-system
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9999_ff-pb-dual-stoch-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 223a4e18-21f7-4aca-8df5-9e24b0326ac4 |
