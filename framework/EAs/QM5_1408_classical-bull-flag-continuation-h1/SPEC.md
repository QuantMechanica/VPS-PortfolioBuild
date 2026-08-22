# QM5_1408_classical-bull-flag-continuation-h1 - Strategy Spec

**EA ID:** QM5_1408  
**Slug:** `classical-bull-flag-continuation-h1`  
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1408_classical-bull-flag-continuation-h1.md`)  
**Author of this spec:** Gemini  
**Last revised:** 2026-08-22  

---

## 1. Strategy Logic

The EA detects classical Edwards-Magee bull flag continuation patterns on closed H1 bars using a three-phase structure: **flagpole → flag-channel → breakout**.

### Phase 1: Flagpole Gate
- Detects a recent sharp bullish impulse leg $N_{pole} \in [12, 36]$ H1 bars:
  - Cumulative move: $close_{end} - close_{start} \ge 4.0 \cdot ATR(14, H1)$.
  - Slope steepness: $slope_{LR}(close, N_{pole}) / ATR(14, H1) \ge +0.20$ per bar.
  - Few-pullback gate: Fraction of bars with $close < close[k-1]$ inside the pole is $\le 35\%$.
  - Volume surge: $mean(tick\_volume, pole) \ge 1.20 \cdot mean(tick\_volume, \text{prior } 60\text{ bars})$.

### Phase 2: Flag Channel Gate
- Consolidation channel following the pole $N_{flag} \in [5, 18]$ H1 bars:
  - Counter-slope: $slope_{LR}(close, flag) / ATR(14, H1) \in [-0.10, -0.005]$ per bar (slopes against the pole impulse).
  - Channel containment: $\ge 80\%$ of bar closes lie within $[upper\_TL(t) - 0.3 ATR, lower\_TL(t) + 0.3 ATR]$ where $upper\_TL$ and $lower\_TL$ are parallel trendlines through swing pivots ($|slope_{upper} - slope_{lower}| \le 0.30 \cdot (|slope_{upper}| + |slope_{lower}|)$).
  - Retracement limit: $(highest\_high_{pole} - lowest\_low_{flag}) / (highest\_high_{pole} - lowest\_low_{pole}) \le 0.50$ (flag retraces at most 50% of flagpole).
  - Volume contraction: $mean(tick\_volume, flag) \le 0.80 \cdot mean(tick\_volume, pole)$.

### Phase 3: Breakout Trigger & Exits
- **Breakout Entry**: Triggered when closed H1 bar closes above $upper\_TL(t) + 0.4 \cdot ATR(14, H1)$.
- **Stop Loss (SL)**: Initial stop placed at $lower\_TL(t_{break}) - 0.3 \cdot ATR(14, H1)$, capped at $2.5 \cdot ATR(14, H1)$.
- **Take Profit (TP)**: Measured move equal to flagpole length projected from entry: $entry + (highest\_high_{pole} - lowest\_low_{pole})$.
- **Partial TP (TP1)**: Half-position (50%) exit at 50% of measured move, moving stop loss to Break-Even.
- **Pattern Failure Exit**: Hard close if H1 close falls back inside the flag channel within the first 6 bars after entry.
- **Time Stop**: 24 H1 bars maximum position duration.
- **Macro Bias Filter**: H4 SMA(200) is rising AND H1 close > H4 SMA(200).
- **Pattern Reuse Guard**: 12 H1 bars cooldown.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tf` | `PERIOD_H1` | H1 | Execution and pattern detection timeframe |
| `strategy_atr_period` | 14 | 2-100 | ATR period for volatility normalization |
| `strategy_fractal_wing_bars` | 1 | 1-3 | Williams-fractal wing bars (3-bar fractal on H1) |
| `strategy_pole_min_bars` | 12 | 6-24 | Minimum flagpole length in H1 bars |
| `strategy_pole_max_bars` | 36 | 20-60 | Maximum flagpole length in H1 bars |
| `strategy_pole_min_atr` | 4.0 | 2.0-8.0 | Minimum cumulative move of flagpole in ATR units |
| `strategy_pole_slope_min_atr` | 0.20 | 0.05-0.60 | Minimum linear regression slope of flagpole in ATR/bar |
| `strategy_pole_max_pullback_pct` | 0.35 | 0.15-0.50 | Maximum allowed fraction of pullback bars within flagpole |
| `strategy_volume_filter_enabled` | true | true/false | Enable volume confirmation checks |
| `strategy_pole_volume_mult` | 1.20 | 1.0-2.5 | Volume surge multiplier for flagpole vs baseline |
| `strategy_pole_volume_prior_bars` | 60 | 20-120 | Baseline volume lookback window |
| `strategy_flag_min_bars` | 5 | 3-10 | Minimum consolidation flag duration in H1 bars |
| `strategy_flag_max_bars` | 18 | 10-30 | Maximum consolidation flag duration in H1 bars |
| `strategy_flag_slope_min_atr` | -0.10 | -0.30..-0.02 | Minimum allowable flag counter-slope in ATR/bar |
| `strategy_flag_slope_max_atr` | -0.005 | -0.02..0.0 | Maximum allowable flag counter-slope in ATR/bar |
| `strategy_flag_containment_pct` | 0.80 | 0.60-0.95 | Fraction of closes required within channel bands |
| `strategy_flag_channel_tol_atr` | 0.30 | 0.10-1.0 | Buffer for channel boundary containment |
| `strategy_flag_max_retrace_pct` | 0.50 | 0.30-0.70 | Maximum allowable retracement of flagpole height |
| `strategy_flag_volume_mult` | 0.80 | 0.40-1.0 | Maximum volume ratio of flag vs flagpole |
| `strategy_breakout_buffer_atr` | 0.40 | 0.10-1.0 | Clearance above upper trendline for breakout close |
| `strategy_tp1_close_fraction` | 0.50 | 0.10-0.90 | Partial exit fraction |
| `strategy_tp1_ratio` | 0.50 | 0.20-0.80 | Measured move percentage trigger for partial TP1 |
| `strategy_failure_exit_bars` | 6 | 2-12 | Window in bars for pattern failure fallback exit |
| `strategy_time_stop_bars` | 24 | 10-60 | Maximum holding duration in H1 bars |
| `strategy_sl_buffer_atr` | 0.30 | 0.10-1.0 | Buffer below lower trendline for initial SL |
| `strategy_sl_cap_atr` | 2.50 | 1.5-5.0 | Maximum initial SL distance in ATR units |
| `strategy_macro_bias_enabled` | true | true/false | Enable H4 macro SMA filter |
| `strategy_macro_sma_period` | 200 | 50-300 | Lookback period for H4 macro SMA |
| `strategy_reuse_guard_bars` | 12 | 4-40 | Cooldown bars after entry before new setup |
| `strategy_spread_filter_enabled` | true | true/false | Enable maximum spread check |
| `strategy_spread_max_atr` | 0.30 | 0.10-1.0 | Maximum allowable spread in ATR units |

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
| Base timeframe | `H1` |
| Macro filter timeframe | `H4` |
| Bar gating | `QM_IsNewBar()` on H1 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `15-40` |
| Typical hold time | `1-2 days` (up to 24 H1 bars time stop) |
| Expected drawdown profile | Well within 5% daily / 10% total DD constraints |
| Regime preference | Fast momentum continuation following steep impulse |
