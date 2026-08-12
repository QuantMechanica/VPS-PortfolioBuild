# QM5_11289_tc20-ha-sma14-osma-mom-rsi-h1 — Strategy Spec

**EA ID:** QM5_11289
**Slug:** `tc20-ha-sma14-osma-mom-rsi-h1`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-08

---

## 1. Strategy Logic

On each closed H1 bar, OsMA(12,26,9) crossing zero is the entry trigger. A long
also requires a bullish Heiken-Ashi candle whose close is above SMA(14),
Momentum(10) above 100, and RSI(5) above 50; a short uses the mirrored states.
The other indicators are states rather than fresh crossover events so the
implementation obeys the DWX simultaneous-cross invariant. The initial stop is
ATR(14) × 1.5 per the card's P2 default, the target is twice the stop distance,
and an OsMA zero-cross against the position exits it early.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_sma_period` | 14 | 2–100 | SMA period used by the Heiken-Ashi price-position state |
| `strategy_macd_fast` | 12 | 2–50 | Fast EMA period for MACD/OsMA |
| `strategy_macd_slow` | 26 | 3–100 | Slow EMA period for MACD/OsMA; must exceed the fast period |
| `strategy_macd_signal` | 9 | 2–50 | Signal EMA period for MACD/OsMA |
| `strategy_momentum_period` | 10 | 2–100 | Momentum period; 100 is the directional midpoint |
| `strategy_rsi_period` | 5 | 2–100 | RSI period; 50 is the directional midpoint |
| `strategy_ha_warmup_bars` | 50 | 2–200 | Bounded closed-bar window used to seed Heiken-Ashi recursion |
| `strategy_atr_period` | 14 | 2–100 | ATR period for the P2 stop default |
| `strategy_atr_sl_mult` | 1.5 | 0.1–10.0 | ATR multiple used for stop distance |
| `strategy_tp_rr` | 2.0 | 0.1–10.0 | Take-profit distance as a multiple of initial risk |
| `strategy_spread_cap_pips` | 20 | 1–200 | Blocks only a genuinely positive spread wider than this cap |

> Note: framework-level inputs are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — card-listed liquid FX-major H1 market.
- `GBPUSD.DWX` — card-listed liquid FX-major H1 market.
- `USDJPY.DWX` — card-listed P2 portable FX-major H1 market.

**Explicitly NOT for:**

- Non-FX `.DWX` symbols — the approved card names only these three FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | `not specified in the approved card` |
| Expected drawdown profile | `not specified in the approved card` |
| Regime preference | `trend-following` |
| Win rate target (qualitative) | `not specified in the approved card` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, *20 Forex Trading Strategies (1 Hour Time Frame)*,
Strategy #4; local PDF
`C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\376863900-20-Forex-Trading-Strategies-Collection.pdf`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per
`artifacts/cards_approved/QM5_11289_tc20-ha-sma14-osma-mom-rsi-h1.md`

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
| v1 | 2026-08-08 | Initial build from card | 0376b8ae-3952-4b94-ad8e-f32020c18340 |
