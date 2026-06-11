# QM5_9699_ff-sonicr-wave-h1 — Strategy Spec

**EA ID:** QM5_9699
**Slug:** `ff-sonicr-wave-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

During the London session (broker hours 08:00–17:00) the EA scans the last 24 H1 closed bars for a three-swing PA wave: a swing low A, a swing high B (with B−A ≥ 1×ATR), and a higher swing low C (C > A). A long entry fires on the first H1 bar whose close exceeds both the swing high B and the nearest whole/half-number level that capped B (within 0.25×ATR above B), provided the Dragon EMA(34) and Trend EMA(89) are both sloping upward over the last 5 bars and the close is above Dragon. The stop is placed below C minus 0.25×ATR; the take-profit is the closer of the next round/half level above entry or 2.0R. The short side is the exact mirror. Positions exit on a Dragon close-cross, a 10-hour time stop, or via SL/TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_dragon` | 34 | 5–100 | Dragon EMA period (H1) |
| `strategy_ema_trend` | 89 | 20–200 | Trend EMA period (H1) |
| `strategy_atr_period` | 14 | 5–50 | ATR period for sizing and thresholds |
| `strategy_wave_lookback` | 24 | 10–50 | Bars scanned for A-B-C swing structure |
| `strategy_dragon_slope_bars` | 5 | 2–20 | Shift used to compute Dragon/Trend slope |
| `strategy_wave_min_atr_mult` | 1.0 | 0.5–3.0 | Minimum B-A range in ATR multiples |
| `strategy_level_atr_mult` | 0.25 | 0.1–0.5 | Level proximity and SL buffer (ATR fraction) |
| `strategy_tp_r_mult` | 2.0 | 1.0–5.0 | TP at N×R (if closer than next level) |
| `strategy_time_stop_hours` | 10 | 4–24 | Time stop (~10 H1 bars) in wall-clock hours |
| `strategy_london_start_hour` | 8 | 0–12 | London session start (broker hour) |
| `strategy_london_end_hour` | 17 | 12–23 | London session end (broker hour) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary EUR/USD H1 pair, high liquidity during London session, tight spreads
- `GBPUSD.DWX` — GBP/USD shows strong directional waves during London open
- `USDJPY.DWX` — USD/JPY exhibits clean swing structure; JPY pair uses 0.5-point level step
- `EURJPY.DWX` — EUR/JPY cross liquid during London; JPY level step applied

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — round-number level logic is FX-centric; no session meaning
- `XAUUSD.DWX` — volatility profile and level spacing incompatible with FX wave parameters

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
| Trades / year / symbol | ~45 |
| Typical hold time | 2–10 hours (time stop at 10 h) |
| Expected drawdown profile | Moderate; SL at structural low C, ~1–2% per trade |
| Regime preference | Trend / breakout during London momentum |
| Win rate target (qualitative) | medium (breakout continuation, ~45–55%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** https://www.forexfactory.com/thread/114792-sonic-r-system (sonicdeejay / traderathome)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9699_ff-sonicr-wave-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | f0c7d913-dde6-4195-b496-3ea9a23125f1 |
