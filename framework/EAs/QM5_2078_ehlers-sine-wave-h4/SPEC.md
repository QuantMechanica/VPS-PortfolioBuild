# QM5_2078_ehlers-sine-wave-h4 - Strategy Spec

**EA ID:** QM5_2078
**Slug:** `ehlers-sine-wave-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA reconstructs Ehlers' Hilbert phase on closed H4 bars, transforms the phase into `Sine = sin(Phase)`, and compares it to the fixed 45-degree lead line `Lead = sin(Phase + pi/4)`. A long entry fires when Sine crosses above Lead in confirmed cycle mode, the dominant period is 10-40 bars, the Sine value is positive, and the latest H4 close is above the D1 EMA(50). A short entry mirrors that rule below the D1 EMA(50). Exits occur on the opposite Sine/Lead cross, trend-mode dissipation for 3 closed H4 bars, the ATR high/low trail, or the natural cycle time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_warmup_h4_bars` | 200 | 100-500 | H4 history used to settle the Hilbert phase reconstruction. |
| `strategy_atr_period` | 20 | 5-100 | ATR period for spread filter, initial stop, and trailing stop. |
| `strategy_spread_atr_mult` | 0.30 | 0.05-2.00 | Blocks only genuinely wide spreads above this ATR fraction. |
| `strategy_d1_ema_period` | 50 | 10-200 | D1 EMA regime filter period. |
| `strategy_cycle_min_dphase_deg` | 6.0 | 1.0-30.0 | Minimum absolute phase rotation for cycle mode. |
| `strategy_cycle_max_dphase_deg` | 60.0 | 20.0-120.0 | Maximum absolute phase rotation for cycle mode. |
| `strategy_trade_min_period` | 10 | 6-30 | Minimum dominant period accepted for entries. |
| `strategy_trade_max_period` | 40 | 20-50 | Maximum dominant period accepted for entries. |
| `strategy_sine_lead_sep_min` | 0.05 | 0.00-0.50 | Minimum Sine/Lead separation after a cross. |
| `strategy_cycle_stability_bars` | 2 | 1-8 | Closed H4 bars that must already be in cycle mode. |
| `strategy_trend_exit_bars` | 3 | 1-8 | Consecutive non-cycle H4 bars that trigger trend-mode exit. |
| `strategy_initial_stop_atr` | 0.50 | 0.10-3.00 | Initial stop offset from the entry bar high/low in ATR units. |
| `strategy_trail_trigger_atr` | 1.50 | 0.50-5.00 | Favorable move required before the ATR trail can move the stop. |
| `strategy_trail_atr_mult` | 2.50 | 0.50-8.00 | ATR multiple for the highest-high/lowest-low trailing stop. |
| `strategy_time_stop_period_mult` | 1.20 | 0.50-3.00 | Time-stop multiple of the dominant period captured at entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Ehlers 2004 cites FX-major applicability and the card targets EURUSD.
- `GBPUSD.DWX` - FX-major member explicitly listed in the card.
- `USDJPY.DWX` - FX-major member explicitly listed in the card.
- `XAUUSD.DWX` - Gold is part of the card's commodity futures portability set.
- `XTIUSD.DWX` - Oil is part of the card's commodity futures portability set.
- `NDX.DWX` - US large-cap index proxy available in the DWX matrix.
- `WS30.DWX` - US large-cap index proxy available in the DWX matrix.
- `GDAXI.DWX` - DAX index member listed in the card's index basket.
- `UK100.DWX` - FTSE index member listed in the card's index basket.
- `SP500.DWX` - S&P 500 is called out in R3 as mechanically testable, backtest-only.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtests must use canonical `.DWX` symbols from `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `PERIOD_D1` EMA(50) regime filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | `about 1.2 dominant-cycle periods on H4, usually hours to days` |
| Expected drawdown profile | `Cycle-mode mean-reversion with ATR-defined initial and trailing risk.` |
| Regime preference | `cycle / mean-reversion; suppresses trend-mode entries` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum plus Ehlers book references`
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_2078_ehlers-sine-wave-h4.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_2078_ehlers-sine-wave-h4.md`

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
| v1 | 2026-06-26 | Initial build from card | d86f2983-8fa0-4273-904b-f3c32791ea2e |
