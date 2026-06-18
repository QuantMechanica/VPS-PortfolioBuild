# QM5_11413_wilder-directional-movement-di14-cross-d1 — Strategy Spec

**EA ID:** QM5_11413
**Slug:** `wilder-directional-movement-di14-cross-d1`
**Source:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b` (see `strategy-seeds/sources/0ab0a479-4a09-5ecc-bb90-6a37148fa78b/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Wilder's Directional Movement System on D1. The single trigger EVENT is the
+DI(14) / -DI(14) crossover on the just-closed daily bar: a long signal when
+DI crosses above -DI, a short signal when -DI crosses above +DI. The crossover
is confirmed by a trend STATE: Wilder's ADXR — `(ADX[1] + ADX[1+14]) / 2` — must
exceed 25, so trades are taken only in directionally strong markets. Confirmation
of the direction uses Wilder's Extreme Point Rule: instead of entering at market
on the cross, a stop order is placed at the crossing day's extreme (BUY_STOP at
the crossing-day high + 1 pip, SELL_STOP at the crossing-day low - 1 pip); price
must trade through the extreme to fill, which filters out false crosses. The
initial stop loss is the opposite extreme of the crossing day (long SL = crossing
day low, short SL = crossing day high), capped at 100 pips. If the DI lines
re-cross in the opposite direction before the pending stop fills, the pending
order is cancelled. The take-profit is ATR(14) × 3 from the entry. An open
position is also closed when the DI lines re-cross against it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 9-20 | Wilder DMI / ADX / DI smoothing period |
| `strategy_adxr_threshold` | 25.0 | 20-30 | ADXR must exceed this for a strong-trend STATE |
| `strategy_extreme_buf_pips` | 1 | 0-5 | Pips beyond the crossing-day extreme for the stop entry |
| `strategy_sl_cap_pips` | 100 | 30-200 | Cap on the extreme-point stop-loss distance (P2) |
| `strategy_atr_period` | 14 | 7-21 | ATR period used for the take-profit |
| `strategy_tp_atr_mult` | 3.0 | 2-4 | Take-profit distance = mult × ATR |
| `strategy_entry_expire_bars` | 5 | 1-10 | Remove an unfilled pending stop after N D1 bars |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Skip if live spread exceeds this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquid major; clean Wilder DMI trends on D1.
- `GBPUSD.DWX` — liquid major with strong directional swings suited to DMI.
- `USDJPY.DWX` — liquid major; trends well; pip scaling handled via pip_factor.
- `AUDUSD.DWX` — commodity major with persistent directional regimes.
- `USDCAD.DWX` — oil-correlated major with sustained trends for DMI capture.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card targets the FX major basket only; DMI
  thresholds and the 100-pip SL cap are FX-tuned.

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
| Trades / year / symbol | `~15` |
| Typical hold time | `days to weeks` |
| Expected drawdown profile | `moderate; trend-following with capped per-trade SL` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low/medium` (trend-following: fewer wins, larger winners) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b`
**Source type:** `book`
**Pointer:** J. Welles Wilder Jr., "New Concepts in Technical Trading Systems" (1978), Section IV: Directional Movement System.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11413_wilder-directional-movement-di14-cross-d1.md`

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
