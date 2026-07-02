# QM5_9571_williams-smash-day-failure-h4 - Strategy Spec

**EA ID:** QM5_9571
**Slug:** `williams-smash-day-failure-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

The EA trades a failed Larry Williams Smash-Day pattern on closed H4 bars.
For a long, the setup bar makes a down Smash-Day by trading below the prior
low by at least `0.25 * ATR(14)` and closing in its lower quartile. The next
closed H4 bar must reject that breakdown by closing above the setup high by at
least `0.10 * ATR(14)`, with a range of at least `0.80 * ATR(14)`. The EA then
enters long at market on the next H4 bar.

The short is the mirror: an up Smash-Day setup closes in its upper quartile,
then the following H4 bar closes below the setup low by `0.10 * ATR(14)`.

Stops are placed beyond the setup/failure bar extreme plus `0.50 * ATR(14)`.
The primary target is `2.0R`. Secondary exits close the position after 16 H4
bars or when an opposite failed Smash-Day signal is cached on a later closed
bar. All structural reads are performed once per framework new-bar pass.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | `> 0` | ATR period for setup, failure, spread, and stop calculations. |
| `strategy_smash_extreme_atr_mult` | 0.25 | `> 0` | Minimum break beyond the prior H4 extreme for a Smash-Day setup. |
| `strategy_setup_close_quartile` | 0.25 | `0 < value < 1` | Required close location inside the setup bar extreme quartile. |
| `strategy_failure_break_atr_mult` | 0.10 | `>= 0` | Required failure close beyond the setup bar opposite extreme. |
| `strategy_failure_range_atr_mult` | 0.80 | `> 0` | Minimum failure-bar range as a multiple of ATR. |
| `strategy_sl_atr_mult` | 0.50 | `> 0` | ATR buffer beyond setup/failure structure for the stop. |
| `strategy_rr` | 2.0 | `> 0` | Fixed reward-to-risk multiple for take profit. |
| `strategy_spread_atr_mult` | 0.20 | `> 0` | Maximum entry spread as a multiple of ATR. |
| `strategy_time_stop_h4_bars` | 16 | `> 0` | Maximum holding period in H4 bars. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major, registered slot 0.
- `GBPUSD.DWX` - FX major, registered slot 1.
- `USDJPY.DWX` - FX major, registered slot 2.
- `AUDUSD.DWX` - FX major, registered slot 3.
- `USDCAD.DWX` - FX major, registered slot 4.
- `USDCHF.DWX` - FX major, registered slot 5.
- `NZDUSD.DWX` - FX major, registered slot 6.
- `XAUUSD.DWX` - metal CFD, registered slot 7.
- `XTIUSD.DWX` - energy CFD, registered slot 8.
- `GDAXI.DWX` - index CFD, registered slot 9.
- `NDX.DWX` - index CFD, registered slot 10.
- `WS30.DWX` - index CFD, registered slot 11.
- `UK100.DWX` - index CFD, registered slot 12.

**Explicitly NOT for:**
- `FRA40.DWX` - present in the approved card but absent from the local DWX symbol matrix.
- `JP225.DWX` - present in the approved card but absent from the local DWX symbol matrix.
- Any other symbol - runtime guard rejects symbols without a registered slot.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Several H4 bars, capped at 16 H4 bars |
| Expected drawdown profile | Fixed-risk reversal profile bounded by RISK_FIXED and framework kill-switch gates |
| Regime preference | Failed breakout / volatility-rejection reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum and book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9571_williams-smash-day-failure-h4.md`
**R1-R4 verdict (Q00):** all PASS; see `artifacts/cards_approved/QM5_9571_williams-smash-day-failure-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% to 0.5% |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from approved card | Build task `d89c0330-bcb1-45da-9f86-abcd839b6210` |
