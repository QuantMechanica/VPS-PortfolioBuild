# QM5_11417_lasker-triple-bb-mean-reversion-gbpjpy-m15 — Strategy Spec

**EA ID:** QM5_11417
**Slug:** `lasker-triple-bb-mean-reversion-gbpjpy-m15`
**Source:** `84b1cd3f-0cb4-5cf1-92ac-e41ba15b7c93` (see `strategy-seeds/sources/84b1cd3f-0cb4-5cf1-92ac-e41ba15b7c93/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Triple Bollinger Band mean reversion on M15. Three bands share period 50 and the
close price, at deviations 2.0 (inner), 3.0 (middle) and 4.0 (outer). When the
last closed bar's close pushes past the midpoint between the inner (2σ) and middle
(3σ) bands, price has reached a statistically extreme extension and is expected to
revert toward the SMA50 midline.

The single trade EVENT is a fresh extension into that middle zone: SHORT when
`close[1] >= (bb1_upper + bb2_upper)/2` AND the prior bar `close[2]` was still
below its own threshold (a genuine cross this bar, not a persistent state). LONG
is the mirror below the lower bands. Take profit is the Bollinger midline (SMA50).
Stop loss is the 4σ outer band plus a small buffer (capped at 30 pips). Trading is
restricted to the active Tokyo+London+NY broker-time window, excluding the dead
NY-close→Tokyo-open hours.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 50 | 30-70 | Bollinger period for all three bands |
| `strategy_bb_dev_inner` | 2.0 | 1.5-2.5 | Inner band (BB1) deviation |
| `strategy_bb_dev_middle` | 3.0 | 2.5-3.5 | Middle band (BB2) deviation |
| `strategy_bb_dev_outer` | 4.0 | 3.5-4.5 | Outer band (BB3) deviation, used for the stop |
| `strategy_sl_buffer_pips` | 5 | 3-10 | Stop buffer beyond the outer band |
| `strategy_sl_cap_pips` | 30 | 20-50 | Hard cap on stop distance from entry |
| `strategy_session_enabled` | true | true/false | Restrict to active session hours |
| `strategy_session_start_hour` | 2 | 0-23 | Broker hour: session start (Tokyo open) |
| `strategy_session_end_hour` | 23 | 0-23 | Broker hour: session end (NY close) |
| `strategy_spread_pct_of_stop` | 25.0 | 10-50 | Skip if spread > this % of stop buffer distance |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` — primary instrument; high volatility produces wide bands and
  frequent extreme extensions, the core edge of the strategy.
- `EURUSD.DWX` — secondary instrument named in the card's R3 portable basket;
  tighter bands but liquid and clean for a mean-reversion baseline.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500.DWX) — the band geometry and pip-scaled stops are
  calibrated to forex; index point scales differ materially.

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
| Trades / year / symbol | `~200` |
| Typical hold time | `minutes to a few hours (intraday)` |
| Expected drawdown profile | `mean-reversion: many small wins, occasional larger losses when extension persists to the outer-band stop` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `84b1cd3f-0cb4-5cf1-92ac-e41ba15b7c93`
**Source type:** `book`
**Pointer:** Rita Lasker (Green Forex Group), "Forex GBP/JPY Scalping Strategy — Triple Bollinger Bands" (local PDF per card source_citation)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11417_lasker-triple-bb-mean-reversion-gbpjpy-m15.md`

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
