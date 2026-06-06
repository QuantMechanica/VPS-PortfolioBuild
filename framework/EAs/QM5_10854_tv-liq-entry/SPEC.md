# QM5_10854_tv-liq-entry — Strategy Spec

**EA ID:** QM5_10854
**Slug:** `tv-liq-entry`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades a session liquidity-sweep reclaim. During the Asian build window
(broker hours 0–9) it records the session high and low. After that window closes
it validates the Asian range against ATR(14) — skipping sessions whose range is
below 0.25×ATR or above 2.5×ATR. During the New York volatility window (broker
hours 15–18) it looks for a stop-hunt-and-reclaim: a long fires when price has
swept below the Asian low and a bar then closes back above it; a short fires when
price has swept above the Asian high and a bar then closes back below it. The
reclaim bar must be a displacement candle (body ≥ 60% of its range, closing in
the trade direction), the triple-EMA stack (9/21/50) on the execution timeframe
must be aligned in the trade direction, and the H4 higher-timeframe bias
(price vs EMA50) must confirm. The initial stop is the sweep extreme offset by
0.25×ATR(14); the target is a fixed 2R. A setup is skipped if spread exceeds 15%
of the stop distance. Positions are closed at the session-close hour (broker 21)
if neither target nor stop is hit, or earlier if the triple-EMA stack flips
against the position. One long and one short are allowed per session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 9 | 5-50 | Fast EMA of the execution-TF stack |
| `strategy_ema_mid` | 21 | 10-100 | Mid EMA of the execution-TF stack |
| `strategy_ema_slow` | 50 | 20-200 | Slow EMA of the execution-TF stack |
| `strategy_htf` | PERIOD_H4 | H4/D1 | Higher-timeframe bias frame |
| `strategy_htf_ema` | 50 | 20-200 | HTF EMA; price above = long bias, below = short |
| `strategy_atr_period` | 14 | 7-50 | ATR period for stop buffer + range filter |
| `strategy_atr_sl_buffer` | 0.25 | 0.10-0.50 | Stop offset beyond sweep extreme, in ATR multiples |
| `strategy_displacement_min` | 0.60 | 0.50-0.70 | Minimum reclaim-candle body/range fraction |
| `strategy_target_r` | 2.0 | 1.5-3.0 | Fixed target as multiple of initial risk |
| `strategy_spread_guard_pct` | 0.15 | 0.05-0.30 | Skip if spread > pct of stop distance |
| `strategy_range_min_atr` | 0.25 | 0.10-1.00 | Skip if Asian range < this × ATR |
| `strategy_range_max_atr` | 2.50 | 1.50-4.00 | Skip if Asian range > this × ATR |
| `strategy_asian_start_hour` | 0 | 0-23 | Asian build window start (broker, inclusive) |
| `strategy_asian_end_hour` | 9 | 0-23 | Asian build window end (broker, exclusive) |
| `strategy_ny_start_hour` | 15 | 0-23 | NY entry window start (broker, inclusive) |
| `strategy_ny_end_hour` | 18 | 0-23 | NY entry window end (broker, exclusive) |
| `strategy_session_close_hour` | 21 | 0-23 | Force-close hour if target/stop not hit |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity FX major with a clean Asian-range/NY-sweep profile.
- `GBPUSD.DWX` — FX major with strong London/NY displacement, the card's core market.
- `XAUUSD.DWX` — gold, high session-driven volatility named in the card's market list.
- `NDX.DWX` — Nasdaq 100, NY-session index with pronounced opening displacement.
- `GDAXI.DWX` — DAX 40, used as the available port for the card's "GER40" index.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker does not route orders); not registered here.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H4` (price-vs-EMA50 directional bias) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~55` |
| Typical hold time | `intraday — minutes to a few hours, flat by session close` |
| Expected drawdown profile | `clustered losses in compressed/false-sweep ranges` |
| Regime preference | `breakout / volatility-expansion (session liquidity sweep)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView open-source strategy script)
**Pointer:** `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/` — author handle `JamesK318`, "Liquidity Entry Logic Execution Engine"
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10854_tv-liq-entry.md`

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
| v1 | 2026-06-06 | Initial build from card | b8f32403-2a2c-4733-8079-585092699678 |
