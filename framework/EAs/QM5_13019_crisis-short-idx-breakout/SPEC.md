# QM5_13019_crisis-short-idx-breakout — Strategy Spec

**EA ID:** QM5_13019
**Slug:** `crisis-short-idx-breakout`
**Source:** `MOP-TSMOM-2012` (see `strategy-seeds/sources/MOP-TSMOM-2012/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-06

---

## 1. Strategy Logic

Short-only D1 breakout on equity indices, active only in a bear regime with
expanding volatility (the crisis-alpha slice of time-series momentum per
Moskowitz/Ooi/Pedersen and Fung/Hsieh). A short opens when, on the same
closed D1 bar, the close is below the SMA(200) (bear regime), ATR(14) is
greater than ATR(14) measured 20 bars earlier (volatility expanding), and
the close breaks below the Donchian(40) low (breakdown trigger). Exit is
whichever comes first: an ATR(14)×3.0 hard stop from entry, a cover on a
closed D1 bar close above the Donchian(15) high (channel trail), or a
25-bar max-hold time stop. Long side never trades.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_entry` | 40 | 30-55 | Donchian low lookback (bars) for the breakdown entry trigger |
| `strategy_sma_regime` | 200 | 150-250 | SMA period defining the bear-regime gate (close below = bear) |
| `strategy_atr_period` | 14 | 10-20 | ATR period used for both the vol-expansion gate and the hard stop |
| `strategy_vol_expansion_lag` | 20 | 10-30 | Bars back for the ATR vol-expansion comparison |
| `strategy_atr_sl_mult` | 3.0 | 2.5-3.5 | ATR multiple for the hard stop distance from entry |
| `strategy_donchian_trail` | 15 | 10-20 | Donchian high lookback (bars) for the cover/trail exit |
| `strategy_max_hold_bars` | 25 | 15-35 | Max D1 bars to hold a position before the time-stop close |
| `strategy_max_spread_points` | 150 | 100-250 | Spread cap in points; `.DWX` reads 0 spread in the tester so this is inert in backtest, active in live |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — primary target per card R3; DAX 40 index, liquid D1 history 2018-2026, bear-regime crisis episodes present (2018Q4, 2020, 2022).
- `WS30.DWX` — secondary target per card R3; Dow 30 index, same crisis-alpha regime structure, live-tradable.

**Explicitly NOT for:**
- FX / commodity symbols — the strategy's crisis-alpha thesis (Fung/Hsieh trend-follower convexity) is specific to equity-index bear regimes, not currency or commodity crises.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (default, host chart) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~7 (5-10 range; episodic, zero-trade calm years possible) |
| Typical hold time | up to 25 D1 bars (time-stop bound); often shorter via trail cover or hard stop |
| Expected drawdown profile | expected_dd_pct 15%; right-skewed, episodic — flat in bull regimes, bursts of shorts in bear regimes |
| Regime preference | bear regime + volatility-expansion (crisis alpha) |
| Win rate target (qualitative) | low-medium; convex payoff (few large winners on panic legs, many small stopped-out losers) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-TSMOM-2012`
**Source type:** paper
**Pointer:** Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics — https://docs.lhpedersen.com/TimeSeriesMomentum.pdf; supplement Fung and Hsieh (2001), Review of Financial Studies — https://faculty.fuqua.duke.edu/~dah7/RFS2001.pdf
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13019_crisis-short-idx-breakout.md`

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
| v1 | 2026-07-06 | Initial build from card | 9a20f6ba-485a-4501-a128-b2eec92875c0 |
