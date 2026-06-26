# QM5_9262_mql5-vidya-dual — Strategy Spec

**EA ID:** QM5_9262
**Slug:** `mql5-vidya-dual`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

On each closed H1 bar, the EA computes two Variable Index Dynamic Averages (VIDYA): a fast line (CMO period 9, EMA period 12) and a slow line (CMO period 20, EMA period 50). VIDYA smooths price using a Chande Momentum Oscillator-based adaptive coefficient, giving it faster response during trending periods and slower response during ranging ones. A long position is opened when the fast VIDYA crosses above the slow VIDYA; a short position is opened when the fast VIDYA crosses below the slow VIDYA. The initial stop is set at 2.2 × ATR(14) from entry and the take profit is placed at 2.4R. Positions are also closed when the fast VIDYA crosses back through the slow VIDYA in the opposite direction, or after a failsafe 96-bar hold limit. A 3-bar cooldown after any exit prevents immediate re-entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_cmo_period` | 9 | 3–20 | CMO lookback period for the fast VIDYA |
| `strategy_fast_ema_period` | 12 | 5–30 | EMA smoothing period for the fast VIDYA alpha |
| `strategy_slow_cmo_period` | 20 | 10–50 | CMO lookback period for the slow VIDYA |
| `strategy_slow_ema_period` | 50 | 20–200 | EMA smoothing period for the slow VIDYA alpha |
| `strategy_atr_period` | 14 | 7–28 | ATR period for stop-loss sizing |
| `strategy_atr_sl_mult` | 2.2 | 1.0–5.0 | ATR multiplier for stop-loss distance |
| `strategy_rr_tp` | 2.4 | 1.0–5.0 | Risk:reward ratio for take-profit placement |
| `strategy_max_hold_bars` | 96 | 24–240 | Failsafe maximum bars in trade (H1 bars) |
| `strategy_cooldown_bars` | 3 | 1–10 | Bars to skip after any exit before new entry |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Major liquid forex pair; stable VIDYA trending behaviour with low noise
- `GBPJPY.DWX` — Highly volatile forex cross; strong trending moves suit VIDYA adaptive smoothing
- `XAUUSD.DWX` — Gold; displays strong trend regimes where adaptive MA crossover excels

**Explicitly NOT for:**
- Index CFDs (NDX, WS30) — not in card's R3 basket; may be added via future rework after symbol expansion analysis

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~60 |
| Typical hold time | Hours to days (H1 bars; failsafe at 96 bars = 4 days) |
| Expected drawdown profile | Trend-following; moderate drawdown in ranging markets |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by VIDYA", MQL5 Articles, 2022-08-31, https://www.mql5.com/en/articles/11341
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9262_mql5-vidya-dual.md`

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
| v1 | 2026-06-26 | Initial build from card | cc643f82-6c1c-476a-8ec3-a4856e037272 |
