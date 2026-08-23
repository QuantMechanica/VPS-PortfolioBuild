# QM5_40008_aqr-value-and-momentum-everywhere — Strategy Spec

**EA ID:** QM5_40008
**Slug:** `aqr-value-and-momentum-everywhere`
**Source:** `aqr-value-and-momentum-everywhere-official-source` (see `strategy-seeds/cards/approved/QM5_40008_aqr-value-and-momentum-everywhere.md`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

The strategy implements the AQR Value and Momentum Everywhere Multi-Asset Engine (Asness, Moskowitz, Pedersen 2013) across a 4-asset cross-sectional universe (`SP500.DWX`, `NDX.DWX`, `XTIUSD.DWX`, `EURUSD.DWX`). All calculations are evaluated strictly on the close of bar [1] (Shift = 1) on D1.

- **12-Month Momentum Factor ($M_t$):** 252-day return $(P[1] - P[253]) / P[253]$.
- **5-Year Valuation Factor ($V_t$):** 1260-day mean reversion Z-score $-(P[1] - \text{SMA}(1260)) / \text{std}(1260)$.
- **Cross-Sectional Combined Score:** $0.50 \times \text{Rank}(M_t) + 0.50 \times \text{Rank}(V_t)$ normalized across universe members.
- **Macro Trend Gate:** D1 Close[1] vs SMA(200)[1].
- **Long Entry:** $\text{CombinedScore} \ge 0.70$ AND $\text{Close}[1] > \text{SMA}(200)[1]$.
- **Short Entry:** $\text{CombinedScore} \le 0.30$ AND $\text{Close}[1] < \text{SMA}(200)[1]$.
- **Stop Loss:** Initial hard stop placed at entry $\mp 2.5 \times \text{ATR}(14, \text{D1})[1]$.
- **Take Profit / Exit:** Open-ended quarterly dynamic factor rebalancing exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | `D1` | Execution and indicator timeframe |
| `InpMomDays` | `252` | `100-300` | 1-year momentum lookback trading days |
| `InpValDays` | `1260` | `500-1500` | 5-year valuation mean lookback trading days |
| `InpSMAPeriod` | `200` | `50-300` | Macro trend baseline SMA period |
| `InpScoreThresholdLong` | `0.70` | `0.60-0.85` | Combined score threshold for long entry |
| `InpScoreThresholdShort` | `0.30` | `0.15-0.40` | Combined score threshold for short entry |
| `InpATRPeriod` | `14` | `10-30` | Stop Loss ATR period |
| `InpATRMultiplier` | `2.5` | `1.5-4.0` | Stop Loss ATR multiplier |
| `InpSpreadATRMult` | `1.8` | `1.0-3.0` | Max spread multiplier vs ATR(14, D1) |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_daily_loss_halt_pct` | `2.0` | `0.5-5.0` | Daily realized loss entry halt percent |
| `strategy_daily_hard_stop_pct` | `2.5` | `1.0-5.0` | Maximum daily drawdown hard stop percent |
| `strategy_total_dd_stop_pct` | `5.0` | `2.0-10.0` | Maximum total drawdown stop percent |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — US large cap equity index CFD (slot 0)
- `NDX.DWX` — US tech equity index CFD (slot 1)
- `XTIUSD.DWX` — WTI Crude Oil energy commodity CFD (slot 2)
- `EURUSD.DWX` — Major FX currency pair (slot 3)

**Explicitly NOT for:** any symbol outside the declared 4-asset cross-sectional universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | 1 quarter (quarterly factor rebalancing) |
| Expected drawdown profile | < 7.2% Maximum Drawdown |
| Regime preference | Multi-asset momentum and value divergence |
| Win rate target (qualitative) | High (> 70%) with factor balance |

---

## 6. Source Citation

**Source ID:** `aqr-value-and-momentum-everywhere-official-source`
**Source Citation:** Asness, C. S., Moskowitz, T. J., & Pedersen, L. H. (2013). Value and Momentum Everywhere. Journal of Finance.
**R1–R4 verdict (Q00):** all PASS — see `strategy-seeds/cards/approved/QM5_40008_aqr-value-and-momentum-everywhere.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build | Task 3e8438fe-884f-4337-974d-7c8c2a1dd459 |
| v2 | 2026-08-23 | Complete cross-asset rank overhaul & card loss limits | Resolves Codex review findings |
