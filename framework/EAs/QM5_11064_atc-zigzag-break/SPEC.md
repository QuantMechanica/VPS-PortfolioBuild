# QM5_11064_atc-zigzag-break — Strategy Spec

**EA ID:** QM5_11064
**Slug:** `atc-zigzag-break`
**Source:** `de2146db-4632-5883-8994-7f300669caa8` (see `strategy-seeds/sources/de2146db-4632-5883-8994-7f300669caa8/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

On the close of each M15 bar the EA reconstructs a non-repainting ZigZag from
confirmed fractal swings (a bar is a swing high/low only when it is the strict
extreme over a window whose right wing is already fully closed, so pivots never
repaint). It reads the most recent confirmed swing high and swing low and places
a BUY STOP just above the high (`+ entry_buffer_atr * ATR`) and a SELL STOP just
below the low (`- entry_buffer_atr * ATR`). When one side fills, the opposite
pending order is cancelled (one position per symbol/magic). Each filled trade
carries a fixed TP of `tp_atr_mult * ATR(14)` (baseline 1.0 — small reliable
profit) and a larger fixed SL of `sl_atr_mult * ATR(14)` (baseline 3.0 —
matching the source's large-stop profile). A position that hits neither is closed
by a time stop after `time_stop_bars` M15 bars (baseline 32). New pendings are
suppressed by a flat-market filter (confirmed swing range must be ≥
`min_range_atr * ATR`) and an ADX trend filter (`ADX(14) ≥ adx_min`, baseline 18).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_zz_depth` | 12 | 8-24 | ZigZag depth — half-window for a confirmed swing |
| `strategy_zz_deviation` | 5 | 5-20 | ZigZag deviation (points) — min move vs prior pivot |
| `strategy_zz_backstep` | 3 | 3-8 | ZigZag backstep — min bar spacing between pivots |
| `strategy_entry_buffer_atr` | 0.10 | 0.05-0.20 | Stop-entry buffer beyond the swing, in ATR |
| `strategy_min_range_atr` | 1.5 | 1.0-2.0 | Flat-market filter — require swing range ≥ this × ATR (0 disables) |
| `strategy_atr_period` | 14 | 7-28 | ATR period (filter / stop / target) |
| `strategy_sl_atr_mult` | 3.0 | 2.0-4.0 | Stop distance = mult × ATR (large stop) |
| `strategy_tp_atr_mult` | 1.0 | 0.8-1.5 | Target distance = mult × ATR (small reliable profit) |
| `strategy_adx_period` | 14 | 7-28 | ADX period for the trend filter |
| `strategy_adx_min` | 18.0 | 0-24 | Skip new pendings if ADX < this (0 disables) |
| `strategy_time_stop_bars` | 32 | 0-96 | Close after this many M15 bars in trade (0 disables) |
| `strategy_pending_expiry_h` | 24 | 0-72 | Pending-order GTC expiry, in hours (0 = GTC) |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip new pendings if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; clean ZigZag swing structure on M15.
- `GBPUSD.DWX` — high-volatility major; rewards breakout-beyond-swing entries.
- `USDJPY.DWX` — trending major; ADX filter suits its directional regimes.
- `EURJPY.DWX` — volatile cross; wide swings fit the large-stop/small-TP profile.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card's source and frequency estimate are
  FX M15 ZigZag breakout; index gap/session dynamics are out of scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~100 (card range 60-160)` |
| Typical hold time | `minutes to a few hours (≤ 32 M15 bars = 8h cap)` |
| Expected drawdown profile | `rare large losses (3× ATR stop), many small wins/scratches` |
| Regime preference | `breakout / trend-continuation` |
| Win rate target (qualitative) | `medium-high (small TP), offset by large stop` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `de2146db-4632-5883-8994-7f300669caa8`
**Source type:** `forum` (MQL5 Articles interview)
**Pointer:** `https://www.mql5.com/en/articles/546` (Tim Fass, ATC 2011)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11064_atc-zigzag-break.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
