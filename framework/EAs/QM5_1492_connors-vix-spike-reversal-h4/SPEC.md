# QM5_1492_connors-vix-spike-reversal-h4 — Strategy Spec

**EA ID:** QM5_1492
**Slug:** `connors-vix-spike-reversal-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

On each H4 bar close, the EA checks six gates: (1) current ATR(14) is at least 1.5× its 50-bar SMA baseline (volatility spike), (2) at least one of the prior two bars also showed a stretch above 1.3× (persistence), (3) H4 close is above its 200-bar SMA and that SMA is rising over 10 bars (long-term uptrend), (4) H4 close is below its 5-bar SMA on both the most recent and second-most-recent bar (short-term pullback), (5) daily close is above its 50-bar SMA and that SMA is rising over 5 bars (D1 trend confirmation), and (6) at least 12 H4 bars have elapsed since the last entry trigger (cooldown). When all six gates pass, a market long is opened with a stop at 2×ATR(14) below entry. TP1 closes 60% of the position when H4 bar closes above the 5-bar SMA; TP2 closes the remaining 40% when H4 bar closes above the 10-bar SMA. A time stop closes the full position after 16 H4 bars regardless of profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 7–21 | ATR period for volatility measurement (H4) |
| `strategy_atr_baseline_period` | 50 | 20–100 | SMA period for ATR stretch baseline envelope |
| `strategy_stretch_entry` | 1.5 | 1.2–2.5 | Entry threshold: ATR must be this multiple of baseline |
| `strategy_stretch_confirm` | 1.3 | 1.0–2.0 | Persistence threshold: prior bar ATR/baseline |
| `strategy_sma_long_h4` | 200 | 100–300 | Long-term H4 SMA period for uptrend gate |
| `strategy_sma_long_slope_bars` | 10 | 5–20 | Bars back for SMA200 slope check |
| `strategy_sma_pullback_h4` | 5 | 3–10 | Fast H4 SMA for pullback gate and TP1 exit |
| `strategy_sma_exit_slow` | 10 | 5–20 | Slow H4 SMA for TP2 exit |
| `strategy_sma_d1` | 50 | 20–100 | Daily SMA period for D1 trend confirmation |
| `strategy_sma_d1_slope_bars` | 5 | 3–10 | Bars back for D1 SMA slope check |
| `strategy_cooldown_bars` | 12 | 6–24 | Minimum H4 bars between entry triggers |
| `strategy_time_stop_bars` | 16 | 8–32 | Maximum H4 bars before forced close |
| `strategy_sl_atr_mult` | 2.0 | 1.0–4.0 | Stop loss = N × ATR(14) below entry |
| `strategy_warmup_h4_bars` | 250 | 200–400 | Minimum H4 bars before first entry allowed |
| `strategy_spread_mult` | 1.5 | 1.0–3.0 | Block entry if spread exceeds N × EMA(spread) |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Nasdaq 100; equity index with strong trend persistence and clear ATR-stretch vol-spike events
- `WS30.DWX` — Dow Jones 30; US large-cap index; Connors VIX mechanism calibrated to equity-index microstructure
- `GDAXI.DWX` — DAX 40; major EU equity index with similar vol-spike dynamics to US indices
- `UK100.DWX` — FTSE 100; major EU equity index; acceptable vol-stretch dynamics; live-tradable
- `SP500.DWX` — S&P 500; original Connors VIX source instrument; backtest-only (broker does not route live orders)

**Explicitly NOT for:**
- Forex pairs — VIX-stretch mechanism is calibrated to equity-index microstructure; FX vol dynamics are structurally different
- Commodities — excluded by card instrument scope

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `PERIOD_D1` (SMA50 for daily trend gate) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~100 |
| Typical hold time | 1–3 trading days (4–16 H4 bars) |
| Expected drawdown profile | Moderate; hard ATR stop limits individual trade loss |
| Regime preference | Mean-reversion pullback within long-term uptrend during volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book + forum
**Pointer:** Connors/Alvarez *Short Term Trading Strategies That Work* (TradingMarkets Publishing 2008, ISBN 978-0-9819239-0-1) ch. 9–10; ForexFactory Trading Systems subforum cluster "Connors VIX EA" / "VIX stretch reversal MT4" (2010–2024)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1492_connors-vix-spike-reversal-h4.md`

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
| v1 | 2026-07-01 | Initial build from card | 2e52925a-f50e-4e36-8394-35738beab9bb |
