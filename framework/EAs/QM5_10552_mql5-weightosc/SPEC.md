# QM5_10552_mql5-weightosc - Strategy Spec

**EA ID:** QM5_10552
**Slug:** `mql5-weightosc`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes a WeightOscillator on closed H6 bars by combining RSI, MFI, Williams %R, and DeMarker components into one 0-100 oscillator. It opens a long position when the oscillator crosses upward through the oversold level, and it opens a short position when the oscillator crosses downward through the overbought level. A long is closed on the opposite overbought-down cross, and a short is closed on the opposite oversold-up cross. Every entry also carries the P2 baseline ATR(14) 2.0 hard stop and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H6` | H4-H12 sweep target | Timeframe used for oscillator and ATR reads. |
| `strategy_osc_period` | `14` | 2-100 | Lookback period for RSI, MFI, WPR, and DeMarker components. |
| `strategy_oversold_level` | `30.0` | 0-50 | Long trigger level crossed upward by the oscillator. |
| `strategy_overbought_level` | `70.0` | 50-100 | Short trigger level crossed downward by the oscillator. |
| `strategy_rsi_weight` | `1.0` | 0-10 | Weight of the RSI component in the oscillator blend. |
| `strategy_mfi_weight` | `1.0` | 0-10 | Weight of the MFI component in the oscillator blend. |
| `strategy_wpr_weight` | `1.0` | 0-10 | Weight of the Williams %R component after normalization to 0-100. |
| `strategy_dem_weight` | `1.0` | 0-10 | Weight of the DeMarker component in the oscillator blend. |
| `strategy_atr_period` | `14` | 2-100 | ATR period used for hard stop sizing. |
| `strategy_atr_sl_mult` | `2.0` | 0.1-10 | Stop distance in ATR multiples. |
| `strategy_reward_r_multiple` | `1.5` | 0.1-10 | Profit target multiple of the stop distance. |
| `strategy_adx_filter_enabled` | `false` | true/false | Optional card-authorized trend-strength filter switch. |
| `strategy_adx_period` | `14` | 2-100 | ADX period when the optional filter is enabled. |
| `strategy_adx_min` | `18.0` | 0-100 | Minimum ADX allowed when the optional filter is enabled. |
| `strategy_max_spread_points` | `0` | 0-10000 | Optional spread ceiling in points; 0 disables the filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` - Card primary source test was EURJPY H6, and the symbol is present in the DWX matrix.
- `EURUSD.DWX` - Liquid FX major from the card's R3 portable basket.
- `GBPUSD.DWX` - Liquid FX major from the card's R3 portable basket.
- `XAUUSD.DWX` - Liquid metal CFD from the card's R3 portable basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build registry only admits verified `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H6` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | hours to several days |
| Expected drawdown profile | Medium mean-reversion drawdown profile from repeated oscillator reversals. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/17076`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10552_mql5-weightosc.md`

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
| v1 | 2026-05-29 | Initial build from card | 97a03257-867b-4220-b814-b95185510289 |
