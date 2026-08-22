# QM5_1409_wyckoff-sign-of-strength-phase-d-h4 - Strategy Spec

**EA ID:** QM5_1409  
**Slug:** `wyckoff-sign-of-strength-phase-d-h4`  
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1409_wyckoff-sign-of-strength-phase-d-h4.md`)  
**Author of this spec:** Gemini  
**Last revised:** 2026-08-22  

---

## 1. Strategy Logic

The EA detects canonical Wyckoff accumulation Phase-D bullish continuation setups on closed H4 bars using a three-phase structural detector: **trading-range → SOS-bar → LPS-pullback → entry**.

### Phase A: Trading Range Gate
- Bounded multi-week consolidation window $N_{TR} \in [60, 240]$ H4 bars.
- Trimmed quantile bounds: drop highest 5% and lowest 5% wicks; $high\_band$ = top 20% percentile, $low\_band$ = bottom 20% percentile.
- Range containment: $\ge 90\%$ of bar closes inside $[low\_band, high\_band]$.
- Range amplitude: $4.0 \le (high\_band - low\_band) / ATR(14, H4) \le 14.0$.
- Prior-trend gate: Linear regression slope over 60 bars preceding the range must be negative: $slope_{pre} / ATR(14, H4) \le -0.10$ per bar.
- Range stability: Internal linear regression slope $|slope_{in}| / ATR(14, H4) \le 0.05$ per bar.
- Spring confirmation: Requires a prior Phase-C spring within the trading range (close $\le low\_band - 0.5 \cdot ATR$ followed by recovery back inside the range within 4 bars).

### Phase B: Sign of Strength (SOS) Bar Gate
- Occurs at the right edge of the range ($t_{SOS}$):
  - Range breakout: $close[t_{SOS}] > high\_band + 0.4 \cdot ATR(14, H4)$.
  - Bullish body magnitude: $(close - open) / ATR \ge 1.0$ and $(close - low) / (high - low) \ge 0.70$ (close in upper third).
  - Volume surge: $tick\_volume \ge 1.50 \cdot mean(tick\_volume, 20\text{ bars})$.
  - Spread expansion: $(high - low) / ATR \ge 1.4$.

### Phase C: Last Point of Support (LPS) Pullback Gate
- Detected at bar $t_{LPS} \in [t_{SOS}+3, t_{SOS}+10]$:
  - Pullback depth: $low[t_{LPS}] \ge high\_band - 0.2 \cdot ATR$ and $low[t_{LPS}] \le high\_band + 1.0 \cdot ATR$.
  - Pullback shallowness: $(close_{SOS} - low_{LPS}) / (close_{SOS} - high\_band) \le 1.20$.
  - Resistance-turned-support integrity: No close between $t_{SOS}+1$ and $t_{LPS}-1$ below $high\_band - 0.4 \cdot ATR$.
  - Reversal bar at LPS: $close > open$ and $(close - low) / (high - low) \ge 0.60$.

### Entry Trigger & Exits
- **Entry**: Buy at market upon completed close of $t_{LPS}$ bar.
- **Stop Loss (SL)**: $\min(low[t_{LPS-2..t_{LPS}}]) - 0.4 \cdot ATR(14, H4)$, capped at $3.0 \cdot ATR(14, H4)$.
- **Take Profit (TP)**: Measured move projection: $entry + 1.2 \cdot (high\_band - low\_band)$.
- **Partial TP (TP1)**: Half-position (50%) exit at 60% of measured move, moving stop loss to Break-Even.
- **Pattern Failure Exit**: Hard close if any closed H4 bar closes below $high\_band - 0.5 \cdot ATR$.
- **Time Stop**: 60 H4 bars maximum position duration.
- **Macro Bias Filter**: $close > SMA(200, D1) - 2.0 \cdot ATR(14, D1)$.
- **Pattern Reuse Guard**: 80 H4 bars cooldown.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tf` | `PERIOD_H4` | H4 | Execution and pattern detection timeframe |
| `strategy_atr_period` | 14 | 2-100 | ATR period for volatility normalization |
| `strategy_fractal_wing_bars` | 2 | 1-5 | Williams-fractal wing bars |
| `strategy_tr_min_bars` | 60 | 30-120 | Minimum trading range length in H4 bars |
| `strategy_tr_max_bars` | 240 | 120-400 | Maximum trading range length in H4 bars |
| `strategy_tr_step_bars` | 10 | 5-20 | Scanning step for trading range search |
| `strategy_tr_containment_pct` | 0.90 | 0.70-0.99 | Minimum fraction of closes inside quantile bounds |
| `strategy_tr_min_amplitude_atr` | 4.0 | 2.0-8.0 | Minimum trading range height in ATR units |
| `strategy_tr_max_amplitude_atr` | 14.0 | 8.0-25.0 | Maximum trading range height in ATR units |
| `strategy_prior_trend_bars` | 60 | 30-120 | Lookback bars before trading range for prior markdown slope |
| `strategy_prior_trend_slope_atr` | -0.10 | -0.50..0.0 | Maximum allowable prior downtrend slope in ATR/bar |
| `strategy_tr_stability_slope_atr` | 0.05 | 0.01-0.20 | Maximum internal range trend slope in ATR/bar |
| `strategy_spring_lookback_bars` | 4 | 1-10 | Maximum bars allowed for recovery after spring penetration |
| `strategy_spring_atr_buffer` | 0.50 | 0.10-1.50 | Penetration depth below low band for spring condition |
| `strategy_sos_breakout_atr` | 0.40 | 0.10-1.50 | Minimum clearance above high band for SOS breakout bar |
| `strategy_sos_body_atr` | 1.00 | 0.50-3.0 | Minimum body size of SOS breakout bar in ATR |
| `strategy_sos_close_upper_third` | 0.70 | 0.50-0.90 | Minimum close position within bar range for SOS |
| `strategy_volume_filter_enabled` | true | true/false | Enable volume expansion check |
| `strategy_sos_volume_mean_bars` | 20 | 5-50 | Volume baseline lookback |
| `strategy_sos_volume_mult` | 1.50 | 1.0-3.0 | Volume multiplier requirement on SOS bar |
| `strategy_sos_spread_atr` | 1.40 | 0.8-3.0 | Minimum total bar range of SOS bar in ATR |
| `strategy_lps_min_bars` | 3 | 1-6 | Minimum bars between SOS and LPS |
| `strategy_lps_max_bars` | 10 | 5-20 | Maximum bars between SOS and LPS |
| `strategy_lps_low_band_min_atr` | -0.20 | -1.0..0.5 | Lower bound of LPS low vs high band |
| `strategy_lps_low_band_max_atr` | 1.00 | 0.2-2.5 | Upper bound of LPS low vs high band |
| `strategy_lps_shallowness_ratio` | 1.20 | 0.5-2.0 | Maximum pullback depth ratio relative to SOS breakout |
| `strategy_lps_no_close_back_atr` | 0.40 | 0.1-1.5 | Buffer below high band forbidden during pullback |
| `strategy_lps_reversal_ratio` | 0.60 | 0.4-0.9 | Reversal bar close-in-range fraction at LPS |
| `strategy_tp_measured_move_mult` | 1.20 | 0.8-2.0 | Multiplier for full measured move TP |
| `strategy_tp1_measured_move_pct` | 0.60 | 0.3-0.8 | Measured move percentage trigger for partial TP1 |
| `strategy_tp1_close_fraction` | 0.50 | 0.1-0.9 | Partial position exit fraction |
| `strategy_failure_exit_atr` | 0.50 | 0.1-2.0 | Buffer below high band triggering pattern failure exit |
| `strategy_time_stop_bars` | 60 | 20-120 | Maximum holding time in H4 bars |
| `strategy_sl_atr_buffer` | 0.40 | 0.1-1.5 | Buffer below structural LPS low for initial SL |
| `strategy_sl_cap_atr` | 3.00 | 1.5-6.0 | Maximum initial SL distance in ATR units |
| `strategy_macro_bias_enabled` | true | true/false | Enable daily macro SMA bias check |
| `strategy_macro_sma_period` | 200 | 50-300 | Daily macro SMA lookback period |
| `strategy_macro_atr_buffer` | 2.00 | 0.5-5.0 | Allowable buffer below daily SMA |
| `strategy_reuse_guard_bars` | 80 | 20-200 | Cooldown bars after trade entry before new setup |
| `strategy_spread_filter_enabled` | true | true/false | Enable maximum spread filter |
| `strategy_spread_max_atr` | 0.25 | 0.05-1.0 | Maximum allowable spread in ATR units |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`
- `GBPUSD.DWX`
- `USDJPY.DWX`
- `AUDUSD.DWX`
- `USDCAD.DWX`
- `USDCHF.DWX`
- `NZDUSD.DWX`
- `NDX.DWX`
- `WS30.DWX`
- `GDAXI.DWX`
- `UK100.DWX`
- `SP500.DWX`
- `XAUUSD.DWX`
- `XTIUSD.DWX`

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Macro filter timeframe | `D1` |
| Bar gating | `QM_IsNewBar()` on H4 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `5-15` (High selectivity due to 13 Wyckoff gates) |
| Typical hold time | `3-10 days` (up to 60 H4 bars time stop) |
| Expected drawdown profile | Well within 5% daily / 10% total DD constraints |
| Regime preference | Prolonged accumulation basing resolving into decisive markup |
