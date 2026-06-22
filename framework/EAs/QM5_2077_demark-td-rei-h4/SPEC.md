# QM5_2077_demark-td-rei-h4 - Strategy Spec

**EA ID:** QM5_2077
**Slug:** demark-td-rei-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `artifacts/cards_approved/QM5_2077_demark-td-rei-h4.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades a DeMark TD Range Expansion Index zone-exit fade on H4 bars. TD-REI is computed over eight qualified range-expansion contribution bars; a long is opened when the oscillator exits the oversold zone after a short stay, the signal bar closes bullish, and the D1 SMA regime gate is bullish. Shorts mirror that logic from the overbought zone with a bearish signal bar and bearish D1 SMA regime. Open trades are closed when TD-REI reaches the opposite zone, crosses the zero line with at least 1.5 ATR of favorable movement, hits the ATR trailing stop, or reaches the 18-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rei_window` | 8 | 1+ | Number of contribution bars in the TD-REI formula. |
| `strategy_zone_level` | 45.0 | >0 | Absolute TD-REI threshold for overbought and oversold zones. |
| `strategy_max_zone_duration` | 5 | 1+ | Maximum consecutive bars allowed inside the extreme zone before rejecting the fade. |
| `strategy_recent_lookback` | 5 | 1+ | Lookback window used to confirm recent extreme-zone residency. |
| `strategy_d1_sma_period` | 100 | 1+ | D1 SMA period for the optional macro-bias gate. |
| `strategy_use_d1_sma_gate` | true | true/false | Enables the D1 SMA regime filter. |
| `strategy_atr_period` | 14 | 1+ | ATR period for stops, trailing, spread cap, and mid-zone target confirmation. |
| `strategy_stop_atr_buffer` | 0.50 | >0 | ATR buffer beyond the recent four-bar structure stop. |
| `strategy_mid_target_atr_mult` | 1.50 | >0 | Favorable movement required before zero-line exit can close the trade. |
| `strategy_trail_atr_mult` | 2.00 | >0 | ATR multiple for the framework trailing stop. |
| `strategy_time_stop_bars` | 18 | 1+ | Maximum holding time in H4 bars. |
| `strategy_spread_atr_mult` | 0.30 | >=0 | Blocks entry only when live modeled spread exceeds this fraction of ATR. |
| `strategy_min_qualified_bars` | 4 | 0-8 | Minimum qualified TD-REI contribution bars on the signal bar. |
| `strategy_min_traversal_bars` | 8 | 0+ | Rejects very fast opposite-zone traversals within this H4-bar window. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major named in the card's portable TD-REI basket.
- `GBPUSD.DWX` - FX major named in the card's portable TD-REI basket.
- `USDJPY.DWX` - FX major named in the card's portable TD-REI basket.
- `XAUUSD.DWX` - gold is named in the card's commodity examples and matrix-valid.
- `XTIUSD.DWX` - crude oil is named in the card's commodity examples and matrix-valid.
- `NDX.DWX` - US large-cap index exposure named in the R3 basket.
- `WS30.DWX` - US large-cap index exposure named in the R3 basket.
- `GDAXI.DWX` - DAX index exposure named in the R3 basket and matrix-valid.
- `UK100.DWX` - FTSE index exposure named in the R3 basket and matrix-valid.
- `SP500.DWX` - S&P 500 exposure named in the R3 discussion; registered as backtest-only per DWX symbol discipline.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester has no canonical `.DWX` tick source for them.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX names; `SP500.DWX` is the available backtest-only S&P 500 symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 SMA(100) regime gate |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 18 H4 bars, about 3 trading days |
| Expected drawdown profile | Mean-reversion exhaustion fades with ATR-defined protective stops. |
| Regime preference | Exhaustion mean-reversion inside the D1 SMA regime direction. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum / book
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_2077_demark-td-rei-h4.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_2077_demark-td-rei-h4.md`

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
| v1 | 2026-06-23 | Initial build from card | 305f11de-4f76-42d0-baee-d6f96dc943be |
