# QM5_10373_et-15ors-scalp - Strategy Spec

**EA ID:** QM5_10373
**Slug:** `et-15ors-scalp`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA records the high and low of M1 bars from 09:30 through 09:44 broker time to define the 15-minute opening range. After 09:45, it enters long when a closed M1 bar closes at least one tick above the range high, or short when a closed M1 bar closes at least one tick below the range low. The stop and target are symmetric at 0.15 ATR(14), the stop moves to breakeven plus one tick after 0.6R favorable movement, and any surviving position is closed after 60 seconds. A second same-day trade is allowed only in the opposite direction and only before the re-entry cutoff.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_start_hhmm` | 930 | 0-2359 | Broker-time start of the opening-range window. |
| `strategy_range_end_hhmm` | 945 | 0-2359 | Broker-time end of the opening-range window and earliest breakout time. |
| `strategy_entry_cutoff_hhmm` | 1600 | 0-2359 | Latest broker time for new opening-range breakout entries. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for target and stop calibration. |
| `strategy_target_atr_mult` | 0.15 | 0.10-0.25 | Symmetric stop and target distance as an ATR fraction. |
| `strategy_entry_offset_ticks` | 1.0 | 1-2 or ATR offset variant | Offset outside the opening range before a breakout qualifies. |
| `strategy_spread_max_frac` | 0.15 | 0.05-0.25 | Maximum spread as a fraction of target distance. |
| `strategy_be_trigger_r` | 0.60 | 0.0-0.8 | Favorable movement in R before moving stop. |
| `strategy_be_buffer_ticks` | 1.0 | 0-2 | Stop buffer beyond entry after the breakeven trigger. |
| `strategy_time_stop_seconds` | 60 | 60-300 | Maximum hold time before strategy close. |
| `strategy_reentry_cutoff_hhmm` | 1000 | 0-2359 | Latest broker time for one opposite-side re-entry. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index proxy for the source's US index opening range scalp; backtest-only per DWX discipline.
- `NDX.DWX` - Nasdaq 100 index proxy with active DWX coverage and US regular-session index behavior.
- `WS30.DWX` - Dow 30 index proxy with active DWX coverage and US regular-session index behavior.
- `GDAXI.DWX` - DAX index proxy used as the available DWX equivalent for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- Non-index forex or commodity symbols - the card is a regular-session index opening-range scalp.
- `GER40.DWX` - card alias is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DWX DAX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 220 |
| Typical hold time | About one minute |
| Expected drawdown profile | High-frequency scalp with slippage and spread sensitivity. |
| Regime preference | Opening-range breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/15-minute-open-range-scalp.100015/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10373_et-15ors-scalp.md`

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
| v1 | 2026-05-25 | Initial build from card | a3ece5d5-cb09-405e-b25b-dafaf0dffeb8 |
