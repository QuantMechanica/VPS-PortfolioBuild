# QM5_12611_tsmom-12m-fx-sign-eurusd - Strategy Spec

**EA ID:** QM5_12611
**Slug:** `tsmom-12m-fx-sign-eurusd`
**Source:** `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements the single-symbol EURUSD version of the Moskowitz, Ooi,
and Pedersen 12-month time-series momentum rule. On the first new D1 bar of
each broker-calendar month, it compares the last completed EURUSD.DWX close
with the close 252 D1 bars earlier. If EURUSD is higher, the EA holds or opens
a long position; if EURUSD is lower, the EA holds or opens a short position.
An opposite monthly signal closes the existing position and opens the new
direction. Each entry receives an ATR(14) x 3.0 hard stop.

The EA uses only Darwinex MT5 price history and broker calendar timing. It
does not use macro files, external APIs, machine learning, grids, martingale
sizing, pyramiding, trailing stops, or partial closes.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1_bars` | 252 | 126-315 | Completed D1 bars used for the 12-month sign signal |
| `strategy_min_d1_bars` | 275 | 252-320 | Minimum D1 history required before the EA can trade |
| `strategy_atr_period` | 14 | 10-30 | ATR period for the hard protective stop |
| `strategy_atr_sl_mult` | 3.0 | 2.0-3.5 | ATR hard-stop distance multiplier |
| `strategy_spread_days` | 20 | 10-30 | Completed D1 bars used for the median-spread guard |
| `strategy_spread_mult` | 3.0 | 2.0-5.0 | Maximum current spread as a multiple of median spread |

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the approved card maps the AQR/JFE time-series momentum
  evidence to the Darwinex EURUSD FX pair, a core live-tradable DWX instrument.

**Explicitly NOT for:**
- Other FX pairs - they are covered by separate cards and require their own
  source mapping, magic rows, and Q02 evidence.
- Indices, metals, and energy symbols - they are handled by separate TSMOM
  or cross-asset sleeves with distinct card assumptions.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()`; entry logic runs only once per completed D1 bar |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 6-10 direction-changing events from 12 monthly checks |
| Typical hold time | one or more calendar months while the 12-month sign persists |
| Expected drawdown profile | medium-high FX trend drawdown, especially around ECB/Fed reversals |
| Regime preference | persistent EURUSD trends driven by relative policy, inflation, and dollar cycles |
| Win rate target (qualitative) | medium-low; trend-following payoff should come from larger winners |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`
**Source type:** paper
**Pointer:** `sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012`
and the approved card `artifacts/cards_approved/QM5_12611_tsmom-12m-fx-sign-eurusd.md`
**R1-R4 verdict (Q00):** all PASS per the approved card.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This build does not touch live manifests,
`T_Live`, AutoTrading, or portfolio admission gates.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial build from approved EURUSD TSMOM card | Farm task b5c4523b-41fb-4d42-8b9c-42afe905dd22 |

