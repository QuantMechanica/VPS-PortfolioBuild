# QM5_36003_nnfx-hull-ma-zerolag-macd-stc — Strategy Spec

**EA ID:** QM5_36003
**Slug:** `nnfx-hull-ma-zerolag-macd-stc`
**Source:** `nnfx-hull-ma-zerolag-macd-stc-official-source` (approved card copy in `docs/strategy_card.md`)
**Author of this spec:** Codex
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

On each completed D1 bar, the EA buys when the close is above HMA(20), ZeroLag MACD(12,26,9) is above its signal line, STC(23,50,10) is at least 75, and tick volume is higher than its prior 20-bar average; the short rule is the exact inverse with STC at or below 25. Every entry receives a hard stop one ATR(14) from market price. At +1 ATR the EA closes 50% and moves the runner stop to entry plus one pip; the runner closes on an opposing closed-bar ZeroLag MACD signal-line crossover.

The entry path also observes the card's GMT rollover blackout, positive-spread-versus-ATR cap, daily realized-loss entry halt, single-position limit, central news gate, and framework Friday close. The shared kill switch carries the card's 2.5% daily hard-stop and 5% total-drawdown thresholds.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_hma_period` | 20 | 14–30 | Hull moving-average baseline period. |
| `strategy_zl_macd_fast` | 12 | 8–15 | Fast ZeroLag EMA period. |
| `strategy_zl_macd_slow` | 26 | 20–35 | Slow ZeroLag EMA period. |
| `strategy_zl_macd_signal` | 9 | 2–20 | EMA period for the ZeroLag MACD signal line. |
| `strategy_stc_fast` | 23 | 2–60 | Fast EMA period inside STC. |
| `strategy_stc_slow` | 50 | 3–100 | Slow EMA period inside STC. |
| `strategy_stc_cycle` | 10 | 2–50 | Lookback for both STC stochastic passes. |
| `strategy_stc_smoothing` | 0.50 | (0, 1] | Fixed smoothing factor for both STC passes. |
| `strategy_stc_long_level` | 75.0 | 50–100 | Minimum STC state for a long entry. |
| `strategy_stc_short_level` | 25.0 | 0–50 | Maximum STC state for a short entry. |
| `strategy_better_volume_lookback` | 20 | 2–100 | Prior D1 bars used by the high tick-volume proxy. |
| `strategy_atr_period` | 14 | 2–100 | ATR period for entry stops and spread comparison. |
| `strategy_stop_atr_mult` | 1.00 | >0 | Hard-stop distance in ATR units. |
| `strategy_tp1_atr_mult` | 1.00 | >0 | Partial-profit trigger in ATR units. |
| `strategy_tp1_fraction` | 0.50 | (0, 1) | Fraction of position volume closed at TP1. |
| `strategy_be_buffer_pips` | 1 | 0–100 | Runner stop buffer beyond entry after TP1. |
| `strategy_spread_atr_mult` | 1.80 | >0 | Blocks entry only when positive spread exceeds this ATR multiple. |
| `strategy_daily_loss_halt_pct` | 2.00 | (0, 100) | Realized daily balance loss that halts new entries. |
| `strategy_daily_hard_stop_pct` | 2.50 | (0, 100) | Daily equity loss threshold passed to the shared kill switch. |
| `strategy_total_dd_stop_pct` | 5.00 | (0, 100) | Total drawdown signal threshold passed to the shared kill switch. |

> Framework inputs such as RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, news controls, RNG seed, stress rejection, and Friday close are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — the card's primary liquid FX baseline and smoke symbol.
- `GBPUSD.DWX` — the card explicitly ports the same D1 NNFX trend logic to this liquid FX major.
- `XAUUSD.DWX` — the card explicitly includes gold for a liquid, volatility-rich trend market.

**Explicitly NOT for:**

- Any symbol outside those three active registry rows — the approved card does not authorize broader universe expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` in the canonical skeleton; runner crossover uses the independent framework D1 calendar-period gate. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 (conservative frontmatter prior) |
| Expected trade frequency | Card also states 80–160 high-conviction trades per year; Q02 must resolve this inconsistency empirically. |
| Typical hold time | Not specified; D1 entries with a MACD runner imply multi-day holds. |
| Expected drawdown profile | 18% frontmatter prior, with card-level 2.5% daily and 5% total hard-stop controls. |
| Regime preference | Trend-following; strongest in sustained directional regimes with elevated tick volume. |
| Win rate target (qualitative) | Medium; source win-rate and PF claims are explicitly unevidenced priors. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-hull-ma-zerolag-macd-stc-official-source`

**Source type:** verified quantitative model / source suite

**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_36003_nnfx-hull-ma-zerolag-macd-stc.md` and the build-local `docs/strategy_card.md` copy

**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_36003_nnfx-hull-ma-zerolag-macd-stc.md`.

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
| v1 | 2026-08-23 | Initial build from card | b3b7bf51-a5fa-406b-bfeb-0283ca68ba81 |
