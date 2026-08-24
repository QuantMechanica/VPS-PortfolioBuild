# QM5_36002_nnfx-kijunsen-absolute-strength-damiani — Strategy Spec

**EA ID:** QM5_36002
**Slug:** `nnfx-kijunsen-absolute-strength-damiani`
**Source:** `nnfx-kijunsen-absolute-strength-damiani-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_36002_nnfx-kijunsen-absolute-strength-damiani.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_36002_nnfx-kijunsen-absolute-strength-damiani.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The EA trades D1 trend alignment only after a completed bar. A long requires the
last close above Kijun-Sen(26), average positive close-to-close movement over
10 bars above average negative movement, Aroon-Up(25) at least 70, and the
Damiani volatility ratio above its anti-threshold; a short reverses those
directional tests. Every entry has a 1.0 ATR(14) stop, half the position closes
after a favorable 1.0 ATR move, and the remainder exits when the completed-bar
close returns across Kijun-Sen.

The exact mechanical implementation is:

- Baseline: Ichimoku Kijun-Sen(26) evaluated on completed D1 bars (Shift=1).
- C1 Trigger: ASO(10) is the arithmetic mean of positive D1 close deltas versus
  the arithmetic mean of absolute negative D1 close deltas.
- C2 Confirmation: Aroon(25) measuring periods since high/low with confirmation threshold 70.0.
- Volume Gate: Damiani uses `ATR(13)/ATR(40) > 1.40 * StdDev(13)/StdDev(40)`.
- Long Entry: Close[1] > Kijun[1] AND ASO_Bulls[1] > ASO_Bears[1] AND AroonUp[1] >= 70.0 AND Damiani Trade == TRUE.
- Short Entry: Close[1] < Kijun[1] AND ASO_Bears[1] > ASO_Bulls[1] AND AroonDown[1] >= 70.0 AND Damiani Trade == TRUE.
- Stop Loss: Placed at 1.0 * ATR(14, D1)[1] from entry.
- TP1: At +1.0R (the entry stop distance, derived from ATR), close 50% once.
- TP1 exactness: entries fail closed when the risk-sized volume cannot split
  into two equal, broker-valid halves; outgoing deal history reconstructs the
  one-time TP1 state after restart.
- Runner protection: After TP1, move SL to Entry + 1.0 pip for a long or Entry - 1.0 pip for a short.
- Runner Exit: Close position when price re-crosses Kijun-Sen line (Close[1] < Kijun[1] for Long, Close[1] > Kijun[1] for Short).
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14, D1)[1]), rollover blackout 23:55–00:05 UTC (broker time converted with `QM_BrokerToUTC`), a 2.0% account realized-loss entry halt, and a one-position maximum for the strategy instance.
- Hard stops: Framework kill switch at 2.5% daily equity drawdown and the 5.0% account-level total-drawdown signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_kijun_period` | 26 | 20 - 35 | Kijun-Sen baseline lookback period |
| `strategy_tenkan_period` | 9 | fixed | Ichimoku helper parameter; Kijun output uses the card lookback |
| `strategy_senkou_period` | 52 | fixed | Ichimoku helper parameter; Kijun output uses the card lookback |
| `strategy_aso_period` | 10 | 7 - 14 | Absolute Strength Oscillator period |
| `strategy_aroon_period` | 25 | fixed | Aroon confirmation period |
| `strategy_aroon_threshold` | 70.0 | 60.0 - 80.0 | Aroon confirmation threshold |
| `strategy_damiani_vis_period` | 13 | fixed | Damiani Volatmeter viscosity ATR period |
| `strategy_damiani_sed_period` | 40 | fixed | Damiani Volatmeter sedimentation ATR period |
| `strategy_damiani_threshold` | 1.40 | fixed | Damiani Volatmeter anti-threshold multiplier |
| `strategy_atr_period` | 14 | fixed | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.00 | fixed | Stop loss distance as ATR multiplier |
| `strategy_tp_atr_mult` | 1.00 | fixed | TP1 trigger as a multiple of the entry ATR risk |
| `strategy_tp1_fraction` | 0.50 | fixed | Volume closed once at TP1 |
| `strategy_be_buffer_pips` | 1 | fixed | Runner stop offset beyond entry after TP1 |
| `strategy_spread_atr_mult` | 1.80 | fixed | Spread filter ATR multiplier |
| `strategy_daily_loss_halt_pct` | 2.0 | fixed | Account realized-loss threshold that blocks new entries |
| `strategy_daily_hard_stop_pct` | 2.5 | fixed | Restart-safe framework daily equity hard stop |
| `strategy_total_dd_halt_pct` | 5.0 | fixed | Account-level total-drawdown signal threshold |
| `strategy_risk_percent` | 1.0 | 0.5 - 1.0 | Card live-risk input; V5 caps per-EA risk at 1% |
| `strategy_per_trade_risk_cap_pct` | 1.0 | fixed | Framework per-trade risk cap |
| `strategy_slippage_ticks` | 3 | fixed | Maximum market-order deviation, converted from trade ticks to symbol points |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-targeted liquid major with canonical DWX D1 history (slot 0).
- `GBPJPY.DWX` — card-targeted volatile FX cross with canonical DWX D1 history (slot 1).
- `AUDCAD.DWX` — card-targeted commodity-currency cross with canonical DWX D1 history (slot 2).
- `NZDUSD.DWX` — card-targeted liquid major with canonical DWX D1 history (slot 3).

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 (`expected_trades_per_year_per_symbol`) |
| Expected trade frequency | `80-160 high-conviction trades per year` across the four-symbol basket |
| Typical hold time | Not specified by the card; D1 runner remains open until Kijun re-cross or a framework exit |
| Expected drawdown profile | Frontmatter prior 18%; card hard-stop contract is 2.5% daily and 5.0% total |
| Regime preference | Trend-following with volatility expansion (inferred from the stated entry rules) |
| Expected profit factor | 1.35 frontmatter prior; source performance claims are not relied upon |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-kijunsen-absolute-strength-damiani-official-source`
**Source type:** verified quantitative model / NNFX indicator-profile source
**Pointer:** `No Nonsense Forex Advanced Indicator Profile Library, nononsenseforex.com`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per
`artifacts/cards_approved/QM5_36002_nnfx-kijunsen-absolute-strength-damiani.md`.

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
| v1 | 2026-08-24 | Initial build from card | a48f0404-cbba-4611-9eaa-bbd9e4f82a75 |
| v2 | 2026-08-24 | Review rework | TP1 is exact-volume and restart-safe; regression coverage added for review findings |
