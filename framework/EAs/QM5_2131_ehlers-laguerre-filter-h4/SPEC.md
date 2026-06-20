# QM5_2131_ehlers-laguerre-filter-h4 — Strategy Spec

**EA ID:** QM5_2131
**Slug:** `ehlers-laguerre-filter-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA reconstructs Ehlers' four-stage Laguerre filter on each closed H4 bar using fixed gamma 0.8 by default, then compares the last closed H4 close against the filter output. It buys when price crosses above the filter, the close is at least 0.3 ATR(20) above the filter, the filter is rising, and the H4 close is above the D1 EMA(50). It sells on the mirrored down-cross. Positions close on the opposite price/filter cross, a two-bar filter-direction reversal, an ATR trailing stop after a 1.5 ATR favorable move, or an 80 H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_gamma` | 0.80 | 0.00-0.99 | Fixed Laguerre damping factor. |
| `strategy_use_typical_price` | false | true/false | Use HLC/3 instead of close as the Laguerre input price. |
| `strategy_atr_period` | 20 | 2-100 | ATR period used for entry magnitude, stops, and trailing. |
| `strategy_cross_atr_mult` | 0.30 | 0.00-5.00 | Minimum price/filter separation as ATR multiple. |
| `strategy_d1_ema_period` | 50 | 2-300 | D1 EMA regime filter period. |
| `strategy_warmup_h4_bars` | 200 | 60-1000 | Closed H4 bars reconstructed before using Laguerre values. |
| `strategy_initial_stop_atr` | 0.50 | 0.10-10.00 | ATR buffer beyond the entry bar low/high for the initial stop. |
| `strategy_trail_trigger_atr` | 1.50 | 0.10-10.00 | Favorable move required before trailing starts. |
| `strategy_trail_atr_mult` | 2.50 | 0.10-10.00 | ATR distance from highest high or lowest low since entry. |
| `strategy_time_stop_h4_bars` | 80 | 1-500 | Maximum holding period in H4 bars. |
| `strategy_cross_throttle_bars` | 3 | 0-20 | Skip entries if any cross fired in the previous H4 bars. |
| `strategy_spread_atr_mult` | 0.30 | 0.00-5.00 | Maximum modeled spread as ATR multiple; zero spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major currency future/spot proxy cited in the card.
- `GBPUSD.DWX` — major currency future/spot proxy cited in the card.
- `USDJPY.DWX` — major currency future/spot proxy cited in the card.
- `XAUUSD.DWX` — gold proxy cited in the commodity examples.
- `XTIUSD.DWX` — crude oil proxy cited in the commodity examples.
- `NDX.DWX` — Nasdaq 100 index exposure from the Ehlers index basket.
- `WS30.DWX` — Dow 30 index exposure from the Ehlers index basket.
- `GDAXI.DWX` — DAX 40 global index expansion from the R3 basket.
- `UK100.DWX` — FTSE 100 global index expansion from the R3 basket.
- `SP500.DWX` — S&P 500 custom symbol, valid for backtest-only validation per the card.

**Explicitly NOT for:**
- Non-DWX symbols — research and backtest artifacts must use canonical `.DWX` symbols.

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
| Typical hold time | `up to 80 H4 bars, roughly two weeks maximum` |
| Expected drawdown profile | `trend-following whipsaw risk during sideways regimes` |
| Regime preference | `trend / volatility-expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum / book / MQL5 code reference`
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_2131_ehlers-laguerre-filter-h4.md`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_2131_ehlers-laguerre-filter-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 01bafb9d-5369-476d-a5fe-5fe80958f738 |
