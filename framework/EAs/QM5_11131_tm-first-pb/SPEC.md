# QM5_11131_tm-first-pb — Strategy Spec

**EA ID:** QM5_11131
**Slug:** `tm-first-pb`
**Source:** `63b6d09c-d79f-561b-b577-eb5bf5878af1` (TradingMarkets, Matt Radtke 2013)
**Author of this spec:** Claude
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

Long-only "first pullback inside a strong uptrend" on the D1 close. The EA only
acts when the last closed daily bar sits in a strong multi-horizon uptrend —
its close is above the 200, 100, 50 and 20-period SMAs — yet has just pulled
back below the 5-period SMA (the first short-term sign of weakness). On that
setup it places a BUY LIMIT a fixed depth below the setup close (4% below for
US index CFDs, or 1.0×ATR(14) below for non-US CFDs) and lets it work for up to
3 D1 bars; if unfilled it is cancelled. Once filled, the position exits when the
daily close climbs back above the 5-period SMA, or after a 7 D1-bar time stop,
whichever comes first. A 2.5×ATR(14) protective stop sits under the entry to cap
adverse moves. One active position (or working limit) per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `trend_sma_anchor` | 200 | 100-300 | Long-horizon trend filter; close must be above it |
| `trend_sma_slow` | 100 | 50-200 | Mid-long trend filter |
| `trend_sma_mid` | 50 | 20-100 | Mid trend filter |
| `trend_sma_fast` | 20 | 10-50 | Short trend filter |
| `pullback_sma` | 5 | 3-10 | First-pullback MA: setup needs close below it; exit when close above it |
| `entry_limit_use_atr` | false | true/false | false = % depth (US indices); true = ATR-proxy depth (non-US) |
| `entry_limit_pct` | 4.0 | 2.0-6.0 | Limit depth % below setup close (US indices) |
| `entry_limit_atr_mult` | 1.0 | 0.5-1.5 | Limit depth in ATR(14) below setup close (non-US) |
| `entry_atr_period` | 14 | 10-20 | ATR period for limit proxy + protective stop |
| `entry_limit_valid_bars` | 3 | 1-5 | Cancel the unfilled limit after N D1 bars |
| `stop_atr_mult` | 2.5 | 2.0-3.0 | Protective stop = N×ATR(14) below entry |
| `max_hold_bars` | 7 | 5-10 | Time exit after N D1 bars in trade |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only strategy-specific inputs are listed.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500; primary US large-cap index from the card R3 basket (backtest-only).
- `NDX.DWX` — Nasdaq 100; live-tradable US large-cap, % limit depth.
- `WS30.DWX` — Dow 30; live-tradable US large-cap, % limit depth.
- `GDAXI.DWX` — DAX 40; card stated GER40 (not in matrix) → ported to GDAXI.DWX. Use ATR limit-depth mode for this non-US CFD.

**Explicitly NOT for:**
- `GER40.DWX` — not a canonical DWX custom symbol; the DAX 40 ships as `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` — unavailable S&P variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~8` |
| Typical hold time | `a few days (<=7 D1 bars)` |
| Expected drawdown profile | `trend-pullback; per-trade loss capped by 2.5xATR stop` |
| Regime preference | `trend (buy first pullback inside a strong uptrend)` |
| Win rate target (qualitative) | `medium-high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `63b6d09c-d79f-561b-b577-eb5bf5878af1`
**Source type:** `article`
**Pointer:** `https://tradingmarkets.com/connorsrsi/learning-from-the-first-pullback-strategy-1584306`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11131_tm-first-pb.md`

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
| v1 | 2026-06-07 | Initial build from card | 5b8bd5a8-f3e1-4f21-af2c-33c20db2620a |
