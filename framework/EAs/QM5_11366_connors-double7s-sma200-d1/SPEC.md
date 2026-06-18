# QM5_11366_connors-double7s-sma200-d1 — Strategy Spec

**EA ID:** QM5_11366
**Slug:** `connors-double7s-sma200-d1`
**Source:** `52847e5c-960d-528a-a3af-7579d2979d92`
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Larry Connors' "Double 7's" quantified mean-reversion, adapted to .DWX FX on D1.
SMA(200) of the close is the trend STATE: a long is only allowed while the prior
closed bar's close is above the SMA(200), a short only while it is below. The
entry EVENT is a fresh N-day (N=7) close extreme computed from prior CLOSED
closes (gapless-safe — closes only, no range): go long when the last closed
close is the lowest close of the last 7 closed bars (pullback in uptrend); go
short when it is the highest close of the last 7 (rally in downtrend). The
"enter at next bar open" rule is realised by firing on the first tick of the new
D1 bar. Positions exit on the opposite Connors extreme (long exits on a 7-day
high close, short on a 7-day low close), on a trend break (close crossing back
through SMA(200)), on a time stop after 10 closed bars, or at the P2 ATR-based
SL/TP (SL = 1.5× ATR(14), TP = 2.0× ATR(14)).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 200 | 100-200 | Trend-filter SMA period on the close |
| `strategy_extreme_lookback` | 7 | 5-14 | N-day close-extreme lookback (Connors "7") |
| `strategy_atr_period` | 14 | 10-20 | ATR period for P2 SL/TP |
| `strategy_sl_atr_mult` | 1.5 | 1.0-3.0 | Stop distance = mult × ATR |
| `strategy_tp_atr_mult` | 2.0 | 1.0-4.0 | Target distance = mult × ATR |
| `strategy_max_hold_bars` | 10 | 5-20 | Time stop: exit after N closed bars |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Block entry if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean D1 mean-reversion behaviour against a 200-day trend.
- `GBPUSD.DWX` — liquid major; comparable D1 pullback/rally dynamics.
- `USDJPY.DWX` — liquid major; pip-factor handled by framework stop helpers.
- `AUDUSD.DWX` — liquid commodity-major; trends and mean-reverts on D1.

**Explicitly NOT for:**
- Index / commodity .DWX symbols at build time — card P1 basket is the four FX majors; P2/P3 may expand to the full DWX basket per the card's Implementation Notes (handled as a later parameter-sweep, not this build).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~20` |
| Typical hold time | `a few days (≤10 D1 bars)` |
| Expected drawdown profile | `moderate; mean-reversion buys/sells extremes, slower reversion in FX than equities` |
| Regime preference | `mean-revert within a 200-day trend` |
| Win rate target (qualitative) | `medium-high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `52847e5c-960d-528a-a3af-7579d2979d92`
**Source type:** `book`
**Pointer:** Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That Work" (2009), "Double 7's Strategy" (Dropbox Forex PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11366_connors-double7s-sma200-d1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
