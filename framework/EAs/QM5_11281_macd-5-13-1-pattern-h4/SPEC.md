# QM5_11281_macd-5-13-1-pattern-h4 — Strategy Spec

**EA ID:** QM5_11281
**Slug:** `macd-5-13-1-pattern-h4`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a custom MACD(5,13,1) on H4. Because the signal period is 1, the
MACD main line is an unsmoothed EMA(5)-EMA(13) price-unit difference — a fast
oscillator that swings both positive and negative (no zero-floor). Two single-
event signal families fire on the close of an H4 bar:

- Type A/D (fade from extreme): when MACD pushes beyond an extreme level
  (+/-0.0045 on EURUSD) and then closes back inside it, fade the move — SELL on
  the cross back down through +threshold, BUY on the cross back up through
  -threshold. These trades carry an ATR(14)x2.0 take-profit and ATR(14)x1.5 stop.
- Type B/C (zero-cross continuation): when price is above SMA(200) and MACD
  crosses up through zero, BUY; when price is below SMA(200) and MACD crosses
  down through zero, SELL. These ride with an ATR(14) trailing stop and exit on
  the opposite zero-cross.

Only one position per magic. Break-even is moved at +1R. The extreme threshold
is expressed in points and scaled by the symbol's own point so it ports
correctly across 5-digit and 3-digit (JPY) FX majors with no external data.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 5 | 3-12 | MACD fast EMA period |
| `strategy_macd_slow` | 13 | 13-26 | MACD slow EMA period |
| `strategy_macd_signal` | 1 | 1-9 | MACD signal period (1 = unsmoothed main) |
| `strategy_extreme_points` | 450 | 300-600 | A/D extreme level in points vs EURUSD 5-digit point (0.0045 price) |
| `strategy_trend_sma` | 200 | 100-365 | Trend filter SMA for B/C zero-cross |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stops/takes |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.5 | Initial stop = ATR x this |
| `strategy_atr_tp_mult` | 2.0 | 1.0-3.0 | A/D take-profit = ATR x this |
| `strategy_bc_trail_atr_mult` | 1.0 | 0.5-2.0 | B/C trailing-stop ATR mult (0 = off) |
| `strategy_be_trigger_pips` | 0 | 0-200 | BE trigger; 0 = derive from initial R |
| `strategy_enable_fade` | true | bool | Enable Type A/D |
| `strategy_enable_zerocross` | true | bool | Enable Type B/C |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary; extreme threshold (0.0045) is calibrated here.
- `GBPUSD.DWX` — liquid USD major, comparable H4 volatility, point-scaled threshold.
- `USDJPY.DWX` — 3-digit JPY major; point-scaling lifts the threshold to JPY scale.
- `AUDUSD.DWX` — liquid commodity USD major, completes the FX-major basket.

**Explicitly NOT for:**
- Index / metal / energy `.DWX` symbols — the 0.0045 extreme level and SMA(200)
  trend filter are FX-H4 calibrated; index MACD scales differ entirely.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~60` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate; fade legs capped by ATR TP, continuation legs trailed` |
| Regime preference | `mean-revert (A/D fades) + trend continuation (B/C zero-cross)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book` (PDF: "4 Hour MACD Forex Strategy")
**Pointer:** `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11281_macd-5-13-1-pattern-h4.md`

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
