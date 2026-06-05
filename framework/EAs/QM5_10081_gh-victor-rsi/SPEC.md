# QM5_10081_gh-victor-rsi — Strategy Spec

**EA ID:** QM5_10081
**Slug:** `gh-victor-rsi`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades RSI-versus-price divergence as a mean-reversion reversal. On each
closed H1 bar it scans the last 100 closed candles for the two most recent local
price extremes (pivots, defined by a strictly higher/lower bar on each side).

Long: the recent pivot low is below the older pivot low (price made a lower low),
the RSI(14) at the recent pivot is above the RSI at the older pivot (RSI made a
higher low), both pivot RSI values are below 30, and the last closed candle is
bullish (close > open). Short is the mirror: recent pivot high above the older
high, recent RSI below the older RSI, both pivot RSI values above 70, and the
last closed candle bearish.

Stops and exit are a percent model. The initial long stop is `ask * (1 - 1%)`,
the initial short stop is `bid * (1 + 1%)`. There is no fixed take-profit: the
position is exited by a percent trailing stop that, each tick, ratchets the long
stop up to `bid * (1 - 1%)` (or the short stop down to `ask * (1 + 1%)`) whenever
that is tighter than the current stop. One active position per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `rsi_period` | 14 | 5-50 | RSI period on close. |
| `rsi_oversold` | 30.0 | 10-40 | Both pivot RSI lows must be below this for a long. |
| `rsi_overbought` | 70.0 | 60-90 | Both pivot RSI highs must be above this for a short. |
| `div_lookback_max` | 100 | 20-300 | Max closed-bar depth searched for divergence pivots. |
| `div_pivot_strength` | 2 | 1-5 | Bars on each side that define a local price extreme. |
| `sl_percent` | 1.0 | 0.2-5.0 | Initial stop distance as a percent of entry price. |
| `trail_percent` | 1.0 | 0.2-5.0 | Trailing stop distance as a percent of current price. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; RSI mean-reversion edge is well-behaved on FX majors.
- `GBPUSD.DWX` — liquid major with comparable volatility profile to EURUSD.
- `USDJPY.DWX` — liquid major; divergence reversals carry across the USD majors.
- `XAUUSD.DWX` — high-volatility metal where percent-based stops scale naturally.

**Explicitly NOT for:**
- Equity index CFDs (NDX/WS30/SP500.DWX) — the card universe is FX majors + gold;
  index behaviour and percent-stop sizing were not validated here.

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
| Trades / year / symbol | `~30` |
| Typical hold time | `hours to a few days (trailing-stop exit)` |
| Expected drawdown profile | `clustered losses in trending regimes that run against reversals` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** `forum` (GitHub public repository)
**Pointer:** Victor Algo, "Divergence Rsi de LeTraderSmart" EA, `victor-algo/channel` GitHub repo
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10081_gh-victor-rsi.md`

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
| v1 | 2026-06-05 | Initial build from card | b0bd92e3-e584-4fe1-9a44-a1de9195f2ba |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
