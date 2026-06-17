# QM5_10946_zuck-weekend-cont — Strategy Spec

**EA ID:** QM5_10946
**Slug:** `zuck-weekend-cont`
**Source:** `21ef3dfd-fac6-5d5d-b9a0-5ba447992f94` (see `strategy-seeds/sources/21ef3dfd-fac6-5d5d-b9a0-5ba447992f94/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Long-only weekend-continuation seasonality on H1. Trading is evaluated only on
Friday during the symbol's final liquid broker-time hour. The EA buys at market
when a clear short-term uptrend exists: the prior closed bar's close is above its
SMA(20) AND above the close 5 bars earlier (`close[1] > SMA(20)[1]` AND
`close[1] > close[5]`). An emergency stop is placed at `1.5 * ATR(14)` below the
entry. The position is held over the weekend and closed on the first liquid
Monday broker-time hour (time stop). If the weekend gap moves price more than
`2.5 * ATR(14)` adverse to the recorded entry, the position is closed
immediately. One position per magic; no scaling, trailing, or grid.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trend_sma_period` | 20 | 10-40 | Trend-filter SMA period (close[1] must be above it) |
| `strategy_trend_return_bars` | 5 | 3-8 | Momentum lookback; close[1] must exceed close[N] |
| `strategy_atr_period` | 14 | 7-21 | ATR period for the stop and the weekend-gap reference |
| `strategy_atr_stop_mult` | 1.5 | 1.0-2.0 | Initial stop distance = mult × ATR |
| `strategy_gap_atr_mult` | 2.5 | 2.0-3.5 | Adverse weekend-gap emergency-close threshold (in ATR) |
| `strategy_entry_hour_broker` | 22 | 0-23 | Friday final-liquid broker-time hour to evaluate the BUY |
| `strategy_exit_hour_broker` | 9 | 0-23 | Monday first-liquid broker-time hour to close |
| `strategy_spread_pct_of_atr` | 20.0 | 5-50 | Skip entry if spread exceeds this % of ATR (fail-open on zero spread) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md`. **Critical setfile override:**
> `qm_friday_close_enabled` MUST be `false` for this EA — it intentionally holds
> over the weekend; the default Friday-close guard would flatten the position
> before Monday.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- `XAUUSD.DWX` — gold; liquid Friday close, strong day-of-week seasonality.
- `OIL.DWX` — WTI; weekend-gap-sensitive commodity, fits the continuation thesis.
- `EURUSD.DWX` — most liquid FX major; clean Friday-close / Monday-open frame.
- `USDJPY.DWX` — liquid FX major with distinct Asian-Monday reopen behaviour.
- `SP500.DWX` — S&P 500 (backtest-only custom symbol; NOT broker-routable, so
  T6/live promotion is forbidden for SP500-only — parallel-validate on NDX/WS30).
- `NDX.DWX` — Nasdaq 100; live-tradable US index for weekend continuation.
- `WS30.DWX` — Dow 30; live-tradable US index, completes the US large-cap basket.

**Explicitly NOT for:**
- `SPX500.DWX` / `SPY.DWX` / `ES.DWX` — not the canonical custom symbol name; use `SP500.DWX`.

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
| Trades / year / symbol | `~38` |
| Typical hold time | `~2-3 days (Friday close → Monday open, over the weekend)` |
| Expected drawdown profile | `weekend-gap risk; bounded by 1.5×ATR stop + 2.5×ATR gap-close` |
| Regime preference | `trend / short-term momentum (seasonality-driven)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `21ef3dfd-fac6-5d5d-b9a0-5ba447992f94`
**Source type:** `book`
**Pointer:** Gregory Zuckerman, "The Man Who Solved the Market", Portfolio/Penguin, 2019, ISBN 9780735217980 — Laufer's day-of-week / weekend effect.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10946_zuck-weekend-cont.md`

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
| v1 | 2026-06-17 | Initial build from card | central build step |
