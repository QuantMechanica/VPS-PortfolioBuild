# QM5_1051_cc-3ducks-sma60-mtf - Strategy Spec

**EA ID:** QM5_1051
**Slug:** cc-3ducks-sma60-mtf
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades the 3 Ducks Trading System as a three-timeframe SMA(60) alignment rule. A long entry requires Bid above the H4 SMA(60), Bid above the H1 SMA(60), and the most recent closed M5 candle close above the M5 SMA(60). A short entry mirrors those conditions below the three SMA values. The initial stop is placed beyond the H1 SMA(60) with a 20-point buffer, the take-profit is 1.5R from the initial stop distance, and the strategy exit closes when the most recent closed M5 candle flips to the opposite side of the M5 SMA(60).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_sma_period | 60 | 1+ | SMA lookback used on H4, H1, and M5. |
| strategy_sl_buffer_points | 20 | 0+ | Point buffer beyond the H1 SMA for the initial stop. |
| strategy_rr | 1.5 | >0 | Fixed reward-to-risk target multiple from initial stop distance. |
| strategy_spread_cap_points | 20 | 0+ | Maximum allowed spread in points; 0 disables the cap. |
| strategy_london_ny_only | false | true/false | Optional broker-time London/New York overlap gate for P3 sweeps. |
| strategy_use_atr_stop | false | true/false | Optional P3 alternate stop mode using H1 ATR. |
| strategy_atr_period | 14 | 1+ | ATR period used only when ATR stop mode is enabled. |
| strategy_atr_mult | 1.5 | >0 | ATR stop multiplier used only when ATR stop mode is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major named in the approved R3 portable basket.
- GBPUSD.DWX - FX major named in the approved R3 portable basket.
- USDJPY.DWX - FX major named in the approved R3 portable basket.
- AUDUSD.DWX - FX major named in the approved R3 portable basket.
- USDCAD.DWX - FX major named in the approved R3 portable basket.
- EURJPY.DWX - liquid JPY cross named in the approved R3 portable basket.

**Explicitly NOT for:**
- Non-DWX symbols - broker/data availability is restricted to the DWX matrix for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H4 SMA(60), H1 SMA(60), M5 SMA(60) |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Trend-following drawdowns during choppy M5 SMA flips. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/97002-3-ducks-trading-system
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1051_cc-3ducks-sma60-mtf.md`

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
| v1 | 2026-06-13 | Initial build from card | d07fb07a-3077-4b75-aa3b-d0911587fe9c |
