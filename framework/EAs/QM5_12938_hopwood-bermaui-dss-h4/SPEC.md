# QM5_12938_hopwood-bermaui-dss-h4 — Strategy Spec

**EA ID:** QM5_12938
**Slug:** hopwood-bermaui-dss-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

Hopwood Bermaui-DSS is a counter-trend oscillator mean-reversion strategy operating on H4 bars. It computes Blau's Double-Stochastic-Smoothed (DSS) oscillator (8-period %K smoothed by 5-period and 3-period EMAs) and tracks a dynamic Bermaui volatility band (20-bar SMA +/- 1.8 std).

When DSS reverses back into the dynamic bands after a >2.0 std extreme overshoot in the direction of the higher-timeframe D1 EMA(200) trend, a counter-trend reversal trade is entered at market open of the next H4 bar. The strategy enforces ATR-based stop loss (1.5x ATR), ATR profit target (1.5x ATR), a 10-bar time stop, break-even trailing at +0.75x ATR profit, and opposite-signal exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_dss_stoch_period | 8 | 6-12 | DSS raw stochastic lookback (%K) |
| strategy_dss_inner_ema | 5 | 3-8 | DSS first EMA smoothing period |
| strategy_dss_outer_ema | 3 | 2-5 | DSS second EMA smoothing period |
| strategy_bermaui_lookback | 20 | 15-30 | Bermaui dynamic threshold lookback |
| strategy_bermaui_k | 1.8 | 1.5-2.2 | Bermaui std multiplier for dynamic bands |
| strategy_min_overshoot_mult | 2.0 | 1.8-2.5 | Minimum overshoot threshold in std deviations |
| strategy_d1_ema_period | 200 | 100-250 | Higher-TF D1 trend filter EMA period |
| strategy_atr_period | 14 | 10-21 | ATR period for stops and targets |
| strategy_atr_sl_mult | 1.5 | 1.0-2.5 | Stop loss distance in ATR multiples |
| strategy_atr_tp_mult | 1.5 | 1.0-2.5 | Take profit distance in ATR multiples |
| strategy_max_hold_bars | 10 | 6-16 | Maximum hold duration in H4 bars |
| strategy_cooldown_bars | 6 | 4-10 | Minimum bars between entries in same direction |
| strategy_be_atr_mult | 0.75 | 0.5-1.5 | Break-even trigger profit in ATR multiples |
| strategy_spread_max_atr_mult | 0.3 | 0.2-0.5 | Max allowed spread as fraction of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — liquid DAX 40 index CFD
- `NDX.DWX` — liquid Nasdaq 100 index CFD
- `SP500.DWX` — liquid S&P 500 index CFD
- `UK100.DWX` — liquid FTSE 100 index CFD
- `WS30.DWX` — liquid Dow 30 index CFD
- `XAUUSD.DWX` — liquid Gold commodity CFD
- `EURUSD.DWX` — liquid FX major
- `GBPUSD.DWX` — liquid FX major
- `USDJPY.DWX` — liquid FX major
- `USDCHF.DWX` — liquid FX major
- `AUDUSD.DWX` — liquid FX major
- `USDCAD.DWX` — liquid FX major
- `NZDUSD.DWX` — liquid FX major

**Explicitly NOT for:**
- Illiquid exotics or symbols without continuous tick history.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 (EMA 200 trend filter) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15-35 |
| Typical hold time | 1-3 days (max 10 H4 bars) |
| Expected drawdown profile | Moderate mean-reversion pullbacks with strict ATR and time stops |
| Regime preference | Trending higher TF with short-term oscillator exhaustion |
| Win rate target (qualitative) | Medium (50-60%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum / book
**Pointer:** Steve Hopwood FF thread/254595 + William Blau (Momentum, Direction and Divergence, Wiley 1995)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12938_hopwood-bermaui-dss-h4.md`

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
| v1 | 2026-08-21 | Initial build from card | 8393fe44-f0b1-4105-be77-0595d6761efe |
