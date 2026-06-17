# QM5_11019_the5ers-ema-tunnel — Strategy Spec

**EA ID:** QM5_11019
**Slug:** `the5ers-ema-tunnel`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (The5ers blog interview with Kiel.R)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

A daily-timeframe EMA-"tunnel" swing routine. The "tunnel" is the band between
EMA(144) and EMA(169) on the close. The EA waits for price to PIERCE the tunnel
and close back outside it, in the direction of the larger trend, with a tight
fast-EMA(12) compression filter.

Long: on a closed D1 bar, the EMAs stack bullishly (EMA144 > EMA169 >
alignment-proxy EMA) and the close sits above the tunnel; the bar's low dipped
into/below the tunnel and the bar closed back above both tunnel EMAs (the
pierce event); and EMA(12) is within `max(5 pips, 0.15*ATR)` of the nearest
tunnel EMA (compression). Short is the mirror. The stop is placed beyond the
pierce-bar extreme by `0.5*ATR`. Management closes 50% at +1R and then
ATR-trails the runner; a hard time stop closes any position after 20 closed D1
bars.

Multi-timeframe note: the source requires H1/D1/W1/MN1 alignment. MN1 yields
0 bars in the DWX tester and W1 is sparse, so per the card's R2/R3 PASS
reasoning the slower-TF alignment is proxied by a longer D1 EMA on the base D1
chart, keeping the EA D1-native and deterministically testable.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tunnel_fast_period` | 144 | 100-200 | Tunnel fast EMA period |
| `strategy_tunnel_slow_period` | 169 | 120-240 | Tunnel slow EMA period |
| `strategy_fast_ema_period` | 12 | 8-21 | Compression fast EMA period |
| `strategy_align_proxy_period` | 300 | 200-500 | D1 EMA proxy for slower-TF trend alignment |
| `strategy_atr_period` | 14 | 7-30 | ATR period (compression + stop) |
| `strategy_compress_pips` | 5.0 | 5-12 | Base compression threshold (pips) |
| `strategy_compress_atr_frac` | 0.15 | 0.05-0.30 | Compression also allowed up to frac*ATR |
| `strategy_sl_atr_mult` | 0.5 | 0.3-1.5 | Stop buffer beyond pierce extreme = mult*ATR |
| `strategy_partial_rr` | 1.0 | 0.5-2.0 | Partial-close trigger (R multiples) |
| `strategy_partial_fraction` | 0.5 | 0.25-0.75 | Fraction closed at the partial |
| `strategy_trail_atr_mult` | 0.5 | 0.3-2.0 | ATR-trail buffer for the runner |
| `strategy_max_hold_bars` | 20 | 5-40 | Hard time stop, in closed D1 bars |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for** (all in `dwx_symbol_matrix.csv`, multi-TF EMA/ATR available):
- `EURUSD.DWX` — major liquid trending FX pair; primary symbol
- `GBPUSD.DWX` — major liquid FX pair, clean trend phases
- `USDJPY.DWX` — major FX, strong directional swings
- `AUDUSD.DWX` — commodity-linked major, trends well
- `EURJPY.DWX` — JPY cross, large swing amplitude
- `GBPJPY.DWX` — high-amplitude JPY cross, classic swing instrument

**Explicitly NOT for:**
- Index/commodity `.DWX` symbols — the card scopes this to FX pairs where the
  multi-timeframe EMA-tunnel structure is the documented edge.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | slower-TF alignment proxied via a longer D1 EMA (MN1/W1 untestable in DWX tester) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~20 |
| Typical hold time | days (swing; ≤20 D1 bars) |
| Expected drawdown profile | moderate; tight initial stop, partial de-risks at +1R |
| Regime preference | trend / breakout continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** forum/blog (The5ers trader interview)
**Pointer:** https://the5ers.com/take-the-time-and-effort-to-learn-yourself/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11019_the5ers-ema-tunnel.md`

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
| v1 | 2026-06-17 | Initial build from card | D1-native realization; MTF alignment proxied per card R2/R3 |
