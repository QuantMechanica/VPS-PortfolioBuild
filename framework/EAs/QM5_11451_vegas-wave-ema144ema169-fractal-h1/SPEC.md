# QM5_11451_vegas-wave-ema144ema169-fractal-h1 — Strategy Spec

**EA ID:** QM5_11451
**Slug:** `vegas-wave-ema144ema169-fractal-h1`
**Source:** `5cb677f3-e06a-590b-a6b5-94a2d4bc9e81` (Vegas Wave System, Vegas Operator, Forex Factory community)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

H1 trend-continuation system built on the "Vegas tunnel" — the EMA(144)/EMA(169)
channel — as the trend STATE, with a Williams fractal break as the single entry
EVENT. The tunnel is bullish when the last closed bar closed above EMA169 and
EMA144 is stacked above EMA169; bearish when the last closed bar closed below
EMA144 and EMA144 is stacked below EMA169. The EA only acts after price has
recently pulled back toward the tunnel (a closed bar within the last few bars
came within `strategy_pullback_pips` of the relevant boundary), so it buys
continuation off the channel rather than chasing extension.

The entry event is a freshly-confirmed Williams fractal (centred `side+1` bars
back so its right-hand confirming bars all exist — exactly one event per bar).
Long: an UP fractal confirms in a bullish tunnel → a BUY STOP is placed one pip
above that fractal's high. Short: a DOWN fractal in a bearish tunnel → a SELL
STOP one pip below the fractal's low. The pending order is cancelled after 24 H1
candles if unfilled. Stop loss is ATR(14)×1.5 from the entry (proxy for the
card's "prior fractal" structural stop), capped at 80 pips. Take profit is the
runner target ATR(14)×3.5 (the card's TP Lot2). The card's two-lot split with
"move to break-even after TP1 (ATR×2.0)" is collapsed into the framework's
one-position-per-magic model as a single runner that pulls its SL to break-even
once price has travelled ATR×2.0 in favour. Exits are SL / TP / break-even only.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 144 | 89-169 | Vegas tunnel fast EMA (bearish/EMA144 boundary) |
| `strategy_ema_slow_period` | 169 | 144-200 | Vegas tunnel slow EMA (bullish/EMA169 boundary) |
| `strategy_fractal_side_bars` | 2 | 2-3 | Williams fractal: confirming bars on each side |
| `strategy_pullback_lookback` | 5 | 3-10 | Closed bars scanned for a tunnel pullback |
| `strategy_pullback_pips` | 10.0 | 5-25 | Pullback proximity to the EMA boundary (pips) |
| `strategy_atr_period` | 14 | 10-21 | ATR period for SL / TP / break-even distance |
| `strategy_sl_atr_mult` | 1.5 | 1.0-2.5 | SL distance = mult × ATR (prior-fractal proxy) |
| `strategy_tp_atr_mult` | 3.5 | 2.5-5.0 | Runner TP distance = mult × ATR (card TP Lot2) |
| `strategy_be_atr_mult` | 2.0 | 1.5-3.0 | Move SL to break-even after price moves mult × ATR (card TP1) |
| `strategy_entry_buffer_pips` | 1.0 | 0.5-3.0 | Stop trigger offset beyond the fractal extreme |
| `strategy_sl_max_pips` | 80.0 | 40-120 | P2 cap on the stop distance (card cap) |
| `strategy_pending_bars` | 24 | 12-48 | Cancel pending after N H1 candles (card: 24H) |
| `strategy_session_start_hr` | 9 | 0-23 | Session open, BROKER hour inclusive (~07:00 GMT +2) |
| `strategy_session_end_hr` | 20 | 0-23 | Session close, BROKER hour exclusive (~18:00 GMT +2) |
| `strategy_spread_cap_pips` | 20.0 | 5-30 | Skip only a genuinely wide spread (card cap) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquidity, clean H1 trend structure for tunnel continuation
- `GBPUSD.DWX` — trending major; respects the EMA144/169 channel
- `USDJPY.DWX` — trending major; pip-scaling handled (3-digit pip factor)
- `AUDUSD.DWX` — commodity major with sustained H1 trends
- `USDCAD.DWX` — commodity major; oil-driven directional H1 moves

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card defines a forex-pair universe; EMA144/169
  tunnel periods and the pip-based pullback/SL caps are calibrated for FX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~40` |
| Typical hold time | `hours to a few days (H1 trend continuation)` |
| Expected drawdown profile | `moderate; ATR-capped stops, break-even after TP1 distance` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `5cb677f3-e06a-590b-a6b5-94a2d4bc9e81`
**Source type:** `forum`
**Pointer:** `Vegas Wave System by Vegas Operator (Forex Factory community, pseudonymous); local Vegas Wave PDF`
**R1–R4 verdict (Q00):** all PASS (R1 CONDITIONAL — pseudonymous author) / see `artifacts/cards_approved/QM5_11451_vegas-wave-ema144ema169-fractal-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor worktree |

---

> **Implementation note (2-lot collapse):** The card specifies a two-lot
> partial-TP design (TP1 @ ATR×2.0 take 50%, TP2 @ ATR×3.5 runner, trail Lot2
> to BE after TP1). The V5 framework is one-position-per-magic, so this is
> realised as a single runner targeting ATR×3.5 with its SL pulled to
> break-even once price travels ATR×2.0 in favour (== the TP1 distance). The
> early-50%-profit leg is not modelled; the runner + BE captures the trend-ride
> and downside-protection halves of the original intent.

> **Session note (GMT→broker):** The card states 07:00–18:00 GMT. Per .DWX
> invariant #5, the session window is matched in BROKER time (DXZ = NY-Close
> GMT+2/+3, DST-aware). Defaults are the GMT window shifted +2 (standard time:
> 09:00–20:00 broker); the exact offset is set-file tunable and should track the
> DST state for the test window.
