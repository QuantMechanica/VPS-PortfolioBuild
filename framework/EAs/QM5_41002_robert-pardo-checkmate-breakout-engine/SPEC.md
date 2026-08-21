# QM5_41002_robert-pardo-checkmate-breakout-engine — Strategy Spec

**EA ID:** QM5_41002
**Slug:** robert-pardo-checkmate-breakout-engine
**Source:** robert-pardo-checkmate-breakout-engine-official-source (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41002_robert-pardo-checkmate-breakout-engine.md`)
**Author of this spec:** Codex
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

On each completed H4 bar, the EA compares Close[1] with the highest high and
lowest low of the preceding ten bars, shifts [2] through [11]. It buys above
that prior upper boundary or sells below the prior lower boundary only when
ATR(14)[1] is greater than ATR(14)[5]. Including the signal bar in its own
channel would make a close breakout impossible, so the approved card's
Donchian notation is implemented as the standard prior-channel test.
Immediately before submitting an entry, the EA rechecks the current spread
against the freshly cached `1.8 * ATR(14)[1]` ceiling; zero modeled DWX spread
is valid and only an actually wider spread blocks the signal. The card's
23:55-00:05 GMT rollover blackout is evaluated after converting Darwinex
broker time to UTC with the framework DST helper.

The initial stop is 1.5 times ATR(14)[1] from entry and the take-profit is 2R.
For an open long, the stop follows the lowest low of the latest ten completed
bars; for an open short, it follows the corresponding highest high. The
framework also applies the approved news pause, Friday close, fixed-risk
backtest sizing, and total-drawdown signal threshold. New entries stop at a
2.0% broker-day equity loss while existing exposure remains managed; the
framework kill switch closes exposure and halts the EA at the card's separate
2.5% daily hard-stop threshold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_H4` | fixed | Card-authorized signal timeframe |
| `strategy_donchian_bars` | `10` | `6-20` | Prior-channel and trailing-channel lookback |
| `strategy_atr_period` | `14` | `8-21` | ATR lookback |
| `strategy_atr_slope_shift` | `5` | fixed | Reference shift in ATR[1] minus ATR[5] |
| `strategy_atr_sl_mult` | `1.5` | fixed | Initial stop distance in ATR units |
| `strategy_tp_rr_mult` | `2.0` | fixed | Take-profit distance in initial-risk units |
| `strategy_rollover_start_hhmm` | `2355` | fixed | GMT rollover blackout start |
| `strategy_rollover_end_hhmm` | `5` | fixed | GMT rollover blackout end |
| `strategy_spread_filter_mult` | `1.8` | fixed | Maximum spread as a fraction of ATR multiple |
| `strategy_max_positions` | `1` | fixed | Maximum host-symbol positions for this magic |
| `strategy_max_slippage_ticks` | `3` | fixed | Entry deviation converted from ticks to points |
| `strategy_daily_loss_halt_pct` | `2.0` | fixed | Entry halt against the framework's restart-safe broker-day equity anchor |
| `strategy_daily_hard_stop_pct` | `2.5` | fixed | Framework kill-switch daily hard-stop threshold |
| `strategy_total_dd_halt_pct` | `5.0` | fixed | Portfolio drawdown-signal threshold |
| `strategy_per_trade_risk_cap_pct` | `0.5` | fixed | Percent-risk ceiling outside fixed-risk tests |

Framework inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are
not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major FX pair and the card's primary target.
- `GBPUSD.DWX` — liquid major FX pair with independent breakout episodes.
- `USDJPY.DWX` — liquid JPY major that broadens the currency regime mix.

**Explicitly NOT for:**

- Index, metal, and energy CFDs — not authorized by this approved FX card.
- Symbols outside `dwx_symbol_matrix.csv` — no reproducible factory data contract.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_signal_tf)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 (card prior; Q02 measures reality) |
| Expected trade frequency | 80-160 high-conviction trades per year across the authorized basket |
| Typical hold time | Not asserted; exits are 2R, 1.5 ATR, opposite-channel, or Friday close |
| Expected drawdown profile | Conservative card prior 15%; 5% external drawdown-signal halt |
| Regime preference | H4 volatility expansion and directional breakout |
| Win rate target (qualitative) | Unknown; source claims are not accepted as gate evidence |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `robert-pardo-checkmate-breakout-engine-official-source`
**Source type:** book
**Pointer:** Pardo, R. (2008), *The Evaluation and Optimization of Trading Strategies*, John Wiley & Sons.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS per `artifacts/cards_approved/QM5_41002_robert-pardo-checkmate-breakout-engine.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. This build creates
backtest setfiles only and does not authorize live use.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from approved card | Task 5d5cc9f6-e096-44a3-af78-99abc2d9e7ed |
| v2 | 2026-08-20 | Entry-permission repair | Recheck current spread after closed-bar state refresh; no signal thresholds changed |
| v3 | 2026-08-21 | Card-time normalization repair | Task 5b0eb50d-de0a-4d75-a461-4a08cc03c2c9; convert broker time to GMT before the rollover blackout |
| v4 | 2026-08-21 | Card loss-limit reconciliation | Preserve the 2.0% entry halt and wire the distinct 2.5% framework hard stop |
