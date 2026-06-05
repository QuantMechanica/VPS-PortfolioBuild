# QM5_10787_tv-ema-rsi-adx — Strategy Spec

**EA ID:** QM5_10787
**Slug:** `tv-ema-rsi-adx`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView script `e7XQPek8`, author `varuns_back`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

A trend-following EMA-crossover system confirmed by momentum and trend strength.
On each closed bar the EA reads a fast EMA (default 9) and a slow EMA (default
21). A long is opened when the fast EMA crosses above the slow EMA, the RSI(14)
of the last closed bar is above 55, and — if the ADX filter is enabled — ADX(14)
is above 20. A short is opened on the mirror conditions: fast EMA crosses below
slow EMA, RSI below 45, and the same ADX gate. Only one position per
symbol/magic is held at a time.

The position is closed when the opposite EMA crossover occurs, or when the stop
loss is hit (ATR(14)×2.0 distance in the P2 baseline, or a fixed-percent stop in
the ablation mode). There is no fixed take-profit. Per the V5 baseline, an
opposite crossover only closes the current position on its bar; a fresh entry in
the new direction can occur no earlier than the next closed bar (no instant
auto-reversal).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 9 | 5-50 | Fast EMA period |
| `strategy_ema_slow` | 21 | 10-200 | Slow EMA period |
| `strategy_rsi_period` | 14 | 5-30 | RSI period |
| `strategy_rsi_long_thresh` | 55.0 | 50-70 | RSI must exceed this for a long |
| `strategy_rsi_short_thresh` | 45.0 | 30-50 | RSI must be below this for a short |
| `strategy_adx_filter_on` | true | true/false | Enable the ADX trend-strength gate |
| `strategy_adx_period` | 14 | 5-30 | ADX period |
| `strategy_adx_threshold` | 20.0 | 0-50 | Minimum ADX to allow an entry |
| `strategy_stop_mode` | 0 | 0-1 | 0 = ATR(period)×mult, 1 = fixed percent |
| `strategy_stop_atr_period` | 14 | 5-30 | ATR period for the ATR stop |
| `strategy_stop_atr_mult` | 2.0 | 0.5-4.0 | ATR multiplier for stop distance |
| `strategy_stop_fixed_pct` | 2.0 | 0.5-5.0 | Fixed-percent stop distance (mode 1) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean EMA trends on intraday TFs.
- `GBPUSD.DWX` — liquid major with sustained directional legs.
- `USDJPY.DWX` — trending major, good momentum persistence.
- `XAUUSD.DWX` — gold; strong trend regimes suit EMA-cross momentum.
- `GDAXI.DWX` — DAX 40; ported from the card's `GER40` (no `GER40.DWX` in matrix).
- `NDX.DWX` — Nasdaq 100; high-beta index with strong trends, live-tradable.
- `WS30.DWX` — Dow 30; index trend exposure, live-tradable.

**Explicitly NOT for:**
- `SP500.DWX` — not in the card's R3 basket; also backtest-only (not routable live).

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
| Trades / year / symbol | `~80` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `whipsaw losses in sideways regimes; ADX/ATR filters dampen them` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView open-source community script)
**Pointer:** `https://www.tradingview.com/script/e7XQPek8-EMA-Cross-RSI-ADX-Autotrade-Strategy-V2/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10787_tv-ema-rsi-adx.md`

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
| v1 | 2026-06-05 | Initial build from card | 965998e0-9872-4e96-aa28-42389e27c2bd |
