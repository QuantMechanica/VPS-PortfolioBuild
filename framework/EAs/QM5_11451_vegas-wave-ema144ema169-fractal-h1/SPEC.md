# QM5_11451_vegas-wave-ema144ema169-fractal-h1 - Strategy Spec

**EA ID:** QM5_11451
**Slug:** `vegas-wave-ema144ema169-fractal-h1`
**Source:** `5cb677f3-e06a-590b-a6b5-94a2d4bc9e81` (Vegas Wave System, Vegas Operator, Forex Factory community)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This H1 trend-continuation EA trades the Vegas tunnel, using EMA(144) and EMA(169) as the trend state and a confirmed Williams fractal as the entry event. The tunnel is bullish when the last closed bar closes above EMA169 and EMA144 is above EMA169; it is bearish when the last closed bar closes below EMA144 and EMA144 is below EMA169. The EA also requires a recent pullback toward the relevant EMA boundary within the last five closed H1 bars.

For a long setup, a confirmed upper Williams fractal places a BUY STOP one pip above the fractal level. For a short setup, a confirmed lower Williams fractal places a SELL STOP one pip below the fractal level. Pending orders expire after 24 H1 candles. Stop loss is ATR(14) x 1.5 from entry, capped at 80 pips. The position takes a 50% partial close after price moves ATR(14) x 2.0 in favour, then moves the remaining runner to break-even and keeps the ATR(14) x 3.5 final target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 144 | 89-169 | Vegas tunnel fast EMA, used as the bearish boundary |
| `strategy_ema_slow_period` | 169 | 144-200 | Vegas tunnel slow EMA, used as the bullish boundary |
| `strategy_fractal_side_bars` | 2 | 2-3 | Williams fractal bars on each side |
| `strategy_pullback_lookback` | 5 | 3-10 | Closed bars scanned for a tunnel pullback |
| `strategy_pullback_pips` | 10.0 | 5-25 | Pullback proximity to the EMA boundary, in pips |
| `strategy_atr_period` | 14 | 10-21 | ATR period for SL, TP, and break-even trigger |
| `strategy_sl_atr_mult` | 1.5 | 1.0-2.5 | Stop distance in ATR multiples |
| `strategy_tp_atr_mult` | 3.5 | 2.5-5.0 | Runner take-profit distance in ATR multiples |
| `strategy_be_atr_mult` | 2.0 | 1.5-3.0 | TP1 and break-even trigger distance in ATR multiples |
| `strategy_entry_buffer_pips` | 1.0 | 0.5-3.0 | Stop trigger offset beyond the fractal level |
| `strategy_sl_max_pips` | 80.0 | 40-120 | Maximum stop distance for P2 |
| `strategy_pending_bars` | 24 | 12-48 | Pending order expiry in H1 bars |
| `strategy_session_start_hr` | 7 | 0-23 | GMT session open hour, inclusive |
| `strategy_session_end_hr` | 18 | 0-23 | GMT session close hour, exclusive |
| `strategy_spread_cap_pips` | 20.0 | 5-30 | Maximum positive modeled spread, in pips |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed H1 FX major with deep liquidity.
- `GBPUSD.DWX` - card-listed H1 FX major with clean trend continuation behaviour.
- `USDJPY.DWX` - card-listed H1 FX major; pip scaling handles JPY quote precision.
- `AUDUSD.DWX` - card-listed H1 FX major with sustained directional moves.
- `USDCAD.DWX` - card-listed H1 FX major with commodity-linked directional moves.

**Explicitly NOT for:**
- Index, metal, and energy `.DWX` symbols - the card defines an FX-pair universe and pip-based pullback and stop caps.

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
| Trades / year / symbol | `40` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate; ATR-capped stops, 50% TP1 partial, break-even after TP1 distance` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `5cb677f3-e06a-590b-a6b5-94a2d4bc9e81`
**Source type:** `forum`
**Pointer:** `Vegas Wave System by Vegas Operator (Forex Factory community, pseudonymous); local Vegas Wave PDF`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11451_vegas-wave-ema144ema169-fractal-h1.md`

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
| v1 | 2026-06-26 | Initial build from card | b185a9c9-d4d5-4ad9-8620-2a85b6722eb3 |

> **Implementation note (two-lot handling):** The card specifies a two-lot partial-TP design. The V5 framework opens one position per magic, so this EA opens one position, partially closes 50% at the TP1 distance, and then moves the remaining runner to break-even.

> **Session note:** The card states 07:00-18:00 GMT. The tester clock is broker time, so the EA converts broker time to UTC with `QM_BrokerToUTC` before applying the card session window.
