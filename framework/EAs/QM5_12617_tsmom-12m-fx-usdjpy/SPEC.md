# QM5_12617_tsmom-12m-fx-usdjpy - Strategy Spec

**EA ID:** QM5_12617
**Slug:** `tsmom-12m-fx-usdjpy`
**Source:** `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements the single-symbol USDJPY version of the Moskowitz, Ooi,
and Pedersen 12-month time-series momentum rule. On the first new D1 bar of
each broker-calendar month, it compares the last completed USDJPY.DWX close
with the close 252 D1 bars earlier. If USDJPY is higher, the EA holds or opens
a long position; if USDJPY is lower, the EA holds or opens a short position.
An opposite monthly signal closes the existing package and opens the new
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
- `USDJPY.DWX` - the card maps the AQR/JFE JPY futures time-series momentum
  evidence to the Darwinex USDJPY FX pair, where long USDJPY represents USD
  strength / JPY weakness and short USDJPY represents JPY strength.

**Explicitly NOT for:**
- Other FX pairs - they are covered by separate cards and require their own
  source mapping, magic rows, and Q02 evidence.
- Indices, metals, and energy symbols - they do not express the USDJPY
  carry/risk-off dynamics described by the card.

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
| Expected drawdown profile | medium-high FX trend drawdown, especially around BOJ/Fed reversals |
| Regime preference | persistent USDJPY trends driven by carry, policy divergence, or risk-off JPY flows |
| Win rate target (qualitative) | medium-low; trend-following payoff should come from larger winners |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`
**Source type:** paper
**Pointer:** `sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012`
and the approved card `artifacts/cards_approved/QM5_12617_tsmom-12m-fx-usdjpy.md`
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
| v1 | 2026-06-29 | Initial build from approved USDJPY TSMOM card | Farm task a9e19c50-85c0-4d07-bc70-11809fc24c0e |

