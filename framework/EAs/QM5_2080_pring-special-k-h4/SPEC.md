# QM5_2080_pring-special-k-h4 — Strategy Spec

**EA ID:** QM5_2080
**Slug:** `pring-special-k-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades Martin Pring's Special-K major-cycle extremes on H4 bars. It computes 12 fixed ROC series, smooths each with its fixed SMA length, and sums the fixed Pring coefficients into one Special-K oscillator. A long entry fires when the just-closed H4 bar is both the 100-bar Special-K low and the 100-bar price low, Special-K turns up, the bar closes bullish, component signs align, and the last major extreme is at least 60 bars back. Shorts mirror the same rule at 100-bar highs; exits use the opposite extreme, a Special-K zero-line reversal, a 3.0 ATR trailing stop after a 2.0 ATR favorable move, or a 200 H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tf` | `PERIOD_H4` | H4 expected | Base signal timeframe. |
| `strategy_major_window` | `100` | `10+` | Rolling Special-K and price extreme window. |
| `strategy_separation_bars` | `60` | `1+` | Minimum H4 bars between major-cycle extreme signals. |
| `strategy_atr_period` | `20` | `1+` | ATR period for initial stop, spread cap, and trailing stop. |
| `strategy_initial_stop_atr_mult` | `1.0` | `>0` | Initial stop offset from signal-bar low/high. |
| `strategy_trail_atr_mult` | `3.0` | `>0` | ATR trailing-stop multiplier. |
| `strategy_trail_trigger_atr_mult` | `2.0` | `>0` | Favorable move required before ATR trailing starts. |
| `strategy_time_stop_bars` | `200` | `1+` | Maximum holding period in H4 bars. |
| `strategy_spread_atr_mult` | `0.30` | `>=0` | Blocks genuinely wide spread above this ATR fraction. |
| `strategy_min_sk_range` | `50.0` | `>=0` | Minimum 100-bar Special-K high-low range. |
| `strategy_d1_regime_filter_enabled` | `false` | `true/false` | Optional D1 SMA trend filter, disabled by card default. |
| `strategy_d1_sma_period` | `100` | `1+` | D1 SMA period when optional regime filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — FX major explicitly listed in R3 as price-only portable.
- `GBPUSD.DWX` — FX major explicitly listed in R3 as price-only portable.
- `USDJPY.DWX` — FX major explicitly listed in R3 as price-only portable.
- `XAUUSD.DWX` — gold spot exposure cited by Pring examples and listed as testable.
- `SP500.DWX` — S&P 500 example is mechanically testable on the approved custom symbol, backtest-only.
- `NDX.DWX` — US large-cap index proxy in the portable DWX basket.
- `WS30.DWX` — DJIA exposure from the Pring examples and portable DWX basket.
- `GDAXI.DWX` — DAX index included in the card's global index basket.
- `UK100.DWX` — FTSE index included in the card's global index basket.

**Explicitly NOT for:**
- `XTIUSD.DWX` — excluded by the card due to crude-oil COVID ROC singularity risk.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | Optional `PERIOD_D1` SMA(100) regime filter, disabled by default |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Up to 200 H4 bars, roughly 5.5 weeks |
| Expected drawdown profile | Wide-cycle reversal trades with ATR stops; drawdown can cluster near cycle lows/highs |
| Regime preference | Major-cycle reversal after multi-timescale momentum extremes |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum / whitepaper / book`
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_2080_pring-special-k-h4.md`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_2080_pring-special-k-h4.md`

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
| v1 | 2026-06-26 | Initial build from card | 1f8e20d5-5615-4a5f-a027-c60145078116 |
