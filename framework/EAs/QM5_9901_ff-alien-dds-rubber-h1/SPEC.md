# QM5_9901_ff-alien-dds-rubber-h1 — Strategy Spec

**EA ID:** QM5_9901
**Slug:** `ff-alien-dds-rubber-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed H1 bar, the EA checks for an oscillator rubber-band reversal setup using a double-smoothed stochastic (DDS, parameters 8/3/3) and an RSI-based momentum gauge (RSIOMA, period 14). For a long entry, the DDS must have dipped below 20 within the last 5 bars and must now cross above its signal line while still below 45 (preserving the early-turn character rather than a late-momentum chase); concurrently, the RSIOMA must be above 50 or have recently crossed above 50, a confirmation stochastic (21/10/10) must be bullish, and at least one ADX (21 or 42 period) must be rising with neither below 14. Short logic mirrors these conditions. The stop is placed below the signal-bar low minus 0.30×ATR(14), with a 1.8R fixed take-profit target; positions are also closed when the DDS crosses back through its signal line, when the RSIOMA crosses back through 50, or after a 14-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsioma_period` | 14 | 5-50 | RSI/RSIOMA period |
| `strategy_dds_k` | 8 | 3-20 | DDS %K period |
| `strategy_dds_d` | 3 | 1-10 | DDS %D period |
| `strategy_dds_slow` | 3 | 1-10 | DDS slow-smoothing period |
| `strategy_stoch_k` | 21 | 5-50 | Confirmation stochastic %K |
| `strategy_stoch_d` | 10 | 1-20 | Confirmation stochastic %D |
| `strategy_stoch_slow` | 10 | 1-20 | Confirmation stochastic slow |
| `strategy_adx_fast` | 21 | 7-50 | Fast ADX period |
| `strategy_adx_slow` | 42 | 14-100 | Slow ADX period |
| `strategy_atr_period` | 14 | 5-30 | ATR period |
| `strategy_lookback_bars` | 5 | 2-10 | Lookback bars for DDS/RSI setup |
| `strategy_sl_atr_buffer` | 0.30 | 0.1-1.0 | SL buffer below/above bar extreme (ATR fraction) |
| `strategy_sl_min_atr` | 0.50 | 0.1-1.5 | Minimum valid stop distance (ATR multiples) |
| `strategy_sl_max_atr` | 2.00 | 1.0-4.0 | Maximum valid stop distance (ATR multiples) |
| `strategy_tp_r_mult` | 1.80 | 1.0-5.0 | Take-profit R-multiple |
| `strategy_time_stop_bars` | 14 | 4-48 | Time stop in H1 bars |
| `strategy_dds_long_max` | 20.0 | 5-40 | DDS oversold threshold for long setup |
| `strategy_dds_long_cap` | 45.0 | 30-60 | Max DDS at cross for long (rubber-band cap) |
| `strategy_dds_short_min` | 80.0 | 60-95 | DDS overbought threshold for short setup |
| `strategy_dds_short_floor` | 55.0 | 40-70 | Min DDS at cross for short (rubber-band floor) |
| `strategy_adx_min` | 14.0 | 5-25 | Minimum ADX for both periods |
| `strategy_atr_pct_lookback` | 60 | 20-200 | ATR percentile lookback bars |
| `strategy_spread_atr_pct` | 0.15 | 0.05-0.50 | Maximum spread as fraction of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; H1 DDS rubber-band patterns well-documented in the Alien thread
- `GBPUSD.DWX` — liquid major FX pair; similar oscillator characteristics to EURUSD
- `AUDUSD.DWX` — risk-sensitive major with distinct momentum cycles suitable for DDS reversals
- `XAUUSD.DWX` — gold exhibits strong oscillator-mean-reversion behavior at H1; included in card R3 basket

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — card specifies FX/XAU basket only; index tick noise differs

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~35 |
| Typical hold time | 4-14 H1 bars |
| Expected drawdown profile | Moderate; RSI/DDS dual exit limits adverse exposure |
| Regime preference | mean-revert / oscillator reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** forexalien, "Alien's Extraterrestrial Visual Systems", ForexFactory 2013-2026, https://www.forexfactory.com/thread/463573-aliens-extraterrestrial-visual-systems
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9901_ff-alien-dds-rubber-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | e1ec846a-38aa-4019-a32c-0566f0568dd8 |
