# QM5_12548_turtle-s1-pyramid-d1 — Strategy Spec

**EA ID:** QM5_12548
**Slug:** `turtle-s1-pyramid-d1`
**Source:** `faith-way-of-turtle-2007-appendix-a` (see `strategy-seeds/sources/faith-way-of-turtle-2007-appendix-a/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades the original Turtle System 1 as documented in Curtis Faith (2007), Way of the Turtle, Appendix A. On the close of each D1 bar, if that bar's high exceeds the highest high of the prior 20 D1 bars, a long market order fires at the open of the next bar; the mirror rule applies for shorts with the prior 20-bar lowest low. A skip rule suppresses the signal if the last completed trade was profitable. Once in a position, the EA adds a new unit (up to four total) each time price advances another half-N (half Wilder ATR) from the previous fill, and raises all existing unit stops to 2N below the newest fill price. The position is closed in full when any bar's low (long) or high (short) touches or breaches the 10-bar channel exit level; a 2N hard stop on each unit is set at the broker.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_period` | 20 | 10–50 | Donchian channel lookback for breakout entry (System 1 = 20) |
| `strategy_exit_period` | 10 | 5–20 | Donchian channel lookback for exit trigger (System 1 = 10) |
| `strategy_n_stop_mult` | 2.0 | 1.0–3.0 | ATR multiple for initial stop and stop convergence on pyramid adds |
| `strategy_n_pyramid_mult` | 0.5 | 0.25–1.0 | ATR multiple between pyramid add trigger levels |
| `strategy_max_units` | 4 | 1–4 | Maximum pyramid units per instrument instance |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — original Turtle FX market (British pound); liquid D1 FX trend candidate
- `USDJPY.DWX` — original Turtle FX market (Japanese yen); deep liquidity, strong trend tendencies
- `USDCHF.DWX` — original Turtle FX market (Swiss franc); historically included in Turtle portfolio
- `USDCAD.DWX` — original Turtle FX market (Canadian dollar); commodity-linked FX, trend-prone
- `XAUUSD.DWX` — gold; original Turtle commodity; strong trending behaviour at D1
- `XTIUSD.DWX` — WTI crude oil; original Turtle energy commodity; high-volatility trend instrument

**Explicitly NOT for:**
- Intraday timeframes (M1–H4) — the N-sizing and channel periods are calibrated for D1 bars
- SP500.DWX, NDX.DWX, WS30.DWX — indices excluded from this card's defined universe

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~5 |
| Typical hold time | 2–8 weeks (D1 trend following) |
| Expected drawdown profile | 25% historical; pyramiding amplifies both gains and losses |
| Regime preference | trend |
| Win rate target (qualitative) | low (Turtle systems typically 35–45% win rate with high R:R) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `faith-way-of-turtle-2007-appendix-a`
**Source type:** book
**Pointer:** Faith, C.M. (2007), "Way of the Turtle", McGraw-Hill, ISBN 0-07-148664-X, Appendix A pp. 251-295
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12548_turtle-s1-pyramid-d1.md`

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
| v1 | 2026-06-13 | Initial build from card | 9919ec02-143d-451e-901a-b20f67e005ef |
