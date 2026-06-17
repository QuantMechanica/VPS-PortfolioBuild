# QM5_11062_pst-scalper — Strategy Spec

**EA ID:** QM5_11062
**Slug:** `pst-scalper`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (Rob Carver / pysystemtrade provided `scalper` system)
**Author of this spec:** Claude (Board Advisor build lane)
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Intraday bracket mean-reversion ported from Rob Carver's pysystemtrade `scalper`
system (`systems/provided/scalper/components.py`). Each closed bar the EA estimates
a short-horizon range `R` as the mean of the last `strategy_R_bars` completed bar
ranges (high-low), clamped to `[min_R, max_R]`. The source rule places a SYMMETRIC
pair of resting limit orders around the current mid — buy-limit at `mid - F*(R/2)`
and sell-limit at `mid + F*(R/2)` (F = `limit_mult_F`, 0.75 default) — and when one
fills, the opposite bracket price is the take-profit while a protective stop is
attached at `(stop_mult_K - limit_mult_F)*R` (default 0.125·R) from the fill price,
at least `min_stop_ticks` away. Trades only when spread < `spread_mult * R`; stops
opening new brackets within `cutoff_horizons*horizon` of session end.

FRAMEWORK REALISATION (deviation, flagged): the V5 corset is single-entry /
one-position-per-magic, so the symmetric two-leg bracket is expressed as ONE
resting limit that FADES the last bar's displacement — a down-close bar places a
BUY_LIMIT at `mid - F*(R/2)`, an up-close bar places a SELL_LIMIT at `mid + F*(R/2)`
— with the opposite-bracket price attached as TP and the `(K-F)*R` stop as SL, and
an order expiration of `horizon_seconds`. A fill reproduces the card's
fill→opposite-bracket-TP / stop geometry exactly for that direction. The
symmetric-pair-to-single-leg fade is the only mechanical deviation from the source.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_R_bars` | 4 | 2-12 | Completed bars averaged (high-low) to estimate range `R` |
| `strategy_limit_mult_F` | 0.75 | 0.5-1.0 | Bracket offset fraction F: limit price = mid ± F·(R/2) |
| `strategy_stop_mult_K` | 0.875 | 0.80-0.95 | Stop multiple K; stop distance = (K − F)·R from fill |
| `strategy_min_R_points` | 50.0 | >0 | Lower clamp for R, in raw points (set per-symbol via setfile) |
| `strategy_max_R_points` | 5000.0 | >0 | Upper clamp for R, in raw points (set per-symbol via setfile) |
| `strategy_min_stop_ticks` | 3 | 1-20 | Minimum stop distance from entry, in ticks |
| `strategy_spread_mult` | 0.25 | 0.10-0.50 | Skip if spread > spread_mult·R (fail-open on zero spread) |
| `strategy_horizon_seconds` | 600 | 60-1800 | Bracket horizon → pending-order expiration seconds |
| `strategy_session_start_h` | 7 | 0-23 | Broker-hour: first hour brackets may be placed |
| `strategy_session_end_h` | 20 | 0-23 | Broker-hour: last hour brackets may be placed |
| `strategy_cutoff_horizons` | 3 | 1-6 | Stop new brackets within cutoff_horizons·horizon of session end |

---

## 3. Symbol Universe

**Designed for** (all card R3 PASS targets, all present in `dwx_symbol_matrix.csv`):
- `EURUSD.DWX` — most-liquid FX major; tightest spread vs R, primary scalper venue.
- `GBPUSD.DWX` — liquid FX major with intraday mean-reverting micro-structure.
- `USDJPY.DWX` — liquid FX major; JPY pip scaling handled by point-based R clamp.
- `AUDUSD.DWX` — liquid FX major; complements the USD-leg basket.
- `NDX.DWX` — liquid index CFD with intraday ranging; live-tradable.
- `WS30.DWX` — liquid index CFD with intraday ranging; live-tradable.

**Explicitly NOT for:**
- Thin / wide-spread crosses — the `spread < spread_mult·R` filter would gate out
  most brackets, starving the strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

> Card default horizon is 600 s (= M10, not a standard MT5 period). Built on `M5`
> (300 s — the lowest card-tested horizon, most scalper-faithful); the 600 s value
> is preserved as the pending-order expiration (`strategy_horizon_seconds`). M15
> (900 s) is the other card-tested horizon and is a valid setfile sweep. See build
> flags re: M1/M5 history gaps (2017-2022) for some DWX symbols.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~200 (card `expected_trades_per_year_per_symbol`) |
| Typical hold time | minutes (intraday bracket; expires within one horizon) |
| Expected drawdown profile | many small wins/losses; sensitive to spread + fill quality |
| Regime preference | mean-revert (intraday range fade) |
| Win rate target (qualitative) | medium-high (tight TP at opposite bracket) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** code (open-source Python system)
**Pointer:** https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/scalper/components.py
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11062_pst-scalper.md`

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
| v1 | 2026-06-17 | Initial build from card | Board Advisor build lane; single-leg fade port of symmetric bracket |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
