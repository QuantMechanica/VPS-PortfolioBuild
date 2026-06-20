# QM5_11440_janus-100pips-daily-range-layered - Strategy Spec

**EA ID:** QM5_11440
**Slug:** janus-100pips-daily-range-layered
**Source:** 0cb650ba-c81d-5a5a-b4d6-6d083fb6b092 (see `strategy-seeds/sources/0cb650ba-c81d-5a5a-b4d6-6d083fb6b092/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

At the daily session reset, the EA measures the prior 24 closed H1 bars. It places one buy-stop order 7 pips above that range high and one sell-stop order 7 pips below that range low. Both orders use a fixed 25-pip stop loss and a fixed 35-pip take profit. When one side opens a position, the opposite pending stop order is cancelled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_bars_h1` | 24 | 1+ | Number of closed H1 bars used to measure the daily range. |
| `strategy_reset_hour_broker` | 1 | 0-23 | Broker-time hour used for the 18:00 New York session reset. |
| `strategy_offset_pips` | 7 | 1+ | Distance beyond the range high/low for stop-entry placement. |
| `strategy_tp_pips` | 35 | 1+ | Fixed take-profit distance for the P2 single-order version. |
| `strategy_sl_pips` | 25 | 1+ | Fixed stop-loss distance for each order. |
| `strategy_max_spread_pips` | 15 | 1+ | Maximum modeled spread allowed before blocking new work. Zero spread is allowed. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - Primary pair named by the source strategy.
- `EURUSD.DWX` - Liquid FX major listed in the card's R3 portable basket.
- `GBPUSD.DWX` - Liquid FX major listed in the card's R3 portable basket.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The card specifies a pip-based FX range breakout and only passes R3 for FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Intraday to one daily session; unfilled orders expire at the next reset. |
| Expected drawdown profile | Fixed-risk breakout losses clustered during false range breaks. |
| Regime preference | Volatility-expansion breakout after the daily reset. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0cb650ba-c81d-5a5a-b4d6-6d083fb6b092
**Source type:** online/self-published trading system
**Pointer:** `artifacts/cards_approved/QM5_11440_janus-100pips-daily-range-layered.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11440_janus-100pips-daily-range-layered.md`

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
| v1 | 2026-06-20 | Initial build from card | eb0e31a5-5668-4c0e-962b-1381e27a3bed |
