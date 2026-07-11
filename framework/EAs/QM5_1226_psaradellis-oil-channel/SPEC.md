# QM5_1226_psaradellis-oil-channel — Strategy Spec

**EA ID:** QM5_1226
**Slug:** `psaradellis-oil-channel`
**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Author of this spec:** Codex
**Last revised:** 2026-07-11

## 1. Strategy Logic

On each completed D1 bar, the EA buys when the close exceeds the highest high
of the preceding 55 bars and sells when the close falls below the preceding
55-bar low. A long closes below the preceding 20-bar low and a short closes
above the preceding 20-bar high. Every entry carries a 3.0 × ATR(20) hard stop;
after a trade reaches +2R, an optional 2.5 × ATR(20) trailing stop manages it.

The framework evaluates the bounded channel windows once per new D1 bar. Risk
management and closed-bar exits continue through news windows; news policy
suppresses new entries only.

## 2. Parameters

| Parameter | Default | Allowed range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_D1` | D1 | Signal and management timeframe |
| `strategy_entry_channel` | 55 | Q03: 20, 55, 100 | Prior-bar breakout window |
| `strategy_exit_channel` | 20 | Q03: 10, 20, 55 | Prior-bar exit window |
| `strategy_atr_period` | 20 | > 0 | ATR lookback for stop placement |
| `strategy_atr_sl_mult` | 3.0 | Q03: 2.0, 3.0, 4.0 | Initial hard-stop distance |
| `strategy_use_trailing_stop` | true | true/false | Enables the post-trigger ATR trail |
| `strategy_trail_atr_mult` | 2.5 | > 0 | Trailing-stop ATR multiple |
| `strategy_trail_trigger_r` | 2.0 | > 0 | Profit in initial-risk units before trailing |
| `strategy_min_bars` | 120 | >= 100 | Completed D1 bars required before signals |
| `strategy_max_spread_points` | 0 | >= 0 | Optional spread cap; 0 disables it |

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` (slot 0) — direct DWX WTI crude-oil CFD port of the source market.

**Explicitly not for:**

- `XNGUSD.DWX` — natural gas has a different physical-market and seasonality structure.
- Equity indices, metals, and FX — outside this oil-specific approved card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | one `QM_IsNewBar(XTIUSD.DWX, PERIOD_D1)` edge per D1 bar |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 20 in the farm intake projection; Q02 is authoritative |
| Typical hold time | several days to several weeks |
| Expected drawdown profile | clustered whipsaws in range-bound oil regimes |
| Regime preference | persistent crude-oil trends and volatility expansion |
| Win-rate target | low-to-medium, offset by positively skewed trend wins |

## 6. Source Citation

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** peer-reviewed journal paper / SSRN preprint
**Pointer:** Psaradellis, Laws, Pantelous, and Sermpinis, “Performance of
Technical Trading Rules: Evidence from the Crude Oil Market,” *European
Journal of Finance* (2019), SSRN 2832600.
**R1–R4 verdict (Q00):** approved in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1226_psaradellis-oil-channel.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | `RISK_FIXED` | $1,000 per trade (HR4) |
| Live burn-in | `RISK_PERCENT` | min-lot equivalent under an OWNER-approved manifest |
| Full live | `RISK_PERCENT` | card requests 0.25%; final value remains manifest-gated |

`QM_FrameworkInit` enforces that exactly one risk mode is active. This repair
does not alter any live setfile, deploy manifest, or T_Live state.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-26 | Initial build from approved card | original Q01 artifact |
| v1.1 | 2026-07-11 | Q02 infrastructure recovery | cached D1 channel state; entry-only news gate; complete Q01 SPEC |
