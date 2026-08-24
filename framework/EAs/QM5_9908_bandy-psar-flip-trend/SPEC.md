# QM5_9908_bandy-psar-flip-trend — Strategy Spec

**EA ID:** QM5_9908
**Slug:** bandy-psar-flip-trend
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Development (Codex rework)
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

The EA implements Howard Bandy's Parabolic SAR Flip Trend strategy on daily bars.
On each closed D1 bar, it computes Wilder's Parabolic SAR (step 0.02, max 0.20), a 200-day SMA regime filter, and ATR(14).
A long entry is triggered on the next bar open when PSAR flips from above price to below price on the closed bar and Close > SMA(200).
A short entry is triggered on the next bar open when PSAR flips from below price to above price on the closed bar and Close < SMA(200).
Positions exit on the next bar open when PSAR flips against the position (above price for long, below price for short), or after a restart-safe 60-D1-bar hard time stop.
The initial PSAR level is the protective stop and the fixed-risk sizing distance. The stop ratchets with closed-bar PSAR through `QM_TM_MoveSL`. A distinct 4.0 * ATR(14) catastrophe boundary is computed at entry, persisted in the position comment, and remains the worst permitted stop after restart.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_psar_step` | 0.02 | 0.01-0.05 | Acceleration factor step for Parabolic SAR |
| `strategy_psar_max` | 0.20 | 0.10-0.40 | Maximum acceleration factor for Parabolic SAR |
| `strategy_sma_period` | 200 | 50-300 | Lookback period for the 200-day SMA regime filter |
| `strategy_atr_period` | 14 | 7-30 | ATR period for catastrophic stop loss calculation |
| `strategy_sl_atr_mult` | 4.0 | 2.0-6.0 | ATR multiplier for catastrophic protective stop loss |
| `strategy_time_stop_bars` | 60 | 20-100 | Maximum holding period in trading days if no SAR flip occurs |
| `strategy_warmup_bars` | 200 | 100-300 | Minimum required closed bars before trading |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 benchmark index (backtest baseline)
- `NDX.DWX` — Nasdaq 100 index CFD
- `WS30.DWX` — Dow Jones Industrial Average CFD
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX` — Major FX currency pairs
- `XAUUSD.DWX` — Gold commodity CFD
- `XTIUSD.DWX` — Oil CFD

**Explicitly NOT for:**
- Illiquid or non-trending low-volatility instruments.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_D1` |
| Multi-timeframe refs | none |
| Initialization contract | `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` rejects a non-D1 chart |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)`; signals read only closed D1 bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~22 |
| Typical hold time | 5 to 30 days (up to 60 D1 bars) |
| Expected drawdown profile | Moderate trend-following drawdowns during choppy/ranging periods |
| Regime preference | Persistent trending bull/bear regimes |
| Win rate target (qualitative) | Medium (40% - 50%) with high payoff ratio |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** Book / Howard B. Bandy
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 9780979183850
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9908_bandy-psar-flip-trend.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

Backtest setfiles seal `RISK_FIXED=1000` and `RISK_PERCENT=0`; live packaging must invert the active mode (`RISK_PERCENT>0`, `RISK_FIXED=0`). Framework sizing configuration is checked by `QM_FrameworkInit` / `EA_RISK_SIZER_UNCONFIGURED`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v2 | 2026-08-24 | Mandatory review rework | D1 contract, PSAR-distance sizing/trail, restart-safe catastrophe boundary, management reachability, and approved symbol scope |
| v1 | 2026-08-23 | Initial build from approved card | Task ce7ef250-d7c0-418a-aa51-fff4f7a8136e |
