# QM5_11350_rbt-follow-trend-ema-adx-macd-h4 — Strategy Spec

**EA ID:** QM5_11350
**Slug:** `rbt-follow-trend-ema-adx-macd-h4`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (RoboForex "Strategy Follow the Trend", H4)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A trend-following system on H4 built from three RoboForex "Follow the Trend"
conditions. To avoid the .DWX two-cross-same-bar zero-trade trap, exactly ONE
crossover is the firing EVENT and the rest are confirming STATEs. Long fires
when either EMA(4) crosses above EMA(10) OR the MACD(5,10,4) main line crosses
up through zero, AND the directional state ADX(28) +DI > -DI holds, AND the
non-triggering indicators confirm long (EMA(4) > EMA(10) and MACD main >= 0).
Short mirrors (EMA-down OR MACD-down cross; -DI > +DI; EMA(4) < EMA(10) and
MACD main <= 0). MACD main may be negative outside an entry; it is never gated
on its sign except as this confirm state. Exit on a fixed 30-pip stop, a fixed
60-pip target, or a reverse EMA(4)/EMA(10) cross against the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 4 | 2-50 | Fast EMA period (cross trigger / confirm) |
| `strategy_ema_slow_period` | 10 | 5-100 | Slow EMA period (cross trigger / confirm) |
| `strategy_adx_period` | 28 | 7-50 | ADX period for the +DI/-DI directional state |
| `strategy_macd_fast` | 5 | 2-30 | MACD fast EMA |
| `strategy_macd_slow` | 10 | 5-60 | MACD slow EMA |
| `strategy_macd_signal` | 4 | 2-20 | MACD signal SMA |
| `strategy_sl_pips` | 30.0 | 5-200 | Fixed stop distance in pips |
| `strategy_tp_pips` | 60.0 | 10-400 | Fixed target distance in pips |
| `strategy_spread_cap_pips` | 30.0 | 1-100 | Block only a genuinely wide spread (fail-open on 0) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; H4 trend persistence; in `dwx_symbol_matrix.csv`.
- `GBPUSD.DWX` — trending major with H4 swings; matrix-verified.
- `AUDUSD.DWX` — commodity-linked major; matrix-verified.
- `USDJPY.DWX` — trending major (3-digit pip scaling handled by `QM_StopRulesPipsToPriceDistance`).

**Explicitly NOT for:**
- Index / metal CFDs — the card's 30/60-pip fixed stops are FX-calibrated; index point scales differ materially.

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
| Expected drawdown profile | `moderate; trend-follower with fixed 30-pip stop, frequent small losers` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low/medium` (2R target offsets <50% hit rate) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** `book` (RoboForex strategy-collection PDF)
**Pointer:** RoboForex "Strategy Follow the Trend" (local PDF per card frontmatter)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11350_rbt-follow-trend-ema-adx-macd-h4.md`

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
