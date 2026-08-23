# QM5_11291_tc20-ema18-28-wma5-12-rsi21-h1 — Strategy Spec

**EA ID:** QM5_11291
**Slug:** `tc20-ema18-28-wma5-12-rsi21-h1`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter strategy archive)
**Author of this spec:** Codex
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

On each new H1 bar, the EA checks that the EMA(18)/EMA(28) tunnel is compressed
within 0.2 ATR(14). It buys when WMA(5) and WMA(12) cross from below to above the
tunnel and RSI(21) is above 50; it sells on the mirrored cross with RSI below 50.
The primary baseline uses fixed 50-pip stop and target, while the card-authorized
P3 stop variant uses 2 ATR(14). A position is closed when both WMAs cross through
the opposite side of the tunnel. New entries above the 20-pip spread cap are skipped.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_ema_fast_period` | 18 | 10-24 | Fast EMA forming the tunnel. |
| `strategy_ema_slow_period` | 28 | 20-40 | Slow EMA forming the tunnel. |
| `strategy_wma_fast_period` | 5 | 3-8 | Fast linear-weighted trigger average. |
| `strategy_wma_slow_period` | 12 | 8-15 | Slow linear-weighted trigger average. |
| `strategy_rsi_period` | 21 | 14-21 | RSI confirmation period. |
| `strategy_rsi_midline` | 50.0 | 45-55 | Long/short confirmation threshold. |
| `strategy_atr_period` | 14 | 10-30 | ATR period for tunnel width and optional stop. |
| `strategy_tunnel_atr_max` | 0.20 | 0.1-0.3 | Maximum tunnel width in ATR units. |
| `strategy_require_wma_cross` | false | false/true | Requires the card's extra-strong WMA(5)/WMA(12) cross. |
| `strategy_use_atr_stop` | false | false/true | Selects the authorized 2-ATR stop variant. |
| `strategy_atr_sl_mult` | 2.0 | 1.0-3.0 | ATR multiplier when the stop variant is enabled. |
| `strategy_fixed_sl_pips` | 50 | 30-80 | Baseline fixed stop distance. |
| `strategy_fixed_tp_pips` | 50 | 30-100 | Baseline fixed target distance. |
| `strategy_max_spread_pips` | 20.0 | 2.0-20.0 | Maximum spread for a new entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary liquid major named by the card.
- `GBPUSD.DWX` — portable liquid major named by the card.
- `USDJPY.DWX` — portable liquid major named by the card.

**Explicitly NOT for:**
- Non-FX CFDs — the source and fixed-pip baseline are scoped to major currency pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with an H1 chart guard |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12 |
| Typical hold time | hours to several days |
| Expected drawdown profile | card estimate around 18%; fixed/ATR protection and central governors cap individual/account risk |
| Regime preference | trend emergence after H1 tunnel compression |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** archived PDF
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy 20.
**R1-R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11291_tc20-ema18-28-wma5-12-rsi21-h1.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`; every backtest set keeps
`RISK_FIXED > 0` and `RISK_PERCENT = 0`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Completed implementation from approved card | task aa43aa9c-27b9-4ee3-b71c-58c1a4abd0f5 |
